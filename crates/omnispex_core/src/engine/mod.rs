pub mod context;
pub mod pipeline;
pub mod simulator;

pub use context::CombatContext;
pub use pipeline::{find_allocated_model_index, required_wound_roll, resolve_volley, VolleyOutcome, WoundKind};
pub use simulator::{run_simulation, SimulationReport};
