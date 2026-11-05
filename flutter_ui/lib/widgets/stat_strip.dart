import 'package:flutter/material.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

class StatCellItem {
  final String label;
  final String value;
  final Color? valueColor;

  const StatCellItem({
    required this.label,
    required this.value,
    this.valueColor,
  });
}

class StatStripRow extends StatelessWidget {
  final List<StatCellItem> items;

  const StatStripRow({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: OmnispexColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: items
            .map(
              (item) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: OmnispexTypography.label.copyWith(
                      fontSize: 10,
                      color: OmnispexColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.value,
                    style: OmnispexTypography.monoData.copyWith(
                      color: item.valueColor ?? OmnispexColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
