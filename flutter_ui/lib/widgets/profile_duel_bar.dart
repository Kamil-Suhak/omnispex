import 'package:flutter/material.dart';
import '../models/simulation_models.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

class ProfileDuelBar extends StatelessWidget {
  final List<WeaponUiProfile> profiles;
  final List<SimulationUiReport> reports;
  final int selectedIndex;
  final ValueChanged<int>? onSelectProfile;

  const ProfileDuelBar({
    super.key,
    required this.profiles,
    required this.reports,
    required this.selectedIndex,
    this.onSelectProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty || reports.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find best profile score
    int bestIndex = 0;
    double bestScore = -1;
    final scores = <double>[];

    for (int i = 0; i < reports.length; i++) {
      final rep = reports[i];
      final score = rep.expectedModelsKilled * 100 + rep.expectedDamageDealt;
      scores.add(score);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    // Find second best or comparison baseline to calculate delta
    double runnerUpScore = 0;
    for (int i = 0; i < scores.length; i++) {
      if (i != bestIndex && scores[i] > runnerUpScore) {
        runnerUpScore = scores[i];
      }
    }

    final double deltaPercent;
    if (runnerUpScore > 0 && bestScore > runnerUpScore) {
      deltaPercent = ((bestScore - runnerUpScore) / runnerUpScore) * 100;
    } else {
      deltaPercent = 0;
    }

    final winningProfile = profiles[bestIndex];

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
              Text(
                profiles.length == 2 ? "PROFILE DUEL COMPARISON" : "MULTI-PROFILE COMPARISON (${profiles.length} PROFILES)",
                style: OmnispexTypography.label,
              ),
              if (deltaPercent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: OmnispexColors.greenKill.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: OmnispexColors.greenKill.withOpacity(0.4)),
                  ),
                  child: Text(
                    "★ RECOMMEND: ${winningProfile.profileName.toUpperCase()} (+${deltaPercent.toStringAsFixed(0)}% OUTPUT)",
                    style: OmnispexTypography.monoStatBadge.copyWith(
                      color: OmnispexColors.greenKill,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Render Profiles in STABLE, FIXED order
          LayoutBuilder(
            builder: (context, constraints) {
              if (profiles.length <= 2) {
                return Row(
                  children: List.generate(profiles.length, (i) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < profiles.length - 1 ? 8 : 0),
                        child: _buildProfileCard(
                          profile: profiles[i],
                          report: reports[i],
                          isSelected: i == selectedIndex,
                          isWinner: i == bestIndex && deltaPercent > 0,
                          onTap: () => onSelectProfile?.call(i),
                        ),
                      ),
                    );
                  }),
                );
              }

              // 3 or more profiles: wrap or grid
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(profiles.length, (i) {
                  final cardWidth = (constraints.maxWidth - (profiles.length - 1) * 8) / profiles.length;
                  return SizedBox(
                    width: cardWidth.clamp(160.0, 320.0),
                    child: _buildProfileCard(
                      profile: profiles[i],
                      report: reports[i],
                      isSelected: i == selectedIndex,
                      isWinner: i == bestIndex && deltaPercent > 0,
                      onTap: () => onSelectProfile?.call(i),
                    ),
                  );
                }),
              );
            },
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
              ? OmnispexColors.cyan.withOpacity(0.14)
              : OmnispexColors.surfaceCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? OmnispexColors.cyan
                : (isWinner ? OmnispexColors.greenKill.withOpacity(0.6) : OmnispexColors.border),
            width: isSelected ? 1.8 : 1.0,
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
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: OmnispexColors.cyan,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      "ACTIVE",
                      style: OmnispexTypography.monoStatBadge.copyWith(
                        fontSize: 8,
                        color: OmnispexColors.background,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (isWinner)
                  const Icon(Icons.star, size: 14, color: OmnispexColors.greenKill),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "A:${profile.attacks} | S:${profile.strength} | AP:${profile.ap} | D:${profile.damage}",
              style: OmnispexTypography.monoStatBadge.copyWith(
                fontSize: 10,
                color: OmnispexColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (profile.abilities.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                profile.abilities.join(", "),
                style: OmnispexTypography.monoStatBadge.copyWith(
                  fontSize: 8,
                  color: OmnispexColors.amber,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 4,
              runSpacing: 2,
              children: [
                Text(
                  "Kills: ${report.expectedModelsKilled.toStringAsFixed(1)}",
                  style: OmnispexTypography.monoData.copyWith(
                    fontSize: 11,
                    color: isSelected ? OmnispexColors.cyan : OmnispexColors.textPrimary,
                  ),
                ),
                Text(
                  "Dmg: ${report.expectedDamageDealt.toStringAsFixed(1)}",
                  style: OmnispexTypography.monoData.copyWith(
                    fontSize: 11,
                    color: OmnispexColors.textSecondary,
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
