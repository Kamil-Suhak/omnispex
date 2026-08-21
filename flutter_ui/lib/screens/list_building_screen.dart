import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/simulation_models.dart';
import '../services/simulation_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/scannable_metric_card.dart';
import '../widgets/stat_badge.dart';
import '../widgets/tactical_card.dart';
import '../widgets/tactical_verdict_badge.dart';

final benchWeaponIndexAProvider = StateProvider<int>((ref) => 0);
final benchWeaponCountAProvider = StateProvider<int>((ref) => 1);
final benchPointsAProvider = StateProvider<int>((ref) => 100);

final benchIsDualCompareProvider = StateProvider<bool>((ref) => false);
final benchWeaponIndexBProvider = StateProvider<int>((ref) => 1);
final benchWeaponCountBProvider = StateProvider<int>((ref) => 1);
final benchPointsBProvider = StateProvider<int>((ref) => 100);

final benchIsStationaryProvider = StateProvider<bool>((ref) => true);
final benchHasChargedProvider = StateProvider<bool>((ref) => false);
final benchTargetInCoverProvider = StateProvider<bool>((ref) => false);

class ListBuildingScreen extends ConsumerWidget {
  const ListBuildingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weaponIdxA = ref.watch(benchWeaponIndexAProvider);
    final countA = ref.watch(benchWeaponCountAProvider);
    final pointsA = ref.watch(benchPointsAProvider);

    final isDualCompare = ref.watch(benchIsDualCompareProvider);
    final weaponIdxB = ref.watch(benchWeaponIndexBProvider);
    final countB = ref.watch(benchWeaponCountBProvider);
    final pointsB = ref.watch(benchPointsBProvider);

    final isStationary = ref.watch(benchIsStationaryProvider);
    final hasCharged = ref.watch(benchHasChargedProvider);
    final targetInCover = ref.watch(benchTargetInCoverProvider);

    final weapons = SimulationService.defaultWeapons;
    final activeWeaponA = weapons[weaponIdxA % weapons.length];
    final activeWeaponB = weapons[weaponIdxB % weapons.length];

    final loadoutA = [WeaponLoadoutEntry(weapon: activeWeaponA, count: countA)];
    final loadoutB = isDualCompare
        ? [WeaponLoadoutEntry(weapon: activeWeaponB, count: countB)]
        : null;

    final benchmarkReport = SimulationService.evaluateArchetypesBenchmark(
      loadoutA: loadoutA,
      pointsA: pointsA,
      loadoutB: loadoutB,
      pointsB: pointsB,
      isStationary: isStationary,
      hasCharged: hasCharged,
      targetInCover: targetInCover,
    );

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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("LIST-BUILDING BENCHMARK",
                          style: OmnispexTypography.h2),
                      Text("Cross-Archetype Efficiency & Weapon Optimization",
                          style: OmnispexTypography.bodyMuted),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 14),
                    label: Text("RESET DEFAULTS",
                        style: OmnispexTypography.monoStatBadge
                            .copyWith(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OmnispexColors.textSecondary,
                      side: const BorderSide(color: OmnispexColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _resetDefaults(ref),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Configuration Card
              TacticalCard(
                title: "LOADOUT BENCHMARK CONFIGURATION",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildProfileSelector(
                              context,
                              ref,
                              title: "PROFILE A (BASELINE)",
                              color: OmnispexColors.cyan,
                              weapons: weapons,
                              weaponIdx: weaponIdxA,
                              count: countA,
                              points: pointsA,
                              onWeaponChanged: (val) => ref
                                  .read(benchWeaponIndexAProvider.notifier)
                                  .state = val,
                              onCountChanged: (val) => ref
                                  .read(benchWeaponCountAProvider.notifier)
                                  .state = val,
                              onPointsChanged: (val) => ref
                                  .read(benchPointsAProvider.notifier)
                                  .state = val,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: isDualCompare
                                ? _buildProfileSelector(
                                    context,
                                    ref,
                                    title: "PROFILE B (COMPARISON)",
                                    color: OmnispexColors.amber,
                                    weapons: weapons,
                                    weaponIdx: weaponIdxB,
                                    count: countB,
                                    points: pointsB,
                                    onWeaponChanged: (val) => ref
                                        .read(
                                            benchWeaponIndexBProvider.notifier)
                                        .state = val,
                                    onCountChanged: (val) => ref
                                        .read(
                                            benchWeaponCountBProvider.notifier)
                                        .state = val,
                                    onPointsChanged: (val) => ref
                                        .read(benchPointsBProvider.notifier)
                                        .state = val,
                                  )
                                : _buildDualComparePrompt(ref),
                          ),
                        ],
                      )
                    else ...[
                      _buildProfileSelector(
                        context,
                        ref,
                        title: "PROFILE A (BASELINE)",
                        color: OmnispexColors.cyan,
                        weapons: weapons,
                        weaponIdx: weaponIdxA,
                        count: countA,
                        points: pointsA,
                        onWeaponChanged: (val) => ref
                            .read(benchWeaponIndexAProvider.notifier)
                            .state = val,
                        onCountChanged: (val) => ref
                            .read(benchWeaponCountAProvider.notifier)
                            .state = val,
                        onPointsChanged: (val) =>
                            ref.read(benchPointsAProvider.notifier).state = val,
                      ),
                      const SizedBox(height: 12),
                      if (isDualCompare)
                        _buildProfileSelector(
                          context,
                          ref,
                          title: "PROFILE B (COMPARISON)",
                          color: OmnispexColors.amber,
                          weapons: weapons,
                          weaponIdx: weaponIdxB,
                          count: countB,
                          points: pointsB,
                          onWeaponChanged: (val) => ref
                              .read(benchWeaponIndexBProvider.notifier)
                              .state = val,
                          onCountChanged: (val) => ref
                              .read(benchWeaponCountBProvider.notifier)
                              .state = val,
                          onPointsChanged: (val) => ref
                              .read(benchPointsBProvider.notifier)
                              .state = val,
                        )
                      else
                        _buildDualComparePrompt(ref),
                    ],

                    const SizedBox(height: 12),
                    const Divider(color: OmnispexColors.border, height: 1),
                    const SizedBox(height: 8),

                    // Situational Modifiers
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: Text("Stationary Attacker (+1 BS Heavy)",
                              style: OmnispexTypography.monoStatBadge
                                  .copyWith(fontSize: 11)),
                          selected: isStationary,
                          selectedColor: OmnispexColors.cyan.withOpacity(0.25),
                          backgroundColor: OmnispexColors.surfaceElevated,
                          side: BorderSide(
                              color: isStationary
                                  ? OmnispexColors.cyan
                                  : OmnispexColors.border),
                          onSelected: (val) => ref
                              .read(benchIsStationaryProvider.notifier)
                              .state = val,
                        ),
                        FilterChip(
                          label: Text("Made Charge Move (+1 Wound Lance)",
                              style: OmnispexTypography.monoStatBadge
                                  .copyWith(fontSize: 11)),
                          selected: hasCharged,
                          selectedColor: OmnispexColors.amber.withOpacity(0.25),
                          backgroundColor: OmnispexColors.surfaceElevated,
                          side: BorderSide(
                              color: hasCharged
                                  ? OmnispexColors.amber
                                  : OmnispexColors.border),
                          onSelected: (val) => ref
                              .read(benchHasChargedProvider.notifier)
                              .state = val,
                        ),
                        FilterChip(
                          label: Text("Target In Cover (+1 Sv)",
                              style: OmnispexTypography.monoStatBadge
                                  .copyWith(fontSize: 11)),
                          selected: targetInCover,
                          selectedColor:
                              OmnispexColors.purple.withOpacity(0.25),
                          backgroundColor: OmnispexColors.surfaceElevated,
                          side: BorderSide(
                              color: targetInCover
                                  ? OmnispexColors.purple
                                  : OmnispexColors.border),
                          onSelected: (val) => ref
                              .read(benchTargetInCoverProvider.notifier)
                              .state = val,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text("DEFENSIVE ARCHETYPE MATRIX", style: OmnispexTypography.h2),
              const SizedBox(height: 10),

              // 5 Archetype Cards Grid
              ...benchmarkReport.evaluations.map((eval) {
                return _buildArchetypeCard(
                    context, eval, activeWeaponA, activeWeaponB, isDualCompare);
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _resetDefaults(WidgetRef ref) {
    ref.read(benchWeaponIndexAProvider.notifier).state = 0;
    ref.read(benchWeaponCountAProvider.notifier).state = 1;
    ref.read(benchPointsAProvider.notifier).state = 100;
    ref.read(benchIsDualCompareProvider.notifier).state = false;
    ref.read(benchWeaponIndexBProvider.notifier).state = 1;
    ref.read(benchWeaponCountBProvider.notifier).state = 1;
    ref.read(benchPointsBProvider.notifier).state = 100;
    ref.read(benchIsStationaryProvider.notifier).state = true;
    ref.read(benchHasChargedProvider.notifier).state = false;
    ref.read(benchTargetInCoverProvider.notifier).state = false;
  }

  Widget _buildProfileSelector(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required Color color,
    required List<WeaponUiProfile> weapons,
    required int weaponIdx,
    required int count,
    required int points,
    required ValueChanged<int> onWeaponChanged,
    required ValueChanged<int> onCountChanged,
    required ValueChanged<int> onPointsChanged,
  }) {
    final active = weapons[weaponIdx % weapons.length];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: OmnispexTypography.label.copyWith(color: color)),
              if (title.contains("PROFILE B"))
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 16, color: OmnispexColors.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => ref
                      .read(benchIsDualCompareProvider.notifier)
                      .state = false,
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: weaponIdx,
            isExpanded: true,
            dropdownColor: OmnispexColors.surfaceCard,
            decoration: const InputDecoration(labelText: "WEAPON PROFILE"),
            items: List.generate(weapons.length, (i) {
              final w = weapons[i];
              return DropdownMenuItem(
                value: i,
                child: Text("${w.name} [${w.profileName}]",
                    style: OmnispexTypography.monoData.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              );
            }),
            onChanged: (val) {
              if (val != null) onWeaponChanged(val);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text("COUNT:",
                        style: OmnispexTypography.label.copyWith(fontSize: 10)),
                    ...[1, 3, 5, 10].map((c) {
                      final isSel = count == c;
                      return ChoiceChip(
                        label: Text("$c",
                            style: OmnispexTypography.monoStatBadge.copyWith(
                                fontSize: 10,
                                color:
                                    isSel ? OmnispexColors.background : color)),
                        selected: isSel,
                        selectedColor: color,
                        backgroundColor: OmnispexColors.surfaceCard,
                        side: BorderSide(
                            color: isSel ? color : OmnispexColors.border),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (sel) {
                          if (sel) onCountChanged(c);
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: "$points",
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Points Cost"),
                  style: OmnispexTypography.monoData.copyWith(fontSize: 12),
                  onChanged: (val) {
                    final p = int.tryParse(val);
                    if (p != null) onPointsChanged(p);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              StatBadge(
                  label: "TYPE",
                  value: active.isMelee ? "MELEE" : '${active.range}"',
                  accentColor: color),
              StatBadge(label: "A", value: active.attacks),
              StatBadge(label: "BS", value: '${active.skill}+'),
              StatBadge(label: "S", value: '${active.strength}'),
              StatBadge(label: "AP", value: '-${active.ap}'),
              StatBadge(label: "D", value: active.damage),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDualComparePrompt(WidgetRef ref) {
    return InkWell(
      onTap: () => ref.read(benchIsDualCompareProvider.notifier).state = true,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        decoration: BoxDecoration(
          color: OmnispexColors.surfaceElevated.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: OmnispexColors.border, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline,
                size: 24, color: OmnispexColors.amber),
            const SizedBox(height: 6),
            Text("ENABLE LOADOUT DUEL COMPARISON",
                style: OmnispexTypography.label
                    .copyWith(color: OmnispexColors.amber, fontSize: 11)),
            const SizedBox(height: 4),
            Text("Compare Weapon A vs Weapon B across all 5 archetypes",
                style: OmnispexTypography.bodyMuted.copyWith(fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildArchetypeCard(
    BuildContext context,
    ArchetypeEvaluationUi eval,
    WeaponUiProfile weaponA,
    WeaponUiProfile weaponB,
    bool isDualCompare,
  ) {
    final target = eval.archetype.target;
    final isSingleModel = target.isSingleModel;

    final verdictTypeA = switch (eval.reportA.tacticalVerdict) {
      TacticalVerdictUi.greenReliableKill => VerdictType.greenReliableKill,
      TacticalVerdictUi.yellowChipContest => VerdictType.yellowChipContest,
      TacticalVerdictUi.redIneffective => VerdictType.redIneffective,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                        color: OmnispexColors.cyan,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text(eval.archetype.label,
                      style: OmnispexTypography.h2.copyWith(fontSize: 14)),
                ],
              ),
              Wrap(
                spacing: 4,
                children: [
                  StatBadge(label: "T", value: '${target.toughness}'),
                  StatBadge(label: "SV", value: '${target.save}+'),
                  if (target.invuln != null)
                    StatBadge(
                        label: "INV",
                        value: '${target.invuln}+',
                        accentColor: OmnispexColors.amber),
                  StatBadge(label: "W", value: '${target.woundsPerModel}'),
                  StatBadge(label: "MODELS", value: '${target.modelCount}'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(eval.archetype.description,
              style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11)),
          const SizedBox(height: 12),

          // Primary Evaluation Cards
          if (!isDualCompare) ...[
            Row(
              children: [
                Expanded(
                  child: ScannableMetricCard(
                    label: isSingleModel ? "Expected Damage" : "Expected Kills",
                    value: isSingleModel
                        ? "${eval.reportA.expectedDamageDealt.toStringAsFixed(1)} / ${target.totalWounds} HP"
                        : "${eval.reportA.expectedModelsKilled.toStringAsFixed(1)} / ${target.modelCount}",
                    subtitle:
                        "± ${(isSingleModel ? eval.reportA.stdDevDamage : eval.reportA.stdDevKills).toStringAsFixed(1)} StdDev",
                    accentColor: OmnispexColors.cyan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ScannableMetricCard(
                    label: "Safe Bet (≥80%)",
                    value: isSingleModel
                        ? "${eval.reportA.safeBetDamage80} HP"
                        : "${eval.reportA.safeBetKills80} models",
                    subtitle: "80% Confidence Floor",
                    accentColor: OmnispexColors.greenKill,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ScannableMetricCard(
                    label: "Points Efficiency",
                    value: "${eval.ptsEfficiencyA.toStringAsFixed(1)} dmg",
                    subtitle: "per 100 points",
                    accentColor: OmnispexColors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TacticalVerdictBadge(verdict: verdictTypeA),
          ] else ...[
            // Side-by-Side Dual Comparison
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: OmnispexColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: OmnispexColors.cyan.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("PROFILE A",
                            style: OmnispexTypography.label.copyWith(
                                color: OmnispexColors.cyan, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(
                          isSingleModel
                              ? "${eval.reportA.expectedDamageDealt.toStringAsFixed(1)} HP"
                              : "${eval.reportA.expectedModelsKilled.toStringAsFixed(1)} / ${target.modelCount} Kills",
                          style: OmnispexTypography.monoData.copyWith(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        Text(
                            "Safe: ${isSingleModel ? '${eval.reportA.safeBetDamage80} HP' : '${eval.reportA.safeBetKills80} kills'}",
                            style: OmnispexTypography.bodyMuted
                                .copyWith(fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(
                            "${eval.ptsEfficiencyA.toStringAsFixed(1)} dmg / 100pts",
                            style: OmnispexTypography.monoStatBadge.copyWith(
                                fontSize: 11, color: OmnispexColors.cyan)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: OmnispexColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: OmnispexColors.amber.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("PROFILE B",
                            style: OmnispexTypography.label.copyWith(
                                color: OmnispexColors.amber, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(
                          isSingleModel
                              ? "${eval.reportB?.expectedDamageDealt.toStringAsFixed(1) ?? '0.0'} HP"
                              : "${eval.reportB?.expectedModelsKilled.toStringAsFixed(1) ?? '0.0'} / ${target.modelCount} Kills",
                          style: OmnispexTypography.monoData.copyWith(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        Text(
                            "Safe: ${isSingleModel ? '${eval.reportB?.safeBetDamage80 ?? 0} HP' : '${eval.reportB?.safeBetKills80 ?? 0} kills'}",
                            style: OmnispexTypography.bodyMuted
                                .copyWith(fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(
                            "${eval.ptsEfficiencyB?.toStringAsFixed(1) ?? '0.0'} dmg / 100pts",
                            style: OmnispexTypography.monoStatBadge.copyWith(
                                fontSize: 11, color: OmnispexColors.amber)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Advantage Banner & Bar
            _buildAdvantageBanner(eval),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvantageBanner(ArchetypeEvaluationUi eval) {
    final winnerColor = eval.winner == DuelWinner.profileA
        ? OmnispexColors.cyan
        : (eval.winner == DuelWinner.profileB
            ? OmnispexColors.amber
            : OmnispexColors.textSecondary);

    final winnerLabel = eval.winner == DuelWinner.profileA
        ? "PROFILE A IS +${eval.winMarginPercent.toStringAsFixed(0)}% MORE EFFICIENT"
        : (eval.winner == DuelWinner.profileB
            ? "PROFILE B IS +${eval.winMarginPercent.toStringAsFixed(0)}% MORE EFFICIENT"
            : "EQUAL POINTS EFFICIENCY");

    final totalPtsEff = eval.ptsEfficiencyA + (eval.ptsEfficiencyB ?? 0.0);
    final ratioA = totalPtsEff > 0
        ? (eval.ptsEfficiencyA / totalPtsEff).clamp(0.05, 0.95)
        : 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(winnerLabel,
                style: OmnispexTypography.monoStatBadge
                    .copyWith(fontSize: 10, color: winnerColor)),
            Text(
                "${(ratioA * 100).toStringAsFixed(0)}% vs ${((1 - ratioA) * 100).toStringAsFixed(0)}%",
                style: OmnispexTypography.monoStatBadge
                    .copyWith(fontSize: 10, color: OmnispexColors.textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                Expanded(
                  flex: (ratioA * 100).round(),
                  child: Container(color: OmnispexColors.cyan),
                ),
                Expanded(
                  flex: ((1 - ratioA) * 100).round(),
                  child: Container(color: OmnispexColors.amber),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
