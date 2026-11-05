use crate::domain::catalogue::{
    CatalogueDatabase, DataProvenance, DatasheetUnit, DetachmentData, EnhancementData,
    FactionCatalogue, PricingTier, RuleEntry, UnitCostOption, WargearCostOption,
};
use crate::domain::dice::ValueExpr;
use crate::domain::unit::{DefensiveAbility, ModelProfile, UnitProfile};
use crate::domain::weapon::{Keyword, WeaponAbility, WeaponProfile};

/// Provides a validated default Warhammer 40,000 (11e / MFM v1.6) seed catalogue
/// for immediate zero-latency startup and test execution before the full bundle is loaded.
pub fn default_wh40k_seed_catalogue() -> CatalogueDatabase {
    CatalogueDatabase {
        provenance: DataProvenance::default(),
        factions: vec![
            build_space_marines_seed(),
            build_orks_seed(),
            build_necrons_seed(),
            build_aeldari_seed(),
        ],
    }
}

fn build_space_marines_seed() -> FactionCatalogue {
    let captain_model = ModelProfile::new("Captain", 5, 3, Some(4), None)
        .with_keywords(vec![Keyword::Infantry, Keyword::Character]);
    let mut captain_profile = UnitProfile::uniform(
        "Captain",
        4,
        captain_model,
        1,
        vec![Keyword::Infantry, Keyword::Character],
    );
    captain_profile.movement = "6\"".to_string();
    captain_profile.leadership = "6+".to_string();
    captain_profile.objective_control = 1;

    let intercessor_model = ModelProfile::new("Intercessor", 2, 3, None, None)
        .with_keywords(vec![Keyword::Infantry, Keyword::Battleline]);
    let mut intercessor_profile = UnitProfile::uniform(
        "Intercessor Squad",
        4,
        intercessor_model,
        5,
        vec![Keyword::Infantry, Keyword::Battleline, Keyword::Grenades],
    );
    intercessor_profile.movement = "6\"".to_string();
    intercessor_profile.leadership = "6+".to_string();
    intercessor_profile.objective_control = 2;

    let terminator_model = ModelProfile::new("Terminator", 3, 2, Some(4), None)
        .with_keywords(vec![Keyword::Infantry]);
    let mut terminator_profile = UnitProfile::uniform(
        "Terminator Squad",
        5,
        terminator_model,
        5,
        vec![Keyword::Infantry],
    );
    terminator_profile.movement = "5\"".to_string();
    terminator_profile.leadership = "6+".to_string();
    terminator_profile.objective_control = 1;

    let redemptor_model = ModelProfile::new("Redemptor Dreadnought", 12, 2, None, None)
        .with_keywords(vec![Keyword::Vehicle, Keyword::Walker]);
    let mut redemptor_profile = UnitProfile::uniform(
        "Redemptor Dreadnought",
        10,
        redemptor_model,
        1,
        vec![Keyword::Vehicle, Keyword::Walker],
    )
    .with_defensive_abilities(vec![DefensiveAbility::DamageReduction(1)]);
    redemptor_profile.movement = "8\"".to_string();
    redemptor_profile.leadership = "6+".to_string();
    redemptor_profile.objective_control = 4;

    let impulsor_model = ModelProfile::new("Impulsor", 11, 3, None, None)
        .with_keywords(vec![Keyword::Vehicle, Keyword::DedicatedTransport]);
    let mut impulsor_profile = UnitProfile::uniform(
        "Impulsor",
        9,
        impulsor_model,
        1,
        vec![Keyword::Vehicle, Keyword::DedicatedTransport],
    );
    impulsor_profile.movement = "12\"".to_string();
    impulsor_profile.leadership = "6+".to_string();
    impulsor_profile.objective_control = 2;

    FactionCatalogue {
        id: "sm-seed".to_string(),
        slug: "space-marines".to_string(),
        name: "Space Marines".to_string(),
        parent_faction: Some("Imperium".to_string()),
        revision: Some(38),
        army_rules: vec![RuleEntry {
            id: "rule-oath".to_string(),
            name: "Oath of Moment".to_string(),
            description: "At the start of your Command phase, select one enemy unit. Until the start of your next Command phase, re-roll Hit rolls of 1 against that unit.".to_string(),
        }],
        detachments: vec![DetachmentData {
            id: "det-sm-gladius".to_string(),
            name: "Gladius Task Force".to_string(),
            dp_cost: 3,
            force_dispositions: vec!["TAKE AND HOLD".to_string(), "PURGE THE FOE".to_string()],
            unique_tag: None,
            rules: vec![RuleEntry {
                id: "rule-combat-doctrines".to_string(),
                name: "Combat Doctrines".to_string(),
                description: "Select Devastator, Tactical, or Assault Doctrine in your Command phase.".to_string(),
            }],
            enhancements: vec![
                EnhancementData {
                    id: "enh-sm-fire-discipline".to_string(),
                    name: "Fire Discipline".to_string(),
                    points: 25,
                    is_upgrade: false,
                    description: "Models in the bearer's unit have the [SUSTAINED HITS 1] ability.".to_string(),
                    leader_to: vec![],
                    support_to: vec![],
                },
                EnhancementData {
                    id: "enh-sm-honour-vehement".to_string(),
                    name: "The Honour Vehement".to_string(),
                    points: 15,
                    is_upgrade: false,
                    description: "Add 1 to the Attacks and Strength characteristics of the bearer's melee weapons.".to_string(),
                    leader_to: vec![],
                    support_to: vec![],
                },
            ],
        }],
        units: vec![
            DatasheetUnit {
                id: "sm-captain".to_string(),
                name: "Captain".to_string(),
                faction_id: "sm-seed".to_string(),
                faction_name: "Space Marines".to_string(),
                group_title: Some("Characters".to_string()),
                is_legends: false,
                points_cost: Some(80),
                profile: captain_profile,
                weapons: vec![
                    WeaponProfile::new(
                        "Master-crafted Bolter",
                        24,
                        ValueExpr::Flat(2),
                        2,
                        4,
                        1,
                        ValueExpr::Flat(2),
                        vec![],
                    ),
                    WeaponProfile::new(
                        "Master-crafted Power Weapon",
                        0,
                        ValueExpr::Flat(6),
                        2,
                        5,
                        2,
                        ValueExpr::Flat(2),
                        vec![],
                    ),
                ],
                abilities: vec![
                    "Rites of Battle: Once per battle round, reduce CP cost of a Stratagem targeting this unit.".to_string(),
                    "Finest Hour: Once per battle, add 3 to Attacks and gain [DEVASTATING WOUNDS] on melee weapons.".to_string(),
                ],
                categories: vec!["Infantry".to_string(), "Character".to_string(), "Captain".to_string()],
                unit_composition: vec!["1 Captain".to_string()],
                wargear_options: vec!["May replace Master-crafted Bolter with Plasma Pistol and Relic Shield.".to_string()],
                pricing_tiers: vec![PricingTier {
                    range: "[1,)".to_string(),
                    label: "Your Unit Costs".to_string(),
                    costs: vec![UnitCostOption {
                        models: 1,
                        points: 80,
                        description: None,
                        is_addon: false,
                    }],
                }],
                wargear_costs: vec![],
                leader_to: vec!["Intercessor Squad".to_string()],
                support_to: vec![],
                transport_capacity: None,
            },
            DatasheetUnit {
                id: "sm-intercessors".to_string(),
                name: "Intercessor Squad".to_string(),
                faction_id: "sm-seed".to_string(),
                faction_name: "Space Marines".to_string(),
                group_title: Some("Battleline".to_string()),
                is_legends: false,
                points_cost: Some(80),
                profile: intercessor_profile,
                weapons: vec![
                    WeaponProfile::new(
                        "Bolt Rifle",
                        24,
                        ValueExpr::Flat(2),
                        3,
                        4,
                        1,
                        ValueExpr::Flat(1),
                        vec![WeaponAbility::Assault, WeaponAbility::Heavy],
                    ),
                    WeaponProfile::new(
                        "Astartes Grenade Launcher - Krak",
                        24,
                        ValueExpr::Flat(1),
                        3,
                        9,
                        2,
                        ValueExpr::D3,
                        vec![],
                    ),
                    WeaponProfile::new(
                        "Close Combat Weapon",
                        0,
                        ValueExpr::Flat(3),
                        3,
                        4,
                        0,
                        ValueExpr::Flat(1),
                        vec![],
                    ),
                ],
                abilities: vec![
                    "Objective Secured: Objectives remain controlled until an enemy controls them.".to_string(),
                ],
                categories: vec!["Infantry".to_string(), "Battleline".to_string(), "Grenades".to_string()],
                unit_composition: vec!["1 Intercessor Sergeant and 4-9 Intercessors".to_string()],
                wargear_options: vec!["1 in 5 Intercessors may equip an Astartes Grenade Launcher.".to_string()],
                pricing_tiers: vec![PricingTier {
                    range: "[1,)".to_string(),
                    label: "Your Unit Costs".to_string(),
                    costs: vec![
                        UnitCostOption {
                            models: 5,
                            points: 80,
                            description: None,
                            is_addon: false,
                        },
                        UnitCostOption {
                            models: 10,
                            points: 160,
                            description: None,
                            is_addon: false,
                        },
                    ],
                }],
                wargear_costs: vec![],
                leader_to: vec![],
                support_to: vec![],
                transport_capacity: None,
            },
            DatasheetUnit {
                id: "sm-terminators".to_string(),
                name: "Terminator Squad".to_string(),
                faction_id: "sm-seed".to_string(),
                faction_name: "Space Marines".to_string(),
                group_title: Some("Other Datasheets".to_string()),
                is_legends: false,
                points_cost: Some(170),
                profile: terminator_profile,
                weapons: vec![
                    WeaponProfile::new(
                        "Storm Bolter",
                        24,
                        ValueExpr::Flat(2),
                        3,
                        4,
                        0,
                        ValueExpr::Flat(1),
                        vec![WeaponAbility::RapidFire(2)],
                    ),
                    WeaponProfile::new(
                        "Power Fist",
                        0,
                        ValueExpr::Flat(3),
                        3,
                        8,
                        2,
                        ValueExpr::Flat(2),
                        vec![],
                    ),
                ],
                abilities: vec!["Deep Strike".to_string(), "Teleport Homer".to_string()],
                categories: vec!["Infantry".to_string(), "Terminator".to_string()],
                unit_composition: vec!["1 Terminator Sergeant and 4-9 Terminators".to_string()],
                wargear_options: vec![],
                pricing_tiers: vec![PricingTier {
                    range: "[1,)".to_string(),
                    label: "Your Unit Costs".to_string(),
                    costs: vec![
                        UnitCostOption {
                            models: 5,
                            points: 170,
                            description: None,
                            is_addon: false,
                        },
                        UnitCostOption {
                            models: 10,
                            points: 340,
                            description: None,
                            is_addon: false,
                        },
                    ],
                }],
                wargear_costs: vec![],
                leader_to: vec![],
                support_to: vec![],
                transport_capacity: None,
            },
            DatasheetUnit {
                id: "sm-redemptor".to_string(),
                name: "Redemptor Dreadnought".to_string(),
                faction_id: "sm-seed".to_string(),
                faction_name: "Space Marines".to_string(),
                group_title: Some("Vehicles".to_string()),
                is_legends: false,
                points_cost: Some(210),
                profile: redemptor_profile,
                weapons: vec![
                    WeaponProfile::new(
                        "Macro Plasma Incinerator - Supercharge",
                        36,
                        ValueExpr::D6Plus(1),
                        3,
                        9,
                        4,
                        ValueExpr::Flat(3),
                        vec![WeaponAbility::Blast, WeaponAbility::Hazardous],
                    ),
                    WeaponProfile::new(
                        "Redemptor Fist",
                        0,
                        ValueExpr::Flat(5),
                        3,
                        12,
                        2,
                        ValueExpr::Flat(3),
                        vec![],
                    ),
                ],
                abilities: vec![
                    "Duty Eternal: Each time an attack is allocated to this model, subtract 1 from the Damage characteristic of that attack.".to_string(),
                ],
                categories: vec!["Vehicle".to_string(), "Walker".to_string(), "Dreadnought".to_string()],
                unit_composition: vec!["1 Redemptor Dreadnought".to_string()],
                wargear_options: vec![],
                pricing_tiers: vec![PricingTier {
                    range: "[1,)".to_string(),
                    label: "Your Unit Costs".to_string(),
                    costs: vec![UnitCostOption {
                        models: 1,
                        points: 210,
                        description: None,
                        is_addon: false,
                    }],
                }],
                wargear_costs: vec![],
                leader_to: vec![],
                support_to: vec![],
                transport_capacity: None,
            },
            DatasheetUnit {
                id: "sm-impulsor".to_string(),
                name: "Impulsor".to_string(),
                faction_id: "sm-seed".to_string(),
                faction_name: "Space Marines".to_string(),
                group_title: Some("Dedicated Transports".to_string()),
                is_legends: false,
                points_cost: Some(80),
                profile: impulsor_profile,
                weapons: vec![WeaponProfile::new(
                    "Twin Storm Bolter",
                    24,
                    ValueExpr::Flat(2),
                    3,
                    4,
                    0,
                    ValueExpr::Flat(1),
                    vec![WeaponAbility::RapidFire(2), WeaponAbility::TwinLinked],
                )],
                abilities: vec!["Assault Vehicle: Units can disembark after this Transport Advances.".to_string()],
                categories: vec!["Vehicle".to_string(), "Transport".to_string(), "Dedicated Transport".to_string()],
                unit_composition: vec!["1 Impulsor".to_string()],
                wargear_options: vec![],
                pricing_tiers: vec![PricingTier {
                    range: "[1,)".to_string(),
                    label: "Your Unit Costs".to_string(),
                    costs: vec![UnitCostOption {
                        models: 1,
                        points: 80,
                        description: None,
                        is_addon: false,
                    }],
                }],
                wargear_costs: vec![],
                leader_to: vec![],
                support_to: vec![],
                transport_capacity: Some("7 TACTICUS or PHOBOS INFANTRY models.".to_string()),
            },
        ],
        warnings: vec![],
    }
}

fn build_orks_seed() -> FactionCatalogue {
    let warboss_model = ModelProfile::new("Warboss", 6, 4, Some(5), None)
        .with_keywords(vec![Keyword::Infantry, Keyword::Character]);
    let mut warboss_profile = UnitProfile::uniform(
        "Warboss",
        5,
        warboss_model,
        1,
        vec![Keyword::Infantry, Keyword::Character],
    );
    warboss_profile.movement = "6\"".to_string();
    warboss_profile.leadership = "6+".to_string();
    warboss_profile.objective_control = 1;

    let boy_model = ModelProfile::new("Ork Boy", 1, 5, None, None)
        .with_keywords(vec![Keyword::Infantry, Keyword::Battleline]);
    let mut boyz_profile = UnitProfile::uniform(
        "Boyz",
        5,
        boy_model,
        10,
        vec![Keyword::Infantry, Keyword::Battleline],
    );
    boyz_profile.movement = "6\"".to_string();
    boyz_profile.leadership = "7+".to_string();
    boyz_profile.objective_control = 2;

    let bw_model = ModelProfile::new("Battlewagon", 16, 3, Some(6), None)
        .with_keywords(vec![Keyword::Vehicle]);
    let mut bw_profile = UnitProfile::uniform(
        "Battlewagon",
        10,
        bw_model,
        1,
        vec![Keyword::Vehicle],
    )
    .with_defensive_abilities(vec![DefensiveAbility::MinusOneAp]);
    bw_profile.movement = "10\"".to_string();
    bw_profile.leadership = "7+".to_string();
    bw_profile.objective_control = 5;

    FactionCatalogue {
        id: "orks-seed".to_string(),
        slug: "orks".to_string(),
        name: "Orks".to_string(),
        parent_faction: Some("Xenos".to_string()),
        revision: Some(25),
        army_rules: vec![RuleEntry {
            id: "rule-waaagh".to_string(),
            name: "Waaagh!".to_string(),
            description: "Once per battle, call a Waaagh! for +1S, +1A in melee, 5+ Invulnerable save, and Advance + Charge.".to_string(),
        }],
        detachments: vec![DetachmentData {
            id: "det-orks-war-horde".to_string(),
            name: "War Horde".to_string(),
            dp_cost: 3,
            force_dispositions: vec!["TAKE AND HOLD".to_string(), "PURGE THE FOE".to_string()],
            unique_tag: None,
            rules: vec![RuleEntry {
                id: "rule-get-stuck-in".to_string(),
                name: "Get Stuck In".to_string(),
                description: "Melee weapons equipped by ORKS models have the [SUSTAINED HITS 1] ability.".to_string(),
            }],
            enhancements: vec![EnhancementData {
                id: "enh-orks-killchoppa".to_string(),
                name: "Headwoppa's Killchoppa".to_string(),
                points: 15,
                is_upgrade: false,
                description: "Melee weapons equipped by the bearer (excluding Extra Attacks) have [DEVASTATING WOUNDS].".to_string(),
                leader_to: vec![],
                support_to: vec![],
            }],
        }],
        units: vec![
            DatasheetUnit {
                id: "orks-warboss".to_string(),
                name: "Warboss".to_string(),
                faction_id: "orks-seed".to_string(),
                faction_name: "Orks".to_string(),
                group_title: Some("Characters".to_string()),
                is_legends: false,
                points_cost: Some(70),
                profile: warboss_profile,
                weapons: vec![
                    WeaponProfile::new(
                        "Kombi-weapon",
                        24,
                        ValueExpr::Flat(1),
                        5,
                        4,
                        0,
                        ValueExpr::Flat(1),
                        vec![
                            WeaponAbility::Anti {
                                target: Keyword::Infantry,
                                threshold: 4,
                            },
                            WeaponAbility::DevastatingWounds,
                            WeaponAbility::RapidFire(1),
                        ],
                    ),
                    WeaponProfile::new(
                        "Power Klaw",
                        0,
                        ValueExpr::Flat(4),
                        3,
                        10,
                        2,
                        ValueExpr::Flat(2),
                        vec![],
                    ),
                ],
                abilities: vec!["Might is Right: Add 1 to Hit rolls for models in this unit in melee.".to_string()],
                categories: vec!["Infantry".to_string(), "Character".to_string(), "Warboss".to_string()],
                unit_composition: vec!["1 Warboss".to_string()],
                wargear_options: vec![],
                pricing_tiers: vec![PricingTier {
                    range: "[1,)".to_string(),
                    label: "Your Unit Costs".to_string(),
                    costs: vec![UnitCostOption {
                        models: 1,
                        points: 70,
                        description: None,
                        is_addon: false,
                    }],
                }],
                wargear_costs: vec![],
                leader_to: vec!["Boyz".to_string()],
                support_to: vec![],
                transport_capacity: None,
            },
            DatasheetUnit {
                id: "orks-boyz".to_string(),
                name: "Boyz".to_string(),
                faction_id: "orks-seed".to_string(),
                faction_name: "Orks".to_string(),
                group_title: Some("Battleline".to_string()),
                is_legends: false,
                points_cost: Some(85),
                profile: boyz_profile,
                weapons: vec![
                    WeaponProfile::new(
                        "Slugga",
                        12,
                        ValueExpr::Flat(1),
                        5,
                        4,
                        0,
                        ValueExpr::Flat(1),
                        vec![WeaponAbility::Pistol],
                    ),
                    WeaponProfile::new(
                        "Choppa",
                        0,
                        ValueExpr::Flat(3),
                        3,
                        4,
                        1,
                        ValueExpr::Flat(1),
                        vec![],
                    ),
                ],
                abilities: vec!["Get Da Good Bitz: Sticky objective control.".to_string()],
                categories: vec!["Infantry".to_string(), "Battleline".to_string()],
                unit_composition: vec!["1 Boss Nob and 9-19 Boyz".to_string()],
                wargear_options: vec![],
                pricing_tiers: vec![PricingTier {
                    range: "[1,)".to_string(),
                    label: "Your Unit Costs".to_string(),
                    costs: vec![
                        UnitCostOption {
                            models: 10,
                            points: 85,
                            description: None,
                            is_addon: false,
                        },
                        UnitCostOption {
                            models: 20,
                            points: 170,
                            description: None,
                            is_addon: false,
                        },
                    ],
                }],
                wargear_costs: vec![],
                leader_to: vec![],
                support_to: vec![],
                transport_capacity: None,
            },
            DatasheetUnit {
                id: "orks-battlewagon".to_string(),
                name: "Battlewagon".to_string(),
                faction_id: "orks-seed".to_string(),
                faction_name: "Orks".to_string(),
                group_title: Some("Vehicles".to_string()),
                is_legends: false,
                points_cost: Some(160),
                profile: bw_profile,
                weapons: vec![WeaponProfile::new(
                    "Killkannon",
                    24,
                    ValueExpr::D6Plus(1),
                    5,
                    9,
                    2,
                    ValueExpr::Flat(2),
                    vec![WeaponAbility::Blast],
                )],
                abilities: vec!["Ramshackle but Rugged: Worsen AP of incoming attacks by 1.".to_string()],
                categories: vec!["Vehicle".to_string(), "Transport".to_string()],
                unit_composition: vec!["1 Battlewagon".to_string()],
                wargear_options: vec![],
                pricing_tiers: vec![
                    PricingTier {
                        range: "[1,2]".to_string(),
                        label: "Your 1st To 2nd Units Cost".to_string(),
                        costs: vec![UnitCostOption {
                            models: 1,
                            points: 160,
                            description: None,
                            is_addon: false,
                        }],
                    },
                    PricingTier {
                        range: "[3,)".to_string(),
                        label: "Your 3rd + Unit Costs".to_string(),
                        costs: vec![UnitCostOption {
                            models: 1,
                            points: 180,
                            description: None,
                            is_addon: false,
                        }],
                    },
                ],
                wargear_costs: vec![WargearCostOption {
                    item: "Zzap gun".to_string(),
                    points: 5,
                }],
                leader_to: vec![],
                support_to: vec![],
                transport_capacity: Some("22 ORKS INFANTRY models.".to_string()),
            },
        ],
        warnings: vec![],
    }
}

fn build_necrons_seed() -> FactionCatalogue {
    let overlord_model = ModelProfile::new("Overlord", 6, 2, Some(4), None)
        .with_keywords(vec![Keyword::Infantry, Keyword::Character]);
    let mut overlord_profile = UnitProfile::uniform(
        "Overlord",
        5,
        overlord_model,
        1,
        vec![Keyword::Infantry, Keyword::Character],
    )
    .with_defensive_abilities(vec![DefensiveAbility::DamageReduction(1)]);
    overlord_profile.movement = "5\"".to_string();
    overlord_profile.leadership = "6+".to_string();
    overlord_profile.objective_control = 1;

    let warrior_model = ModelProfile::new("Necron Warrior", 1, 4, None, None)
        .with_keywords(vec![Keyword::Infantry, Keyword::Battleline]);
    let mut warriors_profile = UnitProfile::uniform(
        "Necron Warriors",
        4,
        warrior_model,
        10,
        vec![Keyword::Infantry, Keyword::Battleline],
    );
    warriors_profile.movement = "5\"".to_string();
    warriors_profile.leadership = "7+".to_string();
    warriors_profile.objective_control = 2;

    FactionCatalogue {
        id: "necrons-seed".to_string(),
        slug: "necrons".to_string(),
        name: "Necrons".to_string(),
        parent_faction: Some("Xenos".to_string()),
        revision: Some(22),
        army_rules: vec![RuleEntry {
            id: "rule-reanimation".to_string(),
            name: "Reanimation Protocols".to_string(),
            description: "At the end of your Command phase, each unit activates Reanimation Protocols and regains D3 wounds.".to_string(),
        }],
        detachments: vec![DetachmentData {
            id: "det-necrons-awakened".to_string(),
            name: "Awakened Dynasty".to_string(),
            dp_cost: 3,
            force_dispositions: vec!["TAKE AND HOLD".to_string()],
            unique_tag: None,
            rules: vec![RuleEntry {
                id: "rule-command-protocols".to_string(),
                name: "Command Protocols".to_string(),
                description: "While a NECRONS CHARACTER is leading a unit, add 1 to the Hit roll.".to_string(),
            }],
            enhancements: vec![EnhancementData {
                id: "enh-necrons-veil".to_string(),
                name: "Veil of Darkness".to_string(),
                points: 20,
                is_upgrade: false,
                description: "Once per battle, redeploy the bearer's unit via Deep Strike.".to_string(),
                leader_to: vec![],
                support_to: vec![],
            }],
        }],
        units: vec![
            DatasheetUnit {
                id: "necrons-overlord".to_string(),
                name: "Overlord".to_string(),
                faction_id: "necrons-seed".to_string(),
                faction_name: "Necrons".to_string(),
                group_title: Some("Characters".to_string()),
                is_legends: false,
                points_cost: Some(85),
                profile: overlord_profile,
                weapons: vec![WeaponProfile::new(
                    "Voidscythe",
                    0,
                    ValueExpr::Flat(3),
                    3,
                    12,
                    3,
                    ValueExpr::Flat(3),
                    vec![WeaponAbility::DevastatingWounds],
                )],
                abilities: vec!["Implacable Resilience: Subtract 1 from incoming Damage.".to_string()],
                categories: vec!["Infantry".to_string(), "Character".to_string()],
                unit_composition: vec!["1 Overlord".to_string()],
                wargear_options: vec![],
                pricing_tiers: vec![PricingTier {
                    range: "[1,)".to_string(),
                    label: "Your Unit Costs".to_string(),
                    costs: vec![UnitCostOption {
                        models: 1,
                        points: 85,
                        description: None,
                        is_addon: false,
                    }],
                }],
                wargear_costs: vec![],
                leader_to: vec!["Necron Warriors".to_string()],
                support_to: vec![],
                transport_capacity: None,
            },
            DatasheetUnit {
                id: "necrons-warriors".to_string(),
                name: "Necron Warriors".to_string(),
                faction_id: "necrons-seed".to_string(),
                faction_name: "Necrons".to_string(),
                group_title: Some("Battleline".to_string()),
                is_legends: false,
                points_cost: Some(90),
                profile: warriors_profile,
                weapons: vec![WeaponProfile::new(
                    "Gauss Flayer",
                    24,
                    ValueExpr::Flat(1),
                    4,
                    4,
                    0,
                    ValueExpr::Flat(1),
                    vec![WeaponAbility::LethalHits, WeaponAbility::RapidFire(1)],
                )],
                abilities: vec!["Their Number Is Legion: Re-roll Reanimation Protocols rolls of 1.".to_string()],
                categories: vec!["Infantry".to_string(), "Battleline".to_string()],
                unit_composition: vec!["10-20 Necron Warriors".to_string()],
                wargear_options: vec![],
                pricing_tiers: vec![PricingTier {
                    range: "[1,)".to_string(),
                    label: "Your Unit Costs".to_string(),
                    costs: vec![
                        UnitCostOption {
                            models: 10,
                            points: 90,
                            description: None,
                            is_addon: false,
                        },
                        UnitCostOption {
                            models: 20,
                            points: 200,
                            description: None,
                            is_addon: false,
                        },
                    ],
                }],
                wargear_costs: vec![],
                leader_to: vec![],
                support_to: vec![],
                transport_capacity: None,
            },
        ],
        warnings: vec![],
    }
}

fn build_aeldari_seed() -> FactionCatalogue {
    let autarch_model = ModelProfile::new("Autarch", 4, 3, Some(4), None)
        .with_keywords(vec![Keyword::Infantry, Keyword::Character]);
    let mut autarch_profile = UnitProfile::uniform(
        "Autarch",
        7,
        autarch_model,
        1,
        vec![Keyword::Infantry, Keyword::Character],
    );
    autarch_profile.movement = "7\"".to_string();
    autarch_profile.leadership = "6+".to_string();
    autarch_profile.objective_control = 1;

    let guardian_model = ModelProfile::new("Guardian Defender", 1, 4, None, None)
        .with_keywords(vec![Keyword::Infantry, Keyword::Battleline]);
    let mut guardians_profile = UnitProfile::uniform(
        "Guardian Defenders",
        3,
        guardian_model,
        10,
        vec![Keyword::Infantry, Keyword::Battleline],
    );
    guardians_profile.movement = "7\"".to_string();
    guardians_profile.leadership = "6+".to_string();
    guardians_profile.objective_control = 2;

    FactionCatalogue {
        id: "aeldari-seed".to_string(),
        slug: "aeldari".to_string(),
        name: "Aeldari".to_string(),
        parent_faction: Some("Xenos".to_string()),
        revision: Some(29),
        army_rules: vec![RuleEntry {
            id: "rule-battle-focus".to_string(),
            name: "Battle Focus".to_string(),
            description: "Agile Manoeuvres in each phase.".to_string(),
        }],
        detachments: vec![DetachmentData {
            id: "det-aeldari-warhost".to_string(),
            name: "Warhost".to_string(),
            dp_cost: 3,
            force_dispositions: vec!["TAKE AND HOLD".to_string()],
            unique_tag: None,
            rules: vec![],
            enhancements: vec![],
        }],
        units: vec![
            DatasheetUnit {
                id: "aeldari-autarch".to_string(),
                name: "Autarch".to_string(),
                faction_id: "aeldari-seed".to_string(),
                faction_name: "Aeldari".to_string(),
                group_title: Some("Characters".to_string()),
                is_legends: false,
                points_cost: Some(75),
                profile: autarch_profile,
                weapons: vec![WeaponProfile::new(
                    "Star Glaive",
                    0,
                    ValueExpr::Flat(4),
                    2,
                    6,
                    2,
                    ValueExpr::Flat(2),
                    vec![],
                )],
                abilities: vec!["Path of Command".to_string()],
                categories: vec!["Infantry".to_string(), "Character".to_string()],
                unit_composition: vec!["1 Autarch".to_string()],
                wargear_options: vec![],
                pricing_tiers: vec![PricingTier {
                    range: "[1,)".to_string(),
                    label: "Your Unit Costs".to_string(),
                    costs: vec![UnitCostOption {
                        models: 1,
                        points: 75,
                        description: None,
                        is_addon: false,
                    }],
                }],
                wargear_costs: vec![],
                leader_to: vec!["Guardian Defenders".to_string()],
                support_to: vec![],
                transport_capacity: None,
            },
            DatasheetUnit {
                id: "aeldari-guardians".to_string(),
                name: "Guardian Defenders".to_string(),
                faction_id: "aeldari-seed".to_string(),
                faction_name: "Aeldari".to_string(),
                group_title: Some("Battleline".to_string()),
                is_legends: false,
                points_cost: Some(100),
                profile: guardians_profile,
                weapons: vec![WeaponProfile::new(
                    "Shuriken Catapult",
                    18,
                    ValueExpr::Flat(2),
                    3,
                    4,
                    1,
                    ValueExpr::Flat(1),
                    vec![WeaponAbility::Assault],
                )],
                abilities: vec!["Crewed Platform".to_string()],
                categories: vec!["Infantry".to_string(), "Battleline".to_string()],
                unit_composition: vec!["10 Guardian Defenders and 1 Heavy Weapon Platform".to_string()],
                wargear_options: vec![],
                pricing_tiers: vec![PricingTier {
                    range: "[1,)".to_string(),
                    label: "Your Unit Costs".to_string(),
                    costs: vec![UnitCostOption {
                        models: 11,
                        points: 100,
                        description: None,
                        is_addon: false,
                    }],
                }],
                wargear_costs: vec![],
                leader_to: vec![],
                support_to: vec![],
                transport_capacity: None,
            },
        ],
        warnings: vec![],
    }
}
