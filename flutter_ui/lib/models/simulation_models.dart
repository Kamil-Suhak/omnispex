enum ReRollOption {
  none,
  ones,
  all;

  String toRustJson() {
    switch (this) {
      case ReRollOption.none:
        return 'none';
      case ReRollOption.ones:
        return 'ones';
      case ReRollOption.all:
        return 'full';
    }
  }

  static ReRollOption fromRustJson(String? raw) {
    switch (raw) {
      case 'ones':
        return ReRollOption.ones;
      case 'full':
      case 'all':
        return ReRollOption.all;
      default:
        return ReRollOption.none;
    }
  }
}

/// Converts a human-readable dice string ("2", "D6", "D6+1", "2D6", "D3+2") to/from Rust's `ValueExpr` JSON.
class DiceJsonHelper {
  static dynamic toRustValueExpr(String expr) {
    final s = expr.trim().toUpperCase().replaceAll(' ', '');
    final n = int.tryParse(s);
    if (n != null) {
      return {'Flat': n};
    }
    if (s == 'D3') return 'D3';
    if (s.startsWith('D3+')) {
      final plus = int.tryParse(s.substring(3)) ?? 1;
      return {'D3Plus': plus};
    }
    if (s == 'D6' || s == '1D6') return 'D6';
    if (s.startsWith('D6+') || s.startsWith('1D6+')) {
      final idx = s.indexOf('+');
      final plus = int.tryParse(s.substring(idx + 1)) ?? 1;
      return {'D6Plus': plus};
    }
    if (s == '2D6') return 'TwoD6';
    if (s.startsWith('2D6+')) {
      final plus = int.tryParse(s.substring(4)) ?? 1;
      return {'TwoD6Plus': plus};
    }
    if (s == '3D6') return 'ThreeD6';
    if (s.startsWith('3D6+')) {
      final plus = int.tryParse(s.substring(4)) ?? 1;
      return {'ThreeD6Plus': plus};
    }
    return {'Flat': 1};
  }

  static String fromRustValueExpr(dynamic json) {
    if (json is String) {
      switch (json) {
        case 'D3':
          return 'D3';
        case 'D6':
          return 'D6';
        case 'TwoD6':
          return '2D6';
        case 'ThreeD6':
          return '3D6';
        default:
          return json;
      }
    }
    if (json is Map) {
      if (json.containsKey('Flat')) return '${json['Flat']}';
      if (json.containsKey('D3Plus')) return 'D3+${json['D3Plus']}';
      if (json.containsKey('D6Plus')) return 'D6+${json['D6Plus']}';
      if (json.containsKey('TwoD6Plus')) return '2D6+${json['TwoD6Plus']}';
      if (json.containsKey('ThreeD6Plus')) return '3D6+${json['ThreeD6Plus']}';
    }
    return '1';
  }

  static Map<String, dynamic> toRustWeaponAbility(String raw) {
    final clean = raw.trim();
    final upper = clean.toUpperCase();
    if (upper == 'TORRENT') return {'type': 'Torrent'};
    if (upper == 'LETHAL HITS') return {'type': 'LethalHits'};
    if (upper.startsWith('SUSTAINED HITS')) {
      final n = int.tryParse(upper.replaceAll('SUSTAINED HITS', '').trim()) ?? 1;
      return {'type': 'SustainedHits', 'data': n};
    }
    if (upper == 'DEVASTATING WOUNDS') return {'type': 'DevastatingWounds'};
    if (upper == 'TWIN-LINKED' || upper == 'TWIN LINKED') {
      return {'type': 'TwinLinked'};
    }
    if (upper == 'BLAST') return {'type': 'Blast'};
    if (upper.startsWith('RAPID FIRE')) {
      final n = int.tryParse(upper.replaceAll('RAPID FIRE', '').trim()) ?? 1;
      return {'type': 'RapidFire', 'data': n};
    }
    if (upper.startsWith('MELTA')) {
      final n = int.tryParse(upper.replaceAll('MELTA', '').trim()) ?? 2;
      return {'type': 'Melta', 'data': n};
    }
    if (upper == 'IGNORES COVER') return {'type': 'IgnoresCover'};
    if (upper == 'HEAVY') return {'type': 'Heavy'};
    if (upper == 'LANCE') return {'type': 'Lance'};
    if (upper == 'INDIRECT FIRE') return {'type': 'IndirectFire'};
    if (upper == 'PRECISION') return {'type': 'Precision'};
    if (upper == 'HAZARDOUS') return {'type': 'Hazardous'};
    if (upper == 'ASSAULT') return {'type': 'Assault'};
    if (upper == 'PISTOL') return {'type': 'Pistol'};
    if (upper == 'CLOSE-QUARTERS' || upper == 'CLOSE QUARTERS') {
      return {'type': 'CloseQuarters'};
    }
    if (upper == 'EXTRA ATTACKS') return {'type': 'ExtraAttacks'};
    if (upper == 'ONE SHOT') return {'type': 'OneShot'};
    if (upper == 'PSYCHIC') return {'type': 'Psychic'};
    if (upper.startsWith('ANTI-')) {
      final rest = clean.substring(5).trim();
      final parts = rest.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final threshStr = parts.last.replaceAll('+', '');
        final thresh = int.tryParse(threshStr) ?? 4;
        final targetStr = parts.sublist(0, parts.length - 1).join(' ');
        return {
          'type': 'Anti',
          'data': {
            'target': toRustKeyword(targetStr),
            'threshold': thresh,
          }
        };
      }
    }
    return {'type': 'Custom', 'data': clean};
  }

  static String fromRustWeaponAbility(dynamic json) {
    if (json is String) return json;
    if (json is Map) {
      final type = json['type']?.toString() ?? '';
      final data = json['data'];
      switch (type) {
        case 'Torrent':
          return 'Torrent';
        case 'LethalHits':
          return 'Lethal Hits';
        case 'SustainedHits':
          return 'Sustained Hits ${data ?? 1}';
        case 'DevastatingWounds':
          return 'Devastating Wounds';
        case 'TwinLinked':
          return 'Twin-Linked';
        case 'Blast':
          return 'Blast';
        case 'RapidFire':
          return 'Rapid Fire ${data ?? 1}';
        case 'Melta':
          return 'Melta ${data ?? 2}';
        case 'IgnoresCover':
          return 'Ignores Cover';
        case 'Heavy':
          return 'Heavy';
        case 'Lance':
          return 'Lance';
        case 'IndirectFire':
          return 'Indirect Fire';
        case 'Precision':
          return 'Precision';
        case 'Hazardous':
          return 'Hazardous';
        case 'Assault':
          return 'Assault';
        case 'Pistol':
          return 'Pistol';
        case 'CloseQuarters':
          return 'Close-Quarters';
        case 'ExtraAttacks':
          return 'Extra Attacks';
        case 'OneShot':
          return 'One Shot';
        case 'Psychic':
          return 'Psychic';
        case 'Anti':
          if (data is Map) {
            final t = fromRustKeyword(data['target']);
            final th = data['threshold'] ?? 4;
            return 'Anti-$t $th+';
          }
          return 'Anti 4+';
        case 'Custom':
          return data?.toString() ?? 'Custom';
        default:
          return type;
      }
    }
    return '';
  }

  static dynamic toRustKeyword(String raw) {
    final u = raw.trim().toUpperCase();
    switch (u) {
      case 'INFANTRY':
        return 'INFANTRY';
      case 'VEHICLE':
        return 'VEHICLE';
      case 'MONSTER':
        return 'MONSTER';
      case 'MOUNTED':
        return 'MOUNTED';
      case 'CHARACTER':
        return 'CHARACTER';
      case 'EPIC HERO':
      case 'EPIC_HERO':
        return 'EPIC_HERO';
      case 'BATTLELINE':
        return 'BATTLELINE';
      case 'DEDICATED TRANSPORT':
      case 'DEDICATED_TRANSPORT':
        return 'DEDICATED_TRANSPORT';
      case 'PSYKER':
        return 'PSYKER';
      case 'FLY':
        return 'FLY';
      case 'SWARM':
        return 'SWARM';
      case 'BEAST':
        return 'BEAST';
      case 'TITANIC':
        return 'TITANIC';
      case 'TOWERING':
        return 'TOWERING';
      case 'WALKER':
        return 'WALKER';
      case 'SMOKE':
        return 'SMOKE';
      case 'GRENADES':
        return 'GRENADES';
      default:
        return {'CUSTOM': raw.trim()};
    }
  }

  static String fromRustKeyword(dynamic json) {
    if (json is String) {
      return json.replaceAll('_', ' ');
    }
    if (json is Map && json.containsKey('CUSTOM')) {
      return json['CUSTOM']?.toString() ?? '';
    }
    return json?.toString() ?? '';
  }

  static Map<String, dynamic> toRustDefensiveAbility(String raw) {
    final s = raw.trim();
    final lower = s.toLowerCase();
    if (lower == 'minus1ap' || lower == 'minusoneap') {
      return {'type': 'MinusOneAp'};
    }
    if (lower == 'minus1towound' || lower.startsWith('minuswound')) {
      return {'type': 'MinusWound', 'data': 1};
    }
    if (lower == 'damagereduction1' || lower.startsWith('reducedamage')) {
      final n = int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      return {'type': 'ReduceDamage', 'data': n};
    }
    if (lower == 'halfdamage') {
      return {'type': 'HalfDamage'};
    }
    if (lower == 'stealth' || lower.startsWith('minushit')) {
      return {'type': 'Stealth'};
    }
    return {'type': 'Stealth'};
  }

  static String fromRustDefensiveAbility(dynamic json) {
    if (json is String) return json;
    if (json is Map) {
      final t = json['type']?.toString() ?? '';
      final d = json['data'];
      switch (t) {
        case 'MinusOneAp':
          return 'MinusOneAp';
        case 'MinusWound':
        case 'MinusOneToWound':
          return 'MinusWound ${d ?? 1}';
        case 'ReduceDamage':
        case 'DamageReduction':
          return 'ReduceDamage ${d ?? 1}';
        case 'HalfDamage':
          return 'HalfDamage';
        case 'Stealth':
        case 'MinusHit':
          return 'Stealth';
        default:
          return t;
      }
    }
    return '';
  }
}

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

  Map<String, dynamic> toRustJson() {
    return {
      'name': name,
      'profile_name': profileName,
      'attack_type': isMelee ? 'Melee' : 'Ranged',
      'range': range,
      'attacks': DiceJsonHelper.toRustValueExpr(attacks),
      'skill': skill,
      'strength': strength,
      'ap': ap.abs(),
      'damage': DiceJsonHelper.toRustValueExpr(damage),
      'abilities': abilities.map(DiceJsonHelper.toRustWeaponAbility).toList(),
    };
  }

  factory WeaponUiProfile.fromRustJson(Map<String, dynamic> json) {
    final attackType = json['attack_type']?.toString() ?? 'Ranged';
    final rawRange = (json['range'] as num?)?.toInt() ?? 0;
    final range = attackType == 'Melee' ? 0 : rawRange;
    final rawSkill = (json['skill'] as num?)?.toInt();
    final rawAp = (json['ap'] as num?)?.toInt() ?? 0;
    final rawAbilities = (json['abilities'] as List? ?? [])
        .map(DiceJsonHelper.fromRustWeaponAbility)
        .where((s) => s.isNotEmpty)
        .toList();
    if (rawSkill == null && !rawAbilities.contains('Torrent')) {
      rawAbilities.add('Torrent');
    }
    return WeaponUiProfile(
      name: json['name']?.toString() ?? 'Weapon',
      profileName: json['profile_name']?.toString() ??
          (range == 0 ? 'Melee' : 'Standard'),
      range: range,
      attacks: DiceJsonHelper.fromRustValueExpr(json['attacks']),
      skill: rawSkill ?? 3,
      strength: (json['strength'] as num?)?.toInt() ?? 4,
      ap: rawAp.abs(),
      damage: DiceJsonHelper.fromRustValueExpr(json['damage']),
      abilities: rawAbilities,
    );
  }
}

class WeaponLoadoutEntry {
  final WeaponUiProfile weapon;
  final int count;
  final bool enabled;

  const WeaponLoadoutEntry({
    required this.weapon,
    required this.count,
    this.enabled = true,
  });

  WeaponLoadoutEntry copyWith({
    WeaponUiProfile? weapon,
    int? count,
    bool? enabled,
  }) {
    return WeaponLoadoutEntry(
      weapon: weapon ?? this.weapon,
      count: count ?? this.count,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toRustJson() => {
        'weapon': weapon.toRustJson(),
        'count': count,
        'enabled': enabled,
      };

  factory WeaponLoadoutEntry.fromRustJson(Map<String, dynamic> json) {
    return WeaponLoadoutEntry(
      weapon: WeaponUiProfile.fromRustJson(
        Map<String, dynamic>.from(json['weapon'] as Map? ?? {}),
      ),
      count: (json['count'] as num?)?.toInt() ?? 1,
      enabled: json['enabled'] as bool? ?? true,
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
  final String movement;
  final String leadership;
  final int objectiveControl;

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
    this.movement = '6"',
    this.leadership = '6+',
    this.objectiveControl = 1,
  });

  int get totalWounds => woundsPerModel * modelCount;
  bool get isSingleModel => modelCount == 1;

  bool get has4PlusInvuln => invuln != null && invuln! <= 4;
  bool get hasMinusWound => defensiveAbilities.any(
      (a) => a.startsWith("MinusWound") || a.toLowerCase() == "minus1towound");
  bool get hasDamageReduction => defensiveAbilities.any((a) =>
      a.startsWith("ReduceDamage") || a.toLowerCase() == "damagereduction1");
  bool get hasHalfDamage => defensiveAbilities
      .any((a) => a == "HalfDamage" || a.toLowerCase() == "halfdamage");
  bool get hasStealth =>
      defensiveAbilities.any((a) => a.toLowerCase() == "stealth");
  bool get hasFnp => fnp != null;

  Map<String, dynamic> toRustJson() {
    final kwJson = keywords.map(DiceJsonHelper.toRustKeyword).toList();
    final defJson =
        defensiveAbilities.map(DiceJsonHelper.toRustDefensiveAbility).toList();
    return {
      'name': name,
      'toughness': toughness,
      'movement': movement,
      'leadership': leadership,
      'objective_control': objectiveControl,
      'model_groups': [
        {
          'count': modelCount,
          'model': {
            'name': name,
            'wounds': woundsPerModel,
            'save': save,
            'invulnerable_save': invuln,
            'feel_no_pain': fnp,
            'defensive_abilities': defJson,
            'keywords': kwJson,
          },
        }
      ],
      'leader': null,
      'keywords': kwJson,
      'defensive_abilities': defJson,
    };
  }

  factory UnitUiProfile.fromRustJson(Map<String, dynamic> json) {
    final groups = json['model_groups'] as List? ?? [];
    Map<String, dynamic> firstGroup = {};
    Map<String, dynamic> firstModel = {};
    int totalCount = 0;
    for (final g in groups) {
      if (g is Map) {
        totalCount += (g['count'] as num?)?.toInt() ?? 0;
        if (firstGroup.isEmpty) {
          firstGroup = Map<String, dynamic>.from(g);
          firstModel = Map<String, dynamic>.from(g['model'] as Map? ?? {});
        }
      }
    }
    if (totalCount <= 0) totalCount = 1;

    final rawKeywords = (json['keywords'] as List? ??
            firstModel['keywords'] as List? ??
            [])
        .map(DiceJsonHelper.fromRustKeyword)
        .where((s) => s.isNotEmpty)
        .toList();

    final rawDef = (json['defensive_abilities'] as List? ??
            firstModel['defensive_abilities'] as List? ??
            [])
        .map(DiceJsonHelper.fromRustDefensiveAbility)
        .where((s) => s.isNotEmpty)
        .toList();

    return UnitUiProfile(
      name: json['name']?.toString() ?? 'Unit',
      toughness: (json['toughness'] as num?)?.toInt() ?? 4,
      save: (firstModel['save'] as num?)?.toInt() ?? 3,
      invuln: (firstModel['invulnerable_save'] as num?)?.toInt(),
      fnp: (firstModel['feel_no_pain'] as num?)?.toInt(),
      woundsPerModel: (firstModel['wounds'] as num?)?.toInt() ?? 1,
      modelCount: totalCount,
      defensiveAbilities: rawDef,
      keywords: rawKeywords,
      movement: json['movement']?.toString() ?? '6"',
      leadership: json['leadership']?.toString() ?? '6+',
      objectiveControl: (json['objective_control'] as num?)?.toInt() ?? 1,
    );
  }
}

class StageProbabilitiesUi {
  final double expectedAttacks;
  final double hitProbability;
  final double critHitProbability;
  final double woundProbability;
  final double critWoundProbability;
  final double unsavedProbabilityGivenNormalWound;
  final double expectedHits;
  final double expectedWounds;
  final double expectedUnsavedWounds;
  final double expectedDamagePerUnsaved;
  final double expectedTotalUnclippedDamage;

  const StageProbabilitiesUi({
    this.expectedAttacks = 0,
    this.hitProbability = 0,
    this.critHitProbability = 0,
    this.woundProbability = 0,
    this.critWoundProbability = 0,
    this.unsavedProbabilityGivenNormalWound = 0,
    this.expectedHits = 0,
    this.expectedWounds = 0,
    this.expectedUnsavedWounds = 0,
    this.expectedDamagePerUnsaved = 0,
    this.expectedTotalUnclippedDamage = 0,
  });

  factory StageProbabilitiesUi.fromRustJson(Map<String, dynamic> json) {
    return StageProbabilitiesUi(
      expectedAttacks: (json['expected_attacks'] as num?)?.toDouble() ?? 0.0,
      hitProbability: (json['hit_probability'] as num?)?.toDouble() ?? 0.0,
      critHitProbability:
          (json['crit_hit_probability'] as num?)?.toDouble() ?? 0.0,
      woundProbability: (json['wound_probability'] as num?)?.toDouble() ?? 0.0,
      critWoundProbability:
          (json['crit_wound_probability'] as num?)?.toDouble() ?? 0.0,
      unsavedProbabilityGivenNormalWound:
          (json['unsaved_probability_given_normal_wound'] as num?)
                  ?.toDouble() ??
              0.0,
      expectedHits: (json['expected_hits'] as num?)?.toDouble() ?? 0.0,
      expectedWounds: (json['expected_wounds'] as num?)?.toDouble() ?? 0.0,
      expectedUnsavedWounds:
          (json['expected_unsaved_wounds'] as num?)?.toDouble() ?? 0.0,
      expectedDamagePerUnsaved:
          (json['expected_damage_per_unsaved'] as num?)?.toDouble() ?? 0.0,
      expectedTotalUnclippedDamage:
          (json['expected_total_unclipped_damage'] as num?)?.toDouble() ?? 0.0,
    );
  }
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

  factory PercentilesUi.fromRustJson(Map<String, dynamic> json) {
    return PercentilesUi(
      p10: (json['p10'] as num?)?.toInt() ?? 0,
      p25: (json['p25'] as num?)?.toInt() ?? 0,
      p50: (json['p50'] as num?)?.toInt() ?? 0,
      p75: (json['p75'] as num?)?.toInt() ?? 0,
      p90: (json['p90'] as num?)?.toInt() ?? 0,
    );
  }
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

  factory KeywordAuditUi.fromRustJson(Map<String, dynamic> json) {
    return KeywordAuditUi(
      lethalDamage: (json['lethal_damage'] as num?)?.toDouble() ?? 0.0,
      sustainedDamage: (json['sustained_damage'] as num?)?.toDouble() ?? 0.0,
      devastatingDamage:
          (json['devastating_damage'] as num?)?.toDouble() ?? 0.0,
      standardDamage: (json['standard_damage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

enum TacticalVerdictUi {
  redIneffective,
  yellowChipContest,
  greenReliableKill;

  static TacticalVerdictUi fromRustJson(String? raw) {
    switch (raw) {
      case 'GreenReliableKill':
        return TacticalVerdictUi.greenReliableKill;
      case 'YellowChipContest':
        return TacticalVerdictUi.yellowChipContest;
      default:
        return TacticalVerdictUi.redIneffective;
    }
  }
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
  final int safeBetDamage80;
  final double bracket50Probability;
  final double wipeProbability;
  final double stdDevKills;
  final double stdDevDamage;
  final TacticalVerdictUi tacticalVerdict;
  final PercentilesUi percentiles;
  final KeywordAuditUi keywordAudit;
  final List<MapEntry<int, double>> killDistribution;
  final List<MapEntry<int, double>> damageDistribution;
  final StageProbabilitiesUi stageProbabilities;
  final String calculationMethod;
  final List<String> unsupportedNotices;

  const SimulationUiReport({
    required this.iterations,
    required this.totalModels,
    required this.totalWounds,
    required this.expectedModelsKilled,
    required this.expectedDamageDealt,
    required this.rawDamageGenerated,
    required this.spilloverDamageLost,
    required this.safeBetKills80,
    required this.safeBetDamage80,
    required this.bracket50Probability,
    required this.wipeProbability,
    required this.stdDevKills,
    required this.stdDevDamage,
    required this.tacticalVerdict,
    required this.percentiles,
    required this.keywordAudit,
    required this.killDistribution,
    required this.damageDistribution,
    this.stageProbabilities = const StageProbabilitiesUi(),
    this.calculationMethod =
        'Exact Analytical Stage Expectations + Monte Carlo Discrete Wound Allocation',
    this.unsupportedNotices = const [],
  });

  factory SimulationUiReport.fromRustJson(Map<String, dynamic> json) {
    List<MapEntry<int, double>> parseDist(dynamic listRaw) {
      final out = <MapEntry<int, double>>[];
      if (listRaw is List) {
        for (final item in listRaw) {
          if (item is List && item.length >= 2) {
            out.add(MapEntry(
              (item[0] as num).toInt(),
              (item[1] as num).toDouble(),
            ));
          }
        }
      }
      return out;
    }

    return SimulationUiReport(
      iterations: (json['iterations'] as num?)?.toInt() ?? 10000,
      totalModels: (json['total_models'] as num?)?.toInt() ?? 1,
      totalWounds: (json['total_wounds'] as num?)?.toInt() ?? 1,
      expectedModelsKilled:
          (json['expected_models_killed'] as num?)?.toDouble() ?? 0.0,
      expectedDamageDealt:
          (json['expected_damage_dealt'] as num?)?.toDouble() ?? 0.0,
      rawDamageGenerated:
          (json['raw_damage_generated'] as num?)?.toDouble() ?? 0.0,
      spilloverDamageLost:
          (json['spillover_damage_lost'] as num?)?.toDouble() ?? 0.0,
      safeBetKills80: (json['safe_bet_kills_80'] as num?)?.toInt() ?? 0,
      safeBetDamage80: (json['safe_bet_damage_80'] as num?)?.toInt() ?? 0,
      bracket50Probability:
          (json['bracket_50_probability'] as num?)?.toDouble() ?? 0.0,
      wipeProbability: (json['wipe_probability'] as num?)?.toDouble() ?? 0.0,
      stdDevKills: (json['std_dev_kills'] as num?)?.toDouble() ?? 0.0,
      stdDevDamage: (json['std_dev_damage'] as num?)?.toDouble() ?? 0.0,
      tacticalVerdict:
          TacticalVerdictUi.fromRustJson(json['tactical_verdict']?.toString()),
      percentiles: PercentilesUi.fromRustJson(
        Map<String, dynamic>.from(json['percentiles'] as Map? ?? {}),
      ),
      keywordAudit: KeywordAuditUi.fromRustJson(
        Map<String, dynamic>.from(json['keyword_audit'] as Map? ?? {}),
      ),
      killDistribution: parseDist(json['kill_distribution']),
      damageDistribution: parseDist(json['damage_distribution']),
      stageProbabilities: StageProbabilitiesUi.fromRustJson(
        Map<String, dynamic>.from(json['stage_probabilities'] as Map? ?? {}),
      ),
      calculationMethod: json['calculation_method']?.toString() ??
          'Exact Analytical Stage Expectations + Monte Carlo Discrete Wound Allocation',
      unsupportedNotices: (json['unsupported_notices'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

// Archetype Benchmark Models
class ArchetypeEntryUi {
  final String id;
  final String label;
  final String description;
  final UnitUiProfile target;

  const ArchetypeEntryUi({
    required this.id,
    required this.label,
    required this.description,
    required this.target,
  });
}

enum DuelWinner { profileA, profileB, tie }

class ArchetypeEvaluationUi {
  final ArchetypeEntryUi archetype;
  final SimulationUiReport reportA;
  final SimulationUiReport? reportB;
  final double ptsEfficiencyA;
  final double? ptsEfficiencyB;
  final DuelWinner winner;
  final double winMarginPercent;

  const ArchetypeEvaluationUi({
    required this.archetype,
    required this.reportA,
    this.reportB,
    required this.ptsEfficiencyA,
    this.ptsEfficiencyB,
    required this.winner,
    this.winMarginPercent = 0.0,
  });
}

class BenchmarkRosterReportUi {
  final List<ArchetypeEvaluationUi> evaluations;

  const BenchmarkRosterReportUi({
    required this.evaluations,
  });
}
