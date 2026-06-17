import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

class AppTheme {
  static ThemeData lightTheme(ColorScheme colorScheme) {
    return _buildTheme(colorScheme, Brightness.light);
  }

  static ThemeData darkTheme(ColorScheme colorScheme) {
    return _buildTheme(colorScheme, Brightness.dark);
  }

  static ThemeData _buildTheme(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final surfaceColor = isDark ? MinimalColors.darkSurface : MinimalColors.lightSurface;
    final backgroundColor = isDark ? MinimalColors.darkBg : MinimalColors.lightBg;
    final borderColor = isDark ? BorderTokens.dark : BorderTokens.light;

    final customColorScheme = scheme.copyWith(
      surface: surfaceColor,
      surfaceContainerLow: surfaceColor,
      surfaceContainer: isDark ? MinimalColors.darkSurfaceSecondary : MinimalColors.lightSurfaceSecondary,
      surfaceContainerHigh: isDark ? MinimalColors.darkSurfaceSecondary : MinimalColors.lightSurfaceSecondary,
      surfaceContainerHighest: isDark ? MinimalColors.darkSurface : MinimalColors.lightSurfaceSecondary,
      surfaceTint: Colors.transparent,
      error: MinimalColors.accentRedText,
      errorContainer: MinimalColors.accentRedBg,
      onErrorContainer: MinimalColors.accentRedText,
      outline: borderColor,
      outlineVariant: borderColor,
    );

    final textTheme = GoogleFonts.outfitTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: customColorScheme,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? MinimalColors.textInverse : MinimalColors.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: isDark ? MinimalColors.textInverse : MinimalColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.card),
          side: BorderSide(color: borderColor, width: BorderTokens.thin),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isDark ? Colors.white : const Color(0xFF111111),
          foregroundColor: isDark ? const Color(0xFF111111) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.crisp),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? Colors.white : const Color(0xFF111111),
          foregroundColor: isDark ? const Color(0xFF111111) : Colors.white,
          disabledBackgroundColor: borderColor,
          disabledForegroundColor: MinimalColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.crisp),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: isDark ? MinimalColors.textInverse : MinimalColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.crisp),
            side: BorderSide(color: borderColor, width: BorderTokens.thin),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          foregroundColor: isDark ? MinimalColors.textInverse : MinimalColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.crisp),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? MinimalColors.darkSurfaceSecondary : MinimalColors.lightSurfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.soft),
          borderSide: BorderSide(color: borderColor, width: BorderTokens.thin),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.soft),
          borderSide: BorderSide(color: borderColor, width: BorderTokens.thin),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.soft),
          borderSide: BorderSide(color: customColorScheme.primary, width: BorderTokens.thin * 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.soft),
          borderSide: BorderSide(color: MinimalColors.accentRedText, width: BorderTokens.thin),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.soft),
          borderSide: BorderSide(color: MinimalColors.accentRedText, width: BorderTokens.thin * 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: MinimalColors.textSecondary,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: MinimalColors.textSecondary.withValues(alpha: 0.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.card),
          side: BorderSide(color: borderColor, width: BorderTokens.thin),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(RadiusTokens.card)),
          side: BorderSide(color: borderColor, width: BorderTokens.thin),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: customColorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: BorderTokens.thin,
        space: Spacing.lg,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFF111111),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.soft),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
