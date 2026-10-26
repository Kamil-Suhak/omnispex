use crate::domain::unit::{ModelProfile, UnitProfile};
use crate::domain::weapon::{ReRollMode, WeaponLoadoutEntry, WeaponProfile};
use crate::engine::context::CombatContext;
use rand::Rng;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WoundSource {
    Standard,
    LethalHits,
    SustainedHits,
    DevastatingWounds,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WoundKind {
    Standard(WoundSource),
    Devastating(WoundSource),
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct VolleyOutcome {
    pub attacks_generated: u32,
    pub hits_scored: u32,
    pub critical_hits: u32,
    pub wounds_inflicted: u32,
    pub critical_wounds: u32,
    pub saves_failed: u32,
    pub models_killed: u32,
    pub damage_dealt: u32,
    pub raw_damage_generated: u32,
    pub lethal_damage: u32,
    pub sustained_damage: u32,
    pub devastating_damage: u32,
    pub surviving_models: usize,
    pub final_wounds: Vec<u32>,
}

/// Exact analytical stage probabilities computed deterministically without Monte Carlo variance.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct StageProbabilities {
    pub expected_attacks: f64,
    pub hit_probability: f64,
    pub crit_hit_probability: f64,
    pub wound_probability: f64,
    pub crit_wound_probability: f64,
    pub unsaved_probability_given_normal_wound: f64,
    pub expected_hits: f64,
    pub expected_wounds: f64,
    pub expected_unsaved_wounds: f64,
    pub expected_damage_per_unsaved: f64,
    pub expected_total_unclipped_damage: f64,
}

pub fn required_wound_roll(strength: u32, toughness: u32) -> u32 {
    if toughness == 0 {
        return 2;
    }
    if strength >= 2 * toughness {
        2
    } else if strength > toughness {
        3
    } else if strength == toughness {
        4
    } else if 2 * strength <= toughness {
        6
    } else {
        5
    }
}

pub fn find_allocated_model_index(wounds: &[u32], models: &[ModelProfile]) -> Option<usize> {
    for (i, (&w, model)) in wounds.iter().zip(models).enumerate() {
        if w > 0 && w < model.wounds {
            return Some(i);
        }
    }
    wounds.iter().position(|&w| w > 0)
}

fn effective_weapon_with_context(weapon: &WeaponProfile, context: &CombatContext) -> WeaponProfile {
    let mut w = weapon.clone();
    if context.bonus_strength != 0 {
        w.strength = (w.strength as i32 + context.bonus_strength).max(1) as u32;
    }
    if context.bonus_ap != 0 {
        w.ap = (w.ap as i32 + context.bonus_ap).max(0) as u32;
    }
    for ab in &context.extra_abilities {
        if !w.abilities.contains(ab) {
            w.abilities.push(ab.clone());
        }
    }
    w
}

/// Computes exact analytical stage probabilities for a weapon profile against a target unit.
pub fn compute_exact_stage_probabilities(
    raw_weapon: &WeaponProfile,
    target: &UnitProfile,
    context: &CombatContext,
) -> StageProbabilities {
    let weapon = effective_weapon_with_context(raw_weapon, context);
    let living_count = target.total_models();
    if living_count == 0
        || (weapon.is_ranged() && weapon.has_blast() && context.in_engagement_range)
        || (weapon.is_ranged() && context.attacker_advanced && !weapon.has_assault())
        || (weapon.is_ranged()
            && !context.target_visible
            && !weapon.has_indirect_fire())
    {
        return StageProbabilities::default();
    }

    let mut expected_attacks = weapon.attacks.expected_value();
    if weapon.is_ranged() && weapon.has_blast() && living_count >= 5 {
        expected_attacks += (living_count / 5) as f64;
    }
    if weapon.is_ranged() {
        if let Some(rf) = weapon.rapid_fire_bonus() {
            if let Some(dist) = context.distance_inches {
                if dist <= weapon.range / 2 {
                    expected_attacks += rf as f64;
                }
            }
        }
    }

    // Hit stage
    let crit_hit_threshold = context.crit_hit_on.clamp(2, 6);
    let (p_hit, p_crit_hit) = if weapon.has_torrent() {
        (1.0, 0.0)
    } else {
        let mut raw_hit_mod: i32 = context.hit_modifier;
        if weapon.is_ranged() && weapon.has_heavy() && context.is_stationary {
            raw_hit_mod += 1;
        }
        if weapon.is_ranged() && weapon.has_indirect_fire() && !context.target_visible {
            raw_hit_mod -= 1;
        }
        if weapon.is_ranged() && (target.has_stealth() || context.stealth_active) {
            raw_hit_mod -= 1;
        }
        raw_hit_mod -= target.minus_hit_value() as i32;
        let hit_mod = raw_hit_mod.clamp(-1, 1);

        let mut single_hit_faces = 0u32;
        let mut single_crit_faces = 0u32;
        for roll in 1..=6u32 {
            if roll == 1 {
                continue;
            }
            if weapon.is_ranged()
                && weapon.has_indirect_fire()
                && !context.target_visible
                && roll <= 3
            {
                continue;
            }
            let is_crit = roll >= crit_hit_threshold;
            let modified = (roll as i32 + hit_mod).max(1) as u32;
            if is_crit || modified >= weapon.skill {
                single_hit_faces += 1;
                if is_crit {
                    single_crit_faces += 1;
                }
            }
        }

        let p_single_hit = single_hit_faces as f64 / 6.0;
        let p_single_crit = single_crit_faces as f64 / 6.0;

        let effective_reroll = if target.prevents_hit_rerolls() {
            ReRollMode::None
        } else {
            context.hit_reroll
        };

        let reroll_prob = match effective_reroll {
            ReRollMode::None => 0.0,
            ReRollMode::Ones => 1.0 / 6.0,
            ReRollMode::Full => 1.0 - p_single_hit,
        };

        (
            p_single_hit + reroll_prob * p_single_hit,
            p_single_crit + reroll_prob * p_single_crit,
        )
    };

    let sustained_val = weapon.sustained_hits_value().unwrap_or(0) as f64;
    let p_non_crit_hit = (p_hit - p_crit_hit).max(0.0);
    let expected_hits_per_attack = p_hit + p_crit_hit * sustained_val;
    let expected_hits = expected_attacks * expected_hits_per_attack;

    // Wound stage
    let base_req_wound = required_wound_roll(weapon.strength, target.toughness);
    let mut raw_wound_mod: i32 = context.wound_modifier;
    if weapon.is_melee() && weapon.has_lance() && context.has_charged {
        raw_wound_mod += 1;
    }
    raw_wound_mod -= target.minus_wound_value() as i32;
    if context.minus_one_wound {
        raw_wound_mod -= 1;
    }
    let wound_mod = raw_wound_mod.clamp(-1, 1);

    let target_keywords = target.all_keywords();
    let anti_threshold = weapon.anti_threshold_for(&target_keywords);
    let crit_wound_threshold = anti_threshold
        .map(|a| a.min(context.crit_wound_on.clamp(2, 6)))
        .unwrap_or_else(|| context.crit_wound_on.clamp(2, 6));

    let mut single_wound_faces = 0u32;
    let mut single_crit_wound_faces = 0u32;
    for roll in 1..=6u32 {
        let eval = evaluate_wound_roll_with_crit(
            roll,
            wound_mod,
            base_req_wound,
            Some(crit_wound_threshold),
        );
        if eval.is_wound {
            single_wound_faces += 1;
            if eval.is_crit {
                single_crit_wound_faces += 1;
            }
        }
    }

    let p_single_wound = single_wound_faces as f64 / 6.0;
    let p_single_crit_wound = single_crit_wound_faces as f64 / 6.0;

    let effective_wound_reroll = if target.prevents_wound_rerolls() {
        ReRollMode::None
    } else if weapon.has_twin_linked() {
        ReRollMode::Full
    } else {
        context.wound_reroll
    };

    let wound_reroll_prob = match effective_wound_reroll {
        ReRollMode::None => 0.0,
        ReRollMode::Ones => 1.0 / 6.0,
        ReRollMode::Full => 1.0 - p_single_wound,
    };

    let p_wound = p_single_wound + wound_reroll_prob * p_single_wound;
    let p_crit_wound = p_single_crit_wound + wound_reroll_prob * p_single_crit_wound;
    let p_normal_wound = (p_wound - p_crit_wound).max(0.0);

    // Hits entering wound roll:
    // If Lethal Hits: crit hits auto-wound as normal wounds; non-crit hits + sustained hits roll to wound.
    let hits_rolling_wound_per_attack = if weapon.has_lethal_hits() {
        p_non_crit_hit + p_crit_hit * sustained_val
    } else {
        p_hit + p_crit_hit * sustained_val
    };
    let auto_normal_wounds_per_attack = if weapon.has_lethal_hits() {
        p_crit_hit
    } else {
        0.0
    };

    let normal_wounds_per_attack = auto_normal_wounds_per_attack
        + hits_rolling_wound_per_attack
            * (if weapon.has_devastating_wounds() {
                p_normal_wound
            } else {
                p_wound
            });
    let dev_wounds_per_attack = if weapon.has_devastating_wounds() {
        hits_rolling_wound_per_attack * p_crit_wound
    } else {
        0.0
    };

    let expected_wounds =
        expected_attacks * (normal_wounds_per_attack + dev_wounds_per_attack);

    // Save stage (evaluated against primary model group)
    let primary_model = target
        .model_groups
        .first()
        .map(|g| &g.model)
        .cloned()
        .unwrap_or_else(|| ModelProfile::new("Target", 1, 4, None, None));

    let has_cover = (context.target_has_benefit_of_cover
        || (weapon.has_indirect_fire() && !context.target_visible))
        && !weapon.has_ignores_cover();

    let ap_reduction =
        (if target.has_minus_one_ap() || primary_model.has_minus_one_ap() { 1 } else { 0 })
            + (if context.armor_of_contempt { 1 } else { 0 });
    let effective_ap = weapon.ap.saturating_sub(ap_reduction);

    let cover_bonus = if has_cover {
        if effective_ap == 0 && primary_model.save <= 3 {
            0
        } else {
            1
        }
    } else {
        0
    };

    let effective_armor =
        (primary_model.save as i32 + effective_ap as i32 - cover_bonus as i32).max(2) as u32;
    let best_invuln = match (primary_model.invulnerable_save, context.grant_invuln_4) {
        (Some(inv), true) => Some(inv.min(4)),
        (Some(inv), false) => Some(inv),
        (None, true) => Some(4),
        (None, false) => None,
    };
    let chosen_save = match best_invuln {
        Some(invuln) => effective_armor.min(invuln),
        None => effective_armor,
    };

    let p_save_success = if chosen_save > 6 {
        0.0
    } else {
        (7 - chosen_save.max(2)) as f64 / 6.0
    };
    let p_unsaved = 1.0 - p_save_success;

    let expected_unsaved_wounds =
        expected_attacks * (normal_wounds_per_attack * p_unsaved + dev_wounds_per_attack);

    // Damage per unsaved wound (exact PMF over weapon.damage)
    let melta_bonus = if weapon.is_ranged() {
        weapon
            .melta_bonus()
            .and_then(|m| context.distance_inches.map(|d| if d <= weapon.range / 2 { m } else { 0 }))
            .unwrap_or(0)
    } else {
        0
    };

    let half_dmg = target.has_half_damage() || primary_model.has_half_damage() || context.half_damage;
    let dmg_red = target
        .damage_reduction_value()
        .max(primary_model.damage_reduction_value())
        + (if context.minus_one_damage { 1 } else { 0 });

    let best_fnp = match (primary_model.feel_no_pain, context.grant_fnp_5) {
        (Some(fnp), true) => Some(fnp.min(5)),
        (Some(fnp), false) => Some(fnp),
        (None, true) => Some(5),
        (None, false) => None,
    };
    let fnp_pass_multiplier = match best_fnp {
        Some(fnp) if (2..=6).contains(&fnp) => (fnp - 1) as f64 / 6.0,
        _ => 1.0,
    };

    let mut expected_damage_per_unsaved = 0.0;
    for (base_d, prob) in weapon.damage.pmf() {
        let mut d = base_d + melta_bonus;
        if half_dmg {
            d = ((d as f64) / 2.0).ceil() as u32;
        }
        if dmg_red > 0 {
            d = d.saturating_sub(dmg_red).max(1);
        }
        expected_damage_per_unsaved += (d as f64) * fnp_pass_multiplier * prob;
    }

    let expected_total_unclipped_damage = expected_unsaved_wounds * expected_damage_per_unsaved;

    StageProbabilities {
        expected_attacks,
        hit_probability: p_hit,
        crit_hit_probability: p_crit_hit,
        wound_probability: p_wound,
        crit_wound_probability: p_crit_wound,
        unsaved_probability_given_normal_wound: p_unsaved,
        expected_hits,
        expected_wounds,
        expected_unsaved_wounds,
        expected_damage_per_unsaved,
        expected_total_unclipped_damage,
    }
}

pub fn resolve_squad_volley(
    loadout: &[WeaponLoadoutEntry],
    target: &UnitProfile,
    context: &CombatContext,
    wounds: &mut [u32],
    rng: &mut impl Rng,
) -> VolleyOutcome {
    let mut combined = VolleyOutcome::default();
    let initial_living = UnitProfile::living_models_count(wounds);
    if initial_living == 0 {
        combined.final_wounds = wounds.to_vec();
        return combined;
    }

    for entry in loadout {
        if !entry.enabled || entry.count == 0 {
            continue;
        }
        for _ in 0..entry.count {
            if UnitProfile::living_models_count(wounds) == 0 {
                break;
            }
            let sub = resolve_volley(&entry.weapon, target, context, wounds, rng);
            combined.attacks_generated += sub.attacks_generated;
            combined.hits_scored += sub.hits_scored;
            combined.critical_hits += sub.critical_hits;
            combined.wounds_inflicted += sub.wounds_inflicted;
            combined.critical_wounds += sub.critical_wounds;
            combined.saves_failed += sub.saves_failed;
            combined.models_killed += sub.models_killed;
            combined.damage_dealt += sub.damage_dealt;
            combined.raw_damage_generated += sub.raw_damage_generated;
            combined.lethal_damage += sub.lethal_damage;
            combined.sustained_damage += sub.sustained_damage;
            combined.devastating_damage += sub.devastating_damage;
        }
    }

    combined.surviving_models = UnitProfile::living_models_count(wounds);
    combined.final_wounds = wounds.to_vec();
    combined
}

pub fn resolve_volley(
    raw_weapon: &WeaponProfile,
    target: &UnitProfile,
    context: &CombatContext,
    wounds: &mut [u32],
    rng: &mut impl Rng,
) -> VolleyOutcome {
    let weapon = effective_weapon_with_context(raw_weapon, context);
    let mut outcome = VolleyOutcome::default();

    let living_count = UnitProfile::living_models_count(wounds);
    if living_count == 0 {
        outcome.final_wounds = wounds.to_vec();
        return outcome;
    }

    if (weapon.is_ranged() && weapon.has_blast() && context.in_engagement_range)
        || (weapon.is_ranged() && context.attacker_advanced && !weapon.has_assault())
        || (weapon.is_ranged() && !context.target_visible && !weapon.has_indirect_fire())
    {
        outcome.surviving_models = living_count;
        outcome.final_wounds = wounds.to_vec();
        return outcome;
    }

    let mut attack_count = weapon.attacks.roll(rng);

    if weapon.is_ranged() && weapon.has_blast() && living_count >= 5 {
        attack_count += (living_count / 5) as u32;
    }

    if weapon.is_ranged() {
        if let Some(rf) = weapon.rapid_fire_bonus() {
            if let Some(dist) = context.distance_inches {
                if dist <= weapon.range / 2 {
                    attack_count += rf;
                }
            }
        }
    }

    outcome.attacks_generated = attack_count;

    let mut pending_wounds: Vec<WoundKind> = Vec::new();
    let mut pending_hits_sources: Vec<WoundSource> = Vec::new();

    let mut raw_hit_mod: i32 = context.hit_modifier;
    if weapon.is_ranged() && weapon.has_heavy() && context.is_stationary {
        raw_hit_mod += 1;
    }
    if weapon.is_ranged() && weapon.has_indirect_fire() && !context.target_visible {
        raw_hit_mod -= 1;
    }
    if weapon.is_ranged() && (target.has_stealth() || context.stealth_active) {
        raw_hit_mod -= 1;
    }
    raw_hit_mod -= target.minus_hit_value() as i32;
    let hit_mod = raw_hit_mod.clamp(-1, 1);

    let crit_hit_threshold = context.crit_hit_on.clamp(2, 6);
    let effective_hit_reroll = if target.prevents_hit_rerolls() {
        ReRollMode::None
    } else {
        context.hit_reroll
    };

    for _ in 0..attack_count {
        if weapon.has_torrent() {
            outcome.hits_scored += 1;
            pending_hits_sources.push(WoundSource::Standard);
            continue;
        }

        let mut roll = rng.gen_range(1..=6);
        let mut hit_eval = evaluate_hit_roll(
            roll,
            hit_mod,
            weapon.skill,
            crit_hit_threshold,
            weapon.is_ranged() && weapon.has_indirect_fire() && !context.target_visible,
        );

        let should_reroll = match effective_hit_reroll {
            ReRollMode::None => false,
            ReRollMode::Ones => roll == 1,
            ReRollMode::Full => !hit_eval.is_hit,
        };
        if should_reroll {
            roll = rng.gen_range(1..=6);
            hit_eval = evaluate_hit_roll(
                roll,
                hit_mod,
                weapon.skill,
                crit_hit_threshold,
                weapon.is_ranged() && weapon.has_indirect_fire() && !context.target_visible,
            );
        }

        if hit_eval.is_hit {
            outcome.hits_scored += 1;

            if hit_eval.is_crit {
                outcome.critical_hits += 1;

                if weapon.has_lethal_hits() {
                    pending_wounds.push(WoundKind::Standard(WoundSource::LethalHits));
                    outcome.wounds_inflicted += 1;
                } else {
                    pending_hits_sources.push(WoundSource::Standard);
                }

                if let Some(sustained) = weapon.sustained_hits_value() {
                    for _ in 0..sustained {
                        pending_hits_sources.push(WoundSource::SustainedHits);
                    }
                }
            } else {
                pending_hits_sources.push(WoundSource::Standard);
            }
        }
    }

    let base_req_wound = required_wound_roll(weapon.strength, target.toughness);
    let mut raw_wound_mod: i32 = context.wound_modifier;
    if weapon.is_melee() && weapon.has_lance() && context.has_charged {
        raw_wound_mod += 1;
    }
    raw_wound_mod -= target.minus_wound_value() as i32;
    if context.minus_one_wound {
        raw_wound_mod -= 1;
    }
    let wound_mod = raw_wound_mod.clamp(-1, 1);

    let target_keywords = target.all_keywords();
    let anti_threshold = weapon.anti_threshold_for(&target_keywords);
    let crit_wound_threshold = anti_threshold
        .map(|a| a.min(context.crit_wound_on.clamp(2, 6)))
        .unwrap_or_else(|| context.crit_wound_on.clamp(2, 6));

    let effective_wound_reroll = if target.prevents_wound_rerolls() {
        ReRollMode::None
    } else if weapon.has_twin_linked() {
        ReRollMode::Full
    } else {
        context.wound_reroll
    };

    for source in pending_hits_sources {
        let mut roll = rng.gen_range(1..=6);
        let mut wound_success = evaluate_wound_roll_with_crit(
            roll,
            wound_mod,
            base_req_wound,
            Some(crit_wound_threshold),
        );

        let should_reroll = match effective_wound_reroll {
            ReRollMode::None => false,
            ReRollMode::Ones => roll == 1,
            ReRollMode::Full => !wound_success.is_wound,
        };

        if should_reroll {
            roll = rng.gen_range(1..=6);
            wound_success = evaluate_wound_roll_with_crit(
                roll,
                wound_mod,
                base_req_wound,
                Some(crit_wound_threshold),
            );
        }

        if wound_success.is_wound {
            outcome.wounds_inflicted += 1;
            if wound_success.is_crit {
                outcome.critical_wounds += 1;
                if weapon.has_devastating_wounds() {
                    pending_wounds.push(WoundKind::Devastating(WoundSource::DevastatingWounds));
                } else {
                    pending_wounds.push(WoundKind::Standard(source));
                }
            } else {
                pending_wounds.push(WoundKind::Standard(source));
            }
        }
    }

    let expanded_models = target.expanded_models();

    for wound_kind in pending_wounds {
        let alloc_idx = match find_allocated_model_index(wounds, &expanded_models) {
            Some(idx) => idx,
            None => break,
        };

        let model = &expanded_models[alloc_idx];
        let (is_devastating, source) = match wound_kind {
            WoundKind::Standard(src) => (false, src),
            WoundKind::Devastating(src) => (true, src),
        };

        if !is_devastating {
            let has_cover = (context.target_has_benefit_of_cover
                || (weapon.has_indirect_fire() && !context.target_visible))
                && !weapon.has_ignores_cover();

            let ap_reduction =
                (if target.has_minus_one_ap() || model.has_minus_one_ap() { 1 } else { 0 })
                    + (if context.armor_of_contempt { 1 } else { 0 });
            let effective_ap = weapon.ap.saturating_sub(ap_reduction);

            let cover_bonus = if has_cover {
                if effective_ap == 0 && model.save <= 3 {
                    0
                } else {
                    1
                }
            } else {
                0
            };

            let effective_armor =
                (model.save as i32 + effective_ap as i32 - cover_bonus as i32).max(2) as u32;
            let best_invuln = match (model.invulnerable_save, context.grant_invuln_4) {
                (Some(inv), true) => Some(inv.min(4)),
                (Some(inv), false) => Some(inv),
                (None, true) => Some(4),
                (None, false) => None,
            };
            let chosen_save = match best_invuln {
                Some(invuln) => effective_armor.min(invuln),
                None => effective_armor,
            };

            let save_roll = rng.gen_range(1..=6);
            if save_roll != 1 && save_roll >= chosen_save {
                continue;
            }
        }

        outcome.saves_failed += 1;

        let mut damage = weapon.damage.roll(rng);
        if weapon.is_ranged() {
            if let Some(melta) = weapon.melta_bonus() {
                if let Some(dist) = context.distance_inches {
                    if dist <= weapon.range / 2 {
                        damage += melta;
                    }
                }
            }
        }

        if target.has_half_damage() || model.has_half_damage() || context.half_damage {
            damage = ((damage as f64) / 2.0).ceil() as u32;
        }

        let dmg_reduction = target
            .damage_reduction_value()
            .max(model.damage_reduction_value())
            + (if context.minus_one_damage { 1 } else { 0 });
        if dmg_reduction > 0 {
            damage = damage.saturating_sub(dmg_reduction).max(1);
        }

        let best_fnp = match (model.feel_no_pain, context.grant_fnp_5) {
            (Some(fnp), true) => Some(fnp.min(5)),
            (Some(fnp), false) => Some(fnp),
            (None, true) => Some(5),
            (None, false) => None,
        };

        let effective_dmg = if let Some(fnp) = best_fnp {
            let mut taken = 0;
            for _ in 0..damage {
                let fnp_roll = rng.gen_range(1..=6);
                if fnp_roll < fnp {
                    taken += 1;
                }
            }
            taken
        } else {
            damage
        };

        outcome.raw_damage_generated += effective_dmg;

        if effective_dmg > 0 {
            let current_hp = wounds[alloc_idx];
            let damage_applied = effective_dmg.min(current_hp);
            wounds[alloc_idx] -= damage_applied;
            outcome.damage_dealt += damage_applied;

            match source {
                WoundSource::LethalHits => outcome.lethal_damage += damage_applied,
                WoundSource::SustainedHits => outcome.sustained_damage += damage_applied,
                WoundSource::DevastatingWounds => outcome.devastating_damage += damage_applied,
                WoundSource::Standard => {}
            }

            if wounds[alloc_idx] == 0 {
                outcome.models_killed += 1;
            }
        }
    }

    outcome.surviving_models = UnitProfile::living_models_count(wounds);
    outcome.final_wounds = wounds.to_vec();
    outcome
}

struct HitRollEval {
    is_hit: bool,
    is_crit: bool,
}

fn evaluate_hit_roll(
    roll: u32,
    hit_mod: i32,
    skill: u32,
    crit_threshold: u32,
    indirect_out_of_los: bool,
) -> HitRollEval {
    if roll == 1 {
        return HitRollEval {
            is_hit: false,
            is_crit: false,
        };
    }
    if indirect_out_of_los && roll <= 3 {
        return HitRollEval {
            is_hit: false,
            is_crit: false,
        };
    }
    let is_crit = roll >= crit_threshold;
    let modified = (roll as i32 + hit_mod).max(1) as u32;
    if is_crit || modified >= skill {
        HitRollEval {
            is_hit: true,
            is_crit,
        }
    } else {
        HitRollEval {
            is_hit: false,
            is_crit: false,
        }
    }
}

struct WoundRollEval {
    is_wound: bool,
    is_crit: bool,
}

fn evaluate_wound_roll_with_crit(
    roll: u32,
    wound_mod: i32,
    base_req_wound: u32,
    crit_threshold: Option<u32>,
) -> WoundRollEval {
    if roll == 1 {
        return WoundRollEval {
            is_wound: false,
            is_crit: false,
        };
    }

    let crit_on = crit_threshold.unwrap_or(6).clamp(2, 6);
    if roll >= crit_on {
        return WoundRollEval {
            is_wound: true,
            is_crit: true,
        };
    }

    let modified = (roll as i32 + wound_mod).max(1) as u32;
    if modified >= base_req_wound {
        WoundRollEval {
            is_wound: true,
            is_crit: false,
        }
    } else {
        WoundRollEval {
            is_wound: false,
            is_crit: false,
        }
    }
}
