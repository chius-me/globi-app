import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData lightTheme(ColorScheme colorScheme) {
    return _buildTheme(colorScheme, Brightness.light);
  }

  static ThemeData darkTheme(ColorScheme colorScheme) {
    return _buildTheme(colorScheme, Brightness.dark);
  }

  static ThemeData _buildTheme(ColorScheme scheme, Brightness brightness) {     
    final isDark = brightness == Brightness.dark;

    // Premium Layer Separation
    // Ensuring distinct colors between background (underneath) and surface (cards/sheets) without bleed
    final surfaceColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFFFFFF);
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF8F9FA);
    final surfaceContainerHighestColor = isDark
        ? const Color(0xFF2C2C2C)
        : const Color(0xFFEEF2F6);

    final customColorScheme = scheme.copyWith(
      surface: backgroundColor, // Use surface as background due to deprecation of background
      surfaceContainerHighest: surfaceContainerHighestColor,
    );

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: customColorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: backgroundColor,
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        surfaceTintColor:
            Colors.transparent, // Disable surface tint to prevent color bleed  
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: isDark
              ? BorderSide(color: Colors.white.withAlpha(12), width: 1)     
              : BorderSide(color: Colors.black.withAlpha(12), width: 1),    
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),        
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),    
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),    
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),    
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: customColorScheme.outline.withAlpha(127)),  
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),    
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHighestColor.withAlpha(127),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: customColorScheme.primary, width: 2),   
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: customColorScheme.error, width: 2),     
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), 
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),        
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: customColorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
