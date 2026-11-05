// Strictly isolated Kill Team (2024 / 3rd Edition) UI DTO models.
// Zero imports from Warhammer 40,000 models or services.

class KtWeaponRuleUi {
  final String type;
  final dynamic value;

  const KtWeaponRuleUi({
    required this.type,
    this.value,
  });

  factory KtWeaponRuleUi.fromRustJson(Map<String, dynamic> json) {
    return KtWeaponRuleUi(
      type: json['type']?.toString() ?? 'Custom',
      value: json['data'] ?? json['value'],
    );
  }

  Map<String, dynamic> toRustJson() {
    if (value == null) {
      return {'type': type};
    }
    return {'type': type, 'data': value, 'value': value};
  }

  String get label {
    switch (type) {
      case 'Accurate':
        return 'Accurate ${value ?? 1}';
      case 'Balanced':
        return 'Balanced';
      case 'Ceaseless':
        return 'Ceaseless';
      case 'Relentless':
        return 'Relentless';
      case 'Lethal':
        return 'Lethal ${value ?? 5}+';
      case 'Rending':
        return 'Rending';
      case 'Severe':
        return 'Severe';
      case 'Punishing':
        return 'Punishing';
      case 'Piercing':
        return 'Piercing ${value ?? 1}';
      case 'PiercingCrits':
        return 'Piercing Crits ${value ?? 1}';
      case 'Devastating':
        return 'Devastating ${value ?? 1}';
      case 'Brutal':
        return 'Brutal';
      case 'Shock':
        return 'Shock';
      case 'Stun':
        return 'Stun';
      case 'Saturate':
        return 'Saturate';
      case 'Seek':
        return 'Seek';
      case 'SeekLight':
        return 'Seek Light';
      case 'Silent':
        return 'Silent';
      case 'Torrent':
        return 'Torrent ${value ?? 2}"';
      case 'Blast':
        return 'Blast ${value ?? 2}"';
      case 'Heavy':
        return value != null && value.toString().isNotEmpty
            ? 'Heavy ($value)'
            : 'Heavy';
      case 'Limited':
        return 'Limited ${value ?? 1}';
      case 'Hot':
        return 'Hot';
      case 'Range':
        return 'Range ${value ?? 6}"';
      default:
        return value?.toString() ?? type;
    }
  }
}

class KtWeaponProfileUi {
  final String name;
  final String weaponType; // 'ranged' | 'melee'
  final int attacks;
  final int hitStat;
  final int normalDamage;
  final int criticalDamage;
  final List<KtWeaponRuleUi> rules;

  const KtWeaponProfileUi({
    required this.name,
    required this.weaponType,
    required this.attacks,
    required this.hitStat,
    required this.normalDamage,
    required this.criticalDamage,
    this.rules = const [],
  });

  bool get isRanged => weaponType == 'ranged';
  bool get isMelee => weaponType == 'melee';
  String get damageDisplay => '$normalDamage/$criticalDamage';

  String get rulesSummary =>
      rules.isEmpty ? '—' : rules.map((r) => r.label).join(', ');

  KtWeaponProfileUi copyWith({
    String? name,
    String? weaponType,
    int? attacks,
    int? hitStat,
    int? normalDamage,
    int? criticalDamage,
    List<KtWeaponRuleUi>? rules,
  }) {
    return KtWeaponProfileUi(
      name: name ?? this.name,
      weaponType: weaponType ?? this.weaponType,
      attacks: attacks ?? this.attacks,
      hitStat: hitStat ?? this.hitStat,
      normalDamage: normalDamage ?? this.normalDamage,
      criticalDamage: criticalDamage ?? this.criticalDamage,
      rules: rules ?? this.rules,
    );
  }

  factory KtWeaponProfileUi.fromRustJson(Map<String, dynamic> json) {
    return KtWeaponProfileUi(
      name: json['name']?.toString() ?? 'Weapon',
      weaponType: json['weapon_type']?.toString() ?? 'ranged',
      attacks: (json['attacks'] as num?)?.toInt() ?? 4,
      hitStat: (json['hit'] as num?)?.toInt() ??
          (json['hit_stat'] as num?)?.toInt() ??
          3,
      normalDamage: (json['normal_damage'] as num?)?.toInt() ?? 3,
      criticalDamage: (json['critical_damage'] as num?)?.toInt() ?? 4,
      rules: (json['rules'] as List? ?? [])
          .map((r) => KtWeaponRuleUi.fromRustJson(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'name': name,
        'weapon_type': weaponType,
        'attacks': attacks,
        'hit': hitStat,
        'normal_damage': normalDamage,
        'critical_damage': criticalDamage,
        'rules': rules.map((r) => r.toRustJson()).toList(),
      };
}

class OperativeAbilityUi {
  final String name;
  final String description;
  final int? apCost;

  const OperativeAbilityUi({
    required this.name,
    required this.description,
    this.apCost,
  });

  factory OperativeAbilityUi.fromRustJson(Map<String, dynamic> json) {
    return OperativeAbilityUi(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      apCost: (json['ap_cost'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'name': name,
        'description': description,
        'ap_cost': apCost,
      };
}

class OperativeDatacardUi {
  final String id;
  final String name;
  final String factionId;
  final String factionName;
  final String role;
  final int apl;
  final int movement;
  final int save;
  final int wounds;
  final List<KtWeaponProfileUi> weapons;
  final List<OperativeAbilityUi> abilities;
  final List<String> keywords;
  final int maxPerKillTeam;

  const OperativeDatacardUi({
    required this.id,
    required this.name,
    required this.factionId,
    required this.factionName,
    this.role = 'Warrior',
    this.apl = 2,
    this.movement = 6,
    this.save = 4,
    this.wounds = 8,
    this.weapons = const [],
    this.abilities = const [],
    this.keywords = const [],
    this.maxPerKillTeam = 1,
  });

  bool get isLeader =>
      role.toLowerCase() == 'leader' ||
      keywords.any((k) => k.toUpperCase() == 'LEADER');

  List<KtWeaponProfileUi> get rangedWeapons =>
      weapons.where((w) => w.isRanged).toList();

  List<KtWeaponProfileUi> get meleeWeapons =>
      weapons.where((w) => w.isMelee).toList();

  OperativeDatacardUi copyWith({
    String? id,
    String? name,
    String? factionId,
    String? factionName,
    String? role,
    int? apl,
    int? movement,
    int? save,
    int? wounds,
    List<KtWeaponProfileUi>? weapons,
    List<OperativeAbilityUi>? abilities,
    List<String>? keywords,
    int? maxPerKillTeam,
  }) {
    return OperativeDatacardUi(
      id: id ?? this.id,
      name: name ?? this.name,
      factionId: factionId ?? this.factionId,
      factionName: factionName ?? this.factionName,
      role: role ?? this.role,
      apl: apl ?? this.apl,
      movement: movement ?? this.movement,
      save: save ?? this.save,
      wounds: wounds ?? this.wounds,
      weapons: weapons ?? this.weapons,
      abilities: abilities ?? this.abilities,
      keywords: keywords ?? this.keywords,
      maxPerKillTeam: maxPerKillTeam ?? this.maxPerKillTeam,
    );
  }

  factory OperativeDatacardUi.fromRustJson(Map<String, dynamic> json) {
    return OperativeDatacardUi(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Operative',
      factionId: json['faction_id']?.toString() ?? '',
      factionName: json['faction_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Warrior',
      apl: (json['apl'] as num?)?.toInt() ?? 2,
      movement: (json['movement'] as num?)?.toInt() ?? 6,
      save: (json['save'] as num?)?.toInt() ?? 4,
      wounds: (json['wounds'] as num?)?.toInt() ?? 8,
      weapons: (json['weapons'] as List? ?? [])
          .map((w) =>
              KtWeaponProfileUi.fromRustJson(Map<String, dynamic>.from(w)))
          .toList(),
      abilities: (json['abilities'] as List? ?? [])
          .map((a) =>
              OperativeAbilityUi.fromRustJson(Map<String, dynamic>.from(a)))
          .toList(),
      keywords:
          (json['keywords'] as List? ?? []).map((e) => e.toString()).toList(),
      maxPerKillTeam: (json['max_per_kill_team'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'name': name,
        'faction_id': factionId,
        'faction_name': factionName,
        'role': role,
        'apl': apl,
        'movement': movement,
        'save': save,
        'wounds': wounds,
        'weapons': weapons.map((w) => w.toRustJson()).toList(),
        'abilities': abilities.map((a) => a.toRustJson()).toList(),
        'keywords': keywords,
        'max_per_kill_team': maxPerKillTeam,
      };
}

class KillTeamPloyUi {
  final String id;
  final String name;
  final String ployType; // 'strategy' | 'firefight'
  final int cpCost;
  final String description;

  const KillTeamPloyUi({
    required this.id,
    required this.name,
    required this.ployType,
    this.cpCost = 1,
    required this.description,
  });

  factory KillTeamPloyUi.fromRustJson(Map<String, dynamic> json) {
    return KillTeamPloyUi(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      ployType: json['ploy_type']?.toString() ?? 'strategy',
      cpCost: (json['cp_cost'] as num?)?.toInt() ?? 1,
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'name': name,
        'ploy_type': ployType,
        'cp_cost': cpCost,
        'description': description,
      };
}

class KillTeamEquipmentUi {
  final String id;
  final String name;
  final bool isUniversal;
  final String description;

  const KillTeamEquipmentUi({
    required this.id,
    required this.name,
    this.isUniversal = false,
    required this.description,
  });

  factory KillTeamEquipmentUi.fromRustJson(Map<String, dynamic> json) {
    return KillTeamEquipmentUi(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isUniversal: json['is_universal'] as bool? ?? false,
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'name': name,
        'is_universal': isUniversal,
        'description': description,
      };
}

class KillTeamFactionUi {
  final String id;
  final String slug;
  final String name;
  final String superfaction;
  final List<String> archetypes;
  final List<String> factionRules;
  final List<KillTeamPloyUi> strategyPloys;
  final List<KillTeamPloyUi> firefightPloys;
  final List<KillTeamEquipmentUi> factionEquipment;
  final List<OperativeDatacardUi> operatives;
  final int minTeamSize;
  final int maxTeamSize;
  final int teamSize;

  const KillTeamFactionUi({
    required this.id,
    required this.slug,
    required this.name,
    this.superfaction = 'Imperium',
    this.archetypes = const [],
    this.factionRules = const [],
    this.strategyPloys = const [],
    this.firefightPloys = const [],
    this.factionEquipment = const [],
    this.operatives = const [],
    this.minTeamSize = 6,
    this.maxTeamSize = 6,
    this.teamSize = 6,
  });

  factory KillTeamFactionUi.fromRustJson(Map<String, dynamic> json) {
    return KillTeamFactionUi(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      superfaction: json['superfaction']?.toString() ?? 'Imperium',
      archetypes:
          (json['archetypes'] as List? ?? []).map((e) => e.toString()).toList(),
      factionRules: (json['faction_rules'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      strategyPloys: (json['strategy_ploys'] as List? ?? [])
          .map((p) => KillTeamPloyUi.fromRustJson(Map<String, dynamic>.from(p)))
          .toList(),
      firefightPloys: (json['firefight_ploys'] as List? ?? [])
          .map((p) => KillTeamPloyUi.fromRustJson(Map<String, dynamic>.from(p)))
          .toList(),
      factionEquipment: (json['faction_equipment'] as List? ?? [])
          .map((e) =>
              KillTeamEquipmentUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      operatives: (json['operatives'] as List? ?? [])
          .map((o) =>
              OperativeDatacardUi.fromRustJson(Map<String, dynamic>.from(o)))
          .toList(),
      minTeamSize: (json['min_team_size'] as num?)?.toInt() ?? 6,
      maxTeamSize: (json['max_team_size'] as num?)?.toInt() ?? 6,
      teamSize: (json['team_size'] as num?)?.toInt() ?? 6,
    );
  }
}

class KtShootingContextUi {
  final bool targetInCover;
  final bool targetObscured;
  final bool attackerInjured;
  final int accurateBonus;
  final bool balancedActive;
  final bool ceaselessActive;
  final bool relentlessActive;
  final bool severeActive;
  final bool punishingActive;
  final bool rendingActive;
  final bool saturateActive;

  const KtShootingContextUi({
    this.targetInCover = false,
    this.targetObscured = false,
    this.attackerInjured = false,
    this.accurateBonus = 0,
    this.balancedActive = false,
    this.ceaselessActive = false,
    this.relentlessActive = false,
    this.severeActive = false,
    this.punishingActive = false,
    this.rendingActive = false,
    this.saturateActive = false,
  });

  Map<String, dynamic> toRustJson() => {
        'target_in_cover': targetInCover,
        'target_obscured': targetObscured,
        'attacker_injured': attackerInjured,
        'accurate_bonus': accurateBonus,
        'balanced_active': balancedActive,
        'ceaseless_active': ceaselessActive,
        'relentless_active': relentlessActive,
        'severe_active': severeActive,
        'punishing_active': punishingActive,
        'rending_active': rendingActive,
        'saturate_active': saturateActive,
      };
}

class KtShootingSimulationReportUi {
  final int iterations;
  final int targetWounds;
  final double expectedDamage;
  final double killProbability;
  final double injuryProbability;
  final int safeBetDamage80;
  final double expectedNormalHits;
  final double expectedCriticalHits;
  final double expectedUnblockedNormals;
  final double expectedUnblockedCrits;
  final double expectedSelfMortalWounds;
  final String tacticalVerdict;
  final int p10;
  final int p25;
  final int p50;
  final int p75;
  final int p90;
  final List<MapEntry<int, double>> damageDistribution;

  const KtShootingSimulationReportUi({
    required this.iterations,
    required this.targetWounds,
    required this.expectedDamage,
    required this.killProbability,
    required this.injuryProbability,
    required this.safeBetDamage80,
    required this.expectedNormalHits,
    required this.expectedCriticalHits,
    required this.expectedUnblockedNormals,
    required this.expectedUnblockedCrits,
    required this.expectedSelfMortalWounds,
    required this.tacticalVerdict,
    required this.p10,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p90,
    required this.damageDistribution,
  });

  factory KtShootingSimulationReportUi.fromRustJson(Map<String, dynamic> json) {
    final pct = Map<String, dynamic>.from(json['percentiles'] as Map? ?? {});
    final dist = <MapEntry<int, double>>[];
    final rawDist = json['damage_distribution'];
    if (rawDist is List) {
      for (final item in rawDist) {
        if (item is List && item.length >= 2) {
          dist.add(MapEntry(
            (item[0] as num).toInt(),
            (item[1] as num).toDouble(),
          ));
        }
      }
    }
    return KtShootingSimulationReportUi(
      iterations: (json['iterations'] as num?)?.toInt() ?? 5000,
      targetWounds: (json['target_wounds'] as num?)?.toInt() ?? 8,
      expectedDamage: (json['expected_damage'] as num?)?.toDouble() ?? 0.0,
      killProbability: (json['kill_probability'] as num?)?.toDouble() ?? 0.0,
      injuryProbability:
          (json['injury_probability'] as num?)?.toDouble() ?? 0.0,
      safeBetDamage80: (json['safe_bet_damage_80'] as num?)?.toInt() ?? 0,
      expectedNormalHits:
          (json['expected_normal_hits'] as num?)?.toDouble() ?? 0.0,
      expectedCriticalHits:
          (json['expected_critical_hits'] as num?)?.toDouble() ?? 0.0,
      expectedUnblockedNormals:
          (json['expected_unblocked_normals'] as num?)?.toDouble() ?? 0.0,
      expectedUnblockedCrits:
          (json['expected_unblocked_crits'] as num?)?.toDouble() ?? 0.0,
      expectedSelfMortalWounds:
          (json['expected_self_mortal_wounds'] as num?)?.toDouble() ?? 0.0,
      tacticalVerdict:
          json['tactical_verdict']?.toString() ?? 'RedIneffective',
      p10: (pct['p10'] as num?)?.toInt() ?? 0,
      p25: (pct['p25'] as num?)?.toInt() ?? 0,
      p50: (pct['p50'] as num?)?.toInt() ?? 0,
      p75: (pct['p75'] as num?)?.toInt() ?? 0,
      p90: (pct['p90'] as num?)?.toInt() ?? 0,
      damageDistribution: dist,
    );
  }
}

class KtFightContextUi {
  final int attackerStartingWounds;
  final int defenderStartingWounds;
  final bool attackerInjured;
  final bool defenderInjured;
  final int attackerSupportFriends;
  final int defenderSupportFriends;

  const KtFightContextUi({
    this.attackerStartingWounds = 0,
    this.defenderStartingWounds = 0,
    this.attackerInjured = false,
    this.defenderInjured = false,
    this.attackerSupportFriends = 0,
    this.defenderSupportFriends = 0,
  });

  Map<String, dynamic> toRustJson() => {
        'attacker_starting_wounds': attackerStartingWounds,
        'defender_starting_wounds': defenderStartingWounds,
        'attacker_injured': attackerInjured,
        'defender_injured': defenderInjured,
        'attacker_combat_support': attackerSupportFriends,
        'defender_combat_support': defenderSupportFriends,
      };
}

class KtFightSimulationReportUi {
  final int iterations;
  final double expectedDamageToDefender;
  final double expectedDamageToAttacker;
  final double defenderKillProbability;
  final double attackerSurvivesProbability;
  final double mutualSurvivalProbability;
  final double cleanKillZeroRetaliationProbability;
  final String tacticalVerdict;
  final List<MapEntry<int, double>> damageToDefenderDistribution;
  final List<MapEntry<int, double>> damageToAttackerDistribution;

  const KtFightSimulationReportUi({
    required this.iterations,
    required this.expectedDamageToDefender,
    required this.expectedDamageToAttacker,
    required this.defenderKillProbability,
    required this.attackerSurvivesProbability,
    required this.mutualSurvivalProbability,
    required this.cleanKillZeroRetaliationProbability,
    required this.tacticalVerdict,
    required this.damageToDefenderDistribution,
    required this.damageToAttackerDistribution,
  });

  factory KtFightSimulationReportUi.fromRustJson(Map<String, dynamic> json) {
    List<MapEntry<int, double>> parseDist(dynamic raw) {
      final out = <MapEntry<int, double>>[];
      if (raw is List) {
        for (final item in raw) {
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

    return KtFightSimulationReportUi(
      iterations: (json['iterations'] as num?)?.toInt() ?? 5000,
      expectedDamageToDefender:
          (json['expected_damage_to_defender'] as num?)?.toDouble() ?? 0.0,
      expectedDamageToAttacker:
          (json['expected_damage_to_attacker'] as num?)?.toDouble() ?? 0.0,
      defenderKillProbability:
          (json['defender_kill_probability'] as num?)?.toDouble() ?? 0.0,
      attackerSurvivesProbability:
          (json['attacker_survives_probability'] as num?)?.toDouble() ?? 0.0,
      mutualSurvivalProbability:
          (json['mutual_survival_probability'] as num?)?.toDouble() ?? 0.0,
      cleanKillZeroRetaliationProbability:
          (json['clean_kill_zero_retaliation_probability'] as num?)
                  ?.toDouble() ??
              0.0,
      tacticalVerdict:
          json['tactical_verdict']?.toString() ?? 'RedIneffective',
      damageToDefenderDistribution:
          parseDist(json['damage_to_defender_distribution']),
      damageToAttackerDistribution:
          parseDist(json['damage_to_attacker_distribution']),
    );
  }
}

class SelectedOperativeEntryUi {
  final String entryId;
  final String operativeId;
  final String operativeName;
  final String customCallsign;
  final String role;
  final bool isLeader;
  final List<String> selectedWeapons;
  final String notes;

  const SelectedOperativeEntryUi({
    required this.entryId,
    required this.operativeId,
    required this.operativeName,
    this.customCallsign = '',
    this.role = 'Warrior',
    this.isLeader = false,
    this.selectedWeapons = const [],
    this.notes = '',
  });

  SelectedOperativeEntryUi copyWith({
    String? customCallsign,
    bool? isLeader,
    List<String>? selectedWeapons,
    String? notes,
  }) {
    return SelectedOperativeEntryUi(
      entryId: entryId,
      operativeId: operativeId,
      operativeName: operativeName,
      customCallsign: customCallsign ?? this.customCallsign,
      role: role,
      isLeader: isLeader ?? this.isLeader,
      selectedWeapons: selectedWeapons ?? this.selectedWeapons,
      notes: notes ?? this.notes,
    );
  }

  factory SelectedOperativeEntryUi.fromRustJson(Map<String, dynamic> json) {
    return SelectedOperativeEntryUi(
      entryId: json['entry_id']?.toString() ?? '',
      operativeId: json['operative_id']?.toString() ?? '',
      operativeName: json['operative_name']?.toString() ?? '',
      customCallsign: json['custom_callsign']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Warrior',
      isLeader: json['is_leader'] as bool? ?? false,
      selectedWeapons: (json['selected_weapons'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toRustJson() => {
        'entry_id': entryId,
        'operative_id': operativeId,
        'operative_name': operativeName,
        'custom_callsign': customCallsign,
        'role': role,
        'is_leader': isLeader,
        'selected_weapons': selectedWeapons,
        'notes': notes,
      };
}

class SelectedEquipmentEntryUi {
  final String equipmentId;
  final String name;
  final bool isUniversal;

  const SelectedEquipmentEntryUi({
    required this.equipmentId,
    required this.name,
    this.isUniversal = false,
  });

  factory SelectedEquipmentEntryUi.fromRustJson(Map<String, dynamic> json) {
    return SelectedEquipmentEntryUi(
      equipmentId: json['equipment_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isUniversal: json['is_universal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toRustJson() => {
        'equipment_id': equipmentId,
        'name': name,
        'is_universal': isUniversal,
      };
}

class KillTeamRosterUi {
  final String id;
  final String name;
  final String factionId;
  final String factionName;
  final String selectedPrimaryArchetype;
  final List<SelectedOperativeEntryUi> operatives;
  final List<SelectedEquipmentEntryUi> equipment;
  final String notes;
  final String createdAtIso;
  final String updatedAtIso;

  const KillTeamRosterUi({
    required this.id,
    required this.name,
    required this.factionId,
    required this.factionName,
    this.selectedPrimaryArchetype = '',
    this.operatives = const [],
    this.equipment = const [],
    this.notes = '',
    required this.createdAtIso,
    required this.updatedAtIso,
  });

  KillTeamRosterUi copyWith({
    String? name,
    String? factionId,
    String? factionName,
    String? selectedPrimaryArchetype,
    List<SelectedOperativeEntryUi>? operatives,
    List<SelectedEquipmentEntryUi>? equipment,
    String? notes,
    String? updatedAtIso,
  }) {
    return KillTeamRosterUi(
      id: id,
      name: name ?? this.name,
      factionId: factionId ?? this.factionId,
      factionName: factionName ?? this.factionName,
      selectedPrimaryArchetype:
          selectedPrimaryArchetype ?? this.selectedPrimaryArchetype,
      operatives: operatives ?? this.operatives,
      equipment: equipment ?? this.equipment,
      notes: notes ?? this.notes,
      createdAtIso: createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  factory KillTeamRosterUi.fromRustJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc().toIso8601String();
    return KillTeamRosterUi(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Kill Team Roster',
      factionId: json['faction_id']?.toString() ?? '',
      factionName: json['faction_name']?.toString() ?? '',
      selectedPrimaryArchetype:
          json['selected_primary_archetype']?.toString() ?? '',
      operatives: (json['operatives'] as List? ?? [])
          .map((o) => SelectedOperativeEntryUi.fromRustJson(
              Map<String, dynamic>.from(o)))
          .toList(),
      equipment: (json['equipment'] as List? ?? [])
          .map((e) => SelectedEquipmentEntryUi.fromRustJson(
              Map<String, dynamic>.from(e)))
          .toList(),
      notes: json['notes']?.toString() ?? '',
      createdAtIso: json['created_at_iso']?.toString() ?? now,
      updatedAtIso: json['updated_at_iso']?.toString() ?? now,
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'name': name,
        'faction_id': factionId,
        'faction_name': factionName,
        'selected_primary_archetype': selectedPrimaryArchetype,
        'operatives': operatives.map((o) => o.toRustJson()).toList(),
        'equipment': equipment.map((e) => e.toRustJson()).toList(),
        'notes': notes,
        'created_at_iso': createdAtIso,
        'updated_at_iso': updatedAtIso,
      };
}

class KtValidationIssueUi {
  final String severity;
  final String code;
  final String message;

  const KtValidationIssueUi({
    required this.severity,
    required this.code,
    required this.message,
  });

  factory KtValidationIssueUi.fromRustJson(Map<String, dynamic> json) {
    return KtValidationIssueUi(
      severity: json['severity']?.toString() ?? 'error',
      code: json['code']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

class KtRosterValidationReportUi {
  final bool isValid;
  final int operativeCount;
  final int minOperatives;
  final int maxOperatives;
  final int leaderCount;
  final int equipmentCount;
  final int maxEquipment;
  final List<KtValidationIssueUi> violations;
  final List<KtValidationIssueUi> warnings;

  const KtRosterValidationReportUi({
    required this.isValid,
    required this.operativeCount,
    required this.minOperatives,
    required this.maxOperatives,
    required this.leaderCount,
    required this.equipmentCount,
    required this.maxEquipment,
    this.violations = const [],
    this.warnings = const [],
  });

  factory KtRosterValidationReportUi.fromRustJson(Map<String, dynamic> json) {
    return KtRosterValidationReportUi(
      isValid: json['is_valid'] as bool? ?? false,
      operativeCount: (json['operative_count'] as num?)?.toInt() ?? 0,
      minOperatives: (json['min_operatives'] as num?)?.toInt() ?? 6,
      maxOperatives: (json['max_operatives'] as num?)?.toInt() ?? 6,
      leaderCount: (json['leader_count'] as num?)?.toInt() ?? 0,
      equipmentCount: (json['equipment_count'] as num?)?.toInt() ?? 0,
      maxEquipment: (json['max_equipment'] as num?)?.toInt() ?? 4,
      violations: (json['violations'] as List? ?? [])
          .map((v) =>
              KtValidationIssueUi.fromRustJson(Map<String, dynamic>.from(v)))
          .toList(),
      warnings: (json['warnings'] as List? ?? [])
          .map((w) =>
              KtValidationIssueUi.fromRustJson(Map<String, dynamic>.from(w)))
          .toList(),
    );
  }
}
