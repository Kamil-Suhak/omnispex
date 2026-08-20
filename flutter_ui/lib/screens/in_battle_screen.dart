import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/simulation_models.dart';
import '../providers/app_state_provider.dart';
import '../services/simulation_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/kill_histogram_chart.dart';
import '../widgets/profile_duel_bar.dart';
import '../widgets/scannable_metric_card.dart';
import '../widgets/stat_badge.dart';
import '../widgets/tactical_card.dart';
import '../widgets/tactical_verdict_badge.dart';

final selectedWeaponIndexProvider = StateProvider<int>((ref) => 0); // Default to Frag
final selectedTargetIndexProvider = StateProvider<int>((ref) => 0); // Default to Ork Boyz
final isStationaryProvider = StateProvider<bool>((ref) => true);
final hasChargedProvider = StateProvider<bool>((ref) => false);
final targetInCoverProvider = StateProvider<bool>((ref) => false);
final combatDistanceProvider = StateProvider<int>((ref) => 12);

class InBattleScreen extends ConsumerWidget {
  const InBattleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeepAnalytics = ref.watch(isDeepAnalyticsModeProvider);
    final weaponIdx = ref.watch(selectedWeaponIndexProvider);
    final targetIdx = ref.watch(selectedTargetIndexProvider);
    final isStationary = ref.watch(isStationaryProvider);
    final hasCharged = ref.watch(hasChargedProvider);
    final targetInCover = ref.watch(targetInCoverProvider);
    final distance = ref.watch(combatDistanceProvider);

    final weapons = SimulationService.defaultWeapons;
    final targets = SimulationService.defaultTargets;

    final activeWeapon = weapons[weaponIdx % weapons.length];
    final activeTarget = targets[targetIdx % targets.length];

    final report = SimulationService.runSimulation(
      weapon: activeWeapon,
      target: activeTarget,
      isStationary: isStationary,
      hasCharged: hasCharged,
      targetInCover: targetInCover,
      distance: distance,
    );

    // If active weapon is Frag (idx 0), compare with Krak (idx 1).
    // If active is Plasma Standard (idx 2), compare with Supercharge (idx 3).
    WeaponUiProfile? altWeapon;
    SimulationUiReport? altReport;
    if (weaponIdx == 0) {
      altWeapon = weapons[1];
    } else if (weaponIdx == 1) {
      altWeapon = weapons[0];
    } else if (weaponIdx == 2) {
      altWeapon = weapons[3];
    } else if (weaponIdx == 3) {
      altWeapon = weapons[2];
    }

    if (altWeapon != null) {
      altReport = SimulationService.runSimulation(
        weapon: altWeapon,
        target: activeTarget,
        isStationary: isStationary,
        hasCharged: hasCharged,
        targetInCover: targetInCover,
        distance: distance,
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildControlsColumn(
                        context,
                        ref,
                        weapons,
                        targets,
                        weaponIdx,
                        targetIdx,
                        isStationary,
                        hasCharged,
                        targetInCover,
                        distance,
                        activeWeapon,
                        activeTarget,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 7,
                      child: _buildResultsColumn(
                        report,
                        activeWeapon,
                        altWeapon,
                        altReport,
                        weaponIdx,
                        isDeepAnalytics,
                        ref,
                      ),
                    ),
                  ],
                )
              else ...[
                _buildControlsColumn(
                  context,
                  ref,
                  weapons,
                  targets,
                  weaponIdx,
                  targetIdx,
                  isStationary,
                  hasCharged,
                  targetInCover,
                  distance,
                  activeWeapon,
                  activeTarget,
                ),
                const SizedBox(height: 16),
                _buildResultsColumn(
                  report,
                  activeWeapon,
                  altWeapon,
                  altReport,
                  weaponIdx,
                  isDeepAnalytics,
                  ref,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsColumn(
    BuildContext context,
    WidgetRef ref,
    List<WeaponUiProfile> weapons,
    List<UnitUiProfile> targets,
    int weaponIdx,
    int targetIdx,
    bool isStationary,
    bool hasCharged,
    bool targetInCover,
    int distance,
    WeaponUiProfile activeWeapon,
    UnitUiProfile activeTarget,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TacticalCard(
          title: "1. ATTACKER WEAPON LOADOUT",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                value: weaponIdx,
                isExpanded: true,
                dropdownColor: OmnispexColors.surfaceCard,
                decoration: const InputDecoration(labelText: "SELECT WEAPON PROFILE"),
                items: List.generate(weapons.length, (i) {
                  final w = weapons[i];
                  return DropdownMenuItem(
                    value: i,
                    child: Text("${w.name} [${w.profileName}]", style: OmnispexTypography.monoData),
                  );
                }),
                onChanged: (val) {
                  if (val != null) ref.read(selectedWeaponIndexProvider.notifier).state = val;
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatBadge(label: "RNG", value: '${activeWeapon.range}"'),
                  StatBadge(label: "A", value: activeWeapon.attacks),
                  StatBadge(label: "BS", value: '${activeWeapon.skill}+'),
                  StatBadge(label: "S", value: '${activeWeapon.strength}'),
                  StatBadge(label: "AP", value: '-${activeWeapon.ap}'),
                  StatBadge(label: "D", value: activeWeapon.damage),
                ],
              ),
              if (activeWeapon.abilities.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: activeWeapon.abilities.map((ab) {
                    return Chip(
                      label: Text(ab, style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10)),
                      backgroundColor: OmnispexColors.surfaceElevated,
                      side: const BorderSide(color: OmnispexColors.border),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        TacticalCard(
          title: "2. DEFENDER TARGET DATASHEET",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                value: targetIdx,
                isExpanded: true,
                dropdownColor: OmnispexColors.surfaceCard,
                decoration: const InputDecoration(labelText: "SELECT TARGET UNIT"),
                items: List.generate(targets.length, (i) {
                  final t = targets[i];
                  return DropdownMenuItem(
                    value: i,
                    child: Text(t.name, style: OmnispexTypography.monoData),
                  );
                }),
                onChanged: (val) {
                  if (val != null) ref.read(selectedTargetIndexProvider.notifier).state = val;
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatBadge(label: "MODELS", value: '${activeTarget.modelCount}'),
                  StatBadge(label: "T", value: '${activeTarget.toughness}'),
                  StatBadge(label: "SV", value: '${activeTarget.save}+'),
                  if (activeTarget.invuln != null)
                    StatBadge(
                      label: "INV",
                      value: '${activeTarget.invuln}+',
                      accentColor: OmnispexColors.amber,
                    ),
                  StatBadge(label: "W/MODEL", value: '${activeTarget.woundsPerModel}'),
                  StatBadge(
                    label: "TOTAL HP",
                    value: '${activeTarget.totalWounds}',
                    accentColor: OmnispexColors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
        TacticalCard(
          title: "3. COMBAT MODIFIERS",
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Target Has Benefit of Cover", style: OmnispexTypography.body),
                value: targetInCover,
                activeColor: OmnispexColors.cyan,
                onChanged: (val) => ref.read(targetInCoverProvider.notifier).state = val,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Attacker Stationary (Heavy +1)", style: OmnispexTypography.body),
                value: isStationary,
                activeColor: OmnispexColors.cyan,
                onChanged: (val) => ref.read(isStationaryProvider.notifier).state = val,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Attacker Made Charge Move (Lance +1)", style: OmnispexTypography.body),
                value: hasCharged,
                activeColor: OmnispexColors.cyan,
                onChanged: (val) => ref.read(hasChargedProvider.notifier).state = val,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsColumn(
    SimulationUiReport report,
    WeaponUiProfile activeWeapon,
    WeaponUiProfile? altWeapon,
    SimulationUiReport? altReport,
    int weaponIdx,
    bool isDeepAnalytics,
    WidgetRef ref,
  ) {
    final verdictType = switch (report.tacticalVerdict) {
      TacticalVerdictUi.greenReliableKill => VerdictType.greenReliableKill,
      TacticalVerdictUi.yellowChipContest => VerdictType.yellowChipContest,
      TacticalVerdictUi.redIneffective => VerdictType.redIneffective,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hero Verdict Badge
        TacticalVerdictBadge(verdict: verdictType),
        const SizedBox(height: 12),

        // 2. The 3 Core Numbers
        Row(
          children: [
            Expanded(
              child: ScannableMetricCard(
                label: "Expected Kills",
                value: report.expectedModelsKilled.toStringAsFixed(1),
                subtitle: "± ${report.stdDevKills.toStringAsFixed(1)} StdDev",
                accentColor: OmnispexColors.cyan,
                icon: Icons.track_changes,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ScannableMetricCard(
                label: "Safe Bet (≥80%)",
                value: "${report.safeBetKills80}",
                subtitle: "80% Confidence Floor",
                accentColor: OmnispexColors.greenKill,
                icon: Icons.shield,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ScannableMetricCard(
                label: "Wipe Chance",
                value: "${(report.wipeProbability * 100).toStringAsFixed(0)}%",
                subtitle: "100% Casualty Odds",
                accentColor: report.wipeProbability >= 0.75
                    ? OmnispexColors.greenKill
                    : (report.wipeProbability >= 0.25 ? OmnispexColors.yellowContest : OmnispexColors.redIneffective),
                icon: Icons.dangerous,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 3. Profile Duel Comparison Mini-Bar
        if (altWeapon != null && altReport != null) ...[
          ProfileDuelBar(
            profileA: activeWeapon,
            reportA: report,
            profileB: altWeapon,
            reportB: altReport,
            isASelected: true,
            onSelectA: () {},
            onSelectB: () {
              final targetAltIdx = SimulationService.defaultWeapons.indexOf(altWeapon!);
              if (targetAltIdx != -1) {
                ref.read(selectedWeaponIndexProvider.notifier).state = targetAltIdx;
              }
            },
          ),
          const SizedBox(height: 12),
        ],

        // 4. Deep Analytics View (Conditional)
        if (isDeepAnalytics) ...[
          TacticalCard(
            title: "DEEP ANALYTICS: CASUALTY HISTOGRAM",
            child: KillHistogramChart(
              distribution: report.killDistribution,
              safeBetFloor: report.safeBetKills80,
              expectedKills: report.expectedModelsKilled,
            ),
          ),
          TacticalCard(
            title: "PERCENTILE DISTRIBUTION & OVERKILL LOSS",
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPercentilePill("p10", "${report.percentiles.p10}"),
                    _buildPercentilePill("p25", "${report.percentiles.p25}"),
                    _buildPercentilePill("p50 (Median)", "${report.percentiles.p50}", isMedian: true),
                    _buildPercentilePill("p75", "${report.percentiles.p75}"),
                    _buildPercentilePill("p90", "${report.percentiles.p90}"),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: OmnispexColors.border, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Raw Damage Generated:", style: OmnispexTypography.bodyMuted),
                    Text("${report.rawDamageGenerated.toStringAsFixed(1)} dmg", style: OmnispexTypography.monoData),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Effective Damage Applied:", style: OmnispexTypography.bodyMuted),
                    Text("${report.expectedDamageDealt.toStringAsFixed(1)} dmg", style: OmnispexTypography.monoData),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Overkill Loss to Model Truncation:", style: OmnispexTypography.bodyMuted),
                    Text(
                      "${report.spilloverDamageLost.toStringAsFixed(1)} dmg",
                      style: OmnispexTypography.monoData.copyWith(color: OmnispexColors.amber),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (report.keywordAudit.lethalDamage > 0 ||
              report.keywordAudit.sustainedDamage > 0 ||
              report.keywordAudit.devastatingDamage > 0)
            TacticalCard(
              title: "KEYWORD DAMAGE AUDIT",
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Lethal Hits Contribution:", style: OmnispexTypography.bodyMuted),
                      Text("${report.keywordAudit.lethalDamage.toStringAsFixed(1)} dmg", style: OmnispexTypography.monoData),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Sustained Hits Contribution:", style: OmnispexTypography.bodyMuted),
                      Text("${report.keywordAudit.sustainedDamage.toStringAsFixed(1)} dmg", style: OmnispexTypography.monoData),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Devastating Wounds Contribution:", style: OmnispexTypography.bodyMuted),
                      Text("${report.keywordAudit.devastatingDamage.toStringAsFixed(1)} dmg", style: OmnispexTypography.monoData),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPercentilePill(String label, String value, {bool isMedian = false}) {
    return Column(
      children: [
        Text(
          label,
          style: OmnispexTypography.label.copyWith(
            fontSize: 10,
            color: isMedian ? OmnispexColors.cyan : OmnispexColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isMedian ? OmnispexColors.cyan.withOpacity(0.15) : OmnispexColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isMedian ? OmnispexColors.cyan : OmnispexColors.border,
            ),
          ),
          child: Text(
            "$value kills",
            style: OmnispexTypography.monoData.copyWith(
              fontSize: 12,
              color: isMedian ? OmnispexColors.cyan : OmnispexColors.textPrimary,
              fontWeight: isMedian ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
