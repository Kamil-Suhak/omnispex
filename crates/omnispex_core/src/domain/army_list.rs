use super::catalogue::{CatalogueDatabase, FactionCatalogue};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum BattleSize {
    Incursion,
    #[default]
    StrikeForce,
    Onslaught,
    Custom,
}

impl BattleSize {
    pub fn default_points_limit(&self) -> u32 {
        match self {
            BattleSize::Incursion => 1000,
            BattleSize::StrikeForce => 2000,
            BattleSize::Onslaught => 3000,
            BattleSize::Custom => 2000,
        }
    }

    pub fn dp_limit(&self) -> u32 {
        match self {
            BattleSize::Incursion => 2,
            BattleSize::StrikeForce => 3,
            BattleSize::Onslaught => 4,
            BattleSize::Custom => 4,
        }
    }

    pub fn enhancement_limit(&self) -> usize {
        match self {
            BattleSize::Incursion => 2,
            BattleSize::StrikeForce => 4,
            BattleSize::Onslaught => 6,
            BattleSize::Custom => 6,
        }
    }

    pub fn base_unit_limit(&self) -> usize {
        match self {
            BattleSize::Incursion => 2,
            BattleSize::StrikeForce => 3,
            BattleSize::Onslaught => 3,
            BattleSize::Custom => 3,
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            BattleSize::Incursion => "Incursion (1,000 pts)",
            BattleSize::StrikeForce => "Strike Force (2,000 pts)",
            BattleSize::Onslaught => "Onslaught (3,000 pts)",
            BattleSize::Custom => "Custom Battle Size",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SelectedDetachment {
    pub id: String,
    pub name: String,
    pub dp_cost: u32,
    #[serde(default)]
    pub unique_tag: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SelectedWargearOption {
    pub item: String,
    pub count: u32,
    pub points_each: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RosterUnitEntry {
    pub entry_id: String,
    pub unit_id: String,
    pub unit_name: String,
    pub models_count: u32,
    #[serde(default)]
    pub option_description: Option<String>,
    pub base_points: u32,
    #[serde(default)]
    pub requisition_tier_label: Option<String>,
    #[serde(default)]
    pub selected_wargear: Vec<SelectedWargearOption>,
    #[serde(default)]
    pub enhancement_id: Option<String>,
    #[serde(default)]
    pub enhancement_name: Option<String>,
    #[serde(default)]
    pub enhancement_points: u32,
    #[serde(default)]
    pub enhancement_is_upgrade: bool,
    #[serde(default)]
    pub is_warlord: bool,
    #[serde(default)]
    pub attached_to_entry_id: Option<String>,
    #[serde(default)]
    pub categories: Vec<String>,
    #[serde(default)]
    pub custom_weapons: Vec<String>,
    #[serde(default)]
    pub notes: String,
}

impl RosterUnitEntry {
    pub fn wargear_points(&self) -> u32 {
        self.selected_wargear
            .iter()
            .map(|w| w.count * w.points_each)
            .sum()
    }

    pub fn total_points(&self) -> u32 {
        self.base_points + self.wargear_points() + self.enhancement_points
    }

    pub fn has_category(&self, cat: &str) -> bool {
        self.categories.iter().any(|c| c.eq_ignore_ascii_case(cat))
    }

    pub fn is_character(&self) -> bool {
        self.has_category("Character")
    }

    pub fn is_epic_hero(&self) -> bool {
        self.has_category("Epic Hero")
    }

    pub fn is_battleline(&self) -> bool {
        self.has_category("Battleline")
    }

    pub fn is_dedicated_transport(&self) -> bool {
        self.has_category("Dedicated Transport")
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ArmyList {
    pub id: String,
    pub name: String,
    pub faction_id: String,
    pub faction_name: String,
    pub battle_size: BattleSize,
    pub points_limit: u32,
    #[serde(default)]
    pub detachments: Vec<SelectedDetachment>,
    #[serde(default)]
    pub units: Vec<RosterUnitEntry>,
    #[serde(default)]
    pub notes: String,
    pub created_at_iso: String,
    pub updated_at_iso: String,
}

impl ArmyList {
    pub fn total_points(&self) -> u32 {
        self.units.iter().map(|u| u.total_points()).sum()
    }

    pub fn total_dp(&self) -> u32 {
        self.detachments.iter().map(|d| d.dp_cost).sum()
    }

    /// Recomputes unit points dynamically against the faction catalogue, respecting 11th Edition
    /// Requisition Thresholds (where the Nth copy of a unit can fall into a higher cost bracket).
    pub fn recalculate_points(&mut self, faction: &FactionCatalogue) {
        let mut instance_counters: HashMap<String, usize> = HashMap::new();

        for entry in &mut self.units {
            let count = instance_counters
                .entry(entry.unit_name.to_lowercase())
                .and_modify(|c| *c += 1)
                .or_insert(1);
            let instance_num = *count;

            if let Some(unit_data) = faction.units.iter().find(|u| {
                u.id.eq_ignore_ascii_case(&entry.unit_id)
                    || u.name.eq_ignore_ascii_case(&entry.unit_name)
            }) {
                entry.base_points =
                    unit_data.points_for_instance_and_models(instance_num, entry.models_count);

                if let Some(tier) = unit_data
                    .pricing_tiers
                    .iter()
                    .find(|t| t.matches_instance(instance_num))
                {
                    entry.requisition_tier_label = Some(tier.label.clone());
                }
            }
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ValidationSeverity {
    Error,
    Warning,
    UnverifiedNotice,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ValidationIssue {
    pub severity: ValidationSeverity,
    pub code: String,
    pub message: String,
    pub affected_entry_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ListValidationReport {
    pub is_valid: bool,
    pub total_points: u32,
    pub points_limit: u32,
    pub total_dp: u32,
    pub dp_limit: u32,
    pub enhancement_slots_used: usize,
    pub enhancement_limit: usize,
    pub violations: Vec<ValidationIssue>,
    pub warnings: Vec<ValidationIssue>,
    pub unverified_rules: Vec<String>,
}

pub fn validate_army_list(
    list: &ArmyList,
    catalogue_db: Option<&CatalogueDatabase>,
) -> ListValidationReport {
    let mut violations = Vec::new();
    let mut warnings = Vec::new();
    let mut unverified_rules = Vec::new();

    let total_points = list.total_points();
    let points_limit = list.points_limit;
    let total_dp = list.total_dp();
    let dp_limit = list.battle_size.dp_limit();
    let enhancement_limit = list.battle_size.enhancement_limit();
    let base_unit_limit = list.battle_size.base_unit_limit();

    let faction_cat = catalogue_db.and_then(|db| {
        db.find_faction(&list.faction_id)
            .or_else(|| db.find_faction(&list.faction_name))
    });

    // 1. Points limit check
    if total_points > points_limit {
        violations.push(ValidationIssue {
            severity: ValidationSeverity::Error,
            code: "POINTS_EXCEEDED".to_string(),
            message: format!(
                "Army total ({} pts) exceeds the battle size limit of {} pts by {} pts.",
                total_points,
                points_limit,
                total_points - points_limit
            ),
            affected_entry_id: None,
        });
    }

    if list.units.is_empty() {
        violations.push(ValidationIssue {
            severity: ValidationSeverity::Error,
            code: "EMPTY_ROSTER".to_string(),
            message: "Roster must include at least one unit.".to_string(),
            affected_entry_id: None,
        });
    }

    // 2. Detachment checks
    if list.detachments.is_empty() {
        violations.push(ValidationIssue {
            severity: ValidationSeverity::Error,
            code: "NO_DETACHMENT".to_string(),
            message: "At least one detachment must be selected for the army.".to_string(),
            affected_entry_id: None,
        });
    } else {
        // Check duplicate detachments and unique tags
        let mut seen_detachments = HashSet::new();
        let mut seen_unique_tags = HashSet::new();
        for det in &list.detachments {
            if !seen_detachments.insert(det.name.to_lowercase()) {
                violations.push(ValidationIssue {
                    severity: ValidationSeverity::Error,
                    code: "DUPLICATE_DETACHMENT".to_string(),
                    message: format!(
                        "Detachment '{}' is selected more than once.",
                        det.name
                    ),
                    affected_entry_id: None,
                });
            }
            if let Some(tag) = &det.unique_tag {
                let clean_tag = tag.trim().to_lowercase();
                if !clean_tag.is_empty() && !seen_unique_tags.insert(clean_tag) {
                    violations.push(ValidationIssue {
                        severity: ValidationSeverity::Error,
                        code: "DUPLICATE_UNIQUE_DETACHMENT_TAG".to_string(),
                        message: format!(
                            "Multiple detachments share the Unique tag '{}' (found on '{}').",
                            tag, det.name
                        ),
                        affected_entry_id: None,
                    });
                }
            }
        }

        // Incursion exception: a single 3DP detachment is legal as the only detachment
        let incursion_3dp_exception = list.battle_size == BattleSize::Incursion
            && list.detachments.len() == 1
            && total_dp == 3;

        if total_dp > dp_limit && !incursion_3dp_exception {
            violations.push(ValidationIssue {
                severity: ValidationSeverity::Error,
                code: "DP_LIMIT_EXCEEDED".to_string(),
                message: format!(
                    "Selected detachments cost {} DP, exceeding the {} limit of {} DP.",
                    total_dp,
                    list.battle_size.label(),
                    dp_limit
                ),
                affected_entry_id: None,
            });
        }
    }

    // 3. Warlord check
    let warlords: Vec<&RosterUnitEntry> = list.units.iter().filter(|u| u.is_warlord).collect();
    if warlords.is_empty() {
        violations.push(ValidationIssue {
            severity: ValidationSeverity::Error,
            code: "MISSING_WARLORD".to_string(),
            message: "Exactly one CHARACTER unit must be designated as your Warlord.".to_string(),
            affected_entry_id: None,
        });
    } else if warlords.len() > 1 {
        violations.push(ValidationIssue {
            severity: ValidationSeverity::Error,
            code: "MULTIPLE_WARLORDS".to_string(),
            message: format!(
                "Only one unit may be designated as Warlord ({} currently marked).",
                warlords.len()
            ),
            affected_entry_id: Some(warlords[1].entry_id.clone()),
        });
    } else if !warlords[0].is_character() {
        violations.push(ValidationIssue {
            severity: ValidationSeverity::Error,
            code: "NON_CHARACTER_WARLORD".to_string(),
            message: format!(
                "Warlord '{}' does not have the CHARACTER keyword.",
                warlords[0].unit_name
            ),
            affected_entry_id: Some(warlords[0].entry_id.clone()),
        });
    }

    // 4. Datasheet duplication & Requisition Threshold pricing check
    let mut unit_counts: HashMap<String, Vec<&RosterUnitEntry>> = HashMap::new();
    for entry in &list.units {
        unit_counts
            .entry(entry.unit_name.to_lowercase())
            .or_default()
            .push(entry);
    }

    for entries in unit_counts.values() {
        let first = entries[0];
        let count = entries.len();
        let max_allowed = if first.is_epic_hero() {
            1
        } else if first.is_battleline() || first.is_dedicated_transport() {
            base_unit_limit * 2
        } else {
            base_unit_limit
        };

        if count > max_allowed {
            let reason = if first.is_epic_hero() {
                "EPIC HERO (max 1 per army)".to_string()
            } else if first.is_battleline() || first.is_dedicated_transport() {
                format!(
                    "BATTLELINE / DEDICATED TRANSPORT (max {} in {})",
                    max_allowed,
                    list.battle_size.label()
                )
            } else {
                format!(
                    "datasheet limit (max {} in {})",
                    max_allowed,
                    list.battle_size.label()
                )
            };
            violations.push(ValidationIssue {
                severity: ValidationSeverity::Error,
                code: "UNIT_LIMIT_EXCEEDED".to_string(),
                message: format!(
                    "'{}' is included {} times, exceeding the {}.",
                    first.unit_name, count, reason
                ),
                affected_entry_id: entries.last().map(|e| e.entry_id.clone()),
            });
        }

        // Verify Requisition Threshold pricing against catalogue if available
        if let Some(fcat) = faction_cat {
            if let Some(unit_data) = fcat.units.iter().find(|u| {
                u.id.eq_ignore_ascii_case(&first.unit_id)
                    || u.name.eq_ignore_ascii_case(&first.unit_name)
            }) {
                for (idx, entry) in entries.iter().enumerate() {
                    let expected_pts =
                        unit_data.points_for_instance_and_models(idx + 1, entry.models_count);
                    if expected_pts > 0 && entry.base_points != expected_pts {
                        warnings.push(ValidationIssue {
                            severity: ValidationSeverity::Warning,
                            code: "STALE_UNIT_POINTS".to_string(),
                            message: format!(
                                "Copy #{} of '{}' ({} models) has {} pts recorded, but current MFM tier pricing is {} pts.",
                                idx + 1,
                                entry.unit_name,
                                entry.models_count,
                                entry.base_points,
                                expected_pts
                            ),
                            affected_entry_id: Some(entry.entry_id.clone()),
                        });
                    }
                }
            }
        }
    }

    // 5. Enhancements validation (including 11e Upgrade rules)
    let mut enh_counts: HashMap<String, (usize, bool, String)> = HashMap::new();
    let allowed_detachment_names: HashSet<String> = list
        .detachments
        .iter()
        .map(|d| d.name.to_lowercase())
        .collect();

    for entry in &list.units {
        if let Some(enh_name) = &entry.enhancement_name {
            let clean_enh = enh_name.trim();
            if clean_enh.is_empty() {
                continue;
            }
            let is_upgrade =
                entry.enhancement_is_upgrade || clean_enh.to_lowercase().contains("(upgrade)");

            if entry.is_epic_hero() {
                violations.push(ValidationIssue {
                    severity: ValidationSeverity::Error,
                    code: "EPIC_HERO_ENHANCEMENT".to_string(),
                    message: format!(
                        "EPIC HERO '{}' cannot be given the enhancement '{}'.",
                        entry.unit_name, clean_enh
                    ),
                    affected_entry_id: Some(entry.entry_id.clone()),
                });
            } else if !is_upgrade && !entry.is_character() {
                violations.push(ValidationIssue {
                    severity: ValidationSeverity::Error,
                    code: "NON_CHARACTER_ENHANCEMENT".to_string(),
                    message: format!(
                        "Non-CHARACTER unit '{}' cannot take non-Upgrade enhancement '{}'.",
                        entry.unit_name, clean_enh
                    ),
                    affected_entry_id: Some(entry.entry_id.clone()),
                });
            }

            // Check if enhancement belongs to a selected detachment
            if let Some(fcat) = faction_cat {
                let enh_belongs_to_selected = fcat
                    .detachments
                    .iter()
                    .filter(|d| allowed_detachment_names.contains(&d.name.to_lowercase()))
                    .any(|d| {
                        d.enhancements
                            .iter()
                            .any(|e| e.name.eq_ignore_ascii_case(clean_enh))
                    });

                let enh_exists_in_faction = fcat.detachments.iter().any(|d| {
                    d.enhancements
                        .iter()
                        .any(|e| e.name.eq_ignore_ascii_case(clean_enh))
                });

                if enh_exists_in_faction && !enh_belongs_to_selected {
                    violations.push(ValidationIssue {
                        severity: ValidationSeverity::Error,
                        code: "ENHANCEMENT_DETACHMENT_MISMATCH".to_string(),
                        message: format!(
                            "Enhancement '{}' on '{}' does not belong to any selected detachment.",
                            clean_enh, entry.unit_name
                        ),
                        affected_entry_id: Some(entry.entry_id.clone()),
                    });
                }
            }

            let record = enh_counts
                .entry(clean_enh.to_lowercase())
                .or_insert((0, is_upgrade, clean_enh.to_string()));
            record.0 += 1;
        }
    }

    let mut enhancement_slots_used = 0usize;
    for (count, is_upgrade, display_name) in enh_counts.values() {
        if *is_upgrade {
            // In 11e MFM: up to 3 of the same Upgrade; 2nd and 3rd instances do not count toward Enhancement Limit
            enhancement_slots_used += 1;
            if *count > 3 {
                violations.push(ValidationIssue {
                    severity: ValidationSeverity::Error,
                    code: "UPGRADE_ENHANCEMENT_LIMIT".to_string(),
                    message: format!(
                        "Upgrade enhancement '{}' is taken {} times (maximum 3 allowed).",
                        display_name, count
                    ),
                    affected_entry_id: None,
                });
            }
        } else {
            enhancement_slots_used += *count;
            if *count > 1 {
                violations.push(ValidationIssue {
                    severity: ValidationSeverity::Error,
                    code: "DUPLICATE_ENHANCEMENT".to_string(),
                    message: format!(
                        "Enhancement '{}' is taken {} times (non-Upgrade enhancements are unique).",
                        display_name, count
                    ),
                    affected_entry_id: None,
                });
            }
        }
    }

    if enhancement_slots_used > enhancement_limit {
        violations.push(ValidationIssue {
            severity: ValidationSeverity::Error,
            code: "ENHANCEMENT_LIMIT_EXCEEDED".to_string(),
            message: format!(
                "Army uses {} enhancement slots, exceeding the {} limit of {}.",
                enhancement_slots_used,
                list.battle_size.label(),
                enhancement_limit
            ),
            affected_entry_id: None,
        });
    }

    // 6. Attached unit checks (Leader / Support) + max 1 enhancement per attached unit
    let entry_map: HashMap<&str, &RosterUnitEntry> = list
        .units
        .iter()
        .map(|u| (u.entry_id.as_str(), u))
        .collect();

    for entry in &list.units {
        if let Some(target_id) = &entry.attached_to_entry_id {
            if let Some(bodyguard) = entry_map.get(target_id.as_str()) {
                // Check attached unit enhancement rule: max 1 enhancement across leader + bodyguard
                if entry.enhancement_name.is_some() && bodyguard.enhancement_name.is_some() {
                    violations.push(ValidationIssue {
                        severity: ValidationSeverity::Error,
                        code: "ATTACHED_UNIT_MULTIPLE_ENHANCEMENTS".to_string(),
                        message: format!(
                            "Attached unit ('{}' attached to '{}') has multiple enhancements (max 1 per attached unit).",
                            entry.unit_name, bodyguard.unit_name
                        ),
                        affected_entry_id: Some(entry.entry_id.clone()),
                    });
                }

                // Verify eligibility against catalogue if available
                if let Some(fcat) = faction_cat {
                    if let Some(leader_data) = fcat.units.iter().find(|u| {
                        u.id.eq_ignore_ascii_case(&entry.unit_id)
                            || u.name.eq_ignore_ascii_case(&entry.unit_name)
                    }) {
                        let mut valid_targets: Vec<String> = leader_data
                            .leader_to
                            .iter()
                            .chain(leader_data.support_to.iter())
                            .cloned()
                            .collect();

                        // Also check if an equipped enhancement unlocks Leader/Support for this unit
                        if let Some(enh_name) = &entry.enhancement_name {
                            for det in &fcat.detachments {
                                for enh in &det.enhancements {
                                    if enh.name.eq_ignore_ascii_case(enh_name) {
                                        valid_targets.extend(enh.leader_to.iter().cloned());
                                        valid_targets.extend(enh.support_to.iter().cloned());
                                    }
                                }
                            }
                        }

                        if !valid_targets.is_empty()
                            && !valid_targets
                                .iter()
                                .any(|t| t.eq_ignore_ascii_case(&bodyguard.unit_name))
                        {
                            violations.push(ValidationIssue {
                                severity: ValidationSeverity::Error,
                                code: "INVALID_LEADER_ATTACHMENT".to_string(),
                                message: format!(
                                    "'{}' cannot be attached to '{}' (allowed targets: {}).",
                                    entry.unit_name,
                                    bodyguard.unit_name,
                                    valid_targets.join(", ")
                                ),
                                affected_entry_id: Some(entry.entry_id.clone()),
                            });
                        }
                    }
                }
            } else {
                violations.push(ValidationIssue {
                    severity: ValidationSeverity::Error,
                    code: "BROKEN_ATTACHMENT_REFERENCE".to_string(),
                    message: format!(
                        "'{}' is attached to a unit that is no longer in the roster.",
                        entry.unit_name
                    ),
                    affected_entry_id: Some(entry.entry_id.clone()),
                });
            }
        } else if let Some(fcat) = faction_cat {
            // Check if this is a Support-only unit that MUST be attached to a bodyguard unit
            if let Some(unit_data) = fcat.units.iter().find(|u| {
                u.id.eq_ignore_ascii_case(&entry.unit_id)
                    || u.name.eq_ignore_ascii_case(&entry.unit_name)
            }) {
                if !unit_data.support_to.is_empty() && unit_data.leader_to.is_empty() {
                    violations.push(ValidationIssue {
                        severity: ValidationSeverity::Error,
                        code: "UNATTACHED_SUPPORT_UNIT".to_string(),
                        message: format!(
                            "Support unit '{}' must be attached to an eligible bodyguard unit ({}).",
                            entry.unit_name,
                            unit_data.support_to.join(", ")
                        ),
                        affected_entry_id: Some(entry.entry_id.clone()),
                    });
                }
            }
        }
    }

    // 7. Explicitly report unverified prose rules so the validator never overclaims compliance
    unverified_rules.push(
        "Per-model wargear replacement ratios (e.g. 'for every 5 models, 1 model may replace...') must be verified against the unit's Wargear Options text on its datasheet."
            .to_string(),
    );
    unverified_rules.push(
        "Detachment-specific prose restrictions and Allied/Agents unit inclusion formulas should be verified against the selected Detachment Rules."
            .to_string(),
    );

    ListValidationReport {
        is_valid: violations.is_empty(),
        total_points,
        points_limit,
        total_dp,
        dp_limit,
        enhancement_slots_used,
        enhancement_limit,
        violations,
        warnings,
        unverified_rules,
    }
}

pub fn export_army_list_text(
    list: &ArmyList,
    validation: Option<&ListValidationReport>,
) -> String {
    let mut out = String::new();
    out.push_str(&format!("=== {} ===\n", list.name));
    out.push_str(&format!("Faction: {}\n", list.faction_name));
    out.push_str(&format!(
        "Battle Size: {} ({} / {} pts)\n",
        list.battle_size.label(),
        list.total_points(),
        list.points_limit
    ));

    if !list.detachments.is_empty() {
        let det_str: Vec<String> = list
            .detachments
            .iter()
            .map(|d| format!("{} ({} DP)", d.name, d.dp_cost))
            .collect();
        out.push_str(&format!(
            "Detachments ({} / {} DP): {}\n",
            list.total_dp(),
            list.battle_size.dp_limit(),
            det_str.join(", ")
        ));
    }

    if let Some(val) = validation {
        out.push_str(&format!(
            "Validation Status: {}\n",
            if val.is_valid {
                "LEGAL (All automated checks passed)"
            } else {
                "ILLEGAL (Violations detected)"
            }
        ));
    }
    out.push('\n');

    let entry_names: HashMap<&str, &str> = list
        .units
        .iter()
        .map(|u| (u.entry_id.as_str(), u.unit_name.as_str()))
        .collect();

    for unit in &list.units {
        let warlord_tag = if unit.is_warlord { " [WARLORD]" } else { "" };
        let desc_tag = unit
            .option_description
            .as_ref()
            .map(|d| format!(" ({})", d))
            .unwrap_or_else(|| format!(" ({} models)", unit.models_count));
        out.push_str(&format!(
            "• {}{}{} — {} pts\n",
            unit.unit_name, desc_tag, warlord_tag, unit.total_points()
        ));

        if let Some(enh) = &unit.enhancement_name {
            out.push_str(&format!(
                "  - Enhancement: {} (+{} pts)\n",
                enh, unit.enhancement_points
            ));
        }

        for wg in &unit.selected_wargear {
            if wg.points_each > 0 {
                out.push_str(&format!(
                    "  - Wargear: {}x {} (+{} pts)\n",
                    wg.count,
                    wg.item,
                    wg.count * wg.points_each
                ));
            } else {
                out.push_str(&format!("  - Wargear: {}x {}\n", wg.count, wg.item));
            }
        }

        if let Some(target_id) = &unit.attached_to_entry_id {
            if let Some(target_name) = entry_names.get(target_id.as_str()) {
                out.push_str(&format!("  - Attached to: {}\n", target_name));
            }
        }

        if !unit.notes.trim().is_empty() {
            out.push_str(&format!("  - Notes: {}\n", unit.notes.trim()));
        }
    }

    if !list.notes.trim().is_empty() {
        out.push_str(&format!("\nArmy Notes:\n{}\n", list.notes.trim()));
    }

    out
}

