mod common;

use common::run_cli;

#[test]
fn test_cli_ork_shoota_calculation_accuracy() {
    // Ork Shoota: A: 2, BS: 5+, S: 4, AP: 0, D: 1
    // Defender: Intercessors (5 models, T: 4, Sv: 3+, W: 2)
    // Exact analytical:
    // Attacks = 2.0
    // P(Hit) = 2/6 = 33.3%
    // P(Wound) = 3/6 = 50.0%
    // P(Unsaved) = 2/6 = 33.3%
    // Expected unsaved = 2 * (1/3) * (1/2) * (1/3) = 2/18 = 1/9 ≈ 0.1111
    let output = run_cli([
        "simulate",
        "--weapon-name",
        "Ork Shoota",
        "--attacks",
        "2",
        "--bs",
        "5",
        "--str",
        "4",
        "--ap",
        "0",
        "--dmg",
        "1",
        "--target-name",
        "Intercessors",
        "--target-t",
        "4",
        "--target-sv",
        "3",
        "--target-w",
        "2",
        "--target-count",
        "5",
        "--iterations",
        "15000",
    ]);

    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);

    assert!(stdout.contains("Expected Attacks       : 2.00"));
    assert!(stdout.contains("P(Hit): 33.3%"));
    assert!(stdout.contains("P(Wound): 50.0%"));
    assert!(stdout.contains("P(Unsaved | Normal Wd) : 33.3%"));
    assert!(stdout.contains("Expected Unsaved Wounds: 0.11"));
    assert!(stdout.contains("Unclipped E[Dmg]: 0.11"));
    assert!(stdout.contains("TACTICAL VERDICT: Ineffective Target"));
}

#[test]
fn test_cli_ork_choppa_melee_accuracy() {
    // Ork Choppa: A: 3, WS: 3+, S: 4, AP: 1, D: 1
    // Defender: Intercessors (T: 4, Sv: 3+, W: 2)
    // Exact analytical:
    // P(Hit) = 4/6 = 66.7%
    // P(Wound) = 3/6 = 50.0%
    // P(Unsaved) = Sv 3+ vs AP 1 => 4+ sv => 3/6 unsaved = 50.0%
    // Expected unsaved = 3 * (2/3) * (1/2) * (1/2) = 0.50
    let output = run_cli([
        "simulate",
        "--weapon-name",
        "Choppa",
        "--attacks",
        "3",
        "--bs",
        "3",
        "--str",
        "4",
        "--ap",
        "1",
        "--dmg",
        "1",
        "--target-name",
        "Intercessors",
        "--target-t",
        "4",
        "--target-sv",
        "3",
        "--target-w",
        "2",
        "--target-count",
        "5",
        "--iterations",
        "15000",
    ]);

    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);

    assert!(stdout.contains("Expected Attacks       : 3.00"));
    assert!(stdout.contains("P(Hit): 66.7%"));
    assert!(stdout.contains("P(Wound): 50.0%"));
    assert!(stdout.contains("P(Unsaved | Normal Wd) : 50.0%"));
    assert!(stdout.contains("Expected Unsaved Wounds: 0.50"));
    assert!(stdout.contains("Unclipped E[Dmg]: 0.50"));
}

#[test]
fn test_cli_ork_power_klaw_vs_rhino() {
    // Nob Power Klaw: A: 4, WS: 4+, S: 9, AP: 2, D: 2
    // Defender: Rhino (T: 9, Sv: 3+, W: 10, count: 1)
    // S9 vs T9 => 4+ to wound (3/6 = 50.0%)
    // Sv 3+ vs AP 2 => 5+ sv => 4/6 unsaved = 66.7%
    // Expected unsaved = 4 * (3/6) * (3/6) * (4/6) = 4 * 0.5 * 0.5 * (2/3) = 4/6 = 0.6667
    // Unclipped E[Dmg] = 0.6667 * 2 = 1.3333
    let output = run_cli([
        "simulate",
        "--weapon-name",
        "Power Klaw",
        "--attacks",
        "4",
        "--bs",
        "4",
        "--str",
        "9",
        "--ap",
        "2",
        "--dmg",
        "2",
        "--target-name",
        "Rhino",
        "--target-t",
        "9",
        "--target-sv",
        "3",
        "--target-w",
        "10",
        "--target-count",
        "1",
        "--iterations",
        "15000",
    ]);

    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);

    assert!(stdout.contains("Expected Attacks       : 4.00"));
    assert!(stdout.contains("P(Hit): 50.0%"));
    assert!(stdout.contains("P(Wound): 50.0%"));
    assert!(stdout.contains("P(Unsaved | Normal Wd) : 66.7%"));
    assert!(stdout.contains("Expected Unsaved Wounds: 0.67"));
    assert!(stdout.contains("Unclipped E[Dmg]: 1.33"));
}

#[test]
fn test_cli_sustained_hits_and_blast() {
    // Ork Dakkagun with Sustained Hits 1
    // Attacks: 3, BS: 5+, S: 5, AP: 0, D: 1
    // Target: Guardsmen (T: 3, Sv: 5+, W: 1, count: 10)
    let output = run_cli([
        "simulate",
        "--weapon-name",
        "Dakkagun",
        "--attacks",
        "3",
        "--bs",
        "5",
        "--str",
        "5",
        "--ap",
        "0",
        "--dmg",
        "1",
        "--abilities",
        "Sustained Hits 1",
        "--target-name",
        "Guardsmen",
        "--target-t",
        "3",
        "--target-sv",
        "5",
        "--target-w",
        "1",
        "--target-count",
        "10",
        "--iterations",
        "10000",
    ]);

    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("Sustained Hits 1"));
    // Sustained damage audit present
    assert!(stdout.contains("Sustained:"));

    // Killkannon Blast on 20 Ork Boyz:
    // Base attacks D6+3 (mean 6.5) + Blast 4 (1 per 5 models in 20-model unit) = 10.5 attacks
    let output_blast = run_cli([
        "simulate",
        "--weapon-name",
        "Killkannon",
        "--attacks",
        "D6+3",
        "--bs",
        "4",
        "--str",
        "9",
        "--ap",
        "2",
        "--dmg",
        "2",
        "--abilities",
        "Blast",
        "--target-name",
        "Boyz Mob",
        "--target-t",
        "5",
        "--target-sv",
        "5",
        "--target-w",
        "1",
        "--target-count",
        "20",
        "--iterations",
        "10000",
    ]);

    assert!(output_blast.status.success());
    let stdout_blast = String::from_utf8_lossy(&output_blast.stdout);
    assert!(stdout_blast.contains("Expected Attacks       : 10.50"));
    assert!(stdout_blast.contains("Overkill loss:"));
}

#[test]
fn test_cli_rerolls_and_defensive_mitigation() {
    // 1. Full hit re-rolls
    let output_reroll = run_cli([
        "simulate",
        "--weapon-name",
        "Twin Big Shoota",
        "--attacks",
        "6",
        "--bs",
        "5",
        "--str",
        "5",
        "--ap",
        "0",
        "--dmg",
        "1",
        "--hit-reroll",
        "full",
        "--target-name",
        "Boyz",
        "--target-t",
        "5",
        "--target-sv",
        "5",
        "--target-w",
        "1",
        "--target-count",
        "10",
    ]);
    assert!(output_reroll.status.success());
    let stdout_reroll = String::from_utf8_lossy(&output_reroll.stdout);
    // BS 5+ with full reroll: 1/3 + (2/3 * 1/3) = 5/9 ≈ 55.6%
    assert!(stdout_reroll.contains("P(Hit): 55.6%"));

    // 2. Armor of Contempt (-1 AP)
    let output_aoc = run_cli([
        "simulate",
        "--weapon-name",
        "Kannon",
        "--attacks",
        "1",
        "--bs",
        "4",
        "--str",
        "8",
        "--ap",
        "2",
        "--dmg",
        "D6",
        "--aoc",
        "--target-name",
        "Terminator",
        "--target-t",
        "5",
        "--target-sv",
        "2",
        "--target-w",
        "3",
        "--target-count",
        "1",
    ]);
    assert!(output_aoc.status.success());
    let stdout_aoc = String::from_utf8_lossy(&output_aoc.stdout);
    // Sv 2+ vs AP 2 modified by AoC (-1 AP) => effective AP 1 => Sv 3+ => 2/6 = 33.3% unsaved
    assert!(stdout_aoc.contains("P(Unsaved | Normal Wd) : 33.3%"));

    // 3. Target Feel No Pain 5+
    let output_fnp = run_cli([
        "simulate",
        "--weapon-name",
        "Klaw",
        "--attacks",
        "4",
        "--bs",
        "3",
        "--str",
        "9",
        "--ap",
        "2",
        "--dmg",
        "2",
        "--target-fnp",
        "5",
        "--target-name",
        "Painboy Unit",
        "--target-t",
        "5",
        "--target-sv",
        "4",
        "--target-w",
        "2",
        "--target-count",
        "5",
    ]);
    assert!(output_fnp.status.success());
    let stdout_fnp = String::from_utf8_lossy(&output_fnp.stdout);
    assert!(stdout_fnp.contains("FNP: 5+"));
}
