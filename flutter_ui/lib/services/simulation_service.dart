import 'dart:math';
import '../models/simulation_models.dart';

class SimulationService {
  static final List<WeaponUiProfile> defaultWeapons = [
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
    int? distance,
    int iterations = 10000,
  }) {
    final rng = Random();
    int totalKills = 0;
    int totalDamage = 0;
    int totalRawDamage = 0;
    int totalLethalDmg = 0;
    int totalSustainedDmg = 0;
    int totalDevDmg = 0;
    int wipes = 0;

    final killCounts = List<int>.filled(target.modelCount + 1, 0);
    final killsSamples = <int>[];
    final damageSamples = <double>[];

    for (int it = 0; it < iterations; it++) {
      final wounds = List<int>.filled(target.modelCount, target.woundsPerModel);
      int livingModels = target.modelCount;

      int attacks = _rollDiceExpr(weapon.attacks, rng);
      if (weapon.abilities.contains("Blast") && livingModels >= 5) {
        attacks += (livingModels ~/ 5);
      }
      for (final ab in weapon.abilities) {
        if (ab.startsWith("Rapid Fire") && distance != null && distance <= weapon.range ~/ 2) {
          final bonus = int.tryParse(ab.replaceAll("Rapid Fire", "").trim()) ?? 1;
          attacks += bonus;
        }
      }

      int hitMod = 0;
      if (weapon.abilities.contains("Heavy") && isStationary) hitMod += 1;
      if (target.defensiveAbilities.contains("Stealth") && weapon.range > 0) hitMod -= 1;
      hitMod = hitMod.clamp(-1, 1);

      final pendingWounds = <_Wound>[];
      final standardHits = <_WoundSource>[];

      for (int a = 0; a < attacks; a++) {
        if (weapon.abilities.contains("Torrent")) {
          standardHits.add(_WoundSource.standard);
          continue;
        }

        final roll = rng.nextInt(6) + 1;
        if (roll == 1) continue;

        final isCrit = roll == 6;
        final modified = (roll + hitMod).clamp(1, 6);

        if (isCrit || modified >= weapon.skill) {
          if (isCrit) {
            if (weapon.abilities.contains("Lethal Hits")) {
              pendingWounds.add(_Wound(false, _WoundSource.lethal));
            } else {
              standardHits.add(_WoundSource.standard);
            }

            for (final ab in weapon.abilities) {
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

      final reqWound = _requiredWoundRoll(weapon.strength, target.toughness);
      int woundMod = 0;
      if (weapon.abilities.contains("Lance") && hasCharged) woundMod += 1;
      for (final def in target.defensiveAbilities) {
        if (def.startsWith("MinusWound")) {
          final minus = int.tryParse(def.replaceAll("MinusWound", "").trim()) ?? 1;
          woundMod -= minus;
        }
      }
      woundMod = woundMod.clamp(-1, 1);

      for (final src in standardHits) {
        int roll = rng.nextInt(6) + 1;
        bool isWound = roll != 1 && (roll == 6 || (roll + woundMod).clamp(1, 6) >= reqWound);

        if (!isWound && weapon.abilities.contains("Twin-Linked")) {
          roll = rng.nextInt(6) + 1;
          isWound = roll != 1 && (roll == 6 || (roll + woundMod).clamp(1, 6) >= reqWound);
        }

        if (isWound) {
          if (roll == 6 && weapon.abilities.contains("Devastating Wounds")) {
            pendingWounds.add(_Wound(true, _WoundSource.devastating));
          } else {
            pendingWounds.add(_Wound(false, src));
          }
        }
      }

      int roundKills = 0;
      int roundDmg = 0;

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
          if (targetInCover && !weapon.abilities.contains("Ignores Cover")) {
            if (weapon.ap == 0 && target.save <= 3) {
              coverBonus = 0;
            } else {
              coverBonus = 1;
            }
          }

          final effectiveArmor = max(2, target.save + weapon.ap - coverBonus);
          final chosenSave = target.invuln != null ? min(effectiveArmor, target.invuln!) : effectiveArmor;

          final saveRoll = rng.nextInt(6) + 1;
          if (saveRoll != 1 && saveRoll >= chosenSave) continue;
        }

        int dmg = _rollDiceExpr(weapon.damage, rng);
        for (final ab in weapon.abilities) {
          if (ab.startsWith("Melta") && distance != null && distance <= weapon.range ~/ 2) {
            final bonus = int.tryParse(ab.replaceAll("Melta", "").trim()) ?? 2;
            dmg += bonus;
          }
        }

        for (final def in target.defensiveAbilities) {
          if (def.startsWith("ReduceDamage")) {
            final red = int.tryParse(def.replaceAll("ReduceDamage", "").trim()) ?? 1;
            dmg = max(1, dmg - red);
          }
        }

        int effectiveDmg = dmg;
        if (target.fnp != null) {
          int taken = 0;
          for (int d = 0; d < dmg; d++) {
            final fnpRoll = rng.nextInt(6) + 1;
            if (fnpRoll < target.fnp!) taken += 1;
          }
          effectiveDmg = taken;
        }

        totalRawDamage += effectiveDmg;

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

      totalKills += roundKills;
      totalDamage += roundDmg;
      if (roundKills < killCounts.length) {
        killCounts[roundKills] += 1;
      }
      if (wounds.every((w) => w == 0)) wipes += 1;

      killsSamples.add(roundKills);
      damageSamples.add(roundDmg.toDouble());
    }

    final n = iterations.toDouble();
    final expectedKills = totalKills / n;
    final expectedDamage = totalDamage / n;
    final rawDamage = totalRawDamage / n;
    final spilloverLost = max(0.0, rawDamage - expectedDamage);
    final wipeProb = wipes / n;

    final lethalDmg = totalLethalDmg / n;
    final sustainedDmg = totalSustainedDmg / n;
    final devDmg = totalDevDmg / n;
    final stdDmg = max(0.0, expectedDamage - (lethalDmg + sustainedDmg + devDmg));

    final varianceKills = killsSamples.map((k) => pow(k - expectedKills, 2)).reduce((a, b) => a + b) / n;
    final stdDevKills = sqrt(varianceKills);

    final varianceDmg = damageSamples.map((d) => pow(d - expectedDamage, 2)).reduce((a, b) => a + b) / n;
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

    int safeBet80 = 0;
    for (int candidate = target.modelCount; candidate >= 0; candidate--) {
      double sum = 0;
      for (final entry in killDist) {
        if (entry.key >= candidate) sum += entry.value;
      }
      if (sum >= 0.80 - 1e-5) {
        safeBet80 = candidate;
        break;
      }
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
      safeBetKills80: safeBet80,
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
    );
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
