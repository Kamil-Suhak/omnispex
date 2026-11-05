import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

class ProbabilityDistributionChart extends StatelessWidget {
  final String title;
  final List<MapEntry<int, double>> distribution;
  final int highlightThreshold;

  const ProbabilityDistributionChart({
    super.key,
    required this.title,
    required this.distribution,
    this.highlightThreshold = 0,
  });

  @override
  Widget build(BuildContext context) {
    final visible = distribution
        .where((e) => e.value >= 0.005 || e.key <= 12)
        .take(18)
        .toList();
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    double maxProb = 0.1;
    for (final e in visible) {
      if (e.value > maxProb) maxProb = e.value;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: OmnispexTypography.label),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: (maxProb * 1.2).clamp(0.1, 1.0),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: OmnispexColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, _) => Text(
                        '${(val * 100).round()}%',
                        style: OmnispexTypography.label.copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${val.toInt()}',
                          style:
                              OmnispexTypography.monoData.copyWith(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: visible
                    .map(
                      (entry) => BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                            color: highlightThreshold > 0 &&
                                    entry.key >= highlightThreshold
                                ? OmnispexColors.greenKill
                                : OmnispexColors.accent,
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
