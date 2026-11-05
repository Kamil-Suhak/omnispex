import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_state_provider.dart';
import '../../../services/personal_data_service.dart';
import '../../../theme/omnispex_colors.dart';
import '../../../theme/omnispex_typography.dart';
import '../../../widgets/stat_strip.dart';
import '../models/kill_team_models.dart';
import '../services/kill_team_service.dart';

class KtRosterBuilderScreen extends ConsumerStatefulWidget {
  const KtRosterBuilderScreen({super.key});

  @override
  ConsumerState<KtRosterBuilderScreen> createState() =>
      _KtRosterBuilderScreenState();
}

class _KtRosterBuilderScreenState
    extends ConsumerState<KtRosterBuilderScreen> {
  List<KillTeamFactionUi> _factions = [];
  List<KillTeamEquipmentUi> _universalEquipment = [];
  String? _selectedRosterId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await KillTeamService.ensureCatalogueLoaded();
    _factions = KillTeamService.getFactions();
    _universalEquipment = KillTeamService.getUniversalEquipment();
    final rosters = ref.read(killTeamRostersProvider);
    if (rosters.isNotEmpty) {
      _selectedRosterId = rosters.first.id;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _updateRoster(KillTeamRosterUi updated) {
    final rosters = List<KillTeamRosterUi>.from(
      ref.read(killTeamRostersProvider),
    );
    final idx = rosters.indexWhere((r) => r.id == updated.id);
    if (idx >= 0) {
      rosters[idx] = updated;
    } else {
      rosters.add(updated);
    }
    ref.read(killTeamRostersProvider.notifier).state = rosters;
    PersonalDataService.saveKillTeamRoster(
      updated,
      ref.read(personalStoreProvider),
    );
  }

  void _createNewRoster(KillTeamFactionUi faction) {
    final now = DateTime.now().toUtc().toIso8601String();
    final newRoster = KillTeamRosterUi(
      id: 'kt-${DateTime.now().microsecondsSinceEpoch}',
      name: '${faction.name} Kill Team',
      factionId: faction.id,
      factionName: faction.name,
      selectedPrimaryArchetype:
          faction.archetypes.isNotEmpty ? faction.archetypes.first : '',
      operatives: faction.operatives.take(faction.teamSize).map((op) {
        return SelectedOperativeEntryUi(
          entryId: 'op-${DateTime.now().microsecondsSinceEpoch}-${op.id}',
          operativeId: op.id,
          operativeName: op.name,
          role: op.role,
          isLeader: op.isLeader,
          selectedWeapons: op.weapons.take(2).map((w) => w.name).toList(),
        );
      }).toList(),
      createdAtIso: now,
      updatedAtIso: now,
    );
    _updateRoster(newRoster);
    setState(() {
      _selectedRosterId = newRoster.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rosters = ref.watch(killTeamRostersProvider);
    final activeRoster = rosters.where((r) => r.id == _selectedRosterId).firstOrNull ??
        (rosters.isNotEmpty ? rosters.first : null);

    if (activeRoster == null) {
      return Center(
        child: ElevatedButton(
          onPressed: _factions.isNotEmpty
              ? () => _createNewRoster(_factions.first)
              : null,
          child: const Text('CREATE KILL TEAM ROSTER'),
        ),
      );
    }

    final faction = KillTeamService.getFactionDetail(activeRoster.factionId) ??
        (_factions.isNotEmpty ? _factions.first : null);
    final validation = KillTeamService.validateRoster(activeRoster);
    final availableEquipment = <KillTeamEquipmentUi>[
      ...?faction?.factionEquipment,
      ..._universalEquipment,
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('KILL TEAM ROSTER BUILDER',
                      style: OmnispexTypography.h2),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('EXPORT TEXT'),
                        onPressed: () {
                          final text =
                              KillTeamService.exportRosterText(activeRoster);
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Kill Team roster copied to clipboard.'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('NEW ROSTER'),
                        onPressed: _factions.isEmpty
                            ? null
                            : () => _showNewRosterDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: activeRoster.id,
                      items: rosters
                          .map(
                            (r) => DropdownMenuItem(
                              value: r.id,
                              child: Text('${r.name} (${r.factionName})'),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (id != null) {
                          setState(() => _selectedRosterId = id);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StatStripRow(
                items: [
                  StatCellItem(
                    label: 'STATUS',
                    value: validation.isValid ? 'LEGAL' : 'INVALID',
                    valueColor: validation.isValid
                        ? OmnispexColors.greenKill
                        : OmnispexColors.redIneffective,
                  ),
                  StatCellItem(
                    label: 'OPERATIVES',
                    value:
                        '${validation.operativeCount} / ${validation.maxOperatives}',
                  ),
                  StatCellItem(
                    label: 'LEADER',
                    value: '${validation.leaderCount} / 1',
                  ),
                  StatCellItem(
                    label: 'EQUIPMENT',
                    value:
                        '${validation.equipmentCount} / ${validation.maxEquipment}',
                  ),
                  StatCellItem(
                    label: 'ARCHETYPE',
                    value: activeRoster.selectedPrimaryArchetype.isEmpty
                        ? '—'
                        : activeRoster.selectedPrimaryArchetype,
                  ),
                ],
              ),
              if (validation.violations.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OmnispexColors.surfaceCard,
                    border: Border(
                      left: const BorderSide(
                          color: OmnispexColors.redIneffective, width: 4),
                      top: const BorderSide(color: OmnispexColors.border),
                      right: const BorderSide(color: OmnispexColors.border),
                      bottom: const BorderSide(color: OmnispexColors.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: validation.violations
                        .map(
                          (v) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• ${v.message}',
                              style: OmnispexTypography.bodyMuted.copyWith(
                                color: OmnispexColors.redIneffective,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SELECTED OPERATIVES', style: OmnispexTypography.label),
                  if (faction != null)
                    TextButton.icon(
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('ADD OPERATIVE'),
                      onPressed: () =>
                          _showAddOperativeDialog(context, activeRoster, faction),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.builder(
            itemCount: activeRoster.operatives.length,
            itemBuilder: (context, idx) {
              final op = activeRoster.operatives[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OmnispexColors.surfaceCard,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: OmnispexColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            op.isLeader
                                ? '${op.operativeName}  •  LEADER'
                                : '${op.operativeName}  •  ${op.role.toUpperCase()}',
                            style: OmnispexTypography.h3,
                          ),
                          if (op.selectedWeapons.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              op.selectedWeapons.join('  •  '),
                              style: OmnispexTypography.bodyMuted,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Toggle Leader',
                      icon: Icon(
                        op.isLeader ? Icons.star : Icons.star_border,
                        color: op.isLeader
                            ? OmnispexColors.amber
                            : OmnispexColors.textMuted,
                      ),
                      onPressed: () {
                        final updatedOps =
                            List<SelectedOperativeEntryUi>.from(
                          activeRoster.operatives,
                        );
                        updatedOps[idx] = op.copyWith(isLeader: !op.isLeader);
                        _updateRoster(
                          activeRoster.copyWith(operatives: updatedOps),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Remove Operative',
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () {
                        final updatedOps =
                            List<SelectedOperativeEntryUi>.from(
                          activeRoster.operatives,
                        )..removeAt(idx);
                        _updateRoster(
                          activeRoster.copyWith(operatives: updatedOps),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text('EQUIPMENT LOADOUT (MAX 4)', style: OmnispexTypography.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableEquipment.map((eq) {
                  final isSelected = activeRoster.equipment
                      .any((e) => e.equipmentId == eq.id);
                  return FilterChip(
                    label: Text(eq.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      final nextEq = List<SelectedEquipmentEntryUi>.from(
                        activeRoster.equipment,
                      );
                      if (selected) {
                        nextEq.add(
                          SelectedEquipmentEntryUi(
                            equipmentId: eq.id,
                            name: eq.name,
                            isUniversal: eq.isUniversal,
                          ),
                        );
                      } else {
                        nextEq.removeWhere((e) => e.equipmentId == eq.id);
                      }
                      _updateRoster(activeRoster.copyWith(equipment: nextEq));
                    },
                  );
                }).toList(),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _showNewRosterDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: OmnispexColors.surfaceCard,
          title: Text('SELECT KILL TEAM FACTION', style: OmnispexTypography.h2),
          content: SizedBox(
            width: 420,
            height: 360,
            child: ListView.builder(
              itemCount: _factions.length,
              itemBuilder: (context, idx) {
                final f = _factions[idx];
                return ListTile(
                  title: Text(f.name, style: OmnispexTypography.body),
                  subtitle: Text(
                    '${f.superfaction}  •  ${f.teamSize} Operatives  •  ${f.archetypes.join(", ")}',
                    style: OmnispexTypography.bodyMuted,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _createNewRoster(f);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddOperativeDialog(
    BuildContext context,
    KillTeamRosterUi roster,
    KillTeamFactionUi faction,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: OmnispexColors.surfaceCard,
          title: Text('ADD OPERATIVE — ${faction.name.toUpperCase()}',
              style: OmnispexTypography.h2),
          content: SizedBox(
            width: 460,
            height: 360,
            child: ListView.builder(
              itemCount: faction.operatives.length,
              itemBuilder: (context, idx) {
                final op = faction.operatives[idx];
                return ListTile(
                  title: Text(op.name, style: OmnispexTypography.body),
                  subtitle: Text(
                    '${op.role} • APL ${op.apl} • SAVE ${op.save}+ • ${op.wounds}W (Max ${op.maxPerKillTeam})',
                    style: OmnispexTypography.bodyMuted,
                  ),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () {
                    final nextOps = [
                      ...roster.operatives,
                      SelectedOperativeEntryUi(
                        entryId:
                            'op-${DateTime.now().microsecondsSinceEpoch}',
                        operativeId: op.id,
                        operativeName: op.name,
                        role: op.role,
                        isLeader: op.isLeader &&
                            !roster.operatives.any((o) => o.isLeader),
                        selectedWeapons:
                            op.weapons.take(2).map((w) => w.name).toList(),
                      ),
                    ];
                    _updateRoster(roster.copyWith(operatives: nextOps));
                    Navigator.of(ctx).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
