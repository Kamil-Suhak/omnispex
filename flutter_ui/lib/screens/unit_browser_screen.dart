import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bsdata_models.dart';
import '../models/omnispex_models.dart';
import '../models/simulation_models.dart';
import '../providers/app_state_provider.dart';
import '../screens/in_battle_screen.dart';
import '../screens/list_building_screen.dart';
import '../services/bsdata_service.dart';
import '../services/faction_registry.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/stat_badge.dart';
import '../widgets/tactical_card.dart';

final unitSearchQueryProvider = StateProvider<String>((ref) => "");
final unitFactionFilterProvider = StateProvider<String>((ref) => "All Factions");
final unitCategoryFilterProvider = StateProvider<String>((ref) => "All Types");

class UnitBrowserScreen extends ConsumerStatefulWidget {
  const UnitBrowserScreen({super.key});

  @override
  ConsumerState<UnitBrowserScreen> createState() => _UnitBrowserScreenState();
}

class _UnitBrowserScreenState extends ConsumerState<UnitBrowserScreen> {
  late TextEditingController _searchController;
  bool _isDownloading = false;
  String _downloadingFactionName = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(unitSearchQueryProvider));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleFactionSelect(String factionName) async {
    if (factionName == "All Factions") {
      ref.read(unitFactionFilterProvider.notifier).state = "All Factions";
      return;
    }

    final meta = FactionRegistry.find(factionName);
    if (meta == null) {
      ref.read(unitFactionFilterProvider.notifier).state = factionName;
      return;
    }

    if (BsDataService.isFactionCached(meta.slug)) {
      await BsDataService.scopeMemoryToBrowser(meta.name);
      ref.read(unitFactionFilterProvider.notifier).state = meta.name;
      if (mounted) setState(() {});
      return;
    }

    // Prompt user to download
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmnispexColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: OmnispexColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.cloud_download, color: OmnispexColors.cyan, size: 20),
            const SizedBox(width: 8),
            Text("DOWNLOAD FACTION DATA", style: OmnispexTypography.h3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Datasheet catalogue for ${meta.name} is not cached on this device.",
              style: OmnispexTypography.body,
            ),
            const SizedBox(height: 8),
            Text(
              "• Expected datasheets: ~${meta.expectedUnits}\n• Size: ~250 KB\n• Memory scope: Strictly 1 faction loaded in RAM",
              style: OmnispexTypography.bodyMuted.copyWith(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text("CANCEL", style: OmnispexTypography.monoData.copyWith(color: OmnispexColors.textMuted)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: Text("DOWNLOAD & LOAD", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 11, color: OmnispexColors.background)),
            style: ElevatedButton.styleFrom(backgroundColor: OmnispexColors.cyan),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isDownloading = true;
        _downloadingFactionName = meta.name;
      });
      try {
        await BsDataService.downloadAndCacheFaction(meta.slug);
        await BsDataService.scopeMemoryToBrowser(meta.name);
        ref.read(unitFactionFilterProvider.notifier).state = meta.name;
        ref.read(catalogueRevisionEpochProvider.notifier).state++;
      } finally {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadingFactionName = '';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(catalogueRevisionEpochProvider);
    final query = ref.watch(unitSearchQueryProvider);
    final factionFilter = ref.watch(unitFactionFilterProvider);
    final categoryFilter = ref.watch(unitCategoryFilterProvider);

    final units = BsDataService.searchUnits(
      query: query,
      factionFilter: factionFilter,
      categoryFilter: categoryFilter,
    );
    final selectedFactionObj = factionFilter != "All Factions"
        ? BsDataService.findFaction(factionFilter)
        : null;
    final displayedUnits = units.take(100).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("BSDATA UNIT & WEAPON BROWSER", style: OmnispexTypography.h2),
                      Text("Instant 40k Datasheets, Wargear & Defensive Rules", style: OmnispexTypography.bodyMuted),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: OmnispexColors.cyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: OmnispexColors.cyan.withOpacity(0.4)),
                    ),
                    child: Text(
                      "${units.length} UNITS FOUND",
                      style: OmnispexTypography.monoData.copyWith(fontSize: 11, color: OmnispexColors.cyan, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search & Filter Card
              TacticalCard(
                title: "SEARCH & ROSTER FILTERS",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      style: OmnispexTypography.monoData.copyWith(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: factionFilter != "All Factions"
                            ? "Search $factionFilter units, weapons, or abilities..."
                            : "Search units, weapons, or abilities (e.g. 'Terminators', 'Leman Russ', 'Melta', 'Ramshackle')...",
                        hintStyle: OmnispexTypography.bodyMuted.copyWith(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 18, color: OmnispexColors.cyan),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: OmnispexColors.textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(unitSearchQueryProvider.notifier).state = "";
                                },
                              )
                            : null,
                        fillColor: OmnispexColors.surfaceElevated,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: OmnispexColors.border)),
                      ),
                      onChanged: (val) => ref.read(unitSearchQueryProvider.notifier).state = val,
                    ),
                    const SizedBox(height: 12),

                    // Faction Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: BsDataService.availableFactions.map((f) {
                          final isSel = factionFilter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(f, style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: isSel ? OmnispexColors.background : OmnispexColors.cyan)),
                              selected: isSel,
                              selectedColor: OmnispexColors.cyan,
                              backgroundColor: OmnispexColors.surfaceElevated,
                              side: BorderSide(color: isSel ? OmnispexColors.cyan : OmnispexColors.border),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onSelected: (sel) {
                                if (sel) _handleFactionSelect(f);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Role Filters
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ["All Types", "Infantry", "Vehicle / Monster", "Character"].map((cat) {
                        final isSel = categoryFilter == cat;
                        return ChoiceChip(
                          label: Text(cat, style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: isSel ? OmnispexColors.background : OmnispexColors.amber)),
                          selected: isSel,
                          selectedColor: OmnispexColors.amber,
                          backgroundColor: OmnispexColors.surfaceElevated,
                          side: BorderSide(color: isSel ? OmnispexColors.amber : OmnispexColors.border),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onSelected: (sel) {
                            if (sel) ref.read(unitCategoryFilterProvider.notifier).state = cat;
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_isDownloading) ...[
                TacticalCard(
                  title: "DOWNLOADING FACTION FROM BSDATA...",
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(color: OmnispexColors.cyan),
                          const SizedBox(height: 16),
                          Text("Ingesting $_downloadingFactionName from BSData repository...", style: OmnispexTypography.monoData),
                          const SizedBox(height: 4),
                          Text("Caching to client storage & scoping strictly 1 faction in memory", style: OmnispexTypography.bodyMuted),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (factionFilter != "All Factions") ...[
                // Active Faction Header & Switcher
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OmnispexColors.cyan.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: OmnispexColors.cyan.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: OmnispexColors.cyan, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ACTIVE FACTION: $factionFilter",
                              style: OmnispexTypography.h3.copyWith(fontSize: 14, color: OmnispexColors.cyan),
                            ),
                            Text(
                              "MEMORY SCOPE: 1 FACTION IN RAM // ${units.length} DATASHEETS LOADED",
                              style: OmnispexTypography.monoData.copyWith(fontSize: 10, color: OmnispexColors.greenKill),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.sync_alt, size: 14),
                        label: Text(
                          "SWITCH FACTION",
                          style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.cyan),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: OmnispexColors.cyan),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: () => _handleFactionSelect("All Factions"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),

              // Faction Army Rules & Detachments Inspector (when a faction is selected)
              if (selectedFactionObj != null &&
                  (selectedFactionObj.armyRules.isNotEmpty ||
                      selectedFactionObj.detachments.isNotEmpty)) ...[
                TacticalCard(
                  title:
                      "FACTION DETACHMENTS & ARMY RULES — ${selectedFactionObj.name.toUpperCase()}",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectedFactionObj.armyRules.isNotEmpty) ...[
                        Text("ARMY RULES:",
                            style: OmnispexTypography.label
                                .copyWith(fontSize: 10, color: OmnispexColors.cyan)),
                        const SizedBox(height: 4),
                        ...selectedFactionObj.armyRules.take(4).map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                "• ${r.name}: ${r.description}",
                                style: OmnispexTypography.bodyMuted
                                    .copyWith(fontSize: 11),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                        const SizedBox(height: 8),
                      ],
                      if (selectedFactionObj.detachments.isNotEmpty) ...[
                        Text(
                            "DETACHMENTS (${selectedFactionObj.detachments.length}):",
                            style: OmnispexTypography.label.copyWith(
                                fontSize: 10, color: OmnispexColors.amber)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedFactionObj.detachments.take(12).map((det) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: OmnispexColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: OmnispexColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${det.name} (${det.dpCost} DP)",
                                    style: OmnispexTypography.monoData
                                        .copyWith(fontSize: 11, color: OmnispexColors.cyan),
                                  ),
                                  if (det.enhancements.isNotEmpty)
                                    Text(
                                      "${det.enhancements.length} Enhancements",
                                      style: OmnispexTypography.bodyMuted
                                          .copyWith(fontSize: 10),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

                // Unit Datasheets Feed
                if (units.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(Icons.search_off, size: 48, color: OmnispexColors.textMuted),
                        const SizedBox(height: 12),
                        Text("No matching units found", style: OmnispexTypography.h2),
                        const SizedBox(height: 4),
                        Text("Try clearing search filters or changing the faction selection.", style: OmnispexTypography.bodyMuted),
                      ],
                    ),
                  )
                else
                  ...displayedUnits.map((u) => _buildUnitCard(context, ref, u)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitCard(BuildContext context, WidgetRef ref, BsDataUnit unit) {
    final p = unit.unitProfile;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(color: OmnispexColors.cyan, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text(unit.name, style: OmnispexTypography.h2.copyWith(fontSize: 15)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: OmnispexColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: OmnispexColors.border),
                    ),
                    child: Text(unit.faction.toUpperCase(), style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 9, color: OmnispexColors.textMuted)),
                  ),
                ],
              ),
              if (unit.pointsCost != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: OmnispexColors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: OmnispexColors.purple.withOpacity(0.4)),
                  ),
                  child: Text("${unit.pointsCost} PTS", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 11, color: OmnispexColors.purple, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Stat Badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatBadge(label: "M", value: unit.movement),
              StatBadge(label: "T", value: '${p.toughness}'),
              StatBadge(label: "SV", value: '${p.save}+'),
              if (p.invuln != null) StatBadge(label: "INV", value: '${p.invuln}+', accentColor: OmnispexColors.amber),
              if (p.fnp != null) StatBadge(label: "FNP", value: '${p.fnp}+', accentColor: OmnispexColors.greenKill),
              StatBadge(label: "W", value: '${p.woundsPerModel}'),
              StatBadge(label: "LD", value: unit.leadership),
              StatBadge(label: "OC", value: '${unit.objectiveControl}'),
            ],
          ),
          const SizedBox(height: 10),

          // Keywords
          if (unit.categories.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: unit.categories.map((cat) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: OmnispexColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: OmnispexColors.border.withOpacity(0.6)),
                  ),
                  child: Text(cat.toUpperCase(), style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 8, color: OmnispexColors.textSecondary)),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // Abilities
          if (unit.abilities.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: OmnispexColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: unit.abilities.map((ab) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("• $ab", style: OmnispexTypography.bodyMuted.copyWith(fontSize: 10)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Weapons Roster
          if (unit.weapons.isNotEmpty) ...[
            Text("WARGEAR & WEAPON PROFILES (${unit.weapons.length}):", style: OmnispexTypography.label.copyWith(fontSize: 10)),
            const SizedBox(height: 6),
            ...unit.weapons.map((w) => _buildWeaponRow(w)),
            const SizedBox(height: 12),
          ],

          const Divider(color: OmnispexColors.border, height: 1),
          const SizedBox(height: 10),

          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.flash_on, size: 13),
                label: Text("LOAD AS ATTACKER", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.background)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmnispexColors.cyan,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref.read(loadedAttackerNameProvider.notifier).state = unit.name;
                  if (unit.weapons.isNotEmpty) {
                    ref.read(customWeaponProfileProvider.notifier).state = unit.weapons.first;
                    ref.read(isCustomWeaponModeProvider.notifier).state = true;
                  }
                  ref.read(currentNavIndexProvider.notifier).state = 0;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Loaded '${unit.name}' as Attacker into In-Battle Simulator!"),
                      backgroundColor: OmnispexColors.surfaceElevated,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.shield_outlined, size: 13),
                label: Text("LOAD AS DEFENDER", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.background)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmnispexColors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref.read(loadedDefenderNameProvider.notifier).state = unit.name;
                  ref.read(customTargetProfileProvider.notifier).state = unit.unitProfile;
                  ref.read(isCustomTargetModeProvider.notifier).state = true;
                  ref.read(currentNavIndexProvider.notifier).state = 0;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Loaded '${unit.name}' as Defender into In-Battle Simulator!"),
                      backgroundColor: OmnispexColors.surfaceElevated,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.grid_view, size: 13),
                label: Text("SEND TO LIST-BUILDER", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmnispexColors.textSecondary,
                  side: const BorderSide(color: OmnispexColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  if (unit.pointsCost != null) {
                    ref.read(benchPointsAProvider.notifier).state = unit.pointsCost!;
                  }
                  ref.read(currentNavIndexProvider.notifier).state = 1;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Sent '${unit.name}' (${unit.pointsCost ?? 100} pts) to List-Building Benchmark!"),
                      backgroundColor: OmnispexColors.surfaceElevated,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.playlist_add, size: 13),
                label: Text("ADD TO ARMY LIST", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.greenKill)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmnispexColors.greenKill,
                  side: const BorderSide(color: OmnispexColors.greenKill),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  final list = ref
                      .read(personalStoreProvider.notifier)
                      .addUnitToArmyList(unit: unit);
                  ref.read(activeArmyListIdProvider.notifier).state = list.id;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Added '${unit.name}' to Army List '${list.name}'!"),
                      backgroundColor: OmnispexColors.surfaceElevated,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined, size: 13),
                label: Text("ADD TO WISHLIST", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.purple)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmnispexColors.purple,
                  side: const BorderSide(color: OmnispexColors.purple),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  final now = DateTime.now().toIso8601String();
                  ref.read(personalStoreProvider.notifier).upsertWishlistItem(
                        WishlistItemUi(
                          id: 'wl-${unit.id}',
                          factionId: unit.factionId.isNotEmpty
                              ? unit.factionId
                              : unit.faction,
                          factionName: unit.faction,
                          unitId: unit.id,
                          unitName: unit.name,
                          quantityDesired: 1,
                          quantityOwned: 0,
                          pointsPerUnit: unit.pointsCost ?? 100,
                          priority: WishlistPriorityUi.medium,
                          state: AcquisitionStateUi.wishlist,
                          updatedAtIso: now,
                        ),
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Added '${unit.name}' to ${unit.faction} Wishlist!"),
                      backgroundColor: OmnispexColors.surfaceElevated,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeaponRow(WeaponUiProfile w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OmnispexColors.border.withOpacity(0.5)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                w.profileName == "Standard" || w.profileName == "Melee" ? w.name : "${w.name} [${w.profileName}]",
                style: OmnispexTypography.monoData.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              StatBadge(label: "R", value: w.isMelee ? "MELEE" : '${w.range}"', accentColor: w.isMelee ? OmnispexColors.amber : OmnispexColors.cyan),
              StatBadge(label: "A", value: w.attacks),
              StatBadge(label: "BS", value: '${w.skill}+'),
              StatBadge(label: "S", value: '${w.strength}'),
              StatBadge(label: "AP", value: '-${w.ap}'),
              StatBadge(label: "D", value: w.damage),
              ...w.abilities.map((ab) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: OmnispexColors.surfaceCard,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: OmnispexColors.border),
                    ),
                    child: Text(ab, style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 8)),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
