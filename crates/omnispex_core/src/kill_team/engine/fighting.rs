use crate::common::{PercentilesReport, TacticalVerdict};
use crate::kill_team::domain::catalogue::{KtWeaponProfile, OperativeDatacard};
use crate::kill_team::engine::shooting::roll_kt_attack_pool;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct KtFightContext {
    #[serde(default)]
    pub attacker_injured: bool,
    #[serde(default)]
    pub defender_injured: bool,
    /// Friendly operatives supporting the attacker in combat (+1 Hit per support in KT24).
    #[serde(default, alias = "attacker_support_friends")]
    pub attacker_combat_support: u32,
    /// Friendly operatives supporting the defender in combat (+1 Hit per support in KT24).
    #[serde(default, alias = "defender_support_friends")]
    pub defender_combat_support: u32,
    #[serde(default)]
    pub attacker_remaining_wounds: Option<u32>,
    #[serde(default)]
    pub defender_remaining_wounds: Option<u32>,
    #[serde(default)]
    pub grant_attacker_balanced: bool,
    #[serde(default)]
    pub grant_attacker_ceaseless: bool,
    #[serde(default)]
    pub grant_attacker_relentless: bool,
    #[serde(default)]
    pub grant_defender_balanced: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct KtFightReport {
    pub calculation_method: String,
    pub iterations: u32,
    pub expected_damage_dealt: f64,
    pub expected_damage_taken: f64,
    pub attacker_kill_probability: f64,
    pub attacker_survival_probability: f64,
    pub clean_kill_probability: f64,
    pub tactical_verdict: TacticalVerdict,
    pub percentiles_damage_dealt: PercentilesReport,
    pub damage_dealt_distribution: Vec<(u32, f64)>,
    pub damage_taken_distribution: Vec<(u32, f64)>,
    pub rule_notices: Vec<String>,
}

#[derive(Debug, Clone, Copy)]
struct DuelConfig {
    a_norm_dmg: u32,
    a_crit_dmg: u32,
    a_brutal: bool,
    a_shock: bool,
    d_norm_dmg: u32,
    d_crit_dmg: u32,
    d_brutal: bool,
    d_shock: bool,
    a_initial_w: u32,
    d_initial_w: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct DuelState {
    a_c: u32,
    a_n: u32,
    a_w: u32,
    a_shock_used: bool,
    d_c: u32,
    d_n: u32,
    d_w: u32,
    d_shock_used: bool,
    attacker_turn: bool,
}

/// Solves the alternating KT24 Strike/Parry melee duel via game-theoretic minimax.
/// Returns `(final_attacker_wounds, final_defender_wounds)`.
pub fn resolve_optimal_kt_melee_duel(
    a_crits: u32,
    a_normals: u32,
    a_wounds: u32,
    a_norm_dmg: u32,
    a_crit_dmg: u32,
    a_brutal: bool,
    a_shock: bool,
    d_crits: u32,
    d_normals: u32,
    d_wounds: u32,
    d_norm_dmg: u32,
    d_crit_dmg: u32,
    d_brutal: bool,
    d_shock: bool,
) -> (u32, u32) {
    let cfg = DuelConfig {
        a_norm_dmg,
        a_crit_dmg,
        a_brutal,
        a_shock,
        d_norm_dmg,
        d_crit_dmg,
        d_brutal,
        d_shock,
        a_initial_w: a_wounds,
        d_initial_w: d_wounds,
    };
    let initial = DuelState {
        a_c: a_crits,
        a_n: a_normals,
        a_w: a_wounds,
        a_shock_used: false,
        d_c: d_crits,
        d_n: d_normals,
        d_w: d_wounds,
        d_shock_used: false,
        attacker_turn: true,
    };
    minimax_duel(initial, &cfg)
}

fn attacker_score(final_a_w: u32, final_d_w: u32, cfg: &DuelConfig) -> (bool, bool, i32, u32) {
    let d_killed = final_d_w == 0;
    let a_survived = final_a_w > 0;
    let dmg_dealt = cfg.d_initial_w.saturating_sub(final_d_w);
    let dmg_taken = cfg.a_initial_w.saturating_sub(final_a_w);
    (
        d_killed,
        a_survived,
        dmg_dealt as i32 - dmg_taken as i32,
        dmg_dealt,
    )
}

fn defender_score(final_a_w: u32, final_d_w: u32, cfg: &DuelConfig) -> (bool, bool, i32, u32) {
    let a_killed = final_a_w == 0;
    let d_survived = final_d_w > 0;
    let dmg_dealt = cfg.a_initial_w.saturating_sub(final_a_w);
    let dmg_taken = cfg.d_initial_w.saturating_sub(final_d_w);
    (
        a_killed,
        d_survived,
        dmg_dealt as i32 - dmg_taken as i32,
        dmg_dealt,
    )
}

fn minimax_duel(st: DuelState, cfg: &DuelConfig) -> (u32, u32) {
    if st.a_w == 0 || st.d_w == 0 || (st.a_c == 0 && st.a_n == 0 && st.d_c == 0 && st.d_n == 0)
    {
        return (st.a_w, st.d_w);
    }

    if st.attacker_turn {
        if st.a_c == 0 && st.a_n == 0 {
            let mut next = st;
            next.attacker_turn = false;
            return minimax_duel(next, cfg);
        }

        // Fast lethal check: if attacker can kill defender right now, do it immediately
        if st.a_n > 0 && cfg.a_norm_dmg >= st.d_w {
            return (st.a_w, 0);
        }
        if st.a_c > 0 && cfg.a_crit_dmg >= st.d_w {
            return (st.a_w, 0);
        }

        let mut best_outcome: Option<(u32, u32)> = None;
        let mut update_best = |cand: (u32, u32)| {
            if let Some(curr) = best_outcome {
                if attacker_score(cand.0, cand.1, cfg) > attacker_score(curr.0, curr.1, cfg) {
                    best_outcome = Some(cand);
                }
            } else {
                best_outcome = Some(cand);
            }
        };

        // Option 1: Strike with Crit
        if st.a_c > 0 {
            let mut next = st;
            next.a_c -= 1;
            next.d_w = next.d_w.saturating_sub(cfg.a_crit_dmg);
            if cfg.a_shock && !next.a_shock_used {
                next.a_shock_used = true;
                if next.d_n > 0 {
                    next.d_n -= 1;
                } else if next.d_c > 0 {
                    next.d_c -= 1;
                }
            }
            next.attacker_turn = false;
            update_best(minimax_duel(next, cfg));
        }

        // Option 2: Strike with Normal
        if st.a_n > 0 {
            let mut next = st;
            next.a_n -= 1;
            next.d_w = next.d_w.saturating_sub(cfg.a_norm_dmg);
            next.attacker_turn = false;
            update_best(minimax_duel(next, cfg));
        }

        // Option 3: Parry with Crit (discard opponent Crit first, or Normal if no Crit)
        if st.a_c > 0 && (st.d_c > 0 || st.d_n > 0) {
            let mut next = st;
            next.a_c -= 1;
            if next.d_c > 0 {
                next.d_c -= 1;
            } else {
                next.d_n -= 1;
            }
            next.attacker_turn = false;
            update_best(minimax_duel(next, cfg));
        }

        // Option 4: Parry with Normal (only if defender does NOT have Brutal and has a Normal)
        if st.a_n > 0 && st.d_n > 0 && !cfg.d_brutal {
            let mut next = st;
            next.a_n -= 1;
            next.d_n -= 1;
            next.attacker_turn = false;
            update_best(minimax_duel(next, cfg));
        }

        best_outcome.unwrap_or((st.a_w, st.d_w))
    } else {
        if st.d_c == 0 && st.d_n == 0 {
            let mut next = st;
            next.attacker_turn = true;
            return minimax_duel(next, cfg);
        }

        // Fast lethal check: if defender can kill attacker right now, do it immediately
        if st.d_n > 0 && cfg.d_norm_dmg >= st.a_w {
            return (0, st.d_w);
        }
        if st.d_c > 0 && cfg.d_crit_dmg >= st.a_w {
            return (0, st.d_w);
        }

        let mut best_outcome: Option<(u32, u32)> = None;
        let mut update_best = |cand: (u32, u32)| {
            if let Some(curr) = best_outcome {
                if defender_score(cand.0, cand.1, cfg) > defender_score(curr.0, curr.1, cfg) {
                    best_outcome = Some(cand);
                }
            } else {
                best_outcome = Some(cand);
            }
        };

        // Option 1: Strike with Crit
        if st.d_c > 0 {
            let mut next = st;
            next.d_c -= 1;
            next.a_w = next.a_w.saturating_sub(cfg.d_crit_dmg);
            if cfg.d_shock && !next.d_shock_used {
                next.d_shock_used = true;
                if next.a_n > 0 {
                    next.a_n -= 1;
                } else if next.a_c > 0 {
                    next.a_c -= 1;
                }
            }
            next.attacker_turn = true;
            update_best(minimax_duel(next, cfg));
        }

        // Option 2: Strike with Normal
        if st.d_n > 0 {
            let mut next = st;
            next.d_n -= 1;
            next.a_w = next.a_w.saturating_sub(cfg.d_norm_dmg);
            next.attacker_turn = true;
            update_best(minimax_duel(next, cfg));
        }

        // Option 3: Parry with Crit
        if st.d_c > 0 && (st.a_c > 0 || st.a_n > 0) {
            let mut next = st;
            next.d_c -= 1;
            if next.a_c > 0 {
                next.a_c -= 1;
            } else {
                next.a_n -= 1;
            }
            next.attacker_turn = true;
            update_best(minimax_duel(next, cfg));
        }

        // Option 4: Parry with Normal (only if attacker does NOT have Brutal)
        if st.d_n > 0 && st.a_n > 0 && !cfg.a_brutal {
            let mut next = st;
            next.d_n -= 1;
            next.a_n -= 1;
            next.attacker_turn = true;
            update_best(minimax_duel(next, cfg));
        }

        best_outcome.unwrap_or((st.a_w, st.d_w))
    }
}

pub fn run_kt_fight_simulation(
    attacker: &OperativeDatacard,
    attacker_weapon: &KtWeaponProfile,
    defender: &OperativeDatacard,
    defender_weapon: &KtWeaponProfile,
    context: &KtFightContext,
    iterations: u32,
) -> KtFightReport {
    let n_iters = iterations.clamp(100, 50_000);
    let mut rng = rand::thread_rng();

    let a_hit_mod = (context.attacker_combat_support as i32)
        - (if context.attacker_injured { 1 } else { 0 });
    let a_effective_hit = (attacker_weapon.hit as i32 - a_hit_mod).clamp(2, 6) as u32;
    let a_lethal = attacker_weapon.lethal_threshold().clamp(2, 6);

    let d_hit_mod = (context.defender_combat_support as i32)
        - (if context.defender_injured { 1 } else { 0 });
    let d_effective_hit = (defender_weapon.hit as i32 - d_hit_mod).clamp(2, 6) as u32;
    let d_lethal = defender_weapon.lethal_threshold().clamp(2, 6);

    let a_start_w = context
        .attacker_remaining_wounds
        .filter(|&w| w > 0)
        .unwrap_or_else(|| attacker.wounds.max(1));
    let d_start_w = context
        .defender_remaining_wounds
        .filter(|&w| w > 0)
        .unwrap_or_else(|| defender.wounds.max(1));

    let a_crit_dmg = attacker_weapon.critical_damage + attacker_weapon.devastating_value();
    let d_crit_dmg = defender_weapon.critical_damage + defender_weapon.devastating_value();

    let mut total_dmg_dealt = 0u64;
    let mut total_dmg_taken = 0u64;
    let mut kills = 0u32;
    let mut survivals = 0u32;
    let mut clean_kills = 0u32;

    let mut dealt_samples = Vec::with_capacity(n_iters as usize);
    let mut taken_samples = Vec::with_capacity(n_iters as usize);

    for _ in 0..n_iters {
        let (a_c, a_n) = roll_kt_attack_pool(
            attacker_weapon,
            a_effective_hit,
            a_lethal,
            attacker_weapon.accurate_value(),
            attacker_weapon.has_relentless() || context.grant_attacker_relentless,
            attacker_weapon.has_ceaseless() || context.grant_attacker_ceaseless,
            attacker_weapon.has_balanced() || context.grant_attacker_balanced,
            attacker_weapon.has_severe(),
            attacker_weapon.has_punishing(),
            attacker_weapon.has_rending(),
            false,
            &mut rng,
        );

        let (d_c, d_n) = roll_kt_attack_pool(
            defender_weapon,
            d_effective_hit,
            d_lethal,
            defender_weapon.accurate_value(),
            defender_weapon.has_relentless(),
            defender_weapon.has_ceaseless(),
            defender_weapon.has_balanced() || context.grant_defender_balanced,
            defender_weapon.has_severe(),
            defender_weapon.has_punishing(),
            defender_weapon.has_rending(),
            false,
            &mut rng,
        );

        let (final_a_w, final_d_w) = resolve_optimal_kt_melee_duel(
            a_c,
            a_n,
            a_start_w,
            attacker_weapon.normal_damage,
            a_crit_dmg,
            attacker_weapon.has_brutal(),
            attacker_weapon.has_shock(),
            d_c,
            d_n,
            d_start_w,
            defender_weapon.normal_damage,
            d_crit_dmg,
            defender_weapon.has_brutal(),
            defender_weapon.has_shock(),
        );

        let dealt = d_start_w.saturating_sub(final_d_w);
        let taken = a_start_w.saturating_sub(final_a_w);

        total_dmg_dealt += dealt as u64;
        total_dmg_taken += taken as u64;
        if final_d_w == 0 {
            kills += 1;
            if taken == 0 {
                clean_kills += 1;
            }
        }
        if final_a_w > 0 {
            survivals += 1;
        }

        dealt_samples.push(dealt);
        taken_samples.push(taken);
    }

    dealt_samples.sort_unstable();
    taken_samples.sort_unstable();
    let n = n_iters as f64;
    let expected_damage_dealt = total_dmg_dealt as f64 / n;
    let expected_damage_taken = total_dmg_taken as f64 / n;
    let attacker_kill_probability = kills as f64 / n;
    let attacker_survival_probability = survivals as f64 / n;
    let clean_kill_probability = clean_kills as f64 / n;

    let idx_at = |pct: f64| -> usize {
        ((pct * (n_iters as usize - 1) as f64).round() as usize).min(n_iters as usize - 1)
    };
    let percentiles_damage_dealt = PercentilesReport {
        p10: dealt_samples[idx_at(0.10)],
        p25: dealt_samples[idx_at(0.25)],
        p50: dealt_samples[idx_at(0.50)],
        p75: dealt_samples[idx_at(0.75)],
        p90: dealt_samples[idx_at(0.90)],
    };

    let build_dist = |samples: &[u32]| -> Vec<(u32, f64)> {
        let max_v = samples.last().copied().unwrap_or(0);
        let mut counts = vec![0u32; (max_v + 1) as usize];
        for &v in samples {
            counts[v as usize] += 1;
        }
        counts
            .into_iter()
            .enumerate()
            .filter(|&(_, c)| c > 0)
            .map(|(v, c)| (v as u32, c as f64 / n))
            .collect()
    };

    let mut rule_notices = Vec::new();
    if attacker_weapon.has_brutal() {
        rule_notices.push(
            "Attacker Brutal: Defender can only parry with Critical successes.".to_string(),
        );
    }
    if attacker_weapon.has_shock() {
        rule_notices.push(
            "Attacker Shock: First Critical Strike also discards 1 unresolved Defender success."
                .to_string(),
        );
    }
    if attacker_weapon.has_stun() {
        rule_notices.push(
            "Attacker Stun: Critical Strike subtracts 1 from Defender's APL.".to_string(),
        );
    }
    if defender_weapon.has_brutal() {
        rule_notices.push(
            "Defender Brutal: Attacker can only parry with Critical successes.".to_string(),
        );
    }
    if defender_weapon.has_shock() {
        rule_notices.push(
            "Defender Shock: First Critical Strike also discards 1 unresolved Attacker success."
                .to_string(),
        );
    }

    let tactical_verdict = TacticalVerdict::from_probabilities(
        attacker_kill_probability,
        attacker_survival_probability,
        expected_damage_dealt,
    );

    KtFightReport {
        calculation_method: format!(
            "KT24 Fight Engine ({} iterations, Minimax Strike/Parry Solver)",
            n_iters
        ),
        iterations: n_iters,
        expected_damage_dealt,
        expected_damage_taken,
        attacker_kill_probability,
        attacker_survival_probability,
        clean_kill_probability,
        tactical_verdict,
        percentiles_damage_dealt,
        damage_dealt_distribution: build_dist(&dealt_samples),
        damage_taken_distribution: build_dist(&taken_samples),
        rule_notices,
    }
}
