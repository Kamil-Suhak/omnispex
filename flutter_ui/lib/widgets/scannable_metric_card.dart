import 'package:flutter/material.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

class ScannableMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? accentColor;
  final IconData? icon;

  const ScannableMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.accentColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? OmnispexColors.cyan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: OmnispexTypography.label.copyWith(
                    color: OmnispexColors.textSecondary,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 14, color: color),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: OmnispexTypography.monoDataLarge.copyWith(
              color: color,
              fontSize: 22,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: OmnispexTypography.bodyMuted.copyWith(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
