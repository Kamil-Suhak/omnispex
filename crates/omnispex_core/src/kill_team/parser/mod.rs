use crate::kill_team::domain::catalogue::{
    parse_kt_weapon_rule, KillTeamFaction, KtAbilityData, KtWeaponProfile, KtWeaponType,
    OperativeDatacard,
};
use std::collections::HashMap;

pub struct KtBsDataParser;

impl KtBsDataParser {
    /// Parses a Kill Team BSData catalogue JSON document into a validated `KillTeamFaction`.
    pub fn parse_kt_catalogue_json(raw_json: &str) -> Result<KillTeamFaction, String> {
        let root: serde_json::Value =
            serde_json::from_str(raw_json).map_err(|e| format!("Invalid KT BSData JSON: {}", e))?;
        let cat = root
            .get("catalogue")
            .ok_or_else(|| "Missing 'catalogue' root key in KT BSData JSON".to_string())?;

        let id = cat
            .get("id")
            .and_then(|v| v.as_str())
            .unwrap_or("kt-custom")
            .to_string();
        let raw_name = cat
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("Kill Team")
            .trim();

        let (superfaction, name) = if let Some((sf, rest)) = raw_name.split_once(" - ") {
            (sf.trim().to_string(), rest.trim().to_string())
        } else {
            ("Kill Team".to_string(), raw_name.to_string())
        };

        let slug = name
            .to_lowercase()
            .chars()
            .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
            .collect::<String>()
            .split('-')
            .filter(|s| !s.is_empty())
            .collect::<Vec<_>>()
            .join("-");

        let mut operatives = Vec::new();

        for section_key in ["sharedSelectionEntries", "selectionEntries"] {
            if let Some(entries) = cat.get(section_key).and_then(|v| v.as_array()) {
                for entry in entries {
                    if let Some(op) = Self::parse_operative_entry(entry, &id, &name) {
                        if !operatives
                            .iter()
                            .any(|existing: &OperativeDatacard| existing.name == op.name)
                        {
                            operatives.push(op);
                        }
                    }
                }
            }
        }

        let team_size = if operatives.len() >= 10 { 10 } else { 6 };

        Ok(KillTeamFaction {
            id,
            slug,
            name,
            superfaction,
            archetypes: vec!["Seek & Destroy".to_string(), "Security".to_string()],
            faction_rules: Vec::new(),
            team_size,
            min_team_size: team_size,
            max_team_size: team_size,
            operatives,
            ploys: Vec::new(),
            equipment: Vec::new(),
        })
    }

    fn parse_operative_entry(
        entry: &serde_json::Value,
        faction_id: &str,
        faction_name: &str,
    ) -> Option<OperativeDatacard> {
        let entry_type = entry.get("type").and_then(|v| v.as_str()).unwrap_or("");
        if entry_type == "upgrade" {
            return None;
        }
        let name = entry.get("name").and_then(|v| v.as_str())?.trim().to_string();
        if name.is_empty() {
            return None;
        }
        let id = entry
            .get("id")
            .and_then(|v| v.as_str())
            .unwrap_or(&name)
            .to_string();

        let profiles = entry.get("profiles").and_then(|v| v.as_array())?;
        let op_prof = profiles.iter().find(|p| {
            let tn = p.get("typeName").and_then(|v| v.as_str()).unwrap_or("");
            tn.eq_ignore_ascii_case("Operative") || tn.eq_ignore_ascii_case("Unit")
        })?;

        let chars = Self::extract_chars(op_prof);
        let apl = chars
            .get("APL")
            .and_then(|s| s.trim().parse::<u32>().ok())
            .unwrap_or(2);
        let movement = chars
            .get("Move")
            .or_else(|| chars.get("M"))
            .and_then(|s| {
                s.trim()
                    .trim_end_matches('"')
                    .trim()
                    .parse::<u32>()
                    .ok()
            })
            .unwrap_or(6);
        let save = chars
            .get("Save")
            .or_else(|| chars.get("SV"))
            .or_else(|| chars.get("Sv"))
            .and_then(|s| s.trim().trim_end_matches('+').parse::<u32>().ok())
            .unwrap_or(4);
        let wounds = chars
            .get("Wounds")
            .or_else(|| chars.get("W"))
            .and_then(|s| s.trim().parse::<u32>().ok())
            .unwrap_or(8);

        let mut keywords = Vec::new();
        if let Some(clinks) = entry.get("categoryLinks").and_then(|v| v.as_array()) {
            for cl in clinks {
                if let Some(cname) = cl.get("name").and_then(|v| v.as_str()) {
                    let clean = cname.trim().to_uppercase();
                    if !clean.is_empty() && !keywords.contains(&clean) {
                        keywords.push(clean);
                    }
                }
            }
        }

        let is_leader = name.to_lowercase().contains("leader")
            || name.to_lowercase().contains("sergeant")
            || name.to_lowercase().contains("nob")
            || keywords.iter().any(|k| k == "LEADER");
        let is_warrior = name.to_lowercase().contains("warrior")
            || name.to_lowercase().contains("trooper")
            || name.to_lowercase().contains("boy");

        let role = if is_leader {
            "Leader".to_string()
        } else if is_warrior {
            "Warrior".to_string()
        } else {
            "Specialist".to_string()
        };

        let max_per_kill_team = if is_warrior && !is_leader { 6 } else { 1 };

        let mut weapons = Vec::new();
        Self::collect_weapons(entry, &mut weapons);

        let mut abilities = Vec::new();
        for p in profiles {
            let tn = p.get("typeName").and_then(|v| v.as_str()).unwrap_or("");
            if tn.eq_ignore_ascii_case("Abilities") || tn.eq_ignore_ascii_case("Unique Actions") {
                let aname = p
                    .get("name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("Ability")
                    .to_string();
                let achars = Self::extract_chars(p);
                let desc = achars
                    .get("Description")
                    .or_else(|| achars.get("Ability"))
                    .cloned()
                    .unwrap_or_default();
                abilities.push(KtAbilityData {
                    name: aname,
                    description: desc,
                });
            }
        }

        Some(OperativeDatacard {
            id,
            name,
            faction_id: faction_id.to_string(),
            faction_name: faction_name.to_string(),
            role,
            apl,
            movement,
            save,
            wounds,
            weapons,
            abilities,
            keywords,
            max_per_kill_team,
        })
    }

    fn collect_weapons(val: &serde_json::Value, out: &mut Vec<KtWeaponProfile>) {
        if let Some(obj) = val.as_object() {
            let tn = obj.get("typeName").and_then(|v| v.as_str()).unwrap_or("");
            if tn.eq_ignore_ascii_case("Weapons")
                || tn.eq_ignore_ascii_case("Ranged Weapons")
                || tn.eq_ignore_ascii_case("Melee Weapons")
            {
                if let Some(w) = Self::parse_weapon_profile(val, tn) {
                    if !out.iter().any(|existing| existing.name == w.name) {
                        out.push(w);
                    }
                }
            }
            for v in obj.values() {
                Self::collect_weapons(v, out);
            }
        } else if let Some(arr) = val.as_array() {
            for item in arr {
                Self::collect_weapons(item, out);
            }
        }
    }

    fn parse_weapon_profile(val: &serde_json::Value, type_name: &str) -> Option<KtWeaponProfile> {
        let raw_name = val.get("name").and_then(|v| v.as_str())?.trim();
        if raw_name.is_empty() {
            return None;
        }
        let chars = Self::extract_chars(val);
        let atk = chars
            .get("ATK")
            .or_else(|| chars.get("A"))
            .and_then(|s| s.trim().parse::<u32>().ok())
            .unwrap_or(4);
        let hit = chars
            .get("HIT")
            .or_else(|| chars.get("BS/WS"))
            .or_else(|| chars.get("BS"))
            .or_else(|| chars.get("WS"))
            .and_then(|s| s.trim().trim_end_matches('+').parse::<u32>().ok())
            .unwrap_or(4);

        let dmg_raw = chars
            .get("DMG")
            .or_else(|| chars.get("D"))
            .map(|s| s.as_str())
            .unwrap_or("3/4");
        let (normal_damage, critical_damage) =
            if let Some((n_str, c_str)) = dmg_raw.split_once('/') {
                (
                    n_str.trim().parse::<u32>().unwrap_or(3),
                    c_str.trim().parse::<u32>().unwrap_or(4),
                )
            } else {
                let d = dmg_raw.trim().parse::<u32>().unwrap_or(3);
                (d, d + 1)
            };

        let wr_raw = chars
            .get("WR")
            .or_else(|| chars.get("SR"))
            .or_else(|| chars.get("Keywords"))
            .or_else(|| chars.get("!"))
            .map(|s| s.as_str())
            .unwrap_or("");
        let mut rules = Vec::new();
        for part in wr_raw.split(|c| c == ',' || c == ';') {
            if let Some(r) = parse_kt_weapon_rule(part) {
                rules.push(r);
            }
        }

        let is_melee = type_name.eq_ignore_ascii_case("Melee Weapons")
            || raw_name.starts_with('⚔')
            || rules
                .iter()
                .any(|r| matches!(r, crate::kill_team::KtWeaponRule::Brutal | crate::kill_team::KtWeaponRule::Shock));

        let clean_name = raw_name
            .trim_start_matches(|c: char| !c.is_ascii_alphanumeric())
            .trim()
            .to_string();

        Some(KtWeaponProfile {
            name: clean_name,
            weapon_type: if is_melee {
                KtWeaponType::Melee
            } else {
                KtWeaponType::Ranged
            },
            attacks: atk,
            hit,
            normal_damage,
            critical_damage,
            rules,
        })
    }

    fn extract_chars(profile: &serde_json::Value) -> HashMap<String, String> {
        let mut map = HashMap::new();
        if let Some(arr) = profile.get("characteristics").and_then(|v| v.as_array()) {
            for c in arr {
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
}
