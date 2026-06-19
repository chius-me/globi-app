import 'dart:async';

import 'package:flutter/material.dart';
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

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
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
    context.read<BlindModeProvider>().stopForegroundTracking();
  }

  @override
  void dispose() {
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
            child: Padding(
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
                          borderRadius: BorderRadius.circular(RadiusTokens.soft),
                          border: Border.all(
                            color: MinimalColors.accentRedText.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          blindMode.errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: MinimalColors.accentRedText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _BigButton(
                          icon: Icons.record_voice_over,
                          label: '语音助手',
                          onTap: () => Navigator.of(context).push(BlindAssistantScreen.route()),
                        )),
                        const SizedBox(width: Spacing.md),
                        Expanded(child: _BigButton(
                          icon: blindMode.isUploadingLocation ? Icons.sync : Icons.my_location_rounded,
                          label: blindMode.isUploadingLocation ? '上传中' : '上传定位',
                          isLoading: blindMode.isUploadingLocation,
                          onTap: blindMode.isUploadingLocation ? null : () => blindMode.uploadCurrentLocation(silentErrors: false),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _BigButton(
                          icon: blindMode.isCallingFamily ? Icons.sync : Icons.phone_callback_rounded,
                          label: blindMode.isCallingFamily ? '获取中' : '呼叫家属',
                          isLoading: blindMode.isCallingFamily,
                          onTap: blindMode.isCallingFamily ? null : _callFamily,
                        )),
                        const SizedBox(width: Spacing.md),
                        Expanded(child: _BigButton(
                          icon: Icons.sos_rounded,
                          label: '呼叫SOS',
                          isDestructive: true,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('功能开发中')),
                            );
                          },
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _BigButton(
                          icon: Icons.link_off_rounded,
                          label: '重新绑定',
                          isSecondary: true,
                          onTap: _confirmClearBlindAuthorization,
                        )),
                        const SizedBox(width: Spacing.md),
                        Expanded(child: _BigButton(
                          icon: Icons.swap_horiz,
                          label: '切换身份',
                          isSecondary: true,
                          onTap: () => context.read<AppModeProvider>().resetMode(),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
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
  final bool isLoading;
  final bool isDestructive;
  final bool isSecondary;
  final VoidCallback? onTap;

  const _BigButton({
    required this.icon,
    required this.label,
    this.isLoading = false,
    this.isDestructive = false,
    this.isSecondary = false,
    this.onTap,
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

    return Semantics(
      button: true,
      label: label,
      hint: '双击以激活',
      enabled: effectiveOnTap != null,
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(RadiusTokens.card),
            border: isSecondary
                ? Border.all(color: theme.colorScheme.outline, width: BorderTokens.thin)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: fgColor,
                  ),
                )
              else
                Icon(icon, size: 40, color: fgColor),
              const SizedBox(height: Spacing.md),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
