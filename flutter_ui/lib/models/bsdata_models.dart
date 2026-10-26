import 'simulation_models.dart';

class DataProvenanceUi {
  final String edition;
  final String bsdataRepository;
  final String bsdataRevision;
  final String mfmRepository;
  final String mfmVersion;
  final String mfmRevision;
  final String mfmLastUpdated;
  final String importedAtIso;
  final String attributionNotice;
  final int unresolvedReferencesCount;
  final List<String> warnings;

  const DataProvenanceUi({
    this.edition = 'Warhammer 40,000 11th Edition',
    this.bsdataRepository = 'https://github.com/BSData/wh40k-11e',
    this.bsdataRevision = 'b4dc3f40ca39ae551e480228186e769344a36194',
    this.mfmRepository = 'https://github.com/BSData/wh40k-11e-mfm',
    this.mfmVersion = '1.6',
    this.mfmRevision = '11c45c5f062d26d6468b8b2156c7a8e258013ef5',
    this.mfmLastUpdated = '2026-10-22',
    this.importedAtIso = '2026-10-26T00:00:00Z',
    this.attributionNotice =
        'Community-maintained game data via BSData/wh40k-11e and points from the Munitorum Field Manual (© Games Workshop) via BSData/wh40k-11e-mfm. Unofficial and not affiliated with or endorsed by Games Workshop.',
    this.unresolvedReferencesCount = 0,
    this.warnings = const [],
  });

  factory DataProvenanceUi.fromRustJson(Map<String, dynamic> json) {
    return DataProvenanceUi(
      edition: json['edition']?.toString() ?? 'Warhammer 40,000 11th Edition',
      bsdataRepository: json['bsdata_repository']?.toString() ??
          'https://github.com/BSData/wh40k-11e',
      bsdataRevision: json['bsdata_revision']?.toString() ?? '',
      mfmRepository: json['mfm_repository']?.toString() ??
          'https://github.com/BSData/wh40k-11e-mfm',
      mfmVersion: json['mfm_version']?.toString() ?? '1.6',
      mfmRevision: json['mfm_revision']?.toString() ?? '',
      mfmLastUpdated: json['mfm_last_updated']?.toString() ?? '',
      importedAtIso: json['imported_at_iso']?.toString() ?? '',
      attributionNotice: json['attribution_notice']?.toString() ?? '',
      unresolvedReferencesCount:
          (json['unresolved_references_count'] as num?)?.toInt() ?? 0,
      warnings: (json['warnings'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'edition': edition,
        'bsdata_repository': bsdataRepository,
        'bsdata_revision': bsdataRevision,
        'mfm_repository': mfmRepository,
        'mfm_version': mfmVersion,
        'mfm_revision': mfmRevision,
        'mfm_last_updated': mfmLastUpdated,
        'imported_at_iso': importedAtIso,
        'attribution_notice': attributionNotice,
        'unresolved_references_count': unresolvedReferencesCount,
        'warnings': warnings,
      };
}

class RuleEntryUi {
  final String id;
  final String name;
  final String description;

  const RuleEntryUi({
    required this.id,
    required this.name,
    required this.description,
  });

  factory RuleEntryUi.fromRustJson(Map<String, dynamic> json) {
    return RuleEntryUi(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'name': name,
        'description': description,
      };
}

class EnhancementDataUi {
  final String id;
  final String name;
  final int points;
  final bool isUpgrade;
  final String description;
  final List<String> leaderTo;
  final List<String> supportTo;

  const EnhancementDataUi({
    required this.id,
    required this.name,
    required this.points,
    this.isUpgrade = false,
    this.description = '',
    this.leaderTo = const [],
    this.supportTo = const [],
  });

  factory EnhancementDataUi.fromRustJson(Map<String, dynamic> json) {
    return EnhancementDataUi(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      isUpgrade: json['is_upgrade'] as bool? ?? false,
      description: json['description']?.toString() ?? '',
      leaderTo:
          (json['leader_to'] as List? ?? []).map((e) => e.toString()).toList(),
      supportTo:
          (json['support_to'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'name': name,
        'points': points,
        'is_upgrade': isUpgrade,
        'description': description,
        'leader_to': leaderTo,
        'support_to': supportTo,
      };
}

class DetachmentDataUi {
  final String id;
  final String name;
  final int dpCost;
  final List<String> forceDispositions;
  final String? uniqueTag;
  final List<RuleEntryUi> rules;
  final List<EnhancementDataUi> enhancements;

  const DetachmentDataUi({
    required this.id,
    required this.name,
    this.dpCost = 2,
    this.forceDispositions = const [],
    this.uniqueTag,
    this.rules = const [],
    this.enhancements = const [],
  });

  factory DetachmentDataUi.fromRustJson(Map<String, dynamic> json) {
    return DetachmentDataUi(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dpCost: (json['dp_cost'] as num?)?.toInt() ?? 2,
      forceDispositions: (json['force_dispositions'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      uniqueTag: json['unique_tag']?.toString(),
      rules: (json['rules'] as List? ?? [])
          .map((e) => RuleEntryUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      enhancements: (json['enhancements'] as List? ?? [])
          .map((e) =>
              EnhancementDataUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'name': name,
        'dp_cost': dpCost,
        'force_dispositions': forceDispositions,
        'unique_tag': uniqueTag,
        'rules': rules.map((e) => e.toRustJson()).toList(),
        'enhancements': enhancements.map((e) => e.toRustJson()).toList(),
      };
}

class UnitCostOptionUi {
  final int models;
  final int points;
  final String? description;
  final bool isAddon;

  const UnitCostOptionUi({
    required this.models,
    required this.points,
    this.description,
    this.isAddon = false,
  });

  factory UnitCostOptionUi.fromRustJson(Map<String, dynamic> json) {
    return UnitCostOptionUi(
      models: (json['models'] as num?)?.toInt() ?? 1,
      points: (json['points'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString(),
      isAddon: json['is_addon'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toRustJson() => {
        'models': models,
        'points': points,
        'description': description,
        'is_addon': isAddon,
      };
}

class PricingTierUi {
  final String range;
  final String label;
  final List<UnitCostOptionUi> costs;

  const PricingTierUi({
    required this.range,
    required this.label,
    required this.costs,
  });

  factory PricingTierUi.fromRustJson(Map<String, dynamic> json) {
    return PricingTierUi(
      range: json['range']?.toString() ?? '[1,)',
      label: json['label']?.toString() ?? 'Standard',
      costs: (json['costs'] as List? ?? [])
          .map((e) =>
              UnitCostOptionUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'range': range,
        'label': label,
        'costs': costs.map((e) => e.toRustJson()).toList(),
      };
}

class WargearCostOptionUi {
  final String item;
  final int points;

  const WargearCostOptionUi({
    required this.item,
    required this.points,
  });

  factory WargearCostOptionUi.fromRustJson(Map<String, dynamic> json) {
    return WargearCostOptionUi(
      item: json['item']?.toString() ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toRustJson() => {
        'item': item,
        'points': points,
      };
}

class BsDataUnit {
  final String id;
  final String name;
  final String faction;
  final String factionId;
  final String? groupTitle;
  final bool isLegends;
  final int? pointsCost;
  final UnitUiProfile unitProfile;
  final List<WeaponUiProfile> weapons;
  final List<String> abilities;
  final List<String> categories;
  final String movement;
  final String leadership;
  final int objectiveControl;
  final List<String> unitComposition;
  final List<String> wargearOptions;
  final List<PricingTierUi> pricingTiers;
  final List<WargearCostOptionUi> wargearCosts;
  final List<String> leaderTo;
  final List<String> supportTo;
  final String? transportCapacity;

  const BsDataUnit({
    required this.id,
    required this.name,
    required this.faction,
    this.factionId = '',
    this.groupTitle,
    this.isLegends = false,
    this.pointsCost,
    required this.unitProfile,
    required this.weapons,
    this.abilities = const [],
    this.categories = const [],
    this.movement = '6"',
    this.leadership = '6+',
    this.objectiveControl = 1,
    this.unitComposition = const [],
    this.wargearOptions = const [],
    this.pricingTiers = const [],
    this.wargearCosts = const [],
    this.leaderTo = const [],
    this.supportTo = const [],
    this.transportCapacity,
  });

  bool get isVehicleOrMonster =>
      categories.any(
          (c) => c.toUpperCase() == 'VEHICLE' || c.toUpperCase() == 'MONSTER') ||
      unitProfile.keywords.any(
          (k) => k.toUpperCase() == 'VEHICLE' || k.toUpperCase() == 'MONSTER');

  bool get isCharacter =>
      categories.any((c) => c.toUpperCase() == 'CHARACTER') ||
      unitProfile.keywords.any((k) => k.toUpperCase() == 'CHARACTER');

  bool get isEpicHero =>
      categories.any((c) =>
          c.toUpperCase() == 'EPIC HERO' || c.toUpperCase() == 'EPIC_HERO') ||
      unitProfile.keywords.any((k) =>
          k.toUpperCase() == 'EPIC HERO' || k.toUpperCase() == 'EPIC_HERO');

  bool get isBattleline =>
      categories.any((c) => c.toUpperCase() == 'BATTLELINE') ||
      unitProfile.keywords.any((k) => k.toUpperCase() == 'BATTLELINE');

  bool get isDedicatedTransport =>
      categories.any((c) =>
          c.toUpperCase() == 'DEDICATED TRANSPORT' ||
          c.toUpperCase() == 'DEDICATED_TRANSPORT') ||
      unitProfile.keywords.any((k) =>
          k.toUpperCase() == 'DEDICATED TRANSPORT' ||
          k.toUpperCase() == 'DEDICATED_TRANSPORT');

  bool get isInfantry =>
      categories.any((c) => c.toUpperCase() == 'INFANTRY') ||
      unitProfile.keywords.any((k) => k.toUpperCase() == 'INFANTRY');

  List<UnitCostOptionUi> get legalSizeOptions {
    if (pricingTiers.isNotEmpty && pricingTiers.first.costs.isNotEmpty) {
      return pricingTiers.first.costs.where((c) => !c.isAddon).toList();
    }
    return [
      UnitCostOptionUi(
        models: unitProfile.modelCount,
        points: pointsCost ?? 100,
      ),
    ];
  }

  factory BsDataUnit.fromRustJson(Map<String, dynamic> json) {
    final profileMap = Map<String, dynamic>.from(json['profile'] as Map? ?? {});
    final unitProfile = UnitUiProfile.fromRustJson(profileMap);
    final rawWeapons = (json['weapons'] as List? ?? [])
        .map((w) => WeaponUiProfile.fromRustJson(Map<String, dynamic>.from(w)))
        .toList();
    final pricingTiers = (json['pricing_tiers'] as List? ?? [])
        .map((t) => PricingTierUi.fromRustJson(Map<String, dynamic>.from(t)))
        .toList();
    int? pts = (json['points_cost'] as num?)?.toInt();
    if (pts == null &&
        pricingTiers.isNotEmpty &&
        pricingTiers.first.costs.isNotEmpty) {
      pts = pricingTiers.first.costs.first.points;
    }
    return BsDataUnit(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Unit',
      faction: json['faction_name']?.toString() ?? 'Unknown Faction',
      factionId: json['faction_id']?.toString() ?? '',
      groupTitle: json['group_title']?.toString(),
      isLegends: json['is_legends'] as bool? ?? false,
      pointsCost: pts,
      unitProfile: unitProfile,
      weapons: rawWeapons,
      abilities: (json['abilities'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      categories: (json['categories'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      movement: unitProfile.movement,
      leadership: unitProfile.leadership,
      objectiveControl: unitProfile.objectiveControl,
      unitComposition: (json['unit_composition'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      wargearOptions: (json['wargear_options'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      pricingTiers: pricingTiers,
      wargearCosts: (json['wargear_costs'] as List? ?? [])
          .map((e) =>
              WargearCostOptionUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      leaderTo:
          (json['leader_to'] as List? ?? []).map((e) => e.toString()).toList(),
      supportTo:
          (json['support_to'] as List? ?? []).map((e) => e.toString()).toList(),
      transportCapacity: json['transport_capacity']?.toString(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'name': name,
        'faction_id': factionId.isNotEmpty ? factionId : faction,
        'faction_name': faction,
        'group_title': groupTitle,
        'is_legends': isLegends,
        'points_cost': pointsCost,
        'profile': unitProfile.toRustJson(),
        'weapons': weapons.map((w) => w.toRustJson()).toList(),
        'abilities': abilities,
        'categories': categories,
        'unit_composition': unitComposition,
        'wargear_options': wargearOptions,
        'pricing_tiers': pricingTiers.map((t) => t.toRustJson()).toList(),
        'wargear_costs': wargearCosts.map((w) => w.toRustJson()).toList(),
        'leader_to': leaderTo,
        'support_to': supportTo,
        'transport_capacity': transportCapacity,
      };
}

class BsDataFaction {
  final String id;
  final String name;
  final int? revision;
  final List<RuleEntryUi> armyRules;
  final List<DetachmentDataUi> detachments;
  final List<BsDataUnit> units;

  const BsDataFaction({
    required this.id,
    required this.name,
    this.revision,
    this.armyRules = const [],
    this.detachments = const [],
    required this.units,
  });

  factory BsDataFaction.fromRustJson(Map<String, dynamic> json) {
    return BsDataFaction(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      revision: (json['revision'] as num?)?.toInt(),
      armyRules: (json['army_rules'] as List? ?? [])
          .map((e) => RuleEntryUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      detachments: (json['detachments'] as List? ?? [])
          .map((e) =>
              DetachmentDataUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      units: (json['units'] as List? ?? [])
          .map((e) => BsDataUnit.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'slug': id,
        'name': name,
        'revision': revision,
        'army_rules': armyRules.map((r) => r.toRustJson()).toList(),
        'detachments': detachments.map((d) => d.toRustJson()).toList(),
        'units': units.map((u) => u.toRustJson()).toList(),
      };
}

class CatalogueDatabaseUi {
  final DataProvenanceUi provenance;
  final List<BsDataFaction> factions;

  const CatalogueDatabaseUi({
    required this.provenance,
    required this.factions,
  });

  factory CatalogueDatabaseUi.fromRustJson(Map<String, dynamic> json) {
    return CatalogueDatabaseUi(
      provenance: DataProvenanceUi.fromRustJson(
        Map<String, dynamic>.from(json['provenance'] as Map? ?? {}),
      ),
      factions: (json['factions'] as List? ?? [])
          .map((e) => BsDataFaction.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'provenance': provenance.toRustJson(),
        'factions': factions.map((f) => f.toRustJson()).toList(),
      };
}
