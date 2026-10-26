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
    final isDesktop = screenWidth >= 820;

    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.flash_on_outlined),
        selectedIcon: Icon(Icons.flash_on, color: OmnispexColors.cyan),
        label: 'In-Battle',
      ),
      NavigationDestination(
        icon: Icon(Icons.list_alt_outlined),
        selectedIcon: Icon(Icons.list_alt, color: OmnispexColors.cyan),
        label: 'List-Build',
      ),
      NavigationDestination(
        icon: Icon(Icons.library_books_outlined),
        selectedIcon: Icon(Icons.library_books, color: OmnispexColors.cyan),
        label: 'Datasheets',
      ),
      NavigationDestination(
        icon: Icon(Icons.bookmark_border),
        selectedIcon: Icon(Icons.bookmark, color: OmnispexColors.cyan),
        label: 'Wishlist',
      ),
      NavigationDestination(
        icon: Icon(Icons.emoji_events_outlined),
        selectedIcon: Icon(Icons.emoji_events, color: OmnispexColors.cyan),
        label: 'Matches',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings, color: OmnispexColors.cyan),
        label: 'Settings',
      ),
    ];

    const railDestinations = [
      NavigationRailDestination(
        icon: Icon(Icons.flash_on_outlined),
        selectedIcon: Icon(Icons.flash_on, color: OmnispexColors.cyan),
        label: Text('In-Battle'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.list_alt_outlined),
        selectedIcon: Icon(Icons.list_alt, color: OmnispexColors.cyan),
        label: Text('List-Build'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.library_books_outlined),
        selectedIcon: Icon(Icons.library_books, color: OmnispexColors.cyan),
        label: Text('Datasheets'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.bookmark_border),
        selectedIcon: Icon(Icons.bookmark, color: OmnispexColors.cyan),
        label: Text('Wishlist'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.emoji_events_outlined),
        selectedIcon: Icon(Icons.emoji_events, color: OmnispexColors.cyan),
        label: Text('Matches'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings, color: OmnispexColors.cyan),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: OmnispexColors.cyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: OmnispexColors.cyan.withOpacity(0.4)),
              ),
              child: Text(
                "OMNISPEX",
                style: OmnispexTypography.monoData.copyWith(
                  color: OmnispexColors.cyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "PROBABILITY ENGINE",
                style: OmnispexTypography.label.copyWith(fontSize: 11),
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
            child: IndexedStack(
              index: safeIndex,
              children: pages,
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
