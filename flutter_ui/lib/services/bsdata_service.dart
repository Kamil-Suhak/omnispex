import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../bridge/omnispex_rust_bridge.dart';
import '../models/bsdata_models.dart';
import '../models/simulation_models.dart';

class BsDataService {
  static List<BsDataFaction> _bundledFactions = _initBundledFactions();
  static DataProvenanceUi _provenance = const DataProvenanceUi();
  static bool _fullBundleLoaded = false;

  static List<BsDataFaction> get bundledFactions => _bundledFactions;
  static DataProvenanceUi get provenance => _provenance;
  static bool get isFullBundleLoaded => _fullBundleLoaded;

  static Future<void> loadFull11eCatalogueBundle() async {
    if (_fullBundleLoaded) return;
    try {
      final rawJson =
          await rootBundle.loadString('assets/data/wh40k_11e_bundle.json');
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        final db = CatalogueDatabaseUi.fromRustJson(decoded);
        if (db.factions.isNotEmpty) {
          _bundledFactions = db.factions;
          _provenance = db.provenance;
          _fullBundleLoaded = true;
        }
      }
    } catch (_) {
      // Fallback to built-in factions in test environments without assets
    }
  }

  static void resetToDefaultFallback() {
    _bundledFactions = _initBundledFactions();
    _provenance = const DataProvenanceUi();
    _fullBundleLoaded = false;
  }

  static BsDataFaction importCatalogueJson(String jsonStr) {
    final BsDataFaction parsed = OmnispexRustBridge.isReady
        ? OmnispexRustBridge.parseBsDataCatalogue(jsonStr)
        : parseFactionJson(jsonStr);
    final updated = List<BsDataFaction>.from(_bundledFactions);
    final idx = updated.indexWhere((f) =>
        f.id == parsed.id ||
        f.name.toLowerCase() == parsed.name.toLowerCase());
    if (idx >= 0) {
      updated[idx] = parsed;
    } else {
      updated.insert(0, parsed);
    }
    _bundledFactions = updated;
    return parsed;
  }

  static BsDataFaction? findFaction(String idOrName) {
    final clean = idOrName.trim().toLowerCase();
    for (final f in _bundledFactions) {
      if (f.id.toLowerCase() == clean ||
          f.name.toLowerCase() == clean ||
          f.name.toLowerCase().contains(clean)) {
        return f;
      }
    }
    return null;
  }

  static List<String> get availableFactions {
    if (_fullBundleLoaded && _bundledFactions.isNotEmpty) {
      final names = _bundledFactions.map((f) => f.name).toList();
      return ["All Factions", ...names];
    }
    return [
      "All Factions",
      "Space Marines",
      "Astra Militarum",
      "Orks",
      "Necrons",
      "Tyranids",
      "Chaos Space Marines",
      "Adeptus Custodes",
      "T'au Empire",
      "Aeldari",
    ];
  }

  static List<BsDataUnit> searchUnits({
    String query = "",
    String factionFilter = "All Factions",
    String categoryFilter = "All Types",
    bool includeLegends = false,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final results = <BsDataUnit>[];

    for (final faction in _bundledFactions) {
      if (factionFilter != "All Factions") {
        if (factionFilter == "Space Marines" && faction.id == "sm-1") {
          // matched fallback
        } else if (factionFilter == "Chaos Space Marines" &&
            faction.id == "csm-1") {
          // matched fallback
        } else if (factionFilter == "Astra Militarum" &&
            faction.id == "am-1") {
          // matched fallback
        } else if (factionFilter == "Orks" && faction.id == "ork-1") {
          // matched fallback
        } else if (factionFilter == "Necrons" && faction.id == "nec-1") {
          // matched fallback
        } else if (factionFilter == "Tyranids" && faction.id == "tyr-1") {
          // matched fallback
        } else if (factionFilter == "Adeptus Custodes" &&
            faction.id == "cust-1") {
          // matched fallback
        } else if (factionFilter == "T'au Empire" && faction.id == "tau-1") {
          // matched fallback
        } else if (factionFilter == "Aeldari" && faction.id == "ael-1") {
          // matched fallback
        } else if (faction.id.toLowerCase() == factionFilter.toLowerCase() ||
            faction.name.toLowerCase() == factionFilter.toLowerCase()) {
          // exact match
        } else if (faction.name
                .toLowerCase()
                .contains(factionFilter.toLowerCase()) &&
            !(factionFilter.toLowerCase() == "space marines" &&
                faction.name.toLowerCase().contains("chaos"))) {
          // matched
        } else {
          continue;
        }
      }

      for (final unit in faction.units) {
        if (!includeLegends && unit.isLegends) {
          continue;
        }
        if (categoryFilter == "Infantry" && !unit.isInfantry) {
          continue;
        }
        if (categoryFilter == "Vehicle / Monster" && !unit.isVehicleOrMonster) {
          continue;
        }
        if (categoryFilter == "Character" && !unit.isCharacter) {
          continue;
        }
        if (categoryFilter == "Battleline" && !unit.isBattleline) {
          continue;
        }

        if (cleanQuery.isEmpty) {
          results.add(unit);
          continue;
        }

        final matchesName = unit.name.toLowerCase().contains(cleanQuery);
        final matchesFaction = unit.faction.toLowerCase().contains(cleanQuery);
        final matchesCategory =
            unit.categories.any((c) => c.toLowerCase().contains(cleanQuery));
        final matchesWeapon =
            unit.weapons.any((w) => w.name.toLowerCase().contains(cleanQuery));
        final matchesAbility =
            unit.abilities.any((a) => a.toLowerCase().contains(cleanQuery));

        if (matchesName ||
            matchesFaction ||
            matchesCategory ||
            matchesWeapon ||
            matchesAbility) {
          results.add(unit);
        }
      }
    }

    return results;
  }

  static BsDataUnit? findUnitById(String id) {
    for (final f in _bundledFactions) {
      for (final u in f.units) {
        if (u.id == id) return u;
      }
    }
    return null;
  }

  static BsDataFaction parseFactionJson(String jsonStr) {
    final data = jsonDecode(jsonStr);
    final cat = data['catalogue'] as Map<String, dynamic>? ?? {};

    final factionId = cat['id']?.toString() ?? 'custom-faction';
    final factionName = cat['name']?.toString() ?? 'Custom Faction';
    final revision = cat['revision'] != null
        ? int.tryParse(cat['revision'].toString())
        : null;

    final units = <BsDataUnit>[];

    final sharedEntries = cat['sharedSelectionEntries'] as List? ?? [];
    for (final entry in sharedEntries) {
      final u = _parseUnitEntry(entry, factionName);
      if (u != null) units.add(u);
    }

    final rootEntries = cat['selectionEntries'] as List? ?? [];
    for (final entry in rootEntries) {
      final u = _parseUnitEntry(entry, factionName);
      if (u != null && !units.any((existing) => existing.name == u.name)) {
        units.add(u);
      }
    }

    return BsDataFaction(
      id: factionId,
      name: factionName,
      revision: revision,
      units: units,
    );
  }

  static BsDataUnit? _parseUnitEntry(dynamic entryJson, String faction) {
    if (entryJson is! Map<String, dynamic>) return null;
    final type = entryJson['type']?.toString() ?? '';
    if (type == 'upgrade') return null;

    final name = entryJson['name']?.toString().trim() ?? 'Unknown Unit';
    final id = entryJson['id']?.toString() ?? name;

    // Find Unit Profile
    Map<String, dynamic>? unitProfileJson;
    final profiles = entryJson['profiles'] as List? ?? [];
    for (final p in profiles) {
      if (p is Map<String, dynamic> && p['typeName'] == 'Unit') {
        unitProfileJson = p;
        break;
      }
    }

    unitProfileJson ??= _findFirstProfileByType(entryJson, 'Unit');
    if (unitProfileJson == null) return null;

    final chars = _extractCharacteristics(unitProfileJson);
    final m = chars['M'] ?? '6"';
    final t = int.tryParse(chars['T'] ?? '4') ?? 4;
    final svRaw = chars['Sv'] ?? '3+';
    final sv = int.tryParse(svRaw.replaceAll('+', '')) ?? 3;
    final w = int.tryParse(chars['W'] ?? '2') ?? 2;
    final ld = chars['LD'] ?? '6+';
    final oc = int.tryParse(chars['OC'] ?? '1') ?? 1;

    final invRaw = chars['InSv'] ?? '';
    int? invuln;
    if (invRaw.isNotEmpty && invRaw != '-') {
      invuln = int.tryParse(invRaw.replaceAll('+', ''));
    }

    // Categories
    final categories = <String>[];
    final catLinks = entryJson['categoryLinks'] as List? ?? [];
    for (final c in catLinks) {
      if (c is Map<String, dynamic> && c['name'] != null) {
        categories.add(c['name'].toString().trim());
      }
    }

    // Points
    int? points;
    final costs = entryJson['costs'] as List? ?? [];
    for (final c in costs) {
      if (c is Map<String, dynamic> && c['name'] == 'pts') {
        points = (c['value'] is num)
            ? (c['value'] as num).toInt()
            : int.tryParse(c['value'].toString());
      }
    }

    // Abilities & Defensive Rules Pattern Matching
    final abilities = <String>[];
    _extractAbilitiesRecursive(entryJson, abilities);

    final defensiveRules = <String>[];
    int? fnp;

    for (final ab in abilities) {
      final lower = ab.toLowerCase();
      if (lower.contains('worsen the armour penetration') ||
          lower.contains('worsen the armor penetration')) {
        if (!defensiveRules.contains('minus1Ap')) {
          defensiveRules.add('minus1Ap');
        }
      }
      if (lower.contains('subtract 1 from the damage characteristic')) {
        if (!defensiveRules.contains('damageReduction1')) {
          defensiveRules.add('damageReduction1');
        }
      }
      if (lower.contains('halve the damage characteristic')) {
        if (!defensiveRules.contains('halfDamage')) {
          defensiveRules.add('halfDamage');
        }
      }
      if (lower.contains('subtract 1 from the wound roll')) {
        if (!defensiveRules.contains('minus1ToWound')) {
          defensiveRules.add('minus1ToWound');
        }
      }
      if (lower.contains('stealth') ||
          lower.contains('subtract 1 from the hit roll')) {
        if (!defensiveRules.contains('stealth')) {
          defensiveRules.add('stealth');
        }
      }

      final fnpMatch =
          RegExp(r'(?:feel no pain|fnp)\s*(\d)\+', caseSensitive: false)
              .firstMatch(ab);
      if (fnpMatch != null && fnp == null) {
        fnp = int.tryParse(fnpMatch.group(1)!);
      }

      final invMatch =
          RegExp(r'(\d)\+\s+invulnerable save', caseSensitive: false)
              .firstMatch(ab);
      if (invMatch != null && invuln == null) {
        invuln = int.tryParse(invMatch.group(1)!);
      }
    }

    if (categories.any((c) => c.toLowerCase() == 'stealth')) {
      if (!defensiveRules.contains('stealth')) defensiveRules.add('stealth');
    }

    // Weapons
    final weapons = <WeaponUiProfile>[];
    _extractWeaponsRecursive(entryJson, weapons);

    final modelCount = categories.any(
            (c) => c.toLowerCase() == 'vehicle' || c.toLowerCase() == 'monster')
        ? 1
        : 5;

    final unitProfile = UnitUiProfile(
      name: name,
      toughness: t,
      save: sv,
      invuln: invuln,
      fnp: fnp,
      woundsPerModel: w,
      modelCount: modelCount,
      keywords: categories,
      defensiveAbilities: defensiveRules,
    );

    return BsDataUnit(
      id: id,
      name: name,
      faction: faction,
      pointsCost: points,
      unitProfile: unitProfile,
      weapons: weapons,
      abilities: abilities,
      categories: categories,
      movement: m,
      leadership: ld,
      objectiveControl: oc,
    );
  }

  static Map<String, String> _extractCharacteristics(
      Map<String, dynamic> profileJson) {
    final map = <String, String>{};
    final chars = profileJson['characteristics'] as List? ?? [];
    for (final c in chars) {
      if (c is Map<String, dynamic>) {
        final k = c['name']?.toString();
        final v = c['\$text']?.toString() ?? '';
        if (k != null) map[k] = v;
      }
    }
    return map;
  }

  static Map<String, dynamic>? _findFirstProfileByType(
      dynamic obj, String typeName) {
    if (obj is Map<String, dynamic>) {
      if (obj['typeName'] == typeName) return obj;
      for (final v in obj.values) {
        final found = _findFirstProfileByType(v, typeName);
        if (found != null) return found;
      }
    } else if (obj is List) {
      for (final item in obj) {
        final found = _findFirstProfileByType(item, typeName);
        if (found != null) return found;
      }
    }
    return null;
  }

  static void _extractAbilitiesRecursive(dynamic obj, List<String> list) {
    if (obj is Map<String, dynamic>) {
      if (obj['typeName'] == 'Abilities') {
        final name = obj['name']?.toString() ?? '';
        final chars = _extractCharacteristics(obj);
        final desc = chars['Description'] ?? '';
        final full = desc.isEmpty ? name : '$name: $desc';
        if (!list.contains(full)) list.add(full);
      }
      for (final v in obj.values) {
        _extractAbilitiesRecursive(v, list);
      }
    } else if (obj is List) {
      for (final item in obj) {
        _extractAbilitiesRecursive(item, list);
      }
    }
  }

  static void _extractWeaponsRecursive(
      dynamic obj, List<WeaponUiProfile> list) {
    if (obj is Map<String, dynamic>) {
      final typeName = obj['typeName']?.toString() ?? '';
      if (typeName == 'Ranged Weapons' || typeName == 'Melee Weapons') {
        final w = _parseWeaponProfile(obj, typeName == 'Melee Weapons');
        if (w != null &&
            !list.any((existing) =>
                existing.name == w.name &&
                existing.profileName == w.profileName)) {
          list.add(w);
        }
      }
      for (final v in obj.values) {
        _extractWeaponsRecursive(v, list);
      }
    } else if (obj is List) {
      for (final item in obj) {
        _extractWeaponsRecursive(item, list);
      }
    }
  }

  static WeaponUiProfile? _parseWeaponProfile(
      Map<String, dynamic> json, bool isMelee) {
    final name = json['name']?.toString().trim() ?? 'Weapon';
    final chars = _extractCharacteristics(json);

    final rangeRaw = chars['Range'] ?? (isMelee ? '0' : '24"');
    final isMeleeRange =
        isMelee || rangeRaw.toLowerCase() == 'melee' || rangeRaw == '-';
    final range =
        isMeleeRange ? 0 : (int.tryParse(rangeRaw.replaceAll('"', '')) ?? 24);

    final attacks = chars['A'] ?? '1';
    final skillRaw = chars['WS'] ?? chars['BS'] ?? '3+';
    final isTorrent = skillRaw == 'N/A' || skillRaw == '-';
    final skill =
        isTorrent ? 7 : (int.tryParse(skillRaw.replaceAll('+', '')) ?? 3);

    final strength = int.tryParse(chars['S'] ?? '4') ?? 4;
    final ap =
        (int.tryParse(chars['AP']?.replaceAll('-', '') ?? '0') ?? 0).abs();
    final damage = chars['D'] ?? '1';

    final abilities = <String>[];
    if (isTorrent) abilities.add('Torrent');

    final kwStr = chars['Keywords'] ?? '';
    if (kwStr.isNotEmpty && kwStr != '-') {
      for (final token in kwStr.split(RegExp(r'[,;]'))) {
        final t = token.trim();
        if (t.isNotEmpty && !abilities.contains(t)) {
          abilities.add(t);
        }
      }
    }

    String mainName = name;
    String profileName = isMelee ? "Melee" : "Standard";
    if (name.contains(" - ")) {
      final parts = name.split(" - ");
      mainName = parts[0].trim();
      profileName = parts.sublist(1).join(" - ").trim();
    }

    return WeaponUiProfile(
      name: mainName,
      profileName: profileName,
      range: range,
      attacks: attacks,
      skill: skill == 7 ? 3 : skill,
      strength: strength,
      ap: ap,
      damage: damage,
      abilities: abilities,
    );
  }

  static List<BsDataFaction> _initBundledFactions() {
    return const [
      // 1. SPACE MARINES
      BsDataFaction(
        id: "sm-1",
        name: "Imperium - Space Marines",
        armyRules: [
          RuleEntryUi(
            id: "oath_of_moment",
            name: "Oath of Moment",
            description:
                "At the start of your Command phase, select one enemy unit for Oath of Moment.",
          ),
        ],
        detachments: [
          DetachmentDataUi(
            id: "gladius_task_force",
            name: "Gladius Task Force",
            dpCost: 2,
            forceDispositions: ["Flexible Assault", "Tactical Reserve"],
            rules: [
              RuleEntryUi(
                id: "combat_doctrines",
                name: "Combat Doctrines",
                description:
                    "Select Devastator, Tactical, or Assault Doctrine in your Command phase.",
              ),
            ],
            enhancements: [
              EnhancementDataUi(
                id: "fire_discipline",
                name: "Fire Discipline",
                points: 25,
                description:
                    "ADEPTUS ASTARTES model only. Grants Sustained Hits 1.",
              ),
              EnhancementDataUi(
                id: "chapter_master_upgrade",
                name: "Chapter Master (Upgrade)",
                points: 40,
                isUpgrade: true,
                description:
                    "CAPTAIN model only. Upgrades bearer to Chapter Master.",
              ),
            ],
          ),
          DetachmentDataUi(
            id: "first_company_spearhead",
            name: "1st Company Auxiliary",
            dpCost: 1,
            forceDispositions: ["Elite Vanguard"],
            rules: [
              RuleEntryUi(
                id: "extremis_threat",
                name: "Extremis-level Threat",
                description:
                    "Once per battle, re-roll Wound rolls against your Oath of Moment target.",
              ),
            ],
            enhancements: [
              EnhancementDataUi(
                id: "the_imperiums_sword",
                name: "The Imperium's Sword",
                points: 20,
                description: "Add 1 to the Attacks characteristic of melee weapons.",
              ),
            ],
          ),
        ],
        units: [
          BsDataUnit(
            id: "sm_captain_terminator",
            name: "Captain in Terminator Armour",
            faction: "Space Marines",
            factionId: "sm-1",
            pointsCost: 95,
            unitProfile: UnitUiProfile(
              name: "Captain in Terminator Armour",
              toughness: 5,
              save: 2,
              invuln: 4,
              woundsPerModel: 6,
              modelCount: 1,
              keywords: ["INFANTRY", "CHARACTER", "IMPERIUM", "TERMINATOR"],
            ),
            movement: '5"',
            leadership: '6+',
            objectiveControl: 1,
            abilities: [
              "Rites of Battle: Reduce CP cost of a Stratagem targeting this unit by 1CP.",
              "Unstoppable Valour: Re-roll Charge rolls made for this unit."
            ],
            categories: ["Infantry", "Character", "Terminator", "Imperium"],
            leaderTo: ["Terminator Squad"],
            weapons: [
              WeaponUiProfile(
                  name: "Storm Bolter",
                  profileName: "Standard",
                  range: 24,
                  attacks: "2",
                  skill: 2,
                  strength: 4,
                  ap: 0,
                  damage: "1",
                  abilities: ["Rapid Fire 2"]),
              WeaponUiProfile(
                  name: "Relic Weapon",
                  profileName: "Melee",
                  range: 0,
                  attacks: "6",
                  skill: 2,
                  strength: 5,
                  ap: 2,
                  damage: "2"),
            ],
          ),
          BsDataUnit(
            id: "sm_terminators",
            name: "Terminator Squad",
            faction: "Space Marines",
            pointsCost: 175,
            unitProfile: UnitUiProfile(
              name: "Terminator Squad",
              toughness: 5,
              save: 2,
              invuln: 4,
              woundsPerModel: 3,
              modelCount: 5,
              keywords: ["INFANTRY", "IMPERIUM", "TERMINATOR"],
            ),
            movement: '5"',
            leadership: '6+',
            objectiveControl: 1,
            abilities: [
              "Teleport Homer: Rapid ingress can be used for 0CP on this unit.",
              "Fury of the First: +1 to Hit against Oath of Moment targets."
            ],
            categories: ["Infantry", "Terminator", "Imperium"],
            weapons: [
              WeaponUiProfile(
                  name: "Storm Bolter",
                  profileName: "Standard",
                  range: 24,
                  attacks: "2",
                  skill: 3,
                  strength: 4,
                  ap: 0,
                  damage: "1",
                  abilities: ["Rapid Fire 2"]),
              WeaponUiProfile(
                  name: "Cyclone Missile Launcher",
                  profileName: "Frag",
                  range: 36,
                  attacks: "2D6",
                  skill: 3,
                  strength: 4,
                  ap: 0,
                  damage: "1",
                  abilities: ["Blast"]),
              WeaponUiProfile(
                  name: "Cyclone Missile Launcher",
                  profileName: "Krak",
                  range: 36,
                  attacks: "2",
                  skill: 3,
                  strength: 9,
                  ap: 2,
                  damage: "D6"),
              WeaponUiProfile(
                  name: "Power Fist",
                  profileName: "Melee",
                  range: 0,
                  attacks: "3",
                  skill: 3,
                  strength: 8,
                  ap: 2,
                  damage: "2"),
              WeaponUiProfile(
                  name: "Chainfist",
                  profileName: "Melee",
                  range: 0,
                  attacks: "3",
                  skill: 4,
                  strength: 8,
                  ap: 2,
                  damage: "2",
                  abilities: ["Anti-Vehicle 3+"]),
            ],
          ),
          BsDataUnit(
            id: "sm_intercessors",
            name: "Intercessor Squad",
            faction: "Space Marines",
            pointsCost: 80,
            unitProfile: UnitUiProfile(
              name: "Intercessor Squad",
              toughness: 4,
              save: 3,
              woundsPerModel: 2,
              modelCount: 5,
              keywords: ["INFANTRY", "IMPERIUM", "TACTICUS"],
            ),
            movement: '6"',
            leadership: '6+',
            objectiveControl: 2,
            abilities: [
              "Sticky Objectives: An objective marker remains under your control even if you move away."
            ],
            categories: ["Infantry", "Battleline", "Imperium"],
            weapons: [
              WeaponUiProfile(
                  name: "Bolt Rifle",
                  profileName: "Standard",
                  range: 24,
                  attacks: "2",
                  skill: 3,
                  strength: 4,
                  ap: 1,
                  damage: "1",
                  abilities: ["Assault", "Heavy"]),
              WeaponUiProfile(
                  name: "Astartes Grenade Launcher",
                  profileName: "Frag",
                  range: 24,
                  attacks: "D3",
                  skill: 3,
                  strength: 4,
                  ap: 0,
                  damage: "1",
                  abilities: ["Blast"]),
              WeaponUiProfile(
                  name: "Astartes Grenade Launcher",
                  profileName: "Krak",
                  range: 24,
                  attacks: "1",
                  skill: 3,
                  strength: 9,
                  ap: 2,
                  damage: "D3"),
              WeaponUiProfile(
                  name: "Close Combat Weapon",
                  profileName: "Melee",
                  range: 0,
                  attacks: "3",
                  skill: 3,
                  strength: 4,
                  ap: 0,
                  damage: "1"),
            ],
          ),
          BsDataUnit(
            id: "sm_eradicators",
            name: "Eradicator Squad",
            faction: "Space Marines",
            pointsCost: 95,
            unitProfile: UnitUiProfile(
              name: "Eradicator Squad",
              toughness: 6,
              save: 3,
              woundsPerModel: 3,
              modelCount: 3,
              keywords: ["INFANTRY", "IMPERIUM", "GRAVIS"],
            ),
            movement: '5"',
            leadership: '6+',
            objectiveControl: 1,
            abilities: [
              "Total Obliteration: Each time a model in this unit makes a ranged attack against a Monster or Vehicle, re-roll the Hit roll, Wound roll, and Damage roll."
            ],
            categories: ["Infantry", "Gravis", "Imperium"],
            weapons: [
              WeaponUiProfile(
                  name: "Melta Rifle",
                  profileName: "Standard",
                  range: 18,
                  attacks: "1",
                  skill: 3,
                  strength: 9,
                  ap: 4,
                  damage: "D6",
                  abilities: ["Melta 2"]),
              WeaponUiProfile(
                  name: "Heavy Melta Rifle",
                  profileName: "Standard",
                  range: 18,
                  attacks: "1",
                  skill: 3,
                  strength: 9,
                  ap: 4,
                  damage: "D6+1",
                  abilities: ["Heavy", "Melta 2"]),
              WeaponUiProfile(
                  name: "Multi-melta",
                  profileName: "Standard",
                  range: 18,
                  attacks: "2",
                  skill: 3,
                  strength: 9,
                  ap: 4,
                  damage: "D6",
                  abilities: ["Heavy", "Melta 2"]),
            ],
          ),
          BsDataUnit(
            id: "sm_land_raider",
            name: "Land Raider",
            faction: "Space Marines",
            pointsCost: 240,
            unitProfile: UnitUiProfile(
              name: "Land Raider",
              toughness: 12,
              save: 2,
              woundsPerModel: 16,
              modelCount: 1,
              keywords: ["VEHICLE", "TRANSPORT", "IMPERIUM", "SMOKE"],
            ),
            movement: '10"',
            leadership: '6+',
            objectiveControl: 5,
            abilities: [
              "Assault Ramp: Units disembarking after this model made a Normal move can still declare a charge."
            ],
            categories: ["Vehicle", "Transport", "Imperium"],
            weapons: [
              WeaponUiProfile(
                  name: "Godhammer Lascannon",
                  profileName: "Standard",
                  range: 48,
                  attacks: "2",
                  skill: 3,
                  strength: 12,
                  ap: 3,
                  damage: "D6+1"),
              WeaponUiProfile(
                  name: "Twin Heavy Bolter",
                  profileName: "Standard",
                  range: 36,
                  attacks: "3",
                  skill: 3,
                  strength: 5,
                  ap: 1,
                  damage: "2",
                  abilities: ["Twin-Linked", "Sustained Hits 1"]),
              WeaponUiProfile(
                  name: "Hunter-Killer Missile",
                  profileName: "Standard",
                  range: 48,
                  attacks: "1",
                  skill: 2,
                  strength: 14,
                  ap: 3,
                  damage: "D6"),
              WeaponUiProfile(
                  name: "Armoured Tracks",
                  profileName: "Melee",
                  range: 0,
                  attacks: "6",
                  skill: 4,
                  strength: 8,
                  ap: 0,
                  damage: "1"),
            ],
          ),
          BsDataUnit(
            id: "sm_redemptor",
            name: "Redemptor Dreadnought",
            faction: "Space Marines",
            pointsCost: 210,
            unitProfile: UnitUiProfile(
              name: "Redemptor Dreadnought",
              toughness: 10,
              save: 2,
              woundsPerModel: 12,
              modelCount: 1,
              keywords: ["VEHICLE", "WALKER", "IMPERIUM", "DREADNOUGHT"],
              defensiveAbilities: ["damageReduction1"],
            ),
            movement: '8"',
            leadership: '6+',
            objectiveControl: 4,
            abilities: [
              "Duty Eternal: Each time an attack is allocated to this model, subtract 1 from the Damage characteristic of that attack."
            ],
            categories: ["Vehicle", "Walker", "Imperium"],
            weapons: [
              WeaponUiProfile(
                  name: "Macro Plasma Incinerator",
                  profileName: "Standard",
                  range: 36,
                  attacks: "D6+1",
                  skill: 3,
                  strength: 8,
                  ap: 3,
                  damage: "2",
                  abilities: ["Blast"]),
              WeaponUiProfile(
                  name: "Macro Plasma Incinerator",
                  profileName: "Supercharge",
                  range: 36,
                  attacks: "D6+1",
                  skill: 3,
                  strength: 9,
                  ap: 4,
                  damage: "3",
                  abilities: ["Blast", "Hazardous"]),
              WeaponUiProfile(
                  name: "Heavy Onslaught Gatling Cannon",
                  profileName: "Standard",
                  range: 24,
                  attacks: "12",
                  skill: 3,
                  strength: 6,
                  ap: 0,
                  damage: "1",
                  abilities: ["Devastating Wounds"]),
              WeaponUiProfile(
                  name: "Redemptor Fist",
                  profileName: "Melee",
                  range: 0,
                  attacks: "5",
                  skill: 3,
                  strength: 12,
                  ap: 2,
                  damage: "D6+1"),
            ],
          ),
        ],
      ),

      // 2. ASTRA MILITARUM
      BsDataFaction(
        id: "am-1",
        name: "Astra Militarum",
        units: [
          BsDataUnit(
            id: "am_guardsmen",
            name: "Cadian Shock Troops",
            faction: "Astra Militarum",
            pointsCost: 60,
            unitProfile: UnitUiProfile(
              name: "Cadian Shock Troops",
              toughness: 3,
              save: 5,
              woundsPerModel: 1,
              modelCount: 10,
              keywords: ["INFANTRY", "IMPERIUM", "BATTLELINE"],
            ),
            movement: '6"',
            leadership: '7+',
            objectiveControl: 2,
            abilities: ["Shock Troops: Sticky objectives."],
            categories: ["Infantry", "Battleline", "Imperium"],
            weapons: [
              WeaponUiProfile(
                  name: "Lasgun",
                  profileName: "Standard",
                  range: 24,
                  attacks: "2",
                  skill: 4,
                  strength: 3,
                  ap: 0,
                  damage: "1",
                  abilities: ["Rapid Fire 1"]),
              WeaponUiProfile(
                  name: "Plasma Gun",
                  profileName: "Standard",
                  range: 24,
                  attacks: "1",
                  skill: 4,
                  strength: 7,
                  ap: 2,
                  damage: "1",
                  abilities: ["Rapid Fire 1"]),
              WeaponUiProfile(
                  name: "Plasma Gun",
                  profileName: "Supercharge",
                  range: 24,
                  attacks: "1",
                  skill: 4,
                  strength: 8,
                  ap: 3,
                  damage: "2",
                  abilities: ["Rapid Fire 1", "Hazardous"]),
              WeaponUiProfile(
                  name: "Melta Gun",
                  profileName: "Standard",
                  range: 12,
                  attacks: "1",
                  skill: 4,
                  strength: 9,
                  ap: 4,
                  damage: "D6",
                  abilities: ["Melta 2"]),
              WeaponUiProfile(
                  name: "Close Combat Weapon",
                  profileName: "Melee",
                  range: 0,
                  attacks: "1",
                  skill: 4,
                  strength: 3,
                  ap: 0,
                  damage: "1"),
            ],
          ),
          BsDataUnit(
            id: "am_leman_russ",
            name: "Leman Russ Battle Tank",
            faction: "Astra Militarum",
            pointsCost: 170,
            unitProfile: UnitUiProfile(
              name: "Leman Russ Battle Tank",
              toughness: 11,
              save: 2,
              woundsPerModel: 13,
              modelCount: 1,
              keywords: ["VEHICLE", "SQUADRON", "IMPERIUM", "SMOKE"],
            ),
            movement: '10"',
            leadership: '7+',
            objectiveControl: 3,
            abilities: [
              "Armoured Spearhead: Re-roll Hit rolls of 1 against targets on objectives."
            ],
            categories: ["Vehicle", "Imperium"],
            weapons: [
              WeaponUiProfile(
                  name: "Leman Russ Battle Cannon",
                  profileName: "Standard",
                  range: 48,
                  attacks: "D6+3",
                  skill: 4,
                  strength: 10,
                  ap: 1,
                  damage: "3",
                  abilities: ["Blast"]),
              WeaponUiProfile(
                  name: "Demolisher Battle Cannon",
                  profileName: "Standard",
                  range: 24,
                  attacks: "D6+3",
                  skill: 4,
                  strength: 14,
                  ap: 3,
                  damage: "D6",
                  abilities: ["Blast"]),
              WeaponUiProfile(
                  name: "Lascannon",
                  profileName: "Standard",
                  range: 48,
                  attacks: "1",
                  skill: 4,
                  strength: 12,
                  ap: 3,
                  damage: "D6+1",
                  abilities: ["Heavy"]),
              WeaponUiProfile(
                  name: "Heavy Bolter",
                  profileName: "Standard",
                  range: 36,
                  attacks: "3",
                  skill: 4,
                  strength: 5,
                  ap: 1,
                  damage: "2",
                  abilities: ["Heavy", "Sustained Hits 1"]),
              WeaponUiProfile(
                  name: "Plasma Cannon",
                  profileName: "Supercharge",
                  range: 36,
                  attacks: "D3",
                  skill: 4,
                  strength: 8,
                  ap: 3,
                  damage: "2",
                  abilities: ["Blast", "Hazardous", "Heavy"]),
              WeaponUiProfile(
                  name: "Armoured Tracks",
                  profileName: "Melee",
                  range: 0,
                  attacks: "6",
                  skill: 4,
                  strength: 7,
                  ap: 0,
                  damage: "1"),
            ],
          ),
          BsDataUnit(
            id: "am_rogal_dorn",
            name: "Rogal Dorn Battle Tank",
            faction: "Astra Militarum",
            pointsCost: 240,
            unitProfile: UnitUiProfile(
              name: "Rogal Dorn Battle Tank",
              toughness: 12,
              save: 2,
              woundsPerModel: 18,
              modelCount: 1,
              keywords: ["VEHICLE", "SQUADRON", "IMPERIUM", "SMOKE"],
              defensiveAbilities: ["damageReduction1"],
            ),
            movement: '10"',
            leadership: '7+',
            objectiveControl: 5,
            abilities: [
              "Ablative Armour: Once per battle, reduce damage of an attack to 0."
            ],
            categories: ["Vehicle", "Imperium"],
            weapons: [
              WeaponUiProfile(
                  name: "Oppressor Cannon",
                  profileName: "Standard",
                  range: 72,
                  attacks: "D6+3",
                  skill: 4,
                  strength: 12,
                  ap: 2,
                  damage: "3",
                  abilities: ["Blast"]),
              WeaponUiProfile(
                  name: "Co-axial Autocannon",
                  profileName: "Standard",
                  range: 48,
                  attacks: "2",
                  skill: 4,
                  strength: 9,
                  ap: 1,
                  damage: "3",
                  abilities: ["Twin-Linked"]),
              WeaponUiProfile(
                  name: "Castigator Gatling Cannon",
                  profileName: "Standard",
                  range: 24,
                  attacks: "12",
                  skill: 4,
                  strength: 5,
                  ap: 0,
                  damage: "1",
                  abilities: ["Sustained Hits 1"]),
              WeaponUiProfile(
                  name: "Heavy Melta",
                  profileName: "Standard",
                  range: 18,
                  attacks: "1",
                  skill: 4,
                  strength: 9,
                  ap: 4,
                  damage: "D6+1",
                  abilities: ["Melta 2"]),
            ],
          ),
        ],
      ),

      // 3. ORKS (BSData Match)
      BsDataFaction(
        id: "ork-1",
        name: "Xenos - Orks",
        units: [
          BsDataUnit(
            id: "ork_battlewagon",
            name: "Battlewagon",
            faction: "Orks",
            pointsCost: 145,
            unitProfile: UnitUiProfile(
              name: "Battlewagon",
              toughness: 10,
              save: 3,
              invuln: 6,
              woundsPerModel: 16,
              modelCount: 1,
              keywords: ["VEHICLE", "TRANSPORT", "ORKS"],
              defensiveAbilities: ["minus1Ap"],
            ),
            movement: '10"',
            leadership: '7+',
            objectiveControl: 5,
            abilities: [
              "Ramshackle but Rugged: Worsen the Armour Penetration characteristic of attacks by 1.",
              "Firing Deck 22: Up to 22 embark models can shoot."
            ],
            categories: ["Vehicle", "Transport", "Orks"],
            weapons: [
              WeaponUiProfile(
                  name: "Killkannon",
                  profileName: "Standard",
                  range: 24,
                  attacks: "D6+1",
                  skill: 5,
                  strength: 9,
                  ap: 2,
                  damage: "2",
                  abilities: ["Blast"]),
              WeaponUiProfile(
                  name: "Zzap Gun",
                  profileName: "Standard",
                  range: 36,
                  attacks: "1",
                  skill: 5,
                  strength: 12,
                  ap: 3,
                  damage: "D6"),
              WeaponUiProfile(
                  name: "Kannon",
                  profileName: "Frag",
                  range: 36,
                  attacks: "D6",
                  skill: 5,
                  strength: 5,
                  ap: 0,
                  damage: "1",
                  abilities: ["Blast"]),
              WeaponUiProfile(
                  name: "Kannon",
                  profileName: "Shell",
                  range: 36,
                  attacks: "1",
                  skill: 5,
                  strength: 9,
                  ap: 2,
                  damage: "D6"),
              WeaponUiProfile(
                  name: "Deff Rolla",
                  profileName: "Melee",
                  range: 0,
                  attacks: "6",
                  skill: 3,
                  strength: 9,
                  ap: 1,
                  damage: "2"),
            ],
          ),
          BsDataUnit(
            id: "ork_beast_snagga",
            name: "Beast Snagga Boyz",
            faction: "Orks",
            pointsCost: 105,
            unitProfile: UnitUiProfile(
              name: "Beast Snagga Boyz",
              toughness: 5,
              save: 5,
              invuln: 6,
              fnp: 6,
              woundsPerModel: 1,
              modelCount: 10,
              keywords: ["INFANTRY", "ORKS", "BEAST SNAGGA"],
            ),
            movement: '6"',
            leadership: '7+',
            objectiveControl: 2,
            abilities: [
              "Monster Hunters: Re-roll Hit rolls of 1 against Monsters and Vehicles.",
              "Feel No Pain 6+."
            ],
            categories: ["Infantry", "Battleline", "Orks"],
            weapons: [
              WeaponUiProfile(
                  name: "Slugga",
                  profileName: "Standard",
                  range: 12,
                  attacks: "1",
                  skill: 5,
                  strength: 4,
                  ap: 0,
                  damage: "1"),
              WeaponUiProfile(
                  name: "Choppa",
                  profileName: "Melee",
                  range: 0,
                  attacks: "4",
                  skill: 3,
                  strength: 5,
                  ap: 1,
                  damage: "1"),
              WeaponUiProfile(
                  name: "Power Snappa",
                  profileName: "Melee",
                  range: 0,
                  attacks: "3",
                  skill: 3,
                  strength: 7,
                  ap: 1,
                  damage: "2"),
            ],
          ),
          BsDataUnit(
            id: "ork_killa_kans",
            name: "Killa Kans",
            faction: "Orks",
            pointsCost: 125,
            unitProfile: UnitUiProfile(
              name: "Killa Kans",
              toughness: 6,
              save: 3,
              invuln: 6,
              woundsPerModel: 5,
              modelCount: 3,
              keywords: ["VEHICLE", "WALKER", "GROT", "ORKS"],
            ),
            movement: '6"',
            leadership: '8+',
            objectiveControl: 2,
            abilities: [
              "Rokkit Barrage: Re-roll Hit rolls of 1 with Rokkit launchas."
            ],
            categories: ["Vehicle", "Walker", "Orks"],
            weapons: [
              WeaponUiProfile(
                  name: "Rokkit Launcha",
                  profileName: "Standard",
                  range: 24,
                  attacks: "D3",
                  skill: 4,
                  strength: 9,
                  ap: 2,
                  damage: "3",
                  abilities: ["Blast"]),
              WeaponUiProfile(
                  name: "Grotzooka",
                  profileName: "Standard",
                  range: 18,
                  attacks: "D6",
                  skill: 4,
                  strength: 6,
                  ap: 0,
                  damage: "1",
                  abilities: ["Blast"]),
              WeaponUiProfile(
                  name: "Kan Klaw",
                  profileName: "Melee",
                  range: 0,
                  attacks: "3",
                  skill: 4,
                  strength: 8,
                  ap: 2,
                  damage: "3"),
            ],
          ),
        ],
      ),

      // 4. NECRONS
      BsDataFaction(
        id: "nec-1",
        name: "Xenos - Necrons",
        units: [
          BsDataUnit(
            id: "nec_warriors",
            name: "Necron Warriors",
            faction: "Necrons",
            pointsCost: 100,
            unitProfile: UnitUiProfile(
              name: "Necron Warriors",
              toughness: 4,
              save: 4,
              woundsPerModel: 1,
              modelCount: 10,
              keywords: ["INFANTRY", "BATTLELINE", "NECRONS"],
            ),
            movement: '5"',
            leadership: '7+',
            objectiveControl: 2,
            abilities: [
              "Their Number is Legion: Reanimation Protocols re-rolls 1s to reanimate."
            ],
            categories: ["Infantry", "Battleline", "Necrons"],
            weapons: [
              WeaponUiProfile(
                  name: "Gauss Flayer",
                  profileName: "Standard",
                  range: 24,
                  attacks: "1",
                  skill: 4,
                  strength: 4,
                  ap: 0,
                  damage: "1",
                  abilities: ["Lethal Hits", "Rapid Fire 1"]),
              WeaponUiProfile(
                  name: "Gauss Reaper",
                  profileName: "Standard",
                  range: 12,
                  attacks: "2",
                  skill: 4,
                  strength: 5,
                  ap: 1,
                  damage: "1",
                  abilities: ["Lethal Hits", "Assault"]),
              WeaponUiProfile(
                  name: "Close Combat Weapon",
                  profileName: "Melee",
                  range: 0,
                  attacks: "1",
                  skill: 4,
                  strength: 4,
                  ap: 0,
                  damage: "1"),
            ],
          ),
          BsDataUnit(
            id: "nec_void_dragon",
            name: "C'tan Shard of the Void Dragon",
            faction: "Necrons",
            pointsCost: 290,
            unitProfile: UnitUiProfile(
              name: "C'tan Shard of the Void Dragon",
              toughness: 11,
              save: 4,
              invuln: 4,
              fnp: 5,
              woundsPerModel: 12,
              modelCount: 1,
              keywords: ["MONSTER", "CHARACTER", "FLY", "NECRONS", "C'TAN"],
              defensiveAbilities: ["halfDamage"],
            ),
            movement: '7"',
            leadership: '6+',
            objectiveControl: 4,
            abilities: [
              "Necrodermis: Halve the Damage characteristic of attacks allocated to this model.",
              "Feel No Pain 5+."
            ],
            categories: ["Monster", "Character", "Necrons"],
            weapons: [
              WeaponUiProfile(
                  name: "Spear of the Void Dragon",
                  profileName: "Ranged Strike",
                  range: 12,
                  attacks: "3",
                  skill: 2,
                  strength: 12,
                  ap: 3,
                  damage: "D6+1",
                  abilities: ["Anti-Vehicle 2+"]),
              WeaponUiProfile(
                  name: "Voltaic Storm",
                  profileName: "Standard",
                  range: 18,
                  attacks: "D6+3",
                  skill: 2,
                  strength: 7,
                  ap: 1,
                  damage: "2",
                  abilities: ["Blast", "Sustained Hits 1"]),
              WeaponUiProfile(
                  name: "Spear of the Void Dragon",
                  profileName: "Melee Strike",
                  range: 0,
                  attacks: "6",
                  skill: 2,
                  strength: 12,
                  ap: 4,
                  damage: "D6+2",
                  abilities: ["Anti-Vehicle 2+"]),
              WeaponUiProfile(
                  name: "Spear of the Void Dragon",
                  profileName: "Melee Sweep",
                  range: 0,
                  attacks: "12",
                  skill: 2,
                  strength: 7,
                  ap: 2,
                  damage: "2"),
            ],
          ),
        ],
      ),

      // 5. TYRANIDS
      BsDataFaction(
        id: "tyr-1",
        name: "Xenos - Tyranids",
        units: [
          BsDataUnit(
            id: "tyr_carnifex",
            name: "Carnifex",
            faction: "Tyranids",
            pointsCost: 125,
            unitProfile: UnitUiProfile(
              name: "Carnifex",
              toughness: 9,
              save: 2,
              woundsPerModel: 8,
              modelCount: 1,
              keywords: ["MONSTER", "GREAT DEVOURER", "TYRANIDS"],
            ),
            movement: '8"',
            leadership: '8+',
            objectiveControl: 3,
            abilities: [
              "Blistering Assault: Each time an enemy unit shoots this model, it can make a Normal move toward that enemy."
            ],
            categories: ["Monster", "Tyranids"],
            weapons: [
              WeaponUiProfile(
                  name: "Heavy Venom Cannon",
                  profileName: "Standard",
                  range: 36,
                  attacks: "D3",
                  skill: 4,
                  strength: 9,
                  ap: 2,
                  damage: "3",
                  abilities: ["Blast"]),
              WeaponUiProfile(
                  name: "Devourers with Brainleech Worms",
                  profileName: "Standard",
                  range: 18,
                  attacks: "12",
                  skill: 4,
                  strength: 6,
                  ap: 0,
                  damage: "1",
                  abilities: ["Twin-Linked"]),
              WeaponUiProfile(
                  name: "Carnifex Crushing Claws",
                  profileName: "Melee",
                  range: 0,
                  attacks: "4",
                  skill: 4,
                  strength: 12,
                  ap: 3,
                  damage: "D6+1"),
              WeaponUiProfile(
                  name: "Carnifex Scything Talons",
                  profileName: "Melee",
                  range: 0,
                  attacks: "6",
                  skill: 3,
                  strength: 9,
                  ap: 2,
                  damage: "3"),
            ],
          ),
        ],
      ),

      // 6. CHAOS SPACE MARINES
      BsDataFaction(
        id: "csm-1",
        name: "Chaos - Chaos Space Marines",
        units: [
          BsDataUnit(
            id: "csm_terminators",
            name: "Chaos Terminator Squad",
            faction: "Chaos Space Marines",
            pointsCost: 185,
            unitProfile: UnitUiProfile(
              name: "Chaos Terminator Squad",
              toughness: 5,
              save: 2,
              invuln: 4,
              woundsPerModel: 3,
              modelCount: 5,
              keywords: ["INFANTRY", "CHAOS", "TERMINATOR"],
            ),
            movement: '5"',
            leadership: '6+',
            objectiveControl: 1,
            abilities: [
              "Dark Pacts: Gain Sustained Hits 1 or Lethal Hits upon passing Leadership test."
            ],
            categories: ["Infantry", "Terminator", "Chaos"],
            weapons: [
              WeaponUiProfile(
                  name: "Combi-bolter",
                  profileName: "Standard",
                  range: 24,
                  attacks: "2",
                  skill: 3,
                  strength: 4,
                  ap: 0,
                  damage: "1",
                  abilities: ["Rapid Fire 2"]),
              WeaponUiProfile(
                  name: "Reaper Autocannon",
                  profileName: "Standard",
                  range: 36,
                  attacks: "4",
                  skill: 3,
                  strength: 7,
                  ap: 1,
                  damage: "1",
                  abilities: ["Sustained Hits 1", "Devastating Wounds"]),
              WeaponUiProfile(
                  name: "Accursed Weapon",
                  profileName: "Melee",
                  range: 0,
                  attacks: "4",
                  skill: 3,
                  strength: 5,
                  ap: 2,
                  damage: "1"),
              WeaponUiProfile(
                  name: "Power Fist",
                  profileName: "Melee",
                  range: 0,
                  attacks: "3",
                  skill: 3,
                  strength: 8,
                  ap: 2,
                  damage: "2"),
            ],
          ),
        ],
      ),

      // 7. ADEPTUS CUSTODES
      BsDataFaction(
        id: "cust-1",
        name: "Imperium - Adeptus Custodes",
        units: [
          BsDataUnit(
            id: "cust_guard",
            name: "Custodian Guard",
            faction: "Adeptus Custodes",
            pointsCost: 180,
            unitProfile: UnitUiProfile(
              name: "Custodian Guard",
              toughness: 6,
              save: 2,
              invuln: 4,
              woundsPerModel: 3,
              modelCount: 4,
              keywords: ["INFANTRY", "IMPERIUM", "CUSTODES"],
            ),
            movement: '6"',
            leadership: '6+',
            objectiveControl: 2,
            abilities: [
              "Stand Vigil: Re-roll Wound rolls of 1, or full Wound re-rolls if within range of an objective marker."
            ],
            categories: ["Infantry", "Battleline", "Imperium"],
            weapons: [
              WeaponUiProfile(
                  name: "Guardian Spear",
                  profileName: "Shooting",
                  range: 24,
                  attacks: "2",
                  skill: 2,
                  strength: 4,
                  ap: 1,
                  damage: "2",
                  abilities: ["Assault"]),
              WeaponUiProfile(
                  name: "Guardian Spear",
                  profileName: "Melee",
                  range: 0,
                  attacks: "5",
                  skill: 2,
                  strength: 7,
                  ap: 2,
                  damage: "2"),
              WeaponUiProfile(
                  name: "Castellan Axe",
                  profileName: "Melee",
                  range: 0,
                  attacks: "4",
                  skill: 2,
                  strength: 9,
                  ap: 1,
                  damage: "3"),
            ],
          ),
        ],
      ),

      // 8. T'AU EMPIRE
      BsDataFaction(
        id: "tau-1",
        name: "Xenos - T'au Empire",
        units: [
          BsDataUnit(
            id: "tau_crisis",
            name: "Crisis Fireknife Battlesuits",
            faction: "T'au Empire",
            pointsCost: 130,
            unitProfile: UnitUiProfile(
              name: "Crisis Fireknife Battlesuits",
              toughness: 5,
              save: 3,
              invuln: 4,
              woundsPerModel: 4,
              modelCount: 3,
              keywords: ["VEHICLE", "WALKER", "FLY", "BATTLESUIT", "TAU"],
            ),
            movement: '10"',
            leadership: '7+',
            objectiveControl: 2,
            abilities: [
              "FTGG: Guided units gain +1 BS against their spotted target."
            ],
            categories: ["Vehicle", "Battlesuit", "Fly", "Tau"],
            weapons: [
              WeaponUiProfile(
                  name: "Missile Pod",
                  profileName: "Standard",
                  range: 30,
                  attacks: "2",
                  skill: 4,
                  strength: 7,
                  ap: 1,
                  damage: "2"),
              WeaponUiProfile(
                  name: "Plasma Rifle",
                  profileName: "Standard",
                  range: 18,
                  attacks: "1",
                  skill: 4,
                  strength: 8,
                  ap: 3,
                  damage: "3"),
            ],
          ),
        ],
      ),

      // 9. AELDARI
      BsDataFaction(
        id: "ael-1",
        name: "Xenos - Aeldari",
        units: [
          BsDataUnit(
            id: "ael_avatar",
            name: "Avatar of Khaine",
            faction: "Aeldari",
            pointsCost: 335,
            unitProfile: UnitUiProfile(
              name: "Avatar of Khaine",
              toughness: 12,
              save: 2,
              invuln: 4,
              woundsPerModel: 14,
              modelCount: 1,
              keywords: ["MONSTER", "CHARACTER", "EPIC HERO", "AELDARI"],
              defensiveAbilities: ["halfDamage"],
            ),
            movement: '10"',
            leadership: '6+',
            objectiveControl: 5,
            abilities: [
              "Molten Body: Halve the Damage characteristic of attacks allocated to this model."
            ],
            categories: ["Monster", "Character", "Epic Hero", "Aeldari"],
            weapons: [
              WeaponUiProfile(
                  name: "The Wailing Doom",
                  profileName: "Ranged",
                  range: 12,
                  attacks: "1",
                  skill: 2,
                  strength: 14,
                  ap: 4,
                  damage: "D6+2",
                  abilities: ["Melta 3"]),
              WeaponUiProfile(
                  name: "The Wailing Doom",
                  profileName: "Melee Strike",
                  range: 0,
                  attacks: "6",
                  skill: 2,
                  strength: 14,
                  ap: 4,
                  damage: "D6+2"),
              WeaponUiProfile(
                  name: "The Wailing Doom",
                  profileName: "Melee Sweep",
                  range: 0,
                  attacks: "12",
                  skill: 2,
                  strength: 7,
                  ap: 2,
                  damage: "2"),
            ],
          ),
        ],
      ),
    ];
  }
}
