pub mod seed;

pub use crate::domain::archetypes::{ArchetypeEntry, ArchetypeRoster};
pub use crate::domain::army_list::{
    export_army_list_text, validate_army_list, ArmyList, BattleSize, ListValidationReport,
    RosterUnitEntry, SelectedDetachment, SelectedWargearOption, ValidationIssue,
    ValidationSeverity,
};
pub use crate::domain::catalogue::{
    CatalogueDatabase, DataProvenance, DetachmentData, EnhancementData, FactionCatalogue,
    PricingTier, RuleEntry, UnitCostOption, WargearCostOption,
};
pub use crate::domain::dice::ValueExpr;
pub use crate::domain::matches::{Wh40kMatchDetails, Wh40kRoundScore};
pub use crate::domain::unit::{DefensiveAbility, ModelGroup, ModelProfile, UnitProfile};
pub use crate::domain::weapon::{
    parse_weapon_ability, Keyword, ReRollMode, WeaponAbility, WeaponLoadoutEntry, WeaponProfile,
};
pub use crate::domain::wishlist::{
    compute_wishlist_summary, filter_and_sort_wishlist, upsert_wishlist_item, WishlistItem,
    WishlistSummary,
};
pub use crate::engine::{
    compare_profiles, compute_exact_stage_probabilities, evaluate_archetypes,
    find_allocated_model_index, required_wound_roll, resolve_squad_volley, resolve_volley,
    resolve_volley_with_blast_count, run_simulation, run_squad_simulation,
    ArchetypeBenchmarkEntry, ArchetypeBenchmarkReport, CombatContext, KeywordAudit,
    PercentilesReport, ProfileComparisonEntry, ProfileComparisonReport, SimulationReport,
    StageProbabilities, TacticalVerdict, VolleyOutcome, WoundKind, WoundSource,
};
pub use crate::parser::{
    build_catalogue_database_from_maps, clean_faction_display_name, merge_mfm_into_faction,
    parse_mfm_faction_yaml, slugify_faction_name, BsDataParser, MfmCostOption, MfmDetachment,
    MfmEnhancement, MfmFactionFile, MfmMetaFile, MfmPricingTier, MfmUnit, MfmWargearOption,
};
pub use seed::default_wh40k_seed_catalogue;

use crate::common::{FactionPerformance, MatchResult, MatchStatisticsReport};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Pure Warhammer 40,000 (11e) match record with zero coupling to other game systems.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Wh40kMatchRecord {
    pub id: String,
    pub date_iso: String,
    pub player_faction: String,
    pub opponent_faction: String,
    #[serde(default)]
    pub opponent_name: String,
    pub player_score: u32,
    pub opponent_score: u32,
    #[serde(default)]
    pub result: MatchResult,
    #[serde(default)]
    pub is_detailed: bool,
    #[serde(default)]
    pub details: Wh40kMatchDetails,
    #[serde(default)]
    pub notes: String,
    #[serde(default)]
    pub created_at_iso: String,
    #[serde(default)]
    pub updated_at_iso: String,
}

impl Wh40kMatchRecord {
    pub fn sync_scores_and_result(&mut self) {
        if self.is_detailed {
            self.player_score = self.details.calculated_player_score();
            self.opponent_score = self.details.calculated_opponent_score();
        }
        if self.result != MatchResult::InProgress {
            self.result = MatchResult::from_scores(self.player_score, self.opponent_score);
        }
    }
}

pub fn filter_wh40k_matches(
    matches: &[Wh40kMatchRecord],
    search_query: &str,
    player_faction_filter: Option<&str>,
    result_filter: Option<MatchResult>,
) -> Vec<Wh40kMatchRecord> {
    let q = search_query.trim().to_lowercase();
    let mut out: Vec<Wh40kMatchRecord> = matches
        .iter()
        .filter(|m| {
            let pf_ok = player_faction_filter.map_or(true, |pf| {
                pf.is_empty() || m.player_faction.eq_ignore_ascii_case(pf)
            });
            let res_ok = result_filter.map_or(true, |r| m.result == r);
            let q_ok = q.is_empty()
                || m.player_faction.to_lowercase().contains(&q)
                || m.opponent_faction.to_lowercase().contains(&q)
                || m.opponent_name.to_lowercase().contains(&q)
                || m.notes.to_lowercase().contains(&q);
            pf_ok && res_ok && q_ok
        })
        .cloned()
        .collect();

    out.sort_by(|a, b| b.date_iso.cmp(&a.date_iso));
    out
}

pub fn compute_wh40k_match_statistics(
    matches: &[Wh40kMatchRecord],
    player_faction_filter: Option<&str>,
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
        if let Some(pf) = player_faction_filter {
            if !pf.is_empty() && !m.player_faction.eq_ignore_ascii_case(pf) {
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
            .entry(m.player_faction.clone())
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
            .entry(m.opponent_faction.clone())
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
            "Calculated across {} completed Warhammer 40,000 match(es) ({} in-progress excluded).",
            completed, in_progress
        ),
    }
}
