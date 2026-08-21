import 'dart:math';
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
    // Ranged Weapons
    const WeaponUiProfile(
      name: "Missile Launcher",
      profileName: "Frag Missile",
      range: 48,
      attacks: "D6",
      skill: 3,
      strength: 4,
      ap: 0,
      damage: "1",
      abilities: ["Blast"],
    ),
    const WeaponUiProfile(
      name: "Missile Launcher",
      profileName: "Krak Missile",
      range: 48,
      attacks: "1",
      skill: 3,
      strength: 9,
      ap: 2,
      damage: "D6",
      abilities: [],
    ),
    const WeaponUiProfile(
      name: "Plasma Incinerator",
      profileName: "Standard",
      range: 24,
      attacks: "2",
      skill: 3,
      strength: 7,
      ap: 2,
      damage: "1",
      abilities: ["Rapid Fire 1"],
    ),
    const WeaponUiProfile(
      name: "Plasma Incinerator",
      profileName: "Supercharge",
      range: 24,
      attacks: "2",
      skill: 3,
      strength: 8,
      ap: 3,
      damage: "2",
      abilities: ["Hazardous", "Rapid Fire 1"],
    ),
    const WeaponUiProfile(
      name: "Meltagun",
      profileName: "Standard",
      range: 12,
      attacks: "1",
      skill: 3,
      strength: 9,
      ap: 4,
      damage: "D6",
      abilities: ["Melta 2"],
    ),
    const WeaponUiProfile(
      name: "Bolt Rifle",
      profileName: "Standard",
      range: 24,
      attacks: "2",
      skill: 3,
      strength: 4,
      ap: 1,
      damage: "1",
      abilities: ["Heavy"],
    ),
    const WeaponUiProfile(
      name: "Storm Bolter",
      profileName: "Standard",
      range: 24,
      attacks: "2",
      skill: 3,
      strength: 4,
      ap: 0,
      damage: "1",
      abilities: ["Rapid Fire 2"],
    ),
    const WeaponUiProfile(
      name: "Lascannon",
      profileName: "Standard",
      range: 48,
      attacks: "1",
      skill: 3,
      strength: 12,
      ap: 3,
      damage: "D6+1",
      abilities: ["Heavy"],
    ),
    const WeaponUiProfile(
      name: "Leman Russ Battle Cannon",
      profileName: "Standard",
      range: 48,
      attacks: "D6+3",
      skill: 4,
      strength: 10,
      ap: 1,
      damage: "3",
      abilities: ["Blast"],
    ),
    const WeaponUiProfile(
      name: "Heavy Bolter",
      profileName: "Standard",
      range: 36,
      attacks: "3",
      skill: 4,
      strength: 5,
      ap: 1,
      damage: "2",
      abilities: ["Sustained Hits 1", "Heavy"],
    ),
    // Melee Weapons
    const WeaponUiProfile(
      name: "Power Fist",
      profileName: "Melee",
      range: 0,
      attacks: "3",
      skill: 3,
      strength: 8,
      ap: 2,
      damage: "2",
      abilities: [],
    ),
    const WeaponUiProfile(
      name: "Thunder Hammer",
      profileName: "Melee",
      range: 0,
      attacks: "3",
      skill: 4,
      strength: 8,
      ap: 2,
      damage: "2",
      abilities: ["Devastating Wounds"],
    ),
    const WeaponUiProfile(
      name: "Astartes Chainsword",
      profileName: "Melee",
      range: 0,
      attacks: "4",
      skill: 3,
      strength: 4,
      ap: 1,
      damage: "1",
      abilities: [],
    ),
    const WeaponUiProfile(
      name: "Master-crafted Power Weapon",
      profileName: "Melee",
      range: 0,
      attacks: "4",
      skill: 2,
      strength: 5,
      ap: 2,
      damage: "2",
      abilities: ["Lance"],
    ),
  ];

  static final List<SquadPreset> defaultSquadPresets = [
    SquadPreset(
      name: "Terminators (4x Storm Bolter + 1x Frag Cyclone)",
      loadout: [
        WeaponLoadoutEntry(weapon: defaultWeapons.firstWhere((w) => w.name == "Storm Bolter"), count: 4),
        WeaponLoadoutEntry(weapon: defaultWeapons.firstWhere((w) => w.profileName == "Frag Missile"), count: 1),
      ],
    ),
    SquadPreset(
      name: "Leman Russ (Battle Cannon + 2x Heavy Bolter + Lascannon)",
      loadout: [
        WeaponLoadoutEntry(weapon: defaultWeapons.firstWhere((w) => w.name == "Leman Russ Battle Cannon"), count: 1),
        WeaponLoadoutEntry(weapon: defaultWeapons.firstWhere((w) => w.name == "Heavy Bolter"), count: 2),
        WeaponLoadoutEntry(weapon: defaultWeapons.firstWhere((w) => w.name == "Lascannon"), count: 1),
      ],
    ),
    SquadPreset(
      name: "Intercessor Squad (5x Bolt Rifle)",
      loadout: [
        WeaponLoadoutEntry(weapon: defaultWeapons.firstWhere((w) => w.name == "Bolt Rifle"), count: 5),
      ],
    ),
    SquadPreset(
      name: "Terminator Melee (5x Power Fist)",
      loadout: [
        WeaponLoadoutEntry(weapon: defaultWeapons.firstWhere((w) => w.name == "Power Fist"), count: 5),
      ],
    ),
  ];

  static final List<ArchetypeEntryUi> defaultArchetypes = [
    const ArchetypeEntryUi(
      id: "geq",
      label: "Chaff / Light Infantry (GEQ)",
      description: "T3 Sv 5+ 1W 10 Models (e.g. Guardsmen, Cultists, Hormagaunts)",
      target: UnitUiProfile(
        name: "Guardsmen Squad",
        toughness: 3,
        save: 5,
        invuln: null,
        fnp: null,
        woundsPerModel: 1,
        modelCount: 10,
        keywords: ["INFANTRY"],
      ),
    ),
    const ArchetypeEntryUi(
      id: "meq",
      label: "Standard Marine (MEQ)",
      description: "T4 Sv 3+ 2W 5 Models (e.g. Intercessors, Legionaries)",
      target: UnitUiProfile(
        name: "Intercessor Squad",
        toughness: 4,
        save: 3,
        invuln: null,
        fnp: null,
        woundsPerModel: 2,
        modelCount: 5,
        keywords: ["INFANTRY"],
      ),
    ),
    const ArchetypeEntryUi(
      id: "teq",
      label: "Heavy Elite Infantry (TEQ)",
      description: "T5 Sv 2+ 4++ 3W 5 Models (e.g. Terminators, Custodes)",
      target: UnitUiProfile(
        name: "Terminator Squad",
        toughness: 5,
        save: 2,
        invuln: 4,
        fnp: null,
        woundsPerModel: 3,
        modelCount: 5,
        keywords: ["INFANTRY"],
      ),
    ),
    const ArchetypeEntryUi(
      id: "transport",
      label: "Light Transport / Skimmer",
      description: "T9 Sv 3+ 10W 1 Model (e.g. Rhino, Raider, Trukk)",
      target: UnitUiProfile(
        name: "Rhino Transport",
        toughness: 9,
        save: 3,
        invuln: null,
        fnp: null,
        woundsPerModel: 10,
        modelCount: 1,
        keywords: ["VEHICLE"],
      ),
    ),
    const ArchetypeEntryUi(
      id: "heavy_armor",
      label: "Heavy Armor / Monster",
      description: "T12 Sv 2+ 16W 1 Model (e.g. Leman Russ, Land Raider, Knight)",
      target: UnitUiProfile(
        name: "Heavy Battle Tank",
        toughness: 12,
        save: 2,
        invuln: null,
        fnp: null,
        woundsPerModel: 16,
        modelCount: 1,
        keywords: ["VEHICLE"],
      ),
    ),
  ];

  static final List<UnitUiProfile> defaultTargets = [
    const UnitUiProfile(
      name: "Ork Boyz (Horde)",
      toughness: 5,
      save: 5,
      invuln: null,
      fnp: null,
      woundsPerModel: 1,
      modelCount: 10,
      keywords: ["INFANTRY"],
    ),
    const UnitUiProfile(
      name: "Intercessor Squad (MEQ)",
      toughness: 4,
      save: 3,
      invuln: null,
      fnp: null,
      woundsPerModel: 2,
      modelCount: 5,
      keywords: ["INFANTRY"],
    ),
    const UnitUiProfile(
      name: "Terminator Squad (TEQ)",
      toughness: 5,
      save: 2,
      invuln: 4,
      fnp: null,
      woundsPerModel: 3,
      modelCount: 5,
      keywords: ["INFANTRY"],
    ),
    const UnitUiProfile(
      name: "Rhino Transport",
      toughness: 9,
      save: 3,
      invuln: null,
      fnp: null,
      woundsPerModel: 10,
      modelCount: 1,
      keywords: ["VEHICLE"],
    ),
    const UnitUiProfile(
      name: "Leman Russ Battle Tank",
      toughness: 11,
      save: 2,
      invuln: null,
      fnp: null,
      woundsPerModel: 13,
      modelCount: 1,
      defensiveAbilities: ["ReduceDamage 1"],
      keywords: ["VEHICLE"],
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
    final rng = Random(seed);
    int totalKills = 0;
    int totalDamage = 0;
    int totalRawDamage = 0;
    int totalLethalDmg = 0;
    int totalSustainedDmg = 0;
    int totalDevDmg = 0;
    int wipes = 0;
    int bracket50Count = 0;

    final effectiveInvuln = defensiveGrantInvuln4
        ? (target.invuln != null ? min(target.invuln!, 4) : 4)
        : target.invuln;

    final effectiveFnp = defensiveGrantFnp5
        ? (target.fnp != null ? min(target.fnp!, 5) : 5)
        : target.fnp;

    final hasEffectiveHalfDamage = target.hasHalfDamage || defensiveGrantHalfDamage;

    final killCounts = List<int>.filled(target.modelCount + 1, 0);
    final damageCounts = <int, int>{};
    final killsSamples = <int>[];
    final damageSamples = <int>[];

    for (int it = 0; it < iterations; it++) {
      final wounds = List<int>.filled(target.modelCount, target.woundsPerModel);
      int roundKills = 0;
      int roundDmg = 0;
      int roundRawDmg = 0;

      for (final entry in loadout) {
        final weapon = entry.weapon;
        final count = entry.count.clamp(1, 100);
        final combinedAbilities = {...weapon.abilities, ...extraAbilities};

        final effectiveStrength = (weapon.strength + bonusStrength).clamp(1, 30);
        int effectiveAp = (weapon.ap + bonusAp).clamp(0, 6);
        if (defensiveArmorOfContempt) {
          effectiveAp = max(0, effectiveAp - 1);
        }

        int livingModels = wounds.where((w) => w > 0).length;

        int attacksPerWeapon = _rollDiceExpr(weapon.attacks, rng);
        if (weapon.isRanged && combinedAbilities.contains("Blast") && livingModels >= 5) {
          attacksPerWeapon += (livingModels ~/ 5);
        }
        if (weapon.isRanged) {
          for (final ab in combinedAbilities) {
            if (ab.startsWith("Rapid Fire") && distance != null && distance <= weapon.range ~/ 2) {
              final bonus = int.tryParse(ab.replaceAll("Rapid Fire", "").trim()) ?? 1;
              attacksPerWeapon += bonus;
            }
          }
        }

        final totalAttacks = attacksPerWeapon * count;

        int hitMod = 0;
        if (weapon.isRanged && combinedAbilities.contains("Heavy") && isStationary) hitMod += 1;
        if (weapon.isRanged && target.hasStealth) hitMod -= 1;
        hitMod = hitMod.clamp(-1, 1);

        final pendingWounds = <_Wound>[];
        final standardHits = <_WoundSource>[];

        for (int a = 0; a < totalAttacks; a++) {
          if (combinedAbilities.contains("Torrent")) {
            standardHits.add(_WoundSource.standard);
            continue;
          }

          int roll = rng.nextInt(6) + 1;
          bool isHit = roll != 1 && (roll == 6 || (roll + hitMod).clamp(1, 6) >= weapon.skill);

          if (!isHit && hitReroll != ReRollOption.none) {
            if (hitReroll == ReRollOption.all || (hitReroll == ReRollOption.ones && roll == 1)) {
              roll = rng.nextInt(6) + 1;
              isHit = roll != 1 && (roll == 6 || (roll + hitMod).clamp(1, 6) >= weapon.skill);
            }
          }

          if (isHit) {
            final isCrit = roll == 6;
            if (isCrit) {
              if (combinedAbilities.contains("Lethal Hits")) {
                pendingWounds.add(_Wound(false, _WoundSource.lethal));
              } else {
                standardHits.add(_WoundSource.standard);
              }

              for (final ab in combinedAbilities) {
                if (ab.startsWith("Sustained Hits")) {
                  final bonus = int.tryParse(ab.replaceAll("Sustained Hits", "").trim()) ?? 1;
                  for (int s = 0; s < bonus; s++) {
                    standardHits.add(_WoundSource.sustained);
                  }
                }
              }
            } else {
              standardHits.add(_WoundSource.standard);
            }
          }
        }

        final reqWound = _requiredWoundRoll(effectiveStrength, target.toughness);
        int woundMod = 0;
        if (weapon.isMelee && combinedAbilities.contains("Lance") && hasCharged) {
          woundMod += 1;
        }
        if (target.hasMinusWound || defensiveMinusWound) {
          woundMod -= 1;
        }
        woundMod = woundMod.clamp(-1, 1);

        final hasTwinLinked = combinedAbilities.contains("Twin-Linked");

        for (final src in standardHits) {
          int roll = rng.nextInt(6) + 1;
          bool isWound = roll != 1 && (roll == 6 || (roll + woundMod).clamp(1, 6) >= reqWound);

          if (!isWound) {
            final shouldReroll = hasTwinLinked || woundReroll == ReRollOption.all || (woundReroll == ReRollOption.ones && roll == 1);
            if (shouldReroll) {
              roll = rng.nextInt(6) + 1;
              isWound = roll != 1 && (roll == 6 || (roll + woundMod).clamp(1, 6) >= reqWound);
            }
          }

          if (isWound) {
            if (roll == 6 && combinedAbilities.contains("Devastating Wounds")) {
              pendingWounds.add(_Wound(true, _WoundSource.devastating));
            } else {
              pendingWounds.add(_Wound(false, src));
            }
          }
        }

        for (final wound in pendingWounds) {
          int allocIdx = -1;
          for (int i = 0; i < wounds.length; i++) {
            if (wounds[i] > 0 && wounds[i] < target.woundsPerModel) {
              allocIdx = i;
              break;
            }
          }
          if (allocIdx == -1) {
            for (int i = 0; i < wounds.length; i++) {
              if (wounds[i] > 0) {
                allocIdx = i;
                break;
              }
            }
          }
          if (allocIdx == -1) break;

          if (!wound.isDevastating) {
            int coverBonus = 0;
            if (weapon.isRanged && targetInCover && !combinedAbilities.contains("Ignores Cover")) {
              if (effectiveAp == 0 && target.save <= 3) {
                coverBonus = 0;
              } else {
                coverBonus = 1;
              }
            }

            final effectiveArmor = max(2, target.save + effectiveAp - coverBonus);
            final chosenSave = effectiveInvuln != null ? min(effectiveArmor, effectiveInvuln) : effectiveArmor;

            final saveRoll = rng.nextInt(6) + 1;
            if (saveRoll != 1 && saveRoll >= chosenSave) continue;
          }

          int dmg = _rollDiceExpr(weapon.damage, rng);
          if (weapon.isRanged) {
            for (final ab in combinedAbilities) {
              if (ab.startsWith("Melta") && distance != null && distance <= weapon.range ~/ 2) {
                final bonus = int.tryParse(ab.replaceAll("Melta", "").trim()) ?? 2;
                dmg += bonus;
              }
            }
          }

          if (hasEffectiveHalfDamage) {
            dmg = ((dmg as double) / 2.0).ceil();
          }

          int totalDmgReduction = 0;
          if (target.hasDamageReduction) totalDmgReduction += 1;
          if (defensiveGrantMinusDamage1 && !target.hasDamageReduction) totalDmgReduction += 1;
          if (totalDmgReduction > 0) {
            dmg = max(1, dmg - totalDmgReduction);
          }

          int effectiveDmg = dmg;
          if (effectiveFnp != null) {
            int taken = 0;
            for (int d = 0; d < dmg; d++) {
              final fnpRoll = rng.nextInt(6) + 1;
              if (fnpRoll < effectiveFnp) taken += 1;
            }
            effectiveDmg = taken;
          }

          totalRawDamage += effectiveDmg;
          roundRawDmg += effectiveDmg;

          if (effectiveDmg > 0) {
            final hp = wounds[allocIdx];
            final applied = min(effectiveDmg, hp);
            wounds[allocIdx] -= applied;
            roundDmg += applied;

            switch (wound.source) {
              case _WoundSource.lethal:
                totalLethalDmg += applied;
                break;
              case _WoundSource.sustained:
                totalSustainedDmg += applied;
                break;
              case _WoundSource.devastating:
                totalDevDmg += applied;
                break;
              case _WoundSource.standard:
                break;
            }

            if (wounds[allocIdx] == 0) {
              roundKills += 1;
            }
          }
        }
      }

      totalKills += roundKills;
      totalDamage += roundDmg;
      if (roundKills < killCounts.length) {
        killCounts[roundKills] += 1;
      }
      damageCounts[roundRawDmg] = (damageCounts[roundRawDmg] ?? 0) + 1;

      if (wounds.every((w) => w == 0)) wipes += 1;
      if (roundDmg >= (target.totalWounds / 2).ceil()) bracket50Count += 1;

      killsSamples.add(roundKills);
      damageSamples.add(roundRawDmg);
    }

    final n = iterations.toDouble();
    final expectedKills = totalKills / n;
    final expectedDamage = totalDamage / n;
    final rawDamage = totalRawDamage / n;
    final spilloverLost = max(0.0, rawDamage - expectedDamage);
    final wipeProb = wipes / n;
    final bracket50Prob = bracket50Count / n;

    final lethalDmg = totalLethalDmg / n;
    final sustainedDmg = totalSustainedDmg / n;
    final devDmg = totalDevDmg / n;
    final stdDmg = max(0.0, expectedDamage - (lethalDmg + sustainedDmg + devDmg));

    final varianceKills = killsSamples.map((k) => pow(k - expectedKills, 2)).reduce((a, b) => a + b) / n;
    final stdDevKills = sqrt(varianceKills);

    final varianceDmg = damageSamples.map((d) => pow(d - rawDamage, 2)).reduce((a, b) => a + b) / n;
    final stdDevDmg = sqrt(varianceDmg);

    killsSamples.sort();
    int getP(double p) => killsSamples[((killsSamples.length - 1) * (p / 100)).round().clamp(0, killsSamples.length - 1)];

    final percentiles = PercentilesUi(
      p10: getP(10),
      p25: getP(25),
      p50: getP(50),
      p75: getP(75),
      p90: getP(90),
    );

    final killDist = <MapEntry<int, double>>[];
    for (int k = 0; k <= target.modelCount; k++) {
      killDist.add(MapEntry(k, killCounts[k] / n));
    }

    final maxDmg = damageCounts.keys.isEmpty ? 0 : damageCounts.keys.reduce(max);
    final damageDist = <MapEntry<int, double>>[];
    for (int d = 0; d <= max(target.totalWounds, maxDmg); d++) {
      damageDist.add(MapEntry(d, (damageCounts[d] ?? 0) / n));
    }

    int safeBetKills80 = 0;
    for (int candidate = target.modelCount; candidate >= 0; candidate--) {
      double sum = 0;
      for (final entry in killDist) {
        if (entry.key >= candidate) sum += entry.value;
      }
      if (sum >= 0.80 - 1e-5) {
        safeBetKills80 = candidate;
        break;
      }
    }

    int safeBetDamage80 = 0;
    damageSamples.sort();
    if (damageSamples.isNotEmpty) {
      final idx80 = ((damageSamples.length - 1) * 0.20).floor().clamp(0, damageSamples.length - 1);
      safeBetDamage80 = damageSamples[idx80];
    }

    final TacticalVerdictUi verdict;
    if (wipeProb >= 0.75) {
      verdict = TacticalVerdictUi.greenReliableKill;
    } else if (expectedKills / target.modelCount >= 0.50 || expectedDamage / target.totalWounds >= 0.50) {
      verdict = TacticalVerdictUi.yellowChipContest;
    } else if (expectedKills / target.modelCount < 0.25 && expectedDamage / target.totalWounds < 0.25) {
      verdict = TacticalVerdictUi.redIneffective;
    } else {
      verdict = TacticalVerdictUi.yellowChipContest;
    }

    return SimulationUiReport(
      iterations: iterations,
      totalModels: target.modelCount,
      totalWounds: target.totalWounds,
      expectedModelsKilled: expectedKills,
      expectedDamageDealt: expectedDamage,
      rawDamageGenerated: rawDamage,
      spilloverDamageLost: spilloverLost,
      safeBetKills80: safeBetKills80,
      safeBetDamage80: safeBetDamage80,
      bracket50Probability: bracket50Prob,
      wipeProbability: wipeProb,
      stdDevKills: stdDevKills,
      stdDevDamage: stdDevDmg,
      tacticalVerdict: verdict,
      percentiles: percentiles,
      keywordAudit: KeywordAuditUi(
        lethalDamage: lethalDmg,
        sustainedDamage: sustainedDmg,
        devastatingDamage: devDmg,
        standardDamage: stdDmg,
      ),
      killDistribution: killDist,
      damageDistribution: damageDist,
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
          margin = ptsEffB > 0 ? ((ptsEffA - ptsEffB) / ptsEffB) * 100.0 : 100.0;
        } else if (ptsEffB > ptsEffA + 1e-4) {
          winner = DuelWinner.profileB;
          margin = ptsEffA > 0 ? ((ptsEffB - ptsEffA) / ptsEffA) * 100.0 : 100.0;
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

  static int _rollDiceExpr(String expr, Random rng) {
    final clean = expr.toUpperCase().replaceAll(" ", "");
    final num = int.tryParse(clean);
    if (num != null) return num;

    if (clean == "D3") return rng.nextInt(3) + 1;
    if (clean == "D6") return rng.nextInt(6) + 1;
    if (clean == "2D6") return (rng.nextInt(6) + 1) + (rng.nextInt(6) + 1);

    if (clean.startsWith("D6+")) {
      final bonus = int.tryParse(clean.replaceFirst("D6+", "")) ?? 0;
      return (rng.nextInt(6) + 1) + bonus;
    }
    if (clean.startsWith("2D6+")) {
      final bonus = int.tryParse(clean.replaceFirst("2D6+", "")) ?? 0;
      return (rng.nextInt(6) + 1) + (rng.nextInt(6) + 1) + bonus;
    }
    if (clean.startsWith("D3+")) {
      final bonus = int.tryParse(clean.replaceFirst("D3+", "")) ?? 0;
      return (rng.nextInt(3) + 1) + bonus;
    }

    return 1;
  }

  static int _requiredWoundRoll(int s, int t) {
    if (s >= 2 * t) return 2;
    if (s > t) return 3;
    if (s == t) return 4;
    if (2 * s <= t) return 6;
    return 5;
  }
}

enum _WoundSource { standard, lethal, sustained, devastating }

class _Wound {
  final bool isDevastating;
  final _WoundSource source;
  _Wound(this.isDevastating, this.source);
}
