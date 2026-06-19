import 'package:flutter/material.dart';

class Spacing {
  Spacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Minimum recommended touch target size for accessibility (blind/low-vision)
  static const double minTapTarget = 48;
}

class RadiusTokens {
  RadiusTokens._();
  static const double sharp = 0;
  static const double crisp = 4;
  static const double soft = 8;
  static const double card = 12;
  static const double pill = 9999;
}

class BorderTokens {
  BorderTokens._();
  static const double thin = 1;
  static const Color light = Color(0xFFEAEAEA);
  static const Color dark = Color(0xFF2C2C2C);
}

class MinimalColors {
  MinimalColors._();

  // Warm monochrome canvas
  static const Color lightBg = Color(0xFFF7F6F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFF9F9F8);

  static const Color darkBg = Color(0xFF141414);
  static const Color darkSurface = Color(0xFF1C1C1C);
  static const Color darkSurfaceSecondary = Color(0xFF242424);

  // Text
  static const Color textPrimary = Color(0xFF2F3437);
  static const Color textSecondary = Color(0xFF787774);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Accent muted pastels
  static const Color accentRedBg = Color(0xFFFDEBEC);
  static const Color accentRedText = Color(0xFF9F2F2D);
  static const Color accentBlueBg = Color(0xFFE1F3FE);
  static const Color accentBlueText = Color(0xFF1F6C9F);
  static const Color accentGreenBg = Color(0xFFEDF3EC);
  static const Color accentGreenText = Color(0xFF346538);
  static const Color accentYellowBg = Color(0xFFFBF3DB);
  static const Color accentYellowText = Color(0xFF956400);
}
