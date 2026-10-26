use crate::domain::catalogue::{
    DetachmentData, EnhancementData, FactionCatalogue, PricingTier, UnitCostOption,
    WargearCostOption,
};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MfmMetaFile {
    #[serde(default)]
    pub version: String,
    #[serde(default, rename = "lastUpdated")]
    pub last_updated: String,
    #[serde(default)]
    pub source: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MfmFactionFile {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub slug: String,
    #[serde(default)]
    pub version: String,
    #[serde(default, rename = "firstSeen")]
    pub first_seen: String,
    #[serde(default)]
    pub parent: Option<String>,
    #[serde(default)]
    pub detachments: Vec<MfmDetachment>,
    #[serde(default)]
    pub units: Vec<MfmUnit>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MfmDetachment {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub dp: Option<u32>,
    #[serde(default)]
    pub objectives: Vec<String>,
    #[serde(default)]
    pub unique: Option<String>,
    #[serde(default)]
    pub enhancements: Vec<MfmEnhancement>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MfmEnhancement {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub points: u32,
    #[serde(default, rename = "leaderTo")]
    pub leader_to: Vec<String>,
    #[serde(default, rename = "supportTo")]
    pub support_to: Vec<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MfmUnit {
    #[serde(default)]
    pub name: String,
    #[serde(default, rename = "groupTitle")]
    pub group_title: Option<String>,
    #[serde(default)]
    pub legends: Option<bool>,
    #[serde(default)]
    pub pricing: Vec<MfmPricingTier>,
    #[serde(default, rename = "leaderTo")]
    pub leader_to: Vec<String>,
    #[serde(default, rename = "supportTo")]
    pub support_to: Vec<String>,
    #[serde(default)]
    pub wargear: Vec<MfmWargearOption>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MfmPricingTier {
    #[serde(default)]
    pub range: String,
    #[serde(default)]
    pub label: String,
    #[serde(default)]
    pub costs: Vec<MfmCostOption>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MfmCostOption {
    #[serde(default)]
    pub models: u32,
    #[serde(default)]
    pub points: u32,
    #[serde(default)]
    pub desc: Option<String>,
    #[serde(default)]
    pub addon: Option<bool>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MfmWargearOption {
    #[serde(default)]
    pub item: String,
    #[serde(default)]
    pub points: u32,
}

pub fn parse_mfm_faction_yaml(yaml_str: &str) -> Result<MfmFactionFile, String> {
    serde_yaml::from_str(yaml_str).map_err(|e| format!("Failed to parse MFM YAML: {}", e))
}

fn normalize_lookup_name(s: &str) -> String {
    s.trim()
        .replace('’', "'")
        .replace('‘', "'")
        .replace("[Legends]", "")
        .trim()
        .to_lowercase()
}

/// Merges authoritative MFM v1.6 detachments, enhancements, unit pricing tiers, wargear costs,
/// and Leader/Support attachment rules into a parsed BSData `FactionCatalogue`.
pub fn merge_mfm_into_faction(faction: &mut FactionCatalogue, mfm: &MfmFactionFile) {
    if faction.slug.is_empty() && !mfm.slug.is_empty() {
        faction.slug = mfm.slug.clone();
    }
    if faction.parent_faction.is_none() && mfm.parent.is_some() {
        faction.parent_faction = mfm.parent.clone();
    }

    // 1. Merge detachments & enhancements
    for mfm_det in &mfm.detachments {
        let det_key = normalize_lookup_name(&mfm_det.name);
        let existing_det = faction
            .detachments
            .iter_mut()
            .find(|d| normalize_lookup_name(&d.name) == det_key);

        let mapped_enhancements: Vec<EnhancementData> = mfm_det
            .enhancements
            .iter()
            .map(|e| {
                let is_upgrade = e.name.contains("(Upgrade)");
                let existing_rule = existing_det
                    .as_ref()
                    .and_then(|d| {
                        d.enhancements
                            .iter()
                            .find(|be| normalize_lookup_name(&be.name) == normalize_lookup_name(&e.name))
                    })
                    .map(|be| (be.id.clone(), be.description.clone()));

                let (id, description) = existing_rule.unwrap_or_else(|| {
                    (
                        format!(
                            "enh-{}-{}",
                            mfm.slug,
                            normalize_lookup_name(&e.name).replace(' ', "-")
                        ),
                        String::new(),
                    )
                });

                EnhancementData {
                    id,
                    name: e.name.clone(),
                    points: e.points,
                    is_upgrade,
                    description,
                    leader_to: e.leader_to.clone(),
                    support_to: e.support_to.clone(),
                }
            })
            .collect();

        if let Some(det) = existing_det {
            det.dp_cost = mfm_det.dp.unwrap_or(det.dp_cost);
            det.force_dispositions = mfm_det.objectives.clone();
            det.unique_tag = mfm_det.unique.clone();
            for me in mapped_enhancements {
                if let Some(be) = det
                    .enhancements
                    .iter_mut()
                    .find(|x| normalize_lookup_name(&x.name) == normalize_lookup_name(&me.name))
                {
                    be.points = me.points;
                    be.is_upgrade = me.is_upgrade;
                    be.leader_to = me.leader_to;
                    be.support_to = me.support_to;
                } else {
                    det.enhancements.push(me);
                }
            }
        } else {
            faction.detachments.push(DetachmentData {
                id: format!("det-{}-{}", mfm.slug, det_key.replace(' ', "-")),
                name: mfm_det.name.clone(),
                dp_cost: mfm_det.dp.unwrap_or(1),
                force_dispositions: mfm_det.objectives.clone(),
                unique_tag: mfm_det.unique.clone(),
                rules: Vec::new(),
                enhancements: mapped_enhancements,
            });
        }
    }

    let all_rule_texts: Vec<(String, String)> = faction
        .detachments
        .iter()
        .flat_map(|d| {
            d.enhancements
                .iter()
                .filter(|e| !e.description.is_empty())
                .map(|e| (normalize_lookup_name(&e.name), e.description.clone()))
        })
        .collect();

    for det in &mut faction.detachments {
        for enh in &mut det.enhancements {
            if enh.description.is_empty() {
                let key = normalize_lookup_name(&enh.name);
                if let Some((_, text)) = all_rule_texts.iter().find(|(k, _)| *k == key) {
                    enh.description = text.clone();
                }
            }
        }
    }

    // 2. Merge unit pricing tiers, wargear costs, and leaderTo/supportTo
    for mfm_unit in &mfm.units {
        let u_key = normalize_lookup_name(&mfm_unit.name);
        if let Some(ds_unit) = faction
            .units
            .iter_mut()
            .find(|u| normalize_lookup_name(&u.name) == u_key)
        {
            ds_unit.pricing_tiers = mfm_unit
                .pricing
                .iter()
                .map(|t| PricingTier {
                    range: t.range.clone(),
                    label: t.label.clone(),
                    costs: t
                        .costs
                        .iter()
                        .map(|c| UnitCostOption {
                            models: c.models,
                            points: c.points,
                            description: c.desc.clone(),
                            is_addon: c.addon.unwrap_or(false),
                        })
                        .collect(),
                })
                .collect();

            if let Some(first_pts) = ds_unit
                .pricing_tiers
                .first()
                .and_then(|t| t.costs.first())
                .map(|c| c.points)
            {
                ds_unit.points_cost = Some(first_pts);
            }

            if !mfm_unit.leader_to.is_empty() {
                ds_unit.leader_to = mfm_unit.leader_to.clone();
            }
            if !mfm_unit.support_to.is_empty() {
                ds_unit.support_to = mfm_unit.support_to.clone();
            }
            if !mfm_unit.wargear.is_empty() {
                ds_unit.wargear_costs = mfm_unit
                    .wargear
                    .iter()
                    .map(|w| WargearCostOption {
                        item: w.item.clone(),
                        points: w.points,
                    })
                    .collect();
            }
            if mfm_unit.legends.unwrap_or(false) {
                ds_unit.is_legends = true;
            }
            if ds_unit.group_title.is_none() {
                ds_unit.group_title = mfm_unit.group_title.clone();
            }
        }
    }
}
