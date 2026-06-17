import 'package:flutter/material.dart';

import '../config/design_tokens.dart';

class GlobiErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const GlobiErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: MinimalColors.accentRedBg,
        borderRadius: BorderRadius.circular(RadiusTokens.soft),
        border: Border.all(
          color: MinimalColors.accentRedText.withValues(alpha: 0.15),
          width: BorderTokens.thin,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: MinimalColors.accentRedText,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: MinimalColors.accentRedText,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: Spacing.sm),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: MinimalColors.accentRedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
