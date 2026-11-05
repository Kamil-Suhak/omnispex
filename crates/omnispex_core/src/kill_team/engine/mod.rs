pub mod fighting;
pub mod shooting;

pub use fighting::{
    resolve_optimal_kt_melee_duel, run_kt_fight_simulation, KtFightContext, KtFightReport,
};
pub use shooting::{
    compare_kt_weapons, resolve_optimal_kt_defense, run_kt_shooting_simulation,
    KtShootingContext, KtShootingReport, KtShootingStageProbabilities, KtWeaponComparisonEntry,
    KtWeaponComparisonReport,
};
