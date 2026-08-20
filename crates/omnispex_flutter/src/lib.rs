pub mod api;
mod frb_generated;

#[cfg(test)]
mod tests {
    use super::api::*;
    use omnispex_core::domain::{ModelProfile, UnitProfile, ValueExpr, WeaponProfile};
    use omnispex_core::engine::CombatContext;

    #[test]
    fn test_bridge_simulate_matchup() {
        let weapon = WeaponProfile::new(
            "Bolt Rifle",
            24,
            ValueExpr::Flat(2),
            3,
            4,
            1,
            ValueExpr::Flat(1),
            vec![],
        );
        let model = ModelProfile::new("Guardsman", 1, 5, None, None);
        let target = UnitProfile::uniform("Guard Squad", 3, model, 10, vec![]);
        let context = CombatContext::default();

        let report = simulate_matchup(weapon, target, context, 500);
        assert!(report.expected_damage_dealt > 0.0);
    }

    #[test]
    fn test_bridge_archetypes() {
        let roster = get_default_archetypes();
        assert_eq!(roster.archetypes.len(), 5);
    }
}
