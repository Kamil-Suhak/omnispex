import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/models/bsdata_models.dart';
import 'package:flutter_ui/theme/omnispex_theme.dart';
import 'package:flutter_ui/widgets/unit_details_modal.dart';
import 'test_fixtures.dart';

void main() {
  testWidgets('unit details modal renders profile, weapons and keywords', (tester) async {
    final faction = BsDataFaction.fromRustJson(TestFixtures.compliantChaptersJson);
    final unit = faction.units.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: OmnispexTheme.darkTheme,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showUnitDetailsModal(ctx, unit),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Terminator Squad'), findsOneWidget);
    expect(find.text('Storm Bolter'), findsOneWidget);
  });
}
