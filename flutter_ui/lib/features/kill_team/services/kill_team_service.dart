import 'package:flutter/services.dart';
import '../../../bridge/omnispex_rust_bridge.dart';
import '../models/kill_team_models.dart';

class KillTeamService {
  static bool _bundleLoaded = false;

  /// Loads `assets/data/kill_team_bundle.json` into Rust's `EngineState` if not already loaded.
  static Future<void> ensureCatalogueLoaded() async {
    if (_bundleLoaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/kill_team_bundle.json');
      if (raw.trim().isNotEmpty && OmnispexRustBridge.isReady) {
        OmnispexRustBridge.callRpc('kt_load_catalogue', raw);
        _bundleLoaded = true;
      }
    } catch (_) {
      // Rust EngineState already initializes with `default_kill_team_catalogue()` seed on startup.
      _bundleLoaded = true;
    }
  }

  static List<KillTeamFactionUi> getFactions() {
    final res = OmnispexRustBridge.callRpc('kt_get_catalogue', {});
    if (res is Map<String, dynamic>) {
      final factionsRaw = res['factions'];
      if (factionsRaw is List) {
        return factionsRaw
            .map((e) =>
                KillTeamFactionUi.fromRustJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return const [];
  }

  static List<String> getFactionNames() {
    return getFactions().map((f) => f.name).toList();
  }

  static KillTeamFactionUi? getFactionDetail(String idOrName) {
    try {
      final res = OmnispexRustBridge.callRpc('kt_get_faction_detail', {
        'id_or_name': idOrName,
      });
      if (res is Map<String, dynamic>) {
        return KillTeamFactionUi.fromRustJson(res);
      }
    } catch (_) {}
    return null;
  }

  static List<OperativeDatacardUi> searchOperatives({
    String query = '',
    String? factionFilter,
    String? roleFilter,
  }) {
    final cleanFaction = (factionFilter == null ||
            factionFilter.isEmpty ||
            factionFilter == 'All Kill Teams')
        ? null
        : factionFilter;
    final cleanRole = (roleFilter == null ||
            roleFilter.isEmpty ||
            roleFilter == 'All Roles')
        ? null
        : roleFilter;
    final res = OmnispexRustBridge.callRpc('kt_search_operatives_full', {
      'query': query,
      'faction': cleanFaction,
      'role': cleanRole,
    });
    if (res is List) {
      return res
          .map((e) =>
              OperativeDatacardUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  static List<KillTeamEquipmentUi> getUniversalEquipment() {
    final res = OmnispexRustBridge.callRpc('kt_get_universal_equipment', {});
    if (res is List) {
      return res
          .map((e) =>
              KillTeamEquipmentUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  static KtShootingSimulationReportUi runShootingSimulation({
    required KtWeaponProfileUi weapon,
    required OperativeDatacardUi target,
    required KtShootingContextUi context,
    int iterations = 5000,
  }) {
    final res = OmnispexRustBridge.callRpc('kt_run_shooting_simulation', {
      'weapon': weapon.toRustJson(),
      'target': target.toRustJson(),
      'context': context.toRustJson(),
      'iterations': iterations,
    });
    if (res is Map<String, dynamic>) {
      return KtShootingSimulationReportUi.fromRustJson(res);
    }
    throw StateError('Invalid response from kt_run_shooting_simulation');
  }

  static KtFightSimulationReportUi runFightSimulation({
    required OperativeDatacardUi attacker,
    required KtWeaponProfileUi attackerWeapon,
    required OperativeDatacardUi defender,
    required KtWeaponProfileUi defenderWeapon,
    required KtFightContextUi context,
    int iterations = 5000,
  }) {
    final res = OmnispexRustBridge.callRpc('kt_run_fight_simulation', {
      'attacker': attacker.toRustJson(),
      'attacker_weapon': attackerWeapon.toRustJson(),
      'defender': defender.toRustJson(),
      'defender_weapon': defenderWeapon.toRustJson(),
      'context': context.toRustJson(),
      'iterations': iterations,
    });
    if (res is Map<String, dynamic>) {
      return KtFightSimulationReportUi.fromRustJson(res);
    }
    throw StateError('Invalid response from kt_run_fight_simulation');
  }

  static KtRosterValidationReportUi validateRoster(KillTeamRosterUi roster) {
    final res = OmnispexRustBridge.callRpc('kt_validate_roster', {
      'roster': roster.toRustJson(),
    });
    if (res is Map<String, dynamic>) {
      return KtRosterValidationReportUi.fromRustJson(res);
    }
    throw StateError('Invalid response from kt_validate_roster');
  }

  static String exportRosterText(KillTeamRosterUi roster) {
    final res = OmnispexRustBridge.callRpc('kt_export_roster_text', {
      'roster': roster.toRustJson(),
    });
    return res?.toString() ?? '';
  }
}
