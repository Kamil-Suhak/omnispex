use super::weapon::Keyword;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelProfile {
    pub name: String,
    pub wounds: u32,
    pub save: u32,
    pub invulnerable_save: Option<u32>,
    pub feel_no_pain: Option<u32>,
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
            keywords: Vec::new(),
        }
    }

    pub fn with_keywords(mut self, keywords: Vec<Keyword>) -> Self {
        self.keywords = keywords;
        self
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UnitProfile {
    pub name: String,
    pub toughness: u32,
    pub models: Vec<ModelProfile>,
    pub keywords: Vec<Keyword>,
}

impl UnitProfile {
    pub fn new(name: impl Into<String>, toughness: u32, models: Vec<ModelProfile>, keywords: Vec<Keyword>) -> Self {
        Self {
            name: name.into(),
            toughness,
            models,
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
        let models = vec![model; count];
        Self {
            name: name.into(),
            toughness,
            models,
            keywords,
        }
    }

    pub fn initial_wounds(&self) -> Vec<u32> {
        self.models.iter().map(|m| m.wounds).collect()
    }

    pub fn total_models(&self) -> usize {
        self.models.len()
    }

    pub fn living_models_count(wounds: &[u32]) -> usize {
        wounds.iter().filter(|&&w| w > 0).count()
    }

    pub fn is_destroyed(wounds: &[u32]) -> bool {
        wounds.iter().all(|&w| w == 0)
    }

    pub fn all_keywords(&self) -> Vec<Keyword> {
        let mut set = self.keywords.clone();
        for model in &self.models {
            for kw in &model.keywords {
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
}
