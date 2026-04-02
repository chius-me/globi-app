import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/blind_link_code.dart';
import '../models/family_blind_user.dart';
import '../providers/app_mode_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/family_blind_provider.dart';
import 'family_blind_user_location_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _blindUserNameController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<FamilyBlindProvider>().refreshBlindUsers();
    });
  }

  @override
  void dispose() {
    _blindUserNameController.dispose();
    super.dispose();
  }

  Future<void> _refreshHome(AuthProvider auth) async {
    await auth.refreshAuthenticatedSession();
    if (!mounted) {
      return;
    }
    await context.read<FamilyBlindProvider>().refreshBlindUsers();
  }

  Future<void> _generateBlindLinkCode(FamilyBlindProvider familyBlind) async {
    FocusScope.of(context).unfocus();
    await familyBlind.createBlindLinkCode(
      blindUserName: _blindUserNameController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer2<AuthProvider, FamilyBlindProvider>(
      builder: (context, auth, familyBlind, _) {
        final user = auth.user;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => _refreshHome(auth),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar.large(
                  title: const Text('Globi'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      tooltip: '切换身份',
                      onPressed: () => _confirmModeSwitch(context, auth),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: '退出登录',
                      onPressed: () => _confirmLogout(context, auth),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(
                    children: [
                      SizedBox(
                        height: 180,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _BentoCard(
                                color: colorScheme.primaryContainer,
                                onColor: colorScheme.onPrimaryContainer,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.displayName ?? '未知用户',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            color:
                                                colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    if (user?.email != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        user!.email!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: colorScheme
                                                  .onPrimaryContainer
                                                  .withValues(alpha: 0.8),
                                            ),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (user?.preferredUsername != null)
                                      Text(
                                        '@${user!.preferredUsername}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colorScheme
                                                  .onPrimaryContainer
                                                  .withValues(alpha: 0.6),
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _BentoCard(
                              color: colorScheme.tertiaryContainer,
                              onColor: colorScheme.onTertiaryContainer,
                              child: Center(
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: colorScheme.tertiary,
                                  backgroundImage: user?.picture != null
                                      ? NetworkImage(user!.picture!)
                                      : null,
                                  child: user?.picture == null
                                      ? Text(
                                          _getInitials(
                                            user?.displayName ?? '?',
                                          ),
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onTertiary,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _BentoCard(
                        color: colorScheme.secondaryContainer,
                        onColor: colorScheme.onSecondaryContainer,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '受保护接口状态',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              auth.privateMessage ?? '尚未拉取受保护接口数据',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                            if (auth.privateUserInfo != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Claims 数量：${auth.privateUserInfo!.length}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _BentoCard(
                        color: colorScheme.surfaceContainerLow,
                        onColor: colorScheme.onSurface,
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.person_outline,
                              label: '用户名',
                              value: user?.preferredUsername ?? '-',
                            ),
                            Divider(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                            _InfoRow(
                              icon: Icons.email_outlined,
                              label: '邮箱',
                              value: user?.email ?? '-',
                              trailing: user?.emailVerified == true
                                  ? Icon(
                                      Icons.verified,
                                      size: 18,
                                      color: colorScheme.primary,
                                    )
                                  : null,
                            ),
                            Divider(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                            _InfoRow(
                              icon: Icons.fingerprint,
                              label: '用户 ID',
                              value: user?.sub ?? '-',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (familyBlind.errorMessage != null) ...[
                        _BentoCard(
                          color: colorScheme.errorContainer,
                          onColor: colorScheme.onErrorContainer,
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  familyBlind.errorMessage!,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: familyBlind.clearError,
                                icon: const Icon(Icons.close),
                                color: colorScheme.onErrorContainer,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _BlindLinkGeneratorCard(
                        controller: _blindUserNameController,
                        latestLinkCode: familyBlind.latestLinkCode,
                        isSubmitting: familyBlind.isCreatingLinkCode,
                        onGenerate: () => _generateBlindLinkCode(familyBlind),
                      ),
                      const SizedBox(height: 12),
                      _BoundBlindUsersCard(
                        blindUsers: familyBlind.blindUsers,
                        isLoading: familyBlind.isLoadingBlindUsers,
                        onRefresh: familyBlind.refreshBlindUsers,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 110,
                        child: Row(
                          children: [
                            Expanded(
                              child: _BentoActionTile(
                                icon: Icons.refresh,
                                label: '刷新会话',
                                color: colorScheme.tertiaryContainer,
                                onColor: colorScheme.onTertiaryContainer,
                                onTap: () => _refreshHome(auth),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BentoActionTile(
                                icon: Icons.logout,
                                label: '退出登录',
                                color: colorScheme.errorContainer,
                                onColor: colorScheme.onErrorContainer,
                                onTap: () => _confirmLogout(context, auth),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<FamilyBlindProvider>().clearState();
              auth.logout();
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _confirmModeSwitch(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('切换身份'),
        content: const Text('切换身份会退出当前家属会话，并回到身份选择页。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              context.read<FamilyBlindProvider>().clearState();
              await auth.logout();
              if (!context.mounted) {
                return;
              }
              await context.read<AppModeProvider>().resetMode();
            },
            child: const Text('确认切换'),
          ),
        ],
      ),
    );
  }
}

class _BlindLinkGeneratorCard extends StatelessWidget {
  final TextEditingController controller;
  final BlindLinkCode? latestLinkCode;
  final bool isSubmitting;
  final VoidCallback onGenerate;

  const _BlindLinkGeneratorCard({
    required this.controller,
    required this.latestLinkCode,
    required this.isSubmitting,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _BentoCard(
      color: colorScheme.primaryContainer,
      onColor: colorScheme.onPrimaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.qr_code_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '绑定盲人用户',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '输入盲人用户名称后生成一次性授权码，供盲人端首次绑定使用。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: '盲人用户姓名',
              hintText: '例如 张三',
              filled: true,
              fillColor: colorScheme.surface,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onGenerate(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSubmitting ? null : onGenerate,
              icon: isSubmitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.add_link_rounded),
              label: Text(latestLinkCode == null ? '生成授权码' : '重新生成授权码'),
            ),
          ),
          if (latestLinkCode != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latestLinkCode!.authorizationCode,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '绑定对象：${latestLinkCode!.blindUserName}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '过期时间：${_formatDateTime(latestLinkCode!.expiresAt)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (latestLinkCode!.expiresIn != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '有效期：${latestLinkCode!.expiresIn} 秒',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BoundBlindUsersCard extends StatelessWidget {
  final List<FamilyBlindUser> blindUsers;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const _BoundBlindUsersCard({
    required this.blindUsers,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _BentoCard(
      color: colorScheme.surfaceContainerHigh,
      onColor: colorScheme.onSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_rounded, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '已绑定盲人用户',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
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
          const SizedBox(height: 8),
          if (blindUsers.isEmpty && !isLoading)
            Text(
              '暂无已绑定的盲人用户。生成授权码并在盲人端完成首次绑定后，这里会显示列表和最新定位。',
              style: theme.textTheme.bodyLarge,
            )
          else
            Column(
              children: [
                for (var index = 0; index < blindUsers.length; index++) ...[
                  _BlindUserTile(blindUser: blindUsers[index]),
                  if (index != blindUsers.length - 1)
                    Divider(
                      height: 20,
                      color: colorScheme.outline.withValues(alpha: 0.16),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _BlindUserTile extends StatelessWidget {
  final FamilyBlindUser blindUser;

  const _BlindUserTile({required this.blindUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = blindUser.latestLocation;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(
        context,
      ).push(FamilyBlindUserLocationScreen.route(blindUser: blindUser)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              child: Text(blindUser.blindUserName.characters.first),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blindUser.blindUserName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    blindUser.deviceLabel ?? '未填写设备名称',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '绑定时间：${_formatDateTime(blindUser.linkedAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '最近在线：${_formatDateTime(blindUser.lastSeenAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    location == null
                        ? '暂无定位'
                        : '最近定位：${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
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

class _BentoCard extends StatelessWidget {
  final Color color;
  final Color onColor;
  final Widget child;

  const _BentoCard({
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _BentoActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  const _BentoActionTile({
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
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: onColor),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  color: onColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
