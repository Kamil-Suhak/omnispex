use omnispex_core::common::{
    AcquisitionState as CommonAcquisitionState, GameSystem, MatchResult as CommonMatchResult,
    WishlistPriority as CommonWishlistPriority, WishlistSortField as CommonWishlistSortField,
};
use omnispex_core::domain::archetypes::ArchetypeRoster;
use omnispex_core::domain::army_list::{export_army_list_text, validate_army_list, ArmyList};
use omnispex_core::domain::catalogue::{CatalogueDatabase, DatasheetUnit, FactionCatalogue};
use omnispex_core::domain::matches::{
    compute_match_statistics, filter_matches, MatchRecord, MatchResult as DomainMatchResult,
};
use omnispex_core::domain::unit::UnitProfile;
use omnispex_core::domain::weapon::{WeaponLoadoutEntry, WeaponProfile};
use omnispex_core::domain::wishlist::{
    compute_wishlist_summary, filter_and_sort_wishlist, upsert_wishlist_item,
    AcquisitionState as DomainAcquisitionState, WishlistItem,
    WishlistPriority as DomainWishlistPriority, WishlistSortField as DomainWishlistSortField,
};
use omnispex_core::engine::comparison::{compare_profiles, evaluate_archetypes};
use omnispex_core::engine::context::CombatContext;
use omnispex_core::engine::simulator::{run_simulation, run_squad_simulation};
use omnispex_core::kill_team::{
    compare_kt_weapons, compute_kt_match_statistics, compute_kt_wishlist_summary,
    default_kill_team_catalogue, export_kill_team_roster_text, filter_and_sort_kt_wishlist,
    filter_kt_matches, run_kt_fight_simulation, run_kt_shooting_simulation,
    validate_kill_team_roster, KillTeamCatalogueDatabase, KillTeamFaction, KillTeamRoster,
    KtFightContext, KtMatchRecord, KtShootingContext, KtWeaponProfile, KtWishlistItem,
    OperativeDatacard,
};
use omnispex_core::parser::BsDataParser;
use omnispex_core::storage::PersonalDataStore;
use omnispex_core::wh40k::{
    compute_wh40k_match_statistics, default_wh40k_seed_catalogue, filter_wh40k_matches,
    Wh40kMatchRecord,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{OnceLock, RwLock};

/// Lightweight summary DTO for 40K faction pickers (avoids serializing 5.8 MB across FFI).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Wh40kFactionSummaryDto {
    pub id: String,
    pub slug: String,
    pub name: String,
    pub parent_faction: Option<String>,
    pub unit_count: usize,
    pub detachment_count: usize,
}

/// Lightweight summary DTO for virtualized 40K unit search & browser lists.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Wh40kUnitSummaryDto {
    pub id: String,
    pub name: String,
    pub faction_id: String,
    pub faction_name: String,
    pub group_title: Option<String>,
    pub is_legends: bool,
    pub base_points: u32,
    pub movement: String,
    pub toughness: u32,
    pub save: u32,
    pub invulnerable_save: Option<u32>,
    pub wounds: u32,
    pub leadership: String,
    pub objective_control: u32,
    pub weapon_count: usize,
    pub categories: Vec<String>,
}

impl Wh40kUnitSummaryDto {
    pub fn from_unit(u: &DatasheetUnit) -> Self {
        let first_model = u.profile.model_groups.first().map(|g| &g.model);
        Self {
            id: u.id.clone(),
            name: u.name.clone(),
            faction_id: u.faction_id.clone(),
            faction_name: u.faction_name.clone(),
            group_title: u.group_title.clone(),
            is_legends: u.is_legends,
            base_points: u.base_points(),
            movement: u.profile.movement.clone(),
            toughness: u.profile.toughness,
            save: first_model.map_or(3, |m| m.save),
            invulnerable_save: first_model.and_then(|m| m.invulnerable_save),
            wounds: first_model.map_or(1, |m| m.wounds),
            leadership: u.profile.leadership.clone(),
            objective_control: u.profile.objective_control,
            weapon_count: u.weapons.len(),
            categories: u.categories.clone(),
        }
    }
}

/// Lightweight summary DTO for Kill Team faction pickers.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KtFactionSummaryDto {
    pub id: String,
    pub slug: String,
    pub name: String,
    pub superfaction: String,
    pub archetypes: Vec<String>,
    pub team_size: u32,
    pub min_team_size: u32,
    pub max_team_size: u32,
    pub operative_count: usize,
}

/// Lightweight summary DTO for virtualized Kill Team operative lists.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KtOperativeSummaryDto {
    pub id: String,
    pub name: String,
    pub faction_id: String,
    pub faction_name: String,
    pub role: String,
    pub apl: u32,
    pub movement: u32,
    pub save: u32,
    pub wounds: u32,
    pub weapon_count: usize,
    pub max_per_kill_team: u32,
    pub keywords: Vec<String>,
}

impl KtOperativeSummaryDto {
    pub fn from_operative(op: &OperativeDatacard) -> Self {
        Self {
            id: op.id.clone(),
            name: op.name.clone(),
            faction_id: op.faction_id.clone(),
            faction_name: op.faction_name.clone(),
            role: op.role.clone(),
            apl: op.apl,
            movement: op.movement,
            save: op.save,
            wounds: op.wounds,
            weapon_count: op.weapons.len(),
            max_per_kill_team: op.max_per_kill_team,
            keywords: op.keywords.clone(),
        }
    }
}

/// Process-wide stateful catalogue and index holder in Rust memory.
pub struct EngineState {
    pub wh40k_db: CatalogueDatabase,
    pub wh40k_faction_by_key: HashMap<String, usize>,
    pub wh40k_unit_by_key: HashMap<String, (usize, usize)>,
    pub kt_db: KillTeamCatalogueDatabase,
    pub kt_faction_by_key: HashMap<String, usize>,
    pub kt_operative_by_key: HashMap<String, (usize, usize)>,
}

impl Default for EngineState {
    fn default() -> Self {
        let mut state = Self {
            wh40k_db: default_wh40k_seed_catalogue(),
            wh40k_faction_by_key: HashMap::new(),
            wh40k_unit_by_key: HashMap::new(),
            kt_db: default_kill_team_catalogue(),
            kt_faction_by_key: HashMap::new(),
            kt_operative_by_key: HashMap::new(),
        };
        state.rebuild_wh40k_indices();
        state.rebuild_kt_indices();
        state
    }
}

impl EngineState {
    pub fn rebuild_wh40k_indices(&mut self) {
        self.wh40k_faction_by_key.clear();
        self.wh40k_unit_by_key.clear();
        for (f_idx, faction) in self.wh40k_db.factions.iter().enumerate() {
            self.wh40k_faction_by_key
                .insert(faction.id.to_lowercase(), f_idx);
            self.wh40k_faction_by_key
                .insert(faction.slug.to_lowercase(), f_idx);
            self.wh40k_faction_by_key
                .insert(faction.name.to_lowercase(), f_idx);

            for (u_idx, unit) in faction.units.iter().enumerate() {
                self.wh40k_unit_by_key
                    .insert(unit.id.to_lowercase(), (f_idx, u_idx));
                self.wh40k_unit_by_key.insert(
                    format!("{}:{}", faction.slug.to_lowercase(), unit.name.to_lowercase()),
                    (f_idx, u_idx),
                );
                self.wh40k_unit_by_key
                    .entry(unit.name.to_lowercase())
                    .or_insert((f_idx, u_idx));
            }
        }
    }

    pub fn rebuild_kt_indices(&mut self) {
        self.kt_faction_by_key.clear();
        self.kt_operative_by_key.clear();
        for (f_idx, faction) in self.kt_db.factions.iter().enumerate() {
            self.kt_faction_by_key
                .insert(faction.id.to_lowercase(), f_idx);
            self.kt_faction_by_key
                .insert(faction.slug.to_lowercase(), f_idx);
            self.kt_faction_by_key
                .insert(faction.name.to_lowercase(), f_idx);

            for (o_idx, op) in faction.operatives.iter().enumerate() {
                self.kt_operative_by_key
                    .insert(op.id.to_lowercase(), (f_idx, o_idx));
                self.kt_operative_by_key.insert(
                    format!("{}:{}", faction.slug.to_lowercase(), op.name.to_lowercase()),
                    (f_idx, o_idx),
                );
                self.kt_operative_by_key
                    .entry(op.name.to_lowercase())
                    .or_insert((f_idx, o_idx));
            }
        }
    }

    pub fn find_wh40k_faction(&self, key: &str) -> Option<&FactionCatalogue> {
        let clean = key.trim().to_lowercase();
        self.wh40k_faction_by_key
            .get(&clean)
            .and_then(|&idx| self.wh40k_db.factions.get(idx))
            .or_else(|| self.wh40k_db.find_faction(key))
    }

    pub fn find_wh40k_unit(&self, key: &str, faction_hint: Option<&str>) -> Option<&DatasheetUnit> {
        let clean = key.trim().to_lowercase();
        if let Some(fhint) = faction_hint {
            if let Some(f) = self.find_wh40k_faction(fhint) {
                if let Some(u) = f
                    .units
                    .iter()
                    .find(|u| u.id.eq_ignore_ascii_case(key) || u.name.eq_ignore_ascii_case(key))
                {
                    return Some(u);
                }
            }
        }
        self.wh40k_unit_by_key
            .get(&clean)
            .and_then(|&(f_idx, u_idx)| {
                self.wh40k_db
                    .factions
                    .get(f_idx)
                    .and_then(|f| f.units.get(u_idx))
            })
    }

    pub fn find_kt_faction(&self, key: &str) -> Option<&KillTeamFaction> {
        let clean = key.trim().to_lowercase();
        self.kt_faction_by_key
            .get(&clean)
            .and_then(|&idx| self.kt_db.factions.get(idx))
            .or_else(|| self.kt_db.find_faction(key))
    }

    pub fn find_kt_operative(
        &self,
        key: &str,
        faction_hint: Option<&str>,
    ) -> Option<&OperativeDatacard> {
        let clean = key.trim().to_lowercase();
        if let Some(fhint) = faction_hint {
            if let Some(f) = self.find_kt_faction(fhint) {
                if let Some(op) = f
                    .operatives
                    .iter()
                    .find(|o| o.id.eq_ignore_ascii_case(key) || o.name.eq_ignore_ascii_case(key))
                {
                    return Some(op);
                }
            }
        }
        self.kt_operative_by_key
            .get(&clean)
            .and_then(|&(f_idx, o_idx)| {
                self.kt_db
                    .factions
                    .get(f_idx)
                    .and_then(|f| f.operatives.get(o_idx))
            })
    }
}

static ENGINE_STATE: OnceLock<RwLock<EngineState>> = OnceLock::new();

pub fn engine_state() -> &'static RwLock<EngineState> {
    ENGINE_STATE.get_or_init(|| RwLock::new(EngineState::default()))
}

// ============================================================================
// Request DTOs
// ============================================================================

#[derive(Debug, Deserialize)]
pub struct SimulationRequestDto {
    pub weapon: WeaponProfile,
    pub target: UnitProfile,
    pub context: CombatContext,
    pub iterations: u32,
}

#[derive(Debug, Deserialize)]
pub struct SquadSimulationRequestDto {
    pub loadout: Vec<WeaponLoadoutEntry>,
    pub target: UnitProfile,
    pub context: CombatContext,
    pub iterations: u32,
}

#[derive(Debug, Deserialize)]
pub struct ProfileComparisonRequestDto {
    pub weapons: Vec<WeaponProfile>,
    pub target: UnitProfile,
    pub context: CombatContext,
    pub iterations: u32,
}

#[derive(Debug, Deserialize)]
pub struct ArchetypeEvaluationRequestDto {
    pub weapon: WeaponProfile,
    #[serde(default)]
    pub roster: Option<ArchetypeRoster>,
    pub context: CombatContext,
    pub iterations: u32,
}

#[derive(Debug, Deserialize)]
pub struct Wh40kSearchRequestDto {
    #[serde(default)]
    pub query: String,
    #[serde(default)]
    pub faction: Option<String>,
    #[serde(default)]
    pub category: Option<String>,
    #[serde(default)]
    pub include_legends: bool,
}

#[derive(Debug, Deserialize)]
pub struct Wh40kLookupRequestDto {
    pub id_or_name: String,
    #[serde(default)]
    pub faction: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ValidateArmyListRequestDto {
    pub list: ArmyList,
    #[serde(default)]
    pub catalogue: Option<CatalogueDatabase>,
    #[serde(default, alias = "faction")]
    pub faction_catalogue: Option<FactionCatalogue>,
}

#[derive(Debug, Deserialize)]
pub struct RecalculatePointsRequestDto {
    pub list: ArmyList,
    #[serde(default)]
    pub faction: Option<FactionCatalogue>,
}

#[derive(Debug, Deserialize)]
pub struct ExportArmyListRequestDto {
    pub list: ArmyList,
    #[serde(default)]
    pub catalogue: Option<CatalogueDatabase>,
}

#[derive(Debug, Deserialize)]
pub struct FilterWishlistRequestDto {
    pub items: Vec<WishlistItem>,
    #[serde(default, alias = "query")]
    pub search_query: String,
    #[serde(default, alias = "faction_id")]
    pub faction_filter: Option<String>,
    #[serde(default)]
    pub state_filter: Option<DomainAcquisitionState>,
    #[serde(default)]
    pub priority_filter: Option<DomainWishlistPriority>,
    #[serde(default)]
    pub sort_by: DomainWishlistSortField,
}

#[derive(Debug, Deserialize)]
pub struct UpsertWishlistRequestDto {
    pub items: Vec<WishlistItem>,
    pub item: WishlistItem,
    #[serde(default)]
    pub active_faction_id: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct WishlistSummaryRequestDto {
    pub items: Vec<WishlistItem>,
    #[serde(default)]
    pub faction_filter: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct FilterMatchesRequestDto {
    pub matches: Vec<MatchRecord>,
    #[serde(default, alias = "game_system")]
    pub system_filter: Option<omnispex_core::domain::matches::GameSystem>,
    #[serde(default, alias = "query")]
    pub search_query: String,
    #[serde(default, alias = "faction_filter")]
    pub player_faction_filter: Option<String>,
    #[serde(default)]
    pub result_filter: Option<DomainMatchResult>,
}

#[derive(Debug, Deserialize)]
pub struct MatchStatsRequestDto {
    pub matches: Vec<MatchRecord>,
    #[serde(default, alias = "game_system")]
    pub system_filter: Option<omnispex_core::domain::matches::GameSystem>,
    #[serde(default, alias = "faction_filter")]
    pub player_faction_filter: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct Wh40kFilterMatchesRequestDto {
    pub matches: Vec<Wh40kMatchRecord>,
    #[serde(default, alias = "query")]
    pub search_query: String,
    #[serde(default, alias = "faction_filter")]
    pub player_faction_filter: Option<String>,
    #[serde(default)]
    pub result_filter: Option<CommonMatchResult>,
}

#[derive(Debug, Deserialize)]
pub struct Wh40kMatchStatsRequestDto {
    pub matches: Vec<Wh40kMatchRecord>,
    #[serde(default, alias = "faction_filter")]
    pub player_faction_filter: Option<String>,
}

// Kill Team Request DTOs
#[derive(Debug, Deserialize)]
pub struct KtSearchRequestDto {
    #[serde(default)]
    pub query: String,
    #[serde(default)]
    pub faction: Option<String>,
    #[serde(default)]
    pub role: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct KtLookupRequestDto {
    pub id_or_name: String,
    #[serde(default)]
    pub faction: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct KtShootingRequestDto {
    pub weapon: KtWeaponProfile,
    pub target: OperativeDatacard,
    pub context: KtShootingContext,
    pub iterations: u32,
}

#[derive(Debug, Deserialize)]
pub struct KtCompareWeaponsRequestDto {
    pub weapons: Vec<KtWeaponProfile>,
    pub target: OperativeDatacard,
    pub context: KtShootingContext,
    pub iterations: u32,
}

#[derive(Debug, Deserialize)]
pub struct KtFightRequestDto {
    pub attacker: OperativeDatacard,
    pub attacker_weapon: KtWeaponProfile,
    pub defender: OperativeDatacard,
    pub defender_weapon: KtWeaponProfile,
    pub context: KtFightContext,
    pub iterations: u32,
}

#[derive(Debug, Deserialize)]
pub struct KtValidateRosterRequestDto {
    pub roster: KillTeamRoster,
}

#[derive(Debug, Deserialize)]
pub struct KtFilterWishlistRequestDto {
    pub items: Vec<KtWishlistItem>,
    #[serde(default, alias = "query")]
    pub search_query: String,
    #[serde(default, alias = "faction_id")]
    pub faction_filter: Option<String>,
    #[serde(default)]
    pub state_filter: Option<CommonAcquisitionState>,
    #[serde(default)]
    pub priority_filter: Option<CommonWishlistPriority>,
    #[serde(default)]
    pub sort_by: CommonWishlistSortField,
}

#[derive(Debug, Deserialize)]
pub struct KtWishlistSummaryRequestDto {
    pub items: Vec<KtWishlistItem>,
    #[serde(default)]
    pub faction_filter: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct KtFilterMatchesRequestDto {
    pub matches: Vec<KtMatchRecord>,
    #[serde(default, alias = "query")]
    pub search_query: String,
    #[serde(default, alias = "faction_filter")]
    pub player_team_filter: Option<String>,
    #[serde(default)]
    pub result_filter: Option<CommonMatchResult>,
}

#[derive(Debug, Deserialize)]
pub struct KtMatchStatsRequestDto {
    pub matches: Vec<KtMatchRecord>,
    #[serde(default)]
    pub player_team_filter: Option<String>,
}

// ============================================================================
// Central JSON RPC Dispatcher
// ============================================================================

pub fn dispatch_command(action: &str, payload_json: &str) -> Result<String, String> {
    match action {
        // --------------------------------------------------------------------
        // System & Health
        // --------------------------------------------------------------------
        "ping" => Ok(serde_json::json!("omnispex_rust_core_ready").to_string()),

        "engine_status" => {
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState lock poisoned".to_string())?;
            let wh40k_units: usize = st.wh40k_db.factions.iter().map(|f| f.units.len()).sum();
            let kt_ops: usize = st.kt_db.factions.iter().map(|f| f.operatives.len()).sum();
            Ok(serde_json::json!({
                "ready": true,
                "supported_systems": [GameSystem::Warhammer40k.as_key(), GameSystem::KillTeam.as_key()],
                "wh40k_factions": st.wh40k_db.factions.len(),
                "wh40k_units": wh40k_units,
                "kt_factions": st.kt_db.factions.len(),
                "kt_operatives": kt_ops,
            })
            .to_string())
        }

        // --------------------------------------------------------------------
        // Warhammer 40,000 (11e) Stateful Catalogue & Engine RPCs
        // --------------------------------------------------------------------
        "wh40k_load_catalogue" => {
            let db: CatalogueDatabase = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid wh40k CatalogueDatabase JSON: {}", e))?;
            let faction_count = db.factions.len();
            let unit_count: usize = db.factions.iter().map(|f| f.units.len()).sum();
            let mut st = engine_state()
                .write()
                .map_err(|_| "EngineState write lock poisoned".to_string())?;
            st.wh40k_db = db;
            st.rebuild_wh40k_indices();
            Ok(serde_json::json!({
                "loaded": true,
                "factions": faction_count,
                "units": unit_count,
            })
            .to_string())
        }

        "wh40k_get_factions_summary" => {
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let summaries: Vec<Wh40kFactionSummaryDto> = st
                .wh40k_db
                .factions
                .iter()
                .map(|f| Wh40kFactionSummaryDto {
                    id: f.id.clone(),
                    slug: f.slug.clone(),
                    name: f.name.clone(),
                    parent_faction: f.parent_faction.clone(),
                    unit_count: f.units.len(),
                    detachment_count: f.detachments.len(),
                })
                .collect();
            serde_json::to_string(&summaries).map_err(|e| e.to_string())
        }

        "wh40k_get_faction_detail" => {
            let req: Wh40kLookupRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid Wh40kLookupRequestDto: {}", e))?;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let faction = st
                .find_wh40k_faction(&req.id_or_name)
                .ok_or_else(|| format!("40K Faction '{}' not found in EngineState", req.id_or_name))?;
            serde_json::to_string(faction).map_err(|e| e.to_string())
        }

        "wh40k_get_unit_detail" => {
            let req: Wh40kLookupRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid Wh40kLookupRequestDto: {}", e))?;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let unit = st
                .find_wh40k_unit(&req.id_or_name, req.faction.as_deref())
                .ok_or_else(|| format!("40K Unit '{}' not found in EngineState", req.id_or_name))?;
            serde_json::to_string(unit).map_err(|e| e.to_string())
        }

        "wh40k_search_units" => {
            let req: Wh40kSearchRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid Wh40kSearchRequestDto: {}", e))?;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let matches = st.wh40k_db.search_units(
                &req.query,
                req.faction.as_deref(),
                req.category.as_deref(),
                req.include_legends,
            );
            let summaries: Vec<Wh40kUnitSummaryDto> = matches
                .iter()
                .map(Wh40kUnitSummaryDto::from_unit)
                .collect();
            serde_json::to_string(&summaries).map_err(|e| e.to_string())
        }

        "wh40k_search_units_full" | "search_catalogue_units" => {
            let req: Wh40kSearchRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid Wh40kSearchRequestDto: {}", e))?;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let matches = st.wh40k_db.search_units(
                &req.query,
                req.faction.as_deref(),
                req.category.as_deref(),
                req.include_legends,
            );
            serde_json::to_string(&matches).map_err(|e| e.to_string())
        }

        "wh40k_run_simulation" | "run_simulation" | "simulate_matchup" => {
            let req: SimulationRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid SimulationRequestDto: {}", e))?;
            let report = run_simulation(&req.weapon, &req.target, &req.context, req.iterations);
            serde_json::to_string(&report).map_err(|e| e.to_string())
        }

        "wh40k_run_squad_simulation" | "run_squad_simulation" | "simulate_squad_matchup" => {
            let req: SquadSimulationRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid SquadSimulationRequestDto: {}", e))?;
            let report =
                run_squad_simulation(&req.loadout, &req.target, &req.context, req.iterations);
            serde_json::to_string(&report).map_err(|e| e.to_string())
        }

        "wh40k_compare_profiles" | "compare_profiles" => {
            let req: ProfileComparisonRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid ProfileComparisonRequestDto: {}", e))?;
            let report = compare_profiles(&req.weapons, &req.target, &req.context, req.iterations)
                .map_err(|e| e.to_string())?;
            serde_json::to_string(&report).map_err(|e| e.to_string())
        }

        "wh40k_evaluate_archetypes" | "evaluate_archetypes" => {
            let req: ArchetypeEvaluationRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid ArchetypeEvaluationRequestDto: {}", e))?;
            let roster = req.roster.unwrap_or_default();
            let report = evaluate_archetypes(&req.weapon, &roster, &req.context, req.iterations);
            serde_json::to_string(&report).map_err(|e| e.to_string())
        }

        "wh40k_get_default_archetypes" | "get_default_archetypes" => {
            let roster = ArchetypeRoster::default();
            serde_json::to_string(&roster).map_err(|e| e.to_string())
        }

        "parse_bsdata_catalogue" => {
            let faction = BsDataParser::parse_catalogue_json(payload_json)?;
            serde_json::to_string(&faction).map_err(|e| e.to_string())
        }

        "parse_rich_catalogue" => {
            let faction = BsDataParser::parse_rich_catalogue_json(payload_json)?;
            serde_json::to_string(&faction).map_err(|e| e.to_string())
        }

        "evaluate_army_list" => {
            let req: ValidateArmyListRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid ValidateArmyListRequestDto: {}", e))?;
            let mut list = req.list;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;

            let temp_db = req.catalogue.or_else(|| {
                req.faction_catalogue.map(|fc| CatalogueDatabase {
                    provenance: Default::default(),
                    factions: vec![fc],
                })
            });
            let active_db = temp_db.as_ref().unwrap_or(&st.wh40k_db);

            if let Some(fcat) = active_db
                .find_faction(&list.faction_id)
                .or_else(|| active_db.find_faction(&list.faction_name))
            {
                list.recalculate_points(fcat);
            }
            let validation = validate_army_list(&list, Some(active_db));
            let exported_text = export_army_list_text(&list, Some(&validation));
            Ok(serde_json::json!({
                "list": list,
                "validation": validation,
                "exported_text": exported_text,
            })
            .to_string())
        }

        "wh40k_validate_army_list" | "validate_army_list" => {
            let req: ValidateArmyListRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid ValidateArmyListRequestDto: {}", e))?;
            let mut list = req.list;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;

            let temp_db = req.catalogue.or_else(|| {
                req.faction_catalogue.map(|fc| CatalogueDatabase {
                    provenance: Default::default(),
                    factions: vec![fc],
                })
            });
            let active_db = temp_db.as_ref().unwrap_or(&st.wh40k_db);

            if let Some(fcat) = active_db
                .find_faction(&list.faction_id)
                .or_else(|| active_db.find_faction(&list.faction_name))
            {
                list.recalculate_points(fcat);
            }
            let report = validate_army_list(&list, Some(active_db));
            serde_json::to_string(&report).map_err(|e| e.to_string())
        }

        "wh40k_recalculate_army_list_points" | "recalculate_army_list_points" => {
            let req: RecalculatePointsRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid RecalculatePointsRequestDto: {}", e))?;
            let mut list = req.list;
            if let Some(fcat) = req.faction {
                list.recalculate_points(&fcat);
            } else {
                let st = engine_state()
                    .read()
                    .map_err(|_| "EngineState read lock poisoned".to_string())?;
                if let Some(fcat) = st
                    .find_wh40k_faction(&list.faction_id)
                    .or_else(|| st.find_wh40k_faction(&list.faction_name))
                {
                    list.recalculate_points(fcat);
                }
            }
            serde_json::to_string(&list).map_err(|e| e.to_string())
        }

        "wh40k_export_army_list_text" | "export_army_list_text" => {
            let req: ExportArmyListRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid ExportArmyListRequestDto: {}", e))?;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let active_db = req.catalogue.as_ref().unwrap_or(&st.wh40k_db);
            let report = validate_army_list(&req.list, Some(active_db));
            let text = export_army_list_text(&req.list, Some(&report));
            serde_json::to_string(&text).map_err(|e| e.to_string())
        }

        "wh40k_filter_wishlist" | "filter_wishlist" => {
            let req: FilterWishlistRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid FilterWishlistRequestDto: {}", e))?;
            let filtered = filter_and_sort_wishlist(
                &req.items,
                req.faction_filter.as_deref(),
                &req.search_query,
                req.priority_filter,
                req.state_filter,
                req.sort_by,
            );
            serde_json::to_string(&filtered).map_err(|e| e.to_string())
        }

        "query_wishlist" => {
            let req: FilterWishlistRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid FilterWishlistRequestDto: {}", e))?;
            let filtered = filter_and_sort_wishlist(
                &req.items,
                req.faction_filter.as_deref(),
                &req.search_query,
                req.priority_filter,
                req.state_filter,
                req.sort_by,
            );
            let summary = compute_wishlist_summary(&req.items, req.faction_filter.as_deref());
            Ok(serde_json::json!({
                "items": req.items,
                "filtered_items": filtered,
                "summary": summary,
            })
            .to_string())
        }

        "upsert_wishlist" => {
            let mut req: UpsertWishlistRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid UpsertWishlistRequestDto: {}", e))?;
            let upserted = upsert_wishlist_item(&mut req.items, req.item);
            let filtered = filter_and_sort_wishlist(
                &req.items,
                req.active_faction_id.as_deref(),
                "",
                None,
                None,
                DomainWishlistSortField::PriorityDesc,
            );
            let summary = compute_wishlist_summary(&req.items, req.active_faction_id.as_deref());
            Ok(serde_json::json!({
                "items": req.items,
                "filtered_items": filtered,
                "upserted": upserted,
                "summary": summary,
            })
            .to_string())
        }

        "wh40k_compute_wishlist_summary" | "compute_wishlist_summary" => {
            let req: WishlistSummaryRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid WishlistSummaryRequestDto: {}", e))?;
            let summary = compute_wishlist_summary(&req.items, req.faction_filter.as_deref());
            serde_json::to_string(&summary).map_err(|e| e.to_string())
        }

        "wh40k_filter_matches" => {
            let req: Wh40kFilterMatchesRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid Wh40kFilterMatchesRequestDto: {}", e))?;
            let filtered = filter_wh40k_matches(
                &req.matches,
                &req.search_query,
                req.player_faction_filter.as_deref(),
                req.result_filter,
            );
            serde_json::to_string(&filtered).map_err(|e| e.to_string())
        }

        "wh40k_compute_match_statistics" => {
            let req: Wh40kMatchStatsRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid Wh40kMatchStatsRequestDto: {}", e))?;
            let stats =
                compute_wh40k_match_statistics(&req.matches, req.player_faction_filter.as_deref());
            serde_json::to_string(&stats).map_err(|e| e.to_string())
        }

        // --------------------------------------------------------------------
        // Kill Team (2024 / 3rd Edition) Stateful Catalogue & Engine RPCs
        // --------------------------------------------------------------------
        "kt_load_catalogue" => {
            let db: KillTeamCatalogueDatabase = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KillTeamCatalogueDatabase JSON: {}", e))?;
            let faction_count = db.factions.len();
            let op_count: usize = db.factions.iter().map(|f| f.operatives.len()).sum();
            let mut st = engine_state()
                .write()
                .map_err(|_| "EngineState write lock poisoned".to_string())?;
            st.kt_db = db;
            st.rebuild_kt_indices();
            Ok(serde_json::json!({
                "loaded": true,
                "factions": faction_count,
                "operatives": op_count,
            })
            .to_string())
        }

        "kt_get_catalogue" => {
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            serde_json::to_string(&st.kt_db).map_err(|e| e.to_string())
        }

        "kt_get_factions_summary" => {
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let summaries: Vec<KtFactionSummaryDto> = st
                .kt_db
                .factions
                .iter()
                .map(|f| KtFactionSummaryDto {
                    id: f.id.clone(),
                    slug: f.slug.clone(),
                    name: f.name.clone(),
                    superfaction: f.superfaction.clone(),
                    archetypes: f.archetypes.clone(),
                    team_size: f.team_size,
                    min_team_size: f.min_team_size,
                    max_team_size: f.max_team_size,
                    operative_count: f.operatives.len(),
                })
                .collect();
            serde_json::to_string(&summaries).map_err(|e| e.to_string())
        }

        "kt_get_faction_detail" => {
            let req: KtLookupRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtLookupRequestDto: {}", e))?;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let faction = st
                .find_kt_faction(&req.id_or_name)
                .ok_or_else(|| format!("Kill Team Faction '{}' not found", req.id_or_name))?;
            serde_json::to_string(faction).map_err(|e| e.to_string())
        }

        "kt_get_operative_detail" => {
            let req: KtLookupRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtLookupRequestDto: {}", e))?;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let op = st
                .find_kt_operative(&req.id_or_name, req.faction.as_deref())
                .ok_or_else(|| format!("Kill Team Operative '{}' not found", req.id_or_name))?;
            serde_json::to_string(op).map_err(|e| e.to_string())
        }

        "kt_search_operatives" => {
            let req: KtSearchRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtSearchRequestDto: {}", e))?;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let ops = st.kt_db.search_operatives(
                &req.query,
                req.faction.as_deref(),
                req.role.as_deref(),
            );
            let summaries: Vec<KtOperativeSummaryDto> = ops
                .into_iter()
                .map(KtOperativeSummaryDto::from_operative)
                .collect();
            serde_json::to_string(&summaries).map_err(|e| e.to_string())
        }

        "kt_search_operatives_full" => {
            let req: KtSearchRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtSearchRequestDto: {}", e))?;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let ops = st.kt_db.search_operatives(
                &req.query,
                req.faction.as_deref(),
                req.role.as_deref(),
            );
            serde_json::to_string(&ops).map_err(|e| e.to_string())
        }

        "kt_get_universal_equipment" => {
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            serde_json::to_string(&st.kt_db.universal_equipment).map_err(|e| e.to_string())
        }

        "kt_run_shooting_simulation" => {
            let req: KtShootingRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtShootingRequestDto: {}", e))?;
            let report =
                run_kt_shooting_simulation(&req.weapon, &req.target, &req.context, req.iterations);
            serde_json::to_string(&report).map_err(|e| e.to_string())
        }

        "kt_compare_weapons" => {
            let req: KtCompareWeaponsRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtCompareWeaponsRequestDto: {}", e))?;
            let report = compare_kt_weapons(&req.weapons, &req.target, &req.context, req.iterations)
                .map_err(|e| e.to_string())?;
            serde_json::to_string(&report).map_err(|e| e.to_string())
        }

        "kt_run_fight_simulation" => {
            let req: KtFightRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtFightRequestDto: {}", e))?;
            let report = run_kt_fight_simulation(
                &req.attacker,
                &req.attacker_weapon,
                &req.defender,
                &req.defender_weapon,
                &req.context,
                req.iterations,
            );
            serde_json::to_string(&report).map_err(|e| e.to_string())
        }

        "kt_validate_roster" => {
            let req: KtValidateRosterRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtValidateRosterRequestDto: {}", e))?;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let report = validate_kill_team_roster(&req.roster, Some(&st.kt_db));
            serde_json::to_string(&report).map_err(|e| e.to_string())
        }

        "kt_export_roster_text" => {
            let req: KtValidateRosterRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtValidateRosterRequestDto: {}", e))?;
            let st = engine_state()
                .read()
                .map_err(|_| "EngineState read lock poisoned".to_string())?;
            let report = validate_kill_team_roster(&req.roster, Some(&st.kt_db));
            let text = export_kill_team_roster_text(&req.roster, Some(&report));
            serde_json::to_string(&text).map_err(|e| e.to_string())
        }

        "kt_filter_wishlist" => {
            let req: KtFilterWishlistRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtFilterWishlistRequestDto: {}", e))?;
            let filtered = filter_and_sort_kt_wishlist(
                &req.items,
                &req.search_query,
                req.faction_filter.as_deref(),
                req.state_filter,
                req.priority_filter,
                req.sort_by,
            );
            serde_json::to_string(&filtered).map_err(|e| e.to_string())
        }

        "kt_compute_wishlist_summary" => {
            let req: KtWishlistSummaryRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtWishlistSummaryRequestDto: {}", e))?;
            let summary = compute_kt_wishlist_summary(&req.items, req.faction_filter.as_deref());
            serde_json::to_string(&summary).map_err(|e| e.to_string())
        }

        "kt_filter_matches" => {
            let req: KtFilterMatchesRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtFilterMatchesRequestDto: {}", e))?;
            let filtered = filter_kt_matches(
                &req.matches,
                &req.search_query,
                req.player_team_filter.as_deref(),
                req.result_filter,
            );
            serde_json::to_string(&filtered).map_err(|e| e.to_string())
        }

        "kt_compute_match_statistics" => {
            let req: KtMatchStatsRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid KtMatchStatsRequestDto: {}", e))?;
            let stats =
                compute_kt_match_statistics(&req.matches, req.player_team_filter.as_deref());
            serde_json::to_string(&stats).map_err(|e| e.to_string())
        }

        // --------------------------------------------------------------------
        // Legacy / CLI Compatibility RPCs
        // --------------------------------------------------------------------
        "filter_matches" => {
            let req: FilterMatchesRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid FilterMatchesRequestDto: {}", e))?;
            let filtered = filter_matches(
                &req.matches,
                req.system_filter,
                &req.search_query,
                req.player_faction_filter.as_deref(),
                req.result_filter,
            );
            serde_json::to_string(&filtered).map_err(|e| e.to_string())
        }

        "compute_match_statistics" => {
            let req: MatchStatsRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid MatchStatsRequestDto: {}", e))?;
            let stats = compute_match_statistics(
                &req.matches,
                req.system_filter,
                req.player_faction_filter.as_deref(),
            );
            serde_json::to_string(&stats).map_err(|e| e.to_string())
        }

        "evaluate_matches" => {
            let req: FilterMatchesRequestDto = serde_json::from_str(payload_json)
                .map_err(|e| format!("Invalid FilterMatchesRequestDto: {}", e))?;
            let filtered = filter_matches(
                &req.matches,
                req.system_filter,
                &req.search_query,
                req.player_faction_filter.as_deref(),
                req.result_filter,
            );
            let statistics = compute_match_statistics(
                &req.matches,
                req.system_filter,
                req.player_faction_filter.as_deref(),
            );
            Ok(serde_json::json!({
                "filtered_matches": filtered,
                "statistics": statistics,
                "kill_team_factions": omnispex_core::domain::matches::default_kill_team_factions(),
            })
            .to_string())
        }

        "migrate_personal_store" => {
            let store = PersonalDataStore::from_json_migrated(payload_json)?;
            serde_json::to_string(&store).map_err(|e| e.to_string())
        }

        other => Err(format!("Unknown Omnispex bridge action: '{}'", other)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_stateful_engine_wh40k_and_kill_team_dispatch() {
        let status_json = dispatch_command("engine_status", "{}").expect("Status failed");
        assert!(status_json.contains("\"ready\":true"));

        // 40K stateful search & lookup
        let wh40k_factions =
            dispatch_command("wh40k_get_factions_summary", "{}").expect("40K factions failed");
        assert!(wh40k_factions.contains("Space Marines"));

        let wh40k_units = dispatch_command(
            "wh40k_search_units",
            r#"{"query": "Intercessor", "include_legends": false}"#,
        )
        .expect("40K unit search failed");
        assert!(wh40k_units.contains("Intercessor Squad"));

        // Kill Team stateful search & combat simulation
        let kt_factions =
            dispatch_command("kt_get_factions_summary", "{}").expect("KT factions failed");
        assert!(kt_factions.contains("Angels of Death"));
        assert!(kt_factions.contains("Plague Marines"));

        let kt_ops = dispatch_command(
            "kt_search_operatives",
            r#"{"query": "Eliminator", "faction": "angels-of-death"}"#,
        )
        .expect("KT operative search failed");
        assert!(kt_ops.contains("Eliminator Sniper"));

        let op_detail = dispatch_command(
            "kt_get_operative_detail",
            r#"{"id_or_name": "Eliminator Sniper", "faction": "angels-of-death"}"#,
        )
        .expect("KT operative detail failed");
        let sniper: OperativeDatacard = serde_json::from_str(&op_detail).unwrap();

        let shoot_req = serde_json::json!({
            "weapon": sniper.weapons[0],
            "target": sniper,
            "context": KtShootingContext::default(),
            "iterations": 500
        });
        let shoot_res = dispatch_command("kt_run_shooting_simulation", &shoot_req.to_string())
            .expect("KT shooting simulation failed");
        assert!(shoot_res.contains("expected_damage_dealt"));
    }

    #[test]
    fn test_hydrate_full_wh40k_and_kill_team_bundles_into_engine_state() {
        use std::fs;
        use std::path::Path;

        let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
        let assets_dir = manifest_dir.join("../../flutter_ui/assets/data");
        fs::create_dir_all(&assets_dir).expect("Failed to create assets/data dir");

        // Ensure kill_team_bundle.json is generated and up-to-date
        let kt_bundle_path = assets_dir.join("kill_team_bundle.json");
        let kt_cat = default_kill_team_catalogue();
        let kt_json = serde_json::to_string_pretty(&kt_cat).expect("Serialize KT catalogue failed");
        fs::write(&kt_bundle_path, &kt_json).expect("Write kill_team_bundle.json failed");

        let kt_load_res =
            dispatch_command("kt_load_catalogue", &kt_json).expect("kt_load_catalogue failed");
        assert!(kt_load_res.contains("\"loaded\":true"));

        // Verify wh40k_11e_bundle.json loads into EngineState
        let wh40k_bundle_path = assets_dir.join("wh40k_11e_bundle.json");
        if wh40k_bundle_path.exists() {
            let raw_40k =
                fs::read_to_string(&wh40k_bundle_path).expect("Read wh40k_11e_bundle.json failed");
            let load_res = dispatch_command("wh40k_load_catalogue", &raw_40k)
                .expect("wh40k_load_catalogue failed");
            assert!(load_res.contains("\"loaded\":true"));
            assert!(load_res.contains("\"factions\":35"));
        }
    }
}
