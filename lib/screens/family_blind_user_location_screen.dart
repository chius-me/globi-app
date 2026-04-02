import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/blind_location.dart';
import '../models/family_blind_user.dart';
import '../models/family_blind_user_location.dart';
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
  FamilyBlindUserLocation? _locationResponse;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLocation();
    });
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await context
          .read<FamilyBlindProvider>()
          .refreshBlindUserLocation(widget.blindUser.blindUserId);
      if (!mounted) {
        return;
      }
      setState(() {
        _locationResponse = result;
      });
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openMap(BlindLocation location) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveLocation =
        _locationResponse?.latestLocation ?? widget.blindUser.latestLocation;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshLocation,
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
                            _locationResponse?.latestLocation?.updatedAt ??
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
                        if (effectiveLocation == null)
                          Text('暂无定位', style: theme.textTheme.bodyLarge)
                        else ...[
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
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _openMap(effectiveLocation),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('打开外部地图'),
                            ),
                          ),
                        ],
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
