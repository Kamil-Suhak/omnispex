mod common;

use common::{project_root, run_cli, temp_dir};
use omnispex_core::domain::dice::ValueExpr;
use omnispex_core::domain::matches::{
    GameSystem, KillTeamMatchDetails, KillTeamTurningPointScore, MatchRecord, MatchResult,
    Wh40kMatchDetails, Wh40kRoundScore,
};
use omnispex_core::domain::unit::{ModelProfile, UnitProfile};
use omnispex_core::domain::weapon::{Keyword, WeaponProfile};
use omnispex_core::storage::PersonalDataStore;
use std::fs;

#[test]
fn test_run_matchup_valid_files() {
    let out_dir = temp_dir("matchup_io_test");
    let weapon_file = out_dir.join("ork_power_klaw.json");
    let target_file = out_dir.join("marine_intercessors.json");

    let klaw = WeaponProfile::new(
        "Ork Power Klaw",
        0,
        ValueExpr::Flat(4),
        4,
        9,
        2,
        ValueExpr::Flat(2),
        vec![],
    );
    fs::write(&weapon_file, serde_json::to_string(&klaw).unwrap()).unwrap();

    let marine_model = ModelProfile::new("Intercessor", 2, 3, None, None);
    let target = UnitProfile::uniform(
        "Intercessors",
        4,
        marine_model,
        5,
        vec![Keyword::Infantry],
    );
    fs::write(&target_file, serde_json::to_string(&target).unwrap()).unwrap();

    let output = run_cli([
        "run-matchup",
        "-a",
        weapon_file.to_str().unwrap(),
        "-d",
        target_file.to_str().unwrap(),
        "-i",
        "5000",
    ]);

    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("OMNISPEX SIMULATION REPORT"));
    assert!(stdout.contains("Ork Power Klaw"));
    assert!(stdout.contains("Intercessors (5 models"));
    assert!(stdout.contains("TACTICAL VERDICT:"));

    let _ = fs::remove_dir_all(out_dir);
}

#[test]
fn test_run_matchup_with_legacy_models_format() {
    let root = project_root();
    let attacker_file = root.join("examples/meltagun.json");
    let defender_file = root.join("examples/terminators.json");

    assert!(attacker_file.exists());
    assert!(defender_file.exists());

    let output = run_cli([
        "run-matchup",
        "-a",
        attacker_file.to_str().unwrap(),
        "-d",
        defender_file.to_str().unwrap(),
        "-i",
        "3000",
    ]);

    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("Defender: Terminator Squad (5 models"));
    assert!(stdout.contains("Meltagun"));
}

#[test]
fn test_run_matchup_missing_files_error_handling() {
    let out_dir = temp_dir("missing_matchup");
    let missing_a = out_dir.join("ghost_weapon.json");
    let missing_d = out_dir.join("ghost_target.json");

    let output = run_cli([
        "run-matchup",
        "-a",
        missing_a.to_str().unwrap(),
        "-d",
        missing_d.to_str().unwrap(),
    ]);

    assert!(
        !output.status.success(),
        "Must exit with non-zero error when file is missing"
    );

    let _ = fs::remove_dir_all(out_dir);
}

#[test]
fn test_run_matchup_corrupted_json_error_handling() {
    let out_dir = temp_dir("corrupt_matchup");
    let bad_weapon = out_dir.join("broken_weapon.json");
    let valid_target = out_dir.join("target.json");

    fs::write(&bad_weapon, "{ not a valid json").unwrap();
    let target = UnitProfile::default();
    fs::write(&valid_target, serde_json::to_string(&target).unwrap()).unwrap();

    let output = run_cli([
        "run-matchup",
        "-a",
        bad_weapon.to_str().unwrap(),
        "-d",
        valid_target.to_str().unwrap(),
    ]);

    assert!(
        !output.status.success(),
        "Must exit with error on corrupted JSON"
    );

    let _ = fs::remove_dir_all(out_dir);
}

#[test]
fn test_match_stats_io_and_filtering() {
    let out_dir = temp_dir("match_stats_test");
    let store_file = out_dir.join("personal_store.json");

    let mut store = PersonalDataStore::default();

    // 1. 40k match: Orks win against Space Marines
    store.matches.push(MatchRecord {
        id: "m-ork-40k-1".to_string(),
        game_system: GameSystem::Warhammer40k,
        date_iso: "2026-10-25T14:00:00Z".to_string(),
        player_faction: "Orks".to_string(),
        opponent_faction: "Space Marines".to_string(),
        opponent_name: "Brother Titus".to_string(),
        player_score: 85,
        opponent_score: 60,
        result: MatchResult::Win,
        is_detailed: true,
        notes: "Green Tide overrun".to_string(),
        created_at_iso: "2026-10-25T14:00:00Z".to_string(),
        updated_at_iso: "2026-10-25T16:00:00Z".to_string(),
        wh40k_details: Some(Wh40kMatchDetails {
            battle_size: "Strike Force".to_string(),
            points_limit: 2000,
            rounds: vec![Wh40kRoundScore {
                round: 1,
                player_primary: 10,
                player_secondary: 5,
                opponent_primary: 5,
                opponent_secondary: 5,
                notes: String::new(),
            }],
            player_battle_ready_bonus: true,
            opponent_battle_ready_bonus: true,
            ..Default::default()
        }),
        kill_team_details: None,
    });

    // 2. 40k match: Orks loss against Necrons
    store.matches.push(MatchRecord {
        id: "m-ork-40k-2".to_string(),
        game_system: GameSystem::Warhammer40k,
        date_iso: "2026-10-24T18:00:00Z".to_string(),
        player_faction: "Orks".to_string(),
        opponent_faction: "Necrons".to_string(),
        opponent_name: "Overlord Szarekh".to_string(),
        player_score: 50,
        opponent_score: 75,
        result: MatchResult::Loss,
        is_detailed: false,
        notes: "C'tan shard survived".to_string(),
        created_at_iso: "2026-10-24T18:00:00Z".to_string(),
        updated_at_iso: "2026-10-24T20:00:00Z".to_string(),
        wh40k_details: None,
        kill_team_details: None,
    });

    // 3. Kill Team match: Orks win
    store.matches.push(MatchRecord {
        id: "m-ork-kt-1".to_string(),
        game_system: GameSystem::KillTeam,
        date_iso: "2026-10-23T11:00:00Z".to_string(),
        player_faction: "Orks".to_string(),
        opponent_faction: "Kommandos".to_string(),
        opponent_name: "Boss Snikrot".to_string(),
        player_score: 18,
        opponent_score: 12,
        result: MatchResult::Win,
        is_detailed: true,
        notes: "Close combat brawl".to_string(),
        created_at_iso: "2026-10-23T11:00:00Z".to_string(),
        updated_at_iso: "2026-10-23T12:00:00Z".to_string(),
        wh40k_details: None,
        kill_team_details: Some(KillTeamMatchDetails {
            player_painted_bonus: true,
            opponent_painted_bonus: true,
            turning_points: vec![KillTeamTurningPointScore {
                turning_point: 1,
                player_crit_op: 2,
                player_tac_op: 1,
                player_kill_op: 1,
                opponent_crit_op: 1,
                opponent_tac_op: 1,
                opponent_kill_op: 0,
                notes: String::new(),
            }],
            ..Default::default()
        }),
    });

    fs::write(&store_file, serde_json::to_string(&store).unwrap()).unwrap();

    // Test overall stats
    let output_all = run_cli(["match-stats", "--store", store_file.to_str().unwrap()]);
    assert!(output_all.status.success());
    let stdout_all = String::from_utf8_lossy(&output_all.stdout);
    assert!(stdout_all.contains("2W - 1L - 0D (66.7% Win Rate)"));
    assert!(stdout_all.contains("Orks"));

    // Test 40k only
    let output_40k = run_cli([
        "match-stats",
        "--store",
        store_file.to_str().unwrap(),
        "--system",
        "40k",
    ]);
    assert!(output_40k.status.success());
    let stdout_40k = String::from_utf8_lossy(&output_40k.stdout);
    assert!(stdout_40k.contains("1W - 1L - 0D (50.0% Win Rate)"));

    // Test Kill Team only
    let output_kt = run_cli([
        "match-stats",
        "--store",
        store_file.to_str().unwrap(),
        "--system",
        "kill_team",
    ]);
    assert!(output_kt.status.success());
    let stdout_kt = String::from_utf8_lossy(&output_kt.stdout);
    assert!(stdout_kt.contains("1W - 0L - 0D (100.0% Win Rate)"));

    // Test missing store file
    let output_err = run_cli(["match-stats", "--store", "non_existent_store.json"]);
    assert!(!output_err.status.success());

    let _ = fs::remove_dir_all(out_dir);
}
