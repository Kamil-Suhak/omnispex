import 'dart:convert';
import '../models/bsdata_models.dart';
import '../models/omnispex_models.dart';
import '../models/simulation_models.dart';
import 'rust_bridge_stub.dart'
    if (dart.library.ffi) 'rust_bridge_native.dart'
    if (dart.library.js_interop) 'rust_bridge_web.dart';

class OmnispexRustBridge {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await initPlatformRustBridge();
    _initialized = isPlatformRustBridgeReady;
  }

  static bool get isReady => isPlatformRustBridgeReady;

  static Map<String, dynamic> _call(String op, Object? payload) {
    final payloadStr = payload == null
        ? ''
        : (payload is String ? payload : jsonEncode(payload));
    final raw = invokePlatformRustRpc(op, payloadStr);
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      if (decoded['ok'] == true) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return {'value': data};
      }
      throw StateError(
          decoded['error']?.toString() ?? 'Unknown Rust bridge error ($op)');
    }
    throw StateError('Malformed Rust bridge response for $op');
  }

  static Map<String, dynamic> buildCombatContextJson({
    required bool isStationary,
    required bool hasCharged,
    required bool targetInCover,
    int? distance,
    Set<String> extraAbilities = const {},
    ReRollOption hitReroll = ReRollOption.none,
    ReRollOption woundReroll = ReRollOption.none,
    int bonusStrength = 0,
    int bonusAp = 0,
    bool defensiveArmorOfContempt = false,
    bool defensiveMinusWound = false,
    bool defensiveGrantInvuln4 = false,
    bool defensiveGrantFnp5 = false,
    bool defensiveGrantHalfDamage = false,
    bool defensiveGrantMinusDamage1 = false,
  }) {
    return {
      'distance_inches': distance,
      'is_stationary': isStationary,
      'has_charged': hasCharged,
      'in_engagement_range': false,
      'target_has_benefit_of_cover': targetInCover,
      'target_visible': true,
      'attacker_advanced': false,
      'hit_reroll': hitReroll.toRustJson(),
      'wound_reroll': woundReroll.toRustJson(),
      'hit_modifier': 0,
      'wound_modifier': 0,
      'bonus_strength': bonusStrength,
      'bonus_ap': bonusAp,
      'crit_hit_on': 6,
      'crit_wound_on': 6,
      'extra_abilities':
          extraAbilities.map(DiceJsonHelper.toRustWeaponAbility).toList(),
      'armor_of_contempt': defensiveArmorOfContempt,
      'minus_one_wound': defensiveMinusWound,
      'grant_invuln_4': defensiveGrantInvuln4,
      'grant_fnp_5': defensiveGrantFnp5,
      'minus_one_damage': defensiveGrantMinusDamage1,
      'half_damage': defensiveGrantHalfDamage,
      'stealth_active': false,
    };
  }

  static SimulationUiReport simulateMatchup({
    required WeaponUiProfile weapon,
    required UnitUiProfile target,
    required Map<String, dynamic> contextJson,
    int iterations = 10000,
  }) {
    final res = _call('simulate_matchup', {
      'weapon': weapon.toRustJson(),
      'target': target.toRustJson(),
      'context': contextJson,
      'iterations': iterations,
    });
    return SimulationUiReport.fromRustJson(res);
  }

  static SimulationUiReport simulateSquadMatchup({
    required List<WeaponLoadoutEntry> loadout,
    required UnitUiProfile target,
    required Map<String, dynamic> contextJson,
    int iterations = 10000,
  }) {
    final res = _call('simulate_squad_matchup', {
      'loadout': loadout.map((e) => e.toRustJson()).toList(),
      'target': target.toRustJson(),
      'context': contextJson,
      'iterations': iterations,
    });
    return SimulationUiReport.fromRustJson(res);
  }

  static BsDataFaction parseBsDataCatalogue(String jsonStr) {
    final res = _call('parse_bsdata_catalogue', jsonStr);
    return BsDataFaction.fromRustJson(res);
  }

  static ArmyListEvaluationUi evaluateArmyList({
    required ArmyListUi list,
    BsDataFaction? faction,
  }) {
    final res = _call('evaluate_army_list', {
      'list': list.toRustJson(),
      'faction': faction?.toRustJson(),
    });
    return ArmyListEvaluationUi.fromRustJson(res);
  }

  static WishlistOperationResponseUi upsertWishlist({
    required List<WishlistItemUi> items,
    required WishlistItemUi item,
    String? activeFactionId,
  }) {
    final res = _call('upsert_wishlist', {
      'items': items.map((e) => e.toRustJson()).toList(),
      'item': item.toRustJson(),
      'active_faction_id': activeFactionId,
    });
    return WishlistOperationResponseUi.fromRustJson(res);
  }

  static WishlistOperationResponseUi queryWishlist({
    required List<WishlistItemUi> items,
    String? factionId,
    String query = '',
    WishlistPriorityUi? priorityFilter,
    AcquisitionStateUi? stateFilter,
    WishlistSortFieldUi sortBy = WishlistSortFieldUi.priorityDesc,
  }) {
    final res = _call('query_wishlist', {
      'items': items.map((e) => e.toRustJson()).toList(),
      'faction_id': factionId,
      'query': query,
      'priority_filter': priorityFilter?.toRustJson(),
      'state_filter': stateFilter?.toRustJson(),
      'sort_by': sortBy.toRustJson(),
    });
    return WishlistOperationResponseUi.fromRustJson(res);
  }

  static MatchDashboardResponseUi evaluateMatches({
    required List<MatchRecordUi> matches,
    GameSystemUi? gameSystem,
    String query = '',
    String? factionFilter,
    MatchResultUi? resultFilter,
  }) {
    final res = _call('evaluate_matches', {
      'matches': matches.map((e) => e.toRustJson()).toList(),
      'game_system': gameSystem?.toRustJson(),
      'query': query,
      'faction_filter': factionFilter,
      'result_filter': resultFilter?.toRustJson(),
    });
    return MatchDashboardResponseUi.fromRustJson(res);
  }

  static PersonalDataStoreUi migratePersonalStore(String rawJson) {
    final res = _call('migrate_personal_store', rawJson);
    return PersonalDataStoreUi.fromRustJson(res);
  }
}
