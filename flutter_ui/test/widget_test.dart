import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/main.dart';
import 'package:flutter_ui/models/omnispex_models.dart';
import 'package:flutter_ui/providers/app_state_provider.dart';

void main() {
  testWidgets('OmnispexApp loads and renders main shell and calculator',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OmnispexApp()));
    await tester.pump();

    expect(find.text('OMNISPEX'), findsOneWidget);
    expect(find.text('PROBABILITY ENGINE'), findsOneWidget);
    expect(find.text('IN-BATTLE RESOLUTION'), findsOneWidget);
  });

  testWidgets('Navigates across Army Lists, Datasheets, Wishlist, Matches, and Settings',
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
        factionId: 'sm-1',
        factionName: 'Space Marines',
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
