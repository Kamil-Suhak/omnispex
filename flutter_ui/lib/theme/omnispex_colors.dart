import 'package:flutter/material.dart';

class OmnispexColors {
  // Backgrounds & Surface
  static const Color background = Color(0xFF0F1115);
  static const Color surface = Color(0xFF16191F);
  static const Color surfaceCard = Color(0xFF1C2028);
  static const Color surfaceElevated = Color(0xFF242933);
  static const Color border = Color(0xFF2E3440);
  static const Color borderBright = Color(0xFF3D4452);

  // Accents (muted; used sparingly)
  static const Color accent = Color(0xFF7FA6CB);
  static const Color accentMuted = Color(0xFF55778F);
  static const Color amber = Color(0xFFD9A441);
  static const Color amberMuted = Color(0xFF9C7A33);
  static const Color purple = Color(0xFFA594D6);

  // Traffic Light System
  static const Color greenKill = Color(0xFF63BF8C);
  static const Color yellowContest = Color(0xFFD8B84A);
  static const Color redIneffective = Color(0xFFE0736A);

  // Text (all >= WCAG AA against surfaceCard)
  static const Color textPrimary = Color(0xFFE8EBF0);
  static const Color textSecondary = Color(0xFFB0B8C5);
  static const Color textMuted = Color(0xFF909AAA);

  /// Foreground for content placed on a solid [accent] fill.
  static const Color onAccent = Color(0xFF0F1115);
}
