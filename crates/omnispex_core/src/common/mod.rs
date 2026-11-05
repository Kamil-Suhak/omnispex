use serde::{Deserialize, Serialize};

/// Top-level game system selector used by the application shell and storage layer.
/// Individual game modules (`wh40k` and `kill_team`) do not depend on each other.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum GameSystem {
    #[serde(
        rename = "wh40k",
        alias = "Warhammer40k",
        alias = "warhammer40k",
        alias = "40k"
    )]
    Warhammer40k,
    #[serde(
        rename = "kill_team",
        alias = "KillTeam",
        alias = "killteam",
        alias = "kt"
    )]
    KillTeam,
}

impl Default for GameSystem {
    fn default() -> Self {
        Self::Warhammer40k
    }
}

impl GameSystem {
    pub fn label(&self) -> &'static str {
        match self {
            GameSystem::Warhammer40k => "Warhammer 40,000 (11e)",
            GameSystem::KillTeam => "Kill Team (2024)",
        }
    }

    pub fn as_key(&self) -> &'static str {
        match self {
            GameSystem::Warhammer40k => "wh40k",
            GameSystem::KillTeam => "kill_team",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TacticalVerdict {
    GreenReliableKill,
    AmberChipDamage,
    RedIneffective,
}

impl TacticalVerdict {
    pub fn label(&self) -> &'static str {
        match self {
            TacticalVerdict::GreenReliableKill => "RELIABLE KILL (HIGH EFFICIENCY)",
            TacticalVerdict::AmberChipDamage => "CHIP DAMAGE / BRACKET THREAT",
            TacticalVerdict::RedIneffective => "INEFFECTIVE / BOUNCE RISK",
        }
    }

    pub fn from_probabilities(kill_or_wipe_prob: f64, half_damage_prob: f64, expected_dmg: f64) -> Self {
        if kill_or_wipe_prob >= 0.80 {
            TacticalVerdict::GreenReliableKill
        } else if kill_or_wipe_prob >= 0.25 || half_damage_prob >= 0.50 || expected_dmg >= 4.0 {
            TacticalVerdict::AmberChipDamage
        } else {
            TacticalVerdict::RedIneffective
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct PercentilesReport {
    pub p10: u32,
    pub p25: u32,
    pub p50: u32,
    pub p75: u32,
    pub p90: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub enum WishlistPriority {
    Low,
    Medium,
    High,
    Critical,
}

impl Default for WishlistPriority {
    fn default() -> Self {
        Self::Medium
    }
}

impl WishlistPriority {
    pub fn label(&self) -> &'static str {
        match self {
            WishlistPriority::Low => "Low",
            WishlistPriority::Medium => "Medium",
            WishlistPriority::High => "High",
            WishlistPriority::Critical => "Critical",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub enum AcquisitionState {
    Wishlist,
    Ordered,
    OwnedInBox,
    Assembled,
    Primed,
    BattleReady,
    ParadeReady,
}

impl Default for AcquisitionState {
    fn default() -> Self {
        Self::Wishlist
    }
}

impl AcquisitionState {
    pub fn label(&self) -> &'static str {
        match self {
            AcquisitionState::Wishlist => "To Buy (Wishlist)",
            AcquisitionState::Ordered => "Ordered / In Transit",
            AcquisitionState::OwnedInBox => "Owned (In Box / Sprue)",
            AcquisitionState::Assembled => "Assembled",
            AcquisitionState::Primed => "Primed",
            AcquisitionState::BattleReady => "Battle Ready",
            AcquisitionState::ParadeReady => "Parade Ready",
        }
    }

    pub fn is_owned(&self) -> bool {
        !matches!(self, AcquisitionState::Wishlist | AcquisitionState::Ordered)
    }

    pub fn is_painted(&self) -> bool {
        matches!(
            self,
            AcquisitionState::BattleReady | AcquisitionState::ParadeReady
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum WishlistSortField {
    PriorityDesc,
    NameAsc,
    FactionAsc,
    PointsDesc,
    StateAsc,
}

impl Default for WishlistSortField {
    fn default() -> Self {
        Self::PriorityDesc
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum MatchResult {
    Win,
    Loss,
    Draw,
    InProgress,
}

impl Default for MatchResult {
    fn default() -> Self {
        Self::InProgress
    }
}

impl MatchResult {
    pub fn from_scores(player_score: u32, opponent_score: u32) -> Self {
        if player_score > opponent_score {
            MatchResult::Win
        } else if player_score < opponent_score {
            MatchResult::Loss
        } else {
            MatchResult::Draw
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            MatchResult::Win => "WIN",
            MatchResult::Loss => "LOSS",
            MatchResult::Draw => "DRAW",
            MatchResult::InProgress => "IN PROGRESS",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct FactionPerformance {
    pub faction: String,
    pub games_played: u32,
    pub wins: u32,
    pub losses: u32,
    pub draws: u32,
    pub win_rate_percent: f64,
    pub average_player_score: f64,
    pub average_opponent_score: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct MatchStatisticsReport {
    pub total_completed_games: u32,
    pub in_progress_games: u32,
    pub wins: u32,
    pub losses: u32,
    pub draws: u32,
    pub win_rate_percent: f64,
    pub average_player_score: f64,
    pub average_opponent_score: f64,
    pub average_differential: f64,
    pub by_player_faction: Vec<FactionPerformance>,
    pub by_opponent_faction: Vec<FactionPerformance>,
    pub scope_explanation: String,
}
