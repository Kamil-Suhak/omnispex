mod common;

use common::{project_root, run_cli, temp_dir};
use omnispex_core::domain::army_list::{
    ArmyList, BattleSize, RosterUnitEntry, SelectedDetachment, SelectedWargearOption,
};
use std::fs;

fn create_base_ork_list() -> ArmyList {
    ArmyList {
        id: "list-ork-1".to_string(),
        name: "Waaagh! Ghazghkull".to_string(),
        faction_id: "orks".to_string(),
        faction_name: "Orks".to_string(),
        battle_size: BattleSize::StrikeForce,
        points_limit: 2000,
        detachments: vec![SelectedDetachment {
            id: "det-war-horde".to_string(),
            name: "War Horde".to_string(),
            dp_cost: 3,
            unique_tag: None,
        }],
        units: vec![
            // Warlord: Warboss with Enhancement
            RosterUnitEntry {
                entry_id: "u-wb-1".to_string(),
                unit_id: "u-warboss".to_string(),
                unit_name: "Warboss".to_string(),
                models_count: 1,
                option_description: Some("1 Warboss".to_string()),
                base_points: 85,
                requisition_tier_label: None,
                selected_wargear: vec![SelectedWargearOption {
                    item: "Power Klaw".to_string(),
                    count: 1,
                    points_each: 0,
                }],
                enhancement_id: Some("enh-killchoppa".to_string()),
                enhancement_name: Some("Headwoppa's Killchoppa".to_string()),
                enhancement_points: 15,
                enhancement_is_upgrade: false,
                is_warlord: true,
                attached_to_entry_id: None,
                categories: vec!["Character".to_string(), "Infantry".to_string()],
                custom_weapons: vec!["Kombishoota".to_string()],
                notes: "Leading 20 Boyz".to_string(),
            },
            // Battleline 1: 20 Boyz
            RosterUnitEntry {
                entry_id: "u-boyz-1".to_string(),
                unit_id: "u-boyz".to_string(),
                unit_name: "Boyz".to_string(),
                models_count: 20,
                option_description: Some("20 Boyz".to_string()),
                base_points: 170,
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
                notes: "".to_string(),
            },
            // Battleline 2: 10 Boyz
            RosterUnitEntry {
                entry_id: "u-boyz-2".to_string(),
                unit_id: "u-boyz".to_string(),
                unit_name: "Boyz".to_string(),
                models_count: 10,
                option_description: Some("10 Boyz".to_string()),
                base_points: 85,
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
                notes: "".to_string(),
            },
            // Nobz
            RosterUnitEntry {
                entry_id: "u-nobz-1".to_string(),
                unit_id: "u-nobz".to_string(),
                unit_name: "Nobz".to_string(),
                models_count: 5,
                option_description: Some("5 Nobz".to_string()),
                base_points: 105,
                requisition_tier_label: None,
                selected_wargear: vec![],
                enhancement_id: None,
                enhancement_name: None,
                enhancement_points: 0,
                enhancement_is_upgrade: false,
                is_warlord: false,
                attached_to_entry_id: None,
                categories: vec!["Infantry".to_string()],
                custom_weapons: vec![],
                notes: "".to_string(),
            },
            // Battlewagon
            RosterUnitEntry {
                entry_id: "u-bw-1".to_string(),
                unit_id: "u-bw".to_string(),
                unit_name: "Battlewagon".to_string(),
                models_count: 1,
                option_description: None,
                base_points: 160,
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
                notes: "".to_string(),
            },
        ],
        notes: "Test Ork Strike Force list".to_string(),
        created_at_iso: "2026-10-26T00:00:00Z".to_string(),
        updated_at_iso: "2026-10-26T00:00:00Z".to_string(),
    }
}

#[test]
fn test_validate_legal_ork_strike_force_with_export() {
    let out_dir = temp_dir("legal_ork_list");
    let list_file = out_dir.join("legal_orks.json");
    let list = create_base_ork_list();

    fs::write(&list_file, serde_json::to_string(&list).unwrap()).unwrap();

    let root = project_root();
    let bundle_path = root.join("flutter_ui/assets/data/wh40k_11e_bundle.json");

    let output = run_cli([
        "validate-list",
        "-l",
        list_file.to_str().unwrap(),
        "-b",
        bundle_path.to_str().unwrap(),
        "--export-text",
        "--strict",
    ]);

    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    println!("VALIDATION STDOUT:\n{}", stdout);
    println!("VALIDATION STDERR:\n{}", stderr);

    assert!(stdout.contains("ROSTER VALIDATION: Waaagh! Ghazghkull (LEGAL)"));
    assert!(stdout.contains("Detachment Points: 3 / 3 DP"));
    assert!(stdout.contains("Warboss"));
    assert!(stdout.contains("[WARLORD]"));
    assert!(stdout.contains("Headwoppa's Killchoppa"));
    assert!(stdout.contains("Boyz"));
    assert!(stdout.contains("Battlewagon"));

    let _ = fs::remove_dir_all(out_dir);
}

#[test]
fn test_validate_ork_points_overflow() {
    let out_dir = temp_dir("overflow_pts_ork");
    let list_file = out_dir.join("overflow_orks.json");
    let mut list = create_base_ork_list();
    list.points_limit = 500; // Total is 620, exceeding 500

    fs::write(&list_file, serde_json::to_string(&list).unwrap()).unwrap();

    // Standard run: prints ILLEGAL and details
    let output = run_cli(["validate-list", "-l", list_file.to_str().unwrap()]);
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("(ILLEGAL)"));
    assert!(stdout.contains("[ERROR] POINTS_EXCEEDED:"));

    // Strict run: exits with non-zero error
    let output_strict = run_cli([
        "validate-list",
        "-l",
        list_file.to_str().unwrap(),
        "--strict",
    ]);
    assert!(
        !output_strict.status.success(),
        "--strict must fail on illegal points list"
    );

    let _ = fs::remove_dir_all(out_dir);
}

#[test]
fn test_validate_ork_dp_limit_exceeded() {
    let out_dir = temp_dir("overflow_dp_ork");
    let list_file = out_dir.join("overflow_dp.json");
    let mut list = create_base_ork_list();
    // Add a second detachment causing DP to be 3 + 2 = 5 (limit is 3 in Strike Force)
    list.detachments.push(SelectedDetachment {
        id: "det-dread-mob".to_string(),
        name: "Dread Mob".to_string(),
        dp_cost: 2,
        unique_tag: None,
    });

    fs::write(&list_file, serde_json::to_string(&list).unwrap()).unwrap();

    let output = run_cli([
        "validate-list",
        "-l",
        list_file.to_str().unwrap(),
        "--strict",
    ]);
    assert!(!output.status.success());
    let stderr = String::from_utf8_lossy(&output.stderr);
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(
        stdout.contains("[ERROR] DP_LIMIT_EXCEEDED:") || stderr.contains("rule violation"),
        "Must flag DP limit violation"
    );

    let _ = fs::remove_dir_all(out_dir);
}

#[test]
fn test_validate_ork_warlord_rules() {
    let out_dir = temp_dir("warlord_rules_ork");
    let list_file = out_dir.join("no_warlord.json");

    // 1. Missing Warlord
    let mut list_no_wl = create_base_ork_list();
    for u in &mut list_no_wl.units {
        u.is_warlord = false;
    }
    fs::write(&list_file, serde_json::to_string(&list_no_wl).unwrap()).unwrap();

    let output_no_wl = run_cli(["validate-list", "-l", list_file.to_str().unwrap()]);
    let stdout_no_wl = String::from_utf8_lossy(&output_no_wl.stdout);
    assert!(stdout_no_wl.contains("[ERROR] MISSING_WARLORD:"));

    // 2. Multiple Warlords
    let mut list_multi_wl = create_base_ork_list();
    list_multi_wl.units[1].is_warlord = true; // Boyz also marked warlord
    fs::write(&list_file, serde_json::to_string(&list_multi_wl).unwrap()).unwrap();

    let output_multi_wl = run_cli(["validate-list", "-l", list_file.to_str().unwrap()]);
    let stdout_multi_wl = String::from_utf8_lossy(&output_multi_wl.stdout);
    assert!(stdout_multi_wl.contains("[ERROR] MULTIPLE_WARLORDS:"));

    // 3. Non-character Warlord
    let mut list_vehicle_wl = create_base_ork_list();
    list_vehicle_wl.units[0].is_warlord = false;
    list_vehicle_wl.units[4].is_warlord = true; // Battlewagon as warlord
    fs::write(&list_file, serde_json::to_string(&list_vehicle_wl).unwrap()).unwrap();

    let output_vehicle_wl = run_cli(["validate-list", "-l", list_file.to_str().unwrap()]);
    let stdout_veh_wl = String::from_utf8_lossy(&output_vehicle_wl.stdout);
    assert!(stdout_veh_wl.contains("[ERROR] NON_CHARACTER_WARLORD:"));

    let _ = fs::remove_dir_all(out_dir);
}

#[test]
fn test_validate_ork_epic_hero_and_rule_of_three() {
    let out_dir = temp_dir("limits_ork");
    let list_file = out_dir.join("limits.json");

    // 1. Duplicate Epic Hero (2x Ghazghkull Thraka)
    let mut list_epic = create_base_ork_list();
    let ghaz_entry = RosterUnitEntry {
        entry_id: "u-ghaz-1".to_string(),
        unit_id: "u-ghaz".to_string(),
        unit_name: "Ghazghkull Thraka".to_string(),
        models_count: 2,
        option_description: None,
        base_points: 235,
        requisition_tier_label: None,
        selected_wargear: vec![],
        enhancement_id: None,
        enhancement_name: None,
        enhancement_points: 0,
        enhancement_is_upgrade: false,
        is_warlord: false,
        attached_to_entry_id: None,
        categories: vec!["Epic Hero".to_string(), "Character".to_string()],
        custom_weapons: vec![],
        notes: "".to_string(),
    };
    list_epic.units.push(ghaz_entry.clone());
    let mut ghaz_dup = ghaz_entry;
    ghaz_dup.entry_id = "u-ghaz-2".to_string();
    list_epic.units.push(ghaz_dup);

    fs::write(&list_file, serde_json::to_string(&list_epic).unwrap()).unwrap();

    let output_epic = run_cli(["validate-list", "-l", list_file.to_str().unwrap()]);
    let stdout_epic = String::from_utf8_lossy(&output_epic.stdout);
    assert!(stdout_epic.contains("[ERROR] UNIT_LIMIT_EXCEEDED:"));
    assert!(stdout_epic.contains("Ghazghkull Thraka"));
    assert!(stdout_epic.contains("EPIC HERO"));

    // 2. Rule of 3: 4x Battlewagon (Vehicle, non-battleline)
    let mut list_bw = create_base_ork_list();
    let bw = list_bw.units[4].clone();
    list_bw.units.push(bw.clone());
    list_bw.units.push(bw.clone());
    list_bw.units.push(bw); // 4 total

    fs::write(&list_file, serde_json::to_string(&list_bw).unwrap()).unwrap();

    let output_bw = run_cli(["validate-list", "-l", list_file.to_str().unwrap()]);
    let stdout_bw = String::from_utf8_lossy(&output_bw.stdout);
    assert!(stdout_bw.contains("[ERROR] UNIT_LIMIT_EXCEEDED:"));
    assert!(stdout_bw.contains("Battlewagon"));

    // 3. Battleline allowance: 6x Boyz is legal in Strike Force (up to 2x base limit = 6)
    let mut list_6_boyz = create_base_ork_list();
    let boyz = list_6_boyz.units[1].clone();
    // list already has 2 boyz, add 4 more for 6 total
    list_6_boyz.units.push(boyz.clone());
    list_6_boyz.units.push(boyz.clone());
    list_6_boyz.units.push(boyz.clone());
    list_6_boyz.units.push(boyz);

    fs::write(&list_file, serde_json::to_string(&list_6_boyz).unwrap()).unwrap();

    let output_6_boyz = run_cli(["validate-list", "-l", list_file.to_str().unwrap()]);
    let stdout_6_boyz = String::from_utf8_lossy(&output_6_boyz.stdout);
    assert!(
        !stdout_6_boyz.contains("'Boyz' is included"),
        "6 copies of Battleline Boyz must be legal"
    );

    let _ = fs::remove_dir_all(out_dir);
}
