import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_provider.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: _BentoCard(
                  icon: Icons.accessible_forward,
                  label: '我是盲人',
                  color: colorScheme.primaryContainer,
                  onColor: colorScheme.onPrimaryContainer,
                  onTap: () =>
                      context.read<AppModeProvider>().selectBlindMode(),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _BentoCard(
                  icon: Icons.family_restroom,
                  label: '我是盲人家属',
                  color: colorScheme.tertiaryContainer,
                  onColor: colorScheme.onTertiaryContainer,
                  onTap: () =>
                      context.read<AppModeProvider>().selectFamilyMode(),
                ),
              ),
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
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  const _BentoCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(36),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(36),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: onColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, size: 36, color: onColor),
              ),
              const SizedBox(height: 18),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: onColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
