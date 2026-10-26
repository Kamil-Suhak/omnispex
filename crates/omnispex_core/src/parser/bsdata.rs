use crate::domain::catalogue::{
    DatasheetUnit, DetachmentData, EnhancementData, FactionCatalogue, PricingTier, RuleEntry,
    UnitCostOption,
};
use crate::domain::dice::ValueExpr;
use crate::domain::unit::{DefensiveAbility, ModelProfile, UnitProfile};
use crate::domain::weapon::{parse_weapon_ability, Keyword, WeaponAbility, WeaponProfile};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
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

#[derive(Default)]
struct BsDataLookupIndex {
    entries_by_id: HashMap<String, serde_json::Value>,
    profiles_by_id: HashMap<String, serde_json::Value>,
    rules_by_id: HashMap<String, serde_json::Value>,
}

impl BsDataLookupIndex {
    fn index_catalogue(&mut self, catalogue: &serde_json::Value) {
        if let Some(arr) = catalogue
            .get("sharedSelectionEntries")
            .and_then(|v| v.as_array())
        {
            for item in arr {
                self.index_entry_recursive(item);
            }
        }
        if let Some(arr) = catalogue.get("selectionEntries").and_then(|v| v.as_array()) {
            for item in arr {
                self.index_entry_recursive(item);
            }
        }
        if let Some(arr) = catalogue
            .get("sharedSelectionEntryGroups")
            .and_then(|v| v.as_array())
        {
            for item in arr {
                self.index_entry_recursive(item);
            }
        }
        if let Some(arr) = catalogue.get("sharedProfiles").and_then(|v| v.as_array()) {
            for p in arr {
                if let Some(id) = p.get("id").and_then(|v| v.as_str()) {
                    self.profiles_by_id.insert(id.to_string(), p.clone());
                }
            }
        }
        if let Some(arr) = catalogue.get("sharedRules").and_then(|v| v.as_array()) {
            for r in arr {
                if let Some(id) = r.get("id").and_then(|v| v.as_str()) {
                    self.rules_by_id.insert(id.to_string(), r.clone());
                }
            }
        }
        if let Some(arr) = catalogue.get("rules").and_then(|v| v.as_array()) {
            for r in arr {
                if let Some(id) = r.get("id").and_then(|v| v.as_str()) {
                    self.rules_by_id.insert(id.to_string(), r.clone());
                }
            }
        }
    }

    fn index_entry_recursive(&mut self, val: &serde_json::Value) {
        if let Some(obj) = val.as_object() {
            if let Some(id) = obj.get("id").and_then(|v| v.as_str()) {
                self.entries_by_id
                    .entry(id.to_string())
                    .or_insert_with(|| val.clone());
            }
            if let Some(profiles) = obj.get("profiles").and_then(|v| v.as_array()) {
                for p in profiles {
                    if let Some(pid) = p.get("id").and_then(|v| v.as_str()) {
                        self.profiles_by_id
                            .entry(pid.to_string())
                            .or_insert_with(|| p.clone());
                    }
                }
            }
            for key in ["selectionEntries", "selectionEntryGroups"] {
                if let Some(arr) = obj.get(key).and_then(|v| v.as_array()) {
                    for child in arr {
                        self.index_entry_recursive(child);
                    }
                }
            }
        }
    }
}

pub struct BsDataParser;

impl BsDataParser {
    pub fn parse_catalogue_json(json_str: &str) -> Result<CatalogueFaction, String> {
        let value: serde_json::Value =
            serde_json::from_str(json_str).map_err(|e| format!("Invalid JSON: {}", e))?;
        let raw_name = value
            .get("catalogue")
            .and_then(|c| c.get("name"))
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown Faction")
            .to_string();

        let rich = Self::parse_rich_catalogue_with_libraries(&value, &[])?;
        let units = rich
            .units
            .into_iter()
            .map(|u| CatalogueUnit {
                id: u.id,
                name: u.name,
                faction: u.faction_name,
                points_cost: u.points_cost,
                profile: u.profile,
                weapons: u.weapons,
                abilities: u.abilities,
                categories: u.categories,
            })
            .collect();

        Ok(CatalogueFaction {
            id: rich.id,
            name: raw_name,
            revision: rich.revision,
            units,
        })
    }

    pub fn parse_rich_catalogue_json(json_str: &str) -> Result<FactionCatalogue, String> {
        let value: serde_json::Value =
            serde_json::from_str(json_str).map_err(|e| format!("Invalid JSON: {}", e))?;
        Self::parse_rich_catalogue_with_libraries(&value, &[])
    }

    pub fn parse_rich_catalogue_with_libraries(
        primary_root: &serde_json::Value,
        library_roots: &[&serde_json::Value],
    ) -> Result<FactionCatalogue, String> {
        let catalogue = primary_root
            .get("catalogue")
            .ok_or_else(|| "Missing root 'catalogue' key".to_string())?;

        let faction_id = catalogue
            .get("id")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown-faction")
            .to_string();

        let raw_faction_name = catalogue
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown Faction")
            .to_string();

        let faction_name = clean_faction_display_name(&raw_faction_name);
        let slug = slugify_faction_name(&faction_name);

        let revision = catalogue
            .get("revision")
            .and_then(|v| v.as_u64())
            .map(|r| r as u32);

        let mut index = BsDataLookupIndex::default();
        for lib_root in library_roots {
            if let Some(lib_cat) = lib_root.get("catalogue") {
                index.index_catalogue(lib_cat);
            }
        }
        index.index_catalogue(catalogue);

        // Extract Army Rules
        let mut army_rules = Vec::new();
        for rule_arr_key in ["rules", "sharedRules"] {
            if let Some(rules) = catalogue.get(rule_arr_key).and_then(|v| v.as_array()) {
                for r in rules {
                    let hidden = r.get("hidden").and_then(|v| v.as_bool()).unwrap_or(false);
                    if hidden {
                        continue;
                    }
                    let name = r
                        .get("name")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .trim()
                        .to_string();
                    let desc = r
                        .get("description")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .trim()
                        .to_string();
                    let id = r
                        .get("id")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string();
                    if !name.is_empty()
                        && !desc.is_empty()
                        && !army_rules.iter().any(|existing: &RuleEntry| existing.name == name)
                    {
                        army_rules.push(RuleEntry {
                            id,
                            name,
                            description: desc,
                        });
                    }
                }
            }
        }

        // Extract Detachments & Enhancements
        let mut detachments = Vec::new();
        let mut standalone_enhancements = Vec::new();
        Self::extract_detachments_and_enhancements(
            catalogue,
            &index,
            &mut detachments,
            &mut standalone_enhancements,
        );
        for lib_root in library_roots {
            if let Some(lib_cat) = lib_root.get("catalogue") {
                Self::extract_detachments_and_enhancements(
                    lib_cat,
                    &index,
                    &mut detachments,
                    &mut standalone_enhancements,
                );
            }
        }

        if !standalone_enhancements.is_empty() {
            if detachments.is_empty() {
                detachments.push(DetachmentData {
                    id: format!("det-{}-default", slug),
                    name: "Index / Codex Detachment".to_string(),
                    dp_cost: 3,
                    force_dispositions: Vec::new(),
                    unique_tag: None,
                    rules: Vec::new(),
                    enhancements: standalone_enhancements,
                });
            } else {
                for enh in standalone_enhancements {
                    if !detachments
                        .iter()
                        .any(|d| d.enhancements.iter().any(|e| e.name == enh.name))
                    {
                        detachments[0].enhancements.push(enh);
                    }
                }
            }
        }

        let mut units: Vec<DatasheetUnit> = Vec::new();
        let mut seen_names: HashSet<String> = HashSet::new();

        if let Some(shared_entries) = catalogue
            .get("sharedSelectionEntries")
            .and_then(|v| v.as_array())
        {
            for entry in shared_entries {
                if let Some(unit) =
                    Self::parse_datasheet_unit(entry, None, &faction_id, &faction_name, &index)
                {
                    let key = unit.name.to_lowercase();
                    if seen_names.insert(key) {
                        units.push(unit);
                    }
                }
            }
        }

        if let Some(root_entries) = catalogue.get("selectionEntries").and_then(|v| v.as_array()) {
            for entry in root_entries {
                if let Some(unit) =
                    Self::parse_datasheet_unit(entry, None, &faction_id, &faction_name, &index)
                {
                    let key = unit.name.to_lowercase();
                    if seen_names.insert(key) {
                        units.push(unit);
                    }
                }
            }
        }

        if let Some(entry_links) = catalogue.get("entryLinks").and_then(|v| v.as_array()) {
            for link in entry_links {
                let target_id = match link.get("targetId").and_then(|v| v.as_str()) {
                    Some(tid) => tid,
                    None => continue,
                };
                if let Some(target_entry) = index.entries_by_id.get(target_id) {
                    if let Some(unit) = Self::parse_datasheet_unit(
                        target_entry,
                        Some(link),
                        &faction_id,
                        &faction_name,
                        &index,
                    ) {
                        let key = unit.name.to_lowercase();
                        if let Some(existing) =
                            units.iter_mut().find(|u| u.name.to_lowercase() == key)
                        {
                            for cat in unit.categories {
                                if !existing.categories.contains(&cat) {
                                    existing.categories.push(cat);
                                }
                            }
                            if existing.points_cost.is_none() && unit.points_cost.is_some() {
                                existing.points_cost = unit.points_cost;
                            }
                            if existing.pricing_tiers.is_empty() && !unit.pricing_tiers.is_empty() {
                                existing.pricing_tiers = unit.pricing_tiers;
                            }
                        } else {
                            seen_names.insert(key);
                            units.push(unit);
                        }
                    }
                }
            }
        }

        units.sort_by(|a, b| a.name.cmp(&b.name));

        Ok(FactionCatalogue {
            id: faction_id,
            slug,
            name: faction_name,
            parent_faction: None,
            revision,
            army_rules,
            detachments,
            units,
            warnings: Vec::new(),
        })
    }

    fn extract_detachments_and_enhancements(
        catalogue: &serde_json::Value,
        index: &BsDataLookupIndex,
        detachments: &mut Vec<DetachmentData>,
        standalone_enhancements: &mut Vec<EnhancementData>,
    ) {
        if let Some(groups) = catalogue
            .get("sharedSelectionEntryGroups")
            .and_then(|v| v.as_array())
        {
            for grp in groups {
                let gname = grp.get("name").and_then(|v| v.as_str()).unwrap_or("");
                if gname.eq_ignore_ascii_case("Detachment")
                    || gname.eq_ignore_ascii_case("Detachments")
                    || gname.eq_ignore_ascii_case("Detachment Choice")
                {
                    if let Some(entries) = grp.get("selectionEntries").and_then(|v| v.as_array()) {
                        for det_entry in entries {
                            let dname = det_entry
                                .get("name")
                                .and_then(|v| v.as_str())
                                .unwrap_or("")
                                .trim()
                                .to_string();
                            if dname.is_empty() {
                                continue;
                            }
                            let did = det_entry
                                .get("id")
                                .and_then(|v| v.as_str())
                                .unwrap_or("")
                                .to_string();

                            let mut det_rules = Vec::new();
                            if let Some(rules) = det_entry.get("rules").and_then(|v| v.as_array()) {
                                for r in rules {
                                    let rname = r
                                        .get("name")
                                        .and_then(|v| v.as_str())
                                        .unwrap_or("")
                                        .trim()
                                        .to_string();
                                    let rdesc = r
                                        .get("description")
                                        .and_then(|v| v.as_str())
                                        .unwrap_or("")
                                        .trim()
                                        .to_string();
                                    let rid = r
                                        .get("id")
                                        .and_then(|v| v.as_str())
                                        .unwrap_or("")
                                        .to_string();
                                    if !rname.is_empty() || !rdesc.is_empty() {
                                        det_rules.push(RuleEntry {
                                            id: rid,
                                            name: rname,
                                            description: rdesc,
                                        });
                                    }
                                }
                            }
                            if det_rules.is_empty() {
                                let mut abs = Vec::new();
                                let mut visited = HashSet::new();
                                Self::extract_abilities_with_index(
                                    det_entry,
                                    index,
                                    &mut abs,
                                    &mut visited,
                                    0,
                                );
                                for (idx, ab) in abs.into_iter().enumerate() {
                                    det_rules.push(RuleEntry {
                                        id: format!("{}-r{}", did, idx),
                                        name: dname.clone(),
                                        description: ab,
                                    });
                                }
                            }

                            if let Some(existing) = detachments
                                .iter_mut()
                                .find(|d| d.name.eq_ignore_ascii_case(&dname))
                            {
                                if existing.rules.is_empty() && !det_rules.is_empty() {
                                    existing.rules = det_rules;
                                }
                            } else {
                                detachments.push(DetachmentData {
                                    id: did,
                                    name: dname,
                                    dp_cost: 1,
                                    force_dispositions: Vec::new(),
                                    unique_tag: None,
                                    rules: det_rules,
                                    enhancements: Vec::new(),
                                });
                            }
                        }
                    }
                } else if gname.starts_with("Enhancement") {
                    let is_upgrade_group = gname.to_lowercase().contains("upgrade");
                    if let Some(entries) = grp.get("selectionEntries").and_then(|v| v.as_array()) {
                        for enh_entry in entries {
                            if let Some(enh) =
                                Self::parse_enhancement_entry(enh_entry, is_upgrade_group, index)
                            {
                                if !standalone_enhancements.iter().any(|e| e.name == enh.name) {
                                    standalone_enhancements.push(enh);
                                }
                            }
                        }
                    }
                    if let Some(subgroups) =
                        grp.get("selectionEntryGroups").and_then(|v| v.as_array())
                    {
                        for sub in subgroups {
                            if let Some(entries) =
                                sub.get("selectionEntries").and_then(|v| v.as_array())
                            {
                                for enh_entry in entries {
                                    if let Some(enh) = Self::parse_enhancement_entry(
                                        enh_entry,
                                        is_upgrade_group,
                                        index,
                                    ) {
                                        if !standalone_enhancements
                                            .iter()
                                            .any(|e| e.name == enh.name)
                                        {
                                            standalone_enhancements.push(enh);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    fn parse_enhancement_entry(
        entry: &serde_json::Value,
        is_upgrade_group: bool,
        index: &BsDataLookupIndex,
    ) -> Option<EnhancementData> {
        let raw_name = entry.get("name").and_then(|v| v.as_str())?.trim();
        if raw_name.is_empty() {
            return None;
        }
        let id = entry
            .get("id")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        let is_upgrade = is_upgrade_group || raw_name.contains("(Upgrade)");
        let name = if is_upgrade && !raw_name.contains("(Upgrade)") {
            format!("{} (Upgrade)", raw_name)
        } else {
            raw_name.to_string()
        };

        let mut points = 0u32;
        if let Some(costs) = entry.get("costs").and_then(|v| v.as_array()) {
            for c in costs {
                if c.get("name").and_then(|v| v.as_str()) == Some("pts") {
                    points = c
                        .get("value")
                        .and_then(|v| v.as_f64())
                        .map(|p| p.max(0.0) as u32)
                        .unwrap_or(0);
                }
            }
        }

        let mut abs = Vec::new();
        let mut visited = HashSet::new();
        Self::extract_abilities_with_index(entry, index, &mut abs, &mut visited, 0);
        let description = abs.join(" ");

        Some(EnhancementData {
            id,
            name,
            points,
            is_upgrade,
            description,
            leader_to: Vec::new(),
            support_to: Vec::new(),
        })
    }

    fn parse_datasheet_unit(
        entry: &serde_json::Value,
        entry_link: Option<&serde_json::Value>,
        faction_id: &str,
        faction_name: &str,
        index: &BsDataLookupIndex,
    ) -> Option<DatasheetUnit> {
        let entry_type = entry.get("type").and_then(|v| v.as_str()).unwrap_or("");
        if entry_type == "upgrade" {
            return None;
        }

        let raw_name = entry_link
            .and_then(|l| l.get("name").and_then(|v| v.as_str()))
            .or_else(|| entry.get("name").and_then(|v| v.as_str()))?
            .trim();
        if raw_name.is_empty() {
            return None;
        }

        let is_legends = raw_name.contains("[Legends]");
        let name = raw_name.replace("[Legends]", "").trim().to_string();
        let id = entry
            .get("id")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let profiles = entry.get("profiles").and_then(|v| v.as_array());
        let unit_profile_json = profiles.and_then(|arr| {
            arr.iter()
                .find(|p| p.get("typeName").and_then(|v| v.as_str()) == Some("Unit"))
        });

        let unit_profile_json =
            unit_profile_json.or_else(|| Self::find_first_profile_by_type(entry, "Unit"))?;

        let char_map = Self::extract_characteristics(unit_profile_json);

        let movement = char_map
            .get("M")
            .cloned()
            .unwrap_or_else(|| "6\"".to_string());
        let toughness = char_map
            .get("T")
            .and_then(|s| s.trim().parse::<u32>().ok())
            .unwrap_or(4);

        let save_raw = char_map.get("Sv").map(|s| s.as_str()).unwrap_or("3+");
        let save = save_raw
            .trim()
            .trim_end_matches('+')
            .parse::<u32>()
            .unwrap_or(3);

        let wounds = char_map
            .get("W")
            .and_then(|s| s.trim().parse::<u32>().ok())
            .unwrap_or(2);

        let leadership = char_map
            .get("LD")
            .or_else(|| char_map.get("Ld"))
            .cloned()
            .unwrap_or_else(|| "6+".to_string());

        let objective_control = char_map
            .get("OC")
            .and_then(|s| s.trim().parse::<u32>().ok())
            .unwrap_or(1);

        let invuln_raw = char_map.get("InSv").map(|s| s.as_str()).unwrap_or("");
        let mut invuln = if !invuln_raw.trim().is_empty() && invuln_raw != "-" {
            invuln_raw.trim().trim_end_matches('+').parse::<u32>().ok()
        } else {
            None
        };

        let mut categories = Vec::new();
        for src in [Some(entry), entry_link].into_iter().flatten() {
            if let Some(cat_links) = src.get("categoryLinks").and_then(|v| v.as_array()) {
                for c in cat_links {
                    if let Some(cname) = c.get("name").and_then(|v| v.as_str()) {
                        let clean = cname.trim().to_string();
                        if !clean.is_empty()
                            && !clean.starts_with("Faction:")
                            && !categories
                                .iter()
                                .any(|existing: &String| existing.eq_ignore_ascii_case(&clean))
                        {
                            categories.push(clean);
                        }
                    }
                }
            }
        }

        if categories
            .iter()
            .any(|c| c.eq_ignore_ascii_case("Configuration"))
        {
            return None;
        }

        let mut keywords: Vec<Keyword> = categories
            .iter()
            .map(|s| Keyword::from(s.as_str()))
            .collect();
        if !keywords
            .iter()
            .any(|k| k.matches(&Keyword::from(faction_name)))
        {
            keywords.push(Keyword::from(faction_name));
        }

        let (points_cost, pricing_tiers) = Self::extract_bsdata_pricing(entry, entry_link);

        let mut abilities_text = Vec::new();
        let mut visited_abilities = HashSet::new();
        Self::extract_abilities_with_index(
            entry,
            index,
            &mut abilities_text,
            &mut visited_abilities,
            0,
        );

        let mut defensive_rules = Vec::new();
        let mut feel_no_pain = None;

        for ab_text in &abilities_text {
            let (rules, fnp_opt, inv_opt) = Self::match_defensive_rules(ab_text);
            for r in rules {
                if !defensive_rules.contains(&r) {
                    defensive_rules.push(r);
                }
            }
            if feel_no_pain.is_none() && fnp_opt.is_some() {
                feel_no_pain = fnp_opt;
            }
            if invuln.is_none() && inv_opt.is_some() {
                invuln = inv_opt;
            }
        }

        if categories.iter().any(|c| c.eq_ignore_ascii_case("Stealth"))
            && !defensive_rules.contains(&DefensiveAbility::Stealth)
        {
            defensive_rules.push(DefensiveAbility::Stealth);
        }

        let leader_to = Self::extract_leader_targets(&abilities_text);

        let mut weapons = Vec::new();
        let mut visited_weapons = HashSet::new();
        Self::extract_weapons_with_index(entry, index, &mut weapons, &mut visited_weapons, 0);

        let unit_composition = Self::extract_unit_composition(entry);
        let wargear_options = Self::extract_wargear_option_labels(entry);

        let default_model_count = pricing_tiers
            .first()
            .and_then(|t| t.costs.first())
            .map(|c| c.models.max(1) as usize)
            .unwrap_or(1);

        let model = ModelProfile::new(name.clone(), wounds, save, invuln, feel_no_pain)
            .with_keywords(keywords.clone());

        let mut unit_profile = UnitProfile::uniform(
            name.clone(),
            toughness,
            model,
            default_model_count,
            keywords,
        );
        unit_profile.movement = movement;
        unit_profile.leadership = leadership;
        unit_profile.objective_control = objective_control;
        unit_profile.defensive_abilities = defensive_rules;

        Some(DatasheetUnit {
            id,
            name,
            faction_id: faction_id.to_string(),
            faction_name: faction_name.to_string(),
            group_title: None,
            is_legends,
            points_cost,
            profile: unit_profile,
            weapons,
            abilities: abilities_text,
            categories,
            unit_composition,
            wargear_options,
            pricing_tiers,
            wargear_costs: Vec::new(),
            leader_to,
            support_to: Vec::new(),
            transport_capacity: None,
        })
    }

    fn extract_bsdata_pricing(
        entry: &serde_json::Value,
        entry_link: Option<&serde_json::Value>,
    ) -> (Option<u32>, Vec<PricingTier>) {
        let mut base_pts: Option<u32> = None;

        for src in [entry_link, Some(entry)].into_iter().flatten() {
            if let Some(costs) = src.get("costs").and_then(|v| v.as_array()) {
                for c in costs {
                    if c.get("name").and_then(|v| v.as_str()) == Some("pts") {
                        if let Some(val) = c.get("value").and_then(|v| v.as_f64()) {
                            let p = val.max(0.0) as u32;
                            if p > 0 || base_pts.is_none() {
                                base_pts = Some(p);
                            }
                        }
                    }
                }
            }
        }

        let mut min_models = 0u32;
        let mut max_models = 0u32;
        if let Some(sub_entries) = entry.get("selectionEntries").and_then(|v| v.as_array()) {
            for sub in sub_entries {
                if sub.get("type").and_then(|v| v.as_str()) == Some("model") {
                    if let Some(constraints) = sub.get("constraints").and_then(|v| v.as_array()) {
                        for con in constraints {
                            let ctype = con.get("type").and_then(|v| v.as_str()).unwrap_or("");
                            let val = con
                                .get("value")
                                .and_then(|v| v.as_f64())
                                .map(|x| x.max(0.0) as u32)
                                .unwrap_or(0);
                            if ctype == "min" {
                                min_models += val;
                            } else if ctype == "max" {
                                max_models += val;
                            }
                        }
                    }
                }
            }
        }
        if min_models == 0 {
            min_models = 1;
        }

        let mut costs = Vec::new();
        if let Some(pts) = base_pts {
            costs.push(UnitCostOption {
                models: min_models,
                points: pts,
                description: None,
                is_addon: false,
            });

            if let Some(mods) = entry.get("modifiers").and_then(|v| v.as_array()) {
                for m in mods {
                    if m.get("field").and_then(|v| v.as_str()) == Some("51b2-306e-1021-d207")
                        && m.get("type").and_then(|v| v.as_str()) == Some("set")
                    {
                        if let Some(higher_pts) = m
                            .get("value")
                            .and_then(|v| v.as_f64())
                            .map(|v| v.max(0.0) as u32)
                        {
                            let model_cnt = if max_models > min_models {
                                max_models
                            } else {
                                min_models * 2
                            };
                            if higher_pts != pts && !costs.iter().any(|c| c.points == higher_pts) {
                                costs.push(UnitCostOption {
                                    models: model_cnt,
                                    points: higher_pts,
                                    description: None,
                                    is_addon: false,
                                });
                            }
                        }
                    }
                }
            }
        }

        let pricing = if costs.is_empty() {
            Vec::new()
        } else {
            vec![PricingTier {
                range: "[1,)".to_string(),
                label: "Your Unit Costs".to_string(),
                costs,
            }]
        };

        (base_pts, pricing)
    }

    fn extract_leader_targets(abilities: &[String]) -> Vec<String> {
        let mut targets = Vec::new();
        for ab in abilities {
            if ab.starts_with("Leader:")
                || ab
                    .to_lowercase()
                    .contains("can be attached to the following unit")
            {
                for line in ab.lines() {
                    let trimmed = line
                        .trim()
                        .trim_start_matches('-')
                        .trim_start_matches('•')
                        .trim_start_matches('■')
                        .trim();
                    if !trimmed.is_empty()
                        && !trimmed.starts_with("Leader:")
                        && !trimmed.to_lowercase().contains("can be attached")
                        && trimmed.len() <= 45
                    {
                        targets.push(trimmed.to_string());
                    }
                }
            }
        }
        targets
    }

    fn extract_unit_composition(entry: &serde_json::Value) -> Vec<String> {
        let mut comp = Vec::new();
        if let Some(sub_entries) = entry.get("selectionEntries").and_then(|v| v.as_array()) {
            for sub in sub_entries {
                if sub.get("type").and_then(|v| v.as_str()) == Some("model") {
                    if let Some(name) = sub.get("name").and_then(|v| v.as_str()) {
                        let mut min_v = None;
                        let mut max_v = None;
                        if let Some(cons) = sub.get("constraints").and_then(|v| v.as_array()) {
                            for c in cons {
                                match c.get("type").and_then(|v| v.as_str()) {
                                    Some("min") => {
                                        min_v = c
                                            .get("value")
                                            .and_then(|v| v.as_f64())
                                            .map(|x| x as u32)
                                    }
                                    Some("max") => {
                                        max_v = c
                                            .get("value")
                                            .and_then(|v| v.as_f64())
                                            .map(|x| x as u32)
                                    }
                                    _ => {}
                                }
                            }
                        }
                        let label = match (min_v, max_v) {
                            (Some(min), Some(max)) if min == max && min > 0 => {
                                format!("{} {}", min, name)
                            }
                            (Some(min), Some(max)) if max > min => {
                                format!("{}-{} {}", min, max, name)
                            }
                            (Some(min), None) if min > 0 => format!("{}+ {}", min, name),
                            _ => name.to_string(),
                        };
                        comp.push(label);
                    }
                }
            }
        }
        comp
    }

    fn extract_wargear_option_labels(entry: &serde_json::Value) -> Vec<String> {
        let mut opts = Vec::new();
        if let Some(groups) = entry.get("selectionEntryGroups").and_then(|v| v.as_array()) {
            for g in groups {
                if let Some(gname) = g.get("name").and_then(|v| v.as_str()) {
                    let clean = gname.trim().to_string();
                    if !clean.is_empty() && !opts.contains(&clean) {
                        opts.push(clean);
                    }
                }
            }
        }
        opts
    }

    fn extract_characteristics(profile: &serde_json::Value) -> HashMap<String, String> {
        let mut map = HashMap::new();
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

    fn extract_abilities_with_index(
        val: &serde_json::Value,
        index: &BsDataLookupIndex,
        list: &mut Vec<String>,
        visited: &mut HashSet<String>,
        depth: usize,
    ) {
        if depth > 5 {
            return;
        }
        if let Some(obj) = val.as_object() {
            let type_name = obj.get("typeName").and_then(|v| v.as_str()).unwrap_or("");
            if type_name == "Abilities" {
                let name = obj
                    .get("name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .trim();
                let chars = Self::extract_characteristics(val);
                let desc = chars
                    .get("Description")
                    .map(|s| s.as_str())
                    .unwrap_or("")
                    .trim();
                let full = if desc.is_empty() {
                    name.to_string()
                } else {
                    format!("{}: {}", name, desc)
                };
                if !full.is_empty() && !list.contains(&full) {
                    list.push(full);
                }
            }

            if let Some(info_links) = obj.get("infoLinks").and_then(|v| v.as_array()) {
                for il in info_links {
                    if let Some(tid) = il.get("targetId").and_then(|v| v.as_str()) {
                        if visited.insert(format!("il:{}", tid)) {
                            if let Some(target_prof) = index.profiles_by_id.get(tid) {
                                Self::extract_abilities_with_index(
                                    target_prof,
                                    index,
                                    list,
                                    visited,
                                    depth + 1,
                                );
                            }
                            if let Some(target_rule) = index.rules_by_id.get(tid) {
                                let rname = target_rule
                                    .get("name")
                                    .and_then(|v| v.as_str())
                                    .unwrap_or("")
                                    .trim();
                                let rdesc = target_rule
                                    .get("description")
                                    .and_then(|v| v.as_str())
                                    .unwrap_or("")
                                    .trim();
                                if !rname.is_empty() {
                                    let full = if rdesc.is_empty() {
                                        rname.to_string()
                                    } else {
                                        format!("{}: {}", rname, rdesc)
                                    };
                                    if !list.contains(&full) {
                                        list.push(full);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            for (k, v) in obj {
                if k == "infoLinks" {
                    continue;
                }
                Self::extract_abilities_with_index(v, index, list, visited, depth + 1);
            }
        } else if let Some(arr) = val.as_array() {
            for item in arr {
                Self::extract_abilities_with_index(item, index, list, visited, depth + 1);
            }
        }
    }

    fn match_defensive_rules(text: &str) -> (Vec<DefensiveAbility>, Option<u32>, Option<u32>) {
        let mut rules = Vec::new();
        let mut fnp = None;
        let mut inv = None;

        let lower = text.to_lowercase();

        if lower.contains("worsen the armour penetration")
            || lower.contains("worsen the armor penetration")
        {
            rules.push(DefensiveAbility::MinusOneAp);
        }

        if lower.contains("subtract 1 from the damage characteristic") {
            rules.push(DefensiveAbility::DamageReduction(1));
        }

        if lower.contains("halve the damage characteristic") {
            rules.push(DefensiveAbility::HalfDamage);
        }

        if lower.contains("stealth") || lower.contains("subtract 1 from the hit roll") {
            rules.push(DefensiveAbility::Stealth);
        }

        if lower.contains("subtract 1 from the wound roll") {
            rules.push(DefensiveAbility::MinusOneToWound);
        }

        let fnp_re = Regex::new(r"(?i)(?:feel no pain|fnp)\s*(\d)\+").unwrap();
        if let Some(caps) = fnp_re.captures(text) {
            if let Ok(val) = caps[1].parse::<u32>() {
                fnp = Some(val);
                rules.push(DefensiveAbility::FeelNoPain(val));
            }
        }

        let inv_re = Regex::new(r"(?i)(\d)\+\s+invulnerable save").unwrap();
        if let Some(caps) = inv_re.captures(text) {
            if let Ok(val) = caps[1].parse::<u32>() {
                inv = Some(val);
                rules.push(DefensiveAbility::InvulnerableSave(val));
            }
        }

        (rules, fnp, inv)
    }

    fn extract_weapons_with_index(
        val: &serde_json::Value,
        index: &BsDataLookupIndex,
        list: &mut Vec<WeaponProfile>,
        visited: &mut HashSet<String>,
        depth: usize,
    ) {
        if depth > 6 {
            return;
        }
        if let Some(obj) = val.as_object() {
            let type_name = obj.get("typeName").and_then(|v| v.as_str()).unwrap_or("");
            if type_name == "Ranged Weapons" || type_name == "Melee Weapons" {
                if let Some(weapon) = Self::parse_weapon_profile(val, type_name == "Melee Weapons")
                {
                    if !list.iter().any(|w| {
                        w.name == weapon.name
                            && w.profile_name == weapon.profile_name
                            && w.range == weapon.range
                            && w.strength == weapon.strength
                    }) {
                        list.push(weapon);
                    }
                }
            }

            if let Some(entry_links) = obj.get("entryLinks").and_then(|v| v.as_array()) {
                for el in entry_links {
                    if let Some(tid) = el.get("targetId").and_then(|v| v.as_str()) {
                        if visited.insert(format!("el:{}", tid)) {
                            if let Some(target_entry) = index.entries_by_id.get(tid) {
                                Self::extract_weapons_with_index(
                                    target_entry,
                                    index,
                                    list,
                                    visited,
                                    depth + 1,
                                );
                            }
                        }
                    }
                }
            }

            if let Some(info_links) = obj.get("infoLinks").and_then(|v| v.as_array()) {
                for il in info_links {
                    if let Some(tid) = il.get("targetId").and_then(|v| v.as_str()) {
                        if visited.insert(format!("wil:{}", tid)) {
                            if let Some(target_prof) = index.profiles_by_id.get(tid) {
                                Self::extract_weapons_with_index(
                                    target_prof,
                                    index,
                                    list,
                                    visited,
                                    depth + 1,
                                );
                            }
                        }
                    }
                }
            }

            for (k, v) in obj {
                if k == "entryLinks" || k == "infoLinks" {
                    continue;
                }
                Self::extract_weapons_with_index(v, index, list, visited, depth + 1);
            }
        } else if let Some(arr) = val.as_array() {
            for item in arr {
                Self::extract_weapons_with_index(item, index, list, visited, depth + 1);
            }
        }
    }

    fn parse_weapon_profile(
        profile_json: &serde_json::Value,
        is_melee: bool,
    ) -> Option<WeaponProfile> {
        let name = profile_json
            .get("name")
            .and_then(|v| v.as_str())?
            .trim()
            .to_string();
        let chars = Self::extract_characteristics(profile_json);

        let range_raw = chars
            .get("Range")
            .map(|s| s.as_str())
            .unwrap_or(if is_melee { "0" } else { "24\"" });
        let range = if is_melee || range_raw.eq_ignore_ascii_case("Melee") || range_raw == "-" {
            0
        } else {
            range_raw.trim_end_matches('"').parse::<u32>().unwrap_or(24)
        };

        let attacks_raw = chars.get("A").map(|s| s.as_str()).unwrap_or("1");
        let attacks = ValueExpr::from_str(attacks_raw).unwrap_or(ValueExpr::Flat(1));

        let skill_key = if is_melee { "WS" } else { "BS" };
        let skill_raw = chars
            .get(skill_key)
            .or_else(|| chars.get("BS"))
            .or_else(|| chars.get("WS"))
            .map(|s| s.as_str())
            .unwrap_or("3+");
        let (skill, is_torrent) = if skill_raw == "N/A" || skill_raw == "-" {
            (7, true)
        } else {
            (
                skill_raw.trim_end_matches('+').parse::<u32>().unwrap_or(3),
                false,
            )
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

pub fn clean_faction_display_name(raw: &str) -> String {
    let trimmed = raw
        .trim()
        .strip_prefix("Imperium - ")
        .or_else(|| raw.trim().strip_prefix("Chaos - "))
        .or_else(|| raw.trim().strip_prefix("Aeldari - "))
        .unwrap_or(raw.trim());
    match trimmed {
        "Craftworlds" => "Aeldari (Craftworlds)".to_string(),
        "Agents of the Imperium" => "Imperial Agents".to_string(),
        other => other.to_string(),
    }
}

pub fn slugify_faction_name(name: &str) -> String {
    match name {
        "Aeldari (Craftworlds)" | "Craftworlds" | "Aeldari" => "aeldari".to_string(),
        "Imperial Agents" | "Agents of the Imperium" => "imperial-agents".to_string(),
        "T'au Empire" => "tau-empire".to_string(),
        "Emperor's Children" => "emperors-children".to_string(),
        "Adeptus Titanicus" => "titan-legions".to_string(),
        "Titanicus Traitoris" => "chaos-titan-legions".to_string(),
        other => other
            .to_lowercase()
            .replace('\'', "")
            .replace('’', "")
            .replace(' ', "-"),
    }
}
