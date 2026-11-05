use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KtDataProvenance {
    pub edition: String,
    pub rules_version: String,
    pub built_at_iso: String,
}

impl Default for KtDataProvenance {
    fn default() -> Self {
        Self {
            edition: "Kill Team 2024 (3rd Edition)".to_string(),
            rules_version: "KT24 Core + Balance Dataslate".to_string(),
            built_at_iso: "2026-11-05T00:00:00Z".to_string(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum KtWeaponType {
    Ranged,
    Melee,
}

impl Default for KtWeaponType {
    fn default() -> Self {
        Self::Ranged
    }
}

impl KtWeaponType {
    pub fn label(&self) -> &'static str {
        match self {
            KtWeaponType::Ranged => "Ranged",
            KtWeaponType::Melee => "Melee",
        }
    }
}

/// Official Kill Team 2024 (3rd Edition) Weapon Rules.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum KtWeaponRule {
    Accurate(u32),
    Balanced,
    Ceaseless,
    Relentless,
    Lethal(u32),
    Rending,
    Severe,
    Punishing,
    Devastating(u32),
    Piercing(u32),
    PiercingCrits(u32),
    Saturate,
    Seek,
    SeekLight,
    Silent,
    Hot,
    Blast(u32),
    Torrent(u32),
    Range(u32),
    Brutal,
    Shock,
    Stun,
    Heavy,
    HeavyDashOnly,
    HeavyRepositionOnly,
    Limited(u32),
    Custom(String),
}

impl KtWeaponRule {
    pub fn display_label(&self) -> String {
        match self {
            KtWeaponRule::Accurate(x) => format!("Accurate {}", x),
            KtWeaponRule::Balanced => "Balanced".to_string(),
            KtWeaponRule::Ceaseless => "Ceaseless".to_string(),
            KtWeaponRule::Relentless => "Relentless".to_string(),
            KtWeaponRule::Lethal(x) => format!("Lethal {}+", x),
            KtWeaponRule::Rending => "Rending".to_string(),
            KtWeaponRule::Severe => "Severe".to_string(),
            KtWeaponRule::Punishing => "Punishing".to_string(),
            KtWeaponRule::Devastating(x) => format!("Devastating {}", x),
            KtWeaponRule::Piercing(x) => format!("Piercing {}", x),
            KtWeaponRule::PiercingCrits(x) => format!("Piercing Crits {}", x),
            KtWeaponRule::Saturate => "Saturate".to_string(),
            KtWeaponRule::Seek => "Seek".to_string(),
            KtWeaponRule::SeekLight => "Seek Light".to_string(),
            KtWeaponRule::Silent => "Silent".to_string(),
            KtWeaponRule::Hot => "Hot".to_string(),
            KtWeaponRule::Blast(x) => format!("Blast {}\"", x),
            KtWeaponRule::Torrent(x) => format!("Torrent {}\"", x),
            KtWeaponRule::Range(x) => format!("Range {}\"", x),
            KtWeaponRule::Brutal => "Brutal".to_string(),
            KtWeaponRule::Shock => "Shock".to_string(),
            KtWeaponRule::Stun => "Stun".to_string(),
            KtWeaponRule::Heavy => "Heavy".to_string(),
            KtWeaponRule::HeavyDashOnly => "Heavy (Dash Only)".to_string(),
            KtWeaponRule::HeavyRepositionOnly => "Heavy (Reposition Only)".to_string(),
            KtWeaponRule::Limited(x) => format!("Limited {}", x),
            KtWeaponRule::Custom(s) => s.clone(),
        }
    }
}

impl fmt::Display for KtWeaponRule {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.display_label())
    }
}

pub fn parse_kt_weapon_rule(raw: &str) -> Option<KtWeaponRule> {
    let clean = raw
        .trim()
        .trim_matches(|c| c == '[' || c == ']' || c == '(' || c == ')' || c == '*')
        .trim();
    if clean.is_empty() || clean == "-" {
        return None;
    }
    let upper = clean.to_uppercase();

    match upper.as_str() {
        "BALANCED" => return Some(KtWeaponRule::Balanced),
        "CEASELESS" => return Some(KtWeaponRule::Ceaseless),
        "RELENTLESS" => return Some(KtWeaponRule::Relentless),
        "RENDING" => return Some(KtWeaponRule::Rending),
        "SEVERE" => return Some(KtWeaponRule::Severe),
        "PUNISHING" => return Some(KtWeaponRule::Punishing),
        "SATURATE" | "NO COVER" => return Some(KtWeaponRule::Saturate),
        "SEEK" => return Some(KtWeaponRule::Seek),
        "SEEK LIGHT" => return Some(KtWeaponRule::SeekLight),
        "SILENT" => return Some(KtWeaponRule::Silent),
        "HOT" | "HOT!" => return Some(KtWeaponRule::Hot),
        "BRUTAL" => return Some(KtWeaponRule::Brutal),
        "SHOCK" => return Some(KtWeaponRule::Shock),
        "STUN" => return Some(KtWeaponRule::Stun),
        "HEAVY" => return Some(KtWeaponRule::Heavy),
        "HEAVY (DASH ONLY)" | "HEAVY DASH ONLY" => return Some(KtWeaponRule::HeavyDashOnly),
        "HEAVY (REPOSITION ONLY)" | "HEAVY REPOSITION ONLY" => {
            return Some(KtWeaponRule::HeavyRepositionOnly)
        }
        _ => {}
    }

    if let Some(rest) = upper.strip_prefix("ACCURATE") {
        if let Ok(v) = rest.trim().parse::<u32>() {
            return Some(KtWeaponRule::Accurate(v));
        }
    }
    if let Some(rest) = upper.strip_prefix("LETHAL") {
        if let Ok(v) = rest.trim().trim_end_matches('+').parse::<u32>() {
            return Some(KtWeaponRule::Lethal(v));
        }
    }
    if let Some(rest) = upper.strip_prefix("DEVASTATING") {
        if let Ok(v) = rest.trim().parse::<u32>() {
            return Some(KtWeaponRule::Devastating(v));
        }
    }
    if let Some(rest) = upper.strip_prefix("MW") {
        if let Ok(v) = rest.trim().parse::<u32>() {
            return Some(KtWeaponRule::Devastating(v));
        }
    }
    if let Some(rest) = upper.strip_prefix("PIERCING CRITS") {
        if let Ok(v) = rest.trim().parse::<u32>() {
            return Some(KtWeaponRule::PiercingCrits(v));
        }
    }
    if let Some(rest) = upper.strip_prefix("PIERCING") {
        if let Ok(v) = rest.trim().parse::<u32>() {
            return Some(KtWeaponRule::Piercing(v));
        }
    }
    if let Some(rest) = upper.strip_prefix("AP") {
        if let Ok(v) = rest.trim().parse::<u32>() {
            return Some(KtWeaponRule::Piercing(v));
        }
    }
    if let Some(rest) = upper.strip_prefix("P") {
        if rest.trim().len() == 1 {
            if let Ok(v) = rest.trim().parse::<u32>() {
                return Some(KtWeaponRule::PiercingCrits(v));
            }
        }
    }
    if let Some(rest) = upper.strip_prefix("BLAST") {
        if let Ok(v) = rest.trim().trim_end_matches('"').parse::<u32>() {
            return Some(KtWeaponRule::Blast(v));
        }
    }
    if let Some(rest) = upper.strip_prefix("TORRENT") {
        if let Ok(v) = rest.trim().trim_end_matches('"').parse::<u32>() {
            return Some(KtWeaponRule::Torrent(v));
        }
    }
    if let Some(rest) = upper.strip_prefix("RANGE") {
        if let Ok(v) = rest.trim().trim_end_matches('"').parse::<u32>() {
            return Some(KtWeaponRule::Range(v));
        }
    }
    if let Some(rest) = upper.strip_prefix("RNG") {
        if let Ok(v) = rest.trim().trim_end_matches('"').parse::<u32>() {
            return Some(KtWeaponRule::Range(v));
        }
    }
    if let Some(rest) = upper.strip_prefix("LIMITED") {
        if let Ok(v) = rest.trim().parse::<u32>() {
            return Some(KtWeaponRule::Limited(v));
        }
    }

    Some(KtWeaponRule::Custom(clean.to_string()))
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KtWeaponProfile {
    pub name: String,
    #[serde(default)]
    pub weapon_type: KtWeaponType,
    pub attacks: u32,
    #[serde(alias = "hit_stat")]
    pub hit: u32,
    pub normal_damage: u32,
    pub critical_damage: u32,
    #[serde(default)]
    pub rules: Vec<KtWeaponRule>,
}

impl Default for KtWeaponProfile {
    fn default() -> Self {
        Self {
            name: "Boltgun".to_string(),
            weapon_type: KtWeaponType::Ranged,
            attacks: 4,
            hit: 3,
            normal_damage: 3,
            critical_damage: 4,
            rules: Vec::new(),
        }
    }
}

impl KtWeaponProfile {
    pub fn new(
        name: impl Into<String>,
        weapon_type: KtWeaponType,
        attacks: u32,
        hit: u32,
        normal_damage: u32,
        critical_damage: u32,
        rules: Vec<KtWeaponRule>,
    ) -> Self {
        Self {
            name: name.into(),
            weapon_type,
            attacks,
            hit,
            normal_damage,
            critical_damage,
            rules,
        }
    }

    pub fn is_ranged(&self) -> bool {
        self.weapon_type == KtWeaponType::Ranged
    }

    pub fn is_melee(&self) -> bool {
        self.weapon_type == KtWeaponType::Melee
    }

    pub fn accurate_value(&self) -> u32 {
        self.rules
            .iter()
            .filter_map(|r| match r {
                KtWeaponRule::Accurate(x) => Some(*x),
                _ => None,
            })
            .max()
            .unwrap_or(0)
    }

    pub fn has_balanced(&self) -> bool {
        self.rules
            .iter()
            .any(|r| matches!(r, KtWeaponRule::Balanced))
    }

    pub fn has_ceaseless(&self) -> bool {
        self.rules
            .iter()
            .any(|r| matches!(r, KtWeaponRule::Ceaseless))
    }

    pub fn has_relentless(&self) -> bool {
        self.rules
            .iter()
            .any(|r| matches!(r, KtWeaponRule::Relentless))
    }

    pub fn lethal_threshold(&self) -> u32 {
        self.rules
            .iter()
            .filter_map(|r| match r {
                KtWeaponRule::Lethal(x) => Some((*x).clamp(2, 6)),
                _ => None,
            })
            .min()
            .unwrap_or(6)
    }

    pub fn has_rending(&self) -> bool {
        self.rules
            .iter()
            .any(|r| matches!(r, KtWeaponRule::Rending))
    }

    pub fn has_severe(&self) -> bool {
        self.rules.iter().any(|r| matches!(r, KtWeaponRule::Severe))
    }

    pub fn has_punishing(&self) -> bool {
        self.rules
            .iter()
            .any(|r| matches!(r, KtWeaponRule::Punishing))
    }

    pub fn devastating_value(&self) -> u32 {
        self.rules
            .iter()
            .filter_map(|r| match r {
                KtWeaponRule::Devastating(x) => Some(*x),
                _ => None,
            })
            .max()
            .unwrap_or(0)
    }

    pub fn piercing_value(&self) -> u32 {
        self.rules
            .iter()
            .filter_map(|r| match r {
                KtWeaponRule::Piercing(x) => Some(*x),
                _ => None,
            })
            .max()
            .unwrap_or(0)
    }

    pub fn piercing_crits_value(&self) -> u32 {
        self.rules
            .iter()
            .filter_map(|r| match r {
                KtWeaponRule::PiercingCrits(x) => Some(*x),
                _ => None,
            })
            .max()
            .unwrap_or(0)
    }

    pub fn has_saturate(&self) -> bool {
        self.rules
            .iter()
            .any(|r| matches!(r, KtWeaponRule::Saturate))
    }

    pub fn has_seek(&self) -> bool {
        self.rules
            .iter()
            .any(|r| matches!(r, KtWeaponRule::Seek | KtWeaponRule::SeekLight))
    }

    pub fn has_hot(&self) -> bool {
        self.rules.iter().any(|r| matches!(r, KtWeaponRule::Hot))
    }

    pub fn has_brutal(&self) -> bool {
        self.rules.iter().any(|r| matches!(r, KtWeaponRule::Brutal))
    }

    pub fn has_shock(&self) -> bool {
        self.rules.iter().any(|r| matches!(r, KtWeaponRule::Shock))
    }

    pub fn has_stun(&self) -> bool {
        self.rules.iter().any(|r| matches!(r, KtWeaponRule::Stun))
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KtAbilityData {
    pub name: String,
    pub description: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OperativeDatacard {
    pub id: String,
    pub name: String,
    pub faction_id: String,
    pub faction_name: String,
    /// e.g. "Leader", "Specialist", "Warrior", "Gunner", "Heavy Gunner", "Sniper"
    pub role: String,
    pub apl: u32,
    pub movement: u32,
    pub save: u32,
    pub wounds: u32,
    #[serde(default)]
    pub weapons: Vec<KtWeaponProfile>,
    #[serde(default)]
    pub abilities: Vec<KtAbilityData>,
    #[serde(default)]
    pub keywords: Vec<String>,
    /// Maximum copies of this operative datacard allowed in a single Kill Team roster (usually 1 for Leader/Specialist, >1 for Warrior/Trooper).
    pub max_per_kill_team: u32,
}

impl Default for OperativeDatacard {
    fn default() -> Self {
        Self {
            id: "kt-op-default".to_string(),
            name: "Assault Intercessor Warrior".to_string(),
            faction_id: "kt-angels-of-death".to_string(),
            faction_name: "Angels of Death".to_string(),
            role: "Warrior".to_string(),
            apl: 3,
            movement: 6,
            save: 3,
            wounds: 14,
            weapons: vec![
                KtWeaponProfile::new(
                    "Heavy Bolt Pistol",
                    KtWeaponType::Ranged,
                    4,
                    3,
                    3,
                    4,
                    vec![KtWeaponRule::Range(8), KtWeaponRule::PiercingCrits(1)],
                ),
                KtWeaponProfile::new(
                    "Chainsword",
                    KtWeaponType::Melee,
                    5,
                    3,
                    4,
                    5,
                    vec![],
                ),
            ],
            abilities: Vec::new(),
            keywords: vec![
                "ANGEL OF DEATH".to_string(),
                "IMPERIUM".to_string(),
                "ADEPTUS ASTARTES".to_string(),
                "WARRIOR".to_string(),
            ],
            max_per_kill_team: 5,
        }
    }
}

impl OperativeDatacard {
    pub fn is_leader(&self) -> bool {
        self.role.eq_ignore_ascii_case("Leader")
            || self
                .keywords
                .iter()
                .any(|k| k.eq_ignore_ascii_case("LEADER"))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum KtPloyType {
    Strategy,
    Firefight,
}

impl KtPloyType {
    pub fn label(&self) -> &'static str {
        match self {
            KtPloyType::Strategy => "Strategy Ploy",
            KtPloyType::Firefight => "Firefight Ploy",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KtPloy {
    pub id: String,
    pub name: String,
    pub ploy_type: KtPloyType,
    pub cp_cost: u32,
    pub description: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KtEquipment {
    pub id: String,
    pub name: String,
    pub is_universal: bool,
    pub description: String,
    #[serde(default)]
    pub granted_weapon: Option<KtWeaponProfile>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KillTeamFaction {
    pub id: String,
    pub slug: String,
    pub name: String,
    /// Superfaction: "Imperium", "Chaos", "Xenos"
    pub superfaction: String,
    /// e.g. ["Security", "Seek & Destroy"]
    pub archetypes: Vec<String>,
    pub faction_rules: Vec<KtAbilityData>,
    /// Required operative count (including Leader) for a legal Kill Team on the killzone (e.g. 6 for Angels of Death, 10 for Kasrkin, 14 for Death Korps).
    pub team_size: u32,
    pub min_team_size: u32,
    pub max_team_size: u32,
    pub operatives: Vec<OperativeDatacard>,
    pub ploys: Vec<KtPloy>,
    pub equipment: Vec<KtEquipment>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct KillTeamCatalogueDatabase {
    pub provenance: KtDataProvenance,
    pub factions: Vec<KillTeamFaction>,
    pub universal_equipment: Vec<KtEquipment>,
}

impl KillTeamCatalogueDatabase {
    pub fn find_faction(&self, id_or_slug_or_name: &str) -> Option<&KillTeamFaction> {
        let q = id_or_slug_or_name.trim();
        self.factions.iter().find(|f| {
            f.id.eq_ignore_ascii_case(q)
                || f.slug.eq_ignore_ascii_case(q)
                || f.name.eq_ignore_ascii_case(q)
        })
    }

    pub fn search_operatives(
        &self,
        query: &str,
        faction_filter: Option<&str>,
        role_filter: Option<&str>,
    ) -> Vec<&OperativeDatacard> {
        let q = query.trim().to_lowercase();
        let mut results = Vec::new();
        for f in &self.factions {
            if let Some(ff) = faction_filter {
                if !ff.is_empty()
                    && !f.id.eq_ignore_ascii_case(ff)
                    && !f.slug.eq_ignore_ascii_case(ff)
                    && !f.name.eq_ignore_ascii_case(ff)
                {
                    continue;
                }
            }
            for op in &f.operatives {
                if let Some(rf) = role_filter {
                    if !rf.is_empty() && !op.role.eq_ignore_ascii_case(rf) {
                        continue;
                    }
                }
                if q.is_empty()
                    || op.name.to_lowercase().contains(&q)
                    || op.faction_name.to_lowercase().contains(&q)
                    || op.role.to_lowercase().contains(&q)
                    || op.keywords.iter().any(|k| k.to_lowercase().contains(&q))
                    || op.weapons.iter().any(|w| w.name.to_lowercase().contains(&q))
                {
                    results.push(op);
                }
            }
        }
        results
    }
}
