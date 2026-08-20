import 'package:flutter/material.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

enum VerdictType {
  redIneffective,
  yellowChipContest,
  greenReliableKill,
}

class TacticalVerdictBadge extends StatelessWidget {
  final VerdictType verdict;
  final String? customLabel;

  const TacticalVerdictBadge({
    super.key,
    required this.verdict,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String defaultLabel;
    final IconData icon;

    switch (verdict) {
      case VerdictType.greenReliableKill:
        color = OmnispexColors.greenKill;
        defaultLabel = "RELIABLE KILL / HIGH VALUE";
        icon = Icons.check_circle_outline;
        break;
      case VerdictType.yellowChipContest:
        color = OmnispexColors.yellowContest;
        defaultLabel = "CHIP / CONTEST TARGET (HALF STRENGTH)";
        icon = Icons.warning_amber_outlined;
        break;
      case VerdictType.redIneffective:
        color = OmnispexColors.redIneffective;
        defaultLabel = "INEFFECTIVE TARGET (LOW DAMAGE)";
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.6), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TACTICAL VERDICT",
                  style: OmnispexTypography.label.copyWith(
                    color: color,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  customLabel ?? defaultLabel,
                  style: OmnispexTypography.h3.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
