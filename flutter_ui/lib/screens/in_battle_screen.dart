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

final selectedWeaponIndexProvider = StateProvider<int>((ref) => 0);
final isCustomWeaponModeProvider = StateProvider<bool>((ref) => false);
final customWeaponProfileProvider = StateProvider<WeaponUiProfile>((ref) => const WeaponUiProfile(
      name: "Custom Weapon",
      profileName: "Custom Profile",
      range: 24,
      attacks: "2",
      skill: 3,
      strength: 4,
      ap: 1,
      damage: "1",
      abilities: [],
    ));

final weaponCountProvider = StateProvider<int>((ref) => 1);
final selectedTargetIndexProvider = StateProvider<int>((ref) => 0);
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
    final isCustomWeapon = ref.watch(isCustomWeaponModeProvider);
    final customWeapon = ref.watch(customWeaponProfileProvider);
    final weaponCount = ref.watch(weaponCountProvider);
    final targetIdx = ref.watch(selectedTargetIndexProvider);
    final isStationary = ref.watch(isStationaryProvider);
    final hasCharged = ref.watch(hasChargedProvider);
    final targetInCover = ref.watch(targetInCoverProvider);
    final distance = ref.watch(combatDistanceProvider);

    final weapons = SimulationService.defaultWeapons;
    final targets = SimulationService.defaultTargets;

    final activeWeapon = isCustomWeapon ? customWeapon : weapons[weaponIdx % weapons.length];
    final activeTarget = targets[targetIdx % targets.length];

    final report = SimulationService.runSimulation(
      weapon: activeWeapon,
      target: activeTarget,
      isStationary: isStationary,
      hasCharged: hasCharged,
      targetInCover: targetInCover,
      weaponCount: weaponCount,
      distance: distance,
    );

    WeaponUiProfile? altWeapon;
    SimulationUiReport? altReport;
    if (!isCustomWeapon) {
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
          weaponCount: weaponCount,
          distance: distance,
        );
      }
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
                        isCustomWeapon,
                        customWeapon,
                        weaponCount,
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
                  isCustomWeapon,
                  customWeapon,
                  weaponCount,
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
    bool isCustomWeapon,
    WeaponUiProfile customWeapon,
    int weaponCount,
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
        // 1. Attacker Weapon Loadout & Quantity
        TacticalCard(
          title: "1. ATTACKER WEAPON LOADOUT",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                value: isCustomWeapon ? -1 : weaponIdx,
                isExpanded: true,
                dropdownColor: OmnispexColors.surfaceCard,
                decoration: const InputDecoration(labelText: "SELECT WEAPON PROFILE"),
                items: [
                  ...List.generate(weapons.length, (i) {
                    final w = weapons[i];
                    final typeTag = w.isMelee ? "⚔️ MELEE" : '🏹 RNG ${w.range}"';
                    return DropdownMenuItem(
                      value: i,
                      child: Text(
                        "${w.name} [${w.profileName}] ($typeTag)",
                        style: OmnispexTypography.monoData.copyWith(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  DropdownMenuItem(
                    value: -1,
                    child: Text(
                      "⚙️ Custom Weapon (Manual Input)...",
                      style: OmnispexTypography.monoData.copyWith(color: OmnispexColors.amber, fontSize: 13),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val == -1) {
                    ref.read(isCustomWeaponModeProvider.notifier).state = true;
                  } else if (val != null) {
                    ref.read(isCustomWeaponModeProvider.notifier).state = false;
                    ref.read(selectedWeaponIndexProvider.notifier).state = val;
                  }
                },
              ),
              const SizedBox(height: 12),

              // Weapon Quantity Selector
              Row(
                children: [
                  Text("WEAPON COUNT:", style: OmnispexTypography.label.copyWith(fontSize: 11)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [1, 3, 5, 10].map((count) {
                        final isSel = weaponCount == count;
                        return ChoiceChip(
                          label: Text(
                            "$count",
                            style: OmnispexTypography.monoStatBadge.copyWith(
                              color: isSel ? OmnispexColors.background : OmnispexColors.cyan,
                              fontSize: 11,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: OmnispexColors.cyan,
                          backgroundColor: OmnispexColors.surfaceElevated,
                          side: BorderSide(
                            color: isSel ? OmnispexColors.cyan : OmnispexColors.border,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              ref.read(weaponCountProvider.notifier).state = count;
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Custom Weapon Builder or Static Badges
              if (isCustomWeapon)
                _buildCustomWeaponEditor(context, ref, customWeapon)
              else ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatBadge(
                      label: activeWeapon.isMelee ? "TYPE" : "RNG",
                      value: activeWeapon.isMelee ? "MELEE" : '${activeWeapon.range}"',
                      accentColor: activeWeapon.isMelee ? OmnispexColors.amber : OmnispexColors.cyan,
                    ),
                    StatBadge(label: "A", value: activeWeapon.attacks),
                    StatBadge(label: "BS/WS", value: '${activeWeapon.skill}+'),
                    StatBadge(label: "S", value: '${activeWeapon.strength}'),
                    StatBadge(label: "AP", value: '-${activeWeapon.ap}'),
                    StatBadge(label: "D", value: activeWeapon.damage),
                  ],
                ),
                if (activeWeapon.abilities.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
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
            ],
          ),
        ),

        // 2. Defender Target Datasheet
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

        // 3. Combat Modifiers (Dynamic Ranged vs Melee Split)
        TacticalCard(
          title: activeWeapon.isMelee ? "3. MELEE COMBAT MODIFIERS" : "3. RANGED COMBAT MODIFIERS",
          child: Column(
            children: [
              if (activeWeapon.isMelee)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Attacker Made Charge Move (Lance +1)", style: OmnispexTypography.body),
                  value: hasCharged,
                  activeColor: OmnispexColors.cyan,
                  onChanged: (val) => ref.read(hasChargedProvider.notifier).state = val,
                )
              else ...[
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
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomWeaponEditor(
    BuildContext context,
    WidgetRef ref,
    WeaponUiProfile custom,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OmnispexColors.amber.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CUSTOM WEAPON ATTRIBUTES", style: OmnispexTypography.label.copyWith(color: OmnispexColors.amber)),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text("🏹 Ranged")),
                  ButtonSegment(value: true, label: Text("⚔️ Melee")),
                ],
                selected: {custom.isMelee},
                onSelectionChanged: (set) {
                  final isMelee = set.first;
                  ref.read(customWeaponProfileProvider.notifier).state = custom.copyWith(
                    range: isMelee ? 0 : 24,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: custom.attacks,
                  decoration: const InputDecoration(labelText: "Attacks (A)"),
                  onChanged: (val) => ref.read(customWeaponProfileProvider.notifier).state = custom.copyWith(attacks: val.trim()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: "${custom.skill}",
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Skill (BS/WS)"),
                  onChanged: (val) {
                    final n = int.tryParse(val);
                    if (n != null) ref.read(customWeaponProfileProvider.notifier).state = custom.copyWith(skill: n);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: "${custom.strength}",
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Strength (S)"),
                  onChanged: (val) {
                    final n = int.tryParse(val);
                    if (n != null) ref.read(customWeaponProfileProvider.notifier).state = custom.copyWith(strength: n);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: "${custom.ap}",
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Armor Pen (AP)"),
                  onChanged: (val) {
                    final n = int.tryParse(val);
                    if (n != null) ref.read(customWeaponProfileProvider.notifier).state = custom.copyWith(ap: n);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: custom.damage,
                  decoration: const InputDecoration(labelText: "Damage (D)"),
                  onChanged: (val) => ref.read(customWeaponProfileProvider.notifier).state = custom.copyWith(damage: val.trim()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text("KEYWORD ABILITIES", style: OmnispexTypography.label.copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (custom.isRanged) "Blast",
              "Lethal Hits",
              "Sustained Hits 1",
              "Devastating Wounds",
              "Twin-Linked",
              if (custom.isMelee) "Lance",
              if (custom.isRanged) "Rapid Fire 1",
              if (custom.isRanged) "Heavy",
              if (custom.isRanged) "Torrent",
              if (custom.isRanged) "Melta 2",
            ].map((kw) {
              final active = custom.abilities.contains(kw);
              return FilterChip(
                label: Text(kw, style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10)),
                selected: active,
                selectedColor: OmnispexColors.cyan.withOpacity(0.25),
                backgroundColor: OmnispexColors.surfaceCard,
                onSelected: (selected) {
                  final list = List<String>.from(custom.abilities);
                  if (selected) {
                    list.add(kw);
                  } else {
                    list.remove(kw);
                  }
                  ref.read(customWeaponProfileProvider.notifier).state = custom.copyWith(abilities: list);
                },
              );
            }).toList(),
          ),
        ],
      ),
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
        TacticalVerdictBadge(verdict: verdictType),
        const SizedBox(height: 12),
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
