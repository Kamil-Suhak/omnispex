pub mod archetypes;
pub mod army_list;
pub mod catalogue;
pub mod dice;
pub mod matches;
pub mod unit;
pub mod weapon;
pub mod wishlist;

pub use archetypes::{ArchetypeEntry, ArchetypeRoster};
pub use army_list::{
    export_army_list_text, validate_army_list, ArmyList, BattleSize, ListValidationReport,
    RosterUnitEntry, SelectedDetachment, SelectedWargearOption, ValidationIssue,
    ValidationSeverity,
};
pub use catalogue::{
    CatalogueDatabase, DataProvenance, DatasheetUnit, DetachmentData, EnhancementData,
    FactionCatalogue, PricingTier, RuleEntry, UnitCostOption, WargearCostOption,
};
pub use dice::ValueExpr;
pub use matches::{
    compute_match_statistics, default_kill_team_factions, filter_matches, FactionPerformance,
    GameSystem, KillTeamMatchDetails, KillTeamTurningPointScore, MatchRecord, MatchResult,
    MatchStatisticsReport, ScoreTrendPoint, Wh40kMatchDetails, Wh40kRoundScore,
};
pub use unit::{DefensiveAbility, ModelGroup, ModelProfile, UnitProfile};
pub use weapon::{
    parse_weapon_ability, Keyword, ReRollMode, WeaponAbility, WeaponLoadoutEntry, WeaponProfile,
};
pub use wishlist::{
    compute_wishlist_summary, filter_and_sort_wishlist, upsert_wishlist_item, AcquisitionState,
    WishlistItem, WishlistPriority, WishlistSortField, WishlistSummary,
};
