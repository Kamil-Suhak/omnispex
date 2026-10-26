use super::dice::ValueExpr;
use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum ReRollMode {
    #[default]
    None,
    Ones,
    Full,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Keyword {
    Infantry,
    Vehicle,
    Monster,
    Mounted,
    Character,
    EpicHero,
    Battleline,
    DedicatedTransport,
    Psyker,
    Fly,
    Swarm,
    Beast,
    Titanic,
    Towering,
    Walker,
    Smoke,
    Grenades,
    Custom(String),
}

impl Keyword {
    pub fn matches(&self, other: &Keyword) -> bool {
        match (self, other) {
            (Keyword::Custom(a), Keyword::Custom(b)) => a.eq_ignore_ascii_case(b),
            (Keyword::Custom(a), standard) | (standard, Keyword::Custom(a)) => {
                standard.to_string().eq_ignore_ascii_case(a)
            }
            (a, b) => a == b,
        }
    }
}

impl fmt::Display for Keyword {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Keyword::Infantry => write!(f, "INFANTRY"),
            Keyword::Vehicle => write!(f, "VEHICLE"),
            Keyword::Monster => write!(f, "MONSTER"),
            Keyword::Mounted => write!(f, "MOUNTED"),
            Keyword::Character => write!(f, "CHARACTER"),
            Keyword::EpicHero => write!(f, "EPIC HERO"),
            Keyword::Battleline => write!(f, "BATTLELINE"),
            Keyword::DedicatedTransport => write!(f, "DEDICATED TRANSPORT"),
            Keyword::Psyker => write!(f, "PSYKER"),
            Keyword::Fly => write!(f, "FLY"),
            Keyword::Swarm => write!(f, "SWARM"),
            Keyword::Beast => write!(f, "BEAST"),
            Keyword::Titanic => write!(f, "TITANIC"),
            Keyword::Towering => write!(f, "TOWERING"),
            Keyword::Walker => write!(f, "WALKER"),
            Keyword::Smoke => write!(f, "SMOKE"),
            Keyword::Grenades => write!(f, "GRENADES"),
            Keyword::Custom(name) => write!(f, "{}", name.to_uppercase()),
        }
    }
}

impl From<&str> for Keyword {
    fn from(s: &str) -> Self {
        match s.trim().to_uppercase().as_str() {
            "INFANTRY" => Keyword::Infantry,
            "VEHICLE" => Keyword::Vehicle,
            "MONSTER" => Keyword::Monster,
            "MOUNTED" => Keyword::Mounted,
            "CHARACTER" => Keyword::Character,
            "EPIC HERO" | "EPIC_HERO" => Keyword::EpicHero,
            "BATTLELINE" => Keyword::Battleline,
            "DEDICATED TRANSPORT" | "DEDICATED_TRANSPORT" => Keyword::DedicatedTransport,
            "PSYKER" => Keyword::Psyker,
            "FLY" => Keyword::Fly,
            "SWARM" => Keyword::Swarm,
            "BEAST" => Keyword::Beast,
            "TITANIC" => Keyword::Titanic,
            "TOWERING" => Keyword::Towering,
            "WALKER" => Keyword::Walker,
            "SMOKE" => Keyword::Smoke,
            "GRENADES" => Keyword::Grenades,
            other => Keyword::Custom(other.to_string()),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum WeaponAbility {
    Torrent,
    LethalHits,
    SustainedHits(u32),
    DevastatingWounds,
    TwinLinked,
    Blast,
    RapidFire(u32),
    Melta(u32),
    IgnoresCover,
    Heavy,
    Lance,
    IndirectFire,
    Precision,
    Hazardous,
    Assault,
    Pistol,
    CloseQuarters,
    ExtraAttacks,
    OneShot,
    Psychic,
    Anti { target: Keyword, threshold: u32 },
    Custom(String),
}

impl WeaponAbility {
    pub fn display_label(&self) -> String {
        match self {
            WeaponAbility::Torrent => "Torrent".to_string(),
            WeaponAbility::LethalHits => "Lethal Hits".to_string(),
            WeaponAbility::SustainedHits(x) => format!("Sustained Hits {}", x),
            WeaponAbility::DevastatingWounds => "Devastating Wounds".to_string(),
            WeaponAbility::TwinLinked => "Twin-Linked".to_string(),
            WeaponAbility::Blast => "Blast".to_string(),
            WeaponAbility::RapidFire(x) => format!("Rapid Fire {}", x),
            WeaponAbility::Melta(x) => format!("Melta {}", x),
            WeaponAbility::IgnoresCover => "Ignores Cover".to_string(),
            WeaponAbility::Heavy => "Heavy".to_string(),
            WeaponAbility::Lance => "Lance".to_string(),
            WeaponAbility::IndirectFire => "Indirect Fire".to_string(),
            WeaponAbility::Precision => "Precision".to_string(),
            WeaponAbility::Hazardous => "Hazardous".to_string(),
            WeaponAbility::Assault => "Assault".to_string(),
            WeaponAbility::Pistol => "Pistol".to_string(),
            WeaponAbility::CloseQuarters => "Close-Quarters".to_string(),
            WeaponAbility::ExtraAttacks => "Extra Attacks".to_string(),
            WeaponAbility::OneShot => "One Shot".to_string(),
            WeaponAbility::Psychic => "Psychic".to_string(),
            WeaponAbility::Anti { target, threshold } => format!("Anti-{} {}+", target, threshold),
            WeaponAbility::Custom(raw) => raw.clone(),
        }
    }

    /// Returns whether this weapon ability has a direct numerical effect in the combat resolution pipeline,
    /// or is a declaration/post-volley/informational rule.
    pub fn is_informational_or_unsupported_in_math(&self) -> Option<&'static str> {
        match self {
            WeaponAbility::Precision => Some("Precision allows allocating attacks to an attached Character visible to the bearer (modeled when targeting the Character directly)."),
            WeaponAbility::Hazardous => Some("Hazardous triggers a post-volley D6 check per weapon fired (on 1, bearer's unit suffers 3 mortal wounds or model loss)."),
            WeaponAbility::Assault => Some("Assault allows shooting after Advancing (declaration eligibility rule; no direct roll modifier)."),
            WeaponAbility::Pistol | WeaponAbility::CloseQuarters => Some("Pistol / Close-Quarters allows shooting while within Engagement Range (declaration eligibility rule)."),
            WeaponAbility::ExtraAttacks => Some("Extra Attacks prevents the attack count from being modified by external abilities."),
            WeaponAbility::OneShot => Some("One Shot weapons can only be fired once per battle."),
            WeaponAbility::Psychic => Some("Psychic tags the attack as Psychic (interacts with Feel No Pain vs Psychic abilities)."),
            WeaponAbility::Custom(_) => Some("Custom or faction-specific weapon ability is displayed for reference and not automatically simulated."),
            _ => None,
        }
    }
}

impl fmt::Display for WeaponAbility {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.display_label())
    }
}

fn default_profile_name() -> String {
    "Standard".to_string()
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WeaponProfile {
    pub name: String,
    #[serde(default = "default_profile_name")]
    pub profile_name: String,
    pub range: u32,
    pub attacks: ValueExpr,
    pub skill: u32,
    pub strength: u32,
    pub ap: u32,
    pub damage: ValueExpr,
    #[serde(default)]
    pub abilities: Vec<WeaponAbility>,
}

impl Default for WeaponProfile {
    fn default() -> Self {
        Self::new(
            "Bolt Rifle",
            24,
            ValueExpr::Flat(2),
            3,
            4,
            1,
            ValueExpr::Flat(1),
            Vec::new(),
        )
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WeaponLoadoutEntry {
    pub weapon: WeaponProfile,
    pub count: u32,
    #[serde(default = "default_true")]
    pub enabled: bool,
}

impl WeaponLoadoutEntry {
    pub fn new(weapon: WeaponProfile, count: u32) -> Self {
        Self {
            weapon,
            count: count.max(1),
            enabled: true,
        }
    }
}

impl WeaponProfile {
    pub fn new(
        name: impl Into<String>,
        range: u32,
        attacks: ValueExpr,
        skill: u32,
        strength: u32,
        ap: u32,
        damage: ValueExpr,
        abilities: Vec<WeaponAbility>,
    ) -> Self {
        let name_str = name.into();
        let (base_name, profile_name) = if let Some((base, prof)) = name_str.split_once(" - ") {
            (base.trim().to_string(), prof.trim().to_string())
        } else {
            (
                name_str,
                if range == 0 {
                    "Melee".to_string()
                } else {
                    "Standard".to_string()
                },
            )
        };
        Self {
            name: base_name,
            profile_name,
            range,
            attacks,
            skill,
            strength,
            ap,
            damage,
            abilities,
        }
    }

    pub fn with_profile_name(mut self, profile_name: impl Into<String>) -> Self {
        self.profile_name = profile_name.into();
        self
    }

    pub fn is_melee(&self) -> bool {
        self.range == 0
    }

    pub fn is_ranged(&self) -> bool {
        self.range > 0
    }

    pub fn has_torrent(&self) -> bool {
        self.abilities
            .iter()
            .any(|a| matches!(a, WeaponAbility::Torrent))
    }

    pub fn has_lethal_hits(&self) -> bool {
        self.abilities
            .iter()
            .any(|a| matches!(a, WeaponAbility::LethalHits))
    }

    pub fn sustained_hits_value(&self) -> Option<u32> {
        self.abilities.iter().find_map(|a| match a {
            WeaponAbility::SustainedHits(x) => Some(*x),
            _ => None,
        })
    }

    pub fn has_devastating_wounds(&self) -> bool {
        self.abilities
            .iter()
            .any(|a| matches!(a, WeaponAbility::DevastatingWounds))
    }

    pub fn has_twin_linked(&self) -> bool {
        self.abilities
            .iter()
            .any(|a| matches!(a, WeaponAbility::TwinLinked))
    }

    pub fn has_blast(&self) -> bool {
        self.abilities
            .iter()
            .any(|a| matches!(a, WeaponAbility::Blast))
    }

    pub fn rapid_fire_bonus(&self) -> Option<u32> {
        self.abilities.iter().find_map(|a| match a {
            WeaponAbility::RapidFire(x) => Some(*x),
            _ => None,
        })
    }

    pub fn melta_bonus(&self) -> Option<u32> {
        self.abilities.iter().find_map(|a| match a {
            WeaponAbility::Melta(x) => Some(*x),
            _ => None,
        })
    }

    pub fn has_ignores_cover(&self) -> bool {
        self.abilities
            .iter()
            .any(|a| matches!(a, WeaponAbility::IgnoresCover))
    }

    pub fn has_heavy(&self) -> bool {
        self.abilities
            .iter()
            .any(|a| matches!(a, WeaponAbility::Heavy))
    }

    pub fn has_lance(&self) -> bool {
        self.abilities
            .iter()
            .any(|a| matches!(a, WeaponAbility::Lance))
    }

    pub fn has_indirect_fire(&self) -> bool {
        self.abilities
            .iter()
            .any(|a| matches!(a, WeaponAbility::IndirectFire))
    }

    pub fn has_assault(&self) -> bool {
        self.abilities
            .iter()
            .any(|a| matches!(a, WeaponAbility::Assault))
    }

    pub fn anti_threshold_for(&self, target_keywords: &[Keyword]) -> Option<u32> {
        self.abilities
            .iter()
            .filter_map(|a| match a {
                WeaponAbility::Anti { target, threshold } => {
                    if target_keywords.iter().any(|kw| target.matches(kw)) {
                        Some(*threshold)
                    } else {
                        None
                    }
                }
                _ => None,
            })
            .min()
    }
}

pub fn parse_weapon_ability(s: &str) -> Option<WeaponAbility> {
    let clean = s
        .trim()
        .trim_matches(|c| c == '[' || c == ']' || c == '(' || c == ')')
        .trim();
    if clean.is_empty() || clean == "-" {
        return None;
    }
    let upper = clean.to_uppercase();

    match upper.as_str() {
        "TORRENT" => return Some(WeaponAbility::Torrent),
        "LETHAL HITS" => return Some(WeaponAbility::LethalHits),
        "DEVASTATING WOUNDS" => return Some(WeaponAbility::DevastatingWounds),
        "TWIN-LINKED" | "TWIN LINKED" => return Some(WeaponAbility::TwinLinked),
        "BLAST" => return Some(WeaponAbility::Blast),
        "IGNORES COVER" => return Some(WeaponAbility::IgnoresCover),
        "HEAVY" => return Some(WeaponAbility::Heavy),
        "LANCE" => return Some(WeaponAbility::Lance),
        "INDIRECT FIRE" => return Some(WeaponAbility::IndirectFire),
        "PRECISION" => return Some(WeaponAbility::Precision),
        "HAZARDOUS" => return Some(WeaponAbility::Hazardous),
        "ASSAULT" => return Some(WeaponAbility::Assault),
        "PISTOL" => return Some(WeaponAbility::Pistol),
        "CLOSE-QUARTERS" | "CLOSE QUARTERS" => return Some(WeaponAbility::CloseQuarters),
        "EXTRA ATTACKS" => return Some(WeaponAbility::ExtraAttacks),
        "ONE SHOT" | "ONE-SHOT" => return Some(WeaponAbility::OneShot),
        "PSYCHIC" => return Some(WeaponAbility::Psychic),
        _ => {}
    }

    if let Some(rest) = upper.strip_prefix("SUSTAINED HITS") {
        let val_str = rest.trim();
        if let Ok(val) = val_str.parse::<u32>() {
            return Some(WeaponAbility::SustainedHits(val));
        }
        if val_str == "D3" {
            return Some(WeaponAbility::SustainedHits(2));
        }
    }

    if let Some(rest) = upper.strip_prefix("RAPID FIRE") {
        let val_str = rest.trim();
        if let Ok(val) = val_str.parse::<u32>() {
            return Some(WeaponAbility::RapidFire(val));
        }
        if val_str == "D3" {
            return Some(WeaponAbility::RapidFire(2));
        }
        if val_str == "D6" {
            return Some(WeaponAbility::RapidFire(3));
        }
    }

    if let Some(rest) = upper.strip_prefix("MELTA") {
        let val_str = rest.trim();
        if let Ok(val) = val_str.parse::<u32>() {
            return Some(WeaponAbility::Melta(val));
        }
        if val_str == "D3" {
            return Some(WeaponAbility::Melta(2));
        }
    }

    if let Some(rest) = upper.strip_prefix("ANTI-") {
        if let Some((target_part, threshold_part)) = rest.rsplit_once(' ') {
            let threshold_clean = threshold_part.trim_end_matches('+');
            if let Ok(threshold) = threshold_clean.parse::<u32>() {
                return Some(WeaponAbility::Anti {
                    target: Keyword::from(target_part.trim()),
                    threshold,
                });
            }
        }
    }

    None
}
