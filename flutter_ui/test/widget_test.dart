import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/main.dart';

void main() {
  testWidgets('OmnispexApp loads and renders main shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OmnispexApp()));
    expect(find.text('OMNISPEX'), findsOneWidget);
    expect(find.text('PROBABILITY ENGINE'), findsOneWidget);
  });
}
