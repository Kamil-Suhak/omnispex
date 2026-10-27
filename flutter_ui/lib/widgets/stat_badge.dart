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
    final color = accentColor ?? OmnispexColors.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "$label ",
                style: OmnispexTypography.label.copyWith(fontSize: 11),
              ),
              TextSpan(
                text: value,
                style: OmnispexTypography.monoStatBadge.copyWith(color: color),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
