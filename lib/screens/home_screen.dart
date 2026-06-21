import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/design_tokens.dart';
import '../models/blind_link_code.dart';
import '../models/family_blind_user.dart';
import '../providers/app_mode_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/family_blind_provider.dart';
import '../widgets/globi_button.dart';
import '../widgets/globi_card.dart';
import '../widgets/globi_error_banner.dart';
import 'family_change_password_screen.dart';
import 'family_blind_user_location_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  final TextEditingController _blindUserNameController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    if (!mounted) return;
    await context.read<FamilyBlindProvider>().refreshBlindUsers();
  }

  Future<void> _generateBlindLinkCode(FamilyBlindProvider familyBlind) async {
    FocusScope.of(context).unfocus();
    await familyBlind.createBlindLinkCode(
      blindUserName: _blindUserNameController.text,
    );
  }

  void _showCopySnackbar(String code) {
    Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('授权码已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, FamilyBlindProvider>(
      builder: (context, auth, familyBlind, _) {
        final pages = <Widget>[
          _MainTab(
            controller: _blindUserNameController,
            latestLinkCode: familyBlind.latestLinkCode,
            isSubmitting: familyBlind.isCreatingLinkCode,
            errorMessage: familyBlind.errorMessage,
            onGenerate: () => _generateBlindLinkCode(familyBlind),
            onDismissError: familyBlind.clearError,
            onCopy: () => _showCopySnackbar(
              familyBlind.latestLinkCode!.authorizationCode,
            ),
            blindUsers: familyBlind.blindUsers,
            isLoading: familyBlind.isLoadingBlindUsers,
            onRefresh: familyBlind.refreshBlindUsers,
          ),
          _SettingsTab(
            isLocalLogin: auth.isLocalLogin,
            onRefresh: () => _refreshHome(auth),
            onChangePassword: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FamilyChangePasswordScreen(),
                ),
              );
            },
            onLogout: () => _confirmLogout(context, auth),
          ),
        ];

        return Scaffold(
          backgroundColor: MinimalColors.lightBg,
          body: IndexedStack(
            index: _currentTabIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentTabIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentTabIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: '主页',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: '我的',
              ),
            ],
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
              if (!context.mounted) return;
              await context.read<AppModeProvider>().resetMode();
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

class _MainTab extends StatelessWidget {
  final TextEditingController controller;
  final BlindLinkCode? latestLinkCode;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onGenerate;
  final VoidCallback onDismissError;
  final VoidCallback onCopy;
  final List<FamilyBlindUser> blindUsers;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const _MainTab({
    required this.controller,
    required this.latestLinkCode,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onGenerate,
    required this.onDismissError,
    required this.onCopy,
    required this.blindUsers,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg, Spacing.xl, Spacing.lg, Spacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '家人守护',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            '生成授权码，查看已绑定用户的位置状态。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: MinimalColors.textSecondary,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: GlobiErrorBanner(
                message: errorMessage!,
                onDismiss: onDismissError,
              ),
            ),
          GlobiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlobiCardHeader(
                  leading: Icon(
                    Icons.qr_code_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: '生成授权码',
                  subtitle: '输入姓名后生成一次性授权码。',
                ),
                const SizedBox(height: Spacing.lg),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: '盲人用户姓名',
                    hintText: '例如 张三',
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onGenerate(),
                ),
                const SizedBox(height: Spacing.md),
                GlobiButton(
                  label: latestLinkCode == null ? '生成授权码' : '重新生成授权码',
                  icon: Icons.add_link_rounded,
                  isLoading: isSubmitting,
                  onPressed: onGenerate,
                ),
                if (latestLinkCode != null) ...[
                  const SizedBox(height: Spacing.lg),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Spacing.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(RadiusTokens.soft),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        width: BorderTokens.thin,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                latestLinkCode!.authorizationCode,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  fontFamily: 'Geist Mono',
                                ),
                              ),
                            ),
                            const SizedBox(width: Spacing.sm),
                            IconButton(
                              onPressed: onCopy,
                              icon: const Icon(Icons.copy_rounded),
                              tooltip: '复制授权码',
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.sm),
                        _InfoRow(
                          label: '对象',
                          value: latestLinkCode!.blindUserName,
                        ),
                        const SizedBox(height: Spacing.xs),
                        _InfoRow(
                          label: '到期',
                          value: _formatDateTime(latestLinkCode!.expiresAt),
                        ),
                        if (latestLinkCode!.expiresIn != null) ...[
                          const SizedBox(height: Spacing.xs),
                          _InfoRow(
                            label: '有效期',
                            value: '${latestLinkCode!.expiresIn} 秒',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
          _BoundUsersSection(
            blindUsers: blindUsers,
            isLoading: isLoading,
            onRefresh: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _BoundUsersSection extends StatelessWidget {
  final List<FamilyBlindUser> blindUsers;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const _BoundUsersSection({
    required this.blindUsers,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlobiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlobiCardHeader(
            leading: Icon(
              Icons.groups_rounded,
              color: theme.colorScheme.primary,
            ),
            title: '已绑定盲人用户',
            trailing: IconButton(
              onPressed: isLoading ? null : onRefresh,
              icon: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          if (blindUsers.isEmpty && !isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
              child: Center(
                child: Text(
                  '暂无已绑定用户。\n完成首次绑定后，这里会显示列表。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: MinimalColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < blindUsers.length; index++) ...[
                  _BlindUserTile(blindUser: blindUsers[index]),
                  if (index != blindUsers.length - 1) const Divider(),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  final bool isLocalLogin;
  final VoidCallback onRefresh;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  const _SettingsTab({
    required this.isLocalLogin,
    required this.onRefresh,
    required this.onChangePassword,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg, Spacing.lg, Spacing.lg, Spacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlobiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlobiCardHeader(
                  leading: Icon(
                    Icons.settings_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: '设置',
                ),
                const SizedBox(height: Spacing.sm),
                _SettingsTile(
                  icon: Icons.refresh_rounded,
                  title: '刷新数据',
                  onTap: onRefresh,
                ),
                if (isLocalLogin) ...[
                  const Divider(),
                  _SettingsTile(
                    icon: Icons.password_rounded,
                    title: '修改密码',
                    onTap: onChangePassword,
                  ),
                ],
                const Divider(),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: '退出登录',
                  titleColor: theme.colorScheme.error,
                  onTap: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusTokens.soft),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.md,
          horizontal: Spacing.sm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: titleColor ?? theme.colorScheme.onSurface),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: titleColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: MinimalColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: MinimalColors.textSecondary,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
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
        : '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';

    final isFresh = location != null && !_isLocationStale(blindUser);

    return InkWell(
      borderRadius: BorderRadius.circular(RadiusTokens.soft),
      onTap: () => Navigator.of(context).push(
        FamilyBlindUserLocationScreen.route(blindUser: blindUser),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                blindUser.blindUserName.characters.first,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          blindUser.blindUserName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isFresh
                              ? MinimalColors.accentGreenBg
                              : MinimalColors.accentRedBg,
                          borderRadius: BorderRadius.circular(RadiusTokens.pill),
                        ),
                        child: Text(
                          isFresh ? '最新' : '离线',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isFresh
                                ? MinimalColors.accentGreenText
                                : MinimalColors.accentRedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '最近在线：${_formatDateTime(blindUser.lastSeenAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: MinimalColors.textSecondary,
                    ),
                  ),
                  Text(
                    locationText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: MinimalColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: MinimalColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

bool _isLocationStale(FamilyBlindUser user) {
  final loc = user.latestLocation;
  final updated = loc?.updatedAt ?? loc?.capturedAt;
  if (loc == null || updated == null) return true;
  return DateTime.now().toUtc().difference(updated).inSeconds > 30;
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '暂无';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
