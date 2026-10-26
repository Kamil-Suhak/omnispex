import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bsdata_models.dart';
import '../models/omnispex_models.dart';
import '../models/simulation_models.dart';
import '../services/personal_data_service.dart';
import '../services/simulation_service.dart';

final isDeepAnalyticsModeProvider = StateProvider<bool>((ref) => false);
final currentNavIndexProvider = StateProvider<int>((ref) => 0);

final customArsenalProvider = StateProvider<List<WeaponUiProfile>>(
    (ref) => List.from(SimulationService.defaultWeapons));

final customArchetypesProvider = StateProvider<List<ArchetypeEntryUi>>(
    (ref) => List.from(SimulationService.defaultArchetypes));

final simulationIterationsProvider = StateProvider<int>((ref) => 10000);
final confidenceThresholdProvider = StateProvider<int>((ref) => 80);

final loadedAttackerNameProvider = StateProvider<String?>((ref) => null);
final loadedDefenderNameProvider = StateProvider<String?>((ref) => null);

final catalogueRevisionEpochProvider = StateProvider<int>((ref) => 0);
final activeArmyListIdProvider = StateProvider<String?>((ref) => null);

class PersonalStoreNotifier extends StateNotifier<PersonalDataStoreUi> {
  PersonalStoreNotifier() : super(_createStarterStore());

  static PersonalDataStoreUi _createStarterStore() {
    final now = DateTime.now().toIso8601String();
    final starterList = ArmyListUi(
      id: 'starter-sm-gladius',
      name: '1st Company Strike Force',
      factionId: 'sm-1',
      factionName: 'Imperium - Space Marines',
      battleSize: BattleSizeUi.strikeForce,
      pointsLimit: 2000,
      detachments: const [
        SelectedDetachmentUi(
          id: 'gladius_task_force',
          name: 'Gladius Task Force',
          dpCost: 2,
        ),
      ],
      units: const [
        RosterUnitEntryUi(
          entryId: 'entry-capt-1',
          unitId: 'sm_captain_terminator',
          unitName: 'Captain in Terminator Armour',
          modelsCount: 1,
          basePoints: 95,
          enhancementId: 'fire_discipline',
          enhancementName: 'Fire Discipline',
          enhancementPoints: 25,
          isWarlord: true,
          attachedToEntryId: 'entry-term-1',
          categories: ['Infantry', 'Character', 'Terminator', 'Imperium'],
        ),
        RosterUnitEntryUi(
          entryId: 'entry-term-1',
          unitId: 'sm_terminators',
          unitName: 'Terminator Squad',
          modelsCount: 5,
          basePoints: 175,
          categories: ['Infantry', 'Terminator', 'Imperium'],
        ),
        RosterUnitEntryUi(
          entryId: 'entry-int-1',
          unitId: 'sm_intercessors',
          unitName: 'Intercessor Squad',
          modelsCount: 5,
          basePoints: 80,
          categories: ['Infantry', 'Battleline', 'Imperium'],
        ),
      ],
      notes: 'Balanced Strike Force core with Terminator anvil.',
      createdAtIso: now,
      updatedAtIso: now,
    );

    final starterWishlist = [
      WishlistItemUi(
        id: 'wl-redemptor',
        factionId: 'sm-1',
        factionName: 'Space Marines',
        unitId: 'sm_redemptor',
        unitName: 'Redemptor Dreadnought',
        quantityDesired: 2,
        quantityOwned: 1,
        pointsPerUnit: 210,
        priority: WishlistPriorityUi.high,
        state: AcquisitionStateUi.battleReady,
        notes: 'Magnetize Macro Plasma & Heavy Onslaught Gatling.',
        updatedAtIso: now,
      ),
      WishlistItemUi(
        id: 'wl-land-raider',
        factionId: 'sm-1',
        factionName: 'Space Marines',
        unitId: 'sm_land_raider',
        unitName: 'Land Raider',
        quantityDesired: 1,
        quantityOwned: 0,
        pointsPerUnit: 240,
        priority: WishlistPriorityUi.critical,
        state: AcquisitionStateUi.wishlist,
        notes: 'Assault Ramp transport for Terminators.',
        updatedAtIso: now,
      ),
    ];

    final starterMatches = [
      MatchRecordUi(
        id: 'match-40k-1',
        gameSystem: GameSystemUi.warhammer40k,
        dateIso: '2026-10-20',
        playerFaction: 'Space Marines',
        opponentFaction: 'Necrons',
        opponentName: 'Phaeron Ahmontekh',
        playerScore: 84,
        opponentScore: 71,
        result: MatchResultUi.win,
        isDetailed: true,
        wh40kDetails: const Wh40kMatchDetailsUi(
          battleSize: 'Strike Force',
          pointsLimit: 2000,
          missionPack: 'Chapter Approved',
          primaryMission: 'Take and Hold',
          deployment: 'Hammer and Anvil',
          playerDetachment: 'Gladius Task Force',
          opponentDetachment: 'Awakened Dynasty',
          armyListId: 'starter-sm-gladius',
          armyListName: '1st Company Strike Force',
          rounds: [
            Wh40kRoundScoreUi(
                round: 1,
                playerPrimary: 0,
                playerSecondary: 5,
                opponentPrimary: 0,
                opponentSecondary: 4),
            Wh40kRoundScoreUi(
                round: 2,
                playerPrimary: 10,
                playerSecondary: 8,
                opponentPrimary: 10,
                opponentSecondary: 6),
            Wh40kRoundScoreUi(
                round: 3,
                playerPrimary: 15,
                playerSecondary: 8,
                opponentPrimary: 10,
                opponentSecondary: 8),
            Wh40kRoundScoreUi(
                round: 4,
                playerPrimary: 15,
                playerSecondary: 8,
                opponentPrimary: 15,
                opponentSecondary: 5),
            Wh40kRoundScoreUi(
                round: 5,
                playerPrimary: 10,
                playerSecondary: 5,
                opponentPrimary: 10,
                opponentSecondary: 3),
          ],
          playerBattleReadyBonus: true,
          opponentBattleReadyBonus: true,
        ),
        notes: 'Terminators held center objective through Round 4.',
        createdAtIso: now,
        updatedAtIso: now,
      ),
      MatchRecordUi(
        id: 'match-kt-1',
        gameSystem: GameSystemUi.killTeam,
        dateIso: '2026-10-22',
        playerFaction: 'Angels of Death',
        opponentFaction: 'Kommandos',
        opponentName: 'Boss Snikrot',
        playerScore: 18,
        opponentScore: 15,
        result: MatchResultUi.win,
        isDetailed: true,
        killTeamDetails: const KillTeamMatchDetailsUi(
          killzone: 'Killzone: Volkus',
          critOpMission: 'Secure',
          playerTacOpArchetype: 'Seek & Destroy',
          playerTacOpName: 'Champion',
          playerPrimaryOp: 'Crit Op',
          opponentPrimaryOp: 'Kill Op',
          playerPaintedBonus: true,
          opponentPaintedBonus: true,
          turningPoints: [
            KillTeamTurningPointScoreUi(
                turningPoint: 1,
                playerCritOp: 1,
                playerTacOp: 0,
                playerKillOp: 1,
                opponentCritOp: 1,
                opponentTacOp: 0,
                opponentKillOp: 1),
            KillTeamTurningPointScoreUi(
                turningPoint: 2,
                playerCritOp: 2,
                playerTacOp: 2,
                playerKillOp: 1,
                opponentCritOp: 1,
                opponentTacOp: 1,
                opponentKillOp: 2),
            KillTeamTurningPointScoreUi(
                turningPoint: 3,
                playerCritOp: 2,
                playerTacOp: 2,
                playerKillOp: 2,
                opponentCritOp: 1,
                opponentTacOp: 2,
                opponentKillOp: 2),
            KillTeamTurningPointScoreUi(
                turningPoint: 4,
                playerCritOp: 1,
                playerTacOp: 1,
                playerKillOp: 1,
                opponentCritOp: 1,
                opponentTacOp: 1,
                opponentKillOp: 0),
          ],
        ),
        notes: 'Close Killzone Volkus firefight; Crit Op Primary bonus secured win.',
        createdAtIso: now,
        updatedAtIso: now,
      ),
    ];

    return PersonalDataStoreUi(
      schemaVersion: 2,
      armyLists: [starterList],
      wishlistItems: starterWishlist,
      matches: starterMatches,
    );
  }

  Future<void> loadFromDisk() async {
    final loaded = await PersonalDataService.loadPersonalStore();
    if (loaded.armyLists.isNotEmpty ||
        loaded.wishlistItems.isNotEmpty ||
        loaded.matches.isNotEmpty ||
        loaded.savedCalculations.isNotEmpty) {
      state = loaded;
    }
  }

  Future<void> _persist() async {
    await PersonalDataService.savePersonalStore(state);
  }

  void upsertArmyList(ArmyListUi list) {
    final lists = List<ArmyListUi>.from(state.armyLists);
    final idx = lists.indexWhere((l) => l.id == list.id);
    if (idx >= 0) {
      lists[idx] = list;
    } else {
      lists.insert(0, list);
    }
    state = state.copyWith(armyLists: lists);
    _persist();
  }

  void deleteArmyList(String listId) {
    final lists = state.armyLists.where((l) => l.id != listId).toList();
    state = state.copyWith(armyLists: lists);
    _persist();
  }

  ArmyListUi duplicateArmyList(ArmyListUi source) {
    final now = DateTime.now().toIso8601String();
    final copy = source.copyWith(
      id: 'list-${DateTime.now().microsecondsSinceEpoch}',
      name: '${source.name} (Copy)',
      createdAtIso: now,
      updatedAtIso: now,
    );
    upsertArmyList(copy);
    return copy;
  }

  ArmyListUi addUnitToArmyList({
    required BsDataUnit unit,
    String? targetListId,
  }) {
    final now = DateTime.now().toIso8601String();
    ArmyListUi targetList;
    if (targetListId != null &&
        state.armyLists.any((l) => l.id == targetListId)) {
      targetList = state.armyLists.firstWhere((l) => l.id == targetListId);
    } else if (state.armyLists.any((l) =>
        l.factionId.toLowerCase() == unit.factionId.toLowerCase() ||
        l.factionName.toLowerCase().contains(unit.faction.toLowerCase()))) {
      targetList = state.armyLists.firstWhere((l) =>
          l.factionId.toLowerCase() == unit.factionId.toLowerCase() ||
          l.factionName.toLowerCase().contains(unit.faction.toLowerCase()));
    } else if (state.armyLists.isNotEmpty) {
      targetList = state.armyLists.first;
    } else {
      targetList = ArmyListUi(
        id: 'list-${DateTime.now().microsecondsSinceEpoch}',
        name: '${unit.faction} Roster',
        factionId: unit.factionId.isNotEmpty ? unit.factionId : unit.faction,
        factionName: unit.faction,
        battleSize: BattleSizeUi.strikeForce,
        pointsLimit: 2000,
        createdAtIso: now,
        updatedAtIso: now,
      );
    }

    final sizeOpt = unit.legalSizeOptions.first;
    final hasWarlord = targetList.units.any((u) => u.isWarlord);
    final newEntry = RosterUnitEntryUi(
      entryId: 'entry-${DateTime.now().microsecondsSinceEpoch}',
      unitId: unit.id,
      unitName: unit.name,
      modelsCount: sizeOpt.models,
      optionDescription: sizeOpt.description,
      basePoints: sizeOpt.points,
      isWarlord: !hasWarlord && unit.isCharacter,
      categories: unit.categories,
    );

    final updatedList = targetList.copyWith(
      units: [...targetList.units, newEntry],
      updatedAtIso: now,
    );
    upsertArmyList(updatedList);
    return updatedList;
  }

  void upsertWishlistItem(WishlistItemUi item, {String? activeFactionId}) {
    final res = PersonalDataService.upsertWishlist(
      items: state.wishlistItems,
      item: item,
      activeFactionId: activeFactionId,
    );
    state = state.copyWith(wishlistItems: res.items);
    _persist();
  }

  void deleteWishlistItem(String itemId) {
    final updated =
        state.wishlistItems.where((i) => i.id != itemId).toList();
    state = state.copyWith(wishlistItems: updated);
    _persist();
  }

  void upsertMatch(MatchRecordUi match) {
    final list = List<MatchRecordUi>.from(state.matches);
    final idx = list.indexWhere((m) => m.id == match.id);
    if (idx >= 0) {
      list[idx] = match;
    } else {
      list.insert(0, match);
    }
    state = state.copyWith(matches: list);
    _persist();
  }

  void deleteMatch(String matchId) {
    final list = state.matches.where((m) => m.id != matchId).toList();
    state = state.copyWith(matches: list);
    _persist();
  }

  void saveCalculationConfig(SavedCalculationConfigUi config) {
    final list = List<SavedCalculationConfigUi>.from(state.savedCalculations);
    final idx = list.indexWhere((c) => c.id == config.id);
    if (idx >= 0) {
      list[idx] = config;
    } else {
      list.insert(0, config);
    }
    state = state.copyWith(savedCalculations: list);
    _persist();
  }

  void deleteCalculationConfig(String configId) {
    final list =
        state.savedCalculations.where((c) => c.id != configId).toList();
    state = state.copyWith(savedCalculations: list);
    _persist();
  }

  void restoreBackup(PersonalDataStoreUi restored) {
    state = restored;
    _persist();
  }
}

final personalStoreProvider =
    StateNotifierProvider<PersonalStoreNotifier, PersonalDataStoreUi>(
  (ref) => PersonalStoreNotifier(),
);
