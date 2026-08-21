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

enum AttackMode { singleWeapon, squadBundle }

final attackModeProvider = StateProvider<AttackMode>((ref) => AttackMode.singleWeapon);
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
final selectedSquadPresetIndexProvider = StateProvider<int>((ref) => 0);

final selectedTargetIndexProvider = StateProvider<int>((ref) => 0);
final isCustomTargetModeProvider = StateProvider<bool>((ref) => false);
final customTargetProfileProvider = StateProvider<UnitUiProfile>((ref) => const UnitUiProfile(
      name: "Custom Target",
      toughness: 4,
      save: 3,
      woundsPerModel: 2,
      modelCount: 5,
      keywords: ["INFANTRY"],
    ));
final isStationaryProvider = StateProvider<bool>((ref) => true);
final hasChargedProvider = StateProvider<bool>((ref) => false);
final targetInCoverProvider = StateProvider<bool>((ref) => false);
final combatDistanceProvider = StateProvider<int>((ref) => 12);

// Offensive What-If Providers
final whatIfAbilitiesProvider = StateProvider<Set<String>>((ref) => {});
final hitRerollProvider = StateProvider<ReRollOption>((ref) => ReRollOption.none);
final woundRerollProvider = StateProvider<ReRollOption>((ref) => ReRollOption.none);
final bonusStrengthProvider = StateProvider<int>((ref) => 0);
final bonusApProvider = StateProvider<int>((ref) => 0);

// Defensive What-If Providers (Opponent Counter-Stratagems)
final defensiveArmorOfContemptProvider = StateProvider<bool>((ref) => false);
final defensiveMinusWoundProvider = StateProvider<bool>((ref) => false);
final defensiveGrantInvuln4Provider = StateProvider<bool>((ref) => false);
final defensiveGrantFnp5Provider = StateProvider<bool>((ref) => false);
final defensiveGrantMinusDamage1Provider = StateProvider<bool>((ref) => false);
final defensiveGrantHalfDamageProvider = StateProvider<bool>((ref) => false);

class InBattleScreen extends ConsumerWidget {
  const InBattleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeepAnalytics = ref.watch(isDeepAnalyticsModeProvider);
    final attackMode = ref.watch(attackModeProvider);
    final weaponIdx = ref.watch(selectedWeaponIndexProvider);
    final isCustomWeapon = ref.watch(isCustomWeaponModeProvider);
    final customWeapon = ref.watch(customWeaponProfileProvider);
    final weaponCount = ref.watch(weaponCountProvider);
    final squadIdx = ref.watch(selectedSquadPresetIndexProvider);

    final targetIdx = ref.watch(selectedTargetIndexProvider);
    final isStationary = ref.watch(isStationaryProvider);
    final hasCharged = ref.watch(hasChargedProvider);
    final targetInCover = ref.watch(targetInCoverProvider);
    final distance = ref.watch(combatDistanceProvider);

    final whatIfAbilities = ref.watch(whatIfAbilitiesProvider);
    final hitReroll = ref.watch(hitRerollProvider);
    final woundReroll = ref.watch(woundRerollProvider);
    final bonusStrength = ref.watch(bonusStrengthProvider);
    final bonusAp = ref.watch(bonusApProvider);

    final defArmorOfContempt = ref.watch(defensiveArmorOfContemptProvider);
    final defMinusWound = ref.watch(defensiveMinusWoundProvider);
    final defGrantInvuln4 = ref.watch(defensiveGrantInvuln4Provider);
    final defGrantFnp5 = ref.watch(defensiveGrantFnp5Provider);
    final defGrantMinusDmg1 = ref.watch(defensiveGrantMinusDamage1Provider);
    final defGrantHalfDmg = ref.watch(defensiveGrantHalfDamageProvider);

    final isCustomTarget = ref.watch(isCustomTargetModeProvider);
    final customTarget = ref.watch(customTargetProfileProvider);

    final weapons = SimulationService.defaultWeapons;
    final squadPresets = SimulationService.defaultSquadPresets;
    final targets = SimulationService.defaultTargets;

    final activeWeapon = isCustomWeapon ? customWeapon : weapons[weaponIdx % weapons.length];
    final activeTarget = isCustomTarget ? customTarget : targets[targetIdx % targets.length];
    final activeSquad = squadPresets[squadIdx % squadPresets.length];

    final SimulationUiReport report;
    if (attackMode == AttackMode.squadBundle) {
      report = SimulationService.runSquadSimulation(
        loadout: activeSquad.loadout,
        target: activeTarget,
        isStationary: isStationary,
        hasCharged: hasCharged,
        targetInCover: targetInCover,
        distance: distance,
        extraAbilities: whatIfAbilities,
        hitReroll: hitReroll,
        woundReroll: woundReroll,
        bonusStrength: bonusStrength,
        bonusAp: bonusAp,
        defensiveArmorOfContempt: defArmorOfContempt,
        defensiveMinusWound: defMinusWound,
        defensiveGrantInvuln4: defGrantInvuln4,
        defensiveGrantFnp5: defGrantFnp5,
        defensiveGrantMinusDamage1: defGrantMinusDmg1,
        defensiveGrantHalfDamage: defGrantHalfDmg,
      );
    } else {
      report = SimulationService.runSimulation(
        weapon: activeWeapon,
        target: activeTarget,
        isStationary: isStationary,
        hasCharged: hasCharged,
        targetInCover: targetInCover,
        weaponCount: weaponCount,
        distance: distance,
        extraAbilities: whatIfAbilities,
        hitReroll: hitReroll,
        woundReroll: woundReroll,
        bonusStrength: bonusStrength,
        bonusAp: bonusAp,
        defensiveArmorOfContempt: defArmorOfContempt,
        defensiveMinusWound: defMinusWound,
        defensiveGrantInvuln4: defGrantInvuln4,
        defensiveGrantFnp5: defGrantFnp5,
        defensiveGrantMinusDamage1: defGrantMinusDmg1,
        defensiveGrantHalfDamage: defGrantHalfDmg,
      );
    }

    WeaponUiProfile? altWeapon;
    SimulationUiReport? altReport;
    if (attackMode == AttackMode.singleWeapon && !isCustomWeapon) {
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
          extraAbilities: whatIfAbilities,
          hitReroll: hitReroll,
          woundReroll: woundReroll,
          bonusStrength: bonusStrength,
          bonusAp: bonusAp,
          defensiveArmorOfContempt: defArmorOfContempt,
          defensiveMinusWound: defMinusWound,
          defensiveGrantInvuln4: defGrantInvuln4,
          defensiveGrantFnp5: defGrantFnp5,
          defensiveGrantMinusDamage1: defGrantMinusDmg1,
          defensiveGrantHalfDamage: defGrantHalfDmg,
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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text("IN-BATTLE RESOLUTION", style: OmnispexTypography.h2),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 14),
                    label: Text("RESET DEFAULTS", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OmnispexColors.textSecondary,
                      side: const BorderSide(color: OmnispexColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _resetAll(ref),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildControlsColumn(
                        context,
                        ref,
                        attackMode,
                        weapons,
                        squadPresets,
                        targets,
                        weaponIdx,
                        isCustomWeapon,
                        customWeapon,
                        weaponCount,
                        squadIdx,
                        targetIdx,
                        isStationary,
                        hasCharged,
                        targetInCover,
                        distance,
                        activeWeapon,
                        activeTarget,
                        activeSquad,
                        whatIfAbilities,
                        hitReroll,
                        woundReroll,
                        defArmorOfContempt,
                        defMinusWound,
                        defGrantInvuln4,
                        defGrantFnp5,
                        defGrantMinusDmg1,
                        defGrantHalfDmg,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 7,
                      child: _buildResultsColumn(
                        report,
                        activeWeapon,
                        activeTarget,
                        altWeapon,
                        altReport,
                        weaponIdx,
                        isDeepAnalytics,
                        attackMode,
                        ref,
                      ),
                    ),
                  ],
                )
              else ...[
                _buildControlsColumn(
                  context,
                  ref,
                  attackMode,
                  weapons,
                  squadPresets,
                  targets,
                  weaponIdx,
                  isCustomWeapon,
                  customWeapon,
                  weaponCount,
                  squadIdx,
                  targetIdx,
                  isStationary,
                  hasCharged,
                  targetInCover,
                  distance,
                  activeWeapon,
                  activeTarget,
                  activeSquad,
                  whatIfAbilities,
                  hitReroll,
                  woundReroll,
                  defArmorOfContempt,
                  defMinusWound,
                  defGrantInvuln4,
                  defGrantFnp5,
                  defGrantMinusDmg1,
                  defGrantHalfDmg,
                ),
                const SizedBox(height: 16),
                _buildResultsColumn(
                  report,
                  activeWeapon,
                  activeTarget,
                  altWeapon,
                  altReport,
                  weaponIdx,
                  isDeepAnalytics,
                  attackMode,
                  ref,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _resetAll(WidgetRef ref) {
    ref.read(attackModeProvider.notifier).state = AttackMode.singleWeapon;
    ref.read(selectedWeaponIndexProvider.notifier).state = 0;
    ref.read(isCustomWeaponModeProvider.notifier).state = false;
    ref.read(weaponCountProvider.notifier).state = 1;
    ref.read(selectedSquadPresetIndexProvider.notifier).state = 0;
    ref.read(selectedTargetIndexProvider.notifier).state = 0;
    ref.read(isStationaryProvider.notifier).state = true;
    ref.read(hasChargedProvider.notifier).state = false;
    ref.read(targetInCoverProvider.notifier).state = false;
    ref.read(combatDistanceProvider.notifier).state = 12;
    ref.read(whatIfAbilitiesProvider.notifier).state = {};
    ref.read(hitRerollProvider.notifier).state = ReRollOption.none;
    ref.read(woundRerollProvider.notifier).state = ReRollOption.none;
    ref.read(bonusStrengthProvider.notifier).state = 0;
    ref.read(bonusApProvider.notifier).state = 0;
    ref.read(defensiveArmorOfContemptProvider.notifier).state = false;
    ref.read(defensiveMinusWoundProvider.notifier).state = false;
    ref.read(defensiveGrantInvuln4Provider.notifier).state = false;
    ref.read(defensiveGrantFnp5Provider.notifier).state = false;
    ref.read(defensiveGrantMinusDamage1Provider.notifier).state = false;
    ref.read(defensiveGrantHalfDamageProvider.notifier).state = false;
  }

  Widget _buildControlsColumn(
    BuildContext context,
    WidgetRef ref,
    AttackMode attackMode,
    List<WeaponUiProfile> weapons,
    List<SquadPreset> squadPresets,
    List<UnitUiProfile> targets,
    int weaponIdx,
    bool isCustomWeapon,
    WeaponUiProfile customWeapon,
    int weaponCount,
    int squadIdx,
    int targetIdx,
    bool isStationary,
    bool hasCharged,
    bool targetInCover,
    int distance,
    WeaponUiProfile activeWeapon,
    UnitUiProfile activeTarget,
    SquadPreset activeSquad,
    Set<String> whatIfAbilities,
    ReRollOption hitReroll,
    ReRollOption woundReroll,
    bool defArmorOfContempt,
    bool defMinusWound,
    bool defGrantInvuln4,
    bool defGrantFnp5,
    bool defGrantMinusDmg1,
    bool defGrantHalfDmg,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode Selector: Single Weapon vs Squad Multi-Weapon Bundle
        TacticalCard(
          title: "ATTACK CONFIGURATION MODE",
          child: SegmentedButton<AttackMode>(
            segments: const [
              ButtonSegment(
                value: AttackMode.singleWeapon,
                label: Text("Single Weapon Profile"),
                icon: Icon(Icons.straighten, size: 14),
              ),
              ButtonSegment(
                value: AttackMode.squadBundle,
                label: Text("Full Squad Volley"),
                icon: Icon(Icons.groups, size: 14),
              ),
            ],
            selected: {attackMode},
            onSelectionChanged: (set) {
              ref.read(attackModeProvider.notifier).state = set.first;
            },
          ),
        ),

        // 1. Attacker Weapon / Squad Loadout
        if (attackMode == AttackMode.singleWeapon)
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
                      return DropdownMenuItem(
                        value: i,
                        child: Text(
                          "${w.name} [${w.profileName}]",
                          style: OmnispexTypography.monoData.copyWith(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                    DropdownMenuItem(
                      value: -1,
                      child: Text(
                        "Custom Weapon (Manual Input)...",
                        style: OmnispexTypography.monoData.copyWith(color: OmnispexColors.amber, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
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

                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text("WEAPON COUNT:", style: OmnispexTypography.label.copyWith(fontSize: 11)),
                    ...[1, 3, 5, 10].map((count) {
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
                    }),
                  ],
                ),
                const SizedBox(height: 12),

                if (isCustomWeapon)
                  _buildCustomWeaponEditor(context, ref, customWeapon)
                else ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatBadge(
                        label: "TYPE",
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
          )
        else
          TacticalCard(
            title: "1. SQUAD MULTI-WEAPON BUNDLE",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  value: squadIdx,
                  isExpanded: true,
                  dropdownColor: OmnispexColors.surfaceCard,
                  decoration: const InputDecoration(labelText: "SELECT SQUAD PRESET"),
                  items: List.generate(squadPresets.length, (i) {
                    final sq = squadPresets[i];
                    return DropdownMenuItem(
                      value: i,
                      child: Text(sq.name, style: OmnispexTypography.monoData.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) ref.read(selectedSquadPresetIndexProvider.notifier).state = val;
                  },
                ),
                const SizedBox(height: 12),
                Text("SQUAD WEAPONS BUNDLED:", style: OmnispexTypography.label.copyWith(fontSize: 10)),
                const SizedBox(height: 6),
                ...activeSquad.loadout.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: OmnispexColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: OmnispexColors.border),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          "${entry.count}x ${entry.weapon.name} [${entry.weapon.profileName}]",
                          style: OmnispexTypography.monoData.copyWith(fontSize: 12),
                        ),
                        Text(
                          "A: ${entry.weapon.attacks} | S: ${entry.weapon.strength} | AP: ${entry.weapon.ap} | D: ${entry.weapon.damage}",
                          style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }),
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
                    child: Text(t.name, style: OmnispexTypography.monoData, overflow: TextOverflow.ellipsis),
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

        // 3. Applicable Combat Modifiers (Situational Only)
        TacticalCard(
          title: "3. APPLICABLE COMBAT MODIFIERS",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeWeapon.isMelee && activeWeapon.abilities.contains("Lance"))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Attacker Made Charge Move (Lance +1)", style: OmnispexTypography.body),
                  value: hasCharged,
                  activeColor: OmnispexColors.cyan,
                  onChanged: (val) => ref.read(hasChargedProvider.notifier).state = val,
                ),
              if (activeWeapon.isRanged &&
                  !activeWeapon.abilities.contains("Ignores Cover") &&
                  !whatIfAbilities.contains("Ignores Cover") &&
                  (activeWeapon.ap > 0 || activeTarget.save > 3))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Target Has Benefit of Cover (+1 Sv)", style: OmnispexTypography.body),
                  value: targetInCover,
                  activeColor: OmnispexColors.cyan,
                  onChanged: (val) => ref.read(targetInCoverProvider.notifier).state = val,
                ),
              if (activeWeapon.isRanged && activeWeapon.abilities.contains("Heavy"))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Attacker Stationary (Heavy +1)", style: OmnispexTypography.body),
                  value: isStationary,
                  activeColor: OmnispexColors.cyan,
                  onChanged: (val) => ref.read(isStationaryProvider.notifier).state = val,
                ),
              if (!activeWeapon.abilities.contains("Lance") &&
                  (!activeWeapon.isRanged || (!activeWeapon.abilities.contains("Heavy") && activeWeapon.abilities.contains("Ignores Cover"))))
                Text(
                  "No situational weapon modifiers apply to this profile.",
                  style: OmnispexTypography.bodyMuted,
                ),
            ],
          ),
        ),

        // 4. Offensive What-If Stratagem Injection (Idempotent / Inherent Lock)
        TacticalCard(
          title: "4. OFFENSIVE STRATAGEM INJECTION",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Test the impact of granting additional offensive rules:",
                style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildOffensiveChip(ref, "Lethal Hits", activeWeapon.abilities.contains("Lethal Hits"), whatIfAbilities),
                  _buildOffensiveChip(ref, "Sustained Hits 1", activeWeapon.abilities.contains("Sustained Hits 1"), whatIfAbilities),
                  _buildOffensiveChip(ref, "Devastating Wounds", activeWeapon.abilities.contains("Devastating Wounds"), whatIfAbilities),
                  _buildOffensiveChip(ref, "Twin-Linked", activeWeapon.abilities.contains("Twin-Linked"), whatIfAbilities),
                  _buildOffensiveChip(ref, "Lance", activeWeapon.abilities.contains("Lance"), whatIfAbilities),
                  _buildOffensiveChip(ref, "Ignores Cover", activeWeapon.abilities.contains("Ignores Cover"), whatIfAbilities),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: OmnispexColors.border, height: 1),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ReRollOption>(
                      value: hitReroll,
                      decoration: const InputDecoration(labelText: "HIT RE-ROLLS"),
                      dropdownColor: OmnispexColors.surfaceCard,
                      items: const [
                        DropdownMenuItem(value: ReRollOption.none, child: Text("None")),
                        DropdownMenuItem(value: ReRollOption.ones, child: Text("Re-roll 1s")),
                        DropdownMenuItem(value: ReRollOption.all, child: Text("Full Re-rolls")),
                      ],
                      onChanged: (val) {
                        if (val != null) ref.read(hitRerollProvider.notifier).state = val;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<ReRollOption>(
                      value: woundReroll,
                      decoration: const InputDecoration(labelText: "WOUND RE-ROLLS"),
                      dropdownColor: OmnispexColors.surfaceCard,
                      items: const [
                        DropdownMenuItem(value: ReRollOption.none, child: Text("None")),
                        DropdownMenuItem(value: ReRollOption.ones, child: Text("Re-roll 1s")),
                        DropdownMenuItem(value: ReRollOption.all, child: Text("Full Re-rolls")),
                      ],
                      onChanged: (val) {
                        if (val != null) ref.read(woundRerollProvider.notifier).state = val;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 5. Defensive Counter-Stratagems ("What-If Defender Reacts")
        TacticalCard(
          title: "5. DEFENDER COUNTER-STRATAGEMS",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Test resilience if the defender uses defensive reactions:",
                style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilterChip(
                    label: Text("Armor of Contempt (-1 AP)", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10)),
                    selected: defArmorOfContempt,
                    selectedColor: OmnispexColors.purple.withOpacity(0.25),
                    backgroundColor: OmnispexColors.surfaceElevated,
                    side: BorderSide(color: defArmorOfContempt ? OmnispexColors.purple : OmnispexColors.border),
                    onSelected: (val) => ref.read(defensiveArmorOfContemptProvider.notifier).state = val,
                  ),
                  _buildDefensiveChip(
                    label: "-1 to Wound (Transhuman)",
                    isInherent: activeTarget.hasMinusWound,
                    isSelected: defMinusWound,
                    onSelected: (val) => ref.read(defensiveMinusWoundProvider.notifier).state = val,
                  ),
                  _buildDefensiveChip(
                    label: "4++ Invulnerable Save",
                    isInherent: activeTarget.has4PlusInvuln,
                    isSelected: defGrantInvuln4,
                    onSelected: (val) => ref.read(defensiveGrantInvuln4Provider.notifier).state = val,
                  ),
                  _buildDefensiveChip(
                    label: "5+++ Feel No Pain",
                    isInherent: activeTarget.hasFnp,
                    isSelected: defGrantFnp5,
                    onSelected: (val) => ref.read(defensiveGrantFnp5Provider.notifier).state = val,
                  ),
                  _buildDefensiveChip(
                    label: "-1 Damage Reduction",
                    isInherent: activeTarget.hasDamageReduction,
                    isSelected: defGrantMinusDmg1,
                    onSelected: (val) => ref.read(defensiveGrantMinusDamage1Provider.notifier).state = val,
                  ),
                  _buildDefensiveChip(
                    label: "Half Damage",
                    isInherent: activeTarget.hasHalfDamage,
                    isSelected: defGrantHalfDmg,
                    onSelected: (val) => ref.read(defensiveGrantHalfDamageProvider.notifier).state = val,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOffensiveChip(
    WidgetRef ref,
    String label,
    bool isInherent,
    Set<String> whatIfAbilities,
  ) {
    if (isInherent) {
      return Chip(
        label: Text("$label (Inherent)", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.cyan)),
        backgroundColor: OmnispexColors.cyan.withOpacity(0.15),
        side: const BorderSide(color: OmnispexColors.cyan),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    final active = whatIfAbilities.contains(label);
    return FilterChip(
      label: Text(label, style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10)),
      selected: active,
      selectedColor: OmnispexColors.amber.withOpacity(0.25),
      backgroundColor: OmnispexColors.surfaceElevated,
      side: BorderSide(color: active ? OmnispexColors.amber : OmnispexColors.border),
      onSelected: (selected) {
        final updated = Set<String>.from(whatIfAbilities);
        if (selected) {
          updated.add(label);
        } else {
          updated.remove(label);
        }
        ref.read(whatIfAbilitiesProvider.notifier).state = updated;
      },
    );
  }

  Widget _buildDefensiveChip({
    required String label,
    required bool isInherent,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    if (isInherent) {
      return Chip(
        label: Text("$label (Inherent)", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.purple)),
        backgroundColor: OmnispexColors.purple.withOpacity(0.15),
        side: const BorderSide(color: OmnispexColors.purple),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    return FilterChip(
      label: Text(label, style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10)),
      selected: isSelected,
      selectedColor: OmnispexColors.purple.withOpacity(0.25),
      backgroundColor: OmnispexColors.surfaceElevated,
      side: BorderSide(color: isSelected ? OmnispexColors.purple : OmnispexColors.border),
      onSelected: onSelected,
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
                  ButtonSegment(value: false, label: Text("Ranged")),
                  ButtonSegment(value: true, label: Text("Melee")),
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
    UnitUiProfile activeTarget,
    WeaponUiProfile? altWeapon,
    SimulationUiReport? altReport,
    int weaponIdx,
    bool isDeepAnalytics,
    AttackMode attackMode,
    WidgetRef ref,
  ) {
    final verdictType = switch (report.tacticalVerdict) {
      TacticalVerdictUi.greenReliableKill => VerdictType.greenReliableKill,
      TacticalVerdictUi.yellowChipContest => VerdictType.yellowChipContest,
      TacticalVerdictUi.redIneffective => VerdictType.redIneffective,
    };

    final isSingleModel = activeTarget.isSingleModel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TacticalVerdictBadge(verdict: verdictType),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: ScannableMetricCard(
                label: isSingleModel ? "Expected Damage" : "Expected Kills",
                value: isSingleModel
                    ? "${report.expectedDamageDealt.toStringAsFixed(1)} / ${activeTarget.totalWounds} HP"
                    : "${report.expectedModelsKilled.toStringAsFixed(1)} / ${activeTarget.modelCount}",
                subtitle: isSingleModel
                    ? "± ${report.stdDevDamage.toStringAsFixed(1)} HP StdDev"
                    : "± ${report.stdDevKills.toStringAsFixed(1)} Models StdDev",
                accentColor: OmnispexColors.cyan,
                icon: Icons.track_changes,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ScannableMetricCard(
                label: "Safe Bet (≥80%)",
                value: isSingleModel ? "${report.safeBetDamage80} HP" : "${report.safeBetKills80} models",
                subtitle: "80% Confidence Floor",
                accentColor: OmnispexColors.greenKill,
                icon: Icons.shield,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ScannableMetricCard(
                label: isSingleModel ? "Bracket Odds" : "Wipe Chance",
                value: isSingleModel
                    ? "${(report.bracket50Probability * 100).toStringAsFixed(0)}%"
                    : "${(report.wipeProbability * 100).toStringAsFixed(0)}%",
                subtitle: isSingleModel ? "≥50% HP Damage" : "100% Wipe Odds",
                accentColor: (isSingleModel ? report.bracket50Probability : report.wipeProbability) >= 0.75
                    ? OmnispexColors.greenKill
                    : ((isSingleModel ? report.bracket50Probability : report.wipeProbability) >= 0.25
                        ? OmnispexColors.yellowContest
                        : OmnispexColors.redIneffective),
                icon: Icons.dangerous,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (attackMode == AttackMode.singleWeapon && altWeapon != null && altReport != null) ...[
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
            title: isSingleModel ? "DEEP ANALYTICS: DAMAGE HISTOGRAM" : "DEEP ANALYTICS: CASUALTY HISTOGRAM",
            child: KillHistogramChart(
              distribution: isSingleModel ? report.damageDistribution : report.killDistribution,
              safeBetFloor: isSingleModel ? report.safeBetDamage80 : report.safeBetKills80,
              title: isSingleModel ? "DAMAGE PROBABILITY DENSITY" : "KILL PROBABILITY DENSITY",
              unitLabel: isSingleModel ? "dmg" : "kills",
              targetMaxHp: isSingleModel ? activeTarget.totalWounds : null,
            ),
          ),
          TacticalCard(
            title: "PERCENTILE DISTRIBUTION & OVERKILL LOSS",
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 8,
                  runSpacing: 6,
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
                    Expanded(child: Text("Raw Damage Generated:", style: OmnispexTypography.bodyMuted, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text("${report.rawDamageGenerated.toStringAsFixed(1)} dmg", style: OmnispexTypography.monoData),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text("Effective Damage Applied:", style: OmnispexTypography.bodyMuted, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text("${report.expectedDamageDealt.toStringAsFixed(1)} dmg", style: OmnispexTypography.monoData),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text("Overkill Loss to Model Truncation:", style: OmnispexTypography.bodyMuted, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
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
                      Expanded(child: Text("Lethal Hits Contribution:", style: OmnispexTypography.bodyMuted, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Text("${report.keywordAudit.lethalDamage.toStringAsFixed(1)} dmg", style: OmnispexTypography.monoData),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("Sustained Hits Contribution:", style: OmnispexTypography.bodyMuted, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Text("${report.keywordAudit.sustainedDamage.toStringAsFixed(1)} dmg", style: OmnispexTypography.monoData),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("Devastating Wounds Contribution:", style: OmnispexTypography.bodyMuted, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
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
