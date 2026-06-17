import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../config/design_tokens.dart';
import '../models/blind_assistant_message.dart';
import '../providers/blind_assistant_provider.dart';
import '../services/blind_assistant_api_service.dart';
import '../utils/wav_envelope.dart';

class BlindAssistantScreen extends StatelessWidget {
  const BlindAssistantScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) =>
            BlindAssistantProvider(assistantApi: BlindAssistantApiService())
              ..initialize(),
        child: const BlindAssistantScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _BlindAssistantView();
  }
}

enum _AssistantVisualState {
  ready,
  connecting,
  listening,
  thinking,
  speaking,
  error,
}

class _BlindAssistantView extends StatefulWidget {
  const _BlindAssistantView();

  @override
  State<_BlindAssistantView> createState() => _BlindAssistantViewState();
}

class _BlindAssistantViewState extends State<_BlindAssistantView>
    with SingleTickerProviderStateMixin {
  static const Duration _waveSampleInterval = Duration(
    milliseconds: kWaveEnvelopeBucketMillis,
  );
  static const _messageListKey = Key('message-list');

  final TextEditingController _textController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _messageScrollController = ScrollController();
  late final AnimationController _waveController;
  StreamSubscription<Amplitude>? _recordingAmplitudeSubscription;
  StreamSubscription<Duration>? _playerPositionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _isRecording = false;
  bool _isPreparingSpeech = false;
  bool _isSpeaking = false;
  double _waveLevel = 0.0;
  List<double> _playbackEnvelope = const [];
  String? _currentSpeechFilePath;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _playerPositionSubscription = _audioPlayer
        .createPositionStream(
          minPeriod: _waveSampleInterval,
          maxPeriod: _waveSampleInterval,
        )
        .listen(_handleSpeechPosition);
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      _handlePlayerStateChanged,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _waveController.dispose();
    _messageScrollController.dispose();
    unawaited(_recordingAmplitudeSubscription?.cancel());
    unawaited(_playerPositionSubscription?.cancel());
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_audioPlayer.dispose());
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageScrollController.hasClients) {
        _messageScrollController.animateTo(
          _messageScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  double _normalizeMicrophoneLevel(double dbfs) {
    if (dbfs.isNaN || dbfs.isInfinite) {
      return 0.0;
    }
    final clamped = dbfs.clamp(-48.0, 0.0);
    final linear = math.pow(10.0, clamped / 20.0).toDouble();
    return math.pow(linear.clamp(0.0, 1.0), 0.45).toDouble();
  }

  void _updateWaveLevel(
    double next, {
    double responsiveness = 0.34,
    bool force = false,
  }) {
    final target = next.clamp(0.0, 1.0);
    final value = force
        ? target
        : (_waveLevel * (1 - responsiveness)) + (target * responsiveness);
    if (!mounted) return;
    if (!force && (value - _waveLevel).abs() < 0.01) return;
    setState(() => _waveLevel = value < 0.01 ? 0.0 : value);
  }

  Future<void> _startRecordingAmplitudeTracking() async {
    await _recordingAmplitudeSubscription?.cancel();
    _recordingAmplitudeSubscription = _audioRecorder
        .onAmplitudeChanged(_waveSampleInterval)
        .listen((amplitude) {
          if (!_isRecording) return;
          _updateWaveLevel(_normalizeMicrophoneLevel(amplitude.current));
        });
  }

  Future<void> _stopRecordingAmplitudeTracking() async {
    await _recordingAmplitudeSubscription?.cancel();
    _recordingAmplitudeSubscription = null;
    _updateWaveLevel(0.0, force: true);
  }

  void _handleSpeechPosition(Duration position) {
    if (!_isSpeaking || _playbackEnvelope.isEmpty) return;
    final index = (position.inMilliseconds ~/ kWaveEnvelopeBucketMillis).clamp(
      0,
      _playbackEnvelope.length - 1,
    );
    _updateWaveLevel(_playbackEnvelope[index], responsiveness: 0.42);
  }

  void _handlePlayerStateChanged(PlayerState state) {
    if (state.processingState == ProcessingState.completed ||
        (!state.playing && _isSpeaking)) {
      _finishSpeechPlayback();
    }
  }

  Future<void> _deleteCurrentSpeechFile() async {
    final path = _currentSpeechFilePath;
    _currentSpeechFilePath = null;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }

  void _finishSpeechPlayback() {
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _playbackEnvelope = const [];
      _waveLevel = 0.0;
    });
    unawaited(_deleteCurrentSpeechFile());
  }

  List<double> _fallbackSpeechEnvelope(Duration duration) {
    final bucketCount = math.max(
      10,
      (duration.inMilliseconds / kWaveEnvelopeBucketMillis).ceil(),
    );
    return List<double>.generate(bucketCount, (index) {
      final phrase = math.sin((index / bucketCount) * math.pi * 3).abs();
      final beat = math.sin(index * 0.85).abs();
      return (0.22 + (phrase * 0.36) + (beat * 0.18)).clamp(0.12, 0.82);
    });
  }

  Future<void> _stopSpeechPlayback() async {
    if (_audioPlayer.playing || _isSpeaking) {
      await _audioPlayer.stop();
    }
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isPreparingSpeech = false;
        _playbackEnvelope = const [];
        _waveLevel = 0.0;
      });
    }
    await _deleteCurrentSpeechFile();
  }

  Future<void> _speakAssistantReply(String text) async {
    final message = text.trim();
    if (message.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _stopSpeechPlayback();
      if (!mounted) return;
      setState(() {
        _isPreparingSpeech = true;
        _waveLevel = 0.0;
      });
      final speechBytes = await context
          .read<BlindAssistantProvider>()
          .synthesizeSpeech(message);
      if (!mounted || speechBytes == null || speechBytes.isEmpty) return;
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/assistant-reply-${DateTime.now().microsecondsSinceEpoch}.wav';
      await File(filePath).writeAsBytes(speechBytes, flush: true);
      final duration = await _audioPlayer.setFilePath(filePath);
      final envelope = extractWaveEnvelope(speechBytes);
      final resolvedDuration =
          duration ??
          _audioPlayer.duration ??
          Duration(milliseconds: math.max(1600, message.runes.length * 150));
      if (!mounted) {
        await File(filePath).delete();
        return;
      }
      setState(() {
        _currentSpeechFilePath = filePath;
        _isPreparingSpeech = false;
        _isSpeaking = true;
        _playbackEnvelope = envelope.isEmpty
            ? _fallbackSpeechEnvelope(resolvedDuration)
            : envelope;
        _waveLevel = _playbackEnvelope.first;
      });
      unawaited(_audioPlayer.play());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPreparingSpeech = false;
        _isSpeaking = false;
        _playbackEnvelope = const [];
        _waveLevel = 0.0;
      });
      messenger.showSnackBar(const SnackBar(content: Text('语音播报失败，请稍后重试。')));
    }
  }

  Future<void> _resetConversation() async {
    await _stopSpeechPlayback();
    if (!mounted) return;
    await context.read<BlindAssistantProvider>().resetConversation();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndSend();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _stopSpeechPlayback();
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能使用语音输入。')),
        );
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/assistant-input-${DateTime.now().microsecondsSinceEpoch}.wav';
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: 16000,
      );
      await _audioRecorder.start(config, path: filePath);
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _waveLevel = 0.0;
      });
      await _startRecordingAmplitudeTracking();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('开始录音失败，请稍后重试。')));
    }
  }

  Future<void> _stopRecordingAndSend() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _stopRecordingAmplitudeTracking();
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (path == null || path.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('没有录到语音，请再试一次。')));
        return;
      }
      final bytes = await File(path).readAsBytes();
      if (!mounted) return;
      final reply = await context
          .read<BlindAssistantProvider>()
          .sendVoiceMessage(
            audioBytes: Uint8List.fromList(bytes),
            fileName: 'assistant-input.wav',
            audioFormat: 'wav',
          );
      if (!mounted || reply == null) return;
      await _speakAssistantReply(reply.text);
    } catch (_) {
      if (!mounted) return;
      await _stopRecordingAmplitudeTracking();
      setState(() => _isRecording = false);
      messenger.showSnackBar(const SnackBar(content: Text('语音发送失败，请稍后重试。')));
    }
  }

  Future<void> _openTextInputSheet() async {
    _textController.clear();
    final submitted = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.sm,
            Spacing.lg,
            MediaQuery.viewInsetsOf(sheetContext).bottom + Spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '文字输入',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: _textController,
                minLines: 3,
                maxLines: 6,
                autofocus: true,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) {
                  final message = value.trim();
                  if (message.isEmpty) return;
                  Navigator.of(sheetContext).pop(message);
                },
                decoration: const InputDecoration(
                  hintText: '输入你想说的话...',
                ),
              ),
              const SizedBox(height: Spacing.md),
              FilledButton(
                onPressed: () {
                  final message = _textController.text.trim();
                  if (message.isEmpty) return;
                  Navigator.of(sheetContext).pop(message);
                },
                child: const Text('发送'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || submitted == null) return;
    final reply = await context.read<BlindAssistantProvider>().sendMessage(
      submitted,
    );
    if (!mounted || reply == null) return;
    _scrollToBottom();
    await _speakAssistantReply(reply.text);
  }

  _AssistantVisualState _resolveVisualState(BlindAssistantProvider assistant) {
    if (assistant.errorMessage != null) {
      return _AssistantVisualState.error;
    }
    if (assistant.isInitializing) {
      return _AssistantVisualState.connecting;
    }
    if (_isRecording) {
      return _AssistantVisualState.listening;
    }
    if (assistant.isSending || _isPreparingSpeech) {
      return _AssistantVisualState.thinking;
    }
    if (_isSpeaking) {
      return _AssistantVisualState.speaking;
    }
    return _AssistantVisualState.ready;
  }

  String _labelForState(_AssistantVisualState state) {
    return switch (state) {
      _AssistantVisualState.ready => '待命中',
      _AssistantVisualState.connecting => '连接中',
      _AssistantVisualState.listening => '聆听中',
      _AssistantVisualState.thinking => '思考中',
      _AssistantVisualState.speaking => '播报中',
      _AssistantVisualState.error => '出错',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BlindAssistantProvider>(
      builder: (context, assistant, _) {
        final visualState = _resolveVisualState(assistant);
        final isBusy =
            assistant.isInitializing ||
            assistant.isSending ||
            _isPreparingSpeech;
        final isActionLocked = isBusy || _isRecording || _isSpeaking;
        final showKeyboardEntry = !isBusy && !_isRecording && !_isSpeaking;
        final hasMessages = assistant.messages.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('语音助手'),
            actions: [
              IconButton(
                onPressed: showKeyboardEntry ? _openTextInputSheet : null,
                tooltip: '文字输入',
                icon: const Icon(Icons.keyboard_rounded),
              ),
              IconButton(
                onPressed: isActionLocked ? null : _resetConversation,
                tooltip: '重来',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (hasMessages)
                  Expanded(
                    flex: 5,
                    child: _MessageList(
                      key: _messageListKey,
                      messages: assistant.messages,
                      scrollController: _messageScrollController,
                    ),
                  )
                else
                  Expanded(
                    flex: 5,
                    child: _WaveStage(
                      state: visualState,
                      label: _labelForState(visualState),
                      intensity: _waveLevel,
                      animation: _waveController,
                      errorMessage: assistant.errorMessage,
                    ),
                  ),
                _ControlBar(
                  visualState: visualState,
                  label: _labelForState(visualState),
                  intensity: _waveLevel,
                  isBusy: isBusy,
                  isRecording: _isRecording,
                  hasMessages: hasMessages,
                  errorMessage: assistant.errorMessage,
                  onToggleRecording: isBusy ? null : _toggleRecording,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MessageList extends StatelessWidget {
  final List<BlindAssistantMessage> messages;
  final ScrollController scrollController;

  const _MessageList({
    super.key,
    required this.messages,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        Spacing.lg, Spacing.md, Spacing.lg, 0,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: BorderTokens.thin,
        ),
      ),
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.all(Spacing.md),
        itemCount: messages.length,
        separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
        itemBuilder: (context, index) {
          final message = messages[index];
          return _MessageBubble(message: message);
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final BlindAssistantMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          decoration: BoxDecoration(
            color: MinimalColors.accentBlueBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(RadiusTokens.soft),
              topRight: Radius.circular(RadiusTokens.soft),
              bottomLeft: Radius.circular(RadiusTokens.soft),
              bottomRight: Radius.circular(RadiusTokens.crisp),
            ),
          ),
          child: Text(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: MinimalColors.accentBlueText,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(RadiusTokens.crisp),
            topRight: Radius.circular(RadiusTokens.soft),
            bottomLeft: Radius.circular(RadiusTokens.soft),
            bottomRight: Radius.circular(RadiusTokens.soft),
          ),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: BorderTokens.thin,
          ),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: MinimalColors.textPrimary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _WaveStage extends StatelessWidget {
  final _AssistantVisualState state;
  final String label;
  final double intensity;
  final Animation<double> animation;
  final String? errorMessage;

  const _WaveStage({
    required this.state,
    required this.label,
    required this.intensity,
    required this.animation,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final waveColor = switch (state) {
      _AssistantVisualState.ready => MinimalColors.accentBlueText,
      _AssistantVisualState.connecting => MinimalColors.accentGreenText,
      _AssistantVisualState.listening => MinimalColors.accentBlueText,
      _AssistantVisualState.thinking => MinimalColors.accentYellowText,
      _AssistantVisualState.speaking => MinimalColors.accentGreenText,
      _AssistantVisualState.error => MinimalColors.accentRedText,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(RadiusTokens.card),
          border: Border.all(
            color: colorScheme.outline,
            width: BorderTokens.thin,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md, Spacing.xl, Spacing.md, Spacing.sm,
                ),
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _WavePainter(
                        progress: animation.value,
                        state: state,
                        intensity: intensity,
                        waveColor: waveColor,
                      ),
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
            _StatusPill(
              label: errorMessage ?? label,
              color: state == _AssistantVisualState.error
                  ? MinimalColors.accentRedText
                  : waveColor,
              isError: errorMessage != null,
            ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isError;

  const _StatusPill({
    required this.label,
    required this.color,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RadiusTokens.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final _AssistantVisualState state;
  final double intensity;
  final Color waveColor;

  const _WavePainter({
    required this.progress,
    required this.state,
    required this.intensity,
    required this.waveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 25;
    final totalWidth = size.width - 16;
    final gap = 3.0;
    final barWidth = (totalWidth - gap * (barCount - 1)) / barCount;
    final midY = size.height / 2;

    final energy = switch (state) {
      _AssistantVisualState.ready => 0.10,
      _AssistantVisualState.connecting =>
        0.30 + (math.sin(progress * math.pi * 2).abs() * 0.14),
      _AssistantVisualState.listening => 0.16 + (intensity * 0.84),
      _AssistantVisualState.thinking =>
        0.38 + (math.sin(progress * math.pi * 4).abs() * 0.20),
      _AssistantVisualState.speaking => 0.14 + (intensity * 0.86),
      _AssistantVisualState.error => 0.05,
    };

    final maxHeight = size.height * 0.42;

    for (var i = 0; i < barCount; i++) {
      final centerFactor = 1.0 - ((i - barCount / 2).abs() / (barCount / 2));
      final centerWeight = 0.6 + 0.4 * centerFactor;

      final idlePhase = math.sin(progress * math.pi * 2 + i * 0.5) * 0.3 + 0.5;
      final idleHeight = 0.08 + idlePhase * 0.10;

      final amp = switch (state) {
        _AssistantVisualState.ready => idleHeight,
        _AssistantVisualState.connecting =>
          0.15 + math.sin(progress * math.pi * 2 + i * 0.7).abs() * 0.20,
        _AssistantVisualState.listening =>
          idleHeight * 0.2 + energy * 0.8 * centerWeight,
        _AssistantVisualState.thinking => 0.12 +
            (math.sin(progress * math.pi * 3 + i * 0.4).abs() * 0.32) *
                centerWeight,
        _AssistantVisualState.speaking =>
          idleHeight * 0.15 + energy * 0.85 * centerWeight,
        _AssistantVisualState.error => 0.05,
      };

      final barHeight = (amp * maxHeight).clamp(2.0, maxHeight);
      final x = 8 + i * (barWidth + gap);
      final y = midY - barHeight / 2;

      final opacity = switch (state) {
        _AssistantVisualState.ready => 0.35 + 0.30 * centerFactor,
        _AssistantVisualState.error => 0.25,
        _ => 0.50 + 0.50 * centerFactor,
      };

      final paint = Paint()
        ..color = waveColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rrect, paint);

      if (i == barCount ~/ 2 && (state == _AssistantVisualState.listening || state == _AssistantVisualState.speaking)) {
        final glowPaint = Paint()
          ..color = waveColor.withValues(alpha: 0.08 + energy * 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        final glowR = RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 4, y - 4, barWidth + 8, barHeight + 8),
          const Radius.circular(4),
        );
        canvas.drawRRect(glowR, glowPaint);
      }
    }

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          waveColor.withValues(alpha: 0.04 + energy * 0.06),
          waveColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * (0.5 - energy * 0.12)),
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.state != state ||
        oldDelegate.intensity != intensity ||
        oldDelegate.waveColor != waveColor;
  }
}

class _ControlBar extends StatelessWidget {
  final _AssistantVisualState visualState;
  final String label;
  final double intensity;
  final bool isBusy;
  final bool isRecording;
  final bool hasMessages;
  final String? errorMessage;
  final VoidCallback? onToggleRecording;

  const _ControlBar({
    required this.visualState,
    required this.label,
    required this.intensity,
    required this.isBusy,
    required this.isRecording,
    required this.hasMessages,
    this.errorMessage,
    required this.onToggleRecording,
  });

  @override
  Widget build(BuildContext context) {
    if (hasMessages && !isRecording && !isBusy && !_isSpeaking(visualState)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.md, Spacing.lg, Spacing.xl,
        ),
        child: _MicButton(
          isBusy: isBusy,
          isRecording: isRecording,
          onTap: onToggleRecording,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg, Spacing.md, Spacing.lg, Spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasMessages || isRecording || isBusy || _isSpeaking(visualState))
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: _StatusPill(
                label: errorMessage ?? label,
                color: visualState == _AssistantVisualState.error
                    ? MinimalColors.accentRedText
                    : isRecording
                    ? MinimalColors.accentBlueText
                    : MinimalColors.accentGreenText,
                isError: errorMessage != null,
              ),
            ),
          _MicButton(
            isBusy: isBusy,
            isRecording: isRecording,
            onTap: onToggleRecording,
          ),
        ],
      ),
    );
  }

  bool _isSpeaking(_AssistantVisualState state) {
    return state == _AssistantVisualState.speaking ||
        state == _AssistantVisualState.thinking;
  }
}

class _MicButton extends StatelessWidget {
  final bool isBusy;
  final bool isRecording;
  final VoidCallback? onTap;

  const _MicButton({
    required this.isBusy,
    required this.isRecording,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final buttonSize = shortestSide < 380 ? 96.0 : 112.0;

    final bgColor = isBusy
        ? MinimalColors.accentYellowBg
        : isRecording
        ? MinimalColors.accentRedBg
        : colorScheme.surface;
    final fgColor = isBusy
        ? MinimalColors.accentYellowText
        : isRecording
        ? MinimalColors.accentRedText
        : MinimalColors.textPrimary;

    return Semantics(
      button: true,
      label: isBusy
          ? '处理中'
          : isRecording
          ? '结束录音并发送'
          : '开始录音',
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: fgColor.withValues(alpha: 0.2),
            width: BorderTokens.thin,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBusy
                    ? Icons.graphic_eq_rounded
                    : isRecording
                    ? Icons.stop_rounded
                    : Icons.mic_rounded,
                size: buttonSize * 0.36,
                color: fgColor,
              ),
              const SizedBox(height: 4),
              Text(
                isBusy
                    ? '处理中'
                    : isRecording
                    ? '停止'
                    : '录音',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
