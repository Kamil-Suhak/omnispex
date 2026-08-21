import 'dart:convert';
import '../models/bsdata_models.dart';
import '../models/simulation_models.dart';

class BsDataService {
  static final List<BsDataFaction> _bundledFactions = _initBundledFactions();

  static List<BsDataFaction> get bundledFactions => _bundledFactions;

  static List<String> get availableFactions => [
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

  static List<BsDataUnit> searchUnits({
    String query = "",
    String factionFilter = "All Factions",
    String categoryFilter = "All Types",
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final results = <BsDataUnit>[];

    for (final faction in _bundledFactions) {
      if (factionFilter != "All Factions" &&
          !faction.name.toLowerCase().contains(factionFilter.toLowerCase())) {
        continue;
      }

      for (final unit in faction.units) {
        if (categoryFilter == "Infantry" && !unit.isInfantry) continue;
        if (categoryFilter == "Vehicle / Monster" && !unit.isVehicleOrMonster) continue;
        if (categoryFilter == "Character" && !unit.isCharacter) continue;

        if (cleanQuery.isEmpty) {
          results.add(unit);
          continue;
        }

        final matchesName = unit.name.toLowerCase().contains(cleanQuery);
        final matchesFaction = unit.faction.toLowerCase().contains(cleanQuery);
        final matchesCategory = unit.categories.any((c) => c.toLowerCase().contains(cleanQuery));
        final matchesWeapon = unit.weapons.any((w) => w.name.toLowerCase().contains(cleanQuery));
        final matchesAbility = unit.abilities.any((a) => a.toLowerCase().contains(cleanQuery));

        if (matchesName || matchesFaction || matchesCategory || matchesWeapon || matchesAbility) {
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
    final revision = cat['revision'] != null ? int.tryParse(cat['revision'].toString()) : null;

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

    final name = entryJson['name']?.toString()?.trim() ?? 'Unknown Unit';
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

    if (unitProfileJson == null) {
      unitProfileJson = _findFirstProfileByType(entryJson, 'Unit');
    }
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
        points = (c['value'] is num) ? (c['value'] as num).toInt() : int.tryParse(c['value'].toString());
      }
    }

    // Abilities & Defensive Rules Pattern Matching
    final abilities = <String>[];
    _extractAbilitiesRecursive(entryJson, abilities);

    final defensiveRules = <String>[];
    int? fnp;

    for (final ab in abilities) {
      final lower = ab.toLowerCase();
      if (lower.contains('worsen the armour penetration') || lower.contains('worsen the armor penetration')) {
        if (!defensiveRules.contains('minus1Ap')) defensiveRules.add('minus1Ap');
      }
      if (lower.contains('subtract 1 from the damage characteristic')) {
        if (!defensiveRules.contains('damageReduction1')) defensiveRules.add('damageReduction1');
      }
      if (lower.contains('halve the damage characteristic')) {
        if (!defensiveRules.contains('halfDamage')) defensiveRules.add('halfDamage');
      }
      if (lower.contains('subtract 1 from the wound roll')) {
        if (!defensiveRules.contains('minus1ToWound')) defensiveRules.add('minus1ToWound');
      }
      if (lower.contains('stealth') || lower.contains('subtract 1 from the hit roll')) {
        if (!defensiveRules.contains('stealth')) defensiveRules.add('stealth');
      }

      final fnpMatch = RegExp(r'(?:feel no pain|fnp)\s*(\d)\+', caseSensitive: false).firstMatch(ab);
      if (fnpMatch != null && fnp == null) {
        fnp = int.tryParse(fnpMatch.group(1)!);
      }

      final invMatch = RegExp(r'(\d)\+\s+invulnerable save', caseSensitive: false).firstMatch(ab);
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

    final modelCount = categories.any((c) => c.toLowerCase() == 'vehicle' || c.toLowerCase() == 'monster') ? 1 : 5;

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

  static Map<String, String> _extractCharacteristics(Map<String, dynamic> profileJson) {
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

  static Map<String, dynamic>? _findFirstProfileByType(dynamic obj, String typeName) {
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

  static void _extractWeaponsRecursive(dynamic obj, List<WeaponUiProfile> list) {
    if (obj is Map<String, dynamic>) {
      final typeName = obj['typeName']?.toString() ?? '';
      if (typeName == 'Ranged Weapons' || typeName == 'Melee Weapons') {
        final w = _parseWeaponProfile(obj, typeName == 'Melee Weapons');
        if (w != null && !list.any((existing) => existing.name == w.name && existing.profileName == w.profileName)) {
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

  static WeaponUiProfile? _parseWeaponProfile(Map<String, dynamic> json, bool isMelee) {
    final name = json['name']?.toString()?.trim() ?? 'Weapon';
    final chars = _extractCharacteristics(json);

    final rangeRaw = chars['Range'] ?? (isMelee ? '0' : '24"');
    final isMeleeRange = isMelee || rangeRaw.toLowerCase() == 'melee' || rangeRaw == '-';
    final range = isMeleeRange ? 0 : (int.tryParse(rangeRaw.replaceAll('"', '')) ?? 24);

    final attacks = chars['A'] ?? '1';
    final skillRaw = chars['WS'] ?? chars['BS'] ?? '3+';
    final isTorrent = skillRaw == 'N/A' || skillRaw == '-';
    final skill = isTorrent ? 7 : (int.tryParse(skillRaw.replaceAll('+', '')) ?? 3);

    final strength = int.tryParse(chars['S'] ?? '4') ?? 4;
    final ap = (int.tryParse(chars['AP']?.replaceAll('-', '') ?? '0') ?? 0).abs();
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
    return [
      // 1. SPACE MARINES
      BsDataFaction(
        id: "sm-1",
        name: "Imperium - Space Marines",
        units: [
          BsDataUnit(
            id: "sm_terminators",
            name: "Terminator Squad",
            faction: "Space Marines",
            pointsCost: 175,
            unitProfile: const UnitUiProfile(
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
            abilities: ["Teleport Homer: Rapid ingress can be used for 0CP on this unit.", "Fury of the First: +1 to Hit against Oath of Moment targets."],
            categories: ["Infantry", "Terminator", "Imperium"],
            weapons: [
              const WeaponUiProfile(name: "Storm Bolter", profileName: "Standard", range: 24, attacks: "2", skill: 3, strength: 4, ap: 0, damage: "1", abilities: ["Rapid Fire 2"]),
              const WeaponUiProfile(name: "Cyclone Missile Launcher", profileName: "Frag", range: 36, attacks: "2D6", skill: 3, strength: 4, ap: 0, damage: "1", abilities: ["Blast"]),
              const WeaponUiProfile(name: "Cyclone Missile Launcher", profileName: "Krak", range: 36, attacks: "2", skill: 3, strength: 9, ap: 2, damage: "D6"),
              const WeaponUiProfile(name: "Power Fist", profileName: "Melee", range: 0, attacks: "3", skill: 3, strength: 8, ap: 2, damage: "2"),
              const WeaponUiProfile(name: "Chainfist", profileName: "Melee", range: 0, attacks: "3", skill: 4, strength: 8, ap: 2, damage: "2", abilities: ["Anti-Vehicle 3+"]),
            ],
          ),
          BsDataUnit(
            id: "sm_intercessors",
            name: "Intercessor Squad",
            faction: "Space Marines",
            pointsCost: 80,
            unitProfile: const UnitUiProfile(
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
            abilities: ["Sticky Objectives: An objective marker remains under your control even if you move away."],
            categories: ["Infantry", "Battleline", "Imperium"],
            weapons: [
              const WeaponUiProfile(name: "Bolt Rifle", profileName: "Standard", range: 24, attacks: "2", skill: 3, strength: 4, ap: 1, damage: "1", abilities: ["Assault", "Heavy"]),
              const WeaponUiProfile(name: "Astartes Grenade Launcher", profileName: "Frag", range: 24, attacks: "D3", skill: 3, strength: 4, ap: 0, damage: "1", abilities: ["Blast"]),
              const WeaponUiProfile(name: "Astartes Grenade Launcher", profileName: "Krak", range: 24, attacks: "1", skill: 3, strength: 9, ap: 2, damage: "D3"),
              const WeaponUiProfile(name: "Close Combat Weapon", profileName: "Melee", range: 0, attacks: "3", skill: 3, strength: 4, ap: 0, damage: "1"),
            ],
          ),
          BsDataUnit(
            id: "sm_eradicators",
            name: "Eradicator Squad",
            faction: "Space Marines",
            pointsCost: 95,
            unitProfile: const UnitUiProfile(
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
            abilities: ["Total Obliteration: Each time a model in this unit makes a ranged attack against a Monster or Vehicle, re-roll the Hit roll, Wound roll, and Damage roll."],
            categories: ["Infantry", "Gravis", "Imperium"],
            weapons: [
              const WeaponUiProfile(name: "Melta Rifle", profileName: "Standard", range: 18, attacks: "1", skill: 3, strength: 9, ap: 4, damage: "D6", abilities: ["Melta 2"]),
              const WeaponUiProfile(name: "Heavy Melta Rifle", profileName: "Standard", range: 18, attacks: "1", skill: 3, strength: 9, ap: 4, damage: "D6+1", abilities: ["Heavy", "Melta 2"]),
              const WeaponUiProfile(name: "Multi-melta", profileName: "Standard", range: 18, attacks: "2", skill: 3, strength: 9, ap: 4, damage: "D6", abilities: ["Heavy", "Melta 2"]),
            ],
          ),
          BsDataUnit(
            id: "sm_land_raider",
            name: "Land Raider",
            faction: "Space Marines",
            pointsCost: 240,
            unitProfile: const UnitUiProfile(
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
            abilities: ["Assault Ramp: Units disembarking after this model made a Normal move can still declare a charge."],
            categories: ["Vehicle", "Transport", "Imperium"],
            weapons: [
              const WeaponUiProfile(name: "Godhammer Lascannon", profileName: "Standard", range: 48, attacks: "2", skill: 3, strength: 12, ap: 3, damage: "D6+1"),
              const WeaponUiProfile(name: "Twin Heavy Bolter", profileName: "Standard", range: 36, attacks: "3", skill: 3, strength: 5, ap: 1, damage: "2", abilities: ["Twin-Linked", "Sustained Hits 1"]),
              const WeaponUiProfile(name: "Hunter-Killer Missile", profileName: "Standard", range: 48, attacks: "1", skill: 2, strength: 14, ap: 3, damage: "D6"),
              const WeaponUiProfile(name: "Armoured Tracks", profileName: "Melee", range: 0, attacks: "6", skill: 4, strength: 8, ap: 0, damage: "1"),
            ],
          ),
          BsDataUnit(
            id: "sm_redemptor",
            name: "Redemptor Dreadnought",
            faction: "Space Marines",
            pointsCost: 210,
            unitProfile: const UnitUiProfile(
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
            abilities: ["Duty Eternal: Each time an attack is allocated to this model, subtract 1 from the Damage characteristic of that attack."],
            categories: ["Vehicle", "Walker", "Imperium"],
            weapons: [
              const WeaponUiProfile(name: "Macro Plasma Incinerator", profileName: "Standard", range: 36, attacks: "D6+1", skill: 3, strength: 8, ap: 3, damage: "2", abilities: ["Blast"]),
              const WeaponUiProfile(name: "Macro Plasma Incinerator", profileName: "Supercharge", range: 36, attacks: "D6+1", skill: 3, strength: 9, ap: 4, damage: "3", abilities: ["Blast", "Hazardous"]),
              const WeaponUiProfile(name: "Heavy Onslaught Gatling Cannon", profileName: "Standard", range: 24, attacks: "12", skill: 3, strength: 6, ap: 0, damage: "1", abilities: ["Devastating Wounds"]),
              const WeaponUiProfile(name: "Redemptor Fist", profileName: "Melee", range: 0, attacks: "5", skill: 3, strength: 12, ap: 2, damage: "D6+1"),
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
            unitProfile: const UnitUiProfile(
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
              const WeaponUiProfile(name: "Lasgun", profileName: "Standard", range: 24, attacks: "2", skill: 4, strength: 3, ap: 0, damage: "1", abilities: ["Rapid Fire 1"]),
              const WeaponUiProfile(name: "Plasma Gun", profileName: "Standard", range: 24, attacks: "1", skill: 4, strength: 7, ap: 2, damage: "1", abilities: ["Rapid Fire 1"]),
              const WeaponUiProfile(name: "Plasma Gun", profileName: "Supercharge", range: 24, attacks: "1", skill: 4, strength: 8, ap: 3, damage: "2", abilities: ["Rapid Fire 1", "Hazardous"]),
              const WeaponUiProfile(name: "Melta Gun", profileName: "Standard", range: 12, attacks: "1", skill: 4, strength: 9, ap: 4, damage: "D6", abilities: ["Melta 2"]),
              const WeaponUiProfile(name: "Close Combat Weapon", profileName: "Melee", range: 0, attacks: "1", skill: 4, strength: 3, ap: 0, damage: "1"),
            ],
          ),
          BsDataUnit(
            id: "am_leman_russ",
            name: "Leman Russ Battle Tank",
            faction: "Astra Militarum",
            pointsCost: 170,
            unitProfile: const UnitUiProfile(
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
            abilities: ["Armoured Spearhead: Re-roll Hit rolls of 1 against targets on objectives."],
            categories: ["Vehicle", "Imperium"],
            weapons: [
              const WeaponUiProfile(name: "Leman Russ Battle Cannon", profileName: "Standard", range: 48, attacks: "D6+3", skill: 4, strength: 10, ap: 1, damage: "3", abilities: ["Blast"]),
              const WeaponUiProfile(name: "Demolisher Battle Cannon", profileName: "Standard", range: 24, attacks: "D6+3", skill: 4, strength: 14, ap: 3, damage: "D6", abilities: ["Blast"]),
              const WeaponUiProfile(name: "Lascannon", profileName: "Standard", range: 48, attacks: "1", skill: 4, strength: 12, ap: 3, damage: "D6+1", abilities: ["Heavy"]),
              const WeaponUiProfile(name: "Heavy Bolter", profileName: "Standard", range: 36, attacks: "3", skill: 4, strength: 5, ap: 1, damage: "2", abilities: ["Heavy", "Sustained Hits 1"]),
              const WeaponUiProfile(name: "Plasma Cannon", profileName: "Supercharge", range: 36, attacks: "D3", skill: 4, strength: 8, ap: 3, damage: "2", abilities: ["Blast", "Hazardous", "Heavy"]),
              const WeaponUiProfile(name: "Armoured Tracks", profileName: "Melee", range: 0, attacks: "6", skill: 4, strength: 7, ap: 0, damage: "1"),
            ],
          ),
          BsDataUnit(
            id: "am_rogal_dorn",
            name: "Rogal Dorn Battle Tank",
            faction: "Astra Militarum",
            pointsCost: 240,
            unitProfile: const UnitUiProfile(
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
            abilities: ["Ablative Armour: Once per battle, reduce damage of an attack to 0."],
            categories: ["Vehicle", "Imperium"],
            weapons: [
              const WeaponUiProfile(name: "Oppressor Cannon", profileName: "Standard", range: 72, attacks: "D6+3", skill: 4, strength: 12, ap: 2, damage: "3", abilities: ["Blast"]),
              const WeaponUiProfile(name: "Co-axial Autocannon", profileName: "Standard", range: 48, attacks: "2", skill: 4, strength: 9, ap: 1, damage: "3", abilities: ["Twin-Linked"]),
              const WeaponUiProfile(name: "Castigator Gatling Cannon", profileName: "Standard", range: 24, attacks: "12", skill: 4, strength: 5, ap: 0, damage: "1", abilities: ["Sustained Hits 1"]),
              const WeaponUiProfile(name: "Heavy Melta", profileName: "Standard", range: 18, attacks: "1", skill: 4, strength: 9, ap: 4, damage: "D6+1", abilities: ["Melta 2"]),
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
            unitProfile: const UnitUiProfile(
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
            abilities: ["Ramshackle but Rugged: Worsen the Armour Penetration characteristic of attacks by 1.", "Firing Deck 22: Up to 22 embark models can shoot."],
            categories: ["Vehicle", "Transport", "Orks"],
            weapons: [
              const WeaponUiProfile(name: "Killkannon", profileName: "Standard", range: 24, attacks: "D6+1", skill: 5, strength: 9, ap: 2, damage: "2", abilities: ["Blast"]),
              const WeaponUiProfile(name: "Zzap Gun", profileName: "Standard", range: 36, attacks: "1", skill: 5, strength: 12, ap: 3, damage: "D6"),
              const WeaponUiProfile(name: "Kannon", profileName: "Frag", range: 36, attacks: "D6", skill: 5, strength: 5, ap: 0, damage: "1", abilities: ["Blast"]),
              const WeaponUiProfile(name: "Kannon", profileName: "Shell", range: 36, attacks: "1", skill: 5, strength: 9, ap: 2, damage: "D6"),
              const WeaponUiProfile(name: "Deff Rolla", profileName: "Melee", range: 0, attacks: "6", skill: 3, strength: 9, ap: 1, damage: "2"),
            ],
          ),
          BsDataUnit(
            id: "ork_beast_snagga",
            name: "Beast Snagga Boyz",
            faction: "Orks",
            pointsCost: 105,
            unitProfile: const UnitUiProfile(
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
            abilities: ["Monster Hunters: Re-roll Hit rolls of 1 against Monsters and Vehicles.", "Feel No Pain 6+."],
            categories: ["Infantry", "Battleline", "Orks"],
            weapons: [
              const WeaponUiProfile(name: "Slugga", profileName: "Standard", range: 12, attacks: "1", skill: 5, strength: 4, ap: 0, damage: "1"),
              const WeaponUiProfile(name: "Choppa", profileName: "Melee", range: 0, attacks: "4", skill: 3, strength: 5, ap: 1, damage: "1"),
              const WeaponUiProfile(name: "Power Snappa", profileName: "Melee", range: 0, attacks: "3", skill: 3, strength: 7, ap: 1, damage: "2"),
            ],
          ),
          BsDataUnit(
            id: "ork_killa_kans",
            name: "Killa Kans",
            faction: "Orks",
            pointsCost: 125,
            unitProfile: const UnitUiProfile(
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
            abilities: ["Rokkit Barrage: Re-roll Hit rolls of 1 with Rokkit launchas."],
            categories: ["Vehicle", "Walker", "Orks"],
            weapons: [
              const WeaponUiProfile(name: "Rokkit Launcha", profileName: "Standard", range: 24, attacks: "D3", skill: 4, strength: 9, ap: 2, damage: "3", abilities: ["Blast"]),
              const WeaponUiProfile(name: "Grotzooka", profileName: "Standard", range: 18, attacks: "D6", skill: 4, strength: 6, ap: 0, damage: "1", abilities: ["Blast"]),
              const WeaponUiProfile(name: "Kan Klaw", profileName: "Melee", range: 0, attacks: "3", skill: 4, strength: 8, ap: 2, damage: "3"),
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
            unitProfile: const UnitUiProfile(
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
            abilities: ["Their Number is Legion: Reanimation Protocols re-rolls 1s to reanimate."],
            categories: ["Infantry", "Battleline", "Necrons"],
            weapons: [
              const WeaponUiProfile(name: "Gauss Flayer", profileName: "Standard", range: 24, attacks: "1", skill: 4, strength: 4, ap: 0, damage: "1", abilities: ["Lethal Hits", "Rapid Fire 1"]),
              const WeaponUiProfile(name: "Gauss Reaper", profileName: "Standard", range: 12, attacks: "2", skill: 4, strength: 5, ap: 1, damage: "1", abilities: ["Lethal Hits", "Assault"]),
              const WeaponUiProfile(name: "Close Combat Weapon", profileName: "Melee", range: 0, attacks: "1", skill: 4, strength: 4, ap: 0, damage: "1"),
            ],
          ),
          BsDataUnit(
            id: "nec_void_dragon",
            name: "C'tan Shard of the Void Dragon",
            faction: "Necrons",
            pointsCost: 290,
            unitProfile: const UnitUiProfile(
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
            abilities: ["Necrodermis: Halve the Damage characteristic of attacks allocated to this model.", "Feel No Pain 5+."],
            categories: ["Monster", "Character", "Necrons"],
            weapons: [
              const WeaponUiProfile(name: "Spear of the Void Dragon", profileName: "Ranged Strike", range: 12, attacks: "3", skill: 2, strength: 12, ap: 3, damage: "D6+1", abilities: ["Anti-Vehicle 2+"]),
              const WeaponUiProfile(name: "Voltaic Storm", profileName: "Standard", range: 18, attacks: "D6+3", skill: 2, strength: 7, ap: 1, damage: "2", abilities: ["Blast", "Sustained Hits 1"]),
              const WeaponUiProfile(name: "Spear of the Void Dragon", profileName: "Melee Strike", range: 0, attacks: "6", skill: 2, strength: 12, ap: 4, damage: "D6+2", abilities: ["Anti-Vehicle 2+"]),
              const WeaponUiProfile(name: "Spear of the Void Dragon", profileName: "Melee Sweep", range: 0, attacks: "12", skill: 2, strength: 7, ap: 2, damage: "2"),
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
            unitProfile: const UnitUiProfile(
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
            abilities: ["Blistering Assault: Each time an enemy unit shoots this model, it can make a Normal move toward that enemy."],
            categories: ["Monster", "Tyranids"],
            weapons: [
              const WeaponUiProfile(name: "Heavy Venom Cannon", profileName: "Standard", range: 36, attacks: "D3", skill: 4, strength: 9, ap: 2, damage: "3", abilities: ["Blast"]),
              const WeaponUiProfile(name: "Devourers with Brainleech Worms", profileName: "Standard", range: 18, attacks: "12", skill: 4, strength: 6, ap: 0, damage: "1", abilities: ["Twin-Linked"]),
              const WeaponUiProfile(name: "Carnifex Crushing Claws", profileName: "Melee", range: 0, attacks: "4", skill: 4, strength: 12, ap: 3, damage: "D6+1"),
              const WeaponUiProfile(name: "Carnifex Scything Talons", profileName: "Melee", range: 0, attacks: "6", skill: 3, strength: 9, ap: 2, damage: "3"),
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
            unitProfile: const UnitUiProfile(
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
            abilities: ["Dark Pacts: Gain Sustained Hits 1 or Lethal Hits upon passing Leadership test."],
            categories: ["Infantry", "Terminator", "Chaos"],
            weapons: [
              const WeaponUiProfile(name: "Combi-bolter", profileName: "Standard", range: 24, attacks: "2", skill: 3, strength: 4, ap: 0, damage: "1", abilities: ["Rapid Fire 2"]),
              const WeaponUiProfile(name: "Reaper Autocannon", profileName: "Standard", range: 36, attacks: "4", skill: 3, strength: 7, ap: 1, damage: "1", abilities: ["Sustained Hits 1", "Devastating Wounds"]),
              const WeaponUiProfile(name: "Accursed Weapon", profileName: "Melee", range: 0, attacks: "4", skill: 3, strength: 5, ap: 2, damage: "1"),
              const WeaponUiProfile(name: "Power Fist", profileName: "Melee", range: 0, attacks: "3", skill: 3, strength: 8, ap: 2, damage: "2"),
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
            unitProfile: const UnitUiProfile(
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
            abilities: ["Stand Vigil: Re-roll Wound rolls of 1, or full Wound re-rolls if within range of an objective marker."],
            categories: ["Infantry", "Battleline", "Imperium"],
            weapons: [
              const WeaponUiProfile(name: "Guardian Spear", profileName: "Shooting", range: 24, attacks: "2", skill: 2, strength: 4, ap: 1, damage: "2", abilities: ["Assault"]),
              const WeaponUiProfile(name: "Guardian Spear", profileName: "Melee", range: 0, attacks: "5", skill: 2, strength: 7, ap: 2, damage: "2"),
              const WeaponUiProfile(name: "Castellan Axe", profileName: "Melee", range: 0, attacks: "4", skill: 2, strength: 9, ap: 1, damage: "3"),
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
            unitProfile: const UnitUiProfile(
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
            abilities: ["FTGG: Guided units gain +1 BS against their spotted target."],
            categories: ["Vehicle", "Battlesuit", "Fly", "Tau"],
            weapons: [
              const WeaponUiProfile(name: "Missile Pod", profileName: "Standard", range: 30, attacks: "2", skill: 4, strength: 7, ap: 1, damage: "2"),
              const WeaponUiProfile(name: "Plasma Rifle", profileName: "Standard", range: 18, attacks: "1", skill: 4, strength: 8, ap: 3, damage: "3"),
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
            unitProfile: const UnitUiProfile(
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
            abilities: ["Molten Body: Halve the Damage characteristic of attacks allocated to this model."],
            categories: ["Monster", "Character", "Epic Hero", "Aeldari"],
            weapons: [
              const WeaponUiProfile(name: "The Wailing Doom", profileName: "Ranged", range: 12, attacks: "1", skill: 2, strength: 14, ap: 4, damage: "D6+2", abilities: ["Melta 3"]),
              const WeaponUiProfile(name: "The Wailing Doom", profileName: "Melee Strike", range: 0, attacks: "6", skill: 2, strength: 14, ap: 4, damage: "D6+2"),
              const WeaponUiProfile(name: "The Wailing Doom", profileName: "Melee Sweep", range: 0, attacks: "12", skill: 2, strength: 7, ap: 2, damage: "2"),
            ],
          ),
        ],
      ),
    ];
  }
}
