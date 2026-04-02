import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

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

  final TextEditingController _textController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
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
    unawaited(_recordingAmplitudeSubscription?.cancel());
    unawaited(_playerPositionSubscription?.cancel());
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_audioPlayer.dispose());
    unawaited(_audioRecorder.dispose());
    super.dispose();
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

    if (!mounted) {
      return;
    }

    if (!force && (value - _waveLevel).abs() < 0.01) {
      return;
    }

    setState(() {
      _waveLevel = value < 0.01 ? 0.0 : value;
    });
  }

  Future<void> _startRecordingAmplitudeTracking() async {
    await _recordingAmplitudeSubscription?.cancel();
    _recordingAmplitudeSubscription = _audioRecorder
        .onAmplitudeChanged(_waveSampleInterval)
        .listen((amplitude) {
          if (!_isRecording) {
            return;
          }
          _updateWaveLevel(_normalizeMicrophoneLevel(amplitude.current));
        });
  }

  Future<void> _stopRecordingAmplitudeTracking() async {
    await _recordingAmplitudeSubscription?.cancel();
    _recordingAmplitudeSubscription = null;
    _updateWaveLevel(0.0, force: true);
  }

  void _handleSpeechPosition(Duration position) {
    if (!_isSpeaking || _playbackEnvelope.isEmpty) {
      return;
    }

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
    if (path == null || path.isEmpty) {
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      return;
    }

    try {
      await file.delete();
    } catch (_) {
      // Ignore temporary file cleanup failures.
    }
  }

  void _finishSpeechPlayback() {
    if (!mounted) {
      return;
    }

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
    if (message.isEmpty || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      await _stopSpeechPlayback();
      if (!mounted) {
        return;
      }

      setState(() {
        _isPreparingSpeech = true;
        _waveLevel = 0.0;
      });

      final speechBytes = await context
          .read<BlindAssistantProvider>()
          .synthesizeSpeech(message);
      if (!mounted || speechBytes == null || speechBytes.isEmpty) {
        return;
      }

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
      if (!mounted) {
        return;
      }
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
    if (!mounted) {
      return;
    }
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
        if (!mounted) {
          return;
        }
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
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
        _waveLevel = 0.0;
      });
      await _startRecordingAmplitudeTracking();
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('开始录音失败，请稍后重试。')));
    }
  }

  Future<void> _stopRecordingAndSend() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _stopRecordingAmplitudeTracking();
      final path = await _audioRecorder.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
      });

      if (path == null || path.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('没有录到语音，请再试一次。')));
        return;
      }

      final bytes = await File(path).readAsBytes();
      if (!mounted) {
        return;
      }

      final reply = await context
          .read<BlindAssistantProvider>()
          .sendVoiceMessage(
            audioBytes: Uint8List.fromList(bytes),
            fileName: 'assistant-input.wav',
            audioFormat: 'wav',
          );

      if (!mounted || reply == null) {
        return;
      }

      await _speakAssistantReply(reply.text);
    } catch (_) {
      if (!mounted) {
        return;
      }
      await _stopRecordingAmplitudeTracking();
      setState(() {
        _isRecording = false;
      });
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
            16,
            8,
            16,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '输入',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                minLines: 3,
                maxLines: 6,
                autofocus: true,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) {
                  final message = value.trim();
                  if (message.isEmpty) {
                    return;
                  }
                  Navigator.of(sheetContext).pop(message);
                },
                decoration: const InputDecoration(
                  hintText: '请输入',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final message = _textController.text.trim();
                  if (message.isEmpty) {
                    return;
                  }
                  Navigator.of(sheetContext).pop(message);
                },
                child: const Text('发送'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || submitted == null) {
      return;
    }

    final reply = await context.read<BlindAssistantProvider>().sendMessage(
      submitted,
    );
    if (!mounted || reply == null) {
      return;
    }

    await _speakAssistantReply(reply.text);
  }

  BlindAssistantMessage? _latestAssistantMessage(
    List<BlindAssistantMessage> messages,
  ) {
    for (final message in messages.reversed) {
      if (!message.isUser) {
        return message;
      }
    }
    return null;
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
      _AssistantVisualState.ready => '待命',
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
        final latestAssistant = _latestAssistantMessage(assistant.messages);
        final displayText = assistant.errorMessage ?? latestAssistant?.text;
        final isBusy =
            assistant.isInitializing ||
            assistant.isSending ||
            _isPreparingSpeech;
        final isActionLocked = isBusy || _isRecording || _isSpeaking;
        final showKeyboardEntry = !isBusy && !_isRecording && !_isSpeaking;

        return Scaffold(
          appBar: AppBar(
            title: const Text('助手'),
            actions: [
              IconButton(
                onPressed: showKeyboardEntry ? _openTextInputSheet : null,
                tooltip: '文字输入',
                icon: const Icon(Icons.keyboard_rounded),
              ),
              IconButton(
                onPressed: isActionLocked ? null : _resetConversation,
                tooltip: '重来',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _WaveStage(
                      state: visualState,
                      label: _labelForState(visualState),
                      intensity: _waveLevel,
                      animation: _waveController,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (displayText != null &&
                            displayText.trim().isNotEmpty)
                          _ReplyCard(
                            text: displayText.trim(),
                            isError: assistant.errorMessage != null,
                          ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _InputButton(
                            isBusy: isBusy,
                            isRecording: _isRecording,
                            onTap: isBusy ? null : _toggleRecording,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaveStage extends StatelessWidget {
  final _AssistantVisualState state;
  final String label;
  final double intensity;
  final Animation<double> animation;

  const _WaveStage({
    required this.state,
    required this.label,
    required this.intensity,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final primaryWaveColor = switch (state) {
      _AssistantVisualState.ready => colorScheme.primary,
      _AssistantVisualState.connecting => colorScheme.secondary,
      _AssistantVisualState.listening => colorScheme.primary,
      _AssistantVisualState.thinking => colorScheme.tertiary,
      _AssistantVisualState.speaking => colorScheme.secondary,
      _AssistantVisualState.error => colorScheme.error,
    };

    final secondaryWaveColor = switch (state) {
      _AssistantVisualState.ready => colorScheme.secondary,
      _AssistantVisualState.connecting => colorScheme.primary,
      _AssistantVisualState.listening => colorScheme.tertiary,
      _AssistantVisualState.thinking => colorScheme.primary,
      _AssistantVisualState.speaking => colorScheme.primary,
      _AssistantVisualState.error => colorScheme.error,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
        child: Column(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _WavePainter(
                      progress: animation.value,
                      state: state,
                      intensity: intensity,
                      primaryColor: primaryWaveColor,
                      secondaryColor: secondaryWaveColor,
                      tertiaryColor: colorScheme.outline,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: primaryWaveColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: primaryWaveColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final _AssistantVisualState state;
  final double intensity;
  final Color primaryColor;
  final Color secondaryColor;
  final Color tertiaryColor;

  const _WavePainter({
    required this.progress,
    required this.state,
    required this.intensity,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final center = Offset(size.width / 2, centerY);
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

    final haloPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.05 + (energy * 0.12))
      ..style = PaintingStyle.fill;
    final corePaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.08 + (energy * 0.18))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      center,
      size.shortestSide * (0.16 + (energy * 0.08)),
      haloPaint,
    );
    canvas.drawCircle(
      center,
      size.shortestSide * (0.08 + (energy * 0.04)),
      corePaint,
    );

    final baselinePaint = Paint()
      ..color = tertiaryColor.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      baselinePaint,
    );

    final baseAmplitude = switch (state) {
      _AssistantVisualState.ready => 6.0,
      _AssistantVisualState.connecting => 10.0,
      _AssistantVisualState.listening => 11.0,
      _AssistantVisualState.thinking => 14.0,
      _AssistantVisualState.speaking => 10.0,
      _AssistantVisualState.error => 3.0,
    };

    final amplitudeBoost = switch (state) {
      _AssistantVisualState.ready => 5.0,
      _AssistantVisualState.connecting => 10.0,
      _AssistantVisualState.listening => 34.0,
      _AssistantVisualState.thinking => 14.0,
      _AssistantVisualState.speaking => 30.0,
      _AssistantVisualState.error => 1.0,
    };

    final speed = switch (state) {
      _AssistantVisualState.ready => 0.7,
      _AssistantVisualState.connecting => 1.2,
      _AssistantVisualState.listening => 1.5 + (energy * 0.8),
      _AssistantVisualState.thinking => 2.1,
      _AssistantVisualState.speaking => 1.4 + (energy * 0.7),
      _AssistantVisualState.error => 0.3,
    };

    final configs = [
      (primaryColor, 1.0, 0.0, 4.0),
      (secondaryColor.withValues(alpha: 0.80), 0.68, 18.0, 3.0),
      (primaryColor.withValues(alpha: 0.42), 0.42, -16.0, 2.0),
    ];

    for (var index = 0; index < configs.length; index++) {
      final (color, factor, yOffset, strokeWidth) = configs[index];
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final path = Path();
      final phase = progress * math.pi * 2 * speed * (index + 1);
      final amplitude = (baseAmplitude + (amplitudeBoost * energy)) * factor;
      final frequency = 1.35 + (index * 0.28);

      for (double x = 0; x <= size.width; x += 4) {
        final normalized = x / size.width;
        final y =
            centerY +
            yOffset +
            math.sin((normalized * math.pi * 2 * frequency) + phase) *
                amplitude;

        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.state != state ||
        oldDelegate.intensity != intensity ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.tertiaryColor != tertiaryColor;
  }
}

class _ReplyCard extends StatelessWidget {
  final String text;
  final bool isError;

  const _ReplyCard({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = isError
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHighest;
    final foregroundColor = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onSurface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 120),
          child: SingleChildScrollView(
            child: Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                color: foregroundColor,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputButton extends StatelessWidget {
  final bool isBusy;
  final bool isRecording;
  final VoidCallback? onTap;

  const _InputButton({
    required this.isBusy,
    required this.isRecording,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final buttonSize = shortestSide < 380 ? 176.0 : 200.0;

    return Semantics(
      button: true,
      label: isBusy
          ? '处理中'
          : isRecording
          ? '结束录音并发送'
          : '开始录音',
      child: Material(
        color: isBusy
            ? colorScheme.secondaryContainer
            : isRecording
            ? colorScheme.errorContainer
            : colorScheme.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isBusy
                      ? Icons.graphic_eq_rounded
                      : isRecording
                      ? Icons.stop_rounded
                      : Icons.mic_rounded,
                  size: buttonSize * 0.28,
                  color: isBusy
                      ? colorScheme.onSecondaryContainer
                      : isRecording
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimary,
                ),
                const SizedBox(height: 10),
                Text(
                  isBusy
                      ? '稍候'
                      : isRecording
                      ? '结束录音'
                      : '开始录音',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isBusy
                        ? colorScheme.onSecondaryContainer
                        : isRecording
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
