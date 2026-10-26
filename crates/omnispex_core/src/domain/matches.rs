use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum GameSystem {
    #[default]
    Warhammer40k,
    KillTeam,
}

impl GameSystem {
    pub fn label(&self) -> &'static str {
        match self {
            GameSystem::Warhammer40k => "Warhammer 40,000",
            GameSystem::KillTeam => "Kill Team",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum MatchResult {
    #[default]
    Win,
    Loss,
    Draw,
    InProgress,
}

impl MatchResult {
    pub fn from_scores(player_score: u32, opponent_score: u32) -> Self {
        if player_score > opponent_score {
            MatchResult::Win
        } else if player_score < opponent_score {
            MatchResult::Loss
        } else {
            MatchResult::Draw
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            MatchResult::Win => "Win",
            MatchResult::Loss => "Loss",
            MatchResult::Draw => "Draw",
            MatchResult::InProgress => "In Progress",
        }
    }

    pub fn is_completed(&self) -> bool {
        !matches!(self, MatchResult::InProgress)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct Wh40kRoundScore {
    pub round: u32,
    pub player_primary: u32,
    pub player_secondary: u32,
    pub opponent_primary: u32,
    pub opponent_secondary: u32,
    #[serde(default)]
    pub notes: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Wh40kMatchDetails {
    pub battle_size: String,
    pub points_limit: u32,
    #[serde(default)]
    pub mission_pack: String,
    #[serde(default)]
    pub primary_mission: String,
    #[serde(default)]
    pub deployment: String,
    #[serde(default)]
    pub player_detachment: String,
    #[serde(default)]
    pub opponent_detachment: String,
    #[serde(default)]
    pub army_list_id: Option<String>,
    #[serde(default)]
    pub army_list_name: Option<String>,
    #[serde(default)]
    pub player_secondaries: Vec<String>,
    #[serde(default)]
    pub opponent_secondaries: Vec<String>,
    #[serde(default)]
    pub rounds: Vec<Wh40kRoundScore>,
    #[serde(default)]
    pub player_battle_ready_bonus: bool,
    #[serde(default)]
    pub opponent_battle_ready_bonus: bool,
    #[serde(default)]
    pub player_went_first: Option<bool>,
}

impl Default for Wh40kMatchDetails {
    fn default() -> Self {
        Self {
            battle_size: "Strike Force".to_string(),
            points_limit: 2000,
            mission_pack: "Chapter Approved".to_string(),
            primary_mission: "Take and Hold".to_string(),
            deployment: "Hammer and Anvil".to_string(),
            player_detachment: String::new(),
            opponent_detachment: String::new(),
            army_list_id: None,
            army_list_name: None,
            player_secondaries: Vec::new(),
            opponent_secondaries: Vec::new(),
            rounds: (1..=5)
                .map(|r| Wh40kRoundScore {
                    round: r,
                    ..Default::default()
                })
                .collect(),
            player_battle_ready_bonus: true,
            opponent_battle_ready_bonus: true,
            player_went_first: None,
        }
    }
}

impl Wh40kMatchDetails {
    pub fn calculated_player_score(&self) -> u32 {
        let primary: u32 = self.rounds.iter().map(|r| r.player_primary).sum::<u32>().min(50);
        let secondary: u32 = self
            .rounds
            .iter()
            .map(|r| r.player_secondary)
            .sum::<u32>()
            .min(40);
        let bonus = if self.player_battle_ready_bonus { 10 } else { 0 };
        (primary + secondary + bonus).min(100)
    }

    pub fn calculated_opponent_score(&self) -> u32 {
        let primary: u32 = self
            .rounds
            .iter()
            .map(|r| r.opponent_primary)
            .sum::<u32>()
            .min(50);
        let secondary: u32 = self
            .rounds
            .iter()
            .map(|r| r.opponent_secondary)
            .sum::<u32>()
            .min(40);
        let bonus = if self.opponent_battle_ready_bonus { 10 } else { 0 };
        (primary + secondary + bonus).min(100)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct KillTeamTurningPointScore {
    pub turning_point: u32,
    pub player_crit_op: u32,
    pub player_tac_op: u32,
    pub player_kill_op: u32,
    pub opponent_crit_op: u32,
    pub opponent_tac_op: u32,
    pub opponent_kill_op: u32,
    #[serde(default)]
    pub notes: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KillTeamMatchDetails {
    #[serde(default)]
    pub killzone: String,
    #[serde(default)]
    pub crit_op_mission: String,
    #[serde(default)]
    pub player_tac_op_archetype: String,
    #[serde(default)]
    pub player_tac_op_name: String,
    #[serde(default)]
    pub opponent_tac_op_name: String,
    /// `"Crit Op"`, `"Tac Op"`, or `"Kill Op"`
    #[serde(default)]
    pub player_primary_op: String,
    #[serde(default)]
    pub opponent_primary_op: String,
    #[serde(default)]
    pub player_primary_op_bonus: u32,
    #[serde(default)]
    pub opponent_primary_op_bonus: u32,
    #[serde(default)]
    pub player_painted_bonus: bool,
    #[serde(default)]
    pub opponent_painted_bonus: bool,
    #[serde(default)]
    pub turning_points: Vec<KillTeamTurningPointScore>,
}

impl Default for KillTeamMatchDetails {
    fn default() -> Self {
        Self {
            killzone: "Killzone: Volkus".to_string(),
            crit_op_mission: "Secure".to_string(),
            player_tac_op_archetype: "Seek & Destroy".to_string(),
            player_tac_op_name: String::new(),
            opponent_tac_op_name: String::new(),
            player_primary_op: "Crit Op".to_string(),
            opponent_primary_op: "Crit Op".to_string(),
            player_primary_op_bonus: 0,
            opponent_primary_op_bonus: 0,
            player_painted_bonus: true,
            opponent_painted_bonus: true,
            turning_points: (1..=4)
                .map(|tp| KillTeamTurningPointScore {
                    turning_point: tp,
                    ..Default::default()
                })
                .collect(),
        }
    }
}

impl KillTeamMatchDetails {
    pub fn calculated_player_score(&self) -> u32 {
        let crit: u32 = self
            .turning_points
            .iter()
            .map(|tp| tp.player_crit_op)
            .sum::<u32>()
            .min(6);
        let tac: u32 = self
            .turning_points
            .iter()
            .map(|tp| tp.player_tac_op)
            .sum::<u32>()
            .min(6);
        let kill: u32 = self
            .turning_points
            .iter()
            .map(|tp| tp.player_kill_op)
            .sum::<u32>()
            .min(6);
        let primary_bonus = if self.player_primary_op_bonus > 0 {
            self.player_primary_op_bonus.min(3)
        } else {
            let base = match self.player_primary_op.as_str() {
                "Crit Op" => crit,
                "Tac Op" => tac,
                "Kill Op" => kill,
                _ => 0,
            };
            ((base as f64) / 2.0).ceil() as u32
        };
        let painted = if self.player_painted_bonus { 2 } else { 0 };
        crit + tac + kill + primary_bonus + painted
    }

    pub fn calculated_opponent_score(&self) -> u32 {
        let crit: u32 = self
            .turning_points
            .iter()
            .map(|tp| tp.opponent_crit_op)
            .sum::<u32>()
            .min(6);
        let tac: u32 = self
            .turning_points
            .iter()
            .map(|tp| tp.opponent_tac_op)
            .sum::<u32>()
            .min(6);
        let kill: u32 = self
            .turning_points
            .iter()
            .map(|tp| tp.opponent_kill_op)
            .sum::<u32>()
            .min(6);
        let primary_bonus = if self.opponent_primary_op_bonus > 0 {
            self.opponent_primary_op_bonus.min(3)
        } else {
            let base = match self.opponent_primary_op.as_str() {
                "Crit Op" => crit,
                "Tac Op" => tac,
                "Kill Op" => kill,
                _ => 0,
            };
            ((base as f64) / 2.0).ceil() as u32
        };
        let painted = if self.opponent_painted_bonus { 2 } else { 0 };
        crit + tac + kill + primary_bonus + painted
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MatchRecord {
    pub id: String,
    pub game_system: GameSystem,
    pub date_iso: String,
    pub player_faction: String,
    pub opponent_faction: String,
    #[serde(default)]
    pub opponent_name: String,
    pub player_score: u32,
    pub opponent_score: u32,
    pub result: MatchResult,
    #[serde(default)]
    pub is_detailed: bool,
    #[serde(default)]
    pub wh40k_details: Option<Wh40kMatchDetails>,
    #[serde(default)]
    pub kill_team_details: Option<KillTeamMatchDetails>,
    #[serde(default)]
    pub notes: String,
    pub created_at_iso: String,
    pub updated_at_iso: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FactionPerformance {
    pub faction: String,
    pub games_played: usize,
    pub wins: usize,
    pub losses: usize,
    pub draws: usize,
    pub win_rate_percent: f64,
    pub average_player_score: f64,
    pub average_opponent_score: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ScoreTrendPoint {
    pub match_id: String,
    pub date_iso: String,
    pub game_system: GameSystem,
    pub player_faction: String,
    pub opponent_faction: String,
    pub player_score: u32,
    pub opponent_score: u32,
    pub result: MatchResult,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct MatchStatisticsReport {
    pub scope_explanation: String,
    pub game_system_filter: Option<GameSystem>,
    pub total_completed_games: usize,
    pub incomplete_games_excluded: usize,
    pub wins: usize,
    pub losses: usize,
    pub draws: usize,
    pub win_rate_percent: f64,
    pub average_player_score: f64,
    pub average_opponent_score: f64,
    pub average_differential: f64,
    pub by_player_faction: Vec<FactionPerformance>,
    pub by_opponent_faction: Vec<FactionPerformance>,
    pub recent_results: Vec<MatchResult>,
    pub score_trends: Vec<ScoreTrendPoint>,
}

pub fn default_kill_team_factions() -> Vec<String> {
    vec![
        "Angels of Death".to_string(),
        "Plague Marines".to_string(),
        "Kommandos".to_string(),
        "Death Korps".to_string(),
        "Kasrkin".to_string(),
        "Tempestus Aquilons".to_string(),
        "Vespid Stingwings".to_string(),
        "Phobos Strike Team".to_string(),
        "Scout Squad".to_string(),
        "Nemesis Claw".to_string(),
        "Legionaries".to_string(),
        "Warpcoven".to_string(),
        "Blades of Khaine".to_string(),
        "Corsair Voidscarred".to_string(),
        "Hand of the Archon".to_string(),
        "Mandrakes".to_string(),
        "Pathfinders".to_string(),
        "Farstalker Kinband".to_string(),
        "Hierotek Circle".to_string(),
        "Hearthkyn Salvagers".to_string(),
        "Hernkyn Yaegirs".to_string(),
        "Brood Brothers".to_string(),
        "Wyrmblade".to_string(),
        "Hunter Clade".to_string(),
        "Inquisitorial Agents".to_string(),
        "Novitiates".to_string(),
        "Exaction Squad".to_string(),
        "Imperial Navy Breachers".to_string(),
        "Fellgor Ravagers".to_string(),
        "Blooded".to_string(),
        "Chaos Cult".to_string(),
        "Gellerpox Infected".to_string(),
        "Elucidian Starstriders".to_string(),
    ]
}

pub fn filter_matches(
    matches: &[MatchRecord],
    game_system: Option<GameSystem>,
    query: &str,
    faction_filter: Option<&str>,
    result_filter: Option<MatchResult>,
) -> Vec<MatchRecord> {
    let q = query.trim().to_lowercase();
    let mut filtered: Vec<MatchRecord> = matches
        .iter()
        .filter(|m| {
            if let Some(gs) = game_system {
                if m.game_system != gs {
                    return false;
                }
            }
            if let Some(rf) = result_filter {
                if m.result != rf {
                    return false;
                }
            }
            if let Some(ff) = faction_filter {
                let ff_clean = ff.trim();
                if !ff_clean.is_empty() && !ff_clean.eq_ignore_ascii_case("All Factions") {
                    if !m.player_faction.eq_ignore_ascii_case(ff_clean)
                        && !m.opponent_faction.eq_ignore_ascii_case(ff_clean)
                    {
                        return false;
                    }
                }
            }
            if !q.is_empty() {
                let matches_pf = m.player_faction.to_lowercase().contains(&q);
                let matches_of = m.opponent_faction.to_lowercase().contains(&q);
                let matches_opp = m.opponent_name.to_lowercase().contains(&q);
                let matches_notes = m.notes.to_lowercase().contains(&q);
                let matches_det = m
                    .wh40k_details
                    .as_ref()
                    .map(|d| {
                        d.player_detachment.to_lowercase().contains(&q)
                            || d.primary_mission.to_lowercase().contains(&q)
                            || d.army_list_name
                                .as_deref()
                                .unwrap_or("")
                                .to_lowercase()
                                .contains(&q)
                    })
                    .unwrap_or(false);
                let matches_kt = m
                    .kill_team_details
                    .as_ref()
                    .map(|d| {
                        d.killzone.to_lowercase().contains(&q)
                            || d.crit_op_mission.to_lowercase().contains(&q)
                    })
                    .unwrap_or(false);

                if !matches_pf
                    && !matches_of
                    && !matches_opp
                    && !matches_notes
                    && !matches_det
                    && !matches_kt
                {
                    return false;
                }
            }
            true
        })
        .cloned()
        .collect();

    // Sort newest first by date_iso, then updated_at_iso
    filtered.sort_by(|a, b| {
        b.date_iso
            .cmp(&a.date_iso)
            .then_with(|| b.updated_at_iso.cmp(&a.updated_at_iso))
    });

    filtered
}

pub fn compute_match_statistics(
    matches: &[MatchRecord],
    game_system_filter: Option<GameSystem>,
    player_faction_filter: Option<&str>,
) -> MatchStatisticsReport {
    let mut scoped_all: Vec<&MatchRecord> = matches
        .iter()
        .filter(|m| {
            if let Some(gs) = game_system_filter {
                if m.game_system != gs {
                    return false;
                }
            }
            if let Some(pf) = player_faction_filter {
                let pf_clean = pf.trim();
                if !pf_clean.is_empty()
                    && !pf_clean.eq_ignore_ascii_case("All Factions")
                    && !m.player_faction.eq_ignore_ascii_case(pf_clean)
                {
                    return false;
                }
            }
            true
        })
        .collect();

    // Sort chronologically (oldest to newest) for trend calculation
    scoped_all.sort_by(|a, b| {
        a.date_iso
            .cmp(&b.date_iso)
            .then_with(|| a.created_at_iso.cmp(&b.created_at_iso))
    });

    let incomplete_games_excluded = scoped_all
        .iter()
        .filter(|m| !m.result.is_completed())
        .count();

    let completed: Vec<&MatchRecord> = scoped_all
        .into_iter()
        .filter(|m| m.result.is_completed())
        .collect();

    let total_completed_games = completed.len();
    let wins = completed
        .iter()
        .filter(|m| m.result == MatchResult::Win)
        .count();
    let losses = completed
        .iter()
        .filter(|m| m.result == MatchResult::Loss)
        .count();
    let draws = completed
        .iter()
        .filter(|m| m.result == MatchResult::Draw)
        .count();

    let win_rate_percent = if total_completed_games > 0 {
        (wins as f64 / total_completed_games as f64) * 100.0
    } else {
        0.0
    };

    let (average_player_score, average_opponent_score, average_differential) =
        if total_completed_games > 0 {
            let n = total_completed_games as f64;
            let sum_p: f64 = completed.iter().map(|m| m.player_score as f64).sum();
            let sum_o: f64 = completed.iter().map(|m| m.opponent_score as f64).sum();
            let avg_p = sum_p / n;
            let avg_o = sum_o / n;
            (avg_p, avg_o, avg_p - avg_o)
        } else {
            (0.0, 0.0, 0.0)
        };

    let by_player_faction = aggregate_faction_performance(&completed, |m| &m.player_faction);
    let by_opponent_faction = aggregate_faction_performance(&completed, |m| &m.opponent_faction);

    let recent_results: Vec<MatchResult> = completed
        .iter()
        .rev()
        .take(10)
        .map(|m| m.result)
        .collect();

    let score_trends: Vec<ScoreTrendPoint> = completed
        .iter()
        .map(|m| ScoreTrendPoint {
            match_id: m.id.clone(),
            date_iso: m.date_iso.clone(),
            game_system: m.game_system,
            player_faction: m.player_faction.clone(),
            opponent_faction: m.opponent_faction.clone(),
            player_score: m.player_score,
            opponent_score: m.opponent_score,
            result: m.result,
        })
        .collect();

    let sys_label = match game_system_filter {
        Some(gs) => gs.label().to_string(),
        None => "All Game Systems (40K + Kill Team — score averages are most meaningful when filtered to a single game system)".to_string(),
    };
    let scope_explanation = if incomplete_games_excluded > 0 {
        format!(
            "Scope: {} ({} completed matches; {} in-progress matches excluded).",
            sys_label, total_completed_games, incomplete_games_excluded
        )
    } else {
        format!(
            "Scope: {} ({} completed matches).",
            sys_label, total_completed_games
        )
    };

    MatchStatisticsReport {
        scope_explanation,
        game_system_filter,
        total_completed_games,
        incomplete_games_excluded,
        wins,
        losses,
        draws,
        win_rate_percent,
        average_player_score,
        average_opponent_score,
        average_differential,
        by_player_faction,
        by_opponent_faction,
        recent_results,
        score_trends,
    }
}

fn aggregate_faction_performance<'a, F>(
    completed: &[&'a MatchRecord],
    extractor: F,
) -> Vec<FactionPerformance>
where
    F: Fn(&'a MatchRecord) -> &'a String,
{
    let mut groups: BTreeMap<String, Vec<&'a MatchRecord>> = BTreeMap::new();
    for m in completed {
        let key = extractor(m).trim().to_string();
        if !key.is_empty() {
            groups.entry(key).or_default().push(*m);
        }
    }

    let mut out: Vec<FactionPerformance> = groups
        .into_iter()
        .map(|(faction, list)| {
            let games_played = list.len();
            let wins = list.iter().filter(|m| m.result == MatchResult::Win).count();
            let losses = list
                .iter()
                .filter(|m| m.result == MatchResult::Loss)
                .count();
            let draws = list
                .iter()
                .filter(|m| m.result == MatchResult::Draw)
                .count();
            let n = games_played as f64;
            let win_rate_percent = (wins as f64 / n) * 100.0;
            let average_player_score = list.iter().map(|m| m.player_score as f64).sum::<f64>() / n;
            let average_opponent_score =
                list.iter().map(|m| m.opponent_score as f64).sum::<f64>() / n;

            FactionPerformance {
                faction,
                games_played,
                wins,
                losses,
                draws,
                win_rate_percent,
                average_player_score,
                average_opponent_score,
            }
        })
        .collect();

    out.sort_by(|a, b| {
        b.games_played
            .cmp(&a.games_played)
            .then_with(|| b.wins.cmp(&a.wins))
    });
    out
}

