import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'in_battle_screen.dart';
import '../providers/app_state_provider.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(currentNavIndexProvider);
    final isDeepAnalytics = ref.watch(isDeepAnalyticsModeProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 720;

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.flash_on_outlined),
        selectedIcon: Icon(Icons.flash_on, color: OmnispexColors.cyan),
        label: 'In-Battle',
      ),
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view, color: OmnispexColors.cyan),
        label: 'List-Build',
      ),
      const NavigationDestination(
        icon: Icon(Icons.description_outlined),
        selectedIcon: Icon(Icons.description, color: OmnispexColors.cyan),
        label: 'Import',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings, color: OmnispexColors.cyan),
        label: 'Settings',
      ),
    ];

    final railDestinations = [
      const NavigationRailDestination(
        icon: Icon(Icons.flash_on_outlined),
        selectedIcon: Icon(Icons.flash_on, color: OmnispexColors.cyan),
        label: Text('In-Battle'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view, color: OmnispexColors.cyan),
        label: Text('List-Build'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.description_outlined),
        selectedIcon: Icon(Icons.description, color: OmnispexColors.cyan),
        label: Text('Import'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings, color: OmnispexColors.cyan),
        label: Text('Settings'),
      ),
    ];

    final pages = [
      const InBattleScreen(),
      _buildPlaceholderTab(
        title: "LIST-BUILDING BENCHMARK",
        subtitle: "Evaluating Loadouts vs GEQ, MEQ, TEQ, Transport, Heavy Armor",
        icon: Icons.grid_view,
      ),
      _buildPlaceholderTab(
        title: "WAHAPEDIA INGESTION",
        subtitle: "Quick-Paste Raw Text Weapon & Datasheet Tables",
        icon: Icons.description,
      ),
      _buildPlaceholderTab(
        title: "SETTINGS & ARCHETYPES",
        subtitle: "Customize standard defensive benchmark profiles",
        icon: Icons.settings,
      ),
    ];

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
            Text(
              "PROBABILITY ENGINE",
              style: OmnispexTypography.label.copyWith(fontSize: 11),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilterChip(
              avatar: Icon(
                isDeepAnalytics ? Icons.insights : Icons.bolt,
                size: 14,
                color: isDeepAnalytics ? OmnispexColors.amber : OmnispexColors.cyan,
              ),
              label: Text(
                isDeepAnalytics ? "DEEP ANALYTICS" : "SIMPLIFIED VIEW",
                style: OmnispexTypography.monoStatBadge.copyWith(
                  color: isDeepAnalytics ? OmnispexColors.amber : OmnispexColors.cyan,
                  fontSize: 11,
                ),
              ),
              selected: isDeepAnalytics,
              onSelected: (val) {
                ref.read(isDeepAnalyticsModeProvider.notifier).state = val;
              },
              backgroundColor: OmnispexColors.surfaceCard,
              selectedColor: OmnispexColors.amber.withOpacity(0.2),
              side: BorderSide(
                color: isDeepAnalytics ? OmnispexColors.amber : OmnispexColors.cyan.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: navIndex,
                  onDestinationSelected: (idx) {
                    ref.read(currentNavIndexProvider.notifier).state = idx;
                  },
                  destinations: railDestinations,
                  labelType: NavigationRailLabelType.all,
                ),
                const VerticalDivider(width: 1, color: OmnispexColors.border),
                Expanded(child: pages[navIndex]),
              ],
            )
          : pages[navIndex],
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: navIndex,
              onDestinationSelected: (idx) {
                ref.read(currentNavIndexProvider.notifier).state = idx;
              },
              destinations: destinations,
            ),
    );
  }

  Widget _buildPlaceholderTab({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: OmnispexColors.cyanMuted),
            const SizedBox(height: 16),
            Text(title, style: OmnispexTypography.h2),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: OmnispexTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
