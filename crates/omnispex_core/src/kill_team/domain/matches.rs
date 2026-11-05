use crate::common::{FactionPerformance, MatchResult, MatchStatisticsReport};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// In Kill Team 2024 (3rd Edition), each player secretly selects one Primary Op
/// (Crit Op, Tac Op, or Kill Op) at the start of the battle and scores 50% (rounded up, max 3 VP)
/// of that Op's total score at the end of the battle.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum KtPrimaryOp {
    CritOp,
    TacOp,
    KillOp,
}

impl Default for KtPrimaryOp {
    fn default() -> Self {
        Self::CritOp
    }
}

impl KtPrimaryOp {
    pub fn label(&self) -> &'static str {
        match self {
            KtPrimaryOp::CritOp => "Crit Op",
            KtPrimaryOp::TacOp => "Tac Op",
            KtPrimaryOp::KillOp => "Kill Op",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct KtTurningPointScore {
    /// Turning Point 1 to 4
    pub turning_point: u32,
    pub player_crit_op: u32,
    pub player_tac_op: u32,
    pub player_kill_op: u32,
    pub opponent_crit_op: u32,
    pub opponent_tac_op: u32,
    pub opponent_kill_op: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KtMatchDetails {
    #[serde(default)]
    pub killzone: String,
    #[serde(default)]
    pub crit_op_name: String,
    #[serde(default)]
    pub player_tac_op_name: String,
    #[serde(default)]
    pub opponent_tac_op_name: String,
    #[serde(default)]
    pub player_primary_op: KtPrimaryOp,
    #[serde(default)]
    pub opponent_primary_op: KtPrimaryOp,
    /// 4 Turning Points
    #[serde(default)]
    pub turning_points: Vec<KtTurningPointScore>,
    #[serde(default)]
    pub player_painted_bonus: bool,
    #[serde(default)]
    pub opponent_painted_bonus: bool,
    #[serde(default)]
    pub player_crit_total: u32,
    #[serde(default)]
    pub player_tac_total: u32,
    #[serde(default)]
    pub player_kill_total: u32,
    #[serde(default)]
    pub player_primary_bonus: u32,
    #[serde(default)]
    pub opponent_crit_total: u32,
    #[serde(default)]
    pub opponent_tac_total: u32,
    #[serde(default)]
    pub opponent_kill_total: u32,
    #[serde(default)]
    pub opponent_primary_bonus: u32,
    #[serde(default)]
    pub player_total: u32,
    #[serde(default)]
    pub opponent_total: u32,
}

impl Default for KtMatchDetails {
    fn default() -> Self {
        Self {
            killzone: "Volkus".to_string(),
            crit_op_name: "Secure".to_string(),
            player_tac_op_name: "Confirm Kill".to_string(),
            opponent_tac_op_name: "Contain".to_string(),
            player_primary_op: KtPrimaryOp::CritOp,
            opponent_primary_op: KtPrimaryOp::CritOp,
            turning_points: (1..=4)
                .map(|tp| KtTurningPointScore {
                    turning_point: tp,
                    ..Default::default()
                })
                .collect(),
            player_painted_bonus: true,
            opponent_painted_bonus: true,
            player_crit_total: 0,
            player_tac_total: 0,
            player_kill_total: 0,
            player_primary_bonus: 0,
            opponent_crit_total: 0,
            opponent_tac_total: 0,
            opponent_kill_total: 0,
            opponent_primary_bonus: 0,
            player_total: 0,
            opponent_total: 0,
        }
    }
}

impl KtMatchDetails {
    /// Recalculates totals according to Kill Team 2024 (3rd Edition) Matched Play rules:
    /// - Crit Op capped at 6 VP (scored in TP 2–4, max 2 VP per TP)
    /// - Tac Op capped at 6 VP (scored in TP 2–4)
    /// - Kill Op capped at 6 VP
    /// - Primary Op bonus = ceil(selected_op_total / 2), capped at 3 VP
    /// - Painted bonus = +2 VP
    /// - Maximum total score = 21 VP
    pub fn recalculate_totals(&mut self) {
        self.player_crit_total = self
            .turning_points
            .iter()
            .map(|tp| tp.player_crit_op.min(2))
            .sum::<u32>()
            .min(6);
        self.player_tac_total = self
            .turning_points
            .iter()
            .map(|tp| tp.player_tac_op)
            .sum::<u32>()
            .min(6);
        self.player_kill_total = self
            .turning_points
            .iter()
            .map(|tp| tp.player_kill_op)
            .sum::<u32>()
            .min(6);

        let p_primary_base = match self.player_primary_op {
            KtPrimaryOp::CritOp => self.player_crit_total,
            KtPrimaryOp::TacOp => self.player_tac_total,
            KtPrimaryOp::KillOp => self.player_kill_total,
        };
        self.player_primary_bonus = p_primary_base.div_ceil(2).min(3);

        self.opponent_crit_total = self
            .turning_points
            .iter()
            .map(|tp| tp.opponent_crit_op.min(2))
            .sum::<u32>()
            .min(6);
        self.opponent_tac_total = self
            .turning_points
            .iter()
            .map(|tp| tp.opponent_tac_op)
            .sum::<u32>()
            .min(6);
        self.opponent_kill_total = self
            .turning_points
            .iter()
            .map(|tp| tp.opponent_kill_op)
            .sum::<u32>()
            .min(6);

        let o_primary_base = match self.opponent_primary_op {
            KtPrimaryOp::CritOp => self.opponent_crit_total,
            KtPrimaryOp::TacOp => self.opponent_tac_total,
            KtPrimaryOp::KillOp => self.opponent_kill_total,
        };
        self.opponent_primary_bonus = o_primary_base.div_ceil(2).min(3);

        let p_paint = if self.player_painted_bonus { 2 } else { 0 };
        let o_paint = if self.opponent_painted_bonus { 2 } else { 0 };

        self.player_total = (self.player_crit_total
            + self.player_tac_total
            + self.player_kill_total
            + self.player_primary_bonus
            + p_paint)
            .min(21);
        self.opponent_total = (self.opponent_crit_total
            + self.opponent_tac_total
            + self.opponent_kill_total
            + self.opponent_primary_bonus
            + o_paint)
            .min(21);
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KtMatchRecord {
    pub id: String,
    pub date_iso: String,
    pub player_kill_team: String,
    pub opponent_kill_team: String,
    #[serde(default)]
    pub opponent_name: String,
    pub player_score: u32,
    pub opponent_score: u32,
    #[serde(default)]
    pub result: MatchResult,
    #[serde(default)]
    pub is_detailed: bool,
    #[serde(default)]
    pub details: KtMatchDetails,
    #[serde(default)]
    pub notes: String,
    #[serde(default)]
    pub created_at_iso: String,
    #[serde(default)]
    pub updated_at_iso: String,
}

impl KtMatchRecord {
    pub fn sync_scores_and_result(&mut self) {
        if self.is_detailed {
            self.details.recalculate_totals();
            self.player_score = self.details.player_total;
            self.opponent_score = self.details.opponent_total;
        }
        if self.result != MatchResult::InProgress {
            self.result = MatchResult::from_scores(self.player_score, self.opponent_score);
        }
    }
}

pub fn filter_kt_matches(
    matches: &[KtMatchRecord],
    search_query: &str,
    player_team_filter: Option<&str>,
    result_filter: Option<MatchResult>,
) -> Vec<KtMatchRecord> {
    let q = search_query.trim().to_lowercase();
    let mut out: Vec<KtMatchRecord> = matches
        .iter()
        .filter(|m| {
            let pf_ok = player_team_filter.map_or(true, |pf| {
                pf.is_empty() || m.player_kill_team.eq_ignore_ascii_case(pf)
            });
            let res_ok = result_filter.map_or(true, |r| m.result == r);
            let q_ok = q.is_empty()
                || m.player_kill_team.to_lowercase().contains(&q)
                || m.opponent_kill_team.to_lowercase().contains(&q)
                || m.opponent_name.to_lowercase().contains(&q)
                || m.notes.to_lowercase().contains(&q);
            pf_ok && res_ok && q_ok
        })
        .cloned()
        .collect();

    out.sort_by(|a, b| b.date_iso.cmp(&a.date_iso));
    out
}

pub fn compute_kt_match_statistics(
    matches: &[KtMatchRecord],
    player_team_filter: Option<&str>,
) -> MatchStatisticsReport {
    let mut wins = 0u32;
    let mut losses = 0u32;
    let mut draws = 0u32;
    let mut in_progress = 0u32;
    let mut total_player_score = 0u64;
    let mut total_opp_score = 0u64;

    let mut pf_map: HashMap<String, (u32, u32, u32, u64, u64)> = HashMap::new();
    let mut of_map: HashMap<String, (u32, u32, u32, u64, u64)> = HashMap::new();

    for m in matches {
        if let Some(pf) = player_team_filter {
            if !pf.is_empty() && !m.player_kill_team.eq_ignore_ascii_case(pf) {
                continue;
            }
        }
        if m.result == MatchResult::InProgress {
            in_progress += 1;
            continue;
        }
        match m.result {
            MatchResult::Win => wins += 1,
            MatchResult::Loss => losses += 1,
            MatchResult::Draw => draws += 1,
            MatchResult::InProgress => unreachable!(),
        }
        total_player_score += m.player_score as u64;
        total_opp_score += m.opponent_score as u64;

        let p_entry = pf_map
            .entry(m.player_kill_team.clone())
            .or_insert((0, 0, 0, 0, 0));
        match m.result {
            MatchResult::Win => p_entry.0 += 1,
            MatchResult::Loss => p_entry.1 += 1,
            MatchResult::Draw => p_entry.2 += 1,
            MatchResult::InProgress => {}
        }
        p_entry.3 += m.player_score as u64;
        p_entry.4 += m.opponent_score as u64;

        let o_entry = of_map
            .entry(m.opponent_kill_team.clone())
            .or_insert((0, 0, 0, 0, 0));
        match m.result {
            MatchResult::Win => o_entry.0 += 1,
            MatchResult::Loss => o_entry.1 += 1,
            MatchResult::Draw => o_entry.2 += 1,
            MatchResult::InProgress => {}
        }
        o_entry.3 += m.player_score as u64;
        o_entry.4 += m.opponent_score as u64;
    }

    let completed = wins + losses + draws;
    let win_rate_percent = if completed > 0 {
        (wins as f64 / completed as f64) * 100.0
    } else {
        0.0
    };
    let average_player_score = if completed > 0 {
        total_player_score as f64 / completed as f64
    } else {
        0.0
    };
    let average_opponent_score = if completed > 0 {
        total_opp_score as f64 / completed as f64
    } else {
        0.0
    };

    let build_breakdown =
        |map: HashMap<String, (u32, u32, u32, u64, u64)>| -> Vec<FactionPerformance> {
            let mut list: Vec<FactionPerformance> = map
                .into_iter()
                .map(|(faction, (w, l, d, ps, os))| {
                    let gp = w + l + d;
                    FactionPerformance {
                        faction,
                        games_played: gp,
                        wins: w,
                        losses: l,
                        draws: d,
                        win_rate_percent: if gp > 0 {
                            (w as f64 / gp as f64) * 100.0
                        } else {
                            0.0
                        },
                        average_player_score: if gp > 0 { ps as f64 / gp as f64 } else { 0.0 },
                        average_opponent_score: if gp > 0 { os as f64 / gp as f64 } else { 0.0 },
                    }
                })
                .collect();
            list.sort_by(|a, b| {
                b.games_played
                    .cmp(&a.games_played)
                    .then_with(|| a.faction.cmp(&b.faction))
            });
            list
        };

    MatchStatisticsReport {
        total_completed_games: completed,
        in_progress_games: in_progress,
        wins,
        losses,
        draws,
        win_rate_percent,
        average_player_score,
        average_opponent_score,
        average_differential: average_player_score - average_opponent_score,
        by_player_faction: build_breakdown(pf_map),
        by_opponent_faction: build_breakdown(of_map),
        scope_explanation: format!(
            "Calculated across {} completed Kill Team match(es) ({} in-progress excluded).",
            completed, in_progress
        ),
    }
}
