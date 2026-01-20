//! GHOSTNET Indexer CLI
//!
//! Entry point for the indexer binary. Provides subcommands for:
//! - `run` - Start the indexer
//! - `migrate` - Run database migrations
//! - `backfill` - Backfill historical data

use clap::{Parser, Subcommand};
use tracing::info;

/// GHOSTNET Event Indexer
#[derive(Parser, Debug)]
#[command(name = "ghostnet-indexer")]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Subcommand to execute
    #[command(subcommand)]
    command: Commands,

    /// Configuration file path
    #[arg(short, long, default_value = "config/default.toml")]
    config: String,

    /// Enable verbose logging
    #[arg(short, long)]
    verbose: bool,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Run the indexer
    Run {
        /// Start from a specific block number
        #[arg(long)]
        from_block: Option<u64>,
    },

    /// Run database migrations
    Migrate {
        /// Revert migrations instead of applying
        #[arg(long)]
        revert: bool,
    },

    /// Backfill historical data
    Backfill {
        /// Starting block number
        #[arg(long)]
        from: u64,

        /// Ending block number
        #[arg(long)]
        to: u64,
    },

    /// Show version information
    Version,
}

fn main() {
    // Parse CLI arguments
    let cli = Cli::parse();

    // Initialize logging
    // TODO: Replace with proper tracing setup from config
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive(tracing::Level::INFO.into()),
        )
        .init();

    info!(
        version = ghostnet_indexer::VERSION,
        "Starting GHOSTNET Indexer"
    );
    info!(config = %cli.config, "Using configuration file");

    // Execute the subcommand
    match cli.command {
        Commands::Run { from_block } => {
            info!(?from_block, "Running indexer");
            // TODO: Implement indexer startup
            println!("Indexer run command - not yet implemented");
        }
        Commands::Migrate { revert } => {
            if revert {
                info!("Reverting migrations");
            } else {
                info!("Running migrations");
            }
            // TODO: Implement migration
            println!("Migration command - not yet implemented");
        }
        Commands::Backfill { from, to } => {
            info!(from, to, "Running backfill");
            // TODO: Implement backfill
            println!("Backfill command - not yet implemented");
        }
        Commands::Version => {
            println!("ghostnet-indexer {}", ghostnet_indexer::VERSION);
        }
    }
}
