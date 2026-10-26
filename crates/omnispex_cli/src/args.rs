use clap::{Args, Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "omnispex_cli")]
#[command(
    author,
    version,
    about = "Omnispex — Warhammer 40,000 & Kill Team Companion CLI (Math, Catalogues, Rosters, Match Stats)",
    long_about = None
)]
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
    /// Build a normalized CatalogueDatabase JSON bundle from BSData wh40k-11e and wh40k-11e-mfm directories
    BuildCatalogueBundle(BuildCatalogueBundleArgs),
    /// Search normalized units, weapons, and points across a CatalogueDatabase bundle
    SearchUnits(SearchUnitsArgs),
    /// Validate an ArmyList JSON file against 11th Edition rules and optionally print exported roster text
    ValidateList(ValidateListArgs),
    /// Compute Warhammer 40,000 or Kill Team match statistics from a PersonalDataStore JSON file
    MatchStats(MatchStatsArgs),
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

    /// Hit reroll mode: none, ones, full
    #[arg(long = "hit-reroll", default_value = "none")]
    pub hit_reroll: String,

    /// Wound reroll mode: none, ones, full
    #[arg(long = "wound-reroll", default_value = "none")]
    pub wound_reroll: String,

    /// Apply Armor of Contempt (-1 AP) on defender
    #[arg(long = "aoc")]
    pub armor_of_contempt: bool,
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

#[derive(Args, Debug)]
pub struct BuildCatalogueBundleArgs {
    /// Directory containing BSData wh40k-11e .json catalogue files
    #[arg(long = "bsdata-dir")]
    pub bsdata_dir: PathBuf,

    /// Directory containing BSData wh40k-11e-mfm data/*.yaml files
    #[arg(long = "mfm-dir")]
    pub mfm_dir: Option<PathBuf>,

    /// Output path for the normalized CatalogueDatabase JSON bundle
    #[arg(short = 'o', long = "output")]
    pub output: PathBuf,
}

#[derive(Args, Debug)]
pub struct SearchUnitsArgs {
    /// Path to normalized CatalogueDatabase JSON bundle
    #[arg(short = 'b', long = "bundle")]
    pub bundle: PathBuf,

    /// Search query (unit name, weapon, ability, or keyword)
    #[arg(short = 'q', long = "query", default_value = "")]
    pub query: String,

    /// Optional faction name or slug filter
    #[arg(short = 'f', long = "faction")]
    pub faction: Option<String>,

    /// Optional category filter (e.g. Infantry, Vehicle, Character, Battleline)
    #[arg(short = 'c', long = "category")]
    pub category: Option<String>,

    /// Include [Legends] units in search results
    #[arg(long = "legends")]
    pub include_legends: bool,
}

#[derive(Args, Debug)]
pub struct ValidateListArgs {
    /// Path to ArmyList JSON file
    #[arg(short = 'l', long = "list")]
    pub list: PathBuf,

    /// Optional path to CatalogueDatabase JSON bundle for MFM tier & detachment validation
    #[arg(short = 'b', long = "bundle")]
    pub bundle: Option<PathBuf>,

    /// Print formatted plain-text army roster export
    #[arg(long = "export-text")]
    pub export_text: bool,

    /// Fail with non-zero exit code if confirmed rule violations exist
    #[arg(long = "strict")]
    pub strict: bool,
}

#[derive(Args, Debug)]
pub struct MatchStatsArgs {
    /// Path to PersonalDataStore JSON file
    #[arg(short = 's', long = "store")]
    pub store: PathBuf,

    /// Optional game system filter: 40k or kill_team
    #[arg(long = "system")]
    pub system: Option<String>,

    /// Optional player faction filter
    #[arg(long = "faction")]
    pub faction: Option<String>,
}
