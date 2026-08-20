use crate::domain::archetypes::ArchetypeRoster;
use crate::domain::unit::UnitProfile;
use crate::domain::weapon::WeaponProfile;
use crate::engine::context::CombatContext;
use crate::engine::simulator::{run_simulation, SimulationReport};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ProfileComparisonEntry {
    pub weapon: WeaponProfile,
    pub report: SimulationReport,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ProfileComparisonReport {
    pub target: UnitProfile,
    pub context: CombatContext,
    pub entries: Vec<ProfileComparisonEntry>,
    pub recommended_index: usize,
    pub efficiency_delta_percent: f64,
    pub summary_verdict: String,
}

pub fn compare_profiles(
    weapons: &[WeaponProfile],
    target: &UnitProfile,
    context: &CombatContext,
    iterations: u32,
) -> Result<ProfileComparisonReport, &'static str> {
    if weapons.is_empty() {
        return Err("No weapon profiles provided for comparison");
    }

    let mut entries = Vec::with_capacity(weapons.len());
    for weapon in weapons {
        let report = run_simulation(weapon, target, context, iterations);
        entries.push(ProfileComparisonEntry {
            weapon: weapon.clone(),
            report,
        });
    }

    let mut best_idx = 0;
    let mut best_score = -1.0f64;

    for (i, entry) in entries.iter().enumerate() {
        let score = entry.report.expected_models_killed * 100.0 + entry.report.expected_damage_dealt;
        if score > best_score {
            best_score = score;
            best_idx = i;
        }
    }

    let runner_up_score = entries
        .iter()
        .enumerate()
        .filter(|&(i, _)| i != best_idx)
        .map(|(_, e)| e.report.expected_models_killed * 100.0 + e.report.expected_damage_dealt)
        .fold(0.0f64, f64::max);

    let efficiency_delta_percent = if runner_up_score > 0.0 {
        ((best_score - runner_up_score) / runner_up_score) * 100.0
    } else {
        0.0
    };

    let best_name = &entries[best_idx].weapon.name;
    let summary_verdict = if entries.len() > 1 && efficiency_delta_percent > 0.0 {
        format!(
            "Use {} (+{:.1}% higher combat output into {})",
            best_name, efficiency_delta_percent, target.name
        )
    } else {
        format!("Optimal choice: {}", best_name)
    };

    Ok(ProfileComparisonReport {
        target: target.clone(),
        context: context.clone(),
        entries,
        recommended_index: best_idx,
        efficiency_delta_percent,
        summary_verdict,
    })
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ArchetypeBenchmarkEntry {
    pub archetype_id: String,
    pub archetype_label: String,
    pub report: SimulationReport,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ArchetypeBenchmarkReport {
    pub weapon: WeaponProfile,
    pub context: CombatContext,
    pub entries: Vec<ArchetypeBenchmarkEntry>,
}

pub fn evaluate_archetypes(
    weapon: &WeaponProfile,
    roster: &ArchetypeRoster,
    context: &CombatContext,
    iterations: u32,
) -> ArchetypeBenchmarkReport {
    let mut entries = Vec::with_capacity(roster.archetypes.len());
    for arch in &roster.archetypes {
        let report = run_simulation(weapon, &arch.target, context, iterations);
        entries.push(ArchetypeBenchmarkEntry {
            archetype_id: arch.id.clone(),
            archetype_label: arch.label.clone(),
            report,
        });
    }

    ArchetypeBenchmarkReport {
        weapon: weapon.clone(),
        context: context.clone(),
        entries,
    }
}
