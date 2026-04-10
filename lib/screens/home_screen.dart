import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/blind_link_code.dart';
import '../models/family_blind_user.dart';
import '../providers/app_mode_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/family_blind_provider.dart';
import 'family_change_password_screen.dart';
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
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => _refreshHome(auth),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  title: const Text('家属主页'),
                  actions: [
                    if (auth.isLocalLogin)
                      IconButton(
                        icon: const Icon(Icons.password_rounded),
                        tooltip: '修改密码',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const FamilyChangePasswordScreen(),
                            ),
                          );
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: '退出',
                      onPressed: () => _confirmLogout(context, auth),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(
                    children: [
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
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: familyBlind.isLoadingBlindUsers
                              ? null
                              : () => _refreshHome(auth),
                          icon: familyBlind.isLoadingBlindUsers
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: const Text('刷新数据'),
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

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出并返回首页身份选择吗？'),
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
            child: const Text('退出'),
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
                  '生成授权码',
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
            '输入姓名后生成一次性授权码。',
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
                    '对象：${latestLinkCode!.blindUserName}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '到期：${_formatDateTime(latestLinkCode!.expiresAt)}',
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
            Text('暂无已绑定用户。完成首次绑定后，这里会显示列表。', style: theme.textTheme.bodyLarge)
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
    final locationText = location == null
        ? '暂无定位'
        : '最近定位 ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';

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
                    '最近在线：${_formatDateTime(blindUser.lastSeenAt)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(locationText, style: theme.textTheme.bodySmall),
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
