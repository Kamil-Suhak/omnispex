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
        // Weapon: 3 Attacks, Skill 2+, Strength 4, AP 0, Flat 3 Damage
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

        // Target: 5 models with 2 wounds each, Toughness 4, Save 7+ (auto fail saves)
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
    }

    #[test]
    fn test_lethal_hits_bypasses_wound_step() {
        let weapon = WeaponProfile::new(
            "Lethal Gauss",
            24,
            ValueExpr::Flat(6),
            2,
            1,
            6, // AP 6 (no save)
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
            10, // S10 vs T3 wounds on 2+ (5/6 probability)
            6,  // AP 6 ensures saves fail
            ValueExpr::Flat(1),
            vec![WeaponAbility::Torrent],
        );

        let model = ModelProfile::new("Poxwalker", 1, 7, None, Some(4));
        let target = UnitProfile::uniform("Poxwalker Horde", 3, model, 100, vec![Keyword::Infantry]);

        let report = run_simulation(&weapon, &target, &CombatContext::default(), 5000);
        // Expected damage = 100 * (5/6) * (1/2) = 41.67
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

    #[test]
    fn test_parser_wahapedia_weapon_and_unit() {
        let weapon_raw = r#"Bolt rifle [HEAVY] 24" 2 3+ 4 -1 1 [HEAVY]"#;
        let weapon = parse_weapon_line(weapon_raw).expect("Failed to parse weapon line");
        assert_eq!(weapon.name, "Bolt rifle");
        assert_eq!(weapon.range, 24);
        assert_eq!(weapon.attacks, ValueExpr::Flat(2));
        assert_eq!(weapon.skill, 3);
        assert_eq!(weapon.strength, 4);
        assert_eq!(weapon.ap, 1);
        assert_eq!(weapon.damage, ValueExpr::Flat(1));
        assert!(weapon.has_heavy());

        let unit_raw = r#"
Intercessor Squad
M 6" T 4 SV 3+ W 2
KEYWORDS: INFANTRY, IMPERIUM, TACTICUS
INVULNERABLE SAVE: 4+
FEEL NO PAIN: 6+
MODELS: 10
"#;
        let unit = parse_wahapedia_unit(unit_raw).expect("Failed to parse unit");
        assert_eq!(unit.name, "Intercessor Squad");
        assert_eq!(unit.toughness, 4);
        assert_eq!(unit.models.len(), 10);
        assert_eq!(unit.models[0].save, 3);
        assert_eq!(unit.models[0].wounds, 2);
        assert_eq!(unit.models[0].invulnerable_save, Some(4));
        assert_eq!(unit.models[0].feel_no_pain, Some(6));
        assert!(unit.has_keyword(&Keyword::Infantry));
    }
}
