class WeaponUiProfile {
  final String name;
  final String profileName;
  final int range;
  final String attacks;
  final int skill;
  final int strength;
  final int ap;
  final String damage;
  final List<String> abilities;

  const WeaponUiProfile({
    required this.name,
    required this.profileName,
    required this.range,
    required this.attacks,
    required this.skill,
    required this.strength,
    required this.ap,
    required this.damage,
    this.abilities = const [],
  });

  bool get isMelee => range == 0;
  bool get isRanged => range > 0;

  WeaponUiProfile copyWith({
    String? name,
    String? profileName,
    int? range,
    String? attacks,
    int? skill,
    int? strength,
    int? ap,
    String? damage,
    List<String>? abilities,
  }) {
    return WeaponUiProfile(
      name: name ?? this.name,
      profileName: profileName ?? this.profileName,
      range: range ?? this.range,
      attacks: attacks ?? this.attacks,
      skill: skill ?? this.skill,
      strength: strength ?? this.strength,
      ap: ap ?? this.ap,
      damage: damage ?? this.damage,
      abilities: abilities ?? this.abilities,
    );
  }
}

class UnitUiProfile {
  final String name;
  final int toughness;
  final int save;
  final int? invuln;
  final int? fnp;
  final int woundsPerModel;
  final int modelCount;
  final List<String> defensiveAbilities;
  final List<String> keywords;

  const UnitUiProfile({
    required this.name,
    required this.toughness,
    required this.save,
    this.invuln,
    this.fnp,
    required this.woundsPerModel,
    required this.modelCount,
    this.defensiveAbilities = const [],
    this.keywords = const [],
  });

  int get totalWounds => woundsPerModel * modelCount;
}

class PercentilesUi {
  final int p10;
  final int p25;
  final int p50;
  final int p75;
  final int p90;

  const PercentilesUi({
    required this.p10,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p90,
  });
}

class KeywordAuditUi {
  final double lethalDamage;
  final double sustainedDamage;
  final double devastatingDamage;
  final double standardDamage;

  const KeywordAuditUi({
    required this.lethalDamage,
    required this.sustainedDamage,
    required this.devastatingDamage,
    required this.standardDamage,
  });
}

enum TacticalVerdictUi {
  redIneffective,
  yellowChipContest,
  greenReliableKill,
}

class SimulationUiReport {
  final int iterations;
  final int totalModels;
  final int totalWounds;
  final double expectedModelsKilled;
  final double expectedDamageDealt;
  final double rawDamageGenerated;
  final double spilloverDamageLost;
  final int safeBetKills80;
  final double wipeProbability;
  final double stdDevKills;
  final double stdDevDamage;
  final TacticalVerdictUi tacticalVerdict;
  final PercentilesUi percentiles;
  final KeywordAuditUi keywordAudit;
  final List<MapEntry<int, double>> killDistribution;

  const SimulationUiReport({
    required this.iterations,
    required this.totalModels,
    required this.totalWounds,
    required this.expectedModelsKilled,
    required this.expectedDamageDealt,
    required this.rawDamageGenerated,
    required this.spilloverDamageLost,
    required this.safeBetKills80,
    required this.wipeProbability,
    required this.stdDevKills,
    required this.stdDevDamage,
    required this.tacticalVerdict,
    required this.percentiles,
    required this.keywordAudit,
    required this.killDistribution,
  });
}
