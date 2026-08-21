import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/screens/in_battle_screen.dart';
import 'package:flutter_ui/screens/list_building_screen.dart';
import 'package:flutter_ui/screens/main_shell.dart';
import 'package:flutter_ui/screens/settings_screen.dart';
import 'package:flutter_ui/screens/unit_browser_screen.dart';
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

  testWidgets('ListBuildingScreen renders 5 archetypes and points efficiency', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ListBuildingScreen()),
        ),
      ),
    );

    expect(find.text("LIST-BUILDING BENCHMARK"), findsOneWidget);
    expect(find.text("DEFENSIVE ARCHETYPE MATRIX"), findsOneWidget);
    expect(find.text("Chaff / Light Infantry (GEQ)"), findsOneWidget);
    expect(find.text("Standard Marine (MEQ)"), findsOneWidget);
    expect(find.text("Heavy Elite Infantry (TEQ)"), findsOneWidget);
    expect(find.text("Light Transport / Skimmer"), findsOneWidget);
    expect(find.text("Heavy Armor / Monster"), findsOneWidget);
  });

  testWidgets('SettingsScreen renders simulation engine and archetype configs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    expect(find.text("SETTINGS & ARCHETYPES"), findsOneWidget);
    expect(find.text("1. SIMULATION ENGINE PARAMETERS"), findsOneWidget);
    expect(find.text("2. CUSTOMIZABLE DEFENSIVE ARCHETYPES"), findsOneWidget);
  });

  testWidgets('UnitBrowserScreen renders search bar and bundled 40k units', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: UnitBrowserScreen()),
        ),
      ),
    );

    expect(find.text("BSDATA UNIT & WEAPON BROWSER"), findsOneWidget);
    expect(find.text("SEARCH & ROSTER FILTERS"), findsOneWidget);
    expect(find.text("Battlewagon"), findsOneWidget);
    expect(find.text("Terminator Squad"), findsOneWidget);
    expect(find.text("Leman Russ Battle Tank"), findsOneWidget);
  });
}
