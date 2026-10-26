import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bsdata_models.dart';
import '../models/omnispex_models.dart';
import '../providers/app_state_provider.dart';
import '../services/bsdata_service.dart';
import '../services/personal_data_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/scannable_metric_card.dart';
import '../widgets/stat_badge.dart';
import '../widgets/tactical_card.dart';

final _unitAdderSearchProvider = StateProvider<String>((ref) => '');
final _unitAdderCategoryProvider = StateProvider<String>((ref) => 'All Types');

class ArmyListBuilderScreen extends ConsumerWidget {
  const ArmyListBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(catalogueRevisionEpochProvider);
    final store = ref.watch(personalStoreProvider);
    final lists = store.armyLists;
    final selectedId = ref.watch(activeArmyListIdProvider);

    final ArmyListUi? activeList = lists.isEmpty
        ? null
        : lists.firstWhere(
            (l) => l.id == selectedId,
            orElse: () => lists.first,
          );

    final factions = BsDataService.bundledFactions;
    final activeFaction = activeList != null
        ? (BsDataService.findFaction(activeList.factionId) ??
            BsDataService.findFaction(activeList.factionName) ??
            (factions.isNotEmpty ? factions.first : null))
        : (factions.isNotEmpty ? factions.first : null);

    final ArmyListEvaluationUi? evaluation = activeList != null
        ? PersonalDataService.evaluateArmyList(
            list: activeList,
            faction: activeFaction,
          )
        : null;

    final evaluatedList = evaluation?.list ?? activeList;
    final validation = evaluation?.validation;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 960;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ref, evaluatedList, evaluation, factions),
              const SizedBox(height: 14),
              if (evaluatedList == null)
                _buildEmptyListsState(context, ref, factions)
              else ...[
                _buildRosterSummaryMetrics(evaluatedList, validation),
                const SizedBox(height: 12),
                if (validation != null)
                  _buildValidationBanner(context, validation),
                const SizedBox(height: 14),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildLeftColumn(
                          context,
                          ref,
                          evaluatedList,
                          activeFaction,
                          factions,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 7,
                        child: _buildRosterUnitsColumn(
                          context,
                          ref,
                          evaluatedList,
                          activeFaction,
                          validation,
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildLeftColumn(
                    context,
                    ref,
                    evaluatedList,
                    activeFaction,
                    factions,
                  ),
                  const SizedBox(height: 16),
                  _buildRosterUnitsColumn(
                    context,
                    ref,
                    evaluatedList,
                    activeFaction,
                    validation,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ArmyListUi? activeList,
    ArmyListEvaluationUi? evaluation,
    List<BsDataFaction> factions,
  ) {
    final lists = ref.watch(personalStoreProvider).armyLists;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('11TH EDITION ARMY LIST BUILDER', style: OmnispexTypography.h2),
            Text(
              'Dynamic MFM Requisition Thresholds, Detachment Points & Rust Legality Engine',
              style: OmnispexTypography.bodyMuted,
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (lists.length > 1 && activeList != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: OmnispexColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: OmnispexColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: activeList.id,
                    dropdownColor: OmnispexColors.surfaceCard,
                    items: lists.map((l) {
                      return DropdownMenuItem(
                        value: l.id,
                        child: Text(
                          '${l.name} (${l.totalPoints} pts)',
                          style: OmnispexTypography.monoData
                              .copyWith(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(activeArmyListIdProvider.notifier).state = val;
                      }
                    },
                  ),
                ),
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 15),
              label: Text(
                'NEW LIST',
                style: OmnispexTypography.monoStatBadge
                    .copyWith(fontSize: 11, color: OmnispexColors.background),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: OmnispexColors.cyan,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _showCreateListDialog(context, ref, factions),
            ),
            if (activeList != null) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: Text(
                  'DUPLICATE',
                  style:
                      OmnispexTypography.monoStatBadge.copyWith(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmnispexColors.cyan,
                  side: const BorderSide(color: OmnispexColors.cyan),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: () {
                  final copy = ref
                      .read(personalStoreProvider.notifier)
                      .duplicateArmyList(activeList);
                  ref.read(activeArmyListIdProvider.notifier).state = copy.id;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Duplicated '${copy.name}'"),
                      backgroundColor: OmnispexColors.surfaceElevated,
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.ios_share, size: 14),
                label: Text(
                  'EXPORT TEXT',
                  style:
                      OmnispexTypography.monoStatBadge.copyWith(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmnispexColors.amber,
                  side: const BorderSide(color: OmnispexColors.amber),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: () {
                  if (evaluation != null) {
                    _showExportModal(context, evaluation.exportedText);
                  }
                },
              ),
              IconButton(
                tooltip: 'Delete Army List',
                icon: const Icon(Icons.delete_outline,
                    color: OmnispexColors.redIneffective, size: 20),
                onPressed: () {
                  ref
                      .read(personalStoreProvider.notifier)
                      .deleteArmyList(activeList.id);
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyListsState(
    BuildContext context,
    WidgetRef ref,
    List<BsDataFaction> factions,
  ) {
    return TacticalCard(
      title: 'NO ACTIVE ARMY ROSTERS',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 48, color: OmnispexColors.cyanMuted),
              const SizedBox(height: 12),
              Text('Create your first 11th Edition Roster',
                  style: OmnispexTypography.h3),
              const SizedBox(height: 6),
              Text(
                'Select a faction, configure detachments within your DP budget, and add units.',
                style: OmnispexTypography.bodyMuted,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('CREATE NEW ARMY LIST'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmnispexColors.cyan,
                  foregroundColor: OmnispexColors.background,
                ),
                onPressed: () => _showCreateListDialog(context, ref, factions),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRosterSummaryMetrics(
    ArmyListUi list,
    ListValidationReportUi? validation,
  ) {
    final pts = validation?.totalPoints ?? list.totalPoints;
    final ptsLimit = validation?.pointsLimit ?? list.pointsLimit;
    final dp = validation?.totalDp ?? list.totalDp;
    final dpLimit = validation?.dpLimit ?? list.battleSize.dpLimit;
    final enhUsed = validation?.enhancementSlotsUsed ?? 0;
    final enhLimit =
        validation?.enhancementLimit ?? list.battleSize.enhancementLimit;
    final isValid = validation?.isValid ?? true;

    return Row(
      children: [
        Expanded(
          child: ScannableMetricCard(
            label: 'Roster Points',
            value: '$pts / $ptsLimit PTS',
            subtitle: pts > ptsLimit
                ? 'OVER BUDGET (+${pts - ptsLimit} pts)'
                : '${ptsLimit - pts} pts remaining',
            accentColor: pts > ptsLimit
                ? OmnispexColors.redIneffective
                : OmnispexColors.cyan,
            icon: Icons.military_tech,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ScannableMetricCard(
            label: 'Detachment Budget',
            value: '$dp / $dpLimit DP',
            subtitle: '${list.detachments.length} Detachment(s) active',
            accentColor: dp > dpLimit
                ? OmnispexColors.redIneffective
                : OmnispexColors.amber,
            icon: Icons.account_tree_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ScannableMetricCard(
            label: 'Enhancement Slots',
            value: '$enhUsed / $enhLimit SLOTS',
            subtitle: isValid
                ? 'ROSTER LEGAL (11E VALIDATED)'
                : '${validation?.violations.length ?? 0} RULE VIOLATION(S)',
            accentColor: isValid
                ? OmnispexColors.greenKill
                : OmnispexColors.redIneffective,
            icon: isValid ? Icons.verified : Icons.warning_amber_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildValidationBanner(
    BuildContext context,
    ListValidationReportUi validation,
  ) {
    final isValid = validation.isValid;
    final borderColor =
        isValid ? OmnispexColors.greenKill : OmnispexColors.redIneffective;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: borderColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.check_circle : Icons.error_outline,
                color: borderColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isValid
                      ? 'RUST VALIDATION ENGINE: ROSTER LEGAL FOR BATTLE'
                      : 'RUST VALIDATION ENGINE: ${validation.violations.length} CONFIRMED VIOLATION(S)',
                  style: OmnispexTypography.monoStatBadge.copyWith(
                    color: borderColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (validation.violations.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...validation.violations.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• [${v.code}] ${v.message}',
                    style: OmnispexTypography.body.copyWith(
                      fontSize: 12,
                      color: OmnispexColors.textPrimary,
                    ),
                  ),
                )),
          ],
          if (validation.warnings.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...validation.warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '⚠ [${w.code}] ${w.message}',
                    style: OmnispexTypography.bodyMuted.copyWith(
                      fontSize: 11,
                      color: OmnispexColors.amber,
                    ),
                  ),
                )),
          ],
          if (validation.unverifiedRules.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'UNVERIFIED PROSE RULES (INFORMATIONAL ONLY):',
              style: OmnispexTypography.label
                  .copyWith(fontSize: 10, color: OmnispexColors.cyan),
            ),
            const SizedBox(height: 2),
            ...validation.unverifiedRules.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'ℹ $u',
                    style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildLeftColumn(
    BuildContext context,
    WidgetRef ref,
    ArmyListUi list,
    BsDataFaction? activeFaction,
    List<BsDataFaction> factions,
  ) {
    final unitQuery = ref.watch(_unitAdderSearchProvider);
    final unitCat = ref.watch(_unitAdderCategoryProvider);
    final factionUnits = (activeFaction?.units ?? []).where((u) {
      if (u.isLegends) return false;
      if (unitCat == 'Character' && !u.isCharacter) return false;
      if (unitCat == 'Battleline' && !u.isBattleline) return false;
      if (unitCat == 'Infantry' && !u.isInfantry) return false;
      if (unitCat == 'Vehicle / Monster' && !u.isVehicleOrMonster) return false;
      if (unitQuery.trim().isNotEmpty &&
          !u.name.toLowerCase().contains(unitQuery.trim().toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Roster Configuration & Battle Size
        TacticalCard(
          title: '1. ROSTER CONFIGURATION & BATTLE SIZE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: ValueKey('list-name-${list.id}'),
                initialValue: list.name,
                style: OmnispexTypography.monoData.copyWith(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'ARMY LIST NAME',
                  isDense: true,
                ),
                onChanged: (val) {
                  if (val.trim().isNotEmpty) {
                    ref.read(personalStoreProvider.notifier).upsertArmyList(
                          list.copyWith(
                            name: val.trim(),
                            updatedAtIso: DateTime.now().toIso8601String(),
                          ),
                        );
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: activeFaction?.id ?? factions.first.id,
                isExpanded: true,
                dropdownColor: OmnispexColors.surfaceCard,
                decoration: const InputDecoration(
                  labelText: 'FACTION CATALOGUE',
                  isDense: true,
                ),
                items: factions.map((f) {
                  return DropdownMenuItem(
                    value: f.id,
                    child: Text(
                      '${f.name} (${f.units.length} units)',
                      style: OmnispexTypography.monoData.copyWith(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (factionId) {
                  if (factionId != null) {
                    final f =
                        factions.firstWhere((el) => el.id == factionId);
                    final defaultDet = f.detachments.isNotEmpty
                        ? [
                            SelectedDetachmentUi(
                              id: f.detachments.first.id,
                              name: f.detachments.first.name,
                              dpCost: f.detachments.first.dpCost,
                              uniqueTag: f.detachments.first.uniqueTag,
                            )
                          ]
                        : <SelectedDetachmentUi>[];
                    ref.read(personalStoreProvider.notifier).upsertArmyList(
                          list.copyWith(
                            factionId: f.id,
                            factionName: f.name,
                            detachments: defaultDet,
                            units: [],
                            updatedAtIso: DateTime.now().toIso8601String(),
                          ),
                        );
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<BattleSizeUi>(
                value: list.battleSize,
                isExpanded: true,
                dropdownColor: OmnispexColors.surfaceCard,
                decoration: const InputDecoration(
                  labelText: '11E BATTLE SIZE & DP BUDGET',
                  isDense: true,
                ),
                items: BattleSizeUi.values.map((bs) {
                  return DropdownMenuItem(
                    value: bs,
                    child: Text(
                      '${bs.label} — ${bs.dpLimit} DP / ${bs.enhancementLimit} Enh',
                      style: OmnispexTypography.monoData.copyWith(fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (bs) {
                  if (bs != null) {
                    ref.read(personalStoreProvider.notifier).upsertArmyList(
                          list.copyWith(
                            battleSize: bs,
                            pointsLimit: bs.defaultPointsLimit,
                            updatedAtIso: DateTime.now().toIso8601String(),
                          ),
                        );
                  }
                },
              ),
            ],
          ),
        ),

        // 2. Detachment Selection (DP Budget)
        TacticalCard(
          title:
              '2. DETACHMENTS (${list.totalDp} / ${list.battleSize.dpLimit} DP)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeFaction == null || activeFaction.detachments.isEmpty)
                Text(
                  'No detachments listed for this catalogue.',
                  style: OmnispexTypography.bodyMuted,
                )
              else
                ...activeFaction.detachments.map((det) {
                  final isSelected =
                      list.detachments.any((d) => d.id == det.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? OmnispexColors.cyan.withOpacity(0.12)
                          : OmnispexColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? OmnispexColors.cyan
                            : OmnispexColors.border,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        final updated =
                            List<SelectedDetachmentUi>.from(list.detachments);
                        if (isSelected) {
                          updated.removeWhere((d) => d.id == det.id);
                        } else {
                          updated.add(SelectedDetachmentUi(
                            id: det.id,
                            name: det.name,
                            dpCost: det.dpCost,
                            uniqueTag: det.uniqueTag,
                          ));
                        }
                        ref.read(personalStoreProvider.notifier).upsertArmyList(
                              list.copyWith(
                                detachments: updated,
                                updatedAtIso: DateTime.now().toIso8601String(),
                              ),
                            );
                      },
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 18,
                            color: isSelected
                                ? OmnispexColors.cyan
                                : OmnispexColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  det.name,
                                  style: OmnispexTypography.monoData
                                      .copyWith(fontSize: 12),
                                ),
                                if (det.forceDispositions.isNotEmpty)
                                  Text(
                                    'Dispositions: ${det.forceDispositions.join(", ")}',
                                    style: OmnispexTypography.bodyMuted
                                        .copyWith(fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                          StatBadge(
                            label: 'COST',
                            value: '${det.dpCost} DP',
                            accentColor: OmnispexColors.amber,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),

        // 3. Unit Adder from Faction Catalogue
        TacticalCard(
          title: '3. ADD DATASHEET TO ROSTER (${factionUnits.length})',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                style: OmnispexTypography.monoData.copyWith(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Filter faction units...',
                  prefixIcon:
                      Icon(Icons.search, size: 16, color: OmnispexColors.cyan),
                  isDense: true,
                ),
                onChanged: (val) =>
                    ref.read(_unitAdderSearchProvider.notifier).state = val,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'All Types',
                  'Character',
                  'Battleline',
                  'Infantry',
                  'Vehicle / Monster'
                ].map((cat) {
                  final sel = unitCat == cat;
                  return ChoiceChip(
                    label: Text(
                      cat,
                      style: OmnispexTypography.monoStatBadge.copyWith(
                        fontSize: 10,
                        color: sel
                            ? OmnispexColors.background
                            : OmnispexColors.cyan,
                      ),
                    ),
                    selected: sel,
                    selectedColor: OmnispexColors.cyan,
                    backgroundColor: OmnispexColors.surfaceElevated,
                    onSelected: (_) =>
                        ref.read(_unitAdderCategoryProvider.notifier).state =
                            cat,
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: factionUnits.length,
                  itemBuilder: (context, idx) {
                    final u = factionUnits[idx];
                    final pts = u.pointsCost ??
                        (u.legalSizeOptions.isNotEmpty
                            ? u.legalSizeOptions.first.points
                            : 100);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: OmnispexColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: OmnispexColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.name,
                                  style: OmnispexTypography.monoData
                                      .copyWith(fontSize: 12),
                                ),
                                Text(
                                  'T${u.unitProfile.toughness} Sv${u.unitProfile.save}+ W${u.unitProfile.woundsPerModel} • $pts pts',
                                  style: OmnispexTypography.bodyMuted
                                      .copyWith(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 13),
                            label: Text(
                              'ADD',
                              style: OmnispexTypography.monoStatBadge.copyWith(
                                fontSize: 10,
                                color: OmnispexColors.background,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OmnispexColors.cyan,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              ref
                                  .read(personalStoreProvider.notifier)
                                  .addUnitToArmyList(
                                    unit: u,
                                    targetListId: list.id,
                                  );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRosterUnitsColumn(
    BuildContext context,
    WidgetRef ref,
    ArmyListUi list,
    BsDataFaction? activeFaction,
    ListValidationReportUi? validation,
  ) {
    // Collect available enhancements from selected detachments
    final availableEnhancements = <EnhancementDataUi>[];
    if (activeFaction != null) {
      for (final selDet in list.detachments) {
        final detData = activeFaction.detachments
            .where((d) => d.id == selDet.id || d.name == selDet.name)
            .firstOrNull;
        if (detData != null) {
          availableEnhancements.addAll(detData.enhancements);
        }
      }
    }

    final nonCharacterEntries =
        list.units.where((u) => !u.isCharacter).toList();

    return TacticalCard(
      title:
          'ACTIVE ROSTER UNITS (${list.units.length} UNITS • ${list.totalPoints} PTS)',
      child: list.units.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No units in this roster yet. Use the Unit Adder panel to add units.',
                  style: OmnispexTypography.bodyMuted,
                ),
              ),
            )
          : Column(
              children: list.units.map((entry) {
                final unitData = activeFaction?.units
                    .where((u) =>
                        u.id == entry.unitId ||
                        u.name.toLowerCase() == entry.unitName.toLowerCase())
                    .firstOrNull;
                final sizeOptions = unitData?.legalSizeOptions ?? [];
                final hasViolation = validation?.violations.any(
                        (v) => v.affectedEntryId == entry.entryId) ??
                    false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OmnispexColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasViolation
                          ? OmnispexColors.redIneffective
                          : (entry.isWarlord
                              ? OmnispexColors.amber
                              : OmnispexColors.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  entry.unitName,
                                  style: OmnispexTypography.h3
                                      .copyWith(fontSize: 15),
                                ),
                                if (entry.isWarlord)
                                  const StatBadge(
                                    label: 'ROLE',
                                    value: 'WARLORD',
                                    accentColor: OmnispexColors.amber,
                                  ),
                                if (entry.requisitionTierLabel != null &&
                                    entry.requisitionTierLabel != 'Standard')
                                  StatBadge(
                                    label: 'MFM TIER',
                                    value: entry.requisitionTierLabel!,
                                    accentColor: OmnispexColors.purple,
                                  ),
                              ],
                            ),
                          ),
                          StatBadge(
                            label: 'TOTAL',
                            value: '${entry.totalPoints} PTS',
                            accentColor: OmnispexColors.cyan,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: OmnispexColors.redIneffective),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              final updated = list.units
                                  .where((u) => u.entryId != entry.entryId)
                                  .toList();
                              ref
                                  .read(personalStoreProvider.notifier)
                                  .upsertArmyList(list.copyWith(
                                    units: updated,
                                    updatedAtIso:
                                        DateTime.now().toIso8601String(),
                                  ));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Size & Warlord row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (sizeOptions.length > 1)
                            ...sizeOptions.map((opt) {
                              final isSel = entry.modelsCount == opt.models;
                              return ChoiceChip(
                                label: Text(
                                  '${opt.models} Models (${opt.points} pts)',
                                  style: OmnispexTypography.monoStatBadge
                                      .copyWith(
                                    fontSize: 10,
                                    color: isSel
                                        ? OmnispexColors.background
                                        : OmnispexColors.cyan,
                                  ),
                                ),
                                selected: isSel,
                                selectedColor: OmnispexColors.cyan,
                                backgroundColor: OmnispexColors.surfaceCard,
                                onSelected: (sel) {
                                  if (sel) {
                                    _updateEntry(
                                      ref,
                                      list,
                                      entry.copyWith(
                                        modelsCount: opt.models,
                                        basePoints: opt.points,
                                      ),
                                    );
                                  }
                                },
                              );
                            })
                          else
                            Text(
                              'Models: ${entry.modelsCount} (${entry.basePoints} base pts)',
                              style: OmnispexTypography.bodyMuted
                                  .copyWith(fontSize: 11),
                            ),
                          FilterChip(
                            label: Text(
                              'Warlord',
                              style: OmnispexTypography.monoStatBadge
                                  .copyWith(fontSize: 10),
                            ),
                            selected: entry.isWarlord,
                            selectedColor:
                                OmnispexColors.amber.withOpacity(0.25),
                            backgroundColor: OmnispexColors.surfaceCard,
                            onSelected: (val) {
                              final updatedUnits = list.units.map((u) {
                                if (u.entryId == entry.entryId) {
                                  return u.copyWith(isWarlord: val);
                                }
                                return val ? u.copyWith(isWarlord: false) : u;
                              }).toList();
                              ref
                                  .read(personalStoreProvider.notifier)
                                  .upsertArmyList(list.copyWith(
                                    units: updatedUnits,
                                    updatedAtIso:
                                        DateTime.now().toIso8601String(),
                                  ));
                            },
                          ),
                        ],
                      ),

                      // Character Enhancement & Leader Attachment Pickers
                      if (entry.isCharacter) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (!entry.isEpicHero &&
                                availableEnhancements.isNotEmpty)
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  value: availableEnhancements.any((e) =>
                                          e.id == entry.enhancementId)
                                      ? entry.enhancementId
                                      : null,
                                  isExpanded: true,
                                  dropdownColor: OmnispexColors.surfaceCard,
                                  decoration: const InputDecoration(
                                    labelText: 'ENHANCEMENT',
                                    isDense: true,
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('None'),
                                    ),
                                    ...availableEnhancements.map((enh) {
                                      return DropdownMenuItem<String?>(
                                        value: enh.id,
                                        child: Text(
                                          '${enh.name} (+${enh.points} pts)',
                                          style: OmnispexTypography.monoData
                                              .copyWith(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (enhId) {
                                    if (enhId == null) {
                                      _updateEntry(
                                        ref,
                                        list,
                                        entry.copyWith(clearEnhancement: true),
                                      );
                                    } else {
                                      final enh = availableEnhancements
                                          .firstWhere((e) => e.id == enhId);
                                      _updateEntry(
                                        ref,
                                        list,
                                        entry.copyWith(
                                          enhancementId: enh.id,
                                          enhancementName: enh.name,
                                          enhancementPoints: enh.points,
                                          enhancementIsUpgrade: enh.isUpgrade,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            if (!entry.isEpicHero &&
                                availableEnhancements.isNotEmpty &&
                                nonCharacterEntries.isNotEmpty)
                              const SizedBox(width: 8),
                            if (nonCharacterEntries.isNotEmpty)
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  value: nonCharacterEntries.any((b) =>
                                          b.entryId ==
                                          entry.attachedToEntryId)
                                      ? entry.attachedToEntryId
                                      : null,
                                  isExpanded: true,
                                  dropdownColor: OmnispexColors.surfaceCard,
                                  decoration: const InputDecoration(
                                    labelText: 'ATTACH AS LEADER TO',
                                    isDense: true,
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Unattached'),
                                    ),
                                    ...nonCharacterEntries.map((bg) {
                                      return DropdownMenuItem<String?>(
                                        value: bg.entryId,
                                        child: Text(
                                          bg.unitName,
                                          style: OmnispexTypography.monoData
                                              .copyWith(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (targetEntryId) {
                                    _updateEntry(
                                      ref,
                                      list,
                                      entry.copyWith(
                                        attachedToEntryId: targetEntryId,
                                        clearAttachment: targetEntryId == null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  void _updateEntry(
    WidgetRef ref,
    ArmyListUi list,
    RosterUnitEntryUi updatedEntry,
  ) {
    final updatedUnits = list.units.map((u) {
      return u.entryId == updatedEntry.entryId ? updatedEntry : u;
    }).toList();
    ref.read(personalStoreProvider.notifier).upsertArmyList(
          list.copyWith(
            units: updatedUnits,
            updatedAtIso: DateTime.now().toIso8601String(),
          ),
        );
  }

  void _showCreateListDialog(
    BuildContext context,
    WidgetRef ref,
    List<BsDataFaction> factions,
  ) {
    final nameCtrl = TextEditingController(text: 'New Strike Force');
    BsDataFaction selectedFaction = factions.first;
    BattleSizeUi selectedSize = BattleSizeUi.strikeForce;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: OmnispexColors.surfaceCard,
              title: Text('CREATE NEW ARMY LIST', style: OmnispexTypography.h3),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'ROSTER NAME'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BsDataFaction>(
                      value: selectedFaction,
                      isExpanded: true,
                      dropdownColor: OmnispexColors.surfaceCard,
                      decoration: const InputDecoration(labelText: 'FACTION'),
                      items: factions.map((f) {
                        return DropdownMenuItem(
                          value: f,
                          child: Text(f.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selectedFaction = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BattleSizeUi>(
                      value: selectedSize,
                      isExpanded: true,
                      dropdownColor: OmnispexColors.surfaceCard,
                      decoration:
                          const InputDecoration(labelText: 'BATTLE SIZE'),
                      items: BattleSizeUi.values.map((bs) {
                        return DropdownMenuItem(
                          value: bs,
                          child: Text(bs.label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selectedSize = val);
                        }
                      },
                    ),
                  ],
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
                    final defaultDet = selectedFaction.detachments.isNotEmpty
                        ? [
                            SelectedDetachmentUi(
                              id: selectedFaction.detachments.first.id,
                              name: selectedFaction.detachments.first.name,
                              dpCost: selectedFaction.detachments.first.dpCost,
                              uniqueTag:
                                  selectedFaction.detachments.first.uniqueTag,
                            )
                          ]
                        : <SelectedDetachmentUi>[];
                    final newList = ArmyListUi(
                      id: 'list-${DateTime.now().microsecondsSinceEpoch}',
                      name: nameCtrl.text.trim().isEmpty
                          ? 'Untitled Roster'
                          : nameCtrl.text.trim(),
                      factionId: selectedFaction.id,
                      factionName: selectedFaction.name,
                      battleSize: selectedSize,
                      pointsLimit: selectedSize.defaultPointsLimit,
                      detachments: defaultDet,
                      createdAtIso: now,
                      updatedAtIso: now,
                    );
                    ref
                        .read(personalStoreProvider.notifier)
                        .upsertArmyList(newList);
                    ref.read(activeArmyListIdProvider.notifier).state =
                        newList.id;
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('CREATE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showExportModal(BuildContext context, String exportedText) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: OmnispexColors.surfaceCard,
          title: Text('EXPORTED ARMY ROSTER', style: OmnispexTypography.h3),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                exportedText,
                style: OmnispexTypography.monoData.copyWith(fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CLOSE'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('COPY TO CLIPBOARD'),
              style: ElevatedButton.styleFrom(
                backgroundColor: OmnispexColors.cyan,
                foregroundColor: OmnispexColors.background,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: exportedText));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Army list copied to clipboard!'),
                    backgroundColor: OmnispexColors.surfaceElevated,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
