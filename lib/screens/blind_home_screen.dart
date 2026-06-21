import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/design_tokens.dart';
import '../config/navigation.dart';
import '../providers/app_mode_provider.dart';
import '../providers/blind_mode_provider.dart';
import 'blind_assistant_screen.dart';

class BlindHomeScreen extends StatefulWidget {
  const BlindHomeScreen({super.key});

  @override
  State<BlindHomeScreen> createState() => _BlindHomeScreenState();
}

class _BlindHomeScreenState extends State<BlindHomeScreen>
    with WidgetsBindingObserver, RouteAware {
  bool _routeObserverAttached = false;
  Timer? _sosCountdownTimer;
  int _sosCountdownSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(context.read<BlindModeProvider>().startForegroundTracking());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeObserverAttached) {
      return;
    }

    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
      _routeObserverAttached = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final blindMode = context.read<BlindModeProvider>();
    if (state == AppLifecycleState.resumed) {
      unawaited(blindMode.startForegroundTracking());
      return;
    }

    if (state == AppLifecycleState.detached) {
      blindMode.stopForegroundTracking();
    }
  }

  @override
  void didPush() {
    unawaited(context.read<BlindModeProvider>().startForegroundTracking());
  }

  @override
  void didPopNext() {
    unawaited(context.read<BlindModeProvider>().startForegroundTracking());
  }

  @override
  void didPushNext() {
    unawaited(context.read<BlindModeProvider>().startForegroundTracking());
  }

  @override
  void dispose() {
    _sosCountdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_routeObserverAttached) {
      appRouteObserver.unsubscribe(this);
    }
    context.read<BlindModeProvider>().stopForegroundTracking();
    super.dispose();
  }

  Future<void> _confirmClearBlindAuthorization() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新绑定'),
        content: const Text('这会清除当前盲人授权，并回到授权码输入页。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('明确清除'),
          ),
        ],
      ),
    );

    if (shouldClear == true && mounted) {
      await context.read<BlindModeProvider>().clearBlindAuthorization();
    }
  }

  Future<void> _callFamily() async {
    final blindMode = context.read<BlindModeProvider>();
    final familyCall = await blindMode.fetchBlindFamilyCall();
    if (!mounted || familyCall == null) {
      return;
    }

    final uri = Uri.tryParse(familyCall.telUri);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前无法打开拨号界面')));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || launched) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前无法打开拨号界面')));
  }

  Future<void> _sendSos() async {
    _sosCountdownTimer?.cancel();
    if (mounted) {
      setState(() => _sosCountdownSeconds = 0);
    }
    _announce('正在发送 SOS 求助');
    final blindMode = context.read<BlindModeProvider>();
    final result = await blindMode.sendSos();
    if (!mounted || result == null) {
      return;
    }
    HapticFeedback.heavyImpact();
    _announce('SOS 已发送给家属');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('SOS 已发送给家属')));
  }

  void _showSosHint() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请长按 SOS 按钮发送紧急求助')));
  }

  void _startSosCountdown() {
    if (_sosCountdownSeconds > 0) return;
    HapticFeedback.heavyImpact();
    _announce('SOS 倒计时开始，双击屏幕取消求助');
    setState(() => _sosCountdownSeconds = 10);
    _sosCountdownTimer?.cancel();
    _sosCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_sosCountdownSeconds <= 1) {
        timer.cancel();
        unawaited(_sendSos());
        return;
      }
      HapticFeedback.vibrate();
      final nextSecond = _sosCountdownSeconds - 1;
      if (nextSecond == 5 || nextSecond <= 3) {
        _announce('SOS 将在 $nextSecond 秒后发送');
      }
      setState(() => _sosCountdownSeconds -= 1);
    });
  }

  void _cancelSosCountdown() {
    _sosCountdownTimer?.cancel();
    HapticFeedback.selectionClick();
    _announce('SOS 已取消');
    setState(() => _sosCountdownSeconds = 0);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('SOS 已取消')));
  }

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<BlindModeProvider>(
      builder: (context, blindMode, _) {
        final blindIdentity = blindMode.blindIdentity;

        return Scaffold(
          appBar: AppBar(
            title: Text(blindIdentity?.blindUserName ?? '盲人模式'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Column(
                    children: [
                      if (blindMode.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.md),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(Spacing.lg),
                            decoration: BoxDecoration(
                              color: MinimalColors.accentRedBg,
                              borderRadius: BorderRadius.circular(
                                RadiusTokens.soft,
                              ),
                              border: Border.all(
                                color: MinimalColors.accentRedText.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  blindMode.errorMessage!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: MinimalColors.accentRedText,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: Spacing.sm),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: Spacing.sm,
                                  runSpacing: Spacing.sm,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: blindMode.openLocationSettings,
                                      icon: const Icon(
                                        Icons.location_on_outlined,
                                      ),
                                      label: const Text('打开定位设置'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: blindMode.openAppSettings,
                                      icon: const Icon(Icons.settings_outlined),
                                      label: const Text('打开权限设置'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      _GuardianStatusCard(blindMode: blindMode),
                      const SizedBox(height: Spacing.md),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _BigButton(
                                icon: Icons.record_voice_over,
                                label: '语音助手',
                                semanticsHint: '打开语音助手，可以通过说话提问',
                                onTap: () => Navigator.of(
                                  context,
                                ).push(BlindAssistantScreen.route()),
                              ),
                            ),
                            const SizedBox(width: Spacing.md),
                            Expanded(
                              child: _LocationUploadStatusCard(
                                blindMode: blindMode,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _BigButton(
                                icon: blindMode.isCallingFamily
                                    ? Icons.sync
                                    : Icons.phone_callback_rounded,
                                label: blindMode.isCallingFamily
                                    ? '获取中'
                                    : '呼叫家属',
                                semanticsHint: '打开拨号界面联系绑定家属',
                                isLoading: blindMode.isCallingFamily,
                                onTap: blindMode.isCallingFamily
                                    ? null
                                    : _callFamily,
                              ),
                            ),
                            const SizedBox(width: Spacing.md),
                            Expanded(
                              child: _BigButton(
                                icon: blindMode.isSendingSos
                                    ? Icons.sync
                                    : Icons.sos_rounded,
                                label: blindMode.isSendingSos ? '发送中' : '长按SOS',
                                semanticsHint: '长按启动 SOS 倒计时',
                                isLoading: blindMode.isSendingSos,
                                isDestructive: true,
                                onTap: blindMode.isSendingSos
                                    ? null
                                    : _showSosHint,
                                onLongPress: blindMode.isSendingSos
                                    ? null
                                    : _startSosCountdown,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      SizedBox(
                        height: 72,
                        child: Row(
                          children: [
                            Expanded(
                              child: _BigButton(
                                icon: Icons.link_off_rounded,
                                label: '重新绑定',
                                semanticsHint: '清除当前授权，需要重新输入家属生成的授权码',
                                isSecondary: true,
                                isCompact: true,
                                onTap: _confirmClearBlindAuthorization,
                              ),
                            ),
                            const SizedBox(width: Spacing.md),
                            Expanded(
                              child: _BigButton(
                                icon: Icons.swap_horiz,
                                label: '切换身份',
                                semanticsHint: '切换到身份选择页面',
                                isSecondary: true,
                                isCompact: true,
                                onTap: () =>
                                    context.read<AppModeProvider>().resetMode(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_sosCountdownSeconds > 0)
                  _FullScreenSosCancelOverlay(
                    seconds: _sosCountdownSeconds,
                    onCancel: _cancelSosCountdown,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticsHint;
  final bool isLoading;
  final bool isDestructive;
  final bool isSecondary;
  final bool isCompact;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _BigButton({
    required this.icon,
    required this.label,
    required this.semanticsHint,
    this.isLoading = false,
    this.isDestructive = false,
    this.isSecondary = false,
    this.isCompact = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bgColor;
    Color fgColor;
    if (isDestructive) {
      bgColor = MinimalColors.accentRedBg;
      fgColor = MinimalColors.accentRedText;
    } else if (isSecondary) {
      bgColor = theme.colorScheme.surface;
      fgColor = MinimalColors.textPrimary;
    } else {
      bgColor = theme.colorScheme.primary.withValues(alpha: 0.08);
      fgColor = theme.colorScheme.primary;
    }

    final effectiveOnTap = (isLoading || onTap == null)
        ? null
        : () {
            HapticFeedback.mediumImpact();
            onTap!();
          };
    final effectiveOnLongPress = (isLoading || onLongPress == null)
        ? null
        : () {
            HapticFeedback.heavyImpact();
            onLongPress!();
          };

    return Semantics(
      button: true,
      label: label,
      hint: onLongPress == null
          ? '$semanticsHint，双击以激活'
          : '$semanticsHint，双击提示，长按激活',
      enabled: effectiveOnTap != null || effectiveOnLongPress != null,
      child: InkWell(
        onTap: effectiveOnTap,
        onLongPress: effectiveOnLongPress,
        borderRadius: BorderRadius.circular(
          isCompact ? RadiusTokens.soft : RadiusTokens.card,
        ),
        child: Container(
          padding: isCompact
              ? const EdgeInsets.symmetric(horizontal: Spacing.sm)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(
              isCompact ? RadiusTokens.soft : RadiusTokens.card,
            ),
            border: isSecondary
                ? Border.all(
                    color: theme.colorScheme.outline,
                    width: BorderTokens.thin,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: isCompact ? 22 : 32,
                  height: isCompact ? 22 : 32,
                  child: CircularProgressIndicator(
                    strokeWidth: isCompact ? 2.5 : 3,
                    color: fgColor,
                  ),
                )
              else
                Icon(icon, size: isCompact ? 22 : 40, color: fgColor),
              SizedBox(height: isCompact ? Spacing.xs : Spacing.md),
              Text(
                label,
                textAlign: TextAlign.center,
                style:
                    (isCompact
                            ? theme.textTheme.labelLarge
                            : theme.textTheme.titleMedium)
                        ?.copyWith(fontWeight: FontWeight.w600, color: fgColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationUploadStatusCard extends StatelessWidget {
  final BlindModeProvider blindMode;

  const _LocationUploadStatusCard({required this.blindMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = blindMode.lastUploadedLocation;
    final uploadedAt =
        location?.updatedAt ?? blindMode.lastUploadResult?.updatedAt;
    final statusText = blindMode.isUploadingLocation ? '正在上传' : '自动守护中';
    final detailText = uploadedAt == null
        ? '等待首次定位'
        : _relativeTime(uploadedAt);
    final accuracyText = location?.accuracyMeters == null
        ? '精度未知'
        : '精度约 ${location!.accuracyMeters!.round()} 米';

    return Semantics(
      liveRegion: true,
      label: '定位状态，$statusText，$detailText，$accuracyText',
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(RadiusTokens.card),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            width: BorderTokens.thin,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (blindMode.isUploadingLocation)
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: theme.colorScheme.primary,
                ),
              )
            else
              Icon(
                Icons.satellite_alt_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            const SizedBox(height: Spacing.md),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              detailText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: MinimalColors.textSecondary,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              accuracyText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: MinimalColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenSosCancelOverlay extends StatelessWidget {
  final int seconds;
  final VoidCallback onCancel;

  const _FullScreenSosCancelOverlay({
    required this.seconds,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Semantics(
        button: true,
        liveRegion: true,
        label: 'SOS 将在 $seconds 秒后发送，双击屏幕取消 SOS',
        hint: '双击取消 SOS',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onCancel,
          onDoubleTap: onCancel,
          child: Container(
            color: MinimalColors.accentRedText.withValues(alpha: 0.96),
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_rounded,
                  size: 72,
                  color: MinimalColors.textInverse,
                ),
                const SizedBox(height: Spacing.xl),
                Text(
                  '$seconds 秒后发送 SOS',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: MinimalColors.textInverse,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                Text(
                  '双击屏幕取消 SOS',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: MinimalColors.textInverse,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Spacing.xxl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                  decoration: BoxDecoration(
                    color: MinimalColors.textInverse,
                    borderRadius: BorderRadius.circular(RadiusTokens.card),
                  ),
                  child: Text(
                    '取消 SOS',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: MinimalColors.accentRedText,
                      fontWeight: FontWeight.w800,
                    ),
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

class _GuardianStatusCard extends StatelessWidget {
  final BlindModeProvider blindMode;

  const _GuardianStatusCard({required this.blindMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = blindMode.blindIdentity;
    final location = blindMode.lastUploadedLocation;
    final uploadedAt =
        location?.updatedAt ?? blindMode.lastUploadResult?.updatedAt;
    final batteryText = location?.batteryLevel == null
        ? '电量未知'
        : '电量 ${(location!.batteryLevel! * 100).round()}%';
    final chargingText = location?.isCharging == true ? '，充电中' : '';
    final deviceText = identity?.deviceLabel?.isNotEmpty == true
        ? identity!.deviceLabel!
        : '本机设备';
    final accuracyText = location?.accuracyMeters == null
        ? '精度未知'
        : '精度约 ${location!.accuracyMeters!.round()} 米';
    final coordinateText = location == null
        ? '坐标待上传'
        : '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';

    return Semantics(
      label:
          '守护状态，家属 ${identity?.familyDisplayName ?? '未绑定'}，定位追踪已开启，最后上传 ${_relativeTime(uploadedAt)}，$batteryText$chargingText',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(RadiusTokens.card),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            width: BorderTokens.thin,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    '守护状态：${identity?.familyDisplayName ?? '未绑定家属'}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              '定位追踪已开启 · ${_relativeTime(uploadedAt)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: MinimalColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              '$batteryText$chargingText · $accuracyText',
              style: theme.textTheme.bodySmall?.copyWith(
                color: MinimalColors.textSecondary,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: [
                _StatusPill(icon: Icons.devices_rounded, label: deviceText),
                _StatusPill(
                  icon: Icons.my_location_rounded,
                  label: coordinateText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(RadiusTokens.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MinimalColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: MinimalColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime? value) {
  if (value == null) {
    return '尚未上传';
  }
  final diff = DateTime.now().toUtc().difference(value.toUtc());
  if (diff.inMinutes < 1) {
    return '刚刚上传';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}分钟前上传';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}小时前上传';
  }
  return '${diff.inDays}天前上传';
}
