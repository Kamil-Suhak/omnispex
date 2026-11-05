import 'package:flutter/material.dart';
import '../../../theme/omnispex_colors.dart';
import '../../../theme/omnispex_typography.dart';
import '../../../widgets/distribution_chart.dart';
import '../../../widgets/stat_strip.dart';
import '../../../widgets/verdict_banner.dart';
import '../models/kill_team_models.dart';
import '../services/kill_team_service.dart';

class KtCombatScreen extends StatefulWidget {
  const KtCombatScreen({super.key});

  @override
  State<KtCombatScreen> createState() => _KtCombatScreenState();
}

class _KtCombatScreenState extends State<KtCombatScreen> {
  bool _isFightMode = false;

  List<OperativeDatacardUi> _operatives = [];
  OperativeDatacardUi? _attacker;
  OperativeDatacardUi? _defender;
  KtWeaponProfileUi? _selectedWeapon;
  KtWeaponProfileUi? _defenderMeleeWeapon;

  // Shooting context toggles
  bool _targetInCover = false;
  bool _targetObscured = false;
  bool _attackerInjured = false;
  int _accurateBonus = 0;
  bool _balancedActive = false;
  bool _ceaselessActive = false;
  bool _relentlessActive = false;
  bool _severeActive = false;
  bool _punishingActive = false;
  bool _rendingActive = false;
  bool _saturateActive = false;

  // Fight context toggles
  bool _defenderInjured = false;
  int _attackerSupport = 0;
  int _defenderSupport = 0;

  KtShootingSimulationReportUi? _shootingReport;
  KtFightSimulationReportUi? _fightReport;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await KillTeamService.ensureCatalogueLoaded();
    final ops = KillTeamService.searchOperatives();
    if (ops.isNotEmpty) {
      _operatives = ops;
      _attacker = ops.first;
      _defender = ops.length > 1 ? ops[1] : ops.first;
      _syncDefaultWeapons();
      _recompute();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _syncDefaultWeapons() {
    if (_attacker != null) {
      if (_isFightMode) {
        final melee = _attacker!.meleeWeapons;
        _selectedWeapon = melee.isNotEmpty
            ? melee.first
            : (_attacker!.weapons.isNotEmpty ? _attacker!.weapons.first : null);
      } else {
        final ranged = _attacker!.rangedWeapons;
        _selectedWeapon = ranged.isNotEmpty
            ? ranged.first
            : (_attacker!.weapons.isNotEmpty ? _attacker!.weapons.first : null);
      }
    }
    if (_defender != null) {
      final defMelee = _defender!.meleeWeapons;
      _defenderMeleeWeapon = defMelee.isNotEmpty
          ? defMelee.first
          : (_defender!.weapons.isNotEmpty ? _defender!.weapons.first : null);
    }
  }

  void _recompute() {
    if (_attacker == null || _defender == null || _selectedWeapon == null) {
      return;
    }
    if (_isFightMode) {
      final defWeapon = _defenderMeleeWeapon ?? _selectedWeapon!;
      _fightReport = KillTeamService.runFightSimulation(
        attacker: _attacker!,
        attackerWeapon: _selectedWeapon!,
        defender: _defender!,
        defenderWeapon: defWeapon,
        context: KtFightContextUi(
          attackerInjured: _attackerInjured,
          defenderInjured: _defenderInjured,
          attackerSupportFriends: _attackerSupport,
          defenderSupportFriends: _defenderSupport,
        ),
        iterations: 5000,
      );
    } else {
      _shootingReport = KillTeamService.runShootingSimulation(
        weapon: _selectedWeapon!,
        target: _defender!,
        context: KtShootingContextUi(
          targetInCover: _targetInCover,
          targetObscured: _targetObscured,
          attackerInjured: _attackerInjured,
          accurateBonus: _accurateBonus,
          balancedActive: _balancedActive,
          ceaselessActive: _ceaselessActive,
          relentlessActive: _relentlessActive,
          severeActive: _severeActive,
          punishingActive: _punishingActive,
          rendingActive: _rendingActive,
          saturateActive: _saturateActive,
        ),
        iterations: 5000,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Text('KILL TEAM COMBAT RESOLUTION',
                      style: OmnispexTypography.h2),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('SHOOTING'),
                        icon: Icon(Icons.gps_fixed, size: 16),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('FIGHT (STRIKE / PARRY)'),
                        icon: Icon(Icons.sports_kabaddi, size: 16),
                      ),
                    ],
                    selected: {_isFightMode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _isFightMode = selection.first;
                        _syncDefaultWeapons();
                        _recompute();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildMatchupSelectors(),
              const SizedBox(height: 16),
              _isFightMode ? _buildFightModifiers() : _buildShootingModifiers(),
              const SizedBox(height: 24),
              if (!_isFightMode && _shootingReport != null)
                _buildShootingResults(_shootingReport!),
              if (_isFightMode && _fightReport != null)
                _buildFightResults(_fightReport!),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchupSelectors() {
    if (_operatives.isEmpty) {
      return const SizedBox.shrink();
    }
    final availableAttackerWeapons = _attacker?.weapons ?? const [];
    final availableDefenderMelee = _defender?.meleeWeapons.isNotEmpty == true
        ? _defender!.meleeWeapons
        : (_defender?.weapons ?? const []);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final attackerCard = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OmnispexColors.surfaceCard,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: OmnispexColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ATTACKING OPERATIVE', style: OmnispexTypography.label),
              const SizedBox(height: 8),
              DropdownButtonFormField<OperativeDatacardUi>(
                initialValue: _attacker,
                isExpanded: true,
                items: _operatives
                    .map(
                      (op) => DropdownMenuItem(
                        value: op,
                        child: Text(
                          '${op.factionName} — ${op.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (next) {
                  if (next == null) return;
                  setState(() {
                    _attacker = next;
                    _syncDefaultWeapons();
                    _recompute();
                  });
                },
              ),
              const SizedBox(height: 12),
              Text('WEAPON PROFILE', style: OmnispexTypography.label),
              const SizedBox(height: 8),
              DropdownButtonFormField<KtWeaponProfileUi>(
                initialValue: availableAttackerWeapons.contains(_selectedWeapon)
                    ? _selectedWeapon
                    : (availableAttackerWeapons.isNotEmpty
                        ? availableAttackerWeapons.first
                        : null),
                isExpanded: true,
                items: availableAttackerWeapons
                    .map(
                      (w) => DropdownMenuItem(
                        value: w,
                        child: Text(
                          '${w.name} (ATK ${w.attacks} • HIT ${w.hitStat}+ • DMG ${w.damageDisplay})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (next) {
                  if (next == null) return;
                  setState(() {
                    _selectedWeapon = next;
                    _recompute();
                  });
                },
              ),
              if (_selectedWeapon != null) ...[
                const SizedBox(height: 12),
                StatStripRow(
                  items: [
                    StatCellItem(
                        label: 'ATK', value: '${_selectedWeapon!.attacks}'),
                    StatCellItem(
                        label: 'HIT', value: '${_selectedWeapon!.hitStat}+'),
                    StatCellItem(
                        label: 'DMG (N/C)',
                        value: _selectedWeapon!.damageDisplay),
                    StatCellItem(
                        label: 'RULES', value: _selectedWeapon!.rulesSummary),
                  ],
                ),
              ],
            ],
          ),
        );

        final defenderCard = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OmnispexColors.surfaceCard,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: OmnispexColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TARGET OPERATIVE', style: OmnispexTypography.label),
              const SizedBox(height: 8),
              DropdownButtonFormField<OperativeDatacardUi>(
                initialValue: _defender,
                isExpanded: true,
                items: _operatives
                    .map(
                      (op) => DropdownMenuItem(
                        value: op,
                        child: Text(
                          '${op.factionName} — ${op.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (next) {
                  if (next == null) return;
                  setState(() {
                    _defender = next;
                    _syncDefaultWeapons();
                    _recompute();
                  });
                },
              ),
              if (_isFightMode && availableDefenderMelee.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('DEFENDER MELEE WEAPON', style: OmnispexTypography.label),
                const SizedBox(height: 8),
                DropdownButtonFormField<KtWeaponProfileUi>(
                  initialValue: availableDefenderMelee.contains(_defenderMeleeWeapon)
                      ? _defenderMeleeWeapon
                      : availableDefenderMelee.first,
                  isExpanded: true,
                  items: availableDefenderMelee
                      .map(
                        (w) => DropdownMenuItem(
                          value: w,
                          child: Text(
                            '${w.name} (ATK ${w.attacks} • HIT ${w.hitStat}+ • DMG ${w.damageDisplay})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (next) {
                    if (next == null) return;
                    setState(() {
                      _defenderMeleeWeapon = next;
                      _recompute();
                    });
                  },
                ),
              ],
              if (_defender != null) ...[
                const SizedBox(height: 12),
                StatStripRow(
                  items: [
                    StatCellItem(label: 'APL', value: '${_defender!.apl}'),
                    StatCellItem(label: 'MOVE', value: '${_defender!.movement}"'),
                    StatCellItem(label: 'SAVE', value: '${_defender!.save}+'),
                    StatCellItem(label: 'WOUNDS', value: '${_defender!.wounds}'),
                  ],
                ),
              ],
            ],
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: attackerCard),
              const SizedBox(width: 16),
              Expanded(child: defenderCard),
            ],
          );
        }
        return Column(
          children: [
            attackerCard,
            const SizedBox(height: 16),
            defenderCard,
          ],
        );
      },
    );
  }

  Widget _buildShootingModifiers() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FIREFIGHT MODIFIERS', style: OmnispexTypography.label),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Target in Cover'),
                selected: _targetInCover,
                onSelected: (v) => setState(() {
                  _targetInCover = v;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Target Obscured'),
                selected: _targetObscured,
                onSelected: (v) => setState(() {
                  _targetObscured = v;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Attacker Injured (-1 Hit)'),
                selected: _attackerInjured,
                onSelected: (v) => setState(() {
                  _attackerInjured = v;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Accurate 1'),
                selected: _accurateBonus == 1,
                onSelected: (v) => setState(() {
                  _accurateBonus = v ? 1 : 0;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Balanced'),
                selected: _balancedActive,
                onSelected: (v) => setState(() {
                  _balancedActive = v;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Ceaseless'),
                selected: _ceaselessActive,
                onSelected: (v) => setState(() {
                  _ceaselessActive = v;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Relentless'),
                selected: _relentlessActive,
                onSelected: (v) => setState(() {
                  _relentlessActive = v;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Severe'),
                selected: _severeActive,
                onSelected: (v) => setState(() {
                  _severeActive = v;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Punishing'),
                selected: _punishingActive,
                onSelected: (v) => setState(() {
                  _punishingActive = v;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Rending'),
                selected: _rendingActive,
                onSelected: (v) => setState(() {
                  _rendingActive = v;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Saturate'),
                selected: _saturateActive,
                onSelected: (v) => setState(() {
                  _saturateActive = v;
                  _recompute();
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFightModifiers() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MELEE DUEL MODIFIERS', style: OmnispexTypography.label),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Attacker Injured'),
                selected: _attackerInjured,
                onSelected: (v) => setState(() {
                  _attackerInjured = v;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Defender Injured'),
                selected: _defenderInjured,
                onSelected: (v) => setState(() {
                  _defenderInjured = v;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Attacker Combat Support (+1 Hit)'),
                selected: _attackerSupport > 0,
                onSelected: (v) => setState(() {
                  _attackerSupport = v ? 1 : 0;
                  _recompute();
                }),
              ),
              FilterChip(
                label: const Text('Defender Combat Support (+1 Hit)'),
                selected: _defenderSupport > 0,
                onSelected: (v) => setState(() {
                  _defenderSupport = v ? 1 : 0;
                  _recompute();
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShootingResults(KtShootingSimulationReportUi report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TacticalVerdictBanner(
          verdictKey: report.tacticalVerdict,
          primaryMetricLabel: 'INCAPACITATION PROBABILITY',
          primaryMetricValue:
              '${(report.killProbability * 100).toStringAsFixed(1)}%',
          secondaryMetricLabel: 'EXPECTED DAMAGE',
          secondaryMetricValue:
              '${report.expectedDamage.toStringAsFixed(2)} / ${report.targetWounds} W',
        ),
        const SizedBox(height: 16),
        StatStripRow(
          items: [
            StatCellItem(
              label: 'EXPECTED DAMAGE',
              value: report.expectedDamage.toStringAsFixed(2),
              valueColor: OmnispexColors.accent,
            ),
            StatCellItem(
              label: 'KILL PROBABILITY',
              value: '${(report.killProbability * 100).toStringAsFixed(1)}%',
              valueColor: OmnispexColors.greenKill,
            ),
            StatCellItem(
              label: 'INJURY PROBABILITY',
              value: '${(report.injuryProbability * 100).toStringAsFixed(1)}%',
              valueColor: OmnispexColors.yellowContest,
            ),
            StatCellItem(
              label: '80% FLOOR',
              value: '${report.safeBetDamage80} DMG',
            ),
            StatCellItem(
              label: 'RETAINED NORM / CRIT',
              value:
                  '${report.expectedNormalHits.toStringAsFixed(2)} / ${report.expectedCriticalHits.toStringAsFixed(2)}',
            ),
            StatCellItem(
              label: 'UNBLOCKED NORM / CRIT',
              value:
                  '${report.expectedUnblockedNormals.toStringAsFixed(2)} / ${report.expectedUnblockedCrits.toStringAsFixed(2)}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        ProbabilityDistributionChart(
          title: 'DAMAGE DISTRIBUTION (SOLVED OPTIMAL DEFENSE ALLOCATION)',
          distribution: report.damageDistribution,
          highlightThreshold: report.targetWounds,
        ),
      ],
    );
  }

  Widget _buildFightResults(KtFightSimulationReportUi report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TacticalVerdictBanner(
          verdictKey: report.tacticalVerdict,
          primaryMetricLabel: 'DEFENDER SLAIN',
          primaryMetricValue:
              '${(report.defenderKillProbability * 100).toStringAsFixed(1)}%',
          secondaryMetricLabel: 'CLEAN KILL (0 RETALIATION)',
          secondaryMetricValue:
              '${(report.cleanKillZeroRetaliationProbability * 100).toStringAsFixed(1)}%',
        ),
        const SizedBox(height: 16),
        StatStripRow(
          items: [
            StatCellItem(
              label: 'DMG TO DEFENDER',
              value: report.expectedDamageToDefender.toStringAsFixed(2),
              valueColor: OmnispexColors.greenKill,
            ),
            StatCellItem(
              label: 'DMG TO ATTACKER',
              value: report.expectedDamageToAttacker.toStringAsFixed(2),
              valueColor: OmnispexColors.redIneffective,
            ),
            StatCellItem(
              label: 'DEFENDER SLAIN',
              value:
                  '${(report.defenderKillProbability * 100).toStringAsFixed(1)}%',
            ),
            StatCellItem(
              label: 'ATTACKER SURVIVES',
              value:
                  '${(report.attackerSurvivesProbability * 100).toStringAsFixed(1)}%',
            ),
            StatCellItem(
              label: 'ZERO RETALIATION KILL',
              value:
                  '${(report.cleanKillZeroRetaliationProbability * 100).toStringAsFixed(1)}%',
              valueColor: OmnispexColors.accent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ProbabilityDistributionChart(
          title: 'DAMAGE INFLICTED ON DEFENDER (MINIMAX STRIKE / PARRY)',
          distribution: report.damageToDefenderDistribution,
          highlightThreshold: _defender?.wounds ?? 8,
        ),
      ],
    );
  }
}
