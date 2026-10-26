use crate::domain::unit::UnitProfile;
use crate::domain::weapon::{WeaponLoadoutEntry, WeaponProfile};
use crate::engine::context::CombatContext;
use crate::engine::pipeline::{
    compute_exact_stage_probabilities, resolve_squad_volley, resolve_volley, StageProbabilities,
    VolleyOutcome,
};
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
    #[serde(default)]
    pub safe_bet_damage_80: u32,
    pub wipe_probability: f64,
    #[serde(default)]
    pub bracket_50_probability: f64,
    pub std_dev_kills: f64,
    pub std_dev_damage: f64,
    pub tactical_verdict: TacticalVerdict,
    pub percentiles: PercentilesReport,
    pub keyword_audit: KeywordAudit,
    pub kill_distribution: Vec<(u32, f64)>,
    pub damage_distribution: Vec<(u32, f64)>,
    #[serde(default)]
    pub stage_probabilities: StageProbabilities,
    #[serde(default)]
    pub calculation_method: String,
    #[serde(default)]
    pub unsupported_notices: Vec<String>,
}

fn collect_unsupported_notices(weapons: &[&WeaponProfile]) -> Vec<String> {
    let mut notices = Vec::new();
    for w in weapons {
        for ab in &w.abilities {
            if let Some(msg) = ab.is_informational_or_unsupported_in_math() {
                let entry = format!("{}: {}", w.name, msg);
                if !notices.contains(&entry) {
                    notices.push(entry);
                }
            }
        }
    }
    notices
}

pub fn run_simulation(
    weapon: &WeaponProfile,
    target: &UnitProfile,
    context: &CombatContext,
    iterations: u32,
) -> SimulationReport {
    let stage_probabilities = compute_exact_stage_probabilities(weapon, target, context);
    let unsupported_notices = collect_unsupported_notices(&[weapon]);
    let mut rng = thread_rng();

    run_monte_carlo_core(
        target,
        iterations,
        stage_probabilities,
        unsupported_notices,
        |wounds| resolve_volley(weapon, target, context, wounds, &mut rng),
    )
}

pub fn run_squad_simulation(
    loadout: &[WeaponLoadoutEntry],
    target: &UnitProfile,
    context: &CombatContext,
    iterations: u32,
) -> SimulationReport {
    let mut combined_stage = StageProbabilities::default();
    let mut active_weapons: Vec<&WeaponProfile> = Vec::new();
    let mut total_weight = 0.0;

    for entry in loadout {
        if !entry.enabled || entry.count == 0 {
            continue;
        }
        active_weapons.push(&entry.weapon);
        let st = compute_exact_stage_probabilities(&entry.weapon, target, context);
        let mult = entry.count as f64;
        let w_attacks = st.expected_attacks * mult;
        combined_stage.expected_attacks += w_attacks;
        combined_stage.expected_hits += st.expected_hits * mult;
        combined_stage.expected_wounds += st.expected_wounds * mult;
        combined_stage.expected_unsaved_wounds += st.expected_unsaved_wounds * mult;
        combined_stage.expected_total_unclipped_damage +=
            st.expected_total_unclipped_damage * mult;

        combined_stage.hit_probability += st.hit_probability * w_attacks;
        combined_stage.crit_hit_probability += st.crit_hit_probability * w_attacks;
        combined_stage.wound_probability += st.wound_probability * w_attacks;
        combined_stage.crit_wound_probability += st.crit_wound_probability * w_attacks;
        combined_stage.unsaved_probability_given_normal_wound +=
            st.unsaved_probability_given_normal_wound * w_attacks;
        total_weight += w_attacks;
    }

    if total_weight > 0.0 {
        combined_stage.hit_probability /= total_weight;
        combined_stage.crit_hit_probability /= total_weight;
        combined_stage.wound_probability /= total_weight;
        combined_stage.crit_wound_probability /= total_weight;
        combined_stage.unsaved_probability_given_normal_wound /= total_weight;
    }
    if combined_stage.expected_unsaved_wounds > 0.0 {
        combined_stage.expected_damage_per_unsaved = combined_stage.expected_total_unclipped_damage
            / combined_stage.expected_unsaved_wounds;
    }

    let unsupported_notices = collect_unsupported_notices(&active_weapons);
    let mut rng = thread_rng();

    run_monte_carlo_core(
        target,
        iterations,
        combined_stage,
        unsupported_notices,
        |wounds| resolve_squad_volley(loadout, target, context, wounds, &mut rng),
    )
}

fn run_monte_carlo_core<F>(
    target: &UnitProfile,
    iterations: u32,
    stage_probabilities: StageProbabilities,
    unsupported_notices: Vec<String>,
    mut volley_fn: F,
) -> SimulationReport
where
    F: FnMut(&mut [u32]) -> VolleyOutcome,
{
    let num_iterations = iterations.max(1);
    let total_models = target.total_models();
    let total_wounds: u32 = target.initial_wounds().iter().sum();
    let half_wounds_threshold = (total_wounds as f64 / 2.0).ceil() as usize;

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
    let mut half_brackets = 0u64;

    let mut kills_samples = Vec::with_capacity(num_iterations as usize);
    let mut damage_samples = Vec::with_capacity(num_iterations as usize);

    for _ in 0..num_iterations {
        let mut wounds = target.initial_wounds();
        let outcome = volley_fn(&mut wounds);

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
        if damage >= half_wounds_threshold && half_wounds_threshold > 0 {
            half_brackets += 1;
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
    let bracket_50_probability = half_brackets as f64 / n;

    let lethal_damage = total_lethal_damage as f64 / n;
    let sustained_damage = total_sustained_damage as f64 / n;
    let devastating_damage = total_devastating_damage as f64 / n;
    let standard_damage =
        (expected_damage_dealt - (lethal_damage + sustained_damage + devastating_damage)).max(0.0);

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
            let count = if k < kill_counts.len() {
                kill_counts[k]
            } else {
                0
            };
            (k as u32, count as f64 / n)
        })
        .collect();

    let damage_distribution: Vec<(u32, f64)> = (0..=max_damage_seen)
        .map(|d| {
            let count = if d < damage_counts.len() {
                damage_counts[d]
            } else {
                0
            };
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

    let mut safe_bet_damage_80 = 0u32;
    for candidate in (0..=max_damage_seen as u32).rev() {
        let prob_at_least_d: f64 = damage_distribution
            .iter()
            .filter(|&&(d, _)| d >= candidate)
            .map(|&(_, p)| p)
            .sum();
        if prob_at_least_d >= 0.80 - 1e-6 {
            safe_bet_damage_80 = candidate;
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
        safe_bet_damage_80,
        wipe_probability,
        bracket_50_probability,
        std_dev_kills,
        std_dev_damage,
        tactical_verdict,
        percentiles,
        keyword_audit,
        kill_distribution,
        damage_distribution,
        stage_probabilities,
        calculation_method: format!(
            "Exact Stage Probabilities + Monte Carlo Discrete Wound Allocation (N={})",
            num_iterations
        ),
        unsupported_notices,
    }
}
