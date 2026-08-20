import 'package:flutter/material.dart';
import '../models/simulation_models.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

class ProfileDuelBar extends StatelessWidget {
  final WeaponUiProfile profileA;
  final SimulationUiReport reportA;
  final WeaponUiProfile profileB;
  final SimulationUiReport reportB;
  final VoidCallback? onSelectA;
  final VoidCallback? onSelectB;
  final bool isASelected;

  const ProfileDuelBar({
    super.key,
    required this.profileA,
    required this.reportA,
    required this.profileB,
    required this.reportB,
    this.onSelectA,
    this.onSelectB,
    required this.isASelected,
  });

  @override
  Widget build(BuildContext context) {
    final scoreA = reportA.expectedModelsKilled * 100 + reportA.expectedDamageDealt;
    final scoreB = reportB.expectedModelsKilled * 100 + reportB.expectedDamageDealt;
    final aIsBetter = scoreA >= scoreB;

    final double deltaPercent;
    if (aIsBetter && scoreB > 0) {
      deltaPercent = ((scoreA - scoreB) / scoreB) * 100;
    } else if (!aIsBetter && scoreA > 0) {
      deltaPercent = ((scoreB - scoreA) / scoreA) * 100;
    } else {
      deltaPercent = 0;
    }

    final winningProfileName = aIsBetter ? profileA.profileName : profileB.profileName;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OmnispexColors.borderBright),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text("PROFILE DUEL COMPARISON", style: OmnispexTypography.label),
              if (deltaPercent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: OmnispexColors.greenKill.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: OmnispexColors.greenKill.withOpacity(0.4)),
                  ),
                  child: Text(
                    "★ RECOMMEND: $winningProfileName (+${deltaPercent.toStringAsFixed(0)}% DELTA)",
                    style: OmnispexTypography.monoStatBadge.copyWith(
                      color: OmnispexColors.greenKill,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildProfileCard(
                  profile: profileA,
                  report: reportA,
                  isSelected: isASelected,
                  isWinner: aIsBetter,
                  onTap: onSelectA,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildProfileCard(
                  profile: profileB,
                  report: reportB,
                  isSelected: !isASelected,
                  isWinner: !aIsBetter,
                  onTap: onSelectB,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required WeaponUiProfile profile,
    required SimulationUiReport report,
    required bool isSelected,
    required bool isWinner,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? OmnispexColors.cyan.withOpacity(0.12)
              : OmnispexColors.surfaceCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? OmnispexColors.cyan
                : (isWinner ? OmnispexColors.greenKill.withOpacity(0.5) : OmnispexColors.border),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    profile.profileName,
                    style: OmnispexTypography.h3.copyWith(
                      fontSize: 13,
                      color: isSelected ? OmnispexColors.cyan : OmnispexColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isWinner)
                  const Icon(Icons.check_circle, size: 14, color: OmnispexColors.greenKill),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "A: ${profile.attacks} | S: ${profile.strength} | AP: ${profile.ap} | D: ${profile.damage}",
              style: OmnispexTypography.monoStatBadge.copyWith(
                fontSize: 10,
                color: OmnispexColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 4,
              runSpacing: 2,
              children: [
                Text(
                  "Kills: ${report.expectedModelsKilled.toStringAsFixed(1)}",
                  style: OmnispexTypography.monoData.copyWith(fontSize: 11),
                ),
                Text(
                  "Wipe: ${(report.wipeProbability * 100).toStringAsFixed(0)}%",
                  style: OmnispexTypography.monoData.copyWith(
                    fontSize: 11,
                    color: report.wipeProbability > 0.5 ? OmnispexColors.greenKill : OmnispexColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
