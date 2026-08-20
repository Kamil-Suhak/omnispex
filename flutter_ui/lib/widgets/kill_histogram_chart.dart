import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

class KillHistogramChart extends StatelessWidget {
  final List<MapEntry<int, double>> distribution;
  final int safeBetFloor;
  final String title;
  final String unitLabel;
  final int? targetMaxHp;

  const KillHistogramChart({
    super.key,
    required this.distribution,
    required this.safeBetFloor,
    this.title = "KILL PROBABILITY DENSITY",
    this.unitLabel = "kills",
    this.targetMaxHp,
  });

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) return const SizedBox.shrink();

    final maxProb = distribution.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxY = (maxProb * 1.25).clamp(0.05, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(title, style: OmnispexTypography.label),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildLegendPill("Safe Bet (≥80%)", OmnispexColors.greenKill),
                _buildLegendPill("Distribution", OmnispexColors.cyan),
                if (targetMaxHp != null)
                  _buildLegendPill("Kill Zone (≥$targetMaxHp HP)", OmnispexColors.purple),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 190,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => OmnispexColors.surfaceElevated,
                  tooltipBorder: const BorderSide(color: OmnispexColors.cyan, width: 1),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final xVal = group.x;
                    final prob = (rod.toY * 100).toStringAsFixed(1);
                    final isKill = targetMaxHp != null && xVal >= targetMaxHp!;
                    return BarTooltipItem(
                      "$xVal $unitLabel${isKill ? ' (Kill)' : ''}\n$prob%",
                      OmnispexTypography.monoStatBadge.copyWith(
                        fontSize: 12,
                        color: isKill ? OmnispexColors.purple : OmnispexColors.textPrimary,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final intVal = value.toInt();
                      final isKill = targetMaxHp != null && intVal >= targetMaxHp!;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          "$intVal",
                          style: OmnispexTypography.monoStatBadge.copyWith(
                            fontSize: 10,
                            color: isKill
                                ? OmnispexColors.purple
                                : (intVal <= safeBetFloor && safeBetFloor > 0
                                    ? OmnispexColors.greenKill
                                    : OmnispexColors.textSecondary),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 0.1,
                    getTitlesWidget: (value, meta) {
                      final pct = (value * 100).toInt();
                      return Text(
                        "$pct%",
                        style: OmnispexTypography.monoStatBadge.copyWith(
                          fontSize: 9,
                          color: OmnispexColors.textMuted,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 0.1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: OmnispexColors.border.withOpacity(0.5),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: distribution.map((entry) {
                final isSafeBet = entry.key <= safeBetFloor && safeBetFloor > 0;
                final isKill = targetMaxHp != null && entry.key >= targetMaxHp!;

                final barColor = isKill
                    ? OmnispexColors.purple
                    : (isSafeBet ? OmnispexColors.greenKill : OmnispexColors.cyan);

                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value,
                      color: barColor,
                      width: distribution.length > 14 ? 6 : (distribution.length > 8 ? 10 : 14),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: OmnispexColors.surfaceElevated.withOpacity(0.3),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendPill(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: OmnispexTypography.bodyMuted.copyWith(fontSize: 10)),
      ],
    );
  }
}
