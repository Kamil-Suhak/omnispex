import 'dart:convert';
import 'package:http/http.dart' as http;
import '../bridge/omnispex_rust_bridge.dart';
import '../models/bsdata_models.dart';
import '../models/simulation_models.dart';
import 'faction_registry.dart';
import 'storage_adapter.dart';

class BsDataService {
  static final Map<String, BsDataFaction> _loadedFactions = {};
  static final Set<String> _cachedFactionSlugs = {};
  static DataProvenanceUi _provenance = const DataProvenanceUi();
  static bool _fullBundleLoaded = false;
  static bool _isCheckingUpdates = false;
  static String? _updateStatusMessage;

  static List<BsDataFaction> get bundledFactions =>
      _loadedFactions.values.toList();

  static Map<String, BsDataFaction> get loadedFactionsMap => _loadedFactions;
  static Set<String> get cachedFactionSlugs => _cachedFactionSlugs;
  static DataProvenanceUi get provenance => _provenance;
  static bool get isFullBundleLoaded => _fullBundleLoaded;
  static String? get updateStatusMessage => _updateStatusMessage;

  static Future<void> initOnStartup() async {
    // 1. Populate cached faction slugs from disk/storage
    try {
      final cached = await listCachedFactionSlugs();
      _cachedFactionSlugs.clear();
      _cachedFactionSlugs.addAll(cached);
    } catch (_) {}

    // 2. Load Universal MFM upfront
    await loadUniversalMfm();

    // 3. Check for upstream updates asynchronously
    checkForCatalogUpdates().catchError((_) => false);
  }

  static Future<void> loadUniversalMfm() async {
    try {
      final cachedRaw = await readMfmCacheRaw();
      if (cachedRaw != null && cachedRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(cachedRaw);
        if (decoded is Map<String, dynamic>) {
          _provenance = DataProvenanceUi.fromRustJson(decoded);
          return;
        }
      }
    } catch (_) {}

    _provenance = const DataProvenanceUi(
      edition: 'Warhammer 40,000 11th Edition',
      bsdataRevision: 'b4dc3f40ca39ae551e480228186e769344a36194',
      mfmVersion: '1.6',
      mfmRevision: '11c45c5f062d26d6468b8b2156c7a8e258013ef5',
      mfmLastUpdated: '2026-10-22',
      attributionNotice:
          'Community-maintained game data via BSData/wh40k-11e and points from the Munitorum Field Manual via BSData/wh40k-11e-mfm.',
    );
    try {
      await writeMfmCacheRaw(jsonEncode(_provenance.toRustJson()));
    } catch (_) {}
  }

  static bool isFactionCached(String idOrSlugOrName) {
    final meta = FactionRegistry.find(idOrSlugOrName);
    if (meta == null) return false;
    return _cachedFactionSlugs.contains(meta.slug);
  }

  static Future<BsDataFaction?> downloadAndCacheFaction(
    String idOrSlugOrName, {
    bool force = false,
  }) async {
    final meta = FactionRegistry.find(idOrSlugOrName);
    if (meta == null) return null;

    if (!force) {
      final cachedRaw = await readFactionCacheRaw(meta.slug);
      if (cachedRaw != null && cachedRaw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedRaw);
          if (decoded is Map<String, dynamic>) {
            final f = BsDataFaction.fromRustJson(decoded);
            _cachedFactionSlugs.add(meta.slug);
            _loadedFactions[f.id] = f;
            return f;
          }
        } catch (_) {}
      }
    }

    BsDataFaction? faction;

    // 1. Try remote GitHub BSData
    try {
      final encodedFile = Uri.encodeComponent(meta.remoteFile);
      final url = Uri.parse(
          'https://raw.githubusercontent.com/BSData/wh40k-11e/refs/heads/main/$encodedFile');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        faction = OmnispexRustBridge.isReady
            ? OmnispexRustBridge.parseBsDataCatalogue(res.body)
            : parseFactionJson(res.body);
      }
    } catch (_) {}

    if (faction != null) {
      final jsonStr = jsonEncode(faction.toRustJson());
      await writeFactionCacheRaw(meta.slug, jsonStr);
      _cachedFactionSlugs.add(meta.slug);
      _loadedFactions[faction.id] = faction;
      return faction;
    }

    return null;
  }

  static Future<void> deleteFactionCache(String idOrSlugOrName) async {
    final meta = FactionRegistry.find(idOrSlugOrName);
    if (meta == null) return;

    await deleteFactionCacheRaw(meta.slug);
    _cachedFactionSlugs.remove(meta.slug);
    _loadedFactions.remove(meta.id);
    _loadedFactions.remove(meta.slug);
  }

  /// List Builder Scope: strictly ONLY the list's chosen faction in memory
  static Future<BsDataFaction?> scopeMemoryToListBuilder(
      String factionIdOrName) async {
    _loadedFactions.clear();
    final faction = await loadFactionIntoMemory(factionIdOrName);
    return faction;
  }

  /// Live Match Scope: at most 2 factions in memory
  static Future<void> scopeMemoryToMatch(
    String factionA, [
    String? factionB,
  ]) async {
    final keepSlugs = <String>{};
    final metaA = FactionRegistry.find(factionA);
    if (metaA != null) keepSlugs.add(metaA.id);
    if (factionB != null) {
      final metaB = FactionRegistry.find(factionB);
      if (metaB != null) keepSlugs.add(metaB.id);
    }

    _loadedFactions.removeWhere((k, _) => !keepSlugs.contains(k));
    if (metaA != null) await loadFactionIntoMemory(metaA.id);
    if (factionB != null) await loadFactionIntoMemory(factionB);
  }

  /// Datasheet Browser Scope: strictly the 1 selected faction in memory
  static Future<BsDataFaction?> scopeMemoryToBrowser(
      String factionIdOrName) async {
    _loadedFactions.clear();
    final faction = await loadFactionIntoMemory(factionIdOrName);
    return faction;
  }

  static Future<BsDataFaction?> loadFactionIntoMemory(
      String idOrSlugOrName) async {
    final meta = FactionRegistry.find(idOrSlugOrName);
    if (meta != null && _loadedFactions.containsKey(meta.id)) {
      return _loadedFactions[meta.id];
    }

    final faction = await downloadAndCacheFaction(idOrSlugOrName);
    if (faction != null) {
      _loadedFactions[faction.id] = faction;
      return faction;
    }

    return null;
  }

  static Future<bool> checkForCatalogUpdates() async {
    if (_isCheckingUpdates) return false;
    _isCheckingUpdates = true;
    try {
      final url = Uri.parse(
          'https://api.github.com/repos/BSData/wh40k-11e/commits/main');
      final res = await http.get(url, headers: {'User-Agent': 'Omnispex-App'}).timeout(
        const Duration(seconds: 4),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final latestSha = data['sha']?.toString() ?? '';
        if (latestSha.isNotEmpty &&
            !latestSha.startsWith(_provenance.bsdataRevision)) {
          _updateStatusMessage = 'New 11e data update available (${latestSha.substring(0, 7)})';
          return true;
        } else {
          _updateStatusMessage = 'Data up to date (BSData 11e @ ${_provenance.bsdataRevision.substring(0, 7)})';
        }
      }
    } catch (_) {
      _updateStatusMessage = 'Checked offline // using local BSData cache';
    } finally {
      _isCheckingUpdates = false;
    }
    return false;
  }

  static Future<bool> checkForMfmUpdates() async {
    try {
      final url = Uri.parse(
          'https://api.github.com/repos/BSData/wh40k-11e-mfm/commits/main');
      final res = await http.get(url, headers: {'User-Agent': 'Omnispex-App'}).timeout(
        const Duration(seconds: 4),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final latestSha = data['sha']?.toString() ?? '';
        if (latestSha.isNotEmpty &&
            !latestSha.startsWith(_provenance.mfmRevision)) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<void> loadFull11eCatalogueBundle() async {
    await initOnStartup();
    if (_fullBundleLoaded) return;
    for (final slug in _cachedFactionSlugs) {
      try {
        final raw = await readFactionCacheRaw(slug);
        if (raw != null && raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            final f = BsDataFaction.fromRustJson(decoded);
            _loadedFactions[f.id] = f;
          }
        }
      } catch (_) {}
    }
    _fullBundleLoaded = true;
  }

  static void resetToDefaultFallback() {
    _loadedFactions.clear();
    _provenance = const DataProvenanceUi();
    _fullBundleLoaded = false;
  }

  static BsDataFaction importCatalogueJson(String jsonStr) {
    final BsDataFaction parsed = OmnispexRustBridge.isReady
        ? OmnispexRustBridge.parseBsDataCatalogue(jsonStr)
        : parseFactionJson(jsonStr);
    _loadedFactions[parsed.id] = parsed;
    return parsed;
  }

  static BsDataFaction? findFaction(String idOrName) {
    final clean = idOrName.trim().toLowerCase();
    for (final f in _loadedFactions.values) {
      if (f.id.toLowerCase() == clean ||
          f.name.toLowerCase() == clean ||
          f.name.toLowerCase().contains(clean)) {
        return f;
      }
    }
    return null;
  }

  static List<String> get availableFactions {
    final names = FactionRegistry.allFactions.map((f) => f.name).toList();
    return ["All Factions", ...names];
  }

  static List<BsDataUnit> searchUnits({
    String query = "",
    String factionFilter = "All Factions",
    String categoryFilter = "All Types",
    bool includeLegends = false,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final results = <BsDataUnit>[];

    for (final faction in bundledFactions) {
      if (factionFilter != "All Factions") {
        final wanted = factionFilter.toLowerCase();
        if (faction.id.toLowerCase() != wanted &&
            faction.name.toLowerCase() != wanted) {
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
    for (final f in bundledFactions) {
      for (final u in f.units) {
        if (u.id == id) return u;
      }
    }
    return null;
  }

  static BsDataUnit? findUnitByName(String name) {
    final clean = name.trim().toLowerCase();
    for (final f in bundledFactions) {
      for (final u in f.units) {
        if (u.name.trim().toLowerCase() == clean) return u;
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
}
