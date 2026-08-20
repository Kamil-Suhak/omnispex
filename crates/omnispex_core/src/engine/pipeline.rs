use crate::domain::unit::UnitProfile;
use crate::domain::weapon::WeaponProfile;
use crate::engine::context::CombatContext;
use rand::Rng;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WoundKind {
    Standard,
    Devastating,
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
    pub surviving_models: usize,
    pub final_wounds: Vec<u32>,
}

pub fn required_wound_roll(strength: u32, toughness: u32) -> u32 {
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

pub fn find_allocated_model_index(wounds: &[u32], target: &UnitProfile) -> Option<usize> {
    for (i, (&w, model)) in wounds.iter().zip(&target.models).enumerate() {
        if w > 0 && w < model.wounds {
            return Some(i);
        }
    }
    wounds.iter().position(|&w| w > 0)
}

pub fn resolve_volley(
    weapon: &WeaponProfile,
    target: &UnitProfile,
    context: &CombatContext,
    wounds: &mut [u32],
    rng: &mut impl Rng,
) -> VolleyOutcome {
    let mut outcome = VolleyOutcome::default();

    let living_count = UnitProfile::living_models_count(wounds);
    if living_count == 0 {
        outcome.final_wounds = wounds.to_vec();
        return outcome;
    }

    if weapon.has_blast() && context.in_engagement_range {
        outcome.surviving_models = living_count;
        outcome.final_wounds = wounds.to_vec();
        return outcome;
    }

    let mut attack_count = weapon.attacks.roll(rng);

    if weapon.has_blast() && living_count >= 5 {
        attack_count += (living_count / 5) as u32;
    }

    if let Some(rf) = weapon.rapid_fire_bonus() {
        if let Some(dist) = context.distance_inches {
            if dist <= weapon.range / 2 {
                attack_count += rf;
            }
        }
    }

    outcome.attacks_generated = attack_count;

    let mut pending_wounds: Vec<WoundKind> = Vec::new();
    let mut standard_hits = 0u32;

    let mut raw_hit_mod: i32 = 0;
    if weapon.has_heavy() && context.is_stationary {
        raw_hit_mod += 1;
    }
    if weapon.has_indirect_fire() && !context.target_visible {
        raw_hit_mod -= 1;
    }
    let hit_mod = raw_hit_mod.clamp(-1, 1);

    for _ in 0..attack_count {
        if weapon.has_torrent() {
            outcome.hits_scored += 1;
            standard_hits += 1;
            continue;
        }

        let roll = rng.gen_range(1..=6);
        if roll == 1 {
            continue;
        }

        let is_crit = roll == 6;
        let modified_roll = (roll as i32 + hit_mod).max(1) as u32;

        if is_crit || modified_roll >= weapon.skill {
            outcome.hits_scored += 1;

            if is_crit {
                outcome.critical_hits += 1;

                if weapon.has_lethal_hits() {
                    pending_wounds.push(WoundKind::Standard);
                    outcome.wounds_inflicted += 1;
                } else {
                    standard_hits += 1;
                }

                if let Some(sustained) = weapon.sustained_hits_value() {
                    standard_hits += sustained;
                }
            } else {
                standard_hits += 1;
            }
        }
    }

    let base_req_wound = required_wound_roll(weapon.strength, target.toughness);
    let mut raw_wound_mod: i32 = 0;
    if weapon.has_lance() && context.has_charged {
        raw_wound_mod += 1;
    }
    let wound_mod = raw_wound_mod.clamp(-1, 1);

    let target_keywords = target.all_keywords();
    let anti_threshold = weapon.anti_threshold_for(&target_keywords);

    for _ in 0..standard_hits {
        let mut roll = rng.gen_range(1..=6);
        let mut wound_success = evaluate_wound_roll(roll, wound_mod, base_req_wound, anti_threshold);

        if !wound_success.is_wound && weapon.has_twin_linked() {
            roll = rng.gen_range(1..=6);
            wound_success = evaluate_wound_roll(roll, wound_mod, base_req_wound, anti_threshold);
        }

        if wound_success.is_wound {
            outcome.wounds_inflicted += 1;
            if wound_success.is_crit {
                outcome.critical_wounds += 1;
                if weapon.has_devastating_wounds() {
                    pending_wounds.push(WoundKind::Devastating);
                } else {
                    pending_wounds.push(WoundKind::Standard);
                }
            } else {
                pending_wounds.push(WoundKind::Standard);
            }
        }
    }

    for wound_kind in pending_wounds {
        let alloc_idx = match find_allocated_model_index(wounds, target) {
            Some(idx) => idx,
            None => break,
        };

        let model = &target.models[alloc_idx];

        if wound_kind == WoundKind::Standard {
            let has_cover = (context.target_has_benefit_of_cover
                || (weapon.has_indirect_fire() && !context.target_visible))
                && !weapon.has_ignores_cover();

            let cover_bonus = if has_cover {
                if weapon.ap == 0 && model.save <= 3 {
                    0
                } else {
                    1
                }
            } else {
                0
            };

            let effective_armor = (model.save as i32 + weapon.ap as i32 - cover_bonus as i32).max(2) as u32;
            let chosen_save = match model.invulnerable_save {
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
        if let Some(melta) = weapon.melta_bonus() {
            if let Some(dist) = context.distance_inches {
                if dist <= weapon.range / 2 {
                    damage += melta;
                }
            }
        }

        let effective_dmg = if let Some(fnp) = model.feel_no_pain {
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

        if effective_dmg > 0 {
            let current_hp = wounds[alloc_idx];
            let damage_applied = effective_dmg.min(current_hp);
            wounds[alloc_idx] -= damage_applied;
            outcome.damage_dealt += damage_applied;

            if wounds[alloc_idx] == 0 {
                outcome.models_killed += 1;
            }
        }
    }

    outcome.surviving_models = UnitProfile::living_models_count(wounds);
    outcome.final_wounds = wounds.to_vec();
    outcome
}

struct WoundRollEval {
    is_wound: bool,
    is_crit: bool,
}

fn evaluate_wound_roll(
    roll: u32,
    wound_mod: i32,
    base_req_wound: u32,
    anti_threshold: Option<u32>,
) -> WoundRollEval {
    if roll == 1 {
        return WoundRollEval {
            is_wound: false,
            is_crit: false,
        };
    }

    if roll == 6 {
        return WoundRollEval {
            is_wound: true,
            is_crit: true,
        };
    }

    if let Some(threshold) = anti_threshold {
        if roll >= threshold {
            return WoundRollEval {
                is_wound: true,
                is_crit: true,
            };
        }
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
