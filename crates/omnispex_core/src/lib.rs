pub mod domain;
pub mod engine;
pub mod parser;
pub mod storage;

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
}
