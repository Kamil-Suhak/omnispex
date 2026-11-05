import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../bridge/omnispex_rust_bridge.dart';
import '../models/bsdata_models.dart';
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
    try {
      final cached = await listCachedFactionSlugs();
      _cachedFactionSlugs
        ..clear()
        ..addAll(cached);
    } catch (_) {}

    await loadUniversalMfm();
    await _ensureBundledCatalogueInRustEngine();
  }

  static Future<void> _ensureBundledCatalogueInRustEngine() async {
    if (_fullBundleLoaded) return;
    try {
      final bundleRaw =
          await rootBundle.loadString('assets/data/wh40k_11e_bundle.json');
      if (bundleRaw.trim().isNotEmpty && OmnispexRustBridge.isReady) {
        OmnispexRustBridge.wh40kLoadCatalogue(bundleRaw);
        _fullBundleLoaded = true;
        for (final meta in FactionRegistry.allFactions) {
          _cachedFactionSlugs.add(meta.slug);
        }
      }
    } catch (_) {
      // Rust EngineState already holds `default_wh40k_seed_catalogue()` on startup.
    }
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
    await _ensureBundledCatalogueInRustEngine();
    if (!force) {
      final fromEngine = findFaction(idOrSlugOrName);
      if (fromEngine != null) {
        return fromEngine;
      }
    }

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

    try {
      final encodedFile = Uri.encodeComponent(meta.remoteFile);
      final url = Uri.parse(
          'https://raw.githubusercontent.com/BSData/wh40k-11e/refs/heads/main/$encodedFile');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        final faction = OmnispexRustBridge.parseBsDataCatalogue(res.body);
        final jsonStr = jsonEncode(faction.toRustJson());
        await writeFactionCacheRaw(meta.slug, jsonStr);
        _cachedFactionSlugs.add(meta.slug);
        _loadedFactions[faction.id] = faction;
        return faction;
      }
    } catch (_) {}

    return findFaction(idOrSlugOrName);
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
    final faction = await loadFactionIntoMemory(factionIdOrName);
    if (faction != null) {
      _loadedFactions.removeWhere((k, _) => k != faction.id && k != faction.name);
    }
    return faction;
  }

  /// Live Match Scope: at most 2 factions in memory
  static Future<void> scopeMemoryToMatch(
    String factionA, [
    String? factionB,
  ]) async {
    final keepIds = <String>{};
    final fA = await loadFactionIntoMemory(factionA);
    if (fA != null) {
      keepIds.add(fA.id);
      keepIds.add(fA.name);
    }
    if (factionB != null) {
      final fB = await loadFactionIntoMemory(factionB);
      if (fB != null) {
        keepIds.add(fB.id);
        keepIds.add(fB.name);
      }
    }
    _loadedFactions.removeWhere((k, _) => !keepIds.contains(k));
  }

  /// Browser Scope: strictly ONLY the browsed faction in memory
  static Future<BsDataFaction?> scopeMemoryToBrowser(
      String factionIdOrName) async {
    final faction = await loadFactionIntoMemory(factionIdOrName);
    if (faction != null) {
      _loadedFactions.removeWhere((k, _) => k != faction.id && k != faction.name);
    }
    return faction;
  }

  static Future<BsDataFaction?> loadFactionIntoMemory(
      String idOrSlugOrName) async {
    await _ensureBundledCatalogueInRustEngine();
    final existing = findFaction(idOrSlugOrName);
    if (existing != null) return existing;
    return downloadAndCacheFaction(idOrSlugOrName);
  }

  static Future<bool> checkForCatalogUpdates() async {
    if (_isCheckingUpdates) return false;
    _isCheckingUpdates = true;
    try {
      final url = Uri.parse(
          'https://api.github.com/repos/BSData/wh40k-11e/commits/main');
      final res = await http
          .get(url, headers: {'User-Agent': 'Omnispex-App'})
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final latestSha = data['sha']?.toString() ?? '';
        if (latestSha.isNotEmpty &&
            !latestSha.startsWith(_provenance.bsdataRevision)) {
          _updateStatusMessage =
              'New 11e data update available (${latestSha.substring(0, 7)})';
          return true;
        } else {
          _updateStatusMessage =
              'Data up to date (BSData 11e @ ${_provenance.bsdataRevision.substring(0, 7)})';
        }
      }
    } catch (_) {
      _updateStatusMessage = 'Local BSData 11e catalogue active';
    } finally {
      _isCheckingUpdates = false;
    }
    return false;
  }

  static Future<bool> checkForMfmUpdates() async {
    try {
      final url = Uri.parse(
          'https://api.github.com/repos/BSData/wh40k-11e-mfm/commits/main');
      final res = await http
          .get(url, headers: {'User-Agent': 'Omnispex-App'})
          .timeout(const Duration(seconds: 4));
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
  }

  static void resetToDefaultFallback() {
    _loadedFactions.clear();
    _provenance = const DataProvenanceUi();
    _fullBundleLoaded = false;
  }

  static BsDataFaction importCatalogueJson(String jsonStr) {
    final parsed = OmnispexRustBridge.parseBsDataCatalogue(jsonStr);
    _loadedFactions[parsed.id] = parsed;
    return parsed;
  }

  static BsDataFaction? findFaction(String idOrName) {
    final clean = idOrName.trim();
    if (clean.isEmpty || clean == 'All Factions') return null;

    for (final f in _loadedFactions.values) {
      if (f.id.toLowerCase() == clean.toLowerCase() ||
          f.name.toLowerCase() == clean.toLowerCase()) {
        return f;
      }
    }

    if (OmnispexRustBridge.isReady) {
      try {
        final faction = OmnispexRustBridge.wh40kGetFactionDetail(clean);
        _loadedFactions[faction.id] = faction;
        return faction;
      } catch (_) {}
    }

    return null;
  }

  static List<String> get availableFactions {
    if (OmnispexRustBridge.isReady) {
      try {
        final summaries = OmnispexRustBridge.wh40kGetFactionsSummary();
        if (summaries.isNotEmpty) {
          final names =
              summaries.map((s) => s['name']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
          return ['All Factions', ...names];
        }
      } catch (_) {}
    }
    final names = FactionRegistry.allFactions.map((f) => f.name).toList();
    return ['All Factions', ...names];
  }

  static List<BsDataUnit> searchUnits({
    String query = '',
    String factionFilter = 'All Factions',
    String categoryFilter = 'All Types',
    bool includeLegends = false,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final combined = <BsDataUnit>[];
    final seen = <String>{};

    if (OmnispexRustBridge.isReady) {
      final String? rustFactionFilter =
          (factionFilter.isEmpty || factionFilter == 'All Factions')
              ? null
              : factionFilter;
      String? rustCategoryFilter;
      if (categoryFilter == 'Infantry') {
        rustCategoryFilter = 'INFANTRY';
      } else if (categoryFilter == 'Vehicle / Monster') {
        rustCategoryFilter = null; // Filtered below across both VEHICLE and MONSTER
      } else if (categoryFilter == 'Character') {
        rustCategoryFilter = 'CHARACTER';
      } else if (categoryFilter == 'Battleline') {
        rustCategoryFilter = 'BATTLELINE';
      }

      final results = OmnispexRustBridge.wh40kSearchUnitsFull(
        query: query,
        faction: rustFactionFilter,
        category: rustCategoryFilter,
        includeLegends: includeLegends,
      );

      for (final u in results) {
        if (categoryFilter == 'Vehicle / Monster' && !u.isVehicleOrMonster) continue;
        if (seen.add(u.name.toLowerCase())) {
          combined.add(u);
        }
      }
    }

    // Also search in-memory loaded factions (e.g. custom imported or test fixtures)
    for (final faction in _loadedFactions.values) {
      if (factionFilter != 'All Factions' &&
          factionFilter.isNotEmpty &&
          faction.name.toLowerCase() != factionFilter.toLowerCase() &&
          !faction.name.toLowerCase().contains(factionFilter.toLowerCase()) &&
          faction.id.toLowerCase() != factionFilter.toLowerCase()) {
        continue;
      }

      for (final unit in faction.units) {
        if (categoryFilter == 'Infantry' && !unit.isInfantry) continue;
        if (categoryFilter == 'Vehicle / Monster' && !unit.isVehicleOrMonster) continue;
        if (categoryFilter == 'Character' && !unit.isCharacter) continue;
        if (categoryFilter == 'Battleline' && !unit.isBattleline) continue;

        if (cleanQuery.isNotEmpty) {
          final matchesName = unit.name.toLowerCase().contains(cleanQuery);
          final matchesFaction = unit.faction.toLowerCase().contains(cleanQuery);
          final matchesCategory =
              unit.categories.any((c) => c.toLowerCase().contains(cleanQuery));
          if (!matchesName && !matchesFaction && !matchesCategory) continue;
        }

        if (seen.add(unit.name.toLowerCase())) {
          combined.add(unit);
        }
      }
    }

    return combined;
  }

  static BsDataUnit? findUnitById(String id) {
    try {
      return OmnispexRustBridge.wh40kGetUnitDetail(id);
    } catch (_) {
      return null;
    }
  }

  static BsDataUnit? findUnitByName(String name) {
    try {
      return OmnispexRustBridge.wh40kGetUnitDetail(name);
    } catch (_) {
      return null;
    }
  }
}
