use super::weapon::Keyword;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum DefensiveAbility {
    MinusHit(u32),
    MinusWound(u32),
    ReduceDamage(u32),
    HalfDamage,
    Stealth,
    NoWoundReRolls,
    NoHitReRolls,
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
                DefensiveAbility::ReduceDamage(x) => Some(*x),
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UnitProfile {
    pub name: String,
    pub toughness: u32,
    #[serde(default)]
    pub model_groups: Vec<ModelGroup>,
    #[serde(default)]
    pub defensive_abilities: Vec<DefensiveAbility>,
    #[serde(default)]
    pub keywords: Vec<Keyword>,
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
            model_groups,
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
            model_groups: vec![ModelGroup::new(count, model)],
            defensive_abilities: Vec::new(),
            keywords,
        }
    }

    pub fn with_defensive_abilities(mut self, abilities: Vec<DefensiveAbility>) -> Self {
        self.defensive_abilities = abilities;
        self
    }

    pub fn expanded_models(&self) -> Vec<ModelProfile> {
        let mut models = Vec::with_capacity(self.total_models());
        for group in &self.model_groups {
            for _ in 0..group.count {
                models.push(group.model.clone());
            }
        }
        models
    }

    pub fn initial_wounds(&self) -> Vec<u32> {
        let mut wounds = Vec::with_capacity(self.total_models());
        for group in &self.model_groups {
            for _ in 0..group.count {
                wounds.push(group.model.wounds);
            }
        }
        wounds
    }

    pub fn total_models(&self) -> usize {
        self.model_groups.iter().map(|g| g.count).sum()
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
                _ => None,
            })
            .max()
            .unwrap_or(0)
    }

    pub fn damage_reduction_value(&self) -> u32 {
        self.defensive_abilities
            .iter()
            .filter_map(|a| match a {
                DefensiveAbility::ReduceDamage(x) => Some(*x),
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
