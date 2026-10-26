import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/omnispex_models.dart';
import '../providers/app_state_provider.dart';
import '../services/personal_data_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/scannable_metric_card.dart';
import '../widgets/stat_badge.dart';
import '../widgets/tactical_card.dart';

final matchGameSystemFilterProvider =
    StateProvider<GameSystemUi?>((ref) => null);
final matchResultFilterProvider = StateProvider<MatchResultUi?>((ref) => null);
final matchSearchQueryProvider = StateProvider<String>((ref) => '');

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(personalStoreProvider);
    final systemFilter = ref.watch(matchGameSystemFilterProvider);
    final resultFilter = ref.watch(matchResultFilterProvider);
    final query = ref.watch(matchSearchQueryProvider);

    final dashboard = PersonalDataService.evaluateMatches(
      matches: store.matches,
      gameSystem: systemFilter,
      query: query,
      resultFilter: resultFilter,
    );

    final stats = dashboard.statistics;
    final matches = dashboard.filteredMatches;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
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
                      Text('MATCH HISTORY & PERFORMANCE ANALYTICS',
                          style: OmnispexTypography.h2),
                      Text(
                        'Warhammer 40,000 (5 Battle Rounds) & Kill Team (4 Turning Points) Tracker',
                        style: OmnispexTypography.bodyMuted,
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_chart, size: 15),
                        label: Text(
                          'LOG 40K MATCH',
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
                        onPressed: () => _showLogMatchDialog(
                          context,
                          ref,
                          initialSystem: GameSystemUi.warhammer40k,
                          ktFactions: dashboard.killTeamFactions,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.gps_fixed, size: 15),
                        label: Text(
                          'LOG KILL TEAM MATCH',
                          style: OmnispexTypography.monoStatBadge.copyWith(
                            fontSize: 11,
                            color: OmnispexColors.background,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OmnispexColors.amber,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _showLogMatchDialog(
                          context,
                          ref,
                          initialSystem: GameSystemUi.killTeam,
                          ktFactions: dashboard.killTeamFactions,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Statistics Summary Metrics
              Row(
                children: [
                  Expanded(
                    child: ScannableMetricCard(
                      label: 'Win Rate',
                      value: '${stats.winRatePercent.toStringAsFixed(1)}%',
                      subtitle:
                          '${stats.wins}W - ${stats.losses}L - ${stats.draws}D (${stats.totalCompletedGames} games)',
                      accentColor: stats.winRatePercent >= 50
                          ? OmnispexColors.greenKill
                          : OmnispexColors.amber,
                      icon: Icons.emoji_events_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ScannableMetricCard(
                      label: 'Average Score',
                      value:
                          '${stats.averagePlayerScore.toStringAsFixed(1)} vs ${stats.averageOpponentScore.toStringAsFixed(1)}',
                      subtitle:
                          'Avg Diff: ${stats.averageDifferential >= 0 ? "+" : ""}${stats.averageDifferential.toStringAsFixed(1)} VP',
                      accentColor: OmnispexColors.cyan,
                      icon: Icons.analytics_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ScannableMetricCard(
                      label: 'Recent Form',
                      value: stats.recentResults.isEmpty
                          ? 'NO GAMES'
                          : stats.recentResults
                              .take(5)
                              .map((r) => r == MatchResultUi.win
                                  ? 'W'
                                  : (r == MatchResultUi.loss ? 'L' : 'D'))
                              .join(' • '),
                      subtitle: stats.scopeExplanation.isNotEmpty
                          ? stats.scopeExplanation
                          : 'Completed matches only',
                      accentColor: OmnispexColors.purple,
                      icon: Icons.timeline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Faction Performance Breakdown (if available)
              if (stats.byPlayerFaction.isNotEmpty ||
                  stats.byOpponentFaction.isNotEmpty)
                TacticalCard(
                  title: 'FACTION WIN-RATE BREAKDOWN',
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      ...stats.byPlayerFaction.map((fp) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: OmnispexColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: OmnispexColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PLAYED: ${fp.faction.toUpperCase()}',
                                style: OmnispexTypography.label.copyWith(
                                  fontSize: 10,
                                  color: OmnispexColors.cyan,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${fp.winRatePercent.toStringAsFixed(0)}% Win (${fp.wins}W-${fp.losses}L-${fp.draws}D)',
                                style: OmnispexTypography.monoData
                                    .copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }),
                      ...stats.byOpponentFaction.map((fp) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: OmnispexColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: OmnispexColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VS OPPONENT: ${fp.faction.toUpperCase()}',
                                style: OmnispexTypography.label.copyWith(
                                  fontSize: 10,
                                  color: OmnispexColors.amber,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${fp.winRatePercent.toStringAsFixed(0)}% Win (${fp.wins}W-${fp.losses}L-${fp.draws}D)',
                                style: OmnispexTypography.monoData
                                    .copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

              // Search & Filter Controls
              TacticalCard(
                title: 'FILTER MATCH LOG',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      style: OmnispexTypography.monoData.copyWith(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText:
                            'Search by faction, opponent name, mission, detachment, or notes...',
                        prefixIcon: Icon(Icons.search,
                            size: 16, color: OmnispexColors.cyan),
                        isDense: true,
                      ),
                      onChanged: (val) => ref
                          .read(matchSearchQueryProvider.notifier)
                          .state = val,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(
                            'All Systems',
                            style: OmnispexTypography.monoStatBadge
                                .copyWith(fontSize: 10),
                          ),
                          selected: systemFilter == null,
                          selectedColor: OmnispexColors.cyan.withOpacity(0.25),
                          backgroundColor: OmnispexColors.surfaceElevated,
                          onSelected: (_) => ref
                              .read(matchGameSystemFilterProvider.notifier)
                              .state = null,
                        ),
                        ...GameSystemUi.values.map((sys) {
                          final sel = systemFilter == sys;
                          return ChoiceChip(
                            label: Text(
                              sys.label,
                              style: OmnispexTypography.monoStatBadge
                                  .copyWith(fontSize: 10),
                            ),
                            selected: sel,
                            selectedColor:
                                OmnispexColors.cyan.withOpacity(0.25),
                            backgroundColor: OmnispexColors.surfaceElevated,
                            onSelected: (_) => ref
                                .read(matchGameSystemFilterProvider.notifier)
                                .state = sel ? null : sys,
                          );
                        }),
                        const SizedBox(width: 8),
                        ...MatchResultUi.values.map((res) {
                          final sel = resultFilter == res;
                          return ChoiceChip(
                            label: Text(
                              res.label,
                              style: OmnispexTypography.monoStatBadge
                                  .copyWith(fontSize: 10),
                            ),
                            selected: sel,
                            selectedColor:
                                OmnispexColors.amber.withOpacity(0.25),
                            backgroundColor: OmnispexColors.surfaceElevated,
                            onSelected: (_) => ref
                                .read(matchResultFilterProvider.notifier)
                                .state = sel ? null : res,
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Chronological Match History Feed
              if (matches.isEmpty)
                TacticalCard(
                  title: 'NO MATCHES RECORDED',
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No matches match the current filters. Log a Warhammer 40,000 or Kill Team game above.',
                        style: OmnispexTypography.bodyMuted,
                      ),
                    ),
                  ),
                )
              else
                ...matches.map((m) => _buildMatchCard(
                    context, ref, m, dashboard.killTeamFactions)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    WidgetRef ref,
    MatchRecordUi match,
    List<String> ktFactions,
  ) {
    final resultColor = switch (match.result) {
      MatchResultUi.win => OmnispexColors.greenKill,
      MatchResultUi.loss => OmnispexColors.redIneffective,
      MatchResultUi.draw => OmnispexColors.amber,
      MatchResultUi.inProgress => OmnispexColors.cyan,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: resultColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: resultColor),
                    ),
                    child: Text(
                      match.result.label.toUpperCase(),
                      style: OmnispexTypography.monoStatBadge.copyWith(
                        fontSize: 11,
                        color: resultColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatBadge(
                    label: 'SYSTEM',
                    value: match.gameSystem.label.toUpperCase(),
                    accentColor: match.gameSystem == GameSystemUi.warhammer40k
                        ? OmnispexColors.cyan
                        : OmnispexColors.amber,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    match.dateIso,
                    style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${match.playerScore} - ${match.opponentScore} VP',
                    style: OmnispexTypography.monoData.copyWith(
                      fontSize: 16,
                      color: resultColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: OmnispexColors.redIneffective),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref
                          .read(personalStoreProvider.notifier)
                          .deleteMatch(match.id);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${match.playerFaction} vs ${match.opponentFaction}${match.opponentName.isNotEmpty ? " (${match.opponentName})" : ""}',
            style: OmnispexTypography.h3.copyWith(fontSize: 15),
          ),
          if (match.wh40kDetails != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                StatBadge(
                    label: 'SIZE', value: match.wh40kDetails!.battleSize),
                if (match.wh40kDetails!.primaryMission.isNotEmpty)
                  StatBadge(
                      label: 'MISSION',
                      value: match.wh40kDetails!.primaryMission),
                if (match.wh40kDetails!.playerDetachment.isNotEmpty)
                  StatBadge(
                      label: 'DETACHMENT',
                      value: match.wh40kDetails!.playerDetachment),
              ],
            ),
          ],
          if (match.killTeamDetails != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                StatBadge(
                    label: 'KILLZONE', value: match.killTeamDetails!.killzone),
                StatBadge(
                    label: 'CRIT OP',
                    value: match.killTeamDetails!.critOpMission),
                StatBadge(
                    label: 'PRIMARY OP',
                    value: match.killTeamDetails!.playerPrimaryOp),
              ],
            ),
          ],
          if (match.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              match.notes,
              style: OmnispexTypography.bodyMuted.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  void _showLogMatchDialog(
    BuildContext context,
    WidgetRef ref, {
    required GameSystemUi initialSystem,
    required List<String> ktFactions,
  }) {
    GameSystemUi system = initialSystem;
    bool isDetailed = true;
    final dateCtrl = TextEditingController(
        text: DateTime.now().toIso8601String().split('T').first);
    final playerFactionCtrl = TextEditingController(
      text: initialSystem == GameSystemUi.warhammer40k
          ? 'Space Marines'
          : 'Angels of Death',
    );
    final oppFactionCtrl = TextEditingController(
      text: initialSystem == GameSystemUi.warhammer40k ? 'Necrons' : 'Kommandos',
    );
    final oppNameCtrl = TextEditingController();
    final quickPlayerScoreCtrl = TextEditingController(
      text: initialSystem == GameSystemUi.warhammer40k ? '80' : '18',
    );
    final quickOppScoreCtrl = TextEditingController(
      text: initialSystem == GameSystemUi.warhammer40k ? '70' : '14',
    );
    final missionCtrl = TextEditingController(
      text: initialSystem == GameSystemUi.warhammer40k
          ? 'Take and Hold'
          : 'Secure',
    );
    final notesCtrl = TextEditingController();

    final rounds40k = List.generate(
      5,
      (i) => Wh40kRoundScoreUi(
        round: i + 1,
        playerPrimary: i == 0 ? 0 : 10,
        playerSecondary: 5,
        opponentPrimary: i == 0 ? 0 : 10,
        opponentSecondary: 4,
      ),
    );
    final turningPointsKt = List.generate(
      4,
      (i) => KillTeamTurningPointScoreUi(
        turningPoint: i + 1,
        playerCritOp: 1,
        playerTacOp: 1,
        playerKillOp: 1,
        opponentCritOp: 1,
        opponentTacOp: 1,
        opponentKillOp: 1,
      ),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final details40k = Wh40kMatchDetailsUi(
              primaryMission: missionCtrl.text,
              rounds: rounds40k,
            );
            final detailsKt = KillTeamMatchDetailsUi(
              critOpMission: missionCtrl.text,
              turningPoints: turningPointsKt,
            );

            final calcPlayer = isDetailed
                ? (system == GameSystemUi.warhammer40k
                    ? details40k.calculatedPlayerScore
                    : detailsKt.calculatedPlayerScore)
                : (int.tryParse(quickPlayerScoreCtrl.text) ?? 0);
            final calcOpp = isDetailed
                ? (system == GameSystemUi.warhammer40k
                    ? details40k.calculatedOpponentScore
                    : detailsKt.calculatedOpponentScore)
                : (int.tryParse(quickOppScoreCtrl.text) ?? 0);

            return AlertDialog(
              backgroundColor: OmnispexColors.surfaceCard,
              title: Text(
                'LOG ${system.label.toUpperCase()} MATCH',
                style: OmnispexTypography.h3,
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SegmentedButton<GameSystemUi>(
                              segments: const [
                                ButtonSegment(
                                  value: GameSystemUi.warhammer40k,
                                  label: Text('Warhammer 40K'),
                                ),
                                ButtonSegment(
                                  value: GameSystemUi.killTeam,
                                  label: Text('Kill Team'),
                                ),
                              ],
                              selected: {system},
                              onSelectionChanged: (set) {
                                setState(() {
                                  system = set.first;
                                  if (system == GameSystemUi.killTeam) {
                                    playerFactionCtrl.text = 'Angels of Death';
                                    oppFactionCtrl.text = 'Kommandos';
                                  } else {
                                    playerFactionCtrl.text = 'Space Marines';
                                    oppFactionCtrl.text = 'Necrons';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          system == GameSystemUi.warhammer40k
                              ? 'Detailed 5-Battle-Round Scoring'
                              : 'Detailed 4-Turning-Point Scoring',
                          style: OmnispexTypography.body,
                        ),
                        value: isDetailed,
                        activeColor: OmnispexColors.cyan,
                        onChanged: (val) => setState(() => isDetailed = val),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: playerFactionCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'YOUR FACTION / KILL TEAM'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: oppFactionCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'OPPONENT FACTION / KILL TEAM'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: oppNameCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'OPPONENT NAME'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: missionCtrl,
                              decoration: InputDecoration(
                                labelText: system == GameSystemUi.warhammer40k
                                    ? 'PRIMARY MISSION'
                                    : 'CRIT OP / KILLZONE',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: dateCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'DATE'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!isDetailed)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: quickPlayerScoreCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'YOUR FINAL VP'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: quickOppScoreCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'OPPONENT FINAL VP'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        )
                      else if (system == GameSystemUi.warhammer40k) ...[
                        Text(
                          'BATTLE ROUNDS 1–5 (PRIMARY + SECONDARY VP, +10 BATTLE READY):',
                          style: OmnispexTypography.label.copyWith(fontSize: 10),
                        ),
                        const SizedBox(height: 6),
                        ...List.generate(5, (idx) {
                          final r = rounds40k[idx];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text('Round ${r.round}',
                                      style: OmnispexTypography.monoData
                                          .copyWith(fontSize: 11)),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: '${r.playerPrimary}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'You Pri', isDense: true),
                                    onChanged: (v) => setState(() {
                                      rounds40k[idx] = r.copyWith(
                                          playerPrimary: int.tryParse(v) ?? 0);
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: '${r.playerSecondary}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'You Sec', isDense: true),
                                    onChanged: (v) => setState(() {
                                      rounds40k[idx] = r.copyWith(
                                          playerSecondary:
                                              int.tryParse(v) ?? 0);
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: '${r.opponentPrimary}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Opp Pri', isDense: true),
                                    onChanged: (v) => setState(() {
                                      rounds40k[idx] = r.copyWith(
                                          opponentPrimary:
                                              int.tryParse(v) ?? 0);
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: '${r.opponentSecondary}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Opp Sec', isDense: true),
                                    onChanged: (v) => setState(() {
                                      rounds40k[idx] = r.copyWith(
                                          opponentSecondary:
                                              int.tryParse(v) ?? 0);
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ] else ...[
                        Text(
                          'TURNING POINTS 1–4 (CRIT OP / TAC OP / KILL OP + PRIMARY BONUS + PAINTED):',
                          style: OmnispexTypography.label.copyWith(fontSize: 10),
                        ),
                        const SizedBox(height: 6),
                        ...List.generate(4, (idx) {
                          final tp = turningPointsKt[idx];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  child: Text('TP ${tp.turningPoint}',
                                      style: OmnispexTypography.monoData
                                          .copyWith(fontSize: 11)),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: '${tp.playerCritOp}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'You Crit', isDense: true),
                                    onChanged: (v) => setState(() {
                                      turningPointsKt[idx] = tp.copyWith(
                                          playerCritOp: int.tryParse(v) ?? 0);
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: '${tp.playerTacOp}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'You Tac', isDense: true),
                                    onChanged: (v) => setState(() {
                                      turningPointsKt[idx] = tp.copyWith(
                                          playerTacOp: int.tryParse(v) ?? 0);
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: '${tp.playerKillOp}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'You Kill', isDense: true),
                                    onChanged: (v) => setState(() {
                                      turningPointsKt[idx] = tp.copyWith(
                                          playerKillOp: int.tryParse(v) ?? 0);
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: '${tp.opponentCritOp}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Opp Crit', isDense: true),
                                    onChanged: (v) => setState(() {
                                      turningPointsKt[idx] = tp.copyWith(
                                          opponentCritOp:
                                              int.tryParse(v) ?? 0);
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: OmnispexColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: OmnispexColors.cyan),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('CALCULATED FINAL SCORE:',
                                style: OmnispexTypography.label),
                            Text(
                              '$calcPlayer VP vs $calcOpp VP',
                              style: OmnispexTypography.monoData
                                  .copyWith(color: OmnispexColors.cyan),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                            labelText: 'MATCH NOTES / KEY MOMENTS'),
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
                    final result = calcPlayer > calcOpp
                        ? MatchResultUi.win
                        : (calcPlayer < calcOpp
                            ? MatchResultUi.loss
                            : MatchResultUi.draw);
                    final record = MatchRecordUi(
                      id: 'match-${DateTime.now().microsecondsSinceEpoch}',
                      gameSystem: system,
                      dateIso: dateCtrl.text.trim().isEmpty
                          ? now.split('T').first
                          : dateCtrl.text.trim(),
                      playerFaction: playerFactionCtrl.text.trim(),
                      opponentFaction: oppFactionCtrl.text.trim(),
                      opponentName: oppNameCtrl.text.trim(),
                      playerScore: calcPlayer,
                      opponentScore: calcOpp,
                      result: result,
                      isDetailed: isDetailed,
                      wh40kDetails:
                          system == GameSystemUi.warhammer40k ? details40k : null,
                      killTeamDetails:
                          system == GameSystemUi.killTeam ? detailsKt : null,
                      notes: notesCtrl.text.trim(),
                      createdAtIso: now,
                      updatedAtIso: now,
                    );
                    ref
                        .read(personalStoreProvider.notifier)
                        .upsertMatch(record);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('SAVE MATCH'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
