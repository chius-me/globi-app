import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_tokens.dart';
import '../providers/app_mode_provider.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                'Globi',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.02,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                '选择你的身份',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: MinimalColors.textSecondary,
                ),
              ),
              const Spacer(flex: 2),
              _ModeCard(
                icon: Icons.accessible_forward_rounded,
                label: '我是盲人',
                description: '使用语音助手和定位服务',
                onTap: () =>
                    context.read<AppModeProvider>().selectBlindMode(),
              ),
              const SizedBox(height: Spacing.lg),
              _ModeCard(
                icon: Icons.family_restroom_rounded,
                label: '我是盲人家属',
                description: '查看家人位置和安全状态',
                onTap: () =>
                    context.read<AppModeProvider>().selectFamilyMode(),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isDark ? BorderTokens.dark : BorderTokens.light;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(RadiusTokens.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(RadiusTokens.card),
            border: Border.all(color: borderColor, width: BorderTokens.thin),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(RadiusTokens.soft),
                ),
                child: Icon(icon, size: 28, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: MinimalColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.md),
              Icon(
                Icons.chevron_right_rounded,
                color: MinimalColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
