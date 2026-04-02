import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_provider.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                '选择身份',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                flex: 3,
                child: _BentoCard(
                  icon: Icons.accessible_forward,
                  label: '我是盲人',
                  subtitle: '无障碍模式',
                  color: colorScheme.primaryContainer,
                  onColor: colorScheme.onPrimaryContainer,
                  onTap: () =>
                      context.read<AppModeProvider>().selectBlindMode(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: 2,
                child: _BentoCard(
                  icon: Icons.family_restroom,
                  label: '我是盲人家属',
                  subtitle: '家属协助模式',
                  color: colorScheme.secondaryContainer,
                  onColor: colorScheme.onSecondaryContainer,
                  onTap: () =>
                      context.read<AppModeProvider>().selectFamilyMode(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  const _BentoCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: onColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 32, color: onColor),
              ),
              const Spacer(),
              Text(
                label,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: onColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: onColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
