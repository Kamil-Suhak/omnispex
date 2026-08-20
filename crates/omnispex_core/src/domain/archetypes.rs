use super::unit::{ModelProfile, UnitProfile};
use super::weapon::Keyword;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ArchetypeEntry {
    pub id: String,
    pub label: String,
    pub description: String,
    pub target: UnitProfile,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ArchetypeRoster {
    pub archetypes: Vec<ArchetypeEntry>,
}

impl Default for ArchetypeRoster {
    fn default() -> Self {
        Self {
            archetypes: vec![
                ArchetypeEntry {
                    id: "geq".to_string(),
                    label: "Chaff / Light Infantry (GEQ)".to_string(),
                    description: "T3 Sv 5+ 1W (e.g. Guardsmen, Cultists, Hormagaunts)".to_string(),
                    target: UnitProfile::uniform(
                        "Guardsmen Squad",
                        3,
                        ModelProfile::new("Guardsman", 1, 5, None, None),
                        10,
                        vec![Keyword::Infantry],
                    ),
                },
                ArchetypeEntry {
                    id: "meq".to_string(),
                    label: "Standard Marine (MEQ)".to_string(),
                    description: "T4 Sv 3+ 2W (e.g. Intercessors, Legionaries)".to_string(),
                    target: UnitProfile::uniform(
                        "Intercessor Squad",
                        4,
                        ModelProfile::new("Space Marine", 2, 3, None, None),
                        5,
                        vec![Keyword::Infantry],
                    ),
                },
                ArchetypeEntry {
                    id: "teq".to_string(),
                    label: "Heavy Infantry / Elite (TEQ)".to_string(),
                    description: "T5 Sv 2+ 4++ 3W (e.g. Terminators, Custodes)".to_string(),
                    target: UnitProfile::uniform(
                        "Terminator Squad",
                        5,
                        ModelProfile::new("Terminator", 3, 2, Some(4), None),
                        5,
                        vec![Keyword::Infantry],
                    ),
                },
                ArchetypeEntry {
                    id: "transport".to_string(),
                    label: "Light Transport / Skimmer".to_string(),
                    description: "T9 Sv 3+ 10W (e.g. Rhino, Raider, Trukk)".to_string(),
                    target: UnitProfile::uniform(
                        "Rhino",
                        9,
                        ModelProfile::new("Rhino", 10, 3, None, None),
                        1,
                        vec![Keyword::Vehicle],
                    ),
                },
                ArchetypeEntry {
                    id: "heavy_armor".to_string(),
                    label: "Heavy Armor / Monster".to_string(),
                    description: "T12 Sv 2+ 16W (e.g. Leman Russ, Land Raider, Knight)".to_string(),
                    target: UnitProfile::uniform(
                        "Leman Russ Tank",
                        12,
                        ModelProfile::new("Leman Russ", 16, 2, None, None),
                        1,
                        vec![Keyword::Vehicle],
                    ),
                },
            ],
        }
    }
}

impl ArchetypeRoster {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn get(&self, id: &str) -> Option<&ArchetypeEntry> {
        self.archetypes.iter().find(|a| a.id == id)
    }

    pub fn get_mut(&mut self, id: &str) -> Option<&mut ArchetypeEntry> {
        self.archetypes.iter_mut().find(|a| a.id == id)
    }

    pub fn update_entry(&mut self, entry: ArchetypeEntry) {
        if let Some(existing) = self.archetypes.iter_mut().find(|a| a.id == entry.id) {
            *existing = entry;
        } else {
            self.archetypes.push(entry);
        }
    }

    pub fn reset_defaults(&mut self) {
        *self = Self::default();
    }
}
