use crate::domain::archetypes::ArchetypeRoster;
use crate::domain::army_list::ArmyList;
use crate::domain::matches::{MatchRecord, MatchResult};
use crate::domain::unit::UnitProfile;
use crate::domain::weapon::{WeaponLoadoutEntry, WeaponProfile};
use crate::domain::wishlist::WishlistItem;
use crate::engine::context::CombatContext;
use serde::{Deserialize, Serialize};

pub const CURRENT_PERSONAL_SCHEMA_VERSION: u32 = 2;

fn default_iterations() -> u32 {
    10_000
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SavedCalculationConfig {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub attacker_unit_name: String,
    #[serde(default)]
    pub weapon: WeaponProfile,
    #[serde(default)]
    pub squad_loadout: Vec<WeaponLoadoutEntry>,
    pub target: UnitProfile,
    #[serde(default)]
    pub context: CombatContext,
    #[serde(default = "default_iterations")]
    pub iterations: u32,
    #[serde(default)]
    pub created_at: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UserSettings {
    #[serde(default = "default_iterations")]
    pub default_iterations: u32,
    #[serde(default = "default_true")]
    pub show_exact_stage_math: bool,
    #[serde(default)]
    pub preferred_faction_id: Option<String>,
    #[serde(default)]
    pub player_name: String,
}

impl Default for UserSettings {
    fn default() -> Self {
        Self {
            default_iterations: 10_000,
            show_exact_stage_math: true,
            preferred_faction_id: None,
            player_name: String::new(),
        }
    }
}

/// Complete personal data store with schema versioning and migration support.
/// Kept strictly separate from game catalogues so catalogue refreshes never touch personal data.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PersonalDataStore {
    #[serde(default)]
    pub schema_version: u32,
    #[serde(default)]
    pub army_lists: Vec<ArmyList>,
    #[serde(default)]
    pub wishlist_items: Vec<WishlistItem>,
    #[serde(default)]
    pub matches: Vec<MatchRecord>,
    #[serde(default)]
    pub saved_calculations: Vec<SavedCalculationConfig>,
    #[serde(default)]
    pub custom_archetypes: ArchetypeRoster,
    #[serde(default)]
    pub settings: UserSettings,
}

impl Default for PersonalDataStore {
    fn default() -> Self {
        Self {
            schema_version: CURRENT_PERSONAL_SCHEMA_VERSION,
            army_lists: Vec::new(),
            wishlist_items: Vec::new(),
            matches: Vec::new(),
            saved_calculations: Vec::new(),
            custom_archetypes: ArchetypeRoster::default(),
            settings: UserSettings::default(),
        }
    }
}

impl PersonalDataStore {
    pub fn new() -> Self {
        Self::default()
    }

    /// Loads and automatically migrates a `PersonalDataStore` from JSON string.
    pub fn from_json_migrated(json_str: &str) -> Result<Self, String> {
        if json_str.trim().is_empty() {
            return Ok(Self::default());
        }
        let mut store: PersonalDataStore = serde_json::from_str(json_str)
            .map_err(|e| format!("Failed to deserialize personal data store: {}", e))?;
        store.migrate();
        Ok(store)
    }

    /// Runs idempotent schema migrations from older schema versions up to `CURRENT_PERSONAL_SCHEMA_VERSION`.
    pub fn migrate(&mut self) {
        if self.schema_version < 1 {
            if self.custom_archetypes.archetypes.is_empty() {
                self.custom_archetypes = ArchetypeRoster::default();
            }
            if self.settings.default_iterations < 100 {
                self.settings.default_iterations = 10_000;
            }
            self.schema_version = 1;
        }

        if self.schema_version < 2 {
            for (idx, list) in self.army_lists.iter_mut().enumerate() {
                if list.id.trim().is_empty() {
                    list.id = format!("list-migrated-{}", idx + 1);
                }
            }
            for (idx, item) in self.wishlist_items.iter_mut().enumerate() {
                if item.id.trim().is_empty() {
                    item.id = format!("wish-migrated-{}", idx + 1);
                }
                if item.quantity_desired == 0 {
                    item.quantity_desired = 1;
                }
            }
            for (idx, m) in self.matches.iter_mut().enumerate() {
                if m.id.trim().is_empty() {
                    m.id = format!("match-migrated-{}", idx + 1);
                }
                if m.result != MatchResult::InProgress {
                    m.result = MatchResult::from_scores(m.player_score, m.opponent_score);
                }
            }
            self.schema_version = CURRENT_PERSONAL_SCHEMA_VERSION;
        }
    }

    /// Exports personal data as formatted JSON for user backup.
    pub fn export_backup_json(&self) -> Result<String, String> {
        serde_json::to_string_pretty(self)
            .map_err(|e| format!("Failed to serialize backup JSON: {}", e))
    }

    /// Merges or restores personal data from a backup JSON string safely.
    pub fn restore_from_backup_json(&mut self, json_str: &str, merge: bool) -> Result<(), String> {
        let incoming = Self::from_json_migrated(json_str)?;
        if !merge {
            *self = incoming;
            return Ok(());
        }

        for list in incoming.army_lists {
            if let Some(existing) = self.army_lists.iter_mut().find(|l| l.id == list.id) {
                *existing = list;
            } else {
                self.army_lists.push(list);
            }
        }

        for wish in incoming.wishlist_items {
            crate::domain::wishlist::upsert_wishlist_item(&mut self.wishlist_items, wish);
        }

        for m in incoming.matches {
            if let Some(existing) = self.matches.iter_mut().find(|x| x.id == m.id) {
                *existing = m;
            } else {
                self.matches.push(m);
            }
        }

        for calc in incoming.saved_calculations {
            if let Some(existing) = self.saved_calculations.iter_mut().find(|c| c.id == calc.id) {
                *existing = calc;
            } else {
                self.saved_calculations.push(calc);
            }
        }

        Ok(())
    }
}
