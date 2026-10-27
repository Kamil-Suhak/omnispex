import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'in_battle_screen.dart';
import 'list_building_screen.dart';
import 'matches_screen.dart';
import 'settings_screen.dart';
import 'unit_browser_screen.dart';
import 'wishlist_screen.dart';
import '../bridge/omnispex_rust_bridge.dart';
import '../providers/app_state_provider.dart';
import '../services/bsdata_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

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
    await ref.read(personalStoreProvider.notifier).loadFromDisk();
    if (mounted) {
      ref.read(catalogueRevisionEpochProvider.notifier).state++;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final navIndex = ref.watch(currentNavIndexProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;

    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.flash_on_outlined),
        selectedIcon: Icon(Icons.flash_on),
        label: 'In-Battle',
      ),
      NavigationDestination(
        icon: Icon(Icons.list_alt_outlined),
        selectedIcon: Icon(Icons.list_alt),
        label: 'List-Build',
      ),
      NavigationDestination(
        icon: Icon(Icons.library_books_outlined),
        selectedIcon: Icon(Icons.library_books),
        label: 'Datasheets',
      ),
      NavigationDestination(
        icon: Icon(Icons.bookmark_border),
        selectedIcon: Icon(Icons.bookmark),
        label: 'Wishlist',
      ),
      NavigationDestination(
        icon: Icon(Icons.emoji_events_outlined),
        selectedIcon: Icon(Icons.emoji_events),
        label: 'Matches',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    const railDestinations = [
      NavigationRailDestination(
        icon: Icon(Icons.flash_on_outlined),
        selectedIcon: Icon(Icons.flash_on),
        label: Text('In-Battle'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.list_alt_outlined),
        selectedIcon: Icon(Icons.list_alt),
        label: Text('List-Build'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.library_books_outlined),
        selectedIcon: Icon(Icons.library_books),
        label: Text('Datasheets'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.bookmark_border),
        selectedIcon: Icon(Icons.bookmark),
        label: Text('Wishlist'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.emoji_events_outlined),
        selectedIcon: Icon(Icons.emoji_events),
        label: Text('Matches'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('Settings'),
      ),
    ];

    const pages = [
      InBattleScreen(),
      ListBuildingScreen(),
      UnitBrowserScreen(),
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
              "OMNISPEX",
              style: OmnispexTypography.h3.copyWith(letterSpacing: 2),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                "PROBABILITY ENGINE",
                style: OmnispexTypography.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
              key: ValueKey(safeIndex),
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
