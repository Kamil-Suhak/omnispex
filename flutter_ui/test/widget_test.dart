import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/bridge/omnispex_rust_bridge.dart';
import 'package:flutter_ui/features/kill_team/screens/kt_combat_screen.dart';
import 'package:flutter_ui/features/kill_team/screens/kt_operative_browser_screen.dart';
import 'package:flutter_ui/features/kill_team/screens/kt_roster_builder_screen.dart';
import 'package:flutter_ui/features/kill_team/services/kill_team_service.dart';
import 'package:flutter_ui/main.dart';
import 'package:flutter_ui/models/bsdata_models.dart';
import 'package:flutter_ui/models/omnispex_models.dart';
import 'package:flutter_ui/models/simulation_models.dart';
import 'package:flutter_ui/providers/app_state_provider.dart';
import 'package:flutter_ui/services/auth_service.dart';
import 'package:flutter_ui/services/bsdata_service.dart';
import 'package:flutter_ui/services/simulation_service.dart';
import 'package:flutter_ui/widgets/game_system_switcher.dart';
import 'test_fixtures.dart';

void main() {
  setUp(() async {
    await TestFixtures.seedDiskCaches();
    final sm = BsDataFaction.fromRustJson(TestFixtures.compliantChaptersJson);
    BsDataService.loadedFactionsMap.clear();
    BsDataService.loadedFactionsMap[sm.id] = sm;
    await OmnispexRustBridge.initialize();
    await KillTeamService.ensureCatalogueLoaded();
  });

  testWidgets(
      'Warhammer 40,000 shell navigation & Rust FFI engine calculations',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Verify Rust FFI calculateEngagement directly
    const weapon = WeaponUiProfile(
      name: 'Bolt Rifle',
      profileName: 'Standard',
      range: 24,
      attacks: '2',
      skill: 3,
      strength: 4,
      ap: 1,
      damage: '1',
      abilities: ['Heavy'],
    );
    const target = UnitUiProfile(
      name: 'Intercessor Squad',
      toughness: 4,
      save: 3,
      woundsPerModel: 2,
      modelCount: 5,
      keywords: ['INFANTRY'],
    );

    final simReport = SimulationService.calculateEngagement(
      weapon: weapon,
      target: target,
      weaponCount: 5,
      isStationary: true,
      iterations: 2000,
    );
    expect(simReport.expectedDamageDealt, greaterThan(0));
    expect(simReport.tacticalVerdict, isNotNull);
    expect(simReport.damageDistribution, isNotEmpty);

    // 2. Render MainShell in 40K mode and navigate tabs
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OmnispexApp(),
      ),
    );
    await tester.pump();

    // Verify 40K MainShell renders
    expect(find.text('OMNISPEX'), findsOneWidget);
    expect(find.text('PROBABILITY ENGINE'), findsOneWidget);
    expect(find.text('IN-BATTLE RESOLUTION'), findsOneWidget);

    // 1. Navigate to List-Build (11e Army List Builder)
    container.read(currentNavIndexProvider.notifier).state = 1;
    await tester.pump();
    expect(find.text('11TH EDITION ARMY LIST BUILDER'), findsOneWidget);
    expect(find.text('1st Company Strike Force'), findsWidgets);

    // 2. Navigate to Datasheets (Reference Browser)
    container.read(currentNavIndexProvider.notifier).state = 2;
    await tester.pump();
    expect(find.text('BSDATA UNIT & WEAPON BROWSER'), findsOneWidget);
    expect(find.text('Terminator Squad'), findsWidgets);

    // 3. Navigate to Wishlist
    container.read(currentNavIndexProvider.notifier).state = 3;
    await tester.pump();
    expect(find.text('UNIT WISHLIST & HOBBY TRACKER'), findsOneWidget);
    expect(find.text('Redemptor Dreadnought'), findsWidgets);

    // 4. Navigate to Matches (40K & Kill Team)
    container.read(currentNavIndexProvider.notifier).state = 4;
    await tester.pump();
    expect(
        find.text('MATCH HISTORY & PERFORMANCE ANALYTICS'), findsOneWidget);
    expect(find.textContaining('Angels of Death vs Kommandos'), findsOneWidget);

    // 5. Navigate to Settings & Provenance
    container.read(currentNavIndexProvider.notifier).state = 5;
    await tester.pump();
    expect(find.text('SETTINGS & ARCHETYPES'), findsOneWidget);
    expect(find.text('3. WARHAMMER 11E GAME DATA & PROVENANCE'), findsOneWidget);
  });

  testWidgets(
      'Switching to Kill Team verifies KtCombatScreen, KtRosterBuilderScreen, and KtOperativeBrowserScreen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OmnispexApp(),
      ),
    );
    await tester.pump();

    // Verify GameSystemSwitcherButton and switch to Kill Team
    expect(find.byType(GameSystemSwitcherButton), findsOneWidget);
    await tester.tap(find.byType(GameSystemSwitcherButton));
    await tester.pump();

    expect(find.text('SELECT GAME SYSTEM'), findsOneWidget);
    expect(find.text('KILL TEAM (2024 EDITION)'), findsOneWidget);

    await tester.tap(find.text('KILL TEAM (2024 EDITION)'));
    await tester.pump();

    expect(container.read(activeGameSystemProvider), equals(GameSystemUi.killTeam));

    // Tab 0: KtCombatScreen with Shooting and Fight (Strike/Parry duel)
    container.read(currentNavIndexProvider.notifier).state = 0;
    await tester.pump();
    expect(find.byType(KtCombatScreen), findsOneWidget);
    expect(find.text('KILL TEAM COMBAT RESOLUTION'), findsOneWidget);
    expect(find.text('SHOOTING'), findsOneWidget);
    expect(find.text('FIGHT (STRIKE / PARRY)'), findsOneWidget);

    // Switch to Fight Strike/Parry duel via Rust FFI
    await tester.tap(find.text('FIGHT (STRIKE / PARRY)'));
    await tester.pump();
    expect(find.text('MELEE DUEL MODIFIERS'), findsWidgets);

    // Tab 1: KtRosterBuilderScreen
    container.read(currentNavIndexProvider.notifier).state = 1;
    await tester.pump();
    expect(find.byType(KtRosterBuilderScreen), findsOneWidget);
    expect(find.textContaining('ROSTER'), findsWidgets);

    // Tab 2: KtOperativeBrowserScreen
    container.read(currentNavIndexProvider.notifier).state = 2;
    await tester.pump();
    expect(find.byType(KtOperativeBrowserScreen), findsOneWidget);
    expect(find.text('KILL TEAM OPERATIVE DATACARDS'), findsOneWidget);
  });

  test(
      'Single-key authentication generates omnispex_<64-hex> key and imports credentials',
      () async {
    // 1. Generate unique 256-bit key on startup
    final creds = await AuthService.getOrCreateCredentials();
    expect(creds.accessKey.startsWith('omnispex_'), isTrue);
    expect(creds.accessKey.length, equals(73)); // 'omnispex_' (9) + 64 hex characters (32 bytes)
    final hexPart = creds.accessKey.substring('omnispex_'.length);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hexPart), isTrue);
    expect(creds.accountKey, equals(creds.accessKey));

    // 2. Parse valid single key
    final parsed = DeviceCredentials.tryParseAccountKey(creds.accountKey);
    expect(parsed, isNotNull);
    expect(parsed!.accessKey, equals(creds.accessKey));

    // 3. Import new credentials with 64-hex key
    const testImportKey =
        'omnispex_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    final imported = await AuthService.importCredentials(testImportKey);
    expect(imported, isTrue);

    final updatedCreds = await AuthService.getOrCreateCredentials();
    expect(updatedCreds.accessKey, equals(testImportKey));

    // 4. Verify Bearer header formatting
    final headers = AuthService.getAuthHeaders(updatedCreds);
    expect(headers['Authorization'], equals('Bearer $testImportKey'));
    expect(headers['Content-Type'], equals('application/json'));
  });

  test('PersonalStoreNotifier army list, wishlist, and match operations work', () {
    final notifier = PersonalStoreNotifier();

    // Verify starter data exists
    expect(notifier.state.armyLists, isNotEmpty);
    expect(notifier.state.wishlistItems, isNotEmpty);
    expect(notifier.state.matches.length, greaterThanOrEqualTo(2));

    // Upsert wishlist item deduplicates by faction + unit name
    final initialCount = notifier.state.wishlistItems.length;
    notifier.upsertWishlistItem(
      WishlistItemUi(
        id: 'wl-redemptor-dup',
        factionId: 'compliant-chapters',
        factionName: 'Adeptus Astartes - Compliant Chapters',
        unitId: 'sm_redemptor',
        unitName: 'Redemptor Dreadnought',
        quantityDesired: 3,
        quantityOwned: 2,
        pointsPerUnit: 210,
        priority: WishlistPriorityUi.critical,
        state: AcquisitionStateUi.paradeReady,
        updatedAtIso: DateTime.now().toIso8601String(),
      ),
    );
    expect(notifier.state.wishlistItems.length, equals(initialCount));
    final updatedRedemptor = notifier.state.wishlistItems
        .firstWhere((i) => i.unitName == 'Redemptor Dreadnought');
    expect(updatedRedemptor.quantityDesired, equals(3));
    expect(updatedRedemptor.state, equals(AcquisitionStateUi.paradeReady));
  });
}
