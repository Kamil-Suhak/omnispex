import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bridge/omnispex_rust_bridge.dart';
import '../features/kill_team/screens/kt_combat_screen.dart';
import '../features/kill_team/screens/kt_operative_browser_screen.dart';
import '../features/kill_team/screens/kt_roster_builder_screen.dart';
import '../features/kill_team/services/kill_team_service.dart';
import '../models/omnispex_models.dart';
import '../providers/app_state_provider.dart';
import '../services/bsdata_service.dart';
import '../services/personal_data_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/access_key_dialog.dart';
import '../widgets/game_system_switcher.dart';
import 'in_battle_screen.dart';
import 'list_building_screen.dart';
import 'matches_screen.dart';
import 'settings_screen.dart';
import 'unit_browser_screen.dart';
import 'wishlist_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await OmnispexRustBridge.initialize();
    await BsDataService.initOnStartup();
    await KillTeamService.ensureCatalogueLoaded();
    await ref.read(personalStoreProvider.notifier).loadFromDisk();
    if (PersonalDataService.killTeamRosters.isNotEmpty && mounted) {
      ref.read(killTeamRostersProvider.notifier).state =
          List.from(PersonalDataService.killTeamRosters);
    }
    if (mounted) {
      ref.read(catalogueRevisionEpochProvider.notifier).state++;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final navIndex = ref.watch(currentNavIndexProvider);
    final activeSystem = ref.watch(activeGameSystemProvider);
    final is40k = activeSystem == GameSystemUi.warhammer40k;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.flash_on_outlined),
        selectedIcon: Icon(Icons.flash_on),
        label: 'In-Battle',
      ),
      NavigationDestination(
        icon: const Icon(Icons.list_alt_outlined),
        selectedIcon: const Icon(Icons.list_alt),
        label: is40k ? 'List-Build' : 'Rosters',
      ),
      NavigationDestination(
        icon: const Icon(Icons.library_books_outlined),
        selectedIcon: const Icon(Icons.library_books),
        label: is40k ? 'Datasheets' : 'Operatives',
      ),
      const NavigationDestination(
        icon: Icon(Icons.bookmark_border),
        selectedIcon: Icon(Icons.bookmark),
        label: 'Wishlist',
      ),
      const NavigationDestination(
        icon: Icon(Icons.emoji_events_outlined),
        selectedIcon: Icon(Icons.emoji_events),
        label: 'Matches',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    final railDestinations = [
      const NavigationRailDestination(
        icon: Icon(Icons.flash_on_outlined),
        selectedIcon: Icon(Icons.flash_on),
        label: Text('In-Battle'),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.list_alt_outlined),
        selectedIcon: const Icon(Icons.list_alt),
        label: Text(is40k ? 'List-Build' : 'Rosters'),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.library_books_outlined),
        selectedIcon: const Icon(Icons.library_books),
        label: Text(is40k ? 'Datasheets' : 'Operatives'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.bookmark_border),
        selectedIcon: Icon(Icons.bookmark),
        label: Text('Wishlist'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.emoji_events_outlined),
        selectedIcon: Icon(Icons.emoji_events),
        label: Text('Matches'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('Settings'),
      ),
    ];

    final pages = is40k
        ? const [
            InBattleScreen(),
            ListBuildingScreen(),
            UnitBrowserScreen(),
            WishlistScreen(),
            MatchesScreen(),
            SettingsScreen(),
          ]
        : const [
            KtCombatScreen(),
            KtRosterBuilderScreen(),
            KtOperativeBrowserScreen(),
            WishlistScreen(),
            MatchesScreen(),
            SettingsScreen(),
          ];

    final safeIndex = navIndex.clamp(0, pages.length - 1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: OmnispexColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'OMNISPEX',
              style: OmnispexTypography.h3.copyWith(letterSpacing: 2),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'PROBABILITY ENGINE',
                style: OmnispexTypography.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: GameSystemSwitcherButton(),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Access Key',
            icon: const Icon(Icons.vpn_key_outlined, size: 20),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => const AccessKeyVaultDialog(),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop) ...[
            NavigationRail(
              selectedIndex: safeIndex,
              onDestinationSelected: (idx) {
                ref.read(currentNavIndexProvider.notifier).state = idx;
              },
              destinations: railDestinations,
              labelType: NavigationRailLabelType.all,
            ),
            const VerticalDivider(width: 1, color: OmnispexColors.border),
          ],
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('${activeSystem.name}-$safeIndex'),
              child: pages[safeIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (idx) {
                ref.read(currentNavIndexProvider.notifier).state = idx;
              },
              destinations: destinations,
            ),
    );
  }
}
