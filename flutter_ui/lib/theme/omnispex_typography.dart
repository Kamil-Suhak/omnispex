import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'omnispex_colors.dart';

/// Text styles are built once; GoogleFonts lookups are expensive and these
/// are referenced from every build method in the app.
class OmnispexTypography {
  static final TextStyle h1 = GoogleFonts.rajdhani(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: OmnispexColors.textPrimary,
    letterSpacing: 0.6,
  );

  static final TextStyle h2 = GoogleFonts.rajdhani(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: OmnispexColors.textPrimary,
    letterSpacing: 0.5,
  );

  static final TextStyle h3 = GoogleFonts.rajdhani(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: OmnispexColors.textPrimary,
    letterSpacing: 0.3,
  );

  static final TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: OmnispexColors.textPrimary,
  );

  static final TextStyle bodyMuted = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: OmnispexColors.textSecondary,
  );

  static final TextStyle label = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: OmnispexColors.textSecondary,
    letterSpacing: 0.8,
  );

  /// Numeric readouts (stat lines, points).
  static final TextStyle monoData = GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: OmnispexColors.textPrimary,
  );

  static final TextStyle monoDataLarge = GoogleFonts.jetBrainsMono(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: OmnispexColors.textPrimary,
  );

  static final TextStyle monoStatBadge = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: OmnispexColors.accent,
  );
}
