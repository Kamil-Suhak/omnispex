import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/screens/main_shell.dart';
import 'package:flutter_ui/theme/omnispex_theme.dart';
import 'package:flutter_ui/widgets/scannable_metric_card.dart';
import 'package:flutter_ui/widgets/stat_badge.dart';
import 'package:flutter_ui/widgets/tactical_card.dart';
import 'package:flutter_ui/widgets/tactical_verdict_badge.dart';

void main() {
  testWidgets('TacticalCard and StatBadge render correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmnispexTheme.darkTheme,
        home: const Scaffold(
          body: TacticalCard(
            title: "Test Card",
            child: StatBadge(label: "BS", value: "3+"),
          ),
        ),
      ),
    );

    expect(find.text("TEST CARD"), findsOneWidget);
    expect(find.text("BS "), findsOneWidget);
    expect(find.text("3+"), findsOneWidget);
  });

  testWidgets('TacticalVerdictBadge renders Traffic Light states', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmnispexTheme.darkTheme,
        home: const Scaffold(
          body: Column(
            children: [
              TacticalVerdictBadge(verdict: VerdictType.greenReliableKill),
              TacticalVerdictBadge(verdict: VerdictType.yellowChipContest),
              TacticalVerdictBadge(verdict: VerdictType.redIneffective),
            ],
          ),
        ),
      ),
    );

    expect(find.text("RELIABLE KILL / HIGH VALUE"), findsOneWidget);
    expect(find.text("CHIP / CONTEST TARGET (HALF STRENGTH)"), findsOneWidget);
    expect(find.text("INEFFECTIVE TARGET (LOW DAMAGE)"), findsOneWidget);
  });

  testWidgets('ScannableMetricCard renders 80% safe bet metric', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmnispexTheme.darkTheme,
        home: const Scaffold(
          body: ScannableMetricCard(
            label: "Safe Bet (80% Floor)",
            value: "4 models",
            subtitle: "Guaranteed 80% confidence",
          ),
        ),
      ),
    );

    expect(find.text("SAFE BET (80% FLOOR)"), findsOneWidget);
    expect(find.text("4 models"), findsOneWidget);
  });

  testWidgets('MainShell renders adaptive navigation and mode toggle', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MainShell(),
        ),
      ),
    );

    expect(find.text("OMNISPEX"), findsOneWidget);
    expect(find.text("SIMPLIFIED VIEW"), findsOneWidget);
  });
}
