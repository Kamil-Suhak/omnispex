import 'dart:convert';
import 'package:http/http.dart' as http;
import '../bridge/omnispex_rust_bridge.dart';
import '../features/kill_team/models/kill_team_models.dart';
import '../models/bsdata_models.dart';
import '../models/omnispex_models.dart';
import 'auth_service.dart';
import 'storage_adapter.dart';

class PersonalDataService {
  static const List<String> defaultKillTeamFactions = [
    'Angels of Death',
    'Plague Marines',
    'Kommandos',
    'Death Korps',
    'Kasrkin',
    'Tempestus Aquilons',
    'Vespid Stingwings',
    'Phobos Strike Team',
    'Scout Squad',
    'Nemesis Claw',
    'Legionaries',
    'Warpcoven',
    'Blades of Khaine',
    'Corsair Voidscarred',
    'Hand of the Archon',
    'Mandrakes',
    'Pathfinders',
    'Farstalker Kinband',
    'Hierotek Circle',
    'Hearthkyn Salvagers',
    'Hernkyn Yaegirs',
    'Brood Brothers',
    'Wyrmblade',
    'Hunter Clade',
    'Inquisitorial Agents',
    'Novitiates',
    'Exaction Squad',
    'Imperial Navy Breachers',
    'Fellgor Ravagers',
    'Blooded',
    'Chaos Cult',
  ];

  static const String defaultCloudSyncEndpoint =
      'https://omnispex-cloud.kamilsuhak.workers.dev';

  static final List<KillTeamRosterUi> _killTeamRosters = [];
  static List<KillTeamRosterUi> get killTeamRosters =>
      List.unmodifiable(_killTeamRosters);

  static Future<PersonalDataStoreUi> loadPersonalStore() async {
    // 1. Attempt to pull from normalized remote D1 tables (army_rosters, wishlists, match_history)
    try {
      final creds = await AuthService.getOrCreateCredentials();
      final cloudStore = await pullFromCloudSync(
        accessKey: creds.accessKey,
      );
      if (cloudStore != null) {
        return cloudStore;
      }
    } catch (_) {}

    // 2. Local offline cache fallback
    final raw = await readPersonalStoreRaw();
    if (raw == null || raw.trim().isEmpty) {
      return const PersonalDataStoreUi();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _extractKillTeamRostersFromMap(decoded);
      }
      return OmnispexRustBridge.migratePersonalStore(raw);
    } catch (_) {
      return const PersonalDataStoreUi();
    }
  }

  static void _extractKillTeamRostersFromMap(Map<String, dynamic> map) {
    final ktRaw = map['kill_team_rosters'];
    if (ktRaw is List) {
      _killTeamRosters
        ..clear()
        ..addAll(ktRaw.map(
          (e) => KillTeamRosterUi.fromRustJson(Map<String, dynamic>.from(e)),
        ));
    }
  }

  static Future<void> savePersonalStore(PersonalDataStoreUi store) async {
    final map = store.toRustJson();
    map['kill_team_rosters'] =
        _killTeamRosters.map((r) => r.toRustJson()).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
    await writePersonalStoreRaw(jsonStr);

    try {
      final creds = await AuthService.getOrCreateCredentials();
      await pushToCloudSync(
        accessKey: creds.accessKey,
        store: store,
      );
    } catch (_) {}
  }

  static Future<void> saveKillTeamRoster(
    KillTeamRosterUi roster,
    PersonalDataStoreUi currentStore,
  ) async {
    final idx = _killTeamRosters.indexWhere((r) => r.id == roster.id);
    if (idx >= 0) {
      _killTeamRosters[idx] = roster;
    } else {
      _killTeamRosters.add(roster);
    }
    await savePersonalStore(currentStore);
    await upsertRemoteRosterRow(
      id: roster.id,
      gameSystem: 'kill_team',
      name: roster.name,
      factionId: roster.factionId,
      factionName: roster.factionName,
      pointsLimit: roster.operatives.length,
      totalPoints: roster.operatives.length,
      payload: roster.toRustJson(),
    );
  }

  static Future<void> deleteKillTeamRoster(
    String rosterId,
    PersonalDataStoreUi currentStore,
  ) async {
    _killTeamRosters.removeWhere((r) => r.id == rosterId);
    await savePersonalStore(currentStore);
    await deleteRemoteRow('rosters', rosterId);
  }

  static String exportBackupJson(PersonalDataStoreUi store) {
    final map = store.toRustJson();
    map['kill_team_rosters'] =
        _killTeamRosters.map((r) => r.toRustJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static PersonalDataStoreUi restoreFromBackupJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is Map<String, dynamic>) {
      _extractKillTeamRostersFromMap(decoded);
    }
    return OmnispexRustBridge.migratePersonalStore(rawJson);
  }

  static ArmyListEvaluationUi evaluateArmyList({
    required ArmyListUi list,
    BsDataFaction? faction,
  }) {
    return OmnispexRustBridge.evaluateArmyList(list: list, faction: faction);
  }

  static WishlistOperationResponseUi upsertWishlist({
    required List<WishlistItemUi> items,
    required WishlistItemUi item,
    String? activeFactionId,
  }) {
    return OmnispexRustBridge.upsertWishlist(
      items: items,
      item: item,
      activeFactionId: activeFactionId,
    );
  }

  static WishlistOperationResponseUi queryWishlist({
    required List<WishlistItemUi> items,
    String? factionId,
    String query = '',
    WishlistPriorityUi? priorityFilter,
    AcquisitionStateUi? stateFilter,
    WishlistSortFieldUi sortBy = WishlistSortFieldUi.priorityDesc,
  }) {
    return OmnispexRustBridge.queryWishlist(
      items: items,
      factionId: factionId,
      query: query,
      priorityFilter: priorityFilter,
      stateFilter: stateFilter,
      sortBy: sortBy,
    );
  }

  static MatchDashboardResponseUi evaluateMatches({
    required List<MatchRecordUi> matches,
    GameSystemUi? gameSystem,
    String query = '',
    String? factionFilter,
    MatchResultUi? resultFilter,
  }) {
    return OmnispexRustBridge.evaluateMatches(
      matches: matches,
      gameSystem: gameSystem,
      query: query,
      factionFilter: factionFilter,
      resultFilter: resultFilter,
    );
  }

  // ==========================================================================
  // Normalized Remote Table Operations (`army_rosters`, `wishlists`, `match_history`)
  // ==========================================================================

  static Future<bool> upsertRemoteRosterRow({
    required String id,
    required String gameSystem,
    required String name,
    required String factionId,
    required String factionName,
    required int pointsLimit,
    required int totalPoints,
    required Map<String, dynamic> payload,
    String endpoint = defaultCloudSyncEndpoint,
  }) async {
    try {
      final creds = await AuthService.getOrCreateCredentials(endpoint: endpoint);
      final uri = Uri.parse('$endpoint/api/rosters/$id');
      final res = await http
          .put(
            uri,
            headers: AuthService.getAuthHeaders(creds),
            body: jsonEncode({
              'id': id,
              'game_system': gameSystem,
              'name': name,
              'faction_id': factionId,
              'faction_name': factionName,
              'points_limit': pointsLimit,
              'total_points': totalPoints,
              'payload': payload,
            }),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> upsertRemoteWishlistRow(
    WishlistItemUi item, {
    String gameSystem = 'wh40k',
    String endpoint = defaultCloudSyncEndpoint,
  }) async {
    try {
      final creds = await AuthService.getOrCreateCredentials(endpoint: endpoint);
      final uri = Uri.parse('$endpoint/api/wishlists/${item.id}');
      final res = await http
          .put(
            uri,
            headers: AuthService.getAuthHeaders(creds),
            body: jsonEncode({
              'id': item.id,
              'game_system': gameSystem,
              'faction_id': item.factionId,
              'faction_name': item.factionName,
              'unit_id': item.unitId,
              'unit_name': item.unitName,
              'quantity_desired': item.quantityDesired,
              'quantity_owned': item.quantityOwned,
              'points_per_unit': item.pointsPerUnit,
              'priority': item.priority.toRustJson(),
              'state': item.state.toRustJson(),
              'notes': item.notes,
              'updated_at_iso': item.updatedAtIso,
            }),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> upsertRemoteMatchRow(
    MatchRecordUi match, {
    String endpoint = defaultCloudSyncEndpoint,
  }) async {
    try {
      final creds = await AuthService.getOrCreateCredentials(endpoint: endpoint);
      final uri = Uri.parse('$endpoint/api/matches/${match.id}');
      final res = await http
          .put(
            uri,
            headers: AuthService.getAuthHeaders(creds),
            body: jsonEncode({
              'id': match.id,
              'game_system': match.gameSystem.apiKey,
              'date_iso': match.dateIso,
              'player_faction': match.playerFaction,
              'opponent_faction': match.opponentFaction,
              'opponent_name': match.opponentName,
              'player_score': match.playerScore,
              'opponent_score': match.opponentScore,
              'result': match.result.toRustJson(),
              'payload': match.toRustJson(),
              'updated_at_iso': match.updatedAtIso,
            }),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteRemoteRow(
    String resource,
    String id, {
    String endpoint = defaultCloudSyncEndpoint,
  }) async {
    try {
      final creds = await AuthService.getOrCreateCredentials(endpoint: endpoint);
      final uri = Uri.parse('$endpoint/api/$resource/$id');
      final res = await http
          .delete(
            uri,
            headers: AuthService.getAuthHeaders(creds),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Synchronize `army_rosters`, `wishlists`, and `match_history` via `POST /api/sync/batch`.
  static Future<bool> pushToCloudSync({
    String? accessKey,
    String? userId,
    String? secretKey,
    PersonalDataStoreUi? store,
    String endpoint = defaultCloudSyncEndpoint,
  }) async {
    try {
      final key = accessKey ??
          secretKey ??
          (await AuthService.getOrCreateCredentials(endpoint: endpoint))
              .accessKey;
      final activeStore = store ?? await loadPersonalStore();

      final rostersPayload = <Map<String, dynamic>>[
        ...activeStore.armyLists.map((l) => {
              'id': l.id,
              'game_system': 'wh40k',
              'name': l.name,
              'faction_id': l.factionId,
              'faction_name': l.factionName,
              'points_limit': l.pointsLimit,
              'total_points': l.totalPoints,
              'payload': l.toRustJson(),
              'updated_at_iso': l.updatedAtIso,
            }),
        ..._killTeamRosters.map((r) => {
              'id': r.id,
              'game_system': 'kill_team',
              'name': r.name,
              'faction_id': r.factionId,
              'faction_name': r.factionName,
              'points_limit': r.operatives.length,
              'total_points': r.operatives.length,
              'payload': r.toRustJson(),
              'updated_at_iso': r.updatedAtIso,
            }),
      ];

      final wishlistsPayload = activeStore.wishlistItems
          .map((item) => {
                'id': item.id,
                'game_system': 'wh40k',
                'faction_id': item.factionId,
                'faction_name': item.factionName,
                'unit_id': item.unitId,
                'unit_name': item.unitName,
                'quantity_desired': item.quantityDesired,
                'quantity_owned': item.quantityOwned,
                'points_per_unit': item.pointsPerUnit,
                'priority': item.priority.toRustJson(),
                'state': item.state.toRustJson(),
                'notes': item.notes,
                'updated_at_iso': item.updatedAtIso,
              })
          .toList();

      final matchesPayload = activeStore.matches
          .map((m) => {
                'id': m.id,
                'game_system': m.gameSystem.apiKey,
                'date_iso': m.dateIso,
                'player_faction': m.playerFaction,
                'opponent_faction': m.opponentFaction,
                'opponent_name': m.opponentName,
                'player_score': m.playerScore,
                'opponent_score': m.opponentScore,
                'result': m.result.toRustJson(),
                'payload': m.toRustJson(),
                'updated_at_iso': m.updatedAtIso,
              })
          .toList();

      final uri = Uri.parse('$endpoint/api/sync/batch');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode({
              'rosters': rostersPayload,
              'wishlists': wishlistsPayload,
              'matches': matchesPayload,
            }),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Pull user data from normalized remote D1 tables (`GET /api/sync`).
  static Future<PersonalDataStoreUi?> pullFromCloudSync({
    String? accessKey,
    String? userId,
    String? secretKey,
    String endpoint = defaultCloudSyncEndpoint,
  }) async {
    try {
      final key = accessKey ??
          secretKey ??
          (await AuthService.getOrCreateCredentials(endpoint: endpoint))
              .accessKey;
      final uri = Uri.parse('$endpoint/api/sync');
      final res = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $key',
            },
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic> && decoded['ok'] == true) {
          final rostersRaw = decoded['rosters'] as List? ?? [];
          final wishlistsRaw = decoded['wishlists'] as List? ?? [];
          final matchesRaw = decoded['matches'] as List? ?? [];

          final wh40kLists = <ArmyListUi>[];
          final ktLists = <KillTeamRosterUi>[];
          for (final r in rostersRaw) {
            if (r is Map) {
              final gs = r['game_system']?.toString() ?? 'wh40k';
              final payload = r['payload'];
              if (payload is Map) {
                if (gs == 'kill_team') {
                  ktLists.add(KillTeamRosterUi.fromRustJson(
                      Map<String, dynamic>.from(payload)));
                } else {
                  wh40kLists.add(ArmyListUi.fromRustJson(
                      Map<String, dynamic>.from(payload)));
                }
              }
            }
          }
          _killTeamRosters
            ..clear()
            ..addAll(ktLists);

          final wishlists = wishlistsRaw
              .whereType<Map>()
              .map((w) =>
                  WishlistItemUi.fromRustJson(Map<String, dynamic>.from(w)))
              .toList();

          final matches = matchesRaw
              .whereType<Map>()
              .map((m) {
                final payload = m['payload'];
                if (payload is Map) {
                  return MatchRecordUi.fromRustJson(
                      Map<String, dynamic>.from(payload));
                }
                return MatchRecordUi.fromRustJson(
                    Map<String, dynamic>.from(m));
              })
              .toList();

          if (wh40kLists.isEmpty &&
              ktLists.isEmpty &&
              wishlists.isEmpty &&
              matches.isEmpty) {
            return null;
          }

          final store = PersonalDataStoreUi(
            armyLists: wh40kLists,
            wishlistItems: wishlists,
            matches: matches,
          );
          final map = store.toRustJson();
          map['kill_team_rosters'] =
              _killTeamRosters.map((r) => r.toRustJson()).toList();
          await writePersonalStoreRaw(jsonEncode(map));
          return store;
        }
      }
    } catch (_) {}
    return null;
  }
}
