pub mod common;
pub mod domain;
pub mod engine;
pub mod kill_team;
pub mod parser;
pub mod storage;
pub mod wh40k;

pub use domain::*;
pub use engine::*;
pub use parser::*;
pub use storage::*;

#[cfg(target_arch = "wasm32")]
mod wasm_rng {
    use std::sync::atomic::{AtomicU64, Ordering};

    static STATE: AtomicU64 = AtomicU64::new(0x9E37_79B9_7F4A_7C15);

    fn wasm_getrandom(dest: &mut [u8]) -> Result<(), getrandom::Error> {
        let mut s = STATE.load(Ordering::Relaxed);
        if s == 0 {
            s = 0x9E37_79B9_7F4A_7C15;
        }
        for chunk in dest.chunks_mut(8) {
            s ^= s >> 12;
            s ^= s << 25;
            s ^= s >> 27;
            let val = s.wrapping_mul(0x2545_F491_4F6C_DD1D);
            let bytes = val.to_le_bytes();
            for (i, b) in chunk.iter_mut().enumerate() {
                *b = bytes[i];
            }
        }
        STATE.store(s, Ordering::Relaxed);
        Ok(())
    }

    getrandom::register_custom_getrandom!(wasm_getrandom);
}

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

        let guardsman = ModelProfile::new("Guardsman", 1, 5, None, None);
        let horde_target =
            UnitProfile::uniform("Guard Squad", 3, guardsman, 10, vec![Keyword::Infantry]);

        let comparison_horde = compare_profiles(
            &[frag.clone(), krak.clone()],
            &horde_target,
            &CombatContext::default(),
            3000,
        )
        .expect("Comparison failed");
        assert_eq!(
            comparison_horde.recommended_index, 0,
            "Frag must be recommended vs 10 Guardsmen"
        );
        assert!(comparison_horde.efficiency_delta_percent > 50.0);

        let tank_model = ModelProfile::new("Tank", 12, 3, None, None);
        let vehicle_target =
            UnitProfile::uniform("Battle Tank", 10, tank_model, 1, vec![Keyword::Vehicle]);

        let comparison_tank =
            compare_profiles(&[frag, krak], &vehicle_target, &CombatContext::default(), 3000)
                .expect("Comparison failed");
        assert_eq!(
            comparison_tank.recommended_index, 1,
            "Krak must be recommended vs Heavy Vehicle"
        );
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
        assert!(
            report.keyword_audit.lethal_damage > 0.0
                || report.keyword_audit.devastating_damage > 0.0
        );
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
        let standard_target = UnitProfile::uniform(
            "Standard Dread",
            5,
            standard_model.clone(),
            1,
            vec![Keyword::Vehicle],
        );

        let defensive_target =
            UnitProfile::uniform("Defensive Dread", 5, standard_model, 1, vec![Keyword::Vehicle])
                .with_defensive_abilities(vec![
                    DefensiveAbility::MinusWound(1),
                    DefensiveAbility::ReduceDamage(1),
                ]);

        let report_std = run_simulation(&weapon, &standard_target, &CombatContext::default(), 3000);
        let report_def =
            run_simulation(&weapon, &defensive_target, &CombatContext::default(), 3000);

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
        let target =
            UnitProfile::uniform("Imperial Knight", 10, model, 1, vec![Keyword::Vehicle]);

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
        let target =
            UnitProfile::uniform("Terminator Squad", 5, model, 5, vec![Keyword::Infantry]);

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
        let vehicle_target =
            UnitProfile::uniform("Vehicle Unit", 10, vehicle_model, 1, vec![Keyword::Vehicle]);

        let infantry_model = ModelProfile::new("Infantry Model", 10, 7, None, None);
        let infantry_target =
            UnitProfile::uniform("Infantry Unit", 10, infantry_model, 1, vec![Keyword::Infantry]);

        let report_veh =
            run_simulation(&anti_weapon, &vehicle_target, &CombatContext::default(), 2000);
        let report_inf =
            run_simulation(&anti_weapon, &infantry_target, &CombatContext::default(), 2000);

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
        let target =
            UnitProfile::uniform("Poxwalker Horde", 3, model, 100, vec![Keyword::Infantry]);

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

    #[test]
    fn test_bsdata_parser_unit_and_weapons() {
        use parser::BsDataParser;

        let sample_json = r#"{
            "catalogue": {
                "id": "ork-cat-1",
                "name": "Xenos - Orks",
                "revision": 2,
                "sharedSelectionEntries": [
                    {
                        "name": "Battlewagon",
                        "type": "model",
                        "costs": [{ "name": "pts", "value": 160 }],
                        "categoryLinks": [
                            { "name": "Vehicle" },
                            { "name": "Transport" }
                        ],
                        "profiles": [
                            {
                                "name": "Battlewagon",
                                "typeName": "Unit",
                                "characteristics": [
                                    { "name": "M", "$text": "10\"" },
                                    { "name": "T", "$text": "10" },
                                    { "name": "Sv", "$text": "3+" },
                                    { "name": "W", "$text": "16" },
                                    { "name": "InSv", "$text": "6+" }
                                ]
                            },
                            {
                                "name": "Ramshackle but Rugged",
                                "typeName": "Abilities",
                                "characteristics": [
                                    { "name": "Description", "$text": "worsen the Armour Penetration characteristic of that attack by 1." }
                                ]
                            }
                        ],
                        "selectionEntryGroups": [
                            {
                                "selectionEntries": [
                                    {
                                        "name": "Killkannon",
                                        "type": "upgrade",
                                        "profiles": [
                                            {
                                                "name": "Killkannon",
                                                "typeName": "Ranged Weapons",
                                                "characteristics": [
                                                    { "name": "Range", "$text": "24\"" },
                                                    { "name": "A", "$text": "D6+1" },
                                                    { "name": "BS", "$text": "5+" },
                                                    { "name": "S", "$text": "9" },
                                                    { "name": "AP", "$text": "-2" },
                                                    { "name": "D", "$text": "2" },
                                                    { "name": "Keywords", "$text": "BLAST" }
                                                ]
                                            }
                                        ]
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        }"#;

        let faction = BsDataParser::parse_catalogue_json(sample_json).expect("Parse failed");
        assert_eq!(faction.name, "Xenos - Orks");
        assert_eq!(faction.units.len(), 1);

        let unit = &faction.units[0];
        assert_eq!(unit.name, "Battlewagon");
        assert_eq!(unit.points_cost, Some(160));
        assert_eq!(unit.profile.toughness, 10);
        let models = unit.profile.expanded_models();
        assert_eq!(models[0].save, 3);
        assert_eq!(models[0].wounds, 16);
        assert_eq!(models[0].invulnerable_save, Some(6));
        assert!(unit
            .profile
            .defensive_abilities
            .contains(&domain::DefensiveAbility::MinusOneAp));

        assert_eq!(unit.weapons.len(), 1);
        let weapon = &unit.weapons[0];
        assert_eq!(weapon.name, "Killkannon");
        assert_eq!(weapon.range, 24);
        assert_eq!(weapon.strength, 9);
        assert_eq!(weapon.ap, 2);
        assert!(weapon.has_blast());
    }

    #[test]
    fn test_exact_stage_probabilities_vs_simulation() {
        let weapon = WeaponProfile::new(
            "Bolt Rifle",
            24,
            ValueExpr::Flat(10),
            3,
            4,
            1,
            ValueExpr::Flat(1),
            vec![],
        );
        let model = ModelProfile::new("Monolith", 30, 3, None, None);
        let target = UnitProfile::uniform("Monolith", 4, model, 1, vec![Keyword::Vehicle]);
        let ctx = CombatContext::default()
            .with_hit_reroll(ReRollMode::Ones)
            .with_wound_reroll(ReRollMode::Ones);

        let report = run_simulation(&weapon, &target, &ctx, 15_000);
        let exact = &report.stage_probabilities;

        assert!((exact.hit_probability - (28.0 / 36.0)).abs() < 1e-6);
        assert!((exact.wound_probability - (21.0 / 36.0)).abs() < 1e-6);
        assert!((exact.unsaved_probability_given_normal_wound - 0.5).abs() < 1e-6);

        let diff = (report.expected_damage_dealt - exact.expected_total_unclipped_damage).abs();
        assert!(
            diff < 0.15,
            "Monte Carlo damage ({}) must match exact analytical expectation ({}) within tolerance",
            report.expected_damage_dealt,
            exact.expected_total_unclipped_damage
        );
    }

    #[test]
    fn test_squad_multi_weapon_simulation() {
        let bolter = WeaponProfile::new(
            "Bolt Rifle",
            24,
            ValueExpr::Flat(2),
            3,
            4,
            1,
            ValueExpr::Flat(1),
            vec![],
        );
        let plasma = WeaponProfile::new(
            "Plasma Pistol Supercharge",
            12,
            ValueExpr::Flat(1),
            3,
            8,
            3,
            ValueExpr::Flat(2),
            vec![WeaponAbility::Hazardous],
        );

        let loadout = vec![
            WeaponLoadoutEntry::new(bolter, 4),
            WeaponLoadoutEntry::new(plasma, 1),
        ];

        let model = ModelProfile::new("Ork Boy", 1, 5, None, None);
        let target = UnitProfile::uniform("Boyz", 5, model, 10, vec![Keyword::Infantry]);
        let report = run_squad_simulation(&loadout, &target, &CombatContext::default(), 3000);

        assert!((report.stage_probabilities.expected_attacks - 9.0).abs() < 1e-6);
        assert!(report.expected_models_killed > 1.5);
        assert!(!report.unsupported_notices.is_empty());
    }

    #[test]
    fn test_11e_mfm_requisition_pricing_and_list_validation() {
        let mfm_yaml = r#"
name: Orks
slug: orks
version: "1.6"
detachments:
  - name: War Horde
    dp: 3
    objectives: [TAKE AND HOLD, PURGE THE FOE]
    enhancements:
      - { name: Headwoppa's Killchoppa, points: 15 }
  - name: Taktikal Brigade
    dp: 1
    objectives: [TAKE AND HOLD]
    enhancements:
      - { name: Throat-slittas (Upgrade), points: 15 }
units:
  - name: Battlewagon
    pricing:
      - range: "[1,2]"
        label: Your 1st To 2nd Units Cost
        costs: [{ models: 1, points: 160 }]
      - range: "[3,)"
        label: Your 3rd + Unit Costs
        costs: [{ models: 1, points: 180 }]
    wargear:
      - { item: Zzap gun, points: 5 }
  - name: Warboss
    pricing:
      - range: "[1,)"
        label: Your Unit Costs
        costs: [{ models: 1, points: 70 }]
    leaderTo: [Boyz]
  - name: Boyz
    pricing:
      - range: "[1,)"
        label: Your Unit Costs
        costs:
          - { models: 10, points: 85 }
          - { models: 20, points: 170 }
"#;
        let mfm = parse_mfm_faction_yaml(mfm_yaml).expect("MFM YAML parse failed");
        let mut faction = FactionCatalogue {
            id: "orks-id".to_string(),
            slug: "orks".to_string(),
            name: "Orks".to_string(),
            parent_faction: None,
            revision: Some(1),
            army_rules: vec![],
            detachments: vec![],
            units: vec![
                DatasheetUnit {
                    id: "u-bw".to_string(),
                    name: "Battlewagon".to_string(),
                    faction_id: "orks-id".to_string(),
                    faction_name: "Orks".to_string(),
                    group_title: None,
                    is_legends: false,
                    points_cost: None,
                    profile: UnitProfile::default(),
                    weapons: vec![],
                    abilities: vec![],
                    categories: vec!["Vehicle".to_string()],
                    unit_composition: vec![],
                    wargear_options: vec![],
                    pricing_tiers: vec![],
                    wargear_costs: vec![],
                    leader_to: vec![],
                    support_to: vec![],
                    transport_capacity: None,
                },
                DatasheetUnit {
                    id: "u-wb".to_string(),
                    name: "Warboss".to_string(),
                    faction_id: "orks-id".to_string(),
                    faction_name: "Orks".to_string(),
                    group_title: None,
                    is_legends: false,
                    points_cost: None,
                    profile: UnitProfile::default(),
                    weapons: vec![],
                    abilities: vec![],
                    categories: vec!["Character".to_string(), "Infantry".to_string()],
                    unit_composition: vec![],
                    wargear_options: vec![],
                    pricing_tiers: vec![],
                    wargear_costs: vec![],
                    leader_to: vec![],
                    support_to: vec![],
                    transport_capacity: None,
                },
                DatasheetUnit {
                    id: "u-boyz".to_string(),
                    name: "Boyz".to_string(),
                    faction_id: "orks-id".to_string(),
                    faction_name: "Orks".to_string(),
                    group_title: None,
                    is_legends: false,
                    points_cost: None,
                    profile: UnitProfile::default(),
                    weapons: vec![],
                    abilities: vec![],
                    categories: vec!["Battleline".to_string(), "Infantry".to_string()],
                    unit_composition: vec![],
                    wargear_options: vec![],
                    pricing_tiers: vec![],
                    wargear_costs: vec![],
                    leader_to: vec![],
                    support_to: vec![],
                    transport_capacity: None,
                },
            ],
            warnings: vec![],
        };
        merge_mfm_into_faction(&mut faction, &mfm);

        let mut list = ArmyList {
            id: "list-1".to_string(),
            name: "Waaagh Roster".to_string(),
            faction_id: "orks-id".to_string(),
            faction_name: "Orks".to_string(),
            battle_size: BattleSize::StrikeForce,
            points_limit: 2000,
            detachments: vec![SelectedDetachment {
                id: "det-orks-war-horde".to_string(),
                name: "War Horde".to_string(),
                dp_cost: 3,
                unique_tag: None,
            }],
            units: vec![],
            notes: String::new(),
            created_at_iso: "2026-10-26T00:00:00Z".to_string(),
            updated_at_iso: "2026-10-26T00:00:00Z".to_string(),
        };

        list.units.push(RosterUnitEntry {
            entry_id: "e-wb".to_string(),
            unit_id: "u-wb".to_string(),
            unit_name: "Warboss".to_string(),
            models_count: 1,
            option_description: None,
            base_points: 0,
            requisition_tier_label: None,
            selected_wargear: vec![],
            enhancement_id: Some("enh-1".to_string()),
            enhancement_name: Some("Headwoppa's Killchoppa".to_string()),
            enhancement_points: 15,
            enhancement_is_upgrade: false,
            is_warlord: true,
            attached_to_entry_id: None,
            categories: vec!["Character".to_string()],
            custom_weapons: vec![],
            notes: String::new(),
        });

        for i in 1..=3 {
            list.units.push(RosterUnitEntry {
                entry_id: format!("e-bw-{}", i),
                unit_id: "u-bw".to_string(),
                unit_name: "Battlewagon".to_string(),
                models_count: 1,
                option_description: None,
                base_points: 0,
                requisition_tier_label: None,
                selected_wargear: vec![],
                enhancement_id: None,
                enhancement_name: None,
                enhancement_points: 0,
                enhancement_is_upgrade: false,
                is_warlord: false,
                attached_to_entry_id: None,
                categories: vec!["Vehicle".to_string()],
                custom_weapons: vec![],
                notes: String::new(),
            });
        }

        list.recalculate_points(&faction);
        assert_eq!(list.units[1].base_points, 160, "1st Battlewagon = 160 pts");
        assert_eq!(list.units[2].base_points, 160, "2nd Battlewagon = 160 pts");
        assert_eq!(
            list.units[3].base_points, 180,
            "3rd Battlewagon = 180 pts (Requisition tier [3,))"
        );

        let db = CatalogueDatabase {
            provenance: DataProvenance::default(),
            factions: vec![faction],
        };
        let report = validate_army_list(&list, Some(&db));
        assert!(
            report.is_valid,
            "Roster should be valid: {:?}",
            report.violations
        );
        assert_eq!(report.total_points, 70 + 15 + 160 + 160 + 180);
    }

    #[test]
    fn test_wishlist_deduplication_and_summary() {
        let mut items = Vec::new();
        let item1 = WishlistItem {
            id: "w1".to_string(),
            faction_id: "orks".to_string(),
            faction_name: "Orks".to_string(),
            unit_id: "u-boyz".to_string(),
            unit_name: "Boyz".to_string(),
            quantity_desired: 2,
            quantity_owned: 1,
            points_per_unit: 85,
            priority: WishlistPriority::High,
            state: AcquisitionState::Assembled,
            notes: String::new(),
            updated_at_iso: "2026-10-26T00:00:00Z".to_string(),
        };
        upsert_wishlist_item(&mut items, item1);
        assert_eq!(items.len(), 1);

        let item2 = WishlistItem {
            id: "w2".to_string(),
            faction_id: "orks".to_string(),
            faction_name: "Orks".to_string(),
            unit_id: "u-boyz".to_string(),
            unit_name: "Boyz".to_string(),
            quantity_desired: 3,
            quantity_owned: 1,
            points_per_unit: 85,
            priority: WishlistPriority::Critical,
            state: AcquisitionState::BattleReady,
            notes: "Green Tide core".to_string(),
            updated_at_iso: "2026-10-26T01:00:00Z".to_string(),
        };
        upsert_wishlist_item(&mut items, item2);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].quantity_desired, 3);

        let summary = compute_wishlist_summary(&items, Some("orks"));
        assert_eq!(summary.total_distinct_units, 1);
        assert_eq!(summary.total_boxes_desired, 3);
        assert_eq!(summary.total_points_desired, 255);
    }

    #[test]
    fn test_match_statistics_40k_and_kill_team() {
        let m1 = MatchRecord {
            id: "m1".to_string(),
            game_system: GameSystem::Warhammer40k,
            date_iso: "2026-10-20".to_string(),
            player_faction: "Orks".to_string(),
            opponent_faction: "Necrons".to_string(),
            opponent_name: "Alex".to_string(),
            player_score: 85,
            opponent_score: 65,
            result: MatchResult::from_scores(85, 65),
            is_detailed: false,
            wh40k_details: Some(Wh40kMatchDetails::default()),
            kill_team_details: None,
            notes: String::new(),
            created_at_iso: "2026-10-20T00:00:00Z".to_string(),
            updated_at_iso: "2026-10-20T00:00:00Z".to_string(),
        };
        assert_eq!(m1.result, MatchResult::Win);

        let m2 = MatchRecord {
            id: "m2".to_string(),
            game_system: GameSystem::KillTeam,
            date_iso: "2026-10-21".to_string(),
            player_faction: "Kommandos".to_string(),
            opponent_faction: "Pathfinders".to_string(),
            opponent_name: "Sam".to_string(),
            player_score: 14,
            opponent_score: 18,
            result: MatchResult::from_scores(14, 18),
            is_detailed: false,
            wh40k_details: None,
            kill_team_details: Some(KillTeamMatchDetails::default()),
            notes: String::new(),
            created_at_iso: "2026-10-21T00:00:00Z".to_string(),
            updated_at_iso: "2026-10-21T00:00:00Z".to_string(),
        };
        assert_eq!(m2.result, MatchResult::Loss);

        let all = vec![m1, m2];
        let stats_all = compute_match_statistics(&all, None, None);
        assert_eq!(stats_all.total_completed_games, 2);
        assert_eq!(stats_all.wins, 1);
        assert_eq!(stats_all.losses, 1);

        let filtered_kt = filter_matches(&all, Some(GameSystem::KillTeam), "", None, None);
        assert_eq!(filtered_kt.len(), 1);
        assert_eq!(filtered_kt[0].player_faction, "Kommandos");
    }

    #[test]
    fn test_personal_data_store_migration_and_backup() {
        let legacy_json =
            r#"{"schema_version": 0, "army_lists": [], "wishlist_items": [], "matches": []}"#;
        let store = PersonalDataStore::from_json_migrated(legacy_json).expect("Migration failed");
        assert_eq!(store.schema_version, CURRENT_PERSONAL_SCHEMA_VERSION);
        assert_eq!(store.custom_archetypes.archetypes.len(), 5);
        assert_eq!(store.settings.default_iterations, 10_000);
    }

    #[test]
    fn test_strict_wh40k_and_kill_team_module_isolation() {
        use std::fs;
        use std::path::Path;

        fn collect_rs_files(dir: &Path, out: &mut Vec<(String, String)>) {
            if let Ok(entries) = fs::read_dir(dir) {
                for entry in entries.flatten() {
                    let p = entry.path();
                    if p.is_dir() {
                        collect_rs_files(&p, out);
                    } else if p.extension().and_then(|s| s.to_str()) == Some("rs") {
                        if let Ok(content) = fs::read_to_string(&p) {
                            out.push((p.display().to_string(), content));
                        }
                    }
                }
            }
        }

        let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
        let mut wh40k_files = Vec::new();
        collect_rs_files(&manifest_dir.join("src/wh40k"), &mut wh40k_files);
        assert!(!wh40k_files.is_empty());
        for (path, content) in &wh40k_files {
            assert!(
                !content.contains("kill_team") && !content.contains("KillTeam"),
                "wh40k module file {} must not reference kill_team",
                path
            );
        }

        let mut kt_files = Vec::new();
        collect_rs_files(&manifest_dir.join("src/kill_team"), &mut kt_files);
        assert!(!kt_files.is_empty());
        for (path, content) in &kt_files {
            assert!(
                !content.contains("wh40k") && !content.contains("Warhammer40k"),
                "kill_team module file {} must not reference wh40k",
                path
            );
        }
    }

    #[test]
    fn test_half_damage_applies_before_melta_and_minus_one_damage_non_stacking() {
        // 40K Rules Commentary (Modifiers & Melta):
        // Base D = 4, HalfDamage -> ceil(4 / 2) = 2, + Melta 2 = 4.
        // If Melta were added before HalfDamage, it would be ceil((4 + 2)/2) = 3.
        let melta_gun = WeaponProfile::new(
            "Test Melta",
            18,
            ValueExpr::Flat(1),
            2,
            24,
            4,
            ValueExpr::Flat(4),
            vec![
                WeaponAbility::Torrent,
                WeaponAbility::Melta(2),
                WeaponAbility::Anti {
                    target: Keyword::Monster,
                    threshold: 2,
                },
                WeaponAbility::DevastatingWounds,
            ],
        );

        let model = ModelProfile::new("Avatar", 14, 7, None, None);
        let target = UnitProfile::uniform("Avatar", 11, model, 1, vec![Keyword::Monster])
            .with_defensive_abilities(vec![DefensiveAbility::HalfDamage]);

        let ctx = CombatContext::default()
            .with_distance(6)
            .with_wound_reroll(ReRollMode::Full);
        let probs = compute_exact_stage_probabilities(&melta_gun, &target, &ctx);
        assert!(
            (probs.expected_damage_per_unsaved - 4.0).abs() < 1e-6,
            "HalfDamage must divide base damage (4->2) BEFORE adding Melta 2 (=4), got {}",
            probs.expected_damage_per_unsaved
        );

        let mut rng = rand::thread_rng();
        for _ in 0..20 {
            let mut wounds = target.initial_wounds();
            let outcome = resolve_volley(&melta_gun, &target, &ctx, &mut wounds, &mut rng);
            if outcome.wounds_inflicted > 0 {
                assert_eq!(outcome.damage_dealt, 4);
            }
        }

        // Verify -1 Damage on datasheet and context.minus_one_damage do NOT stack to -2
        let dread_model = ModelProfile::new("Dreadnought", 12, 7, None, None);
        let dread_target =
            UnitProfile::uniform("Dreadnought", 10, dread_model, 1, vec![Keyword::Vehicle])
                .with_defensive_abilities(vec![DefensiveAbility::DamageReduction(1)]);
        let mut ctx_minus = CombatContext::default();
        ctx_minus.minus_one_damage = true;

        let probs_dread =
            compute_exact_stage_probabilities(&melta_gun, &dread_target, &ctx_minus);
        assert!(
            (probs_dread.expected_damage_per_unsaved - 3.0).abs() < 1e-6,
            "Duplicate -1 Damage sources must not stack to -2 (expected 4 - 1 = 3, got {})",
            probs_dread.expected_damage_per_unsaved
        );
    }

    #[test]
    fn test_squad_blast_uses_declaration_model_count() {
        let frag_first = WeaponProfile::new(
            "Auto-Wipe Cannon",
            24,
            ValueExpr::Flat(15),
            2,
            10,
            6,
            ValueExpr::Flat(2),
            vec![WeaponAbility::Torrent],
        );
        let blast_second = WeaponProfile::new(
            "Secondary Blast Gun",
            24,
            ValueExpr::Flat(1),
            3,
            4,
            0,
            ValueExpr::Flat(1),
            vec![WeaponAbility::Blast],
        );
        let loadout = vec![
            WeaponLoadoutEntry::new(frag_first, 1),
            WeaponLoadoutEntry::new(blast_second, 1),
        ];

        // Target has 10 models (1W each, 7+ save), except 1 model has 10W so the unit survives weapon 1
        // with only 1 model left alive. Weapon 2 must still receive +2 Blast attacks from the 10 models at declaration!
        let chaff = ModelProfile::new("Trooper", 1, 7, None, None);
        let tanky_leader = ModelProfile::new("Boss", 50, 7, None, None);
        let target = UnitProfile::new(
            "Mixed Squad",
            3,
            vec![ModelGroup::new(9, chaff), ModelGroup::new(1, tanky_leader)],
            vec![Keyword::Infantry],
        );

        let mut wounds = target.initial_wounds();
        let mut rng = rand::thread_rng();
        let outcome = resolve_squad_volley(
            &loadout,
            &target,
            &CombatContext::default(),
            &mut wounds,
            &mut rng,
        );
        // Weapon 1 generates 15 attacks, kills all 9 chaff models (leaving 1 model alive).
        // Weapon 2 generates 1 base + (10 / 5 = 2) Blast attacks = 3 attacks -> total = 18!
        assert_eq!(
            outcome.attacks_generated, 18,
            "Second weapon in squad must use initial declaration model count (10) for Blast (+2)"
        );
    }

    #[test]
    fn test_dice_valued_weapon_abilities_and_custom_preservation() {
        assert_eq!(
            parse_weapon_ability("Sustained Hits D3"),
            Some(WeaponAbility::SustainedHitsDice(ValueExpr::D3))
        );
        assert_eq!(
            parse_weapon_ability("Rapid Fire D6+1"),
            Some(WeaponAbility::RapidFireDice(ValueExpr::D6Plus(1)))
        );
        assert_eq!(
            parse_weapon_ability("Melta D3"),
            Some(WeaponAbility::MeltaDice(ValueExpr::D3))
        );
        assert_eq!(
            parse_weapon_ability("Conversion"),
            Some(WeaponAbility::Custom("Conversion".to_string()))
        );
    }

    #[test]
    fn test_dedicated_transport_and_multi_leader_list_validation() {
        let cat = wh40k::default_wh40k_seed_catalogue();
        let mut list = ArmyList {
            id: "test-dt".to_string(),
            name: "Transport Test".to_string(),
            faction_id: "sm-seed".to_string(),
            faction_name: "Space Marines".to_string(),
            battle_size: BattleSize::Incursion,
            points_limit: 1000,
            detachments: vec![SelectedDetachment {
                id: "det-sm-gladius".to_string(),
                name: "Gladius Task Force".to_string(),
                dp_cost: 3,
                unique_tag: None,
            }],
            units: vec![
                RosterUnitEntry {
                    entry_id: "c1".to_string(),
                    unit_id: "sm-captain".to_string(),
                    unit_name: "Captain".to_string(),
                    models_count: 1,
                    option_description: None,
                    base_points: 80,
                    requisition_tier_label: None,
                    selected_wargear: vec![],
                    enhancement_id: Some("enh-1".to_string()),
                    enhancement_name: Some("Fire Discipline".to_string()),
                    enhancement_points: 25,
                    enhancement_is_upgrade: false,
                    is_warlord: true,
                    attached_to_entry_id: Some("bg1".to_string()),
                    categories: vec!["Character".to_string(), "Infantry".to_string()],
                    custom_weapons: vec![],
                    notes: String::new(),
                },
                RosterUnitEntry {
                    entry_id: "c2".to_string(),
                    unit_id: "sm-captain".to_string(),
                    unit_name: "Captain".to_string(),
                    models_count: 1,
                    option_description: None,
                    base_points: 80,
                    requisition_tier_label: None,
                    selected_wargear: vec![],
                    enhancement_id: Some("enh-2".to_string()),
                    enhancement_name: Some("The Honour Vehement".to_string()),
                    enhancement_points: 15,
                    enhancement_is_upgrade: false,
                    is_warlord: false,
                    attached_to_entry_id: Some("bg1".to_string()),
                    categories: vec!["Character".to_string(), "Infantry".to_string()],
                    custom_weapons: vec![],
                    notes: String::new(),
                },
                RosterUnitEntry {
                    entry_id: "bg1".to_string(),
                    unit_id: "sm-intercessors".to_string(),
                    unit_name: "Intercessor Squad".to_string(),
                    models_count: 5,
                    option_description: None,
                    base_points: 80,
                    requisition_tier_label: None,
                    selected_wargear: vec![],
                    enhancement_id: None,
                    enhancement_name: None,
                    enhancement_points: 0,
                    enhancement_is_upgrade: false,
                    is_warlord: false,
                    attached_to_entry_id: None,
                    categories: vec!["Battleline".to_string(), "Infantry".to_string()],
                    custom_weapons: vec![],
                    notes: String::new(),
                },
                RosterUnitEntry {
                    entry_id: "dt1".to_string(),
                    unit_id: "sm-impulsor".to_string(),
                    unit_name: "Impulsor".to_string(),
                    models_count: 1,
                    option_description: None,
                    base_points: 80,
                    requisition_tier_label: None,
                    selected_wargear: vec![],
                    enhancement_id: None,
                    enhancement_name: None,
                    enhancement_points: 0,
                    enhancement_is_upgrade: false,
                    is_warlord: false,
                    attached_to_entry_id: None,
                    categories: vec![
                        "Vehicle".to_string(),
                        "Dedicated Transport".to_string(),
                    ],
                    custom_weapons: vec![],
                    notes: String::new(),
                },
                RosterUnitEntry {
                    entry_id: "dt2".to_string(),
                    unit_id: "sm-impulsor".to_string(),
                    unit_name: "Impulsor".to_string(),
                    models_count: 1,
                    option_description: None,
                    base_points: 80,
                    requisition_tier_label: None,
                    selected_wargear: vec![],
                    enhancement_id: None,
                    enhancement_name: None,
                    enhancement_points: 0,
                    enhancement_is_upgrade: false,
                    is_warlord: false,
                    attached_to_entry_id: None,
                    categories: vec![
                        "Vehicle".to_string(),
                        "Dedicated Transport".to_string(),
                    ],
                    custom_weapons: vec![],
                    notes: String::new(),
                },
            ],
            notes: String::new(),
            created_at_iso: String::new(),
            updated_at_iso: String::new(),
        };

        let report = validate_army_list(&list, Some(&cat));
        assert!(!report.is_valid);
        let codes: Vec<&str> = report.violations.iter().map(|v| v.code.as_str()).collect();
        assert!(
            codes.contains(&"MAX_LEADERS_EXCEEDED"),
            "Should flag 2 non-Support Captains attached to 1 Intercessor Squad: {:?}",
            codes
        );
        assert!(
            codes.contains(&"ATTACHED_UNIT_DUPLICATE_ENHANCEMENT"),
            "Should flag 2 Enhancements in the same Attached Unit: {:?}",
            codes
        );
        assert!(
            codes.contains(&"DEDICATED_TRANSPORT_UNEMBARKED"),
            "Should flag 2 Dedicated Transports with only 1 independent unit able to embark: {:?}",
            codes
        );

        // Chained leader attachment check
        list.units[1].attached_to_entry_id = Some("c1".to_string());
        let report_chain = validate_army_list(&list, Some(&cat));
        assert!(report_chain
            .violations
            .iter()
            .any(|v| v.code == "CHAINED_LEADER_ATTACHMENT"));
    }

    #[test]
    fn test_kt24_shooting_and_fight_engines_and_roster_validation() {
        use kill_team::*;

        let kt_cat = default_kill_team_catalogue();
        assert!(kt_cat.factions.len() >= 16);

        let aod = kt_cat.find_faction("angels-of-death").unwrap();
        let sniper = aod
            .operatives
            .iter()
            .find(|o| o.name == "Eliminator Sniper")
            .unwrap();
        let mortis_rifle = &sniper.weapons[1]; // Devastating 3, Piercing 1

        let kommando_faction = kt_cat.find_faction("kommandos").unwrap();
        let ork_boy = kommando_faction
            .operatives
            .iter()
            .find(|o| o.name == "Kommando Boy")
            .unwrap();

        let shoot_rep = run_kt_shooting_simulation(
            mortis_rifle,
            ork_boy,
            &KtShootingContext::default(),
            3000,
        );
        assert!(shoot_rep.expected_damage_dealt > 6.0);
        assert!(shoot_rep.stage_probabilities.expected_devastating_damage > 0.0);

        // Obscured target must downgrade all crits (0 devastating damage) and reduce damage
        let mut obs_ctx = KtShootingContext::default();
        obs_ctx.target_obscured = true;
        let obs_rep = run_kt_shooting_simulation(mortis_rifle, ork_boy, &obs_ctx, 3000);
        assert_eq!(obs_rep.stage_probabilities.expected_critical_hits, 0.0);
        assert_eq!(obs_rep.stage_probabilities.expected_devastating_damage, 0.0);
        assert!(obs_rep.expected_damage_dealt < shoot_rep.expected_damage_dealt);

        // Fight (Melee Strike/Parry Duel): Captain (Power Fist, Brutal, 15W) vs Kommando Boy (Choppa, 10W)
        let captain = &aod.operatives[0];
        let power_fist = &captain.weapons[2];
        let choppa = &ork_boy.weapons[1];
        let fight_rep = run_kt_fight_simulation(
            captain,
            power_fist,
            ork_boy,
            choppa,
            &KtFightContext::default(),
            2000,
        );
        assert!(
            fight_rep.attacker_kill_probability > 0.65,
            "Space Marine Captain with Power Fist should have >65% kill probability vs 10W Kommando Boy (got {})",
            fight_rep.attacker_kill_probability
        );
        assert!(fight_rep.attacker_survival_probability > 0.90);

        // KT24 Roster Validation: 1 Leader + 5 Warriors = 6 Operatives, max 4 Equipment
        let warrior = aod
            .operatives
            .iter()
            .find(|o| o.name == "Intercessor Warrior")
            .unwrap();
        let mut roster = KillTeamRoster {
            id: "r1".to_string(),
            name: "AoD Strike Team".to_string(),
            faction_id: aod.id.clone(),
            faction_name: aod.name.clone(),
            selected_archetype: "Seek & Destroy".to_string(),
            operatives: vec![KtRosterOperative {
                entry_id: "op-1".to_string(),
                operative_id: captain.id.clone(),
                operative_name: captain.name.clone(),
                role: captain.role.clone(),
                is_leader: true,
                apl: captain.apl,
                movement: captain.movement,
                save: captain.save,
                wounds: captain.wounds,
                selected_weapons: captain.weapons.clone(),
                custom_name: String::new(),
                notes: String::new(),
            }],
            equipment: vec![],
            notes: String::new(),
            created_at_iso: String::new(),
            updated_at_iso: String::new(),
        };
        for i in 2..=6 {
            roster.operatives.push(KtRosterOperative {
                entry_id: format!("op-{}", i),
                operative_id: warrior.id.clone(),
                operative_name: warrior.name.clone(),
                role: warrior.role.clone(),
                is_leader: false,
                apl: warrior.apl,
                movement: warrior.movement,
                save: warrior.save,
                wounds: warrior.wounds,
                selected_weapons: warrior.weapons.clone(),
                custom_name: String::new(),
                notes: String::new(),
            });
        }

        let val_ok = validate_kill_team_roster(&roster, Some(&kt_cat));
        assert!(
            val_ok.is_valid,
            "6-operative AoD roster with 1 Leader must be valid: {:?}",
            val_ok.violations
        );

        // Add 5 equipment options -> must fail KT24_EQUIPMENT_LIMIT (4)
        for i in 1..=5 {
            roster.equipment.push(KtSelectedEquipment {
                equipment_id: format!("eq-{}", i),
                name: format!("Equipment {}", i),
                is_universal: true,
            });
        }
        let val_eq_fail = validate_kill_team_roster(&roster, Some(&kt_cat));
        assert!(!val_eq_fail.is_valid);
        assert!(val_eq_fail
            .violations
            .iter()
            .any(|v| v.code == "EQUIPMENT_LIMIT_EXCEEDED"));

        // KT24 Match Scoring: 5 Crit Op + 4 Tac Op + 6 Kill Op, Primary = CritOp (+3 bonus), +2 Painted = 20 VP
        let mut kt_details = KtMatchDetails::default();
        kt_details.player_primary_op = KtPrimaryOp::CritOp;
        kt_details.turning_points[1].player_crit_op = 2;
        kt_details.turning_points[2].player_crit_op = 2;
        kt_details.turning_points[3].player_crit_op = 1;
        kt_details.turning_points[1].player_tac_op = 2;
        kt_details.turning_points[2].player_tac_op = 2;
        kt_details.turning_points[3].player_kill_op = 6;
        kt_details.player_painted_bonus = true;
        kt_details.recalculate_totals();
        assert_eq!(kt_details.player_crit_total, 5);
        assert_eq!(kt_details.player_primary_bonus, 3); // ceil(5 / 2) = 3
        assert_eq!(kt_details.player_total, 5 + 4 + 6 + 3 + 2);
    }
}
