import 'dart:math';
import '../bridge/omnispex_rust_bridge.dart';
import '../models/simulation_models.dart';

class SquadPreset {
  final String name;
  final List<WeaponLoadoutEntry> loadout;

  const SquadPreset({
    required this.name,
    required this.loadout,
  });
}

class SimulationService {
  static final List<WeaponUiProfile> defaultWeapons = [
    const WeaponUiProfile(
      name: 'Missile Launcher',
      profileName: 'Frag Missile',
      range: 48,
      attacks: 'D6',
      skill: 3,
      strength: 4,
      ap: 0,
      damage: '1',
      abilities: ['Blast'],
    ),
    const WeaponUiProfile(
      name: 'Missile Launcher',
      profileName: 'Krak Missile',
      range: 48,
      attacks: '1',
      skill: 3,
      strength: 9,
      ap: 2,
      damage: 'D6',
      abilities: [],
    ),
    const WeaponUiProfile(
      name: 'Plasma Incinerator',
      profileName: 'Standard',
      range: 24,
      attacks: '2',
      skill: 3,
      strength: 7,
      ap: 2,
      damage: '1',
      abilities: ['Rapid Fire 1'],
    ),
    const WeaponUiProfile(
      name: 'Plasma Incinerator',
      profileName: 'Supercharge',
      range: 24,
      attacks: '2',
      skill: 3,
      strength: 8,
      ap: 3,
      damage: '2',
      abilities: ['Hazardous', 'Rapid Fire 1'],
    ),
    const WeaponUiProfile(
      name: 'Meltagun',
      profileName: 'Standard',
      range: 12,
      attacks: '1',
      skill: 3,
      strength: 9,
      ap: 4,
      damage: 'D6',
      abilities: ['Melta 2'],
    ),
    const WeaponUiProfile(
      name: 'Bolt Rifle',
      profileName: 'Standard',
      range: 24,
      attacks: '2',
      skill: 3,
      strength: 4,
      ap: 1,
      damage: '1',
      abilities: ['Heavy'],
    ),
    const WeaponUiProfile(
      name: 'Storm Bolter',
      profileName: 'Standard',
      range: 24,
      attacks: '2',
      skill: 3,
      strength: 4,
      ap: 0,
      damage: '1',
      abilities: ['Rapid Fire 2'],
    ),
    const WeaponUiProfile(
      name: 'Lascannon',
      profileName: 'Standard',
      range: 48,
      attacks: '1',
      skill: 3,
      strength: 12,
      ap: 3,
      damage: 'D6+1',
      abilities: ['Heavy'],
    ),
    const WeaponUiProfile(
      name: 'Leman Russ Battle Cannon',
      profileName: 'Standard',
      range: 48,
      attacks: 'D6+3',
      skill: 4,
      strength: 10,
      ap: 1,
      damage: '3',
      abilities: ['Blast'],
    ),
    const WeaponUiProfile(
      name: 'Heavy Bolter',
      profileName: 'Standard',
      range: 36,
      attacks: '3',
      skill: 4,
      strength: 5,
      ap: 1,
      damage: '2',
      abilities: ['Sustained Hits 1', 'Heavy'],
    ),
    const WeaponUiProfile(
      name: 'Power Fist',
      profileName: 'Melee',
      range: 0,
      attacks: '3',
      skill: 3,
      strength: 8,
      ap: 2,
      damage: '2',
      abilities: [],
    ),
    const WeaponUiProfile(
      name: 'Thunder Hammer',
      profileName: 'Melee',
      range: 0,
      attacks: '3',
      skill: 4,
      strength: 8,
      ap: 2,
      damage: '2',
      abilities: ['Devastating Wounds'],
    ),
    const WeaponUiProfile(
      name: 'Astartes Chainsword',
      profileName: 'Melee',
      range: 0,
      attacks: '4',
      skill: 3,
      strength: 4,
      ap: 1,
      damage: '1',
      abilities: [],
    ),
    const WeaponUiProfile(
      name: 'Master-crafted Power Weapon',
      profileName: 'Melee',
      range: 0,
      attacks: '4',
      skill: 2,
      strength: 5,
      ap: 2,
      damage: '2',
      abilities: ['Lance'],
    ),
  ];

  static final List<SquadPreset> defaultSquadPresets = [
    SquadPreset(
      name: 'Terminators (4x Storm Bolter + 1x Frag Cyclone)',
      loadout: [
        WeaponLoadoutEntry(
            weapon: defaultWeapons.firstWhere((w) => w.name == 'Storm Bolter'),
            count: 4),
        WeaponLoadoutEntry(
            weapon: defaultWeapons
                .firstWhere((w) => w.profileName == 'Frag Missile'),
            count: 1),
      ],
    ),
    SquadPreset(
      name: 'Leman Russ (Battle Cannon + 2x Heavy Bolter + Lascannon)',
      loadout: [
        WeaponLoadoutEntry(
            weapon: defaultWeapons
                .firstWhere((w) => w.name == 'Leman Russ Battle Cannon'),
            count: 1),
        WeaponLoadoutEntry(
            weapon: defaultWeapons.firstWhere((w) => w.name == 'Heavy Bolter'),
            count: 2),
        WeaponLoadoutEntry(
            weapon: defaultWeapons.firstWhere((w) => w.name == 'Lascannon'),
            count: 1),
      ],
    ),
    SquadPreset(
      name: 'Intercessor Squad (5x Bolt Rifle)',
      loadout: [
        WeaponLoadoutEntry(
            weapon: defaultWeapons.firstWhere((w) => w.name == 'Bolt Rifle'),
            count: 5),
      ],
    ),
    SquadPreset(
      name: 'Terminator Melee (5x Power Fist)',
      loadout: [
        WeaponLoadoutEntry(
            weapon: defaultWeapons.firstWhere((w) => w.name == 'Power Fist'),
            count: 5),
      ],
    ),
  ];

  static final List<ArchetypeEntryUi> defaultArchetypes = [
    const ArchetypeEntryUi(
      id: 'geq',
      label: 'Chaff / Light Infantry (GEQ)',
      description:
          'T3 Sv 5+ 1W 10 Models (e.g. Guardsmen, Cultists, Hormagaunts)',
      target: UnitUiProfile(
        name: 'Guardsmen Squad',
        toughness: 3,
        save: 5,
        invuln: null,
        fnp: null,
        woundsPerModel: 1,
        modelCount: 10,
        keywords: ['INFANTRY'],
      ),
    ),
    const ArchetypeEntryUi(
      id: 'meq',
      label: 'Standard Marine (MEQ)',
      description: 'T4 Sv 3+ 2W 5 Models (e.g. Intercessors, Legionaries)',
      target: UnitUiProfile(
        name: 'Intercessor Squad',
        toughness: 4,
        save: 3,
        invuln: null,
        fnp: null,
        woundsPerModel: 2,
        modelCount: 5,
        keywords: ['INFANTRY'],
      ),
    ),
    const ArchetypeEntryUi(
      id: 'teq',
      label: 'Heavy Elite Infantry (TEQ)',
      description: 'T5 Sv 2+ 4++ 3W 5 Models (e.g. Terminators, Custodes)',
      target: UnitUiProfile(
        name: 'Terminator Squad',
        toughness: 5,
        save: 2,
        invuln: 4,
        fnp: null,
        woundsPerModel: 3,
        modelCount: 5,
        keywords: ['INFANTRY'],
      ),
    ),
    const ArchetypeEntryUi(
      id: 'transport',
      label: 'Light Transport / Skimmer',
      description: 'T9 Sv 3+ 10W 1 Model (e.g. Rhino, Raider, Trukk)',
      target: UnitUiProfile(
        name: 'Rhino Transport',
        toughness: 9,
        save: 3,
        invuln: null,
        fnp: null,
        woundsPerModel: 10,
        modelCount: 1,
        keywords: ['VEHICLE'],
      ),
    ),
    const ArchetypeEntryUi(
      id: 'heavy_armor',
      label: 'Heavy Armor / Monster',
      description:
          'T12 Sv 2+ 16W 1 Model (e.g. Leman Russ, Land Raider, Knight)',
      target: UnitUiProfile(
        name: 'Heavy Battle Tank',
        toughness: 12,
        save: 2,
        invuln: null,
        fnp: null,
        woundsPerModel: 16,
        modelCount: 1,
        keywords: ['VEHICLE'],
      ),
    ),
  ];

  static final List<UnitUiProfile> defaultTargets = [
    const UnitUiProfile(
      name: 'Ork Boyz (Horde)',
      toughness: 5,
      save: 5,
      invuln: null,
      fnp: null,
      woundsPerModel: 1,
      modelCount: 10,
      keywords: ['INFANTRY'],
    ),
    const UnitUiProfile(
      name: 'Intercessor Squad (MEQ)',
      toughness: 4,
      save: 3,
      invuln: null,
      fnp: null,
      woundsPerModel: 2,
      modelCount: 5,
      keywords: ['INFANTRY'],
    ),
    const UnitUiProfile(
      name: 'Terminator Squad (TEQ)',
      toughness: 5,
      save: 2,
      invuln: 4,
      fnp: null,
      woundsPerModel: 3,
      modelCount: 5,
      keywords: ['INFANTRY'],
    ),
    const UnitUiProfile(
      name: 'Rhino Transport',
      toughness: 9,
      save: 3,
      invuln: null,
      fnp: null,
      woundsPerModel: 10,
      modelCount: 1,
      keywords: ['VEHICLE'],
    ),
    const UnitUiProfile(
      name: 'Leman Russ Battle Tank',
      toughness: 11,
      save: 2,
      invuln: null,
      fnp: null,
      woundsPerModel: 13,
      modelCount: 1,
      defensiveAbilities: ['ReduceDamage 1'],
      keywords: ['VEHICLE'],
    ),
  ];

  static SimulationUiReport runSimulation({
    required WeaponUiProfile weapon,
    required UnitUiProfile target,
    required bool isStationary,
    required bool hasCharged,
    required bool targetInCover,
    int weaponCount = 1,
    int? distance,
    Set<String> extraAbilities = const {},
    ReRollOption hitReroll = ReRollOption.none,
    ReRollOption woundReroll = ReRollOption.none,
    int bonusStrength = 0,
    int bonusAp = 0,
    bool defensiveArmorOfContempt = false,
    bool defensiveMinusWound = false,
    bool defensiveGrantInvuln4 = false,
    bool defensiveGrantFnp5 = false,
    bool defensiveGrantHalfDamage = false,
    bool defensiveGrantMinusDamage1 = false,
    int iterations = 10000,
    int seed = 42,
  }) {
    return runSquadSimulation(
      loadout: [WeaponLoadoutEntry(weapon: weapon, count: weaponCount)],
      target: target,
      isStationary: isStationary,
      hasCharged: hasCharged,
      targetInCover: targetInCover,
      distance: distance,
      extraAbilities: extraAbilities,
      hitReroll: hitReroll,
      woundReroll: woundReroll,
      bonusStrength: bonusStrength,
      bonusAp: bonusAp,
      defensiveArmorOfContempt: defensiveArmorOfContempt,
      defensiveMinusWound: defensiveMinusWound,
      defensiveGrantInvuln4: defensiveGrantInvuln4,
      defensiveGrantFnp5: defensiveGrantFnp5,
      defensiveGrantHalfDamage: defensiveGrantHalfDamage,
      defensiveGrantMinusDamage1: defensiveGrantMinusDamage1,
      iterations: iterations,
      seed: seed,
    );
  }

  static SimulationUiReport runSquadSimulation({
    required List<WeaponLoadoutEntry> loadout,
    required UnitUiProfile target,
    required bool isStationary,
    required bool hasCharged,
    required bool targetInCover,
    int? distance,
    Set<String> extraAbilities = const {},
    ReRollOption hitReroll = ReRollOption.none,
    ReRollOption woundReroll = ReRollOption.none,
    int bonusStrength = 0,
    int bonusAp = 0,
    bool defensiveArmorOfContempt = false,
    bool defensiveMinusWound = false,
    bool defensiveGrantInvuln4 = false,
    bool defensiveGrantFnp5 = false,
    bool defensiveGrantHalfDamage = false,
    bool defensiveGrantMinusDamage1 = false,
    int iterations = 10000,
    int seed = 42,
  }) {
    final ctxJson = OmnispexRustBridge.buildCombatContextJson(
      isStationary: isStationary,
      hasCharged: hasCharged,
      targetInCover: targetInCover,
      distance: distance,
      extraAbilities: extraAbilities,
      hitReroll: hitReroll,
      woundReroll: woundReroll,
      bonusStrength: bonusStrength,
      bonusAp: bonusAp,
      defensiveArmorOfContempt: defensiveArmorOfContempt,
      defensiveMinusWound: defensiveMinusWound,
      defensiveGrantInvuln4: defensiveGrantInvuln4,
      defensiveGrantFnp5: defensiveGrantFnp5,
      defensiveGrantHalfDamage: defensiveGrantHalfDamage,
      defensiveGrantMinusDamage1: defensiveGrantMinusDamage1,
    );
    return OmnispexRustBridge.simulateSquadMatchup(
      loadout: loadout,
      target: target,
      contextJson: ctxJson,
      iterations: iterations,
    );
  }

  static BenchmarkRosterReportUi evaluateArchetypesBenchmark({
    required List<WeaponLoadoutEntry> loadoutA,
    int pointsA = 100,
    List<WeaponLoadoutEntry>? loadoutB,
    int? pointsB,
    bool isStationary = true,
    bool hasCharged = false,
    bool targetInCover = false,
    int distance = 12,
    Set<String> extraAbilitiesA = const {},
    Set<String> extraAbilitiesB = const {},
    ReRollOption hitRerollA = ReRollOption.none,
    ReRollOption hitRerollB = ReRollOption.none,
    ReRollOption woundRerollA = ReRollOption.none,
    ReRollOption woundRerollB = ReRollOption.none,
    int iterations = 10000,
  }) {
    final evaluations = <ArchetypeEvaluationUi>[];

    for (final arch in defaultArchetypes) {
      final repA = runSquadSimulation(
        loadout: loadoutA,
        target: arch.target,
        isStationary: isStationary,
        hasCharged: hasCharged,
        targetInCover: targetInCover,
        distance: distance,
        extraAbilities: extraAbilitiesA,
        hitReroll: hitRerollA,
        woundReroll: woundRerollA,
        iterations: iterations,
      );

      final ptsEffA = repA.expectedDamageDealt / (max(1, pointsA) / 100.0);

      SimulationUiReport? repB;
      double? ptsEffB;
      DuelWinner winner = DuelWinner.tie;
      double margin = 0.0;

      if (loadoutB != null && loadoutB.isNotEmpty) {
        repB = runSquadSimulation(
          loadout: loadoutB,
          target: arch.target,
          isStationary: isStationary,
          hasCharged: hasCharged,
          targetInCover: targetInCover,
          distance: distance,
          extraAbilities: extraAbilitiesB,
          hitReroll: hitRerollB,
          woundReroll: woundRerollB,
          iterations: iterations,
        );

        ptsEffB = repB.expectedDamageDealt / (max(1, pointsB ?? 100) / 100.0);

        if (ptsEffA > ptsEffB + 1e-4) {
          winner = DuelWinner.profileA;
          margin =
              ptsEffB > 0 ? ((ptsEffA - ptsEffB) / ptsEffB) * 100.0 : 100.0;
        } else if (ptsEffB > ptsEffA + 1e-4) {
          winner = DuelWinner.profileB;
          margin =
              ptsEffA > 0 ? ((ptsEffB - ptsEffA) / ptsEffA) * 100.0 : 100.0;
        } else {
          winner = DuelWinner.tie;
        }
      }

      evaluations.add(ArchetypeEvaluationUi(
        archetype: arch,
        reportA: repA,
        reportB: repB,
        ptsEfficiencyA: ptsEffA,
        ptsEfficiencyB: ptsEffB,
        winner: winner,
        winMarginPercent: margin,
      ));
    }

    return BenchmarkRosterReportUi(evaluations: evaluations);
  }
}
