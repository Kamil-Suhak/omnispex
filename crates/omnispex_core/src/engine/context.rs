use crate::domain::weapon::{ReRollMode, WeaponAbility};
use serde::{Deserialize, Serialize};

fn default_true() -> bool {
    true
}

fn default_six() -> u32 {
    6
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CombatContext {
    #[serde(default)]
    pub distance_inches: Option<u32>,
    #[serde(default)]
    pub is_stationary: bool,
    #[serde(default)]
    pub has_charged: bool,
    #[serde(default)]
    pub in_engagement_range: bool,
    #[serde(default)]
    pub target_has_benefit_of_cover: bool,
    #[serde(default = "default_true")]
    pub target_visible: bool,
    #[serde(default)]
    pub attacker_advanced: bool,

    // Attacker modifiers & rerolls
    #[serde(default)]
    pub hit_reroll: ReRollMode,
    #[serde(default)]
    pub wound_reroll: ReRollMode,
    #[serde(default)]
    pub hit_modifier: i32,
    #[serde(default)]
    pub wound_modifier: i32,
    #[serde(default)]
    pub bonus_strength: i32,
    #[serde(default)]
    pub bonus_ap: i32,
    #[serde(default = "default_six")]
    pub crit_hit_on: u32,
    #[serde(default = "default_six")]
    pub crit_wound_on: u32,
    #[serde(default)]
    pub extra_abilities: Vec<WeaponAbility>,

    // Defensive counter-stratagem / rule toggles
    #[serde(default)]
    pub armor_of_contempt: bool,
    #[serde(default)]
    pub minus_one_wound: bool,
    #[serde(default)]
    pub grant_invuln_4: bool,
    #[serde(default)]
    pub grant_fnp_5: bool,
    #[serde(default)]
    pub minus_one_damage: bool,
    #[serde(default)]
    pub half_damage: bool,
    #[serde(default)]
    pub stealth_active: bool,
}

impl Default for CombatContext {
    fn default() -> Self {
        Self {
            distance_inches: None,
            is_stationary: false,
            has_charged: false,
            in_engagement_range: false,
            target_has_benefit_of_cover: false,
            target_visible: true,
            attacker_advanced: false,
            hit_reroll: ReRollMode::None,
            wound_reroll: ReRollMode::None,
            hit_modifier: 0,
            wound_modifier: 0,
            bonus_strength: 0,
            bonus_ap: 0,
            crit_hit_on: 6,
            crit_wound_on: 6,
            extra_abilities: Vec::new(),
            armor_of_contempt: false,
            minus_one_wound: false,
            grant_invuln_4: false,
            grant_fnp_5: false,
            minus_one_damage: false,
            half_damage: false,
            stealth_active: false,
        }
    }
}

impl CombatContext {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_distance(mut self, distance: u32) -> Self {
        self.distance_inches = Some(distance);
        self
    }

    pub fn stationary(mut self, val: bool) -> Self {
        self.is_stationary = val;
        self
    }

    pub fn charged(mut self, val: bool) -> Self {
        self.has_charged = val;
        self
    }

    pub fn in_engagement_range(mut self, val: bool) -> Self {
        self.in_engagement_range = val;
        self
    }

    pub fn with_cover(mut self, val: bool) -> Self {
        self.target_has_benefit_of_cover = val;
        self
    }

    pub fn visible(mut self, val: bool) -> Self {
        self.target_visible = val;
        self
    }

    pub fn advanced(mut self, val: bool) -> Self {
        self.attacker_advanced = val;
        self
    }

    pub fn with_hit_reroll(mut self, mode: ReRollMode) -> Self {
        self.hit_reroll = mode;
        self
    }

    pub fn with_wound_reroll(mut self, mode: ReRollMode) -> Self {
        self.wound_reroll = mode;
        self
    }

    pub fn with_hit_modifier(mut self, modifier: i32) -> Self {
        self.hit_modifier = modifier;
        self
    }

    pub fn with_wound_modifier(mut self, modifier: i32) -> Self {
        self.wound_modifier = modifier;
        self
    }
}
