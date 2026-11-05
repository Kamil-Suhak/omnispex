use super::catalogue::{KillTeamCatalogueDatabase, KtWeaponProfile};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KtSelectedEquipment {
    pub equipment_id: String,
    pub name: String,
    #[serde(default)]
    pub is_universal: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KtRosterOperative {
    pub entry_id: String,
    pub operative_id: String,
    pub operative_name: String,
    pub role: String,
    pub is_leader: bool,
    pub apl: u32,
    pub movement: u32,
    pub save: u32,
    pub wounds: u32,
    #[serde(default)]
    pub selected_weapons: Vec<KtWeaponProfile>,
    #[serde(default)]
    pub custom_name: String,
    #[serde(default)]
    pub notes: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KillTeamRoster {
    pub id: String,
    pub name: String,
    pub faction_id: String,
    pub faction_name: String,
    #[serde(default)]
    pub selected_archetype: String,
    #[serde(default)]
    pub operatives: Vec<KtRosterOperative>,
    /// Up to 4 equipment options in KT24 (3rd Edition).
    #[serde(default)]
    pub equipment: Vec<KtSelectedEquipment>,
    #[serde(default)]
    pub notes: String,
    #[serde(default)]
    pub created_at_iso: String,
    #[serde(default)]
    pub updated_at_iso: String,
}

impl Default for KillTeamRoster {
    fn default() -> Self {
        Self {
            id: "kt-roster-default".to_string(),
            name: "Kill Team Strike Force".to_string(),
            faction_id: "kt-angels-of-death".to_string(),
            faction_name: "Angels of Death".to_string(),
            selected_archetype: "Seek & Destroy".to_string(),
            operatives: Vec::new(),
            equipment: Vec::new(),
            notes: String::new(),
            created_at_iso: "2026-11-05T00:00:00Z".to_string(),
            updated_at_iso: "2026-11-05T00:00:00Z".to_string(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum KtValidationSeverity {
    Error,
    Warning,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KtValidationIssue {
    pub severity: KtValidationSeverity,
    pub code: String,
    pub message: String,
    #[serde(default)]
    pub affected_entry_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct KtRosterValidationReport {
    pub is_valid: bool,
    pub total_operatives: u32,
    pub min_operatives: u32,
    pub max_operatives: u32,
    pub leader_count: u32,
    pub equipment_used: u32,
    pub equipment_limit: u32,
    pub total_wounds: u32,
    pub violations: Vec<KtValidationIssue>,
    pub warnings: Vec<KtValidationIssue>,
}

pub const KT24_EQUIPMENT_LIMIT: u32 = 4;

pub fn validate_kill_team_roster(
    roster: &KillTeamRoster,
    catalogue: Option<&KillTeamCatalogueDatabase>,
) -> KtRosterValidationReport {
    let mut violations = Vec::new();
    let mut warnings = Vec::new();

    let faction_opt = catalogue.and_then(|cat| {
        cat.find_faction(&roster.faction_id)
            .or_else(|| cat.find_faction(&roster.faction_name))
    });

    let (min_ops, max_ops) = faction_opt
        .map(|f| (f.min_team_size, f.max_team_size))
        .unwrap_or((6, 14));

    let total_operatives = roster.operatives.len() as u32;
    let total_wounds: u32 = roster.operatives.iter().map(|o| o.wounds).sum();

    // 1. Operative Count Check
    if total_operatives == 0 {
        violations.push(KtValidationIssue {
            severity: KtValidationSeverity::Error,
            code: "EMPTY_KILL_TEAM".to_string(),
            message: "Kill Team roster contains 0 operatives.".to_string(),
            affected_entry_id: None,
        });
    } else if total_operatives < min_ops || total_operatives > max_ops {
        let req_str = if min_ops == max_ops {
            format!("exactly {} operatives", min_ops)
        } else {
            format!("between {} and {} operatives", min_ops, max_ops)
        };
        violations.push(KtValidationIssue {
            severity: KtValidationSeverity::Error,
            code: "OPERATIVE_COUNT_MISMATCH".to_string(),
            message: format!(
                "{} requires {}, but roster has {}.",
                roster.faction_name, req_str, total_operatives
            ),
            affected_entry_id: None,
        });
    }

    // 2. Leader Count Check (must be exactly 1 Leader)
    let leaders: Vec<&KtRosterOperative> = roster
        .operatives
        .iter()
        .filter(|op| op.is_leader || op.role.eq_ignore_ascii_case("Leader"))
        .collect();
    let leader_count = leaders.len() as u32;

    if leader_count == 0 {
        violations.push(KtValidationIssue {
            severity: KtValidationSeverity::Error,
            code: "MISSING_LEADER".to_string(),
            message: "Kill Team must include exactly 1 LEADER operative.".to_string(),
            affected_entry_id: None,
        });
    } else if leader_count > 1 {
        let names: Vec<&str> = leaders.iter().map(|l| l.operative_name.as_str()).collect();
        violations.push(KtValidationIssue {
            severity: KtValidationSeverity::Error,
            code: "MULTIPLE_LEADERS".to_string(),
            message: format!(
                "Kill Team has {} Leaders ({}); maximum 1 Leader allowed.",
                leader_count,
                names.join(", ")
            ),
            affected_entry_id: Some(leaders[1].entry_id.clone()),
        });
    }

    // 3. Per-Operative Specialist Duplication & Cross-Faction Check
    let mut op_counts: HashMap<String, (u32, String, String)> = HashMap::new();
    for op in &roster.operatives {
        let key = op.operative_name.to_lowercase();
        let entry = op_counts.entry(key).or_insert((
            0,
            op.operative_name.clone(),
            op.entry_id.clone(),
        ));
        entry.0 += 1;
    }

    for (_key, (count, op_name, sample_entry_id)) in &op_counts {
        let max_allowed = if let Some(f) = faction_opt {
            if let Some(datacard) = f
                .operatives
                .iter()
                .find(|d| d.name.eq_ignore_ascii_case(op_name))
            {
                datacard.max_per_kill_team
            } else {
                violations.push(KtValidationIssue {
                    severity: KtValidationSeverity::Error,
                    code: "INVALID_FACTION_OPERATIVE".to_string(),
                    message: format!(
                        "Operative '{}' does not belong to Kill Team '{}'.",
                        op_name, f.name
                    ),
                    affected_entry_id: Some(sample_entry_id.clone()),
                });
                1
            }
        } else {
            // Without catalogue, non-Warrior/Trooper specialists are capped at 1
            let lower = op_name.to_lowercase();
            if lower.contains("warrior") || lower.contains("trooper") || lower.contains("boy") {
                10
            } else {
                1
            }
        };

        if *count > max_allowed {
            violations.push(KtValidationIssue {
                severity: KtValidationSeverity::Error,
                code: "OPERATIVE_LIMIT_EXCEEDED".to_string(),
                message: format!(
                    "Operative '{}' is selected {} times (maximum {} allowed per Kill Team).",
                    op_name, count, max_allowed
                ),
                affected_entry_id: Some(sample_entry_id.clone()),
            });
        }
    }

    // 4. Equipment Limit & Duplication Check (KT24: up to 4 distinct equipment options)
    let equipment_used = roster.equipment.len() as u32;
    if equipment_used > KT24_EQUIPMENT_LIMIT {
        violations.push(KtValidationIssue {
            severity: KtValidationSeverity::Error,
            code: "EQUIPMENT_LIMIT_EXCEEDED".to_string(),
            message: format!(
                "Selected {} equipment options (maximum {} allowed in Kill Team 2024).",
                equipment_used, KT24_EQUIPMENT_LIMIT
            ),
            affected_entry_id: None,
        });
    }

    let mut eq_seen: HashMap<String, u32> = HashMap::new();
    for eq in &roster.equipment {
        let c = eq_seen.entry(eq.name.to_lowercase()).or_insert(0);
        *c += 1;
        if *c == 2 {
            violations.push(KtValidationIssue {
                severity: KtValidationSeverity::Error,
                code: "DUPLICATE_EQUIPMENT".to_string(),
                message: format!(
                    "Equipment option '{}' is selected more than once (each equipment option may only be selected once).",
                    eq.name
                ),
                affected_entry_id: None,
            });
        }
    }

    // 5. Archetype warning if not among faction archetypes
    if let Some(f) = faction_opt {
        if !roster.selected_archetype.trim().is_empty()
            && !f.archetypes.is_empty()
            && !f
                .archetypes
                .iter()
                .any(|a| a.eq_ignore_ascii_case(&roster.selected_archetype))
        {
            warnings.push(KtValidationIssue {
                severity: KtValidationSeverity::Warning,
                code: "NON_STANDARD_ARCHETYPE".to_string(),
                message: format!(
                    "Selected archetype '{}' is not one of {}'s primary archetypes ({}).",
                    roster.selected_archetype,
                    f.name,
                    f.archetypes.join(" / ")
                ),
                affected_entry_id: None,
            });
        }
    }

    KtRosterValidationReport {
        is_valid: violations.is_empty(),
        total_operatives,
        min_operatives: min_ops,
        max_operatives: max_ops,
        leader_count,
        equipment_used,
        equipment_limit: KT24_EQUIPMENT_LIMIT,
        total_wounds,
        violations,
        warnings,
    }
}

pub fn export_kill_team_roster_text(
    roster: &KillTeamRoster,
    report: Option<&KtRosterValidationReport>,
) -> String {
    let mut out = String::new();
    out.push_str(&format!(
        "=== {} [{}] ===\n",
        roster.name, roster.faction_name
    ));
    if !roster.selected_archetype.is_empty() {
        out.push_str(&format!("Archetype: {}\n", roster.selected_archetype));
    }
    if let Some(rep) = report {
        out.push_str(&format!(
            "Status: {} | Operatives: {}/{} | Equipment: {}/{} | Total Wounds: {}\n",
            if rep.is_valid { "LEGAL" } else { "ILLEGAL" },
            rep.total_operatives,
            rep.max_operatives,
            rep.equipment_used,
            rep.equipment_limit,
            rep.total_wounds
        ));
    }
    out.push_str("\n--- OPERATIVES ---\n");
    for (idx, op) in roster.operatives.iter().enumerate() {
        let leader_tag = if op.is_leader { " [LEADER]" } else { "" };
        out.push_str(&format!(
            "{}. {}{} (APL {} | Move {}\" | Save {}+ | {}W)\n",
            idx + 1,
            op.operative_name,
            leader_tag,
            op.apl,
            op.movement,
            op.save,
            op.wounds
        ));
        for w in &op.selected_weapons {
            let rules_str = if w.rules.is_empty() {
                "-".to_string()
            } else {
                w.rules
                    .iter()
                    .map(|r| r.display_label())
                    .collect::<Vec<_>>()
                    .join(", ")
            };
            out.push_str(&format!(
                "   - [{}] {}: ATK {} | HIT {}+ | DMG {}/{} | Rules: {}\n",
                w.weapon_type.label(),
                w.name,
                w.attacks,
                w.hit,
                w.normal_damage,
                w.critical_damage,
                rules_str
            ));
        }
    }

    if !roster.equipment.is_empty() {
        out.push_str("\n--- EQUIPMENT ---\n");
        for eq in &roster.equipment {
            out.push_str(&format!(
                "- {}{}\n",
                eq.name,
                if eq.is_universal {
                    " (Universal)"
                } else {
                    " (Faction)"
                }
            ));
        }
    }

    out
}
