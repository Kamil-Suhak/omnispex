import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bsdata_models.dart';
import '../models/omnispex_models.dart';
import '../models/simulation_models.dart';
import '../providers/app_state_provider.dart';
import '../services/bsdata_service.dart';
import '../services/personal_data_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/scannable_metric_card.dart';
import '../widgets/stat_badge.dart';
import '../widgets/tactical_card.dart';

final wishlistFactionFilterProvider =
    StateProvider<String>((ref) => 'All Factions');
final wishlistSearchQueryProvider = StateProvider<String>((ref) => '');
final wishlistPriorityFilterProvider =
    StateProvider<WishlistPriorityUi?>((ref) => null);
final wishlistStateFilterProvider =
    StateProvider<AcquisitionStateUi?>((ref) => null);
final wishlistSortFieldProvider =
    StateProvider<WishlistSortFieldUi>((ref) => WishlistSortFieldUi.priorityDesc);

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(catalogueRevisionEpochProvider);
    final store = ref.watch(personalStoreProvider);
    final factionFilter = ref.watch(wishlistFactionFilterProvider);
    final query = ref.watch(wishlistSearchQueryProvider);
    final priorityFilter = ref.watch(wishlistPriorityFilterProvider);
    final stateFilter = ref.watch(wishlistStateFilterProvider);
    final sortBy = ref.watch(wishlistSortFieldProvider);

    final response = PersonalDataService.queryWishlist(
      items: store.wishlistItems,
      factionId: factionFilter == 'All Factions' ? null : factionFilter,
      query: query,
      priorityFilter: priorityFilter,
      stateFilter: stateFilter,
      sortBy: sortBy,
    );

    final summary = response.summary;
    final items = response.filteredItems;
    final factionNames = <String>{
      'All Factions',
      ...store.wishlistItems.map((i) => i.factionName),
      ...BsDataService.availableFactions.where((f) => f != 'All Factions'),
    }.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UNIT WISHLIST & HOBBY TRACKER',
                          style: OmnispexTypography.h2),
                      Text(
                        'Army-Specific Collection Planning, Acquisition & Painting Progress',
                        style: OmnispexTypography.bodyMuted,
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart, size: 15),
                    label: Text(
                      'ADD UNIT TO WISHLIST',
                      style: OmnispexTypography.monoStatBadge.copyWith(
                        fontSize: 11,
                        color: OmnispexColors.background,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OmnispexColors.cyan,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _showUpsertWishlistDialog(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: ScannableMetricCard(
                      label: 'Collection Boxes',
                      value:
                          '${summary.totalBoxesOwned} / ${summary.totalBoxesDesired}',
                      subtitle:
                          '${summary.totalBoxesRemaining} remaining to acquire',
                      accentColor: OmnispexColors.cyan,
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ScannableMetricCard(
                      label: 'Wishlist Points',
                      value: '${summary.totalPointsDesired} PTS',
                      subtitle:
                          '${summary.totalPointsOwned} pts owned in collection',
                      accentColor: OmnispexColors.purple,
                      icon: Icons.military_tech,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ScannableMetricCard(
                      label: 'Hobby Completion',
                      value: '${summary.completionPercent.toStringAsFixed(0)}%',
                      subtitle:
                          '${summary.paintedEntriesCount} painted / ${summary.totalDistinctUnits} entries',
                      accentColor: OmnispexColors.greenKill,
                      icon: Icons.brush_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Filters & Sort Card
              TacticalCard(
                title: 'FILTER & SORT COLLECTION WISHLIST',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            style: OmnispexTypography.monoData
                                .copyWith(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Search wishlist units or notes...',
                              prefixIcon: Icon(Icons.search,
                                  size: 16, color: OmnispexColors.cyan),
                              isDense: true,
                            ),
                            onChanged: (val) => ref
                                .read(wishlistSearchQueryProvider.notifier)
                                .state = val,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<WishlistSortFieldUi>(
                            value: sortBy,
                            isExpanded: true,
                            dropdownColor: OmnispexColors.surfaceCard,
                            decoration: const InputDecoration(
                              labelText: 'SORT BY',
                              isDense: true,
                            ),
                            items: WishlistSortFieldUi.values.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s.label,
                                  style: OmnispexTypography.monoData
                                      .copyWith(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref
                                    .read(wishlistSortFieldProvider.notifier)
                                    .state = val;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: factionNames.take(15).map((f) {
                          final sel = factionFilter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                f,
                                style: OmnispexTypography.monoStatBadge
                                    .copyWith(
                                  fontSize: 10,
                                  color: sel
                                      ? OmnispexColors.background
                                      : OmnispexColors.cyan,
                                ),
                              ),
                              selected: sel,
                              selectedColor: OmnispexColors.cyan,
                              backgroundColor: OmnispexColors.surfaceElevated,
                              onSelected: (_) => ref
                                  .read(wishlistFactionFilterProvider.notifier)
                                  .state = f,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(
                            'All Priorities',
                            style: OmnispexTypography.monoStatBadge
                                .copyWith(fontSize: 10),
                          ),
                          selected: priorityFilter == null,
                          selectedColor:
                              OmnispexColors.amber.withOpacity(0.25),
                          backgroundColor: OmnispexColors.surfaceElevated,
                          onSelected: (_) => ref
                              .read(wishlistPriorityFilterProvider.notifier)
                              .state = null,
                        ),
                        ...WishlistPriorityUi.values.map((p) {
                          final sel = priorityFilter == p;
                          return ChoiceChip(
                            label: Text(
                              p.label,
                              style: OmnispexTypography.monoStatBadge
                                  .copyWith(fontSize: 10),
                            ),
                            selected: sel,
                            selectedColor:
                                OmnispexColors.amber.withOpacity(0.25),
                            backgroundColor: OmnispexColors.surfaceElevated,
                            onSelected: (_) => ref
                                .read(wishlistPriorityFilterProvider.notifier)
                                .state = sel ? null : p,
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Wishlist Entries
              if (items.isEmpty)
                TacticalCard(
                  title: 'WISHLIST EMPTY',
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No wishlist entries match the active filters. Add units from the Datasheets browser or click "ADD UNIT TO WISHLIST".',
                        style: OmnispexTypography.bodyMuted,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                ...items.map((item) => _buildWishlistCard(context, ref, item)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWishlistCard(
    BuildContext context,
    WidgetRef ref,
    WishlistItemUi item,
  ) {
    final priorityColor = switch (item.priority) {
      WishlistPriorityUi.critical => OmnispexColors.redIneffective,
      WishlistPriorityUi.high => OmnispexColors.amber,
      WishlistPriorityUi.medium => OmnispexColors.cyan,
      WishlistPriorityUi.low => OmnispexColors.textSecondary,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.unitName,
                    style: OmnispexTypography.h3.copyWith(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  StatBadge(
                    label: 'ARMY',
                    value: item.factionName,
                    accentColor: OmnispexColors.cyan,
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                children: [
                  StatBadge(
                    label: 'PRIORITY',
                    value: item.priority.label.toUpperCase(),
                    accentColor: priorityColor,
                  ),
                  StatBadge(
                    label: 'STATE',
                    value: item.state.label.toUpperCase(),
                    accentColor: OmnispexColors.greenKill,
                  ),
                  StatBadge(
                    label: 'POINTS',
                    value: '${item.totalPointsDesired} PTS',
                    accentColor: OmnispexColors.purple,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quantities & State Selector Row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildStepperPill(
                label: 'OWNED',
                value: item.quantityOwned,
                color: OmnispexColors.greenKill,
                onChanged: (next) {
                  ref.read(personalStoreProvider.notifier).upsertWishlistItem(
                        item.copyWith(
                          quantityOwned: next.clamp(0, 99),
                          updatedAtIso: DateTime.now().toIso8601String(),
                        ),
                      );
                },
              ),
              _buildStepperPill(
                label: 'DESIRED',
                value: item.quantityDesired,
                color: OmnispexColors.cyan,
                onChanged: (next) {
                  ref.read(personalStoreProvider.notifier).upsertWishlistItem(
                        item.copyWith(
                          quantityDesired: next.clamp(1, 99),
                          updatedAtIso: DateTime.now().toIso8601String(),
                        ),
                      );
                },
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<AcquisitionStateUi>(
                  value: item.state,
                  isExpanded: true,
                  dropdownColor: OmnispexColors.surfaceCard,
                  decoration: const InputDecoration(
                    labelText: 'HOBBY PROGRESS STATE',
                    isDense: true,
                  ),
                  items: AcquisitionStateUi.values.map((st) {
                    return DropdownMenuItem(
                      value: st,
                      child: Text(
                        st.label,
                        style:
                            OmnispexTypography.monoData.copyWith(fontSize: 11),
                      ),
                    );
                  }).toList(),
                  onChanged: (st) {
                    if (st != null) {
                      ref
                          .read(personalStoreProvider.notifier)
                          .upsertWishlistItem(
                            item.copyWith(
                              state: st,
                              updatedAtIso: DateTime.now().toIso8601String(),
                            ),
                          );
                    }
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<WishlistPriorityUi>(
                  value: item.priority,
                  isExpanded: true,
                  dropdownColor: OmnispexColors.surfaceCard,
                  decoration: const InputDecoration(
                    labelText: 'PRIORITY',
                    isDense: true,
                  ),
                  items: WishlistPriorityUi.values.map((pr) {
                    return DropdownMenuItem(
                      value: pr,
                      child: Text(
                        pr.label,
                        style:
                            OmnispexTypography.monoData.copyWith(fontSize: 11),
                      ),
                    );
                  }).toList(),
                  onChanged: (pr) {
                    if (pr != null) {
                      ref
                          .read(personalStoreProvider.notifier)
                          .upsertWishlistItem(
                            item.copyWith(
                              priority: pr,
                              updatedAtIso: DateTime.now().toIso8601String(),
                            ),
                          );
                    }
                  },
                ),
              ),
            ],
          ),

          if (item.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: ${item.notes}',
              style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(color: OmnispexColors.border, height: 1),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.playlist_add, size: 14),
                label: Text(
                  'ADD TO ARMY LIST',
                  style: OmnispexTypography.monoStatBadge.copyWith(
                    fontSize: 10,
                    color: OmnispexColors.background,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmnispexColors.cyan,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  final unit = BsDataService.findUnitById(item.unitId) ??
                      BsDataUnit(
                        id: item.unitId,
                        name: item.unitName,
                        faction: item.factionName,
                        factionId: item.factionId,
                        pointsCost: item.pointsPerUnit,
                        unitProfile: UnitUiProfile(
                          name: item.unitName,
                          toughness: 4,
                          save: 3,
                          woundsPerModel: 2,
                          modelCount: 5,
                        ),
                        weapons: const [],
                      );
                  final list = ref
                      .read(personalStoreProvider.notifier)
                      .addUnitToArmyList(unit: unit);
                  ref.read(activeArmyListIdProvider.notifier).state = list.id;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          "Added '${item.unitName}' to Army List '${list.name}'!"),
                      backgroundColor: OmnispexColors.surfaceElevated,
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 13),
                label: Text(
                  'EDIT',
                  style:
                      OmnispexTypography.monoStatBadge.copyWith(fontSize: 10),
                ),
                onPressed: () =>
                    _showUpsertWishlistDialog(context, ref, existing: item),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline,
                    size: 13, color: OmnispexColors.redIneffective),
                label: Text(
                  'REMOVE',
                  style: OmnispexTypography.monoStatBadge.copyWith(
                    fontSize: 10,
                    color: OmnispexColors.redIneffective,
                  ),
                ),
                onPressed: () {
                  ref
                      .read(personalStoreProvider.notifier)
                      .deleteWishlistItem(item.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepperPill({
    required String label,
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: OmnispexTypography.label
                .copyWith(fontSize: 10, color: color),
          ),
          IconButton(
            icon: const Icon(Icons.remove, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            onPressed: () => onChanged(value - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$value',
              style: OmnispexTypography.monoData.copyWith(fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }

  void _showUpsertWishlistDialog(
    BuildContext context,
    WidgetRef ref, {
    WishlistItemUi? existing,
  }) {
    final factions = BsDataService.bundledFactions;
    BsDataFaction selectedFaction = existing != null
        ? (BsDataService.findFaction(existing.factionId) ??
            BsDataService.findFaction(existing.factionName) ??
            factions.first)
        : factions.first;

    final unitNameCtrl =
        TextEditingController(text: existing?.unitName ?? 'Terminator Squad');
    final pointsCtrl =
        TextEditingController(text: '${existing?.pointsPerUnit ?? 175}');
    final desiredCtrl =
        TextEditingController(text: '${existing?.quantityDesired ?? 1}');
    final ownedCtrl =
        TextEditingController(text: '${existing?.quantityOwned ?? 0}');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    WishlistPriorityUi priority =
        existing?.priority ?? WishlistPriorityUi.medium;
    AcquisitionStateUi state = existing?.state ?? AcquisitionStateUi.wishlist;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: OmnispexColors.surfaceCard,
              title: Text(
                existing == null
                    ? 'ADD UNIT TO WISHLIST'
                    : 'EDIT WISHLIST ENTRY',
                style: OmnispexTypography.h3,
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<BsDataFaction>(
                        value: selectedFaction,
                        isExpanded: true,
                        dropdownColor: OmnispexColors.surfaceCard,
                        decoration:
                            const InputDecoration(labelText: 'ARMY / FACTION'),
                        items: factions.map((f) {
                          return DropdownMenuItem(
                            value: f,
                            child:
                                Text(f.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedFaction = val;
                              if (val.units.isNotEmpty && existing == null) {
                                unitNameCtrl.text = val.units.first.name;
                                pointsCtrl.text =
                                    '${val.units.first.pointsCost ?? 100}';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      if (selectedFaction.units.isNotEmpty)
                        DropdownButtonFormField<BsDataUnit>(
                          value: selectedFaction.units
                              .where((u) => u.name == unitNameCtrl.text)
                              .firstOrNull,
                          isExpanded: true,
                          dropdownColor: OmnispexColors.surfaceCard,
                          decoration: const InputDecoration(
                            labelText: 'QUICK-SELECT CATALOGUE UNIT',
                          ),
                          items: selectedFaction.units.take(150).map((u) {
                            return DropdownMenuItem(
                              value: u,
                              child: Text(
                                '${u.name} (${u.pointsCost ?? 100} pts)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (u) {
                            if (u != null) {
                              setState(() {
                                unitNameCtrl.text = u.name;
                                pointsCtrl.text = '${u.pointsCost ?? 100}';
                              });
                            }
                          },
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: unitNameCtrl,
                        decoration:
                            const InputDecoration(labelText: 'UNIT NAME'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: desiredCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'DESIRED QTY'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: ownedCtrl,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'OWNED QTY'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: pointsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'PTS / UNIT'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<WishlistPriorityUi>(
                              value: priority,
                              dropdownColor: OmnispexColors.surfaceCard,
                              decoration:
                                  const InputDecoration(labelText: 'PRIORITY'),
                              items: WishlistPriorityUi.values.map((p) {
                                return DropdownMenuItem(
                                    value: p, child: Text(p.label));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => priority = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<AcquisitionStateUi>(
                              value: state,
                              isExpanded: true,
                              dropdownColor: OmnispexColors.surfaceCard,
                              decoration: const InputDecoration(
                                  labelText: 'HOBBY STATE'),
                              items: AcquisitionStateUi.values.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(s.label,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => state = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                            labelText: 'NOTES (OPTIONAL)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OmnispexColors.cyan,
                    foregroundColor: OmnispexColors.background,
                  ),
                  onPressed: () {
                    final now = DateTime.now().toIso8601String();
                    final item = WishlistItemUi(
                      id: existing?.id ??
                          'wl-${DateTime.now().microsecondsSinceEpoch}',
                      factionId: selectedFaction.id,
                      factionName: selectedFaction.name,
                      unitId: existing?.unitId ??
                          unitNameCtrl.text
                              .trim()
                              .toLowerCase()
                              .replaceAll(' ', '_'),
                      unitName: unitNameCtrl.text.trim().isEmpty
                          ? 'Unknown Unit'
                          : unitNameCtrl.text.trim(),
                      quantityDesired:
                          (int.tryParse(desiredCtrl.text) ?? 1).clamp(1, 99),
                      quantityOwned:
                          (int.tryParse(ownedCtrl.text) ?? 0).clamp(0, 99),
                      pointsPerUnit: int.tryParse(pointsCtrl.text) ?? 100,
                      priority: priority,
                      state: state,
                      notes: notesCtrl.text.trim(),
                      updatedAtIso: now,
                    );
                    ref
                        .read(personalStoreProvider.notifier)
                        .upsertWishlistItem(item);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
