mod args;

use args::{
    BuildCatalogueBundleArgs, Cli, Commands, MatchStatsArgs, RunMatchupArgs, SearchUnitsArgs,
    SimulateArgs, ValidateListArgs,
};
use clap::Parser;
use omnispex_core::domain::army_list::{export_army_list_text, validate_army_list, ArmyList};
use omnispex_core::domain::catalogue::{CatalogueDatabase, DataProvenance};
use omnispex_core::domain::dice::ValueExpr;
use omnispex_core::domain::matches::{compute_match_statistics, GameSystem};
use omnispex_core::domain::unit::{ModelProfile, UnitProfile};
use omnispex_core::domain::weapon::{parse_weapon_ability, Keyword, ReRollMode, WeaponProfile};
use omnispex_core::engine::context::CombatContext;
use omnispex_core::engine::simulator::{run_simulation, SimulationReport};
use omnispex_core::parser::build_catalogue_database_from_maps;
use omnispex_core::storage::PersonalDataStore;
use std::fs;
use std::str::FromStr;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Simulate(sim_args) => handle_simulate(sim_args)?,
        Commands::RunMatchup(matchup_args) => handle_run_matchup(matchup_args)?,
        Commands::BuildCatalogueBundle(bundle_args) => handle_build_catalogue_bundle(bundle_args)?,
        Commands::SearchUnits(search_args) => handle_search_units(search_args)?,
        Commands::ValidateList(val_args) => handle_validate_list(val_args)?,
        Commands::MatchStats(stats_args) => handle_match_stats(stats_args)?,
    }

    Ok(())
}

fn parse_reroll_mode(s: &str) -> ReRollMode {
    match s.trim().to_lowercase().as_str() {
        "1" | "ones" | "one" => ReRollMode::Ones,
        "all" | "full" => ReRollMode::Full,
        _ => ReRollMode::None,
    }
}

fn handle_simulate(args: SimulateArgs) -> Result<(), Box<dyn std::error::Error>> {
    let attacks = ValueExpr::from_str(&args.attacks)
        .map_err(|e| format!("Invalid attack expression '{}': {}", args.attacks, e))?;
    let damage = ValueExpr::from_str(&args.damage)
        .map_err(|e| format!("Invalid damage expression '{}': {}", args.damage, e))?;

    let mut abilities = Vec::new();
    for ab_str in &args.abilities {
        if let Some(ab) = parse_weapon_ability(ab_str) {
            abilities.push(ab);
        } else {
            eprintln!("Warning: Unrecognized weapon ability '{}'", ab_str);
        }
    }

    let weapon = WeaponProfile::new(
        args.weapon_name,
        args.range,
        attacks,
        args.bs,
        args.strength,
        args.ap,
        damage,
        abilities,
    );

    let target_keywords: Vec<Keyword> = args
        .target_keywords
        .iter()
        .map(|s| Keyword::from(s.as_str()))
        .collect();

    let model = ModelProfile::new(
        args.target_name.clone(),
        args.target_w,
        args.target_sv,
        args.target_invuln,
        args.target_fnp,
    )
    .with_keywords(target_keywords.clone());

    let target = UnitProfile::uniform(
        args.target_name,
        args.target_t,
        model,
        args.target_count,
        target_keywords,
    );

    let context = CombatContext {
        distance_inches: args.distance,
        is_stationary: args.stationary,
        has_charged: args.charged,
        in_engagement_range: args.in_engagement,
        target_has_benefit_of_cover: args.cover,
        target_visible: true,
        attacker_advanced: false,
        hit_reroll: parse_reroll_mode(&args.hit_reroll),
        wound_reroll: parse_reroll_mode(&args.wound_reroll),
        armor_of_contempt: args.armor_of_contempt,
        ..CombatContext::default()
    };

    let report = run_simulation(&weapon, &target, &context, args.iterations);
    print_report(&weapon, &target, &context, &report);

    Ok(())
}

fn handle_run_matchup(args: RunMatchupArgs) -> Result<(), Box<dyn std::error::Error>> {
    let weapon_json = fs::read_to_string(&args.attacker)?;
    let weapon: WeaponProfile = serde_json::from_str(&weapon_json).map_err(|e| {
        format!(
            "Failed to parse weapon JSON {}: {}",
            args.attacker.display(),
            e
        )
    })?;

    let target_json = fs::read_to_string(&args.defender)?;
    let target: UnitProfile = serde_json::from_str(&target_json).map_err(|e| {
        format!(
            "Failed to parse target unit JSON {}: {}",
            args.defender.display(),
            e
        )
    })?;

    let context = CombatContext {
        distance_inches: args.distance,
        is_stationary: args.stationary,
        has_charged: args.charged,
        in_engagement_range: false,
        target_has_benefit_of_cover: args.cover,
        target_visible: true,
        attacker_advanced: false,
        ..CombatContext::default()
    };

    let report = run_simulation(&weapon, &target, &context, args.iterations);
    print_report(&weapon, &target, &context, &report);

    Ok(())
}

fn handle_build_catalogue_bundle(
    args: BuildCatalogueBundleArgs,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut bsdata_files = Vec::new();
    for entry in fs::read_dir(&args.bsdata_dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) == Some("json") {
            let fname = path
                .file_name()
                .and_then(|s| s.to_str())
                .unwrap_or("")
                .to_string();
            let content = fs::read_to_string(&path)?;
            bsdata_files.push((fname, content));
        }
    }

    let mut mfm_files = Vec::new();
    if let Some(mfm_dir) = &args.mfm_dir {
        if mfm_dir.exists() {
            for entry in fs::read_dir(mfm_dir)? {
                let entry = entry?;
                let path = entry.path();
                let ext = path.extension().and_then(|s| s.to_str()).unwrap_or("");
                if ext == "yaml" || ext == "yml" {
                    let fname = path
                        .file_name()
                        .and_then(|s| s.to_str())
                        .unwrap_or("")
                        .to_string();
                    let content = fs::read_to_string(&path)?;
                    mfm_files.push((fname, content));
                }
            }
        }
    }

    let db = build_catalogue_database_from_maps(
        &bsdata_files,
        &mfm_files,
        DataProvenance::default(),
    )
    .map_err(|e| format!("Catalogue bundle build error: {}", e))?;

    if let Some(parent) = args.output.parent() {
        fs::create_dir_all(parent)?;
    }
    let out_json = serde_json::to_string(&db)?;
    fs::write(&args.output, out_json)?;

    let total_units: usize = db.factions.iter().map(|f| f.units.len()).sum();
    let total_detachments: usize = db.factions.iter().map(|f| f.detachments.len()).sum();
    println!(
        "Built normalized CatalogueDatabase bundle at {}",
        args.output.display()
    );
    println!(
        "Factions: {} | Detachments: {} | Datasheets: {}",
        db.factions.len(),
        total_detachments,
        total_units
    );

    Ok(())
}

fn handle_search_units(args: SearchUnitsArgs) -> Result<(), Box<dyn std::error::Error>> {
    let raw = fs::read_to_string(&args.bundle)?;
    let db: CatalogueDatabase = serde_json::from_str(&raw)?;
    let results = db.search_units(
        &args.query,
        args.faction.as_deref(),
        args.category.as_deref(),
        args.include_legends,
    );

    println!(
        "Found {} matching units (Edition: {}, MFM v{}):",
        results.len(),
        db.provenance.edition,
        db.provenance.mfm_version
    );
    println!("--------------------------------------------------------------------------------");
    for u in results.iter().take(50) {
        let pts = u.base_points();
        let model = u.profile.expanded_models();
        let sv = model.first().map_or(3, |m| m.save);
        let w = model.first().map_or(1, |m| m.wounds);
        println!(
            "[{:<22}] {:<32} | {:>4} pts | M:{} T:{} Sv:{}+ W:{} OC:{} | Weapons: {}",
            u.faction_name,
            u.name,
            pts,
            u.profile.movement,
            u.profile.toughness,
            sv,
            w,
            u.profile.objective_control,
            u.weapons.len()
        );
    }
    if results.len() > 50 {
        println!("... and {} more units.", results.len() - 50);
    }

    Ok(())
}

fn handle_validate_list(args: ValidateListArgs) -> Result<(), Box<dyn std::error::Error>> {
    let list_raw = fs::read_to_string(&args.list)?;
    let mut list: ArmyList = serde_json::from_str(&list_raw)?;

    let db: Option<CatalogueDatabase> = if let Some(bundle_path) = &args.bundle {
        let raw = fs::read_to_string(bundle_path)?;
        Some(serde_json::from_str(&raw)?)
    } else {
        None
    };

    if let Some(ref d) = db {
        if let Some(fcat) = d
            .find_faction(&list.faction_id)
            .or_else(|| d.find_faction(&list.faction_name))
        {
            list.recalculate_points(fcat);
        }
    }

    let report = validate_army_list(&list, db.as_ref());
    println!("================================================================================");
    println!(
        "ROSTER VALIDATION: {} ({})",
        list.name,
        if report.is_valid { "LEGAL" } else { "ILLEGAL" }
    );
    println!("================================================================================");
    println!(
        "Faction     : {} | Battle Size: {}",
        list.faction_name,
        list.battle_size.label()
    );
    println!(
        "Points      : {} / {} pts | Detachment Points: {} / {} DP | Enhancements: {} / {}",
        report.total_points,
        report.points_limit,
        report.total_dp,
        report.dp_limit,
        report.enhancement_slots_used,
        report.enhancement_limit
    );

    if !report.violations.is_empty() {
        println!("\nCONFIRMED RULE VIOLATIONS:");
        for v in &report.violations {
            println!("  [ERROR] {}: {}", v.code, v.message);
        }
    }
    if !report.warnings.is_empty() {
        println!("\nWARNINGS:");
        for w in &report.warnings {
            println!("  [WARN]  {}: {}", w.code, w.message);
        }
    }
    if !report.unverified_rules.is_empty() {
        println!("\nPROSE / DATASHEET CHECKS REQUIRING PLAYER VERIFICATION:");
        for notice in &report.unverified_rules {
            println!("  [INFO]  {}", notice);
        }
    }

    if args.export_text {
        println!("\n--------------------------------------------------------------------------------");
        println!("{}", export_army_list_text(&list, Some(&report)));
    }

    Ok(())
}

fn handle_match_stats(args: MatchStatsArgs) -> Result<(), Box<dyn std::error::Error>> {
    let raw = fs::read_to_string(&args.store)?;
    let store = PersonalDataStore::from_json_migrated(&raw)?;
    let gs_filter = args.system.as_deref().and_then(|s| match s.to_lowercase().as_str() {
        "40k" | "warhammer40k" | "wh40k" => Some(GameSystem::Warhammer40k),
        "kt" | "killteam" | "kill_team" => Some(GameSystem::KillTeam),
        _ => None,
    });

    let report = compute_match_statistics(&store.matches, gs_filter, args.faction.as_deref());
    println!("================================================================================");
    println!("OMNISPEX MATCH PERFORMANCE REPORT");
    println!("================================================================================");
    println!("{}", report.scope_explanation);
    println!(
        "Record      : {}W - {}L - {}D ({:.1}% Win Rate)",
        report.wins, report.losses, report.draws, report.win_rate_percent
    );
    println!(
        "Avg Scores  : Player {:.1} vs Opponent {:.1} (Diff: {:+.1})",
        report.average_player_score, report.average_opponent_score, report.average_differential
    );
    if !report.by_player_faction.is_empty() {
        println!("\nBY PLAYER FACTION:");
        for fp in &report.by_player_faction {
            println!(
                "  - {:<24}: {} games ({}W-{}L-{}D, {:.1}% WR)",
                fp.faction, fp.games_played, fp.wins, fp.losses, fp.draws, fp.win_rate_percent
            );
        }
    }

    Ok(())
}

fn print_report(
    weapon: &WeaponProfile,
    target: &UnitProfile,
    context: &CombatContext,
    report: &SimulationReport,
) {
    println!("================================================================================");
    println!("                           OMNISPEX SIMULATION REPORT                           ");
    println!("================================================================================");
    println!("Method  : {}", report.calculation_method);
    println!(
        "Attacker: {} (A: {}, BS/WS: {}+, S: {}, AP: -{}, D: {})",
        weapon.name, weapon.attacks, weapon.skill, weapon.strength, weapon.ap, weapon.damage
    );
    if !weapon.abilities.is_empty() {
        println!("Abilities: {:?}", weapon.abilities);
    }
    let expanded = target.expanded_models();
    let first_save = expanded.first().map_or(3, |m| m.save);
    let first_wounds = expanded.first().map_or(1, |m| m.wounds);
    println!(
        "Defender: {} ({} models, T: {}, SV: {}+, W: {})",
        target.name,
        target.total_models(),
        target.toughness,
        first_save,
        first_wounds
    );
    if !target.defensive_abilities.is_empty() {
        println!("Defensive Abilities: {:?}", target.defensive_abilities);
    }
    println!(
        "Context : Iterations: {} | Distance: {} | Cover: {} | Stationary: {}",
        report.iterations,
        context
            .distance_inches
            .map_or("N/A".to_string(), |d| format!("{}\"", d)),
        if context.target_has_benefit_of_cover {
            "Yes"
        } else {
            "No"
        },
        if context.is_stationary { "Yes" } else { "No" }
    );
    println!("--------------------------------------------------------------------------------");
    println!("TACTICAL VERDICT: {}", report.tactical_verdict.label());
    println!("--------------------------------------------------------------------------------");
    println!("EXACT ANALYTICAL STAGE PROBABILITIES");
    println!("--------------------------------------------------------------------------------");
    let st = &report.stage_probabilities;
    println!(
        "Expected Attacks       : {:.2} | P(Hit): {:.1}% (Crit: {:.1}%) | P(Wound): {:.1}% (Crit: {:.1}%)",
        st.expected_attacks,
        st.hit_probability * 100.0,
        st.crit_hit_probability * 100.0,
        st.wound_probability * 100.0,
        st.crit_wound_probability * 100.0
    );
    println!(
        "P(Unsaved | Normal Wd) : {:.1}% | Expected Unsaved Wounds: {:.2} | Unclipped E[Dmg]: {:.2}",
        st.unsaved_probability_given_normal_wound * 100.0,
        st.expected_unsaved_wounds,
        st.expected_total_unclipped_damage
    );
    println!("--------------------------------------------------------------------------------");
    println!("MONTE CARLO WOUND ALLOCATION SUMMARY");
    println!("--------------------------------------------------------------------------------");
    println!(
        "Expected Models Killed : {:.2} ± {:.2}",
        report.expected_models_killed, report.std_dev_kills
    );
    println!(
        "Safe Bet (80% Floor)   : {} models ({} damage)",
        report.safe_bet_kills_80, report.safe_bet_damage_80
    );
    println!(
        "Expected Damage Dealt  : {:.2} ± {:.2} (Overkill loss: {:.2})",
        report.expected_damage_dealt, report.std_dev_damage, report.spillover_damage_lost
    );
    println!(
        "Squad Wipe Probability : {:.2}% | >=50% Bracket Prob: {:.2}%",
        report.wipe_probability * 100.0,
        report.bracket_50_probability * 100.0
    );
    println!(
        "Percentiles (Kills)    : p10: {}, p25: {}, p50 (Median): {}, p75: {}, p90: {}",
        report.percentiles.p10,
        report.percentiles.p25,
        report.percentiles.p50,
        report.percentiles.p75,
        report.percentiles.p90
    );
    if report.keyword_audit.lethal_damage > 0.0
        || report.keyword_audit.sustained_damage > 0.0
        || report.keyword_audit.devastating_damage > 0.0
    {
        println!(
            "Keyword Damage Audit   : Lethal: {:.2}, Sustained: {:.2}, Devastating: {:.2}, Standard: {:.2}",
            report.keyword_audit.lethal_damage,
            report.keyword_audit.sustained_damage,
            report.keyword_audit.devastating_damage,
            report.keyword_audit.standard_damage
        );
    }
    if !report.unsupported_notices.is_empty() {
        println!("--------------------------------------------------------------------------------");
        println!("RULE MECHANIC NOTES:");
        for note in &report.unsupported_notices {
            println!("  * {}", note);
        }
    }
    println!("--------------------------------------------------------------------------------");
    println!("KILL PROBABILITY DISTRIBUTION");
    println!("--------------------------------------------------------------------------------");

    let max_prob = report
        .kill_distribution
        .iter()
        .map(|&(_, p)| p)
        .fold(0.0f64, f64::max);

    let bar_width = 30;

    for &(k, prob) in &report.kill_distribution {
        let percent = prob * 100.0;
        let filled_len = if max_prob > 0.0 {
            ((prob / max_prob) * (bar_width as f64)).round() as usize
        } else {
            0
        };
        let bar: String = "█".repeat(filled_len);
        println!("  {:2} kills: {:5.1}% | {}", k, percent, bar);
    }
    println!("================================================================================");
}
