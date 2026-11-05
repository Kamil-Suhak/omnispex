use crate::common::{PercentilesReport, TacticalVerdict};
use crate::kill_team::domain::catalogue::{KtWeaponProfile, KtWeaponRule, OperativeDatacard};
use rand::Rng;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct KtShootingContext {
    #[serde(default)]
    pub target_in_cover: bool,
    #[serde(default)]
    pub improved_cover_save: bool,
    #[serde(default)]
    pub target_obscured: bool,
    #[serde(default)]
    pub attacker_injured: bool,
    #[serde(default)]
    pub hit_modifier: i32,
    #[serde(default)]
    pub bonus_accurate: u32,
    #[serde(default)]
    pub grant_balanced: bool,
    #[serde(default)]
    pub grant_ceaseless: bool,
    #[serde(default)]
    pub grant_relentless: bool,
    #[serde(default)]
    pub grant_rending: bool,
    #[serde(default)]
    pub grant_severe: bool,
    #[serde(default)]
    pub grant_punishing: bool,
    #[serde(default)]
    pub grant_saturate: bool,
    #[serde(default)]
    pub extra_piercing: u32,
    #[serde(default)]
    pub defender_balanced: bool,
    #[serde(default)]
    pub defender_reroll_ones: bool,
    #[serde(default)]
    pub defender_minus_one_damage: bool,
    /// Optional remaining wounds on the target operative (defaults to target.wounds if None or 0).
    #[serde(default)]
    pub target_remaining_wounds: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct KtShootingStageProbabilities {
    pub total_attack_dice: u32,
    pub auto_retained_normals: u32,
    pub effective_hit_threshold: u32,
    pub effective_lethal_threshold: u32,
    pub expected_normal_hits: f64,
    pub expected_critical_hits: f64,
    pub expected_defense_dice: f64,
    pub expected_normal_saves: f64,
    pub expected_critical_saves: f64,
    pub expected_devastating_damage: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct KtShootingReport {
    pub calculation_method: String,
    pub iterations: u32,
    pub expected_damage_dealt: f64,
    pub std_dev_damage: f64,
    pub safe_bet_damage_80: u32,
    pub kill_probability: f64,
    pub injury_probability: f64,
    pub tactical_verdict: TacticalVerdict,
    pub percentiles: PercentilesReport,
    pub stage_probabilities: KtShootingStageProbabilities,
    /// (damage_value, probability)
    pub damage_distribution: Vec<(u32, f64)>,
    pub rule_notices: Vec<String>,
}

/// Computes the optimal KT24 defense dice allocation to minimize damage taken
/// (and prioritize surviving with >= 1 wound remaining).
/// Rules:
/// - 1 Critical Save blocks 1 Critical Attack OR 1 Normal Attack
/// - 2 Normal Saves block 1 Critical Attack
/// - 1 Normal Save blocks 1 Normal Attack
pub fn resolve_optimal_kt_defense(
    atk_crits: u32,
    atk_normals: u32,
    def_crits: u32,
    def_normals: u32,
    crit_dmg: u32,
    normal_dmg: u32,
    devastating_dmg: u32,
    target_remaining_wounds: u32,
) -> (u32, u32, u32) {
    let mut best_total_dmg = u32::MAX;
    let mut best_survives = false;
    let mut best_unblocked_crits = atk_crits;
    let mut best_unblocked_normals = atk_normals;

    let max_c_on_crit = def_crits.min(atk_crits);
    for c_on_crit in 0..=max_c_on_crit {
        let rem_def_c = def_crits - c_on_crit;
        let rem_atk_c = atk_crits - c_on_crit;

        let max_pairs_on_crit = (def_normals / 2).min(rem_atk_c);
        for pairs_on_crit in 0..=max_pairs_on_crit {
            let unblocked_c = rem_atk_c - pairs_on_crit;
            let rem_def_n = def_normals - (pairs_on_crit * 2);

            let blocked_n = (rem_def_c + rem_def_n).min(atk_normals);
            let unblocked_n = atk_normals - blocked_n;

            let total_dmg =
                devastating_dmg + unblocked_c * crit_dmg + unblocked_n * normal_dmg;
            let survives = total_dmg < target_remaining_wounds;

            let is_better = if survives != best_survives {
                survives
            } else {
                total_dmg < best_total_dmg
            };

            if is_better {
                best_survives = survives;
                best_total_dmg = total_dmg;
                best_unblocked_crits = unblocked_c;
                best_unblocked_normals = unblocked_n;
            }
        }
    }

    (
        best_total_dmg,
        best_unblocked_crits,
        best_unblocked_normals,
    )
}

pub(crate) fn roll_kt_attack_pool(
    weapon: &KtWeaponProfile,
    effective_hit: u32,
    lethal_on: u32,
    accurate_count: u32,
    has_relentless: bool,
    has_ceaseless: bool,
    has_balanced: bool,
    has_severe: bool,
    has_punishing: bool,
    has_rending: bool,
    target_obscured: bool,
    rng: &mut impl Rng,
) -> (u32, u32) {
    let total_atk = weapon.attacks;
    let auto_normals = accurate_count.min(2).min(total_atk);
    let dice_to_roll = total_atk - auto_normals;

    let mut rolls: Vec<u32> = (0..dice_to_roll).map(|_| rng.gen_range(1..=6)).collect();
    let mut rerolled: Vec<bool> = vec![false; dice_to_roll as usize];

    if has_relentless {
        for (i, r) in rolls.iter_mut().enumerate() {
            if *r < effective_hit {
                *r = rng.gen_range(1..=6);
                rerolled[i] = true;
            }
        }
    } else if has_ceaseless {
        // Pick the failed die value (< effective_hit) that occurs most frequently
        let mut counts = [0u32; 7];
        for &r in &rolls {
            if r < effective_hit {
                counts[r as usize] += 1;
            }
        }
        let mut best_face = 0usize;
        let mut best_count = 0u32;
        for face in 1..(effective_hit as usize).min(6) {
            if counts[face] > best_count {
                best_count = counts[face];
                best_face = face;
            }
        }
        if best_face > 0 {
            for (i, r) in rolls.iter_mut().enumerate() {
                if *r == best_face as u32 && !rerolled[i] {
                    *r = rng.gen_range(1..=6);
                    rerolled[i] = true;
                }
            }
        }
    }

    if has_balanced {
        if let Some((idx, _)) = rolls
            .iter()
            .enumerate()
            .find(|&(i, &r)| !rerolled[i] && r < effective_hit)
        {
            rolls[idx] = rng.gen_range(1..=6);
        }
    }

    let mut crits = 0u32;
    let mut normals = auto_normals;
    let mut fails = 0u32;

    for r in rolls {
        if r == 1 {
            fails += 1;
        } else if r >= lethal_on {
            crits += 1;
        } else if r >= effective_hit {
            normals += 1;
        } else {
            fails += 1;
        }
    }

    if target_obscured {
        // KT24 Obscured:
        // 1. All critical successes are retained as normal successes instead.
        // 2. Attacker must discard 1 success.
        let total_successes = (crits + normals).saturating_sub(1);
        return (0, total_successes);
    }

    if crits == 0 && normals > 0 && has_severe {
        normals -= 1;
        crits += 1;
    }

    if crits > 0 && fails > 0 && has_punishing {
        fails -= 1;
        normals += 1;
    }
    let _ = fails;

    if crits > 0 && normals > 0 && has_rending {
        normals -= 1;
        crits += 1;
    }

    (crits, normals)
}

pub fn run_kt_shooting_simulation(
    weapon: &KtWeaponProfile,
    target: &OperativeDatacard,
    context: &KtShootingContext,
    iterations: u32,
) -> KtShootingReport {
    let n_iters = iterations.clamp(100, 100_000);
    let mut rng = rand::thread_rng();

    let mut raw_hit_mod = context.hit_modifier;
    if context.attacker_injured {
        raw_hit_mod -= 1;
    }
    let effective_hit = (weapon.hit as i32 - raw_hit_mod).clamp(2, 6) as u32;
    let lethal_on = weapon.lethal_threshold().clamp(2, 6);
    let accurate_count = (weapon.accurate_value() + context.bonus_accurate).min(2);

    let has_relentless = weapon.has_relentless() || context.grant_relentless;
    let has_ceaseless = weapon.has_ceaseless() || context.grant_ceaseless;
    let has_balanced = weapon.has_balanced() || context.grant_balanced;
    let has_severe = weapon.has_severe() || context.grant_severe;
    let has_punishing = weapon.has_punishing() || context.grant_punishing;
    let has_rending = weapon.has_rending() || context.grant_rending;
    let has_saturate = weapon.has_saturate() || context.grant_saturate;

    let base_piercing = weapon.piercing_value().max(context.extra_piercing);
    let crit_piercing = weapon.piercing_crits_value().max(base_piercing);
    let devastating_val = weapon.devastating_value();

    let normal_dmg = if context.defender_minus_one_damage && weapon.normal_damage > 1 {
        weapon.normal_damage - 1
    } else {
        weapon.normal_damage
    };
    let crit_dmg = if context.defender_minus_one_damage && weapon.critical_damage > 1 {
        weapon.critical_damage - 1
    } else {
        weapon.critical_damage
    };

    let target_max_wounds = target.wounds.max(1);
    let target_rem_wounds = context
        .target_remaining_wounds
        .filter(|&w| w > 0)
        .unwrap_or(target_max_wounds);
    let injury_threshold = target_max_wounds / 2;

    let mut total_dmg_sum = 0u64;
    let mut total_dmg_sq_sum = 0u64;
    let mut kills_count = 0u32;
    let mut injured_count = 0u32;

    let mut sum_norm_hits = 0u64;
    let mut sum_crit_hits = 0u64;
    let mut sum_def_dice = 0u64;
    let mut sum_norm_saves = 0u64;
    let mut sum_crit_saves = 0u64;
    let mut sum_dev_dmg = 0u64;

    let mut samples: Vec<u32> = Vec::with_capacity(n_iters as usize);

    for _ in 0..n_iters {
        let (atk_crits, atk_normals) = roll_kt_attack_pool(
            weapon,
            effective_hit,
            lethal_on,
            accurate_count,
            has_relentless,
            has_ceaseless,
            has_balanced,
            has_severe,
            has_punishing,
            has_rending,
            context.target_obscured,
            &mut rng,
        );

        sum_crit_hits += atk_crits as u64;
        sum_norm_hits += atk_normals as u64;

        let dev_dmg = if context.target_obscured {
            0
        } else {
            atk_crits * devastating_val
        };
        sum_dev_dmg += dev_dmg as u64;

        let piercing = if atk_crits > 0 {
            crit_piercing
        } else {
            base_piercing
        };
        let def_dice = 3_u32.saturating_sub(piercing);
        sum_def_dice += def_dice as u64;

        let auto_cover_saves = if context.target_in_cover && !has_saturate {
            let max_cover = if context.improved_cover_save { 2 } else { 1 };
            max_cover.min(def_dice)
        } else {
            0
        };

        let def_to_roll = def_dice - auto_cover_saves;
        let mut def_rolls: Vec<u32> = (0..def_to_roll).map(|_| rng.gen_range(1..=6)).collect();

        if context.defender_reroll_ones {
            for r in &mut def_rolls {
                if *r == 1 {
                    *r = rng.gen_range(1..=6);
                }
            }
        } else if context.defender_balanced {
            if let Some(r) = def_rolls.iter_mut().find(|&&mut v| v < target.save) {
                *r = rng.gen_range(1..=6);
            }
        }

        let mut def_crits = 0u32;
        let mut def_normals = auto_cover_saves;
        let save_target = target.save.clamp(2, 6);

        for r in def_rolls {
            if r == 6 {
                def_crits += 1;
            } else if r != 1 && r >= save_target {
                def_normals += 1;
            }
        }

        sum_crit_saves += def_crits as u64;
        sum_norm_saves += def_normals as u64;

        let (dmg_dealt, _, _) = resolve_optimal_kt_defense(
            atk_crits,
            atk_normals,
            def_crits,
            def_normals,
            crit_dmg,
            normal_dmg,
            dev_dmg,
            target_rem_wounds,
        );

        samples.push(dmg_dealt);
        total_dmg_sum += dmg_dealt as u64;
        total_dmg_sq_sum += (dmg_dealt as u64) * (dmg_dealt as u64);

        if dmg_dealt >= target_rem_wounds {
            kills_count += 1;
            injured_count += 1;
        } else if target_rem_wounds - dmg_dealt < injury_threshold {
            injured_count += 1;
        }
    }

    samples.sort_unstable();
    let n = n_iters as f64;
    let expected_damage_dealt = total_dmg_sum as f64 / n;
    let variance = ((total_dmg_sq_sum as f64 / n) - (expected_damage_dealt * expected_damage_dealt))
        .max(0.0);
    let std_dev_damage = variance.sqrt();

    let kill_probability = kills_count as f64 / n;
    let injury_probability = injured_count as f64 / n;

    let idx_at = |pct: f64| -> usize {
        ((pct * (n_iters as usize - 1) as f64).round() as usize).min(n_iters as usize - 1)
    };
    let safe_bet_damage_80 = samples[idx_at(0.20)];
    let percentiles = PercentilesReport {
        p10: samples[idx_at(0.10)],
        p25: samples[idx_at(0.25)],
        p50: samples[idx_at(0.50)],
        p75: samples[idx_at(0.75)],
        p90: samples[idx_at(0.90)],
    };

    let max_dmg = samples.last().copied().unwrap_or(0);
    let mut dist_counts = vec![0u32; (max_dmg + 1) as usize];
    for &d in &samples {
        dist_counts[d as usize] += 1;
    }
    let damage_distribution: Vec<(u32, f64)> = dist_counts
        .into_iter()
        .enumerate()
        .filter(|&(_, c)| c > 0)
        .map(|(dmg, c)| (dmg as u32, c as f64 / n))
        .collect();

    let mut rule_notices = Vec::new();
    if weapon.has_hot() {
        // KT24 Hot rule: roll 1D6 after shooting; if < Hit stat, suffer result * 2 damage.
        let mut hot_expected = 0.0;
        for r in 1..weapon.hit.min(6) {
            hot_expected += (r * 2) as f64 / 6.0;
        }
        rule_notices.push(format!(
            "Hot: Roll 1D6 after shooting; on <{}+, bearer suffers 2x roll damage (Expected self-damage: {:.2}W).",
            weapon.hit, hot_expected
        ));
    }
    if weapon.has_stun() {
        rule_notices.push(
            "Stun: If any critical success is retained, subtract 1 from target's APL.".to_string(),
        );
    }
    for r in &weapon.rules {
        match r {
            KtWeaponRule::Blast(rad) => rule_notices.push(format!(
                "Blast {}\": Make shooting attacks against primary target and every operative visible to and within {}\" of it.",
                rad, rad
            )),
            KtWeaponRule::Torrent(rad) => rule_notices.push(format!(
                "Torrent {}\": Make shooting attacks against valid targets within {}\" of each other.",
                rad, rad
            )),
            KtWeaponRule::Silent => rule_notices.push(
                "Silent: Can perform Shoot action while having a Conceal order.".to_string(),
            ),
            _ => {}
        }
    }

    let tactical_verdict = TacticalVerdict::from_probabilities(
        kill_probability,
        injury_probability,
        expected_damage_dealt,
    );

    KtShootingReport {
        calculation_method: format!(
            "KT24 Shooting Engine ({} iterations, Optimal Defense Solver)",
            n_iters
        ),
        iterations: n_iters,
        expected_damage_dealt,
        std_dev_damage,
        safe_bet_damage_80,
        kill_probability,
        injury_probability,
        tactical_verdict,
        percentiles,
        stage_probabilities: KtShootingStageProbabilities {
            total_attack_dice: weapon.attacks,
            auto_retained_normals: accurate_count.min(weapon.attacks),
            effective_hit_threshold: effective_hit,
            effective_lethal_threshold: lethal_on,
            expected_normal_hits: sum_norm_hits as f64 / n,
            expected_critical_hits: sum_crit_hits as f64 / n,
            expected_defense_dice: sum_def_dice as f64 / n,
            expected_normal_saves: sum_norm_saves as f64 / n,
            expected_critical_saves: sum_crit_saves as f64 / n,
            expected_devastating_damage: sum_dev_dmg as f64 / n,
        },
        damage_distribution,
        rule_notices,
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct KtWeaponComparisonEntry {
    pub weapon: KtWeaponProfile,
    pub report: KtShootingReport,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct KtWeaponComparisonReport {
    pub target: OperativeDatacard,
    pub context: KtShootingContext,
    pub entries: Vec<KtWeaponComparisonEntry>,
    pub recommended_index: usize,
    pub summary_verdict: String,
}

pub fn compare_kt_weapons(
    weapons: &[KtWeaponProfile],
    target: &OperativeDatacard,
    context: &KtShootingContext,
    iterations: u32,
) -> Result<KtWeaponComparisonReport, &'static str> {
    if weapons.is_empty() {
        return Err("No Kill Team weapons provided for comparison");
    }
    let mut entries = Vec::with_capacity(weapons.len());
    let mut best_idx = 0usize;
    let mut best_score = -1.0f64;

    for (i, w) in weapons.iter().enumerate() {
        let report = run_kt_shooting_simulation(w, target, context, iterations);
        let score = report.kill_probability * 100.0 + report.expected_damage_dealt;
        if score > best_score {
            best_score = score;
            best_idx = i;
        }
        entries.push(KtWeaponComparisonEntry {
            weapon: w.clone(),
            report,
        });
    }

    let best = &entries[best_idx];
    let summary_verdict = format!(
        "Recommended: {} ({:.1}% Kill Prob, {:.1} Expected DMG into {})",
        best.weapon.name,
        best.report.kill_probability * 100.0,
        best.report.expected_damage_dealt,
        target.name
    );

    Ok(KtWeaponComparisonReport {
        target: target.clone(),
        context: context.clone(),
        entries,
        recommended_index: best_idx,
        summary_verdict,
    })
}
