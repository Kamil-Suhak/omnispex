use crate::domain::dice::ValueExpr;
use crate::domain::unit::{DefensiveAbility, ModelProfile, UnitProfile};
use crate::domain::weapon::{parse_weapon_ability, Keyword, WeaponAbility, WeaponProfile};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::str::FromStr;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CatalogueUnit {
    pub id: String,
    pub name: String,
    pub faction: String,
    pub points_cost: Option<u32>,
    pub profile: UnitProfile,
    pub weapons: Vec<WeaponProfile>,
    pub abilities: Vec<String>,
    pub categories: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CatalogueFaction {
    pub id: String,
    pub name: String,
    pub revision: Option<u32>,
    pub units: Vec<CatalogueUnit>,
}

pub struct BsDataParser;

impl BsDataParser {
    pub fn parse_catalogue_json(json_str: &str) -> Result<CatalogueFaction, String> {
        let value: serde_json::Value =
            serde_json::from_str(json_str).map_err(|e| format!("Invalid JSON: {}", e))?;

        let catalogue = value
            .get("catalogue")
            .ok_or_else(|| "Missing root 'catalogue' key".to_string())?;

        let faction_id = catalogue
            .get("id")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown-faction")
            .to_string();

        let faction_name = catalogue
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown Faction")
            .to_string();

        let revision = catalogue
            .get("revision")
            .and_then(|v| v.as_u64())
            .map(|r| r as u32);

        let mut units = Vec::new();

        // 1. Process sharedSelectionEntries
        if let Some(shared_entries) = catalogue.get("sharedSelectionEntries").and_then(|v| v.as_array()) {
            for entry in shared_entries {
                if let Some(unit) = Self::parse_unit_entry(entry, &faction_name) {
                    units.push(unit);
                }
            }
        }

        // 2. Process root selectionEntries
        if let Some(root_entries) = catalogue.get("selectionEntries").and_then(|v| v.as_array()) {
            for entry in root_entries {
                if let Some(unit) = Self::parse_unit_entry(entry, &faction_name) {
                    if !units.iter().any(|u| u.name == unit.name) {
                        units.push(unit);
                    }
                }
            }
        }

        Ok(CatalogueFaction {
            id: faction_id,
            name: faction_name,
            revision,
            units,
        })
    }

    fn parse_unit_entry(entry: &serde_json::Value, faction: &str) -> Option<CatalogueUnit> {
        let entry_type = entry.get("type").and_then(|v| v.as_str()).unwrap_or("");
        if entry_type == "upgrade" {
            return None;
        }

        let name = entry.get("name").and_then(|v| v.as_str())?.trim().to_string();
        let id = entry.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();

        // Find Unit Profile
        let profiles = entry.get("profiles").and_then(|v| v.as_array());
        let unit_profile_json = profiles.and_then(|arr| {
            arr.iter()
                .find(|p| p.get("typeName").and_then(|v| v.as_str()) == Some("Unit"))
        });

        // If no direct unit profile, search recursively in entry
        let unit_profile_json = unit_profile_json.or_else(|| {
            Self::find_first_profile_by_type(entry, "Unit")
        })?;

        // Extract Characteristics
        let char_map = Self::extract_characteristics(unit_profile_json);

        let toughness = char_map
            .get("T")
            .and_then(|s| s.parse::<u32>().ok())
            .unwrap_or(4);

        let save_raw = char_map.get("Sv").map(|s| s.as_str()).unwrap_or("3+");
        let save = save_raw
            .trim_end_matches('+')
            .parse::<u32>()
            .unwrap_or(3);

        let wounds = char_map
            .get("W")
            .and_then(|s| s.parse::<u32>().ok())
            .unwrap_or(2);

        let invuln_raw = char_map.get("InSv").map(|s| s.as_str()).unwrap_or("");
        let mut invuln = if !invuln_raw.trim().is_empty() && invuln_raw != "-" {
            invuln_raw.trim_end_matches('+').parse::<u32>().ok()
        } else {
            None
        };

        // Extract Categories / Keywords
        let mut categories = Vec::new();
        if let Some(cat_links) = entry.get("categoryLinks").and_then(|v| v.as_array()) {
            for c in cat_links {
                if let Some(cname) = c.get("name").and_then(|v| v.as_str()) {
                    categories.push(cname.trim().to_string());
                }
            }
        }

        let mut keywords: Vec<Keyword> = categories.iter().map(|s| Keyword::from(s.as_str())).collect();
        if !keywords.iter().any(|k| k.matches(&Keyword::from(faction))) {
            keywords.push(Keyword::from(faction));
        }

        // Extract Points Cost
        let mut points_cost = None;
        if let Some(costs) = entry.get("costs").and_then(|v| v.as_array()) {
            for c in costs {
                if c.get("name").and_then(|v| v.as_str()) == Some("pts") {
                    points_cost = c.get("value").and_then(|v| v.as_u64()).map(|p| p as u32);
                }
            }
        }

        // Extract Abilities and perform Pattern Matching for Defensive Buffs
        let mut abilities_text = Vec::new();
        let mut defensive_rules = Vec::new();
        let mut feel_no_pain = None;

        Self::extract_abilities_recursive(entry, &mut abilities_text);

        for ab_text in &abilities_text {
            let (rules, fnp_opt, inv_opt) = Self::match_defensive_rules(ab_text);
            defensive_rules.extend(rules);
            if feel_no_pain.is_none() && fnp_opt.is_some() {
                feel_no_pain = fnp_opt;
            }
            if invuln.is_none() && inv_opt.is_some() {
                invuln = inv_opt;
            }
        }

        // Check if Stealth is in categories or rules
        if categories.iter().any(|c| c.eq_ignore_ascii_case("Stealth")) {
            if !defensive_rules.contains(&DefensiveAbility::Stealth) {
                defensive_rules.push(DefensiveAbility::Stealth);
            }
        }

        // Extract Weapons
        let mut weapons = Vec::new();
        Self::extract_weapons_recursive(entry, &mut weapons);

        let model = ModelProfile::new(
            name.clone(),
            wounds,
            save,
            invuln,
            feel_no_pain,
        )
        .with_keywords(keywords.clone());

        let mut unit_profile = UnitProfile::uniform(
            name.clone(),
            toughness,
            model,
            1,
            keywords,
        );
        unit_profile.defensive_abilities = defensive_rules;

        Some(CatalogueUnit {
            id,
            name,
            faction: faction.to_string(),
            points_cost,
            profile: unit_profile,
            weapons,
            abilities: abilities_text,
            categories,
        })
    }

    fn extract_characteristics(profile: &serde_json::Value) -> std::collections::HashMap<String, String> {
        let mut map = std::collections::HashMap::new();
        if let Some(chars) = profile.get("characteristics").and_then(|v| v.as_array()) {
            for c in chars {
                if let (Some(k), Some(v)) = (
                    c.get("name").and_then(|v| v.as_str()),
                    c.get("$text").and_then(|v| v.as_str()),
                ) {
                    map.insert(k.to_string(), v.to_string());
                }
            }
        }
        map
    }

    fn find_first_profile_by_type<'a>(
        val: &'a serde_json::Value,
        type_name: &str,
    ) -> Option<&'a serde_json::Value> {
        if let Some(obj) = val.as_object() {
            if obj.get("typeName").and_then(|v| v.as_str()) == Some(type_name) {
                return Some(val);
            }
            for v in obj.values() {
                if let Some(found) = Self::find_first_profile_by_type(v, type_name) {
                    return Some(found);
                }
            }
        } else if let Some(arr) = val.as_array() {
            for item in arr {
                if let Some(found) = Self::find_first_profile_by_type(item, type_name) {
                    return Some(found);
                }
            }
        }
        None
    }

    fn extract_abilities_recursive(val: &serde_json::Value, list: &mut Vec<String>) {
        if let Some(obj) = val.as_object() {
            if obj.get("typeName").and_then(|v| v.as_str()) == Some("Abilities") {
                let name = obj.get("name").and_then(|v| v.as_str()).unwrap_or("");
                let chars = Self::extract_characteristics(val);
                let desc = chars.get("Description").map(|s| s.as_str()).unwrap_or("");
                let full = if desc.is_empty() {
                    name.to_string()
                } else {
                    format!("{}: {}", name, desc)
                };
                if !list.contains(&full) {
                    list.push(full);
                }
            }
            for v in obj.values() {
                Self::extract_abilities_recursive(v, list);
            }
        } else if let Some(arr) = val.as_array() {
            for item in arr {
                Self::extract_abilities_recursive(item, list);
            }
        }
    }

    fn match_defensive_rules(
        text: &str,
    ) -> (Vec<DefensiveAbility>, Option<u32>, Option<u32>) {
        let mut rules = Vec::new();
        let mut fnp = None;
        let mut inv = None;

        let lower = text.to_lowercase();

        // -1 AP
        if lower.contains("worsen the armour penetration") || lower.contains("worsen the armor penetration") {
            rules.push(DefensiveAbility::MinusOneAp);
        }

        // -1 Damage
        if lower.contains("subtract 1 from the damage characteristic") {
            rules.push(DefensiveAbility::DamageReduction(1));
        }

        // Half Damage
        if lower.contains("halve the damage characteristic") {
            rules.push(DefensiveAbility::HalfDamage);
        }

        // Stealth / -1 to Hit
        if lower.contains("stealth") || lower.contains("subtract 1 from the hit roll") {
            rules.push(DefensiveAbility::Stealth);
        }

        // -1 to Wound
        if lower.contains("subtract 1 from the wound roll") {
            rules.push(DefensiveAbility::MinusOneToWound);
        }

        // Feel No Pain X+
        let fnp_re = Regex::new(r"(?i)(?:feel no pain|fnp)\s*(\d)\+").unwrap();
        if let Some(caps) = fnp_re.captures(text) {
            if let Ok(val) = caps[1].parse::<u32>() {
                fnp = Some(val);
                rules.push(DefensiveAbility::FeelNoPain(val));
            }
        }

        // Invulnerable Save X+
        let inv_re = Regex::new(r"(?i)(\d)\+\s+invulnerable save").unwrap();
        if let Some(caps) = inv_re.captures(text) {
            if let Ok(val) = caps[1].parse::<u32>() {
                inv = Some(val);
                rules.push(DefensiveAbility::InvulnerableSave(val));
            }
        }

        (rules, fnp, inv)
    }

    fn extract_weapons_recursive(val: &serde_json::Value, list: &mut Vec<WeaponProfile>) {
        if let Some(obj) = val.as_object() {
            let type_name = obj.get("typeName").and_then(|v| v.as_str()).unwrap_or("");
            if type_name == "Ranged Weapons" || type_name == "Melee Weapons" {
                if let Some(weapon) = Self::parse_weapon_profile(val, type_name == "Melee Weapons") {
                    if !list.iter().any(|w| w.name == weapon.name) {
                        list.push(weapon);
                    }
                }
            }
            for v in obj.values() {
                Self::extract_weapons_recursive(v, list);
            }
        } else if let Some(arr) = val.as_array() {
            for item in arr {
                Self::extract_weapons_recursive(item, list);
            }
        }
    }

    fn parse_weapon_profile(profile_json: &serde_json::Value, is_melee: bool) -> Option<WeaponProfile> {
        let name = profile_json.get("name").and_then(|v| v.as_str())?.trim().to_string();
        let chars = Self::extract_characteristics(profile_json);

        let range_raw = chars.get("Range").map(|s| s.as_str()).unwrap_or(if is_melee { "0" } else { "24\"" });
        let range = if is_melee || range_raw.eq_ignore_ascii_case("Melee") || range_raw == "-" {
            0
        } else {
            range_raw.trim_end_matches('"').parse::<u32>().unwrap_or(24)
        };

        let attacks_raw = chars.get("A").map(|s| s.as_str()).unwrap_or("1");
        let attacks = ValueExpr::from_str(attacks_raw).unwrap_or(ValueExpr::Flat(1));

        let skill_key = if is_melee { "WS" } else { "BS" };
        let skill_raw = chars.get(skill_key).or_else(|| chars.get("BS")).or_else(|| chars.get("WS")).map(|s| s.as_str()).unwrap_or("3+");
        let (skill, is_torrent) = if skill_raw == "N/A" || skill_raw == "-" {
            (7, true)
        } else {
            (skill_raw.trim_end_matches('+').parse::<u32>().unwrap_or(3), false)
        };

        let s_raw = chars.get("S").map(|s| s.as_str()).unwrap_or("4");
        let strength = s_raw.parse::<u32>().unwrap_or(4);

        let ap_raw = chars.get("AP").map(|s| s.as_str()).unwrap_or("0");
        let ap = ap_raw.trim_start_matches('-').parse::<u32>().unwrap_or(0);

        let d_raw = chars.get("D").map(|s| s.as_str()).unwrap_or("1");
        let damage = ValueExpr::from_str(d_raw).unwrap_or(ValueExpr::Flat(1));

        let mut abilities = Vec::new();
        if is_torrent {
            abilities.push(WeaponAbility::Torrent);
        }

        if let Some(kw_str) = chars.get("Keywords") {
            for t in kw_str.split(|c| c == ',' || c == ';') {
                if let Some(ab) = parse_weapon_ability(t) {
                    if !abilities.contains(&ab) {
                        abilities.push(ab);
                    }
                }
            }
        }

        Some(WeaponProfile::new(
            name, range, attacks, skill, strength, ap, damage, abilities,
        ))
    }
}
