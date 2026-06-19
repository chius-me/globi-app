import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/blind_location.dart';
import '../models/family_blind_user.dart';
import '../models/family_blind_user_map.dart';
import '../providers/family_blind_provider.dart';
import '../utils/api_error.dart';

class FamilyBlindUserLocationScreen extends StatefulWidget {
  final FamilyBlindUser blindUser;

  const FamilyBlindUserLocationScreen({super.key, required this.blindUser});

  static Route<void> route({required FamilyBlindUser blindUser}) {
    return MaterialPageRoute<void>(
      builder: (_) => FamilyBlindUserLocationScreen(blindUser: blindUser),
    );
  }

  @override
  State<FamilyBlindUserLocationScreen> createState() =>
      _FamilyBlindUserLocationScreenState();
}

class _FamilyBlindUserLocationScreenState
    extends State<FamilyBlindUserLocationScreen> {
  FamilyBlindUserMap? _mapResponse;
  String? _errorMessage;
  bool _isLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLocation();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshLocation({bool reschedule = true}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await context
          .read<FamilyBlindProvider>()
          .refreshBlindUserMap(widget.blindUser.blindUserId);
      if (!mounted) {
        return;
      }
      setState(() {
        _mapResponse = result;
      });
      if (reschedule) {
        _scheduleRefresh(result.refreshIntervalSeconds);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = resolveApiErrorMessage(
          error,
          fallback: '定位加载失败，请稍后重试。',
        );
      });
      if (reschedule) {
        _scheduleRefresh(_mapResponse?.refreshIntervalSeconds ?? 5);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scheduleRefresh(int seconds) {
    _refreshTimer?.cancel();
    final safeSeconds = seconds.clamp(3, 60);
    _refreshTimer = Timer(Duration(seconds: safeSeconds), () {
      if (!mounted) {
        return;
      }
      unawaited(_refreshLocation());
    });
  }

  bool get _isLocationStale {
    final latestLocation = _mapResponse?.latestLocation;
    final updatedAt = latestLocation?.updatedAt ?? latestLocation?.capturedAt;
    if (latestLocation == null || updatedAt == null) {
      return false;
    }

    return DateTime.now().toUtc().difference(updatedAt).inSeconds >
        (_mapResponse?.staleAfterSeconds ?? 30);
  }

  Future<void> _showMapOptions(BlindLocation location) async {
    final options = await _buildMapLaunchOptions(location);
    if (!mounted) {
      return;
    }

    if (options.isEmpty) {
      _showMapLaunchError();
      return;
    }

    final selected = await showModalBottomSheet<_MapLaunchOption>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Text(
                  '选择地图应用',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final option in options)
                ListTile(
                  leading: Icon(option.icon),
                  title: Text(option.label),
                  subtitle: option.subtitle == null ? null : Text(option.subtitle!),
                  onTap: () => Navigator.of(context).pop(option),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    final launched = await launchUrl(
      selected.uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showMapLaunchError();
    }
  }

  Future<List<_MapLaunchOption>> _buildMapLaunchOptions(
    BlindLocation location,
  ) async {
    final lat = location.latitude;
    final lng = location.longitude;
    final encodedName = Uri.encodeComponent(widget.blindUser.blindUserName);
    final label = '${widget.blindUser.blindUserName}的位置';
    final encodedLabel = Uri.encodeComponent(label);

    final candidates = <_MapLaunchOption>[
      if (Platform.isAndroid)
        _MapLaunchOption(
          label: '系统默认地图',
          subtitle: '使用系统选择器打开',
          icon: Icons.map_rounded,
          uri: Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedName)'),
        ),
      if (Platform.isIOS)
        _MapLaunchOption(
          label: 'Apple 地图',
          icon: Icons.map_rounded,
          uri: Uri.parse('https://maps.apple.com/?ll=$lat,$lng&q=$encodedLabel'),
        ),
      _MapLaunchOption(
        label: 'Google 地图',
        icon: Icons.public_rounded,
        uri: Uri.parse('comgooglemaps://?q=$lat,$lng'),
      ),
      _MapLaunchOption(
        label: '高德地图',
        icon: Icons.navigation_rounded,
        uri: Uri.parse(
          '${Platform.isIOS ? 'iosamap' : 'androidamap'}://viewMap?sourceApplication=globi&poiname=$encodedLabel&lat=$lat&lon=$lng&dev=0',
        ),
      ),
      _MapLaunchOption(
        label: '百度地图',
        icon: Icons.location_on_rounded,
        uri: Uri.parse(
          'baidumap://map/marker?location=$lat,$lng&title=$encodedLabel&content=$encodedLabel',
        ),
      ),
      _MapLaunchOption(
        label: '腾讯地图',
        icon: Icons.near_me_rounded,
        uri: Uri.parse(
          'qqmap://map/marker?marker=coord:$lat,$lng;title:$encodedLabel',
        ),
      ),
      _MapLaunchOption(
        label: '浏览器打开地图',
        subtitle: '无需安装地图应用',
        icon: Icons.open_in_browser_rounded,
        uri: Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        ),
        alwaysShow: true,
      ),
    ];

    final available = <_MapLaunchOption>[];
    for (final option in candidates) {
      if (option.alwaysShow || await canLaunchUrl(option.uri)) {
        available.add(option);
      }
    }
    return available;
  }

  void _showMapLaunchError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开地图应用，请稍后重试。')),
    );
  }

  Future<void> _confirmDeleteBlindUser() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除绑定'),
        content: const Text('确认删除当前盲人绑定关系吗？删除后盲人端需要重新授权绑定。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    final deleted = await context.read<FamilyBlindProvider>().deleteBlindUser(
      widget.blindUser.blindUserId,
    );
    if (!mounted) {
      return;
    }

    if (deleted) {
      _refreshTimer?.cancel();
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _errorMessage =
          context.read<FamilyBlindProvider>().errorMessage ?? '删除绑定失败，请稍后重试。';
    });
  }

  Widget _buildMapPreview(
    ThemeData theme,
    ColorScheme colorScheme,
    BlindLocation? location,
  ) {
    if (location == null) {
      return Container(
        height: 280,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('暂无定位', style: theme.textTheme.bodyLarge),
      );
    }

    final point = LatLng(location.latitude, location.longitude);

    return SizedBox(
      height: 280,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FlutterMap(
          key: ValueKey(
            '${location.latitude}_${location.longitude}_${location.updatedAt}',
          ),
          options: MapOptions(initialCenter: point, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'cn.tamochi.globi_mobile',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 72,
                  height: 72,
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 44,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveLocation =
        _mapResponse?.latestLocation ?? widget.blindUser.latestLocation;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refreshLocation(reschedule: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.large(title: Text(widget.blindUser.blindUserName)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.list(
                children: [
                  _SectionCard(
                    color: colorScheme.primaryContainer,
                    onColor: colorScheme.onPrimaryContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.blindUser.blindUserName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.blindUser.deviceLabel ?? '未填写设备名称',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoLine(
                          label: '绑定时间',
                          value: _formatDateTime(widget.blindUser.linkedAt),
                          color: colorScheme.onPrimaryContainer,
                        ),
                        _InfoLine(
                          label: '最近在线',
                          value: _formatDateTime(widget.blindUser.lastSeenAt),
                          color: colorScheme.onPrimaryContainer,
                        ),
                        _InfoLine(
                          label: '最近定位',
                          value: _formatDateTime(
                            _mapResponse?.latestLocation?.updatedAt ??
                                widget.blindUser.lastLocationAt,
                          ),
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_errorMessage != null) ...[
                    _SectionCard(
                      color: colorScheme.errorContainer,
                      onColor: colorScheme.onErrorContainer,
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_isLocationStale) ...[
                    _SectionCard(
                      color: colorScheme.tertiaryContainer,
                      onColor: colorScheme.onTertiaryContainer,
                      child: Text(
                        '定位可能已过期，请稍后刷新确认盲人端是否仍在持续上报。',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SectionCard(
                    color: colorScheme.surfaceContainerLow,
                    onColor: colorScheme.onSurface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.my_location_rounded,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '最新精准定位',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _isLoading ? null : _refreshLocation,
                              icon: _isLoading
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildMapPreview(theme, colorScheme, effectiveLocation),
                        if (effectiveLocation != null) ...[
                          const SizedBox(height: 16),
                          _InfoLine(
                            label: '纬度',
                            value: effectiveLocation.latitude.toStringAsFixed(
                              6,
                            ),
                          ),
                          _InfoLine(
                            label: '经度',
                            value: effectiveLocation.longitude.toStringAsFixed(
                              6,
                            ),
                          ),
                          _InfoLine(
                            label: '精度',
                            value: _formatDistance(
                              effectiveLocation.accuracyMeters,
                            ),
                          ),
                          _InfoLine(
                            label: '速度',
                            value: _formatSpeed(effectiveLocation.speedMps),
                          ),
                          _InfoLine(
                            label: '朝向',
                            value: _formatHeading(
                              effectiveLocation.headingDegrees,
                            ),
                          ),
                          _InfoLine(
                            label: '来源',
                            value: effectiveLocation.provider ?? '未知',
                          ),
                          _InfoLine(
                            label: '采集时间',
                            value: _formatDateTime(
                              effectiveLocation.capturedAt,
                            ),
                          ),
                          _InfoLine(
                            label: '更新时间',
                            value: _formatDateTime(effectiveLocation.updatedAt),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    color: colorScheme.surfaceContainerHigh,
                    onColor: colorScheme.onSurface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (effectiveLocation != null)
                          OutlinedButton.icon(
                            onPressed: () => _showMapOptions(effectiveLocation),
                            icon: const Icon(Icons.map_rounded),
                            label: const Text('选择地图导航'),
                          ),
                        if (effectiveLocation != null)
                          const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _isLoading ? null : _refreshLocation,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('立即刷新定位'),
                        ),
                        const SizedBox(height: 12),
                        Consumer<FamilyBlindProvider>(
                          builder: (context, familyBlind, _) {
                            return FilledButton.icon(
                              onPressed: familyBlind.isDeletingBlindUser
                                  ? null
                                  : _confirmDeleteBlindUser,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.error,
                                foregroundColor: colorScheme.onError,
                              ),
                              icon: familyBlind.isDeletingBlindUser
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onError,
                                      ),
                                    )
                                  : const Icon(Icons.delete_forever_rounded),
                              label: Text(
                                familyBlind.isDeletingBlindUser
                                    ? '删除中...'
                                    : '删除绑定',
                              ),
                            );
                          },
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
  }
}

class _MapLaunchOption {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Uri uri;
  final bool alwaysShow;

  const _MapLaunchOption({
    required this.label,
    required this.icon,
    required this.uri,
    this.subtitle,
    this.alwaysShow = false,
  });
}

class _SectionCard extends StatelessWidget {
  final Color color;
  final Color onColor;
  final Widget child;

  const _SectionCard({
    required this.color,
    required this.onColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InfoLine({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color?.withValues(alpha: 0.75),
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

String _formatDistance(double? value) {
  if (value == null) {
    return '未知';
  }
  return '${value.toStringAsFixed(1)} m';
}

String _formatSpeed(double? value) {
  if (value == null) {
    return '未知';
  }
  return '${value.toStringAsFixed(1)} m/s';
}

String _formatHeading(double? value) {
  if (value == null) {
    return '未知';
  }
  return '${value.toStringAsFixed(0)}°';
}
