import 'package:flutter/material.dart';
import '../../../theme/omnispex_colors.dart';
import '../../../theme/omnispex_typography.dart';
import '../../../widgets/stat_strip.dart';
import '../models/kill_team_models.dart';
import '../services/kill_team_service.dart';

class KtOperativeBrowserScreen extends StatefulWidget {
  const KtOperativeBrowserScreen({super.key});

  @override
  State<KtOperativeBrowserScreen> createState() =>
      _KtOperativeBrowserScreenState();
}

class _KtOperativeBrowserScreenState extends State<KtOperativeBrowserScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFaction = 'All Kill Teams';
  String _selectedRole = 'All Roles';
  List<String> _factionOptions = ['All Kill Teams'];
  List<OperativeDatacardUi> _operatives = [];
  OperativeDatacardUi? _selectedOperative;

  @override
  void initState() {
    super.initState();
    _loadCatalogue();
  }

  Future<void> _loadCatalogue() async {
    await KillTeamService.ensureCatalogueLoaded();
    final names = KillTeamService.getFactionNames();
    _factionOptions = ['All Kill Teams', ...names];
    _runSearch();
    if (mounted) {
      setState(() {});
    }
  }

  void _runSearch() {
    _operatives = KillTeamService.searchOperatives(
      query: _searchController.text,
      factionFilter: _selectedFaction,
      roleFilter: _selectedRole,
    );
    if (_operatives.isNotEmpty &&
        (_selectedOperative == null ||
            !_operatives.any((o) => o.id == _selectedOperative!.id))) {
      _selectedOperative = _operatives.first;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('KILL TEAM OPERATIVE DATACARDS', style: OmnispexTypography.h2),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search operative, weapon, or keyword...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(_runSearch),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedFaction,
                  isExpanded: true,
                  items: _factionOptions
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedFaction = val;
                      _runSearch();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  isExpanded: true,
                  items: const ['All Roles', 'Leader', 'Specialist', 'Warrior']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedRole = val;
                      _runSearch();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: OmnispexColors.surfaceCard,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: OmnispexColors.border),
                    ),
                    child: ListView.builder(
                      itemCount: _operatives.length,
                      itemBuilder: (context, index) {
                        final op = _operatives[index];
                        final isSelected = _selectedOperative?.id == op.id;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: OmnispexColors.surfaceElevated,
                          title: Text(op.name, style: OmnispexTypography.body),
                          subtitle: Text(
                            '${op.factionName}  •  ${op.role}  •  APL ${op.apl}  •  ${op.wounds}W',
                            style: OmnispexTypography.bodyMuted,
                          ),
                          onTap: () => setState(() => _selectedOperative = op),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _selectedOperative == null
                      ? const SizedBox.shrink()
                      : _buildDatacardDetail(_selectedOperative!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatacardDetail(OperativeDatacardUi op) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: ListView(
        children: [
          Text(op.name.toUpperCase(), style: OmnispexTypography.h2),
          const SizedBox(height: 4),
          Text(
            '${op.factionName}  •  ${op.role}  •  Max ${op.maxPerKillTeam} per Kill Team',
            style: OmnispexTypography.bodyMuted,
          ),
          const SizedBox(height: 16),
          StatStripRow(
            items: [
              StatCellItem(label: 'APL', value: '${op.apl}'),
              StatCellItem(label: 'MOVE', value: '${op.movement}"'),
              StatCellItem(label: 'SAVE', value: '${op.save}+'),
              StatCellItem(label: 'WOUNDS', value: '${op.wounds}'),
            ],
          ),
          const SizedBox(height: 20),
          Text('WEAPON PROFILES', style: OmnispexTypography.label),
          const SizedBox(height: 8),
          ...op.weapons.map(
            (w) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OmnispexColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: OmnispexColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(w.name, style: OmnispexTypography.h3),
                      Text(
                        'ATK ${w.attacks}  •  HIT ${w.hitStat}+  •  DMG ${w.damageDisplay}',
                        style: OmnispexTypography.monoData,
                      ),
                    ],
                  ),
                  if (w.rules.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      w.rulesSummary,
                      style: OmnispexTypography.bodyMuted.copyWith(
                        color: OmnispexColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (op.abilities.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('OPERATIVE ABILITIES & UNIQUE ACTIONS',
                style: OmnispexTypography.label),
            const SizedBox(height: 8),
            ...op.abilities.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  a.apCost != null
                      ? '${a.name} (${a.apCost} AP): ${a.description}'
                      : '${a.name}: ${a.description}',
                  style: OmnispexTypography.body,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'KEYWORDS: ${op.keywords.join(" • ")}',
            style: OmnispexTypography.label.copyWith(
              color: OmnispexColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
