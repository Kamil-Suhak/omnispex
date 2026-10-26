use super::weapon::Keyword;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum DefensiveAbility {
    MinusHit(u32),
    MinusWound(u32),
    MinusOneToWound,
    MinusOneAp,
    ReduceDamage(u32),
    DamageReduction(u32),
    HalfDamage,
    Stealth,
    NoWoundReRolls,
    NoHitReRolls,
    FeelNoPain(u32),
    InvulnerableSave(u32),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelProfile {
    pub name: String,
    pub wounds: u32,
    pub save: u32,
    pub invulnerable_save: Option<u32>,
    pub feel_no_pain: Option<u32>,
    #[serde(default)]
    pub defensive_abilities: Vec<DefensiveAbility>,
    #[serde(default)]
    pub keywords: Vec<Keyword>,
}

impl ModelProfile {
    pub fn new(
        name: impl Into<String>,
        wounds: u32,
        save: u32,
        invulnerable_save: Option<u32>,
        feel_no_pain: Option<u32>,
    ) -> Self {
        Self {
            name: name.into(),
            wounds,
            save,
            invulnerable_save,
            feel_no_pain,
            defensive_abilities: Vec::new(),
            keywords: Vec::new(),
        }
    }

    pub fn with_keywords(mut self, keywords: Vec<Keyword>) -> Self {
        self.keywords = keywords;
        self
    }

    pub fn with_defensive_abilities(mut self, abilities: Vec<DefensiveAbility>) -> Self {
        self.defensive_abilities = abilities;
        self
    }

    pub fn damage_reduction_value(&self) -> u32 {
        self.defensive_abilities
            .iter()
            .filter_map(|a| match a {
                DefensiveAbility::ReduceDamage(x) | DefensiveAbility::DamageReduction(x) => {
                    Some(*x)
                }
                _ => None,
            })
            .max()
            .unwrap_or(0)
    }

    pub fn has_half_damage(&self) -> bool {
        self.defensive_abilities
            .iter()
            .any(|a| matches!(a, DefensiveAbility::HalfDamage))
    }

    pub fn has_minus_one_ap(&self) -> bool {
        self.defensive_abilities
            .iter()
            .any(|a| matches!(a, DefensiveAbility::MinusOneAp))
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelGroup {
    pub count: usize,
    pub model: ModelProfile,
}

impl ModelGroup {
    pub fn new(count: usize, model: ModelProfile) -> Self {
        Self { count, model }
    }
}

fn default_movement() -> String {
    "6\"".to_string()
}

fn default_leadership() -> String {
    "6+".to_string()
}

fn default_oc() -> u32 {
    1
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UnitProfile {
    pub name: String,
    pub toughness: u32,
    #[serde(default = "default_movement")]
    pub movement: String,
    #[serde(default = "default_leadership")]
    pub leadership: String,
    #[serde(default = "default_oc")]
    pub objective_control: u32,
    #[serde(default)]
    pub model_groups: Vec<ModelGroup>,
    #[serde(default)]
    pub models: Option<Vec<ModelProfile>>,
    #[serde(default)]
    pub defensive_abilities: Vec<DefensiveAbility>,
    #[serde(default)]
    pub keywords: Vec<Keyword>,
}

impl Default for UnitProfile {
    fn default() -> Self {
        Self::uniform(
            "Target Unit",
            4,
            ModelProfile::new("Model", 2, 3, None, None),
            5,
            vec![Keyword::Infantry],
        )
    }
}

impl UnitProfile {
    pub fn new(
        name: impl Into<String>,
        toughness: u32,
        model_groups: Vec<ModelGroup>,
        keywords: Vec<Keyword>,
    ) -> Self {
        Self {
            name: name.into(),
            toughness,
            movement: default_movement(),
            leadership: default_leadership(),
            objective_control: default_oc(),
            model_groups,
            models: None,
            defensive_abilities: Vec::new(),
            keywords,
        }
    }

    pub fn uniform(
        name: impl Into<String>,
        toughness: u32,
        model: ModelProfile,
        count: usize,
        keywords: Vec<Keyword>,
    ) -> Self {
        Self {
            name: name.into(),
            toughness,
            movement: default_movement(),
            leadership: default_leadership(),
            objective_control: default_oc(),
            model_groups: vec![ModelGroup::new(count, model)],
            models: None,
            defensive_abilities: Vec::new(),
            keywords,
        }
    }

    pub fn with_datasheet_stats(
        mut self,
        movement: impl Into<String>,
        leadership: impl Into<String>,
        objective_control: u32,
    ) -> Self {
        self.movement = movement.into();
        self.leadership = leadership.into();
        self.objective_control = objective_control;
        self
    }

    pub fn with_defensive_abilities(mut self, abilities: Vec<DefensiveAbility>) -> Self {
        self.defensive_abilities = abilities;
        self
    }

    pub fn expanded_models(&self) -> Vec<ModelProfile> {
        if !self.model_groups.is_empty() {
            let mut models = Vec::with_capacity(self.total_models());
            for group in &self.model_groups {
                for _ in 0..group.count {
                    models.push(group.model.clone());
                }
            }
            models
        } else if let Some(ref legacy) = self.models {
            legacy.clone()
        } else {
            Vec::new()
        }
    }

    pub fn initial_wounds(&self) -> Vec<u32> {
        if !self.model_groups.is_empty() {
            let mut wounds = Vec::with_capacity(self.total_models());
            for group in &self.model_groups {
                for _ in 0..group.count {
                    wounds.push(group.model.wounds);
                }
            }
            wounds
        } else if let Some(ref legacy) = self.models {
            legacy.iter().map(|m| m.wounds).collect()
        } else {
            Vec::new()
        }
    }

    pub fn total_models(&self) -> usize {
        let count: usize = self.model_groups.iter().map(|g| g.count).sum();
        if count == 0 {
            if let Some(ref legacy) = self.models {
                return legacy.len();
            }
        }
        count
    }

    pub fn living_models_count(wounds: &[u32]) -> usize {
        wounds.iter().filter(|&&w| w > 0).count()
    }

    pub fn is_destroyed(wounds: &[u32]) -> bool {
        wounds.iter().all(|&w| w == 0)
    }

    pub fn all_keywords(&self) -> Vec<Keyword> {
        let mut set = self.keywords.clone();
        for group in &self.model_groups {
            for kw in &group.model.keywords {
                if !set.iter().any(|k| k.matches(kw)) {
                    set.push(kw.clone());
                }
            }
        }
        set
    }

    pub fn has_keyword(&self, target: &Keyword) -> bool {
        self.all_keywords().iter().any(|k| k.matches(target))
    }

    pub fn has_stealth(&self) -> bool {
        self.defensive_abilities
            .iter()
            .any(|a| matches!(a, DefensiveAbility::Stealth))
    }

    pub fn has_minus_one_ap(&self) -> bool {
        self.defensive_abilities
            .iter()
            .any(|a| matches!(a, DefensiveAbility::MinusOneAp))
    }

    pub fn minus_hit_value(&self) -> u32 {
        self.defensive_abilities
            .iter()
            .filter_map(|a| match a {
                DefensiveAbility::MinusHit(x) => Some(*x),
                _ => None,
            })
            .max()
            .unwrap_or(0)
    }

    pub fn minus_wound_value(&self) -> u32 {
        self.defensive_abilities
            .iter()
            .filter_map(|a| match a {
                DefensiveAbility::MinusWound(x) => Some(*x),
                DefensiveAbility::MinusOneToWound => Some(1),
                _ => None,
            })
            .max()
            .unwrap_or(0)
    }

    pub fn damage_reduction_value(&self) -> u32 {
        self.defensive_abilities
            .iter()
            .filter_map(|a| match a {
                DefensiveAbility::ReduceDamage(x) | DefensiveAbility::DamageReduction(x) => {
                    Some(*x)
                }
                _ => None,
            })
            .max()
            .unwrap_or(0)
    }

    pub fn has_half_damage(&self) -> bool {
        self.defensive_abilities
            .iter()
            .any(|a| matches!(a, DefensiveAbility::HalfDamage))
    }

    pub fn prevents_wound_rerolls(&self) -> bool {
        self.defensive_abilities
            .iter()
            .any(|a| matches!(a, DefensiveAbility::NoWoundReRolls))
    }

    pub fn prevents_hit_rerolls(&self) -> bool {
        self.defensive_abilities
            .iter()
            .any(|a| matches!(a, DefensiveAbility::NoHitReRolls))
    }
}
