pub mod comparison;
pub mod context;
pub mod pipeline;
pub mod simulator;

pub use comparison::{
    compare_profiles, evaluate_archetypes, ArchetypeBenchmarkEntry, ArchetypeBenchmarkReport,
    ProfileComparisonEntry, ProfileComparisonReport,
};
pub use context::CombatContext;
pub use pipeline::{find_allocated_model_index, required_wound_roll, resolve_volley, VolleyOutcome, WoundKind, WoundSource};
pub use simulator::{run_simulation, KeywordAudit, PercentilesReport, SimulationReport, TacticalVerdict};
