use super::dice::ValueExpr;
use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Keyword {
    Infantry,
    Vehicle,
    Monster,
    Mounted,
    Character,
    Psyker,
    Fly,
    Swarm,
    Beast,
    Titanic,
    Towering,
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
            Keyword::Psyker => write!(f, "PSYKER"),
            Keyword::Fly => write!(f, "FLY"),
            Keyword::Swarm => write!(f, "SWARM"),
            Keyword::Beast => write!(f, "BEAST"),
            Keyword::Titanic => write!(f, "TITANIC"),
            Keyword::Towering => write!(f, "TOWERING"),
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
            "PSYKER" => Keyword::Psyker,
            "FLY" => Keyword::Fly,
            "SWARM" => Keyword::Swarm,
            "BEAST" => Keyword::Beast,
            "TITANIC" => Keyword::Titanic,
            "TOWERING" => Keyword::Towering,
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
    ExtraAttacks,
    Anti { target: Keyword, threshold: u32 },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WeaponProfile {
    pub name: String,
    pub range: u32,
    pub attacks: ValueExpr,
    pub skill: u32,
    pub strength: u32,
    pub ap: u32,
    pub damage: ValueExpr,
    pub abilities: Vec<WeaponAbility>,
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
        Self {
            name: name.into(),
            range,
            attacks,
            skill,
            strength,
            ap,
            damage,
            abilities,
        }
    }

    pub fn has_torrent(&self) -> bool {
        self.abilities.iter().any(|a| matches!(a, WeaponAbility::Torrent))
    }

    pub fn has_lethal_hits(&self) -> bool {
        self.abilities.iter().any(|a| matches!(a, WeaponAbility::LethalHits))
    }

    pub fn sustained_hits_value(&self) -> Option<u32> {
        self.abilities.iter().find_map(|a| match a {
            WeaponAbility::SustainedHits(x) => Some(*x),
            _ => None,
        })
    }

    pub fn has_devastating_wounds(&self) -> bool {
        self.abilities.iter().any(|a| matches!(a, WeaponAbility::DevastatingWounds))
    }

    pub fn has_twin_linked(&self) -> bool {
        self.abilities.iter().any(|a| matches!(a, WeaponAbility::TwinLinked))
    }

    pub fn has_blast(&self) -> bool {
        self.abilities.iter().any(|a| matches!(a, WeaponAbility::Blast))
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
        self.abilities.iter().any(|a| matches!(a, WeaponAbility::IgnoresCover))
    }

    pub fn has_heavy(&self) -> bool {
        self.abilities.iter().any(|a| matches!(a, WeaponAbility::Heavy))
    }

    pub fn has_lance(&self) -> bool {
        self.abilities.iter().any(|a| matches!(a, WeaponAbility::Lance))
    }

    pub fn has_indirect_fire(&self) -> bool {
        self.abilities.iter().any(|a| matches!(a, WeaponAbility::IndirectFire))
    }

    pub fn anti_threshold_for(&self, target_keywords: &[Keyword]) -> Option<u32> {
        self.abilities.iter().find_map(|a| match a {
            WeaponAbility::Anti { target, threshold } => {
                if target_keywords.iter().any(|kw| target.matches(kw)) {
                    Some(*threshold)
                } else {
                    None
                }
            }
            _ => None,
        })
    }
}
