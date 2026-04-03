import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final colorScheme = theme.colorScheme;

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
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  if (blindMode.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        blindMode.errorMessage!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _BigButton(
                            icon: Icons.record_voice_over,
                            label: '语音助手',
                            color: colorScheme.secondaryContainer,
                            onColor: colorScheme.onSecondaryContainer,
                            onTap: () => Navigator.of(
                              context,
                            ).push(BlindAssistantScreen.route()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BigButton(
                            icon: blindMode.isUploadingLocation
                                ? Icons.sync
                                : Icons.my_location_rounded,
                            label: blindMode.isUploadingLocation
                                ? '上传中'
                                : '上传定位',
                            color: colorScheme.tertiaryContainer,
                            onColor: colorScheme.onTertiaryContainer,
                            onTap: blindMode.isUploadingLocation
                                ? null
                                : () => blindMode.uploadCurrentLocation(
                                    silentErrors: false,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _BigButton(
                            icon: blindMode.isCallingFamily
                                ? Icons.sync
                                : Icons.phone_callback_rounded,
                            label: blindMode.isCallingFamily ? '获取中' : '呼叫家属',
                            color: colorScheme.primaryContainer,
                            onColor: colorScheme.onPrimaryContainer,
                            onTap: blindMode.isCallingFamily
                                ? null
                                : _callFamily,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BigButton(
                            icon: Icons.sos_rounded,
                            label: '呼叫SOS',
                            color: colorScheme.errorContainer,
                            onColor: colorScheme.onErrorContainer,
                            onTap: () {
                              // TODO: 预留呼叫SOS功能
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('功能开发中')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _BigButton(
                            icon: Icons.link_off_rounded,
                            label: '重新绑定',
                            color: colorScheme.surfaceBright,
                            onColor: colorScheme.onSurface,
                            onTap: _confirmClearBlindAuthorization,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BigButton(
                            icon: Icons.swap_horiz,
                            label: '切换身份',
                            color: colorScheme.surfaceDim,
                            onColor: colorScheme.onSurface,
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
          ),
        );
      },
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;
  final VoidCallback? onTap;

  const _BigButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(32),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: onColor),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: onColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
