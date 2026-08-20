import 'package:flutter/material.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

class StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color? accentColor;

  const StatBadge({
    super.key,
    required this.label,
    required this.value,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? OmnispexColors.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label ",
            style: OmnispexTypography.monoStatBadge.copyWith(
              color: OmnispexColors.textSecondary,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: OmnispexTypography.monoStatBadge.copyWith(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
