import 'dart:convert';
import '../bridge/omnispex_rust_bridge.dart';
import '../models/bsdata_models.dart';
import '../models/omnispex_models.dart';
import 'storage_adapter_stub.dart'
    if (dart.library.io) 'storage_adapter_native.dart'
    if (dart.library.js_interop) 'storage_adapter_web.dart';

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

  static Future<PersonalDataStoreUi> loadPersonalStore() async {
    final raw = await readPersonalStoreRaw();
    if (raw == null || raw.trim().isEmpty) {
      return const PersonalDataStoreUi();
    }
    try {
      if (OmnispexRustBridge.isReady) {
        return OmnispexRustBridge.migratePersonalStore(raw);
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PersonalDataStoreUi.fromRustJson(decoded);
      }
    } catch (_) {}
    return const PersonalDataStoreUi();
  }

  static Future<void> savePersonalStore(PersonalDataStoreUi store) async {
    final jsonStr =
        const JsonEncoder.withIndent('  ').convert(store.toRustJson());
    await writePersonalStoreRaw(jsonStr);
  }

  static String exportBackupJson(PersonalDataStoreUi store) {
    return const JsonEncoder.withIndent('  ').convert(store.toRustJson());
  }

  static PersonalDataStoreUi restoreFromBackupJson(String rawJson) {
    if (OmnispexRustBridge.isReady) {
      return OmnispexRustBridge.migratePersonalStore(rawJson);
    }
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON backup object.');
    }
    return PersonalDataStoreUi.fromRustJson(decoded);
  }

  static ArmyListEvaluationUi evaluateArmyList({
    required ArmyListUi list,
    BsDataFaction? faction,
  }) {
    if (OmnispexRustBridge.isReady) {
      return OmnispexRustBridge.evaluateArmyList(list: list, faction: faction);
    }
    // Fallback for test environments where native FFI library is not loaded
    final violations = <ValidationIssueUi>[];
    final warnings = <ValidationIssueUi>[];
    final unverified = <String>[];
    final totalPts = list.totalPoints;
    final ptsLimit = list.pointsLimit;
    final totalDp = list.totalDp;
    final dpLimit = list.battleSize.dpLimit;
    final enhLimit = list.battleSize.enhancementLimit;

    if (totalPts > ptsLimit) {
      violations.add(ValidationIssueUi(
        severity: 'error',
        code: 'POINTS_EXCEEDED',
        message:
            'Army total ($totalPts pts) exceeds the battle size limit of $ptsLimit pts.',
      ));
    }
    if (totalDp > dpLimit) {
      violations.add(ValidationIssueUi(
        severity: 'error',
        code: 'DP_EXCEEDED',
        message:
            'Detachment Points spent ($totalDp DP) exceed ${list.battleSize.label} limit of $dpLimit DP.',
      ));
    }
    final warlords = list.units.where((u) => u.isWarlord).toList();
    if (list.units.isNotEmpty && warlords.isEmpty) {
      violations.add(const ValidationIssueUi(
        severity: 'error',
        code: 'MISSING_WARLORD',
        message: 'Every army list must designate exactly 1 Warlord.',
      ));
    } else if (warlords.length > 1) {
      violations.add(ValidationIssueUi(
        severity: 'error',
        code: 'MULTIPLE_WARLORDS',
        message:
            'Only 1 model can be designated Warlord (${warlords.length} selected).',
      ));
    }
    int enhSlots = 0;
    for (final u in list.units) {
      if (u.enhancementId != null) {
        enhSlots += u.enhancementIsUpgrade ? 2 : 1;
        if (u.isEpicHero) {
          violations.add(ValidationIssueUi(
            severity: 'error',
            code: 'EPIC_HERO_ENHANCEMENT',
            message:
                "Epic Hero '${u.unitName}' cannot be given an Enhancement.",
            affectedEntryId: u.entryId,
          ));
        }
      }
    }
    if (enhSlots > enhLimit) {
      violations.add(ValidationIssueUi(
        severity: 'error',
        code: 'ENHANCEMENT_SLOTS_EXCEEDED',
        message:
            'Enhancement slots used ($enhSlots) exceed limit of $enhLimit.',
      ));
    }

    final report = ListValidationReportUi(
      isValid: violations.isEmpty,
      totalPoints: totalPts,
      pointsLimit: ptsLimit,
      totalDp: totalDp,
      dpLimit: dpLimit,
      enhancementSlotsUsed: enhSlots,
      enhancementLimit: enhLimit,
      violations: violations,
      warnings: warnings,
      unverifiedRules: unverified,
    );

    final buf = StringBuffer();
    buf.writeln('=== ${list.name} ===');
    buf.writeln('Faction: ${list.factionName}');
    buf.writeln(
        'Battle Size: ${list.battleSize.label} [$totalPts / $ptsLimit pts]');
    buf.writeln('Detachments ($totalDp / $dpLimit DP):');
    for (final d in list.detachments) {
      buf.writeln('  - ${d.name} (${d.dpCost} DP)');
    }
    buf.writeln('\nUnits (${list.units.length}):');
    for (final u in list.units) {
      final wl = u.isWarlord ? ' [WARLORD]' : '';
      final enh =
          u.enhancementName != null ? ' + ${u.enhancementName}' : '';
      buf.writeln(
          '  * ${u.unitName} (${u.modelsCount} models)$wl$enh — ${u.totalPoints} pts');
    }

    return ArmyListEvaluationUi(
      list: list,
      validation: report,
      exportedText: buf.toString(),
    );
  }

  static WishlistOperationResponseUi upsertWishlist({
    required List<WishlistItemUi> items,
    required WishlistItemUi item,
    String? activeFactionId,
  }) {
    if (OmnispexRustBridge.isReady) {
      return OmnispexRustBridge.upsertWishlist(
        items: items,
        item: item,
        activeFactionId: activeFactionId,
      );
    }
    final updated = List<WishlistItemUi>.from(items);
    final idx = updated.indexWhere((existing) =>
        existing.id == item.id ||
        (existing.factionId.toLowerCase() == item.factionId.toLowerCase() &&
            existing.unitName.toLowerCase() == item.unitName.toLowerCase()));
    if (idx >= 0) {
      updated[idx] = item;
    } else {
      updated.add(item);
    }
    return queryWishlist(items: updated, factionId: activeFactionId);
  }

  static WishlistOperationResponseUi queryWishlist({
    required List<WishlistItemUi> items,
    String? factionId,
    String query = '',
    WishlistPriorityUi? priorityFilter,
    AcquisitionStateUi? stateFilter,
    WishlistSortFieldUi sortBy = WishlistSortFieldUi.priorityDesc,
  }) {
    if (OmnispexRustBridge.isReady) {
      return OmnispexRustBridge.queryWishlist(
        items: items,
        factionId: factionId,
        query: query,
        priorityFilter: priorityFilter,
        stateFilter: stateFilter,
        sortBy: sortBy,
      );
    }
    final q = query.trim().toLowerCase();
    final filtered = items.where((item) {
      if (factionId != null &&
          factionId.isNotEmpty &&
          factionId != 'All Factions' &&
          item.factionId.toLowerCase() != factionId.toLowerCase() &&
          item.factionName.toLowerCase() != factionId.toLowerCase()) {
        return false;
      }
      if (priorityFilter != null && item.priority != priorityFilter) {
        return false;
      }
      if (stateFilter != null && item.state != stateFilter) {
        return false;
      }
      if (q.isNotEmpty &&
          !item.unitName.toLowerCase().contains(q) &&
          !item.factionName.toLowerCase().contains(q) &&
          !item.notes.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    final scoped = items.where((item) {
      if (factionId != null &&
          factionId.isNotEmpty &&
          factionId != 'All Factions') {
        return item.factionId.toLowerCase() == factionId.toLowerCase() ||
            item.factionName.toLowerCase() == factionId.toLowerCase();
      }
      return true;
    }).toList();

    final desired = scoped.fold(0, (s, i) => s + i.quantityDesired);
    final owned = scoped.fold(0, (s, i) => s + i.quantityOwned);
    final rem = scoped.fold(0, (s, i) => s + i.remainingToAcquire);
    final ptsDesired = scoped.fold(0, (s, i) => s + i.totalPointsDesired);
    final ptsOwned =
        scoped.fold(0, (s, i) => s + i.quantityOwned * i.pointsPerUnit);

    return WishlistOperationResponseUi(
      items: items,
      filteredItems: filtered,
      summary: WishlistSummaryUi(
        factionFilter: factionId,
        totalDistinctUnits: scoped.length,
        totalBoxesDesired: desired,
        totalBoxesOwned: owned,
        totalBoxesRemaining: rem,
        totalPointsDesired: ptsDesired,
        totalPointsOwned: ptsOwned,
        criticalPriorityCount: scoped
            .where((i) => i.priority == WishlistPriorityUi.critical)
            .length,
        highPriorityCount:
            scoped.where((i) => i.priority == WishlistPriorityUi.high).length,
        paintedEntriesCount: scoped
            .where((i) =>
                i.state == AcquisitionStateUi.battleReady ||
                i.state == AcquisitionStateUi.paradeReady)
            .length,
        acquiredEntriesCount: scoped
            .where((i) =>
                i.state != AcquisitionStateUi.wishlist &&
                i.state != AcquisitionStateUi.ordered)
            .length,
        completionPercent: desired > 0
            ? ((owned / desired) * 100.0).clamp(0.0, 100.0)
            : 0.0,
      ),
    );
  }

  static MatchDashboardResponseUi evaluateMatches({
    required List<MatchRecordUi> matches,
    GameSystemUi? gameSystem,
    String query = '',
    String? factionFilter,
    MatchResultUi? resultFilter,
  }) {
    if (OmnispexRustBridge.isReady) {
      return OmnispexRustBridge.evaluateMatches(
        matches: matches,
        gameSystem: gameSystem,
        query: query,
        factionFilter: factionFilter,
        resultFilter: resultFilter,
      );
    }
    final q = query.trim().toLowerCase();
    final filtered = matches.where((m) {
      if (gameSystem != null && m.gameSystem != gameSystem) return false;
      if (resultFilter != null && m.result != resultFilter) return false;
      if (factionFilter != null &&
          factionFilter.isNotEmpty &&
          factionFilter != 'All Factions' &&
          m.playerFaction.toLowerCase() != factionFilter.toLowerCase() &&
          m.opponentFaction.toLowerCase() != factionFilter.toLowerCase()) {
        return false;
      }
      if (q.isNotEmpty &&
          !m.playerFaction.toLowerCase().contains(q) &&
          !m.opponentFaction.toLowerCase().contains(q) &&
          !m.opponentName.toLowerCase().contains(q) &&
          !m.notes.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    final completed = filtered
        .where((m) => m.result != MatchResultUi.inProgress)
        .toList();
    final wins = completed.where((m) => m.result == MatchResultUi.win).length;
    final losses =
        completed.where((m) => m.result == MatchResultUi.loss).length;
    final draws = completed.where((m) => m.result == MatchResultUi.draw).length;
    final total = completed.length;
    final winRate = total > 0 ? (wins / total) * 100.0 : 0.0;
    final avgPlayer = total > 0
        ? completed.fold(0, (s, m) => s + m.playerScore) / total
        : 0.0;
    final avgOpp = total > 0
        ? completed.fold(0, (s, m) => s + m.opponentScore) / total
        : 0.0;

    return MatchDashboardResponseUi(
      filteredMatches: filtered,
      statistics: MatchStatisticsReportUi(
        scopeExplanation:
            'Completed matches only (in-progress games excluded from win rates).',
        gameSystemFilter: gameSystem,
        totalCompletedGames: total,
        incompleteGamesExcluded: filtered.length - total,
        wins: wins,
        losses: losses,
        draws: draws,
        winRatePercent: winRate,
        averagePlayerScore: avgPlayer,
        averageOpponentScore: avgOpp,
        averageDifferential: avgPlayer - avgOpp,
        recentResults: completed.take(10).map((m) => m.result).toList(),
      ),
      killTeamFactions: defaultKillTeamFactions,
    );
  }
}
