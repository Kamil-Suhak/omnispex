import 'package:flutter/material.dart';
import 'omnispex_colors.dart';
import 'omnispex_typography.dart';

class OmnispexTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: OmnispexColors.background,
      colorScheme: const ColorScheme.dark(
        primary: OmnispexColors.cyan,
        secondary: OmnispexColors.amber,
        surface: OmnispexColors.surface,
        error: OmnispexColors.redIneffective,
        onPrimary: OmnispexColors.background,
        onSecondary: OmnispexColors.background,
        onSurface: OmnispexColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: OmnispexColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: OmnispexColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OmnispexColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OmnispexColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OmnispexColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OmnispexColors.cyan, width: 1.5),
        ),
        hintStyle: OmnispexTypography.bodyMuted,
        labelStyle: OmnispexTypography.label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: OmnispexColors.surface,
        indicatorColor: OmnispexColors.cyan.withOpacity(0.15),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return OmnispexTypography.label.copyWith(color: OmnispexColors.cyan);
          }
          return OmnispexTypography.label.copyWith(color: OmnispexColors.textMuted);
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: OmnispexColors.cyan, size: 22);
          }
          return const IconThemeData(color: OmnispexColors.textMuted, size: 20);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: OmnispexColors.surface,
        indicatorColor: OmnispexColors.cyan.withOpacity(0.15),
        selectedIconTheme: const IconThemeData(color: OmnispexColors.cyan, size: 24),
        unselectedIconTheme: const IconThemeData(color: OmnispexColors.textMuted, size: 22),
        selectedLabelTextStyle: OmnispexTypography.label.copyWith(color: OmnispexColors.cyan),
        unselectedLabelTextStyle: OmnispexTypography.label.copyWith(color: OmnispexColors.textMuted),
      ),
    );
  }
}
