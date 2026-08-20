import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'omnispex_colors.dart';

class OmnispexTypography {
  // Headings
  static TextStyle get h1 => GoogleFonts.rajdhani(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: OmnispexColors.textPrimary,
        letterSpacing: 1.2,
      );

  static TextStyle get h2 => GoogleFonts.rajdhani(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: OmnispexColors.textPrimary,
        letterSpacing: 1.0,
      );

  static TextStyle get h3 => GoogleFonts.rajdhani(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: OmnispexColors.textPrimary,
        letterSpacing: 0.8,
      );

  // Body & Labels
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: OmnispexColors.textPrimary,
      );

  static TextStyle get bodyMuted => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: OmnispexColors.textSecondary,
      );

  static TextStyle get label => GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: OmnispexColors.textSecondary,
        letterSpacing: 1.5,
      );

  // Tactical Monospace Data Readouts
  static TextStyle get monoData => GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: OmnispexColors.textPrimary,
      );

  static TextStyle get monoDataLarge => GoogleFonts.jetBrainsMono(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: OmnispexColors.textPrimary,
      );

  static TextStyle get monoStatBadge => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: OmnispexColors.cyan,
      );
}
