mod common;

use common::{project_root, run_cli, temp_dir};
use omnispex_core::domain::catalogue::CatalogueDatabase;
use std::fs;

#[test]
fn test_build_bundle_from_real_orks_bsdata() {
    let root = project_root();
    let ref_dir = root.join("reference");
    let out_dir = temp_dir("data_ingest_orks");
    let out_bundle = out_dir.join("orks_bundle.json");

    if !ref_dir.join("Orks.json").exists() {
        eprintln!("Notice: reference/Orks.json not found, skipping live BSData ingestion test");
        return;
    }

    let output = run_cli([
        "build-catalogue-bundle",
        "--bsdata-dir",
        ref_dir.to_str().unwrap(),
        "-o",
        out_bundle.to_str().unwrap(),
    ]);

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    assert!(
        output.status.success(),
        "build-catalogue-bundle failed: {}\nStderr: {}",
        stdout,
        stderr
    );
    assert!(stdout.contains("Built normalized CatalogueDatabase bundle"));
    assert!(stdout.contains("Factions: 1"));
    assert!(stdout.contains("Datasheets:"));

    assert!(out_bundle.exists(), "Output bundle file must be created");
    let bundle_content = fs::read_to_string(&out_bundle).expect("Read bundle");
    let db: CatalogueDatabase =
        serde_json::from_str(&bundle_content).expect("Deserialize CatalogueDatabase");

    assert_eq!(db.factions.len(), 1);
    let orks = &db.factions[0];
    assert!(
        orks.name.contains("Orks"),
        "Faction name must contain 'Orks', got: {}",
        orks.name
    );
    assert!(
        orks.units.len() >= 60,
        "Expected at least 60 Ork datasheets, found: {}",
        orks.units.len()
    );

    // Verify key units exist
    let unit_names: Vec<&str> = orks.units.iter().map(|u| u.name.as_str()).collect();
    assert!(unit_names.contains(&"Battlewagon"));
    assert!(unit_names.contains(&"Ghazghkull Thraka"));
    assert!(unit_names.contains(&"Boyz"));
    assert!(unit_names.contains(&"Trukk"));
    assert!(unit_names.contains(&"Deff Dread"));
    assert!(unit_names.contains(&"Warboss"));

    // Verify Battlewagon profiles and weapons
    let bw = orks.units.iter().find(|u| u.name == "Battlewagon").unwrap();
    assert_eq!(bw.profile.toughness, 11);
    let bw_models = bw.profile.expanded_models();
    assert_eq!(bw_models[0].save, 3);
    assert_eq!(bw_models[0].wounds, 16);
    assert!(
        bw.weapons
            .iter()
            .any(|w| w.name.contains("Big Shoota") || w.name.contains("Lobba")),
        "Expected Battlewagon weapons to include Lobba or Big Shoota, found: {:?}",
        bw.weapons.iter().map(|w| &w.name).collect::<Vec<_>>()
    );

    // Verify Ghazghkull Thraka has updated 11e profile: Character, Epic Hero, T10, 16 Wounds
    let ghaz = orks
        .units
        .iter()
        .find(|u| u.name == "Ghazghkull Thraka")
        .unwrap();
    assert!(ghaz.is_epic_hero());
    assert!(ghaz.is_character());
    assert_eq!(ghaz.profile.toughness, 10);
    let ghaz_models = ghaz.profile.expanded_models();
    assert_eq!(ghaz_models[0].wounds, 16);

    let _ = fs::remove_dir_all(out_dir);
}

#[test]
fn test_build_bundle_missing_directory_reports_error() {
    let out_dir = temp_dir("missing_dir_test");
    let non_existent = out_dir.join("does_not_exist_987654");
    let out_bundle = out_dir.join("bundle.json");

    let output = run_cli([
        "build-catalogue-bundle",
        "--bsdata-dir",
        non_existent.to_str().unwrap(),
        "-o",
        out_bundle.to_str().unwrap(),
    ]);

    assert!(
        !output.status.success(),
        "Command must fail when directory does not exist"
    );

    let _ = fs::remove_dir_all(out_dir);
}

#[test]
fn test_build_bundle_corrupted_json_reports_error() {
    let out_dir = temp_dir("corrupt_json_test");
    let bad_json_dir = out_dir.join("bad_bsdata");
    fs::create_dir_all(&bad_json_dir).unwrap();
    fs::write(
        bad_json_dir.join("Orks_Broken.json"),
        "{ \"catalogue\": { broken json here ... ",
    )
    .unwrap();

    let out_bundle = out_dir.join("bundle.json");
    let output = run_cli([
        "build-catalogue-bundle",
        "--bsdata-dir",
        bad_json_dir.to_str().unwrap(),
        "-o",
        out_bundle.to_str().unwrap(),
    ]);

    assert!(
        !output.status.success(),
        "Command must fail on malformed JSON"
    );
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("Invalid JSON") || stderr.contains("error"),
        "Stderr must report JSON error, got: {}",
        stderr
    );

    let _ = fs::remove_dir_all(out_dir);
}

#[test]
fn test_search_units_cli_filtering() {
    let root = project_root();
    let bundle_path = root.join("flutter_ui/assets/data/wh40k_11e_bundle.json");

    assert!(
        bundle_path.exists(),
        "wh40k_11e_bundle.json must exist for CLI search tests"
    );

    // 1. Search for Battlewagon
    let output = run_cli([
        "search-units",
        "-b",
        bundle_path.to_str().unwrap(),
        "-q",
        "Battlewagon",
    ]);
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("Battlewagon"));
    assert!(stdout.contains("pts"));
    assert!(stdout.contains("Sv:3+"));
    assert!(stdout.contains("W:16"));

    // 2. Search for Boyz with Category filter
    let output_inf = run_cli([
        "search-units",
        "-b",
        bundle_path.to_str().unwrap(),
        "-q",
        "Boyz",
        "-c",
        "Infantry",
    ]);
    assert!(output_inf.status.success());
    let stdout_inf = String::from_utf8_lossy(&output_inf.stdout);
    assert!(stdout_inf.contains("Boyz"));
    assert!(!stdout_inf.contains("Hunta Rig")); // Vehicle must be excluded

    // 3. Search non-existent
    let output_none = run_cli([
        "search-units",
        "-b",
        bundle_path.to_str().unwrap(),
        "-q",
        "ZzzUnknownOrkUnit999",
    ]);
    assert!(output_none.status.success());
    let stdout_none = String::from_utf8_lossy(&output_none.stdout);
    assert!(stdout_none.contains("Found 0 matching units"));
}
