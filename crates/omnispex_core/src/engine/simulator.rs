use crate::domain::unit::UnitProfile;
use crate::domain::weapon::WeaponProfile;
use crate::engine::context::CombatContext;
use crate::engine::pipeline::resolve_volley;
use rand::thread_rng;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SimulationReport {
    pub iterations: u32,
    pub total_models: usize,
    pub expected_models_killed: f64,
    pub expected_damage_dealt: f64,
    pub wipe_probability: f64,
    pub std_dev_kills: f64,
    pub std_dev_damage: f64,
    pub kill_distribution: Vec<(u32, f64)>,
    pub damage_distribution: Vec<(u32, f64)>,
}

pub fn run_simulation(
    weapon: &WeaponProfile,
    target: &UnitProfile,
    context: &CombatContext,
    iterations: u32,
) -> SimulationReport {
    let num_iterations = iterations.max(1);
    let mut rng = thread_rng();
    let total_models = target.total_models();

    let mut kill_counts = vec![0u32; total_models + 1];
    let mut max_damage_seen = 0usize;
    let mut damage_counts: Vec<u32> = Vec::new();

    let mut total_kills = 0u64;
    let mut total_damage = 0u64;
    let mut wipes = 0u64;

    let mut kills_samples = Vec::with_capacity(num_iterations as usize);
    let mut damage_samples = Vec::with_capacity(num_iterations as usize);

    for _ in 0..num_iterations {
        let mut wounds = target.initial_wounds();
        let outcome = resolve_volley(weapon, target, context, &mut wounds, &mut rng);

        let kills = outcome.models_killed as usize;
        let damage = outcome.damage_dealt as usize;

        if kills >= kill_counts.len() {
            kill_counts.resize(kills + 1, 0);
        }
        kill_counts[kills] += 1;

        if damage >= damage_counts.len() {
            damage_counts.resize(damage + 1, 0);
        }
        damage_counts[damage] += 1;
        if damage > max_damage_seen {
            max_damage_seen = damage;
        }

        total_kills += kills as u64;
        total_damage += damage as u64;

        if UnitProfile::is_destroyed(&wounds) {
            wipes += 1;
        }

        kills_samples.push(kills as f64);
        damage_samples.push(damage as f64);
    }

    let n = num_iterations as f64;
    let expected_models_killed = total_kills as f64 / n;
    let expected_damage_dealt = total_damage as f64 / n;
    let wipe_probability = wipes as f64 / n;

    let variance_kills = kills_samples
        .iter()
        .map(|&k| (k - expected_models_killed).powi(2))
        .sum::<f64>()
        / n;
    let std_dev_kills = variance_kills.sqrt();

    let variance_damage = damage_samples
        .iter()
        .map(|&d| (d - expected_damage_dealt).powi(2))
        .sum::<f64>()
        / n;
    let std_dev_damage = variance_damage.sqrt();

    let kill_distribution: Vec<(u32, f64)> = (0..=total_models)
        .map(|k| {
            let count = if k < kill_counts.len() { kill_counts[k] } else { 0 };
            (k as u32, count as f64 / n)
        })
        .collect();

    let damage_distribution: Vec<(u32, f64)> = (0..=max_damage_seen)
        .map(|d| {
            let count = if d < damage_counts.len() { damage_counts[d] } else { 0 };
            (d as u32, count as f64 / n)
        })
        .collect();

    SimulationReport {
        iterations: num_iterations,
        total_models,
        expected_models_killed,
        expected_damage_dealt,
        wipe_probability,
        std_dev_kills,
        std_dev_damage,
        kill_distribution,
        damage_distribution,
    }
}
