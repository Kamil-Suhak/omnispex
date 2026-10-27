import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bsdata_models.dart';
import '../models/omnispex_models.dart';
import '../providers/app_state_provider.dart';
import '../screens/in_battle_screen.dart';
import '../services/bsdata_service.dart';
import '../services/faction_registry.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_theme.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/compact_unit_tile.dart';
import '../widgets/tactical_card.dart';

final unitSearchQueryProvider = StateProvider<String>((ref) => "");
final unitFactionFilterProvider = StateProvider<String>((ref) => "All Factions");
final unitCategoryFilterProvider = StateProvider<String>((ref) => "All Types");

enum _BrowserTab { datasheets, armyRules, detachments }

class UnitBrowserScreen extends ConsumerStatefulWidget {
  const UnitBrowserScreen({super.key});

  @override
  ConsumerState<UnitBrowserScreen> createState() => _UnitBrowserScreenState();
}

class _UnitBrowserScreenState extends ConsumerState<UnitBrowserScreen> {
  static const _typeFilters = ["All Types", "Infantry", "Vehicle / Monster", "Character"];

  late final TextEditingController _searchController;
  bool _isDownloading = false;
  _BrowserTab _tab = _BrowserTab.datasheets;

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
    final filter = ref.read(unitFactionFilterProvider.notifier);
    final meta = factionName == "All Factions" ? null : FactionRegistry.find(factionName);
    if (meta == null) {
      filter.state = factionName;
      return;
    }

    if (!BsDataService.isFactionCached(meta.slug)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Download ${meta.name}?", style: OmnispexTypography.h3),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: OmnispexColors.textSecondary),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Download"),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      setState(() => _isDownloading = true);
      try {
        await BsDataService.downloadAndCacheFaction(meta.slug);
      } finally {
        if (mounted) setState(() => _isDownloading = false);
      }
    }

    await BsDataService.scopeMemoryToBrowser(meta.name);
    filter.state = meta.name;
    ref.read(catalogueRevisionEpochProvider.notifier).state++;
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
    final faction = factionFilter == "All Factions"
        ? null
        : BsDataService.findFaction(factionFilter);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: OmnispexLayout.contentMaxWidth),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                OmnispexLayout.pagePadding,
                OmnispexLayout.pagePadding,
                OmnispexLayout.pagePadding,
                OmnispexLayout.gap,
              ),
              sliver: SliverToBoxAdapter(child: _buildHeader(units.length, factionFilter, categoryFilter)),
            ),
            if (_isDownloading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_tab == _BrowserTab.datasheets)
              _buildUnitGrid(units)
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: OmnispexLayout.pagePadding),
                sliver: SliverToBoxAdapter(
                  child: _tab == _BrowserTab.armyRules
                      ? _buildArmyRules(faction)
                      : _buildDetachments(faction),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: OmnispexLayout.pagePadding)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int unitCount, String factionFilter, String categoryFilter) {
    final factions = BsDataService.availableFactions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("BSDATA UNIT & WEAPON BROWSER", style: OmnispexTypography.h2),
        const SizedBox(height: OmnispexLayout.gap),
        Wrap(
          spacing: OmnispexLayout.gap,
          runSpacing: OmnispexLayout.gap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search units, weapons, abilities",
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: "Clear",
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(unitSearchQueryProvider.notifier).state = "";
                          },
                        ),
                ),
                onChanged: (val) => ref.read(unitSearchQueryProvider.notifier).state = val,
              ),
            ),
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<String>(
                initialValue: factions.contains(factionFilter) ? factionFilter : "All Factions",
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (final f in factions)
                    DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) _handleFactionSelect(val);
                },
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _typeFilters)
                  ChoiceChip(
                    label: Text(
                      t,
                      style: OmnispexTypography.monoStatBadge.copyWith(
                        fontSize: 11,
                        color: categoryFilter == t
                            ? OmnispexColors.background
                            : OmnispexColors.accent,
                      ),
                    ),
                    selected: categoryFilter == t,
                    selectedColor: OmnispexColors.accent,
                    backgroundColor: OmnispexColors.surfaceElevated,
                    onSelected: (_) =>
                        ref.read(unitCategoryFilterProvider.notifier).state = t,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: OmnispexLayout.gap),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_BrowserTab>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(
                value: _BrowserTab.datasheets,
                label: Text("Datasheets", maxLines: 1),
              ),
              ButtonSegment(
                value: _BrowserTab.armyRules,
                label: Text("Army Rules", maxLines: 1),
              ),
              ButtonSegment(
                value: _BrowserTab.detachments,
                label: Text("Detachments", maxLines: 1),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitGrid(List<BsDataUnit> units) {
    if (units.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(child: Text("No matching units", style: OmnispexTypography.bodyMuted)),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: OmnispexLayout.pagePadding),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          mainAxisExtent: 52,
          crossAxisSpacing: OmnispexLayout.gap,
          mainAxisSpacing: 8,
        ),
        itemCount: units.length,
        itemBuilder: (context, i) {
          final unit = units[i];
          return CompactUnitTile(
            key: ValueKey(unit.id),
            unit: unit,
            trailing: _UnitActionsMenu(unit: unit),
          );
        },
      ),
    );
  }

  Widget _buildArmyRules(BsDataFaction? faction) {
    if (faction == null || faction.armyRules.isEmpty) {
      return _emptyNote(faction == null
          ? "Select a faction to view its army rules."
          : "No army rules recorded for ${faction.name}.");
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in faction.armyRules)
          TacticalCard(
            title: rule.name,
            child: Text(rule.description, style: OmnispexTypography.bodyMuted),
          ),
      ],
    );
  }

  Widget _buildDetachments(BsDataFaction? faction) {
    final detachments = faction?.matchedPlayDetachments ?? const [];
    if (faction == null || detachments.isEmpty) {
      return _emptyNote(faction == null
          ? "Select a faction to view its detachments."
          : "No detachments recorded for ${faction.name}.");
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final det in detachments)
          TacticalCard(
            title: "${det.name} · ${det.dpCost} DP",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in det.rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      r.description.isNotEmpty ? "${r.name}: ${r.description}" : r.name,
                      style: OmnispexTypography.bodyMuted,
                    ),
                  ),
                if (det.enhancements.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text("ENHANCEMENTS", style: OmnispexTypography.label),
                  const SizedBox(height: 6),
                  for (final enh in det.enhancements)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                          text: "${enh.name} · ${enh.points} pts",
                          style: OmnispexTypography.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (enh.description.isNotEmpty)
                          TextSpan(text: "\n${enh.description}", style: OmnispexTypography.bodyMuted),
                      ])),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _emptyNote(String text) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(text, style: OmnispexTypography.bodyMuted)),
      );
}

enum _UnitAction { attacker, defender, addToList, wishlist }

class _UnitActionsMenu extends ConsumerWidget {
  final BsDataUnit unit;

  const _UnitActionsMenu({required this.unit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_UnitAction>(
      tooltip: "Actions",
      icon: const Icon(Icons.more_vert, size: 20),
      color: OmnispexColors.surfaceElevated,
      onSelected: (action) => _run(context, ref, action),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _UnitAction.attacker, child: Text("Load as attacker")),
        PopupMenuItem(value: _UnitAction.defender, child: Text("Load as defender")),
        PopupMenuItem(value: _UnitAction.addToList, child: Text("Add to army list")),
        PopupMenuItem(value: _UnitAction.wishlist, child: Text("Add to wishlist")),
      ],
    );
  }

  void _run(BuildContext context, WidgetRef ref, _UnitAction action) {
    String message = "";
    switch (action) {
      case _UnitAction.attacker:
        ref.read(loadedAttackerNameProvider.notifier).state = unit.name;
        if (unit.weapons.isNotEmpty) {
          ref.read(customWeaponProfileProvider.notifier).state = unit.weapons.first;
          ref.read(isCustomWeaponModeProvider.notifier).state = true;
        }
        ref.read(currentNavIndexProvider.notifier).state = 0;
        message = "Loaded '${unit.name}' as attacker";
        break;
      case _UnitAction.defender:
        ref.read(loadedDefenderNameProvider.notifier).state = unit.name;
        ref.read(customTargetProfileProvider.notifier).state = unit.unitProfile;
        ref.read(isCustomTargetModeProvider.notifier).state = true;
        ref.read(currentNavIndexProvider.notifier).state = 0;
        message = "Loaded '${unit.name}' as defender";
        break;
      case _UnitAction.addToList:
        final list = ref.read(personalStoreProvider.notifier).addUnitToArmyList(unit: unit);
        ref.read(activeArmyListIdProvider.notifier).state = list.id;
        message = "Added '${unit.name}' to '${list.name}'";
        break;
      case _UnitAction.wishlist:
        ref.read(personalStoreProvider.notifier).upsertWishlistItem(
              WishlistItemUi(
                id: 'wl-${unit.id}',
                factionId: unit.factionId.isNotEmpty ? unit.factionId : unit.faction,
                factionName: unit.faction,
                unitId: unit.id,
                unitName: unit.name,
                quantityDesired: 1,
                quantityOwned: 0,
                pointsPerUnit: unit.pointsCost ?? 100,
                priority: WishlistPriorityUi.medium,
                state: AcquisitionStateUi.wishlist,
                updatedAtIso: DateTime.now().toIso8601String(),
              ),
            );
        message = "Added '${unit.name}' to wishlist";
        break;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }
}

