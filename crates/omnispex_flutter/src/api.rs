use omnispex_core::domain::{
    compute_match_statistics, compute_wishlist_summary, default_kill_team_factions,
    export_army_list_text, filter_and_sort_wishlist, filter_matches, upsert_wishlist_item,
    validate_army_list, AcquisitionState, ArchetypeRoster, ArmyList, CatalogueDatabase,
    FactionCatalogue, GameSystem, ListValidationReport, MatchRecord, MatchResult,
    MatchStatisticsReport, UnitProfile, WeaponLoadoutEntry, WeaponProfile, WishlistItem,
    WishlistPriority, WishlistSortField, WishlistSummary,
};
use omnispex_core::engine::{
    compare_profiles, compute_exact_stage_probabilities, evaluate_archetypes, run_simulation,
    run_squad_simulation, ArchetypeBenchmarkReport, CombatContext, ProfileComparisonReport,
    SimulationReport, StageProbabilities,
};
use omnispex_core::parser::{merge_mfm_into_faction, parse_mfm_faction_yaml, BsDataParser};
use omnispex_core::storage::PersonalDataStore;
use serde::{Deserialize, Serialize};

pub fn init_app() {}

pub fn simulate_matchup(
    weapon: WeaponProfile,
    target: UnitProfile,
    context: CombatContext,
    iterations: u32,
) -> SimulationReport {
    run_simulation(&weapon, &target, &context, iterations)
}

pub fn simulate_squad_matchup(
    loadout: Vec<WeaponLoadoutEntry>,
    target: UnitProfile,
    context: CombatContext,
    iterations: u32,
) -> SimulationReport {
    run_squad_simulation(&loadout, &target, &context, iterations)
}

pub fn exact_stage_probabilities_api(
    weapon: WeaponProfile,
    target: UnitProfile,
    context: CombatContext,
) -> StageProbabilities {
    compute_exact_stage_probabilities(&weapon, &target, &context)
}

pub fn compare_profiles_api(
    weapons: Vec<WeaponProfile>,
    target: UnitProfile,
    context: CombatContext,
    iterations: u32,
) -> Result<ProfileComparisonReport, String> {
    compare_profiles(&weapons, &target, &context, iterations).map_err(|e| e.to_string())
}

pub fn evaluate_archetypes_api(
    weapon: WeaponProfile,
    roster: ArchetypeRoster,
    context: CombatContext,
    iterations: u32,
) -> ArchetypeBenchmarkReport {
    evaluate_archetypes(&weapon, &roster, &context, iterations)
}

pub fn get_default_archetypes() -> ArchetypeRoster {
    ArchetypeRoster::default()
}

pub fn parse_bsdata_catalogue_api(json_str: &str) -> Result<FactionCatalogue, String> {
    BsDataParser::parse_rich_catalogue_json(json_str)
}

pub fn merge_mfm_yaml_api(
    mut faction: FactionCatalogue,
    mfm_yaml: &str,
) -> Result<FactionCatalogue, String> {
    let mfm = parse_mfm_faction_yaml(mfm_yaml)?;
    merge_mfm_into_faction(&mut faction, &mfm);
    Ok(faction)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArmyListEvaluationResponse {
    pub list: ArmyList,
    pub validation: ListValidationReport,
    pub exported_text: String,
}

pub fn evaluate_army_list_api(
    mut list: ArmyList,
    faction: Option<FactionCatalogue>,
) -> ArmyListEvaluationResponse {
    if let Some(ref fcat) = faction {
        list.recalculate_points(fcat);
    }
    let db = faction.map(|f| CatalogueDatabase {
        provenance: Default::default(),
        factions: vec![f],
    });
    let validation = validate_army_list(&list, db.as_ref());
    let exported_text = export_army_list_text(&list, Some(&validation));
    ArmyListEvaluationResponse {
        list,
        validation,
        exported_text,
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WishlistOperationResponse {
    pub items: Vec<WishlistItem>,
    pub filtered_items: Vec<WishlistItem>,
    pub summary: WishlistSummary,
}

pub fn upsert_wishlist_api(
    mut items: Vec<WishlistItem>,
    item: WishlistItem,
    active_faction_id: Option<String>,
) -> WishlistOperationResponse {
    upsert_wishlist_item(&mut items, item);
    let filtered_items = filter_and_sort_wishlist(
        &items,
        active_faction_id.as_deref(),
        "",
        None,
        None,
        WishlistSortField::PriorityDesc,
    );
    let summary = compute_wishlist_summary(&items, active_faction_id.as_deref());
    WishlistOperationResponse {
        items,
        filtered_items,
        summary,
    }
}

pub fn query_wishlist_api(
    items: &[WishlistItem],
    faction_id: Option<&str>,
    query: &str,
    priority_filter: Option<WishlistPriority>,
    state_filter: Option<AcquisitionState>,
    sort_by: WishlistSortField,
) -> WishlistOperationResponse {
    let filtered_items = filter_and_sort_wishlist(
        items,
        faction_id,
        query,
        priority_filter,
        state_filter,
        sort_by,
    );
    let summary = compute_wishlist_summary(items, faction_id);
    WishlistOperationResponse {
        items: items.to_vec(),
        filtered_items,
        summary,
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatchDashboardResponse {
    pub filtered_matches: Vec<MatchRecord>,
    pub statistics: MatchStatisticsReport,
    pub kill_team_factions: Vec<String>,
}

pub fn evaluate_matches_api(
    matches: &[MatchRecord],
    game_system: Option<GameSystem>,
    query: &str,
    faction_filter: Option<&str>,
    result_filter: Option<MatchResult>,
) -> MatchDashboardResponse {
    let filtered_matches =
        filter_matches(matches, game_system, query, faction_filter, result_filter);
    let statistics = compute_match_statistics(matches, game_system, faction_filter);
    MatchDashboardResponse {
        filtered_matches,
        statistics,
        kill_team_factions: default_kill_team_factions(),
    }
}

pub fn migrate_personal_store_api(json_str: &str) -> Result<PersonalDataStore, String> {
    PersonalDataStore::from_json_migrated(json_str)
}
