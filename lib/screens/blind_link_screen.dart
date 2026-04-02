import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_provider.dart';
import '../providers/blind_mode_provider.dart';

class BlindLinkScreen extends StatefulWidget {
  const BlindLinkScreen({super.key});

  @override
  State<BlindLinkScreen> createState() => _BlindLinkScreenState();
}

class _BlindLinkScreenState extends State<BlindLinkScreen> {
  final TextEditingController _authorizationCodeController =
      TextEditingController();
  final TextEditingController _deviceLabelController = TextEditingController();

  @override
  void dispose() {
    _authorizationCodeController.dispose();
    _deviceLabelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await context.read<BlindModeProvider>().redeemBlindLinkCode(
      authorizationCode: _authorizationCodeController.text,
      deviceLabel: _deviceLabelController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Consumer<BlindModeProvider>(
            builder: (context, blindMode, _) {
              return ListView(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Icon(
                        Icons.key_rounded,
                        size: 52,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '盲人模式授权',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '首次进入需要输入家属提供的一次性授权码。绑定成功后，后续将自动恢复，不再重复输入。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (blindMode.errorMessage != null) ...[
                    _NoticeCard(
                      color: colorScheme.errorContainer,
                      onColor: colorScheme.onErrorContainer,
                      icon: Icons.error_outline,
                      title: '操作失败',
                      message: blindMode.errorMessage!,
                      trailing: IconButton(
                        onPressed: blindMode.clearError,
                        icon: const Icon(Icons.close),
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (blindMode.status == BlindSessionStatus.restoreFailed) ...[
                    _NoticeCard(
                      color: colorScheme.secondaryContainer,
                      onColor: colorScheme.onSecondaryContainer,
                      icon: Icons.sync_problem,
                      title: '已保存授权需要重新校验',
                      message: '当前无法确认本机上保存的盲人授权是否仍有效。你可以先重试校验，或清除授权后重新绑定。',
                      actions: [
                        FilledButton.tonal(
                          onPressed: blindMode.isRefreshingIdentity
                              ? null
                              : blindMode.refreshBlindIdentity,
                          child: Text(
                            blindMode.isRefreshingIdentity ? '校验中...' : '重新校验',
                          ),
                        ),
                        TextButton(
                          onPressed: blindMode.isRefreshingIdentity
                              ? null
                              : blindMode.clearBlindAuthorization,
                          child: const Text('清除授权'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Material(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.password_rounded,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '输入授权信息',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _authorizationCodeController,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '授权码',
                              hintText: '例如 ABCD-7KQ9',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _deviceLabelController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: '设备名称',
                              hintText: '例如 Xiaomi 14 Blind',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: blindMode.isLinking ? null : _submit,
                              icon: blindMode.isLinking
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.lock_open_rounded),
                              label: Text(
                                blindMode.isLinking ? '绑定中...' : '绑定并进入盲人模式',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.read<AppModeProvider>().resetMode(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.swap_horiz,
                              color: colorScheme.onSurface,
                            ),
                            const SizedBox(width: 8),
                            Text('切换使用身份', style: theme.textTheme.bodyLarge),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Color color;
  final Color onColor;
  final IconData icon;
  final String title;
  final String message;
  final Widget? trailing;
  final List<Widget> actions;

  const _NoticeCard({
    required this.color,
    required this.onColor,
    required this.icon,
    required this.title,
    required this.message,
    this.trailing,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: onColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}
