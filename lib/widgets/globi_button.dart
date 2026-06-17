import 'package:flutter/material.dart';



class GlobiButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback? onPressed;
  final bool isOutlined;

  const GlobiButton({
    super.key,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isDisabled = false,
    this.onPressed,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isDisabled || isLoading;
    final effectiveOnPressed = disabled ? null : onPressed;

    final Widget child = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    final Widget? iconWidget = (!isLoading && icon != null)
        ? Icon(icon, size: 18)
        : null;

    final button = iconWidget != null
        ? (isOutlined
            ? OutlinedButton.icon(
                onPressed: effectiveOnPressed,
                icon: iconWidget,
                label: child,
              )
            : FilledButton.icon(
                onPressed: effectiveOnPressed,
                icon: iconWidget,
                label: child,
              ))
        : (isOutlined
            ? OutlinedButton(
                onPressed: effectiveOnPressed,
                child: child,
              )
            : FilledButton(
                onPressed: effectiveOnPressed,
                child: child,
              ));

    return SizedBox(width: double.infinity, child: button);
  }
}
