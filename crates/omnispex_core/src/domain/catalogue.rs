use super::unit::UnitProfile;
use super::weapon::WeaponProfile;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DataProvenance {
    pub edition: String,
    pub bsdata_repository: String,
    pub bsdata_revision: String,
    pub mfm_repository: String,
    pub mfm_version: String,
    pub mfm_revision: String,
    pub mfm_last_updated: String,
    pub imported_at_iso: String,
    pub attribution_notice: String,
    #[serde(default)]
    pub unresolved_references_count: usize,
    #[serde(default)]
    pub warnings: Vec<String>,
}

impl Default for DataProvenance {
    fn default() -> Self {
        Self {
            edition: "Warhammer 40,000 11th Edition".to_string(),
            bsdata_repository: "https://github.com/BSData/wh40k-11e".to_string(),
            bsdata_revision: "b4dc3f40ca39ae551e480228186e769344a36194".to_string(),
            mfm_repository: "https://github.com/BSData/wh40k-11e-mfm".to_string(),
            mfm_version: "1.6".to_string(),
            mfm_revision: "11c45c5f062d26d6468b8b2156c7a8e258013ef5".to_string(),
            mfm_last_updated: "2026-10-22".to_string(),
            imported_at_iso: "2026-10-26T00:00:00Z".to_string(),
            attribution_notice: "Community-maintained game data via BSData/wh40k-11e and points from the Munitorum Field Manual (© Games Workshop) via BSData/wh40k-11e-mfm. Unofficial and not affiliated with or endorsed by Games Workshop.".to_string(),
            unresolved_references_count: 0,
            warnings: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuleEntry {
    pub id: String,
    pub name: String,
    pub description: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EnhancementData {
    pub id: String,
    pub name: String,
    pub points: u32,
    #[serde(default)]
    pub is_upgrade: bool,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub leader_to: Vec<String>,
    #[serde(default)]
    pub support_to: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DetachmentData {
    pub id: String,
    pub name: String,
    pub dp_cost: u32,
    #[serde(default)]
    pub force_dispositions: Vec<String>,
    #[serde(default)]
    pub unique_tag: Option<String>,
    #[serde(default)]
    pub rules: Vec<RuleEntry>,
    #[serde(default)]
    pub enhancements: Vec<EnhancementData>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UnitCostOption {
    pub models: u32,
    pub points: u32,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub is_addon: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PricingTier {
    /// Interval string such as `"[1,)"`, `"[1,1]"`, `"[1,2]"`, `"[3,)"`.
    pub range: String,
    pub label: String,
    pub costs: Vec<UnitCostOption>,
}

impl PricingTier {
    /// Checks whether the 1-based copy index (e.g., 1st copy, 2nd copy, 3rd copy of this datasheet in a roster)
    /// falls within this pricing tier's `range` interval.
    pub fn matches_instance(&self, instance_number: usize) -> bool {
        let trimmed = self
            .range
            .trim()
            .trim_start_matches('[')
            .trim_end_matches(|c| c == ']' || c == ')');
        if let Some((start_str, end_str)) = trimmed.split_once(',') {
            let start = start_str.trim().parse::<usize>().unwrap_or(1);
            if instance_number < start {
                return false;
            }
            let end_clean = end_str.trim();
            if end_clean.is_empty() {
                return true;
            }
            if let Ok(end) = end_clean.parse::<usize>() {
                return instance_number <= end;
            }
        }
        true
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WargearCostOption {
    pub item: String,
    pub points: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DatasheetUnit {
    pub id: String,
    pub name: String,
    pub faction_id: String,
    pub faction_name: String,
    #[serde(default)]
    pub group_title: Option<String>,
    #[serde(default)]
    pub is_legends: bool,
    pub points_cost: Option<u32>,
    pub profile: UnitProfile,
    #[serde(default)]
    pub weapons: Vec<WeaponProfile>,
    #[serde(default)]
    pub abilities: Vec<String>,
    #[serde(default)]
    pub categories: Vec<String>,
    #[serde(default)]
    pub unit_composition: Vec<String>,
    #[serde(default)]
    pub wargear_options: Vec<String>,
    #[serde(default)]
    pub pricing_tiers: Vec<PricingTier>,
    #[serde(default)]
    pub wargear_costs: Vec<WargearCostOption>,
    #[serde(default)]
    pub leader_to: Vec<String>,
    #[serde(default)]
    pub support_to: Vec<String>,
    #[serde(default)]
    pub transport_capacity: Option<String>,
}

impl DatasheetUnit {
    pub fn base_points(&self) -> u32 {
        if let Some(first_tier) = self.pricing_tiers.first() {
            if let Some(first_cost) = first_tier.costs.first() {
                return first_cost.points;
            }
        }
        self.points_cost.unwrap_or(0)
    }

    pub fn points_for_instance_and_models(&self, instance_number: usize, models: u32) -> u32 {
        let tier = self
            .pricing_tiers
            .iter()
            .find(|t| t.matches_instance(instance_number))
            .or_else(|| self.pricing_tiers.last());

        if let Some(tier) = tier {
            // Find the smallest non-addon cost option with >= models, or fallback to largest
            let non_addons: Vec<&UnitCostOption> =
                tier.costs.iter().filter(|c| !c.is_addon).collect();
            if !non_addons.is_empty() {
                for opt in &non_addons {
                    if opt.models >= models {
                        return opt.points;
                    }
                }
                if let Some(last) = non_addons.last() {
                    return last.points;
                }
            }
            if let Some(first) = tier.costs.first() {
                return first.points;
            }
        }

        self.points_cost.unwrap_or(0)
    }

    pub fn available_model_counts(&self) -> Vec<UnitCostOption> {
        if let Some(first_tier) = self.pricing_tiers.first() {
            let non_addons: Vec<UnitCostOption> = first_tier
                .costs
                .iter()
                .filter(|c| !c.is_addon)
                .cloned()
                .collect();
            if !non_addons.is_empty() {
                return non_addons;
            }
        }
        let default_models = self.profile.total_models().max(1) as u32;
        vec![UnitCostOption {
            models: default_models,
            points: self.points_cost.unwrap_or(0),
            description: None,
            is_addon: false,
        }]
    }

    pub fn is_character(&self) -> bool {
        self.categories
            .iter()
            .any(|c| c.eq_ignore_ascii_case("Character"))
    }

    pub fn is_epic_hero(&self) -> bool {
        self.categories
            .iter()
            .any(|c| c.eq_ignore_ascii_case("Epic Hero"))
    }

    pub fn is_battleline(&self) -> bool {
        self.categories
            .iter()
            .any(|c| c.eq_ignore_ascii_case("Battleline"))
    }

    pub fn is_dedicated_transport(&self) -> bool {
        self.categories
            .iter()
            .any(|c| c.eq_ignore_ascii_case("Dedicated Transport"))
    }

    pub fn is_vehicle_or_monster(&self) -> bool {
        self.categories
            .iter()
            .any(|c| c.eq_ignore_ascii_case("Vehicle") || c.eq_ignore_ascii_case("Monster"))
    }

    pub fn is_infantry(&self) -> bool {
        self.categories
            .iter()
            .any(|c| c.eq_ignore_ascii_case("Infantry"))
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FactionCatalogue {
    pub id: String,
    #[serde(default)]
    pub slug: String,
    pub name: String,
    #[serde(default)]
    pub parent_faction: Option<String>,
    pub revision: Option<u32>,
    #[serde(default)]
    pub army_rules: Vec<RuleEntry>,
    #[serde(default)]
    pub detachments: Vec<DetachmentData>,
    #[serde(default)]
    pub units: Vec<DatasheetUnit>,
    #[serde(default)]
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct CatalogueDatabase {
    pub provenance: DataProvenance,
    pub factions: Vec<FactionCatalogue>,
}

impl CatalogueDatabase {
    pub fn find_faction(&self, faction_id_or_slug: &str) -> Option<&FactionCatalogue> {
        let q = faction_id_or_slug.trim();
        self.factions.iter().find(|f| {
            f.id.eq_ignore_ascii_case(q)
                || f.slug.eq_ignore_ascii_case(q)
                || f.name.eq_ignore_ascii_case(q)
        })
    }

    pub fn find_unit(&self, faction_id: Option<&str>, unit_id_or_name: &str) -> Option<&DatasheetUnit> {
        let q = unit_id_or_name.trim();
        if let Some(fid) = faction_id {
            if let Some(faction) = self.find_faction(fid) {
                if let Some(unit) = faction
                    .units
                    .iter()
                    .find(|u| u.id.eq_ignore_ascii_case(q) || u.name.eq_ignore_ascii_case(q))
                {
                    return Some(unit);
                }
            }
        }
        for faction in &self.factions {
            if let Some(unit) = faction
                .units
                .iter()
                .find(|u| u.id.eq_ignore_ascii_case(q) || u.name.eq_ignore_ascii_case(q))
            {
                return Some(unit);
            }
        }
        None
    }

    pub fn search_units(
        &self,
        query: &str,
        faction_filter: Option<&str>,
        category_filter: Option<&str>,
        include_legends: bool,
    ) -> Vec<DatasheetUnit> {
        let q = query.trim().to_lowercase();
        let mut results = Vec::new();

        for faction in &self.factions {
            if let Some(ff) = faction_filter {
                let ff_clean = ff.trim();
                if !ff_clean.is_empty()
                    && !ff_clean.eq_ignore_ascii_case("All Factions")
                    && !faction.id.eq_ignore_ascii_case(ff_clean)
                    && !faction.slug.eq_ignore_ascii_case(ff_clean)
                    && !faction.name.eq_ignore_ascii_case(ff_clean)
                    && !faction
                        .name
                        .to_lowercase()
                        .contains(&ff_clean.to_lowercase())
                {
                    continue;
                }
            }

            for unit in &faction.units {
                if !include_legends && unit.is_legends {
                    continue;
                }

                if let Some(cat) = category_filter {
                    let cat_clean = cat.trim();
                    if !cat_clean.is_empty() && !cat_clean.eq_ignore_ascii_case("All Types") {
                        let matched = match cat_clean {
                            "Infantry" => unit.is_infantry(),
                            "Vehicle / Monster" | "Vehicle" | "Monster" => {
                                unit.is_vehicle_or_monster()
                            }
                            "Character" => unit.is_character(),
                            "Battleline" => unit.is_battleline(),
                            "Dedicated Transport" => unit.is_dedicated_transport(),
                            "Epic Hero" => unit.is_epic_hero(),
                            other => unit
                                .categories
                                .iter()
                                .any(|c| c.eq_ignore_ascii_case(other)),
                        };
                        if !matched {
                            continue;
                        }
                    }
                }

                if q.is_empty() {
                    results.push(unit.clone());
                    continue;
                }

                let matches_name = unit.name.to_lowercase().contains(&q);
                let matches_faction = unit.faction_name.to_lowercase().contains(&q);
                let matches_category = unit
                    .categories
                    .iter()
                    .any(|c| c.to_lowercase().contains(&q));
                let matches_weapon = unit
                    .weapons
                    .iter()
                    .any(|w| w.name.to_lowercase().contains(&q));
                let matches_ability = unit
                    .abilities
                    .iter()
                    .any(|a| a.to_lowercase().contains(&q));

                if matches_name
                    || matches_faction
                    || matches_category
                    || matches_weapon
                    || matches_ability
                {
                    results.push(unit.clone());
                }
            }
        }

        results
    }
}

