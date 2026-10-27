import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'omnispex_colors.dart';
import 'omnispex_typography.dart';

/// Layout, shape and motion constants shared by every screen.
class OmnispexLayout {
  static const double contentMaxWidth = 1680;
  static const double wideBreakpoint = 1000;
  static const double radius = 8;
  static const double pagePadding = 20;
  static const double gap = 12;
}

/// Consistent, jank-free scrolling across touch, mouse and trackpad.
class OmnispexScrollBehavior extends MaterialScrollBehavior {
  const OmnispexScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

class OmnispexTheme {
  static final ThemeData darkTheme = _build();

  static ThemeData _build() {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(OmnispexLayout.radius),
    );
    const compactPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    final buttonText = OmnispexTypography.body.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: OmnispexColors.background,
      splashFactory: NoSplash.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: OmnispexColors.accent,
        secondary: OmnispexColors.amber,
        surface: OmnispexColors.surface,
        error: OmnispexColors.redIneffective,
        onPrimary: OmnispexColors.onAccent,
        onSecondary: OmnispexColors.onAccent,
        onSurface: OmnispexColors.textPrimary,
        outline: OmnispexColors.border,
      ),
      dividerTheme: const DividerThemeData(
        color: OmnispexColors.border,
        space: 1,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: OmnispexColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: OmnispexColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: OmnispexColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: OmnispexColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OmnispexColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OmnispexLayout.radius),
          borderSide: const BorderSide(color: OmnispexColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OmnispexLayout.radius),
          borderSide: const BorderSide(color: OmnispexColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OmnispexLayout.radius),
          borderSide:
              const BorderSide(color: OmnispexColors.accent, width: 1.5),
        ),
        hintStyle: OmnispexTypography.bodyMuted,
        labelStyle: OmnispexTypography.label,
        floatingLabelStyle:
            OmnispexTypography.label.copyWith(color: OmnispexColors.accent),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: OmnispexColors.accent,
          foregroundColor: OmnispexColors.onAccent,
          elevation: 0,
          shape: shape,
          padding: compactPadding,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: OmnispexColors.accent,
          foregroundColor: OmnispexColors.onAccent,
          shape: shape,
          padding: compactPadding,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: OmnispexColors.textPrimary,
          side: const BorderSide(color: OmnispexColors.borderBright),
          shape: shape,
          padding: compactPadding,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: OmnispexColors.accent,
          shape: shape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: OmnispexColors.textSecondary,
          hoverColor: OmnispexColors.surfaceElevated,
          highlightColor: OmnispexColors.surfaceElevated,
          shape: shape,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: OmnispexColors.surfaceElevated,
        selectedColor: OmnispexColors.accent.withValues(alpha: 0.22),
        disabledColor: OmnispexColors.surface,
        side: const BorderSide(color: OmnispexColors.border),
        shape: shape,
        showCheckmark: false,
        labelStyle: OmnispexTypography.body.copyWith(fontSize: 12),
        secondaryLabelStyle: OmnispexTypography.body.copyWith(
          fontSize: 12,
          color: OmnispexColors.textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: OmnispexColors.textSecondary,
          size: 16,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: OmnispexColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: OmnispexColors.border),
        ),
        textStyle: OmnispexTypography.body.copyWith(fontSize: 12),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          OmnispexColors.borderBright.withValues(alpha: 0.8),
        ),
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(6),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      }),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: OmnispexColors.surface,
        indicatorColor: OmnispexColors.accent.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return OmnispexTypography.label.copyWith(
            color: selected
                ? OmnispexColors.textPrimary
                : OmnispexColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? OmnispexColors.accent
                : OmnispexColors.textSecondary,
            size: 22,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: OmnispexColors.surface,
        indicatorColor: OmnispexColors.accent.withValues(alpha: 0.16),
        selectedIconTheme:
            const IconThemeData(color: OmnispexColors.accent, size: 24),
        unselectedIconTheme:
            const IconThemeData(color: OmnispexColors.textSecondary, size: 22),
        selectedLabelTextStyle:
            OmnispexTypography.label.copyWith(color: OmnispexColors.textPrimary),
        unselectedLabelTextStyle: OmnispexTypography.label,
      ),
    );
  }
}
