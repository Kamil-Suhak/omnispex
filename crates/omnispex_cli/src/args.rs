use clap::{Args, Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "omnispex_cli")]
#[command(author, version, about = "Warhammer 40k Attack Resolution & Probability Engine", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Run an ad-hoc combat simulation from manual parameters
    Simulate(SimulateArgs),
    /// Run simulation between two JSON profile files and print ASCII distribution report
    RunMatchup(RunMatchupArgs),
}

#[derive(Args, Debug)]
pub struct SimulateArgs {
    #[arg(long, default_value = "Attacker Weapon")]
    pub weapon_name: String,

    #[arg(long, default_value = "1")]
    pub attacks: String,

    #[arg(long, default_value_t = 3)]
    pub bs: u32,

    #[arg(long = "str", default_value_t = 4)]
    pub strength: u32,

    #[arg(long, default_value_t = 0)]
    pub ap: u32,

    #[arg(long = "dmg", default_value = "1")]
    pub damage: String,

    #[arg(long, default_value_t = 24)]
    pub range: u32,

    #[arg(long, value_delimiter = ',')]
    pub abilities: Vec<String>,

    #[arg(long, default_value = "Defender Unit")]
    pub target_name: String,

    #[arg(long = "target-t", default_value_t = 4)]
    pub target_t: u32,

    #[arg(long = "target-sv", default_value_t = 3)]
    pub target_sv: u32,

    #[arg(long = "target-w", default_value_t = 1)]
    pub target_w: u32,

    #[arg(long = "target-count", default_value_t = 5)]
    pub target_count: usize,

    #[arg(long = "target-invuln")]
    pub target_invuln: Option<u32>,

    #[arg(long = "target-fnp")]
    pub target_fnp: Option<u32>,

    #[arg(long = "target-keywords", value_delimiter = ',')]
    pub target_keywords: Vec<String>,

    #[arg(long, default_value_t = 10000)]
    pub iterations: u32,

    #[arg(long)]
    pub distance: Option<u32>,

    #[arg(long)]
    pub stationary: bool,

    #[arg(long)]
    pub charged: bool,

    #[arg(long)]
    pub cover: bool,

    #[arg(long)]
    pub in_engagement: bool,
}

#[derive(Args, Debug)]
pub struct RunMatchupArgs {
    #[arg(short = 'a', long = "attacker")]
    pub attacker: PathBuf,

    #[arg(short = 'd', long = "defender")]
    pub defender: PathBuf,

    #[arg(short = 'i', long, default_value_t = 10000)]
    pub iterations: u32,

    #[arg(long)]
    pub distance: Option<u32>,

    #[arg(long)]
    pub stationary: bool,

    #[arg(long)]
    pub charged: bool,

    #[arg(long)]
    pub cover: bool,
}
