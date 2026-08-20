use crate::domain::unit::UnitProfile;
use crate::domain::weapon::WeaponProfile;
use crate::engine::context::CombatContext;
use crate::engine::pipeline::resolve_volley;
use rand::thread_rng;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TacticalVerdict {
    RedIneffective,
    YellowChipContest,
    GreenReliableKill,
}

impl TacticalVerdict {
    pub fn evaluate(
        expected_models_killed: f64,
        total_models: usize,
        expected_damage_dealt: f64,
        total_wounds: u32,
        wipe_probability: f64,
    ) -> Self {
        if wipe_probability >= 0.75 {
            TacticalVerdict::GreenReliableKill
        } else if (expected_models_killed / total_models.max(1) as f64) >= 0.50
            || (expected_damage_dealt / total_wounds.max(1) as f64) >= 0.50
        {
            TacticalVerdict::YellowChipContest
        } else if (expected_models_killed / total_models.max(1) as f64) < 0.25
            && (expected_damage_dealt / total_wounds.max(1) as f64) < 0.25
        {
            TacticalVerdict::RedIneffective
        } else {
            TacticalVerdict::YellowChipContest
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            TacticalVerdict::RedIneffective => "Ineffective Target (Low Impact)",
            TacticalVerdict::YellowChipContest => "Chip / Contest Target (Half Strength)",
            TacticalVerdict::GreenReliableKill => "Reliable Kill (High Priority)",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct PercentilesReport {
    pub p10: u32,
    pub p25: u32,
    pub p50: u32,
    pub p75: u32,
    pub p90: u32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct KeywordAudit {
    pub lethal_damage: f64,
    pub sustained_damage: f64,
    pub devastating_damage: f64,
    pub standard_damage: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SimulationReport {
    pub iterations: u32,
    pub total_models: usize,
    pub total_wounds: u32,
    pub expected_models_killed: f64,
    pub expected_damage_dealt: f64,
    pub raw_damage_generated: f64,
    pub spillover_damage_lost: f64,
    pub safe_bet_kills_80: u32,
    pub wipe_probability: f64,
    pub std_dev_kills: f64,
    pub std_dev_damage: f64,
    pub tactical_verdict: TacticalVerdict,
    pub percentiles: PercentilesReport,
    pub keyword_audit: KeywordAudit,
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
    let total_wounds: u32 = target.initial_wounds().iter().sum();

    let mut kill_counts = vec![0u32; total_models + 1];
    let mut max_damage_seen = 0usize;
    let mut damage_counts: Vec<u32> = Vec::new();

    let mut total_kills = 0u64;
    let mut total_damage = 0u64;
    let mut total_raw_damage = 0u64;
    let mut total_lethal_damage = 0u64;
    let mut total_sustained_damage = 0u64;
    let mut total_devastating_damage = 0u64;
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
        total_raw_damage += outcome.raw_damage_generated as u64;
        total_lethal_damage += outcome.lethal_damage as u64;
        total_sustained_damage += outcome.sustained_damage as u64;
        total_devastating_damage += outcome.devastating_damage as u64;

        if UnitProfile::is_destroyed(&wounds) {
            wipes += 1;
        }

        kills_samples.push(kills as u32);
        damage_samples.push(damage as f64);
    }

    let n = num_iterations as f64;
    let expected_models_killed = total_kills as f64 / n;
    let expected_damage_dealt = total_damage as f64 / n;
    let raw_damage_generated = total_raw_damage as f64 / n;
    let spillover_damage_lost = (raw_damage_generated - expected_damage_dealt).max(0.0);
    let wipe_probability = wipes as f64 / n;

    let lethal_damage = total_lethal_damage as f64 / n;
    let sustained_damage = total_sustained_damage as f64 / n;
    let devastating_damage = total_devastating_damage as f64 / n;
    let standard_damage = (expected_damage_dealt - (lethal_damage + sustained_damage + devastating_damage)).max(0.0);

    let keyword_audit = KeywordAudit {
        lethal_damage,
        sustained_damage,
        devastating_damage,
        standard_damage,
    };

    let variance_kills = kills_samples
        .iter()
        .map(|&k| (k as f64 - expected_models_killed).powi(2))
        .sum::<f64>()
        / n;
    let std_dev_kills = variance_kills.sqrt();

    let variance_damage = damage_samples
        .iter()
        .map(|&d| (d - expected_damage_dealt).powi(2))
        .sum::<f64>()
        / n;
    let std_dev_damage = variance_damage.sqrt();

    kills_samples.sort_unstable();
    let percentile = |p: f64| -> u32 {
        let idx = (((kills_samples.len() - 1) as f64) * (p / 100.0)).round() as usize;
        kills_samples[idx.min(kills_samples.len() - 1)]
    };

    let percentiles = PercentilesReport {
        p10: percentile(10.0),
        p25: percentile(25.0),
        p50: percentile(50.0),
        p75: percentile(75.0),
        p90: percentile(90.0),
    };

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

    let mut safe_bet_kills_80 = 0u32;
    for candidate in (0..=total_models as u32).rev() {
        let prob_at_least_k: f64 = kill_distribution
            .iter()
            .filter(|&&(k, _)| k >= candidate)
            .map(|&(_, p)| p)
            .sum();
        if prob_at_least_k >= 0.80 - 1e-6 {
            safe_bet_kills_80 = candidate;
            break;
        }
    }

    let tactical_verdict = TacticalVerdict::evaluate(
        expected_models_killed,
        total_models,
        expected_damage_dealt,
        total_wounds,
        wipe_probability,
    );

    SimulationReport {
        iterations: num_iterations,
        total_models,
        total_wounds,
        expected_models_killed,
        expected_damage_dealt,
        raw_damage_generated,
        spillover_damage_lost,
        safe_bet_kills_80,
        wipe_probability,
        std_dev_kills,
        std_dev_damage,
        tactical_verdict,
        percentiles,
        keyword_audit,
        kill_distribution,
        damage_distribution,
    }
}
