import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  Future<void> _refreshBlindHome() async {
    final blindMode = context.read<BlindModeProvider>();
    await blindMode.refreshBlindIdentity();
    if (blindMode.isLinked) {
      await blindMode.uploadCurrentLocation(silentErrors: false);
    }
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
            child: const Text('清除授权'),
          ),
        ],
      ),
    );

    if (shouldClear == true && mounted) {
      await context.read<BlindModeProvider>().clearBlindAuthorization();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<BlindModeProvider>(
      builder: (context, blindMode, _) {
        final blindIdentity = blindMode.blindIdentity;
        final lastLocation = blindMode.lastUploadedLocation;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refreshBlindHome,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar.large(
                  title: Text(blindIdentity?.blindUserName ?? '盲人模式'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      tooltip: '切换身份',
                      onPressed: () =>
                          context.read<AppModeProvider>().resetMode(),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList.list(
                    children: [
                      if (blindMode.errorMessage != null) ...[
                        _BlindCard(
                          color: colorScheme.errorContainer,
                          onColor: colorScheme.onErrorContainer,
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  blindMode.errorMessage!,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: blindMode.clearError,
                                icon: const Icon(Icons.close),
                                color: colorScheme.onErrorContainer,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _BlindCard(
                        color: colorScheme.primaryContainer,
                        onColor: colorScheme.onPrimaryContainer,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '你好，${blindIdentity?.blindUserName ?? '欢迎使用'}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              blindIdentity?.familyDisplayName.isNotEmpty ==
                                      true
                                  ? '已绑定家属：${blindIdentity!.familyDisplayName}'
                                  : '已完成盲人身份绑定',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StatusLine(
                              label: '设备名称',
                              value: blindIdentity?.deviceLabel ?? '未填写',
                              color: colorScheme.onPrimaryContainer,
                            ),
                            _StatusLine(
                              label: '绑定时间',
                              value: _formatDateTime(blindIdentity?.linkedAt),
                              color: colorScheme.onPrimaryContainer,
                            ),
                            _StatusLine(
                              label: '最近在线',
                              value: _formatDateTime(blindIdentity?.lastSeenAt),
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 170,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _BentoTile(
                                icon: Icons.record_voice_over,
                                label: '语音助手',
                                subtitle: '继续使用当前盲人语音能力',
                                color: colorScheme.secondaryContainer,
                                onColor: colorScheme.onSecondaryContainer,
                                onTap: () => Navigator.of(
                                  context,
                                ).push(BlindAssistantScreen.route()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _BentoTile(
                                icon: blindMode.isUploadingLocation
                                    ? Icons.sync
                                    : Icons.my_location_rounded,
                                label: blindMode.isUploadingLocation
                                    ? '上传中'
                                    : '上传定位',
                                subtitle: '立即上报当前坐标',
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
                      _BlindCard(
                        color: colorScheme.surfaceContainerLow,
                        onColor: colorScheme.onSurface,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '定位共享状态',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (blindMode.isUploadingLocation)
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (lastLocation == null)
                              Text(
                                '暂无已上传的位置。进入页面后会自动尝试上传，也可以手动触发一次。',
                                style: theme.textTheme.bodyLarge,
                              )
                            else ...[
                              _StatusLine(
                                label: '纬度',
                                value: lastLocation.latitude.toStringAsFixed(6),
                              ),
                              _StatusLine(
                                label: '经度',
                                value: lastLocation.longitude.toStringAsFixed(
                                  6,
                                ),
                              ),
                              _StatusLine(
                                label: '精度',
                                value: _formatMeters(
                                  lastLocation.accuracyMeters,
                                ),
                              ),
                              _StatusLine(
                                label: '来源',
                                value: lastLocation.provider ?? '未知',
                              ),
                              _StatusLine(
                                label: '采集时间',
                                value: _formatDateTime(lastLocation.capturedAt),
                              ),
                              _StatusLine(
                                label: '上传时间',
                                value: _formatDateTime(lastLocation.updatedAt),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: blindMode.isUploadingLocation
                                      ? null
                                      : () => blindMode.uploadCurrentLocation(
                                          silentErrors: false,
                                        ),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('重新上传'),
                                ),
                                TextButton.icon(
                                  onPressed: blindMode.openLocationSettings,
                                  icon: const Icon(Icons.settings_suggest),
                                  label: const Text('定位服务设置'),
                                ),
                                TextButton.icon(
                                  onPressed: blindMode.openAppSettings,
                                  icon: const Icon(Icons.lock_open),
                                  label: const Text('应用权限设置'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 110,
                        child: Row(
                          children: [
                            Expanded(
                              child: _BentoTile(
                                icon: Icons.link_off_rounded,
                                label: '重新绑定',
                                subtitle: '清除盲人授权',
                                color: colorScheme.errorContainer,
                                onColor: colorScheme.onErrorContainer,
                                onTap: _confirmClearBlindAuthorization,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BentoTile(
                                icon: Icons.swap_horiz,
                                label: '切换身份',
                                subtitle: '返回身份选择页',
                                color: colorScheme.surfaceContainerHigh,
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BlindCard extends StatelessWidget {
  final Color color;
  final Color onColor;
  final Widget child;

  const _BlindCard({
    required this.color,
    required this.onColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatusLine({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color?.withValues(alpha: 0.72),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '暂无';
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

String _formatMeters(double? value) {
  if (value == null) {
    return '未知';
  }
  return '${value.toStringAsFixed(1)} m';
}

class _BentoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color onColor;
  final VoidCallback? onTap;

  const _BentoTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36, color: onColor),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: onColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: onColor.withValues(alpha: 0.72),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
