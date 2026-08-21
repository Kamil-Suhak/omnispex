pub mod domain;
pub mod engine;
pub mod parser;

pub use domain::*;
pub use engine::*;
pub use parser::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_damage_truncation_no_spillover() {
        let weapon = WeaponProfile::new(
            "Heavy Bolter Test",
            36,
            ValueExpr::Flat(3),
            2,
            4,
            0,
            ValueExpr::Flat(3),
            vec![],
        );

        let model = ModelProfile::new("Space Marine", 2, 7, None, None);
        let target = UnitProfile::uniform("Marine Squad", 4, model, 5, vec![Keyword::Infantry]);
        let context = CombatContext::default();

        let report = run_simulation(&weapon, &target, &context, 1000);
        assert!(
            report.expected_models_killed <= 3.0,
            "Cannot kill more models than attack count (no spillover)"
        );
        for &(kills, prob) in &report.kill_distribution {
            if kills > 3 {
                assert_eq!(prob, 0.0, "Kill count {} should have 0 probability", kills);
            }
        }
        assert!(report.spillover_damage_lost > 0.0);
    }

    #[test]
    fn test_tactical_verdict_and_safe_bet_80() {
        // High-power weapon wiping a chaff squad
        let weapon = WeaponProfile::new(
            "Flamer Horde Cleanser",
            12,
            ValueExpr::Flat(50),
            2,
            6,
            2,
            ValueExpr::Flat(1),
            vec![WeaponAbility::Torrent],
        );

        let model = ModelProfile::new("Gretchin", 1, 6, None, None);
        let target = UnitProfile::uniform("Gretchin Horde", 2, model, 10, vec![Keyword::Infantry]);

        let report = run_simulation(&weapon, &target, &CombatContext::default(), 2000);
        assert_eq!(report.tactical_verdict, TacticalVerdict::GreenReliableKill);
        assert!(report.safe_bet_kills_80 >= 9);
        assert!(report.percentiles.p50 >= 9);
    }

    #[test]
    fn test_frag_vs_krak_profile_duel() {
        let frag = WeaponProfile::new(
            "Frag Missile",
            48,
            ValueExpr::D6,
            3,
            4,
            0,
            ValueExpr::Flat(1),
            vec![WeaponAbility::Blast],
        );

        let krak = WeaponProfile::new(
            "Krak Missile",
            48,
            ValueExpr::Flat(1),
            3,
            9,
            2,
            ValueExpr::D6,
            vec![],
        );

        // 1. Target: 10 Guardsmen (Infantry Horde) -> Frag should be recommended
        let guardsman = ModelProfile::new("Guardsman", 1, 5, None, None);
        let horde_target = UnitProfile::uniform("Guard Squad", 3, guardsman, 10, vec![Keyword::Infantry]);

        let comparison_horde = compare_profiles(&[frag.clone(), krak.clone()], &horde_target, &CombatContext::default(), 3000)
            .expect("Comparison failed");
        assert_eq!(comparison_horde.recommended_index, 0, "Frag must be recommended vs 10 Guardsmen");
        assert!(comparison_horde.efficiency_delta_percent > 50.0);

        // 2. Target: Tank (T10, 12W, Sv 3+) -> Krak should be recommended
        let tank_model = ModelProfile::new("Tank", 12, 3, None, None);
        let vehicle_target = UnitProfile::uniform("Battle Tank", 10, tank_model, 1, vec![Keyword::Vehicle]);

        let comparison_tank = compare_profiles(&[frag, krak], &vehicle_target, &CombatContext::default(), 3000)
            .expect("Comparison failed");
        assert_eq!(comparison_tank.recommended_index, 1, "Krak must be recommended vs Heavy Vehicle");
    }

    #[test]
    fn test_archetype_matrix_evaluation() {
        let melta = WeaponProfile::new(
            "Multi-Melta",
            18,
            ValueExpr::Flat(2),
            3,
            9,
            4,
            ValueExpr::D6,
            vec![WeaponAbility::Melta(2)],
        );

        let roster = ArchetypeRoster::default();
        assert_eq!(roster.archetypes.len(), 5);

        let benchmark = evaluate_archetypes(&melta, &roster, &CombatContext::default(), 1000);
        assert_eq!(benchmark.entries.len(), 5);
        assert!(benchmark.entries[0].report.expected_damage_dealt > 0.0);
    }

    #[test]
    fn test_keyword_audit_breakdown() {
        let combi_weapon = WeaponProfile::new(
            "Lethal & Devastating Bolter",
            24,
            ValueExpr::Flat(20),
            2,
            4,
            0,
            ValueExpr::Flat(2),
            vec![
                WeaponAbility::LethalHits,
                WeaponAbility::DevastatingWounds,
                WeaponAbility::SustainedHits(1),
            ],
        );

        let marine = ModelProfile::new("Marine", 2, 3, None, None);
        let target = UnitProfile::uniform("Tactical Squad", 4, marine, 5, vec![Keyword::Infantry]);

        let report = run_simulation(&combi_weapon, &target, &CombatContext::default(), 2000);
        assert!(report.keyword_audit.lethal_damage > 0.0 || report.keyword_audit.devastating_damage > 0.0);
    }

    #[test]
    fn test_model_groups_and_leader_variance() {
        let regular = ModelProfile::new("Terminator", 3, 2, Some(4), None);
        let sergeant = ModelProfile::new("Terminator Sergeant", 4, 2, Some(4), None)
            .with_keywords(vec![Keyword::Character]);

        let target = UnitProfile::new(
            "Terminator Squad",
            5,
            vec![
                ModelGroup::new(4, regular),
                ModelGroup::new(1, sergeant),
            ],
            vec![Keyword::Infantry],
        );

        assert_eq!(target.total_models(), 5);
        let wounds = target.initial_wounds();
        assert_eq!(wounds, vec![3, 3, 3, 3, 4]);
        assert!(target.has_keyword(&Keyword::Character));
    }

    #[test]
    fn test_defensive_abilities_minus_wound_and_damage_reduction() {
        let weapon = WeaponProfile::new(
            "Heavy Gun",
            24,
            ValueExpr::Flat(10),
            2,
            5,
            2,
            ValueExpr::Flat(3),
            vec![WeaponAbility::Torrent],
        );

        let standard_model = ModelProfile::new("Dreadnought", 8, 3, None, None);
        let standard_target = UnitProfile::uniform("Standard Dread", 5, standard_model.clone(), 1, vec![Keyword::Vehicle]);

        let defensive_target = UnitProfile::uniform("Defensive Dread", 5, standard_model, 1, vec![Keyword::Vehicle])
            .with_defensive_abilities(vec![
                DefensiveAbility::MinusWound(1),
                DefensiveAbility::ReduceDamage(1),
            ]);

        let report_std = run_simulation(&weapon, &standard_target, &CombatContext::default(), 3000);
        let report_def = run_simulation(&weapon, &defensive_target, &CombatContext::default(), 3000);

        assert!(
            report_def.expected_damage_dealt < report_std.expected_damage_dealt,
            "Defensive abilities must reduce expected damage (std: {}, def: {})",
            report_std.expected_damage_dealt,
            report_def.expected_damage_dealt
        );
    }

    #[test]
    fn test_lethal_hits_bypasses_wound_step() {
        let weapon = WeaponProfile::new(
            "Lethal Gauss",
            24,
            ValueExpr::Flat(6),
            2,
            1,
            6,
            ValueExpr::Flat(1),
            vec![WeaponAbility::LethalHits],
        );

        let model = ModelProfile::new("Knight", 10, 7, None, None);
        let target = UnitProfile::uniform("Imperial Knight", 10, model, 1, vec![Keyword::Vehicle]);

        let report = run_simulation(&weapon, &target, &CombatContext::default(), 5000);
        assert!(report.expected_damage_dealt > 0.0);
    }

    #[test]
    fn test_devastating_wounds_bypasses_armor_and_invuln() {
        let weapon = WeaponProfile::new(
            "Devastating Combi-Weapon",
            24,
            ValueExpr::Flat(10),
            2,
            4,
            0,
            ValueExpr::Flat(2),
            vec![
                WeaponAbility::DevastatingWounds,
                WeaponAbility::Anti {
                    target: Keyword::Infantry,
                    threshold: 2,
                },
            ],
        );

        let model = ModelProfile::new("Terminator", 3, 2, Some(2), None);
        let target = UnitProfile::uniform("Terminator Squad", 5, model, 5, vec![Keyword::Infantry]);

        let report = run_simulation(&weapon, &target, &CombatContext::default(), 2000);
        assert!(
            report.expected_damage_dealt > 5.0,
            "Devastating wounds must bypass saves"
        );
    }

    #[test]
    fn test_twin_linked_reroll_increases_damage() {
        let base_weapon = WeaponProfile::new(
            "Twin Lascannon Base",
            48,
            ValueExpr::Flat(20),
            3,
            9,
            3,
            ValueExpr::Flat(3),
            vec![],
        );

        let tl_weapon = WeaponProfile::new(
            "Twin Lascannon TL",
            48,
            ValueExpr::Flat(20),
            3,
            9,
            3,
            ValueExpr::Flat(3),
            vec![WeaponAbility::TwinLinked],
        );

        let model = ModelProfile::new("Tank", 10, 3, None, None);
        let target = UnitProfile::uniform("Leman Russ", 11, model, 1, vec![Keyword::Vehicle]);

        let report_base = run_simulation(&base_weapon, &target, &CombatContext::default(), 2000);
        let report_tl = run_simulation(&tl_weapon, &target, &CombatContext::default(), 2000);

        assert!(
            report_tl.expected_damage_dealt > report_base.expected_damage_dealt,
            "Twin-linked must yield higher expected damage via wound re-rolls"
        );
    }

    #[test]
    fn test_anti_keyword_trigger() {
        let anti_weapon = WeaponProfile::new(
            "Haywire Cannon",
            24,
            ValueExpr::Flat(10),
            2,
            3,
            1,
            ValueExpr::Flat(1),
            vec![WeaponAbility::Anti {
                target: Keyword::Vehicle,
                threshold: 4,
            }],
        );

        let vehicle_model = ModelProfile::new("Vehicle Model", 10, 7, None, None);
        let vehicle_target = UnitProfile::uniform("Vehicle Unit", 10, vehicle_model, 1, vec![Keyword::Vehicle]);

        let infantry_model = ModelProfile::new("Infantry Model", 10, 7, None, None);
        let infantry_target = UnitProfile::uniform("Infantry Unit", 10, infantry_model, 1, vec![Keyword::Infantry]);

        let report_veh = run_simulation(&anti_weapon, &vehicle_target, &CombatContext::default(), 2000);
        let report_inf = run_simulation(&anti_weapon, &infantry_target, &CombatContext::default(), 2000);

        assert!(
            report_veh.expected_damage_dealt > report_inf.expected_damage_dealt,
            "Anti-Vehicle 4+ should significantly outperform S3 vs T10 without anti-keyword"
        );
    }

    #[test]
    fn test_feel_no_pain_mitigation() {
        let weapon = WeaponProfile::new(
            "Lasgun Volley",
            24,
            ValueExpr::Flat(100),
            2,
            10,
            6,
            ValueExpr::Flat(1),
            vec![WeaponAbility::Torrent],
        );

        let model = ModelProfile::new("Poxwalker", 1, 7, None, Some(4));
        let target = UnitProfile::uniform("Poxwalker Horde", 3, model, 100, vec![Keyword::Infantry]);

        let report = run_simulation(&weapon, &target, &CombatContext::default(), 5000);
        let theoretical_expected = 100.0 * (5.0 / 6.0) * 0.50;
        let diff = (report.expected_damage_dealt - theoretical_expected).abs();
        assert!(
            diff < 1.0,
            "Expected damage close to {}, got {}",
            theoretical_expected,
            report.expected_damage_dealt
        );
    }

    #[test]
    fn test_blast_and_rapid_fire() {
        let weapon = WeaponProfile::new(
            "Plasma Cannon",
            24,
            ValueExpr::Flat(2),
            3,
            7,
            2,
            ValueExpr::Flat(1),
            vec![WeaponAbility::Blast, WeaponAbility::RapidFire(2)],
        );

        let model = ModelProfile::new("Guardsman", 1, 5, None, None);
        let target = UnitProfile::uniform("Guard Squad", 3, model, 20, vec![Keyword::Infantry]);

        let context = CombatContext::default().with_distance(10);
        let mut wounds = target.initial_wounds();
        let mut rng = rand::thread_rng();
        let outcome = resolve_volley(&weapon, &target, &context, &mut wounds, &mut rng);

        assert_eq!(outcome.attacks_generated, 8);
    }
}

