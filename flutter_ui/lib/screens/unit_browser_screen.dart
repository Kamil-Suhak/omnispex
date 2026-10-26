import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bsdata_models.dart';
import '../models/omnispex_models.dart';
import '../providers/app_state_provider.dart';
import '../screens/in_battle_screen.dart';
import '../services/bsdata_service.dart';
import '../services/faction_registry.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/tactical_card.dart';
import '../widgets/unit_details_modal.dart';

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
  int _selectedTab = 0; // 0: Datasheets, 1: Army Rules, 2: Detachments

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

    // Prompt user to download with clean copy
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
        content: Text(
          "Datasheet catalogue for ${meta.name} is not cached on this device. Would you like to download it now?",
          style: OmnispexTypography.body,
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
                      Text("Datasheets, Detachments & Army Rules", style: OmnispexTypography.bodyMuted),
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
                            : "Search units, weapons, or abilities (e.g. 'Terminators', 'Leman Russ', 'Melta')...",
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

                    // Faction Selector Dropdown
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: BsDataService.availableFactions.contains(factionFilter)
                                ? factionFilter
                                : "All Factions",
                            isExpanded: true,
                            dropdownColor: OmnispexColors.surfaceElevated,
                            decoration: InputDecoration(
                              labelText: "FACTION SELECTION",
                              labelStyle: OmnispexTypography.monoData.copyWith(
                                color: OmnispexColors.cyan,
                                fontSize: 11,
                              ),
                              prefixIcon: const Icon(Icons.shield_outlined,
                                  size: 18, color: OmnispexColors.cyan),
                              fillColor: OmnispexColors.surfaceElevated,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: OmnispexColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: OmnispexColors.border),
                              ),
                            ),
                            items: BsDataService.availableFactions.map((f) {
                              final isCached = f == "All Factions" ||
                                  BsDataService.isFactionCached(
                                      FactionRegistry.find(f)?.slug ?? "");
                              return DropdownMenuItem<String>(
                                value: f,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        f,
                                        style: OmnispexTypography.monoData.copyWith(
                                          fontSize: 12,
                                          color: f == factionFilter
                                              ? OmnispexColors.cyan
                                              : OmnispexColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (f != "All Factions")
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isCached
                                              ? OmnispexColors.greenKill.withOpacity(0.15)
                                              : OmnispexColors.surfaceCard,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          isCached ? "CACHED" : "DOWNLOAD",
                                          style: OmnispexTypography.monoStatBadge.copyWith(
                                            fontSize: 8,
                                            color: isCached
                                                ? OmnispexColors.greenKill
                                                : OmnispexColors.textMuted,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) _handleFactionSelect(val);
                            },
                          ),
                        ),
                        if (factionFilter != "All Factions") ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: "Clear Faction Filter",
                            icon: const Icon(Icons.clear, color: OmnispexColors.textMuted),
                            onPressed: () => _handleFactionSelect("All Factions"),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

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
                          Text("Ingesting $_downloadingFactionName from repository...", style: OmnispexTypography.monoData),
                          const SizedBox(height: 4),
                          Text("Downloading and caching catalogue...", style: OmnispexTypography.bodyMuted),
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
                              "${units.length} DATASHEETS LOADED",
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

              // Sub-navigation Tabs (Datasheets, Army Rules, Detachments)
              Row(
                children: [
                  _buildTabButton(0, "DATASHEETS (${units.length})", Icons.list_alt),
                  const SizedBox(width: 8),
                  _buildTabButton(1, "ARMY RULES (${selectedFactionObj?.armyRules.length ?? 0})", Icons.menu_book),
                  const SizedBox(width: 8),
                  _buildTabButton(2, "DETACHMENTS (${selectedFactionObj?.detachments.length ?? 0})", Icons.shield),
                ],
              ),
              const SizedBox(height: 16),

              // Sub-navigation Content
              if (_selectedTab == 0) ...[
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
                  ...displayedUnits.map((u) => _buildCompactUnitTile(context, ref, u)),
              ] else if (_selectedTab == 1) ...[
                _buildArmyRulesTab(selectedFactionObj),
              ] else ...[
                _buildDetachmentsTab(selectedFactionObj),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? OmnispexColors.cyan.withOpacity(0.15)
                : OmnispexColors.surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? OmnispexColors.cyan : OmnispexColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? OmnispexColors.cyan : OmnispexColors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: OmnispexTypography.monoData.copyWith(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? OmnispexColors.cyan : OmnispexColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactUnitTile(BuildContext context, WidgetRef ref, BsDataUnit unit) {
    final p = unit.unitProfile;
    final pts = unit.pointsCost ??
        (unit.legalSizeOptions.isNotEmpty
            ? unit.legalSizeOptions.first.points
            : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Indicator, Unit Name, Points Badge, Details Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: OmnispexColors.cyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  unit.name,
                  style: OmnispexTypography.h3.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (pts != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: OmnispexColors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: OmnispexColors.purple.withOpacity(0.4)),
                  ),
                  child: Text(
                    "$pts PTS",
                    style: OmnispexTypography.monoStatBadge.copyWith(
                      fontSize: 11,
                      color: OmnispexColors.purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.info_outline, size: 13),
                label: const Text("DETAILS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmnispexColors.cyan,
                  side: const BorderSide(color: OmnispexColors.cyan),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => showUnitDetailsModal(context, unit),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Categories & Core Identifiers Summary
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: OmnispexColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: OmnispexColors.border),
                ),
                child: Text(
                  unit.faction.toUpperCase(),
                  style: OmnispexTypography.monoStatBadge.copyWith(
                    fontSize: 9,
                    color: OmnispexColors.textMuted,
                  ),
                ),
              ),
              ...unit.categories.take(3).map((cat) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: OmnispexColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: OmnispexColors.border.withOpacity(0.6)),
                  ),
                  child: Text(
                    cat.toUpperCase(),
                    style: OmnispexTypography.monoStatBadge.copyWith(
                      fontSize: 8,
                      color: OmnispexColors.textSecondary,
                    ),
                  ),
                );
              }),
              Text(
                "• M ${unit.movement} • T ${p.toughness} • Sv ${p.save}+ • W ${p.woundsPerModel}",
                style: OmnispexTypography.monoData.copyWith(
                  fontSize: 10,
                  color: OmnispexColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: Action Buttons
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.flash_on, size: 12),
                label: Text("ATTACKER", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 9, color: OmnispexColors.background)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmnispexColors.cyan,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
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
                icon: const Icon(Icons.shield_outlined, size: 12),
                label: Text("DEFENDER", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 9, color: OmnispexColors.background)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmnispexColors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
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
                icon: const Icon(Icons.playlist_add, size: 12),
                label: Text("ADD TO LIST", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 9, color: OmnispexColors.greenKill)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmnispexColors.greenKill,
                  side: const BorderSide(color: OmnispexColors.greenKill),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
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
                icon: const Icon(Icons.bookmark_add_outlined, size: 12),
                label: Text("WISHLIST", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 9, color: OmnispexColors.purple)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmnispexColors.purple,
                  side: const BorderSide(color: OmnispexColors.purple),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
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

  Widget _buildArmyRulesTab(BsDataFaction? faction) {
    if (faction == null) {
      return TacticalCard(
        title: "ARMY RULES",
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.shield_outlined, size: 36, color: OmnispexColors.textMuted),
                const SizedBox(height: 8),
                Text("Select a specific faction to view its Army Rules.", style: OmnispexTypography.bodyMuted),
              ],
            ),
          ),
        ),
      );
    }

    if (faction.armyRules.isEmpty) {
      return TacticalCard(
        title: "ARMY RULES — ${faction.name.toUpperCase()}",
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text("No army rules recorded for ${faction.name}.", style: OmnispexTypography.bodyMuted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: faction.armyRules.map((rule) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OmnispexColors.surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: OmnispexColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book, size: 16, color: OmnispexColors.cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rule.name.toUpperCase(),
                      style: OmnispexTypography.h3.copyWith(color: OmnispexColors.cyan, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(rule.description, style: OmnispexTypography.body),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetachmentsTab(BsDataFaction? faction) {
    if (faction == null) {
      return TacticalCard(
        title: "DETACHMENTS",
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.military_tech_outlined, size: 36, color: OmnispexColors.textMuted),
                const SizedBox(height: 8),
                Text("Select a specific faction to view its Detachments.", style: OmnispexTypography.bodyMuted),
              ],
            ),
          ),
        ),
      );
    }

    if (faction.detachments.isEmpty) {
      return TacticalCard(
        title: "DETACHMENTS — ${faction.name.toUpperCase()}",
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text("No detachments recorded for ${faction.name}.", style: OmnispexTypography.bodyMuted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: faction.detachments.map((det) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OmnispexColors.surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: OmnispexColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Detachment Header & DP Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.shield, size: 16, color: OmnispexColors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            det.name.toUpperCase(),
                            style: OmnispexTypography.h3.copyWith(fontSize: 14, color: OmnispexColors.amber),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: OmnispexColors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: OmnispexColors.amber.withOpacity(0.4)),
                    ),
                    child: Text(
                      "${det.dpCost} DP",
                      style: OmnispexTypography.monoStatBadge.copyWith(
                        fontSize: 11,
                        color: OmnispexColors.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (det.rules.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...det.rules.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        r.description.isNotEmpty ? "${r.name}: ${r.description}" : r.name,
                        style: OmnispexTypography.body,
                      ),
                    )),
              ],
              const SizedBox(height: 12),

              // Enhancements List
              if (det.enhancements.isNotEmpty) ...[
                Text(
                  "ENHANCEMENTS (${det.enhancements.length}):",
                  style: OmnispexTypography.monoData.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: OmnispexColors.cyan,
                  ),
                ),
                const SizedBox(height: 6),
                ...det.enhancements.map((enh) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: OmnispexColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: OmnispexColors.border.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                enh.name,
                                style: OmnispexTypography.monoData.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: OmnispexColors.cyan,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: OmnispexColors.purple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                "+${enh.points} PTS",
                                style: OmnispexTypography.monoStatBadge.copyWith(
                                  fontSize: 9,
                                  color: OmnispexColors.purple,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (enh.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            enh.description,
                            style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ] else ...[
                Text(
                  "No enhancements available for this detachment.",
                  style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
