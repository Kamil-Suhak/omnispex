mod args;

use args::{Cli, Commands, RunMatchupArgs, SimulateArgs};
use clap::Parser;
use omnispex_core::domain::dice::ValueExpr;
use omnispex_core::domain::unit::{ModelProfile, UnitProfile};
use omnispex_core::domain::weapon::{parse_weapon_ability, Keyword, WeaponProfile};
use omnispex_core::engine::context::CombatContext;
use omnispex_core::engine::simulator::{run_simulation, SimulationReport};
use std::fs;
use std::str::FromStr;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Simulate(sim_args) => handle_simulate(sim_args)?,
        Commands::RunMatchup(matchup_args) => handle_run_matchup(matchup_args)?,
    }

    Ok(())
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
    };

    let report = run_simulation(&weapon, &target, &context, args.iterations);
    print_report(&weapon, &target, &context, &report);

    Ok(())
}

fn handle_run_matchup(args: RunMatchupArgs) -> Result<(), Box<dyn std::error::Error>> {
    let weapon_json = fs::read_to_string(&args.attacker)?;
    let weapon: WeaponProfile = serde_json::from_str(&weapon_json)
        .map_err(|e| format!("Failed to parse weapon JSON {}: {}", args.attacker.display(), e))?;

    let target_json = fs::read_to_string(&args.defender)?;
    let target: UnitProfile = serde_json::from_str(&target_json)
        .map_err(|e| format!("Failed to parse target unit JSON {}: {}", args.defender.display(), e))?;

    let context = CombatContext {
        distance_inches: args.distance,
        is_stationary: args.stationary,
        has_charged: args.charged,
        in_engagement_range: false,
        target_has_benefit_of_cover: args.cover,
        target_visible: true,
        attacker_advanced: false,
    };

    let report = run_simulation(&weapon, &target, &context, args.iterations);
    print_report(&weapon, &target, &context, &report);

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
    println!(
        "Attacker: {} (A: {}, BS/WS: {}+, S: {}, AP: {}, D: {})",
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
        context.distance_inches.map_or("N/A".to_string(), |d| format!("{}\"", d)),
        if context.target_has_benefit_of_cover { "Yes" } else { "No" },
        if context.is_stationary { "Yes" } else { "No" }
    );
    println!("--------------------------------------------------------------------------------");
    println!("TACTICAL VERDICT: {}", report.tactical_verdict.label());
    println!("--------------------------------------------------------------------------------");
    println!("SUMMARY METRICS");
    println!("--------------------------------------------------------------------------------");
    println!(
        "Expected Models Killed : {:.2} ± {:.2}",
        report.expected_models_killed, report.std_dev_kills
    );
    println!(
        "Safe Bet (80% Floor)   : {} models",
        report.safe_bet_kills_80
    );
    println!(
        "Expected Damage Dealt  : {:.2} ± {:.2} (Overkill loss: {:.2})",
        report.expected_damage_dealt, report.std_dev_damage, report.spillover_damage_lost
    );
    println!(
        "Squad Wipe Probability : {:.2}%",
        report.wipe_probability * 100.0
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
