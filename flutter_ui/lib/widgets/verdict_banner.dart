import 'package:flutter/material.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

class TacticalVerdictBanner extends StatelessWidget {
  final String verdictKey;
  final String primaryMetricLabel;
  final String primaryMetricValue;
  final String secondaryMetricLabel;
  final String secondaryMetricValue;

  const TacticalVerdictBanner({
    super.key,
    required this.verdictKey,
    required this.primaryMetricLabel,
    required this.primaryMetricValue,
    required this.secondaryMetricLabel,
    required this.secondaryMetricValue,
  });

  Color get _statusColor {
    final lower = verdictKey.toLowerCase();
    if (lower.contains('green')) return OmnispexColors.greenKill;
    if (lower.contains('amber') || lower.contains('yellow')) {
      return OmnispexColors.yellowContest;
    }
    return OmnispexColors.redIneffective;
  }

  String get _statusTitle {
    final lower = verdictKey.toLowerCase();
    if (lower.contains('green')) return 'RELIABLE ELIMINATION';
    if (lower.contains('amber') || lower.contains('yellow')) {
      return 'CONTESTED / CHIP THREAT';
    }
    return 'LOW EFFICIENCY / BOUNCE RISK';
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: const BorderSide(color: OmnispexColors.border),
          right: const BorderSide(color: OmnispexColors.border),
          bottom: const BorderSide(color: OmnispexColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusTitle,
                  style: OmnispexTypography.h3.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  '$primaryMetricLabel: $primaryMetricValue  •  $secondaryMetricLabel: $secondaryMetricValue',
                  style: OmnispexTypography.bodyMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
