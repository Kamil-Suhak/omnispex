use flutter_rust_bridge::frb;
use omnispex_core::domain::{ArchetypeRoster, UnitProfile, WeaponProfile};
use omnispex_core::engine::{
    compare_profiles, evaluate_archetypes, run_simulation, ArchetypeBenchmarkReport, CombatContext,
    ProfileComparisonReport, SimulationReport,
};
use omnispex_core::parser::wahapedia::{
    parse_wahapedia_unit, parse_wahapedia_weapons,
};

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub fn simulate_matchup(
    weapon: WeaponProfile,
    target: UnitProfile,
    context: CombatContext,
    iterations: u32,
) -> SimulationReport {
    run_simulation(&weapon, &target, &context, iterations)
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

pub fn parse_waha_weapons_api(raw_text: String) -> Vec<WeaponProfile> {
    parse_wahapedia_weapons(&raw_text)
}

pub fn parse_waha_unit_api(raw_text: String) -> Result<UnitProfile, String> {
    parse_wahapedia_unit(&raw_text).map_err(|e| e.0)
}
