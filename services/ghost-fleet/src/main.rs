//! Ghost Fleet - GHOSTNET Wallet Automation Orchestrator
//!
//! This is the main entry point for the Ghost Fleet service, which coordinates
//! automated wallet operations for the GHOSTNET protocol.
//!
//! # Usage
//!
//! ```bash
//! # Run with default config
//! ghost-fleet --config config.toml
//!
//! # Run with specific log level
//! ghost-fleet --config config.toml --log-level debug
//!
//! # Dry run (no transactions)
//! ghost-fleet --config config.toml --dry-run
//! ```

use anyhow::{Context, Result};
use clap::Parser;
use tracing::{error, info, warn};

mod config;
mod engine;
mod error;
mod service;

use config::Settings;
use service::FleetService;

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ARGUMENTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Ghost Fleet - GHOSTNET Wallet Automation Orchestrator
#[derive(Parser, Debug)]
#[command(name = "ghost-fleet")]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Path to configuration file
    #[arg(short, long, env = "GHOST_FLEET_CONFIG")]
    config: String,

    /// Log level (trace, debug, info, warn, error)
    #[arg(short, long, env = "GHOST_FLEET_LOG_LEVEL", default_value = "info")]
    log_level: String,

    /// Dry run mode (no transactions sent)
    #[arg(long, env = "GHOST_FLEET_DRY_RUN")]
    dry_run: bool,

    /// Output logs as JSON
    #[arg(long, env = "GHOST_FLEET_JSON_LOGS")]
    json_logs: bool,
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::main]
async fn main() -> Result<()> {
    // Parse CLI arguments
    let args = Args::parse();

    // Initialize logging
    init_logging(&args.log_level, args.json_logs)?;

    info!(
        version = env!("CARGO_PKG_VERSION"),
        config = %args.config,
        dry_run = args.dry_run,
        "Starting Ghost Fleet"
    );

    // Load configuration
    let settings = Settings::load(&args.config)
        .with_context(|| format!("Failed to load config from {}", args.config))?;

    info!(
        chain_id = settings.chain.chain_id,
        wallets = settings.wallets.len(),
        plugins = ?settings.plugins.enabled,
        "Configuration loaded"
    );

    // Validate configuration
    settings.validate().context("Invalid configuration")?;

    // Create and run service
    let service = FleetService::new(settings, args.dry_run)
        .await
        .context("Failed to initialize service")?;

    // Set up graceful shutdown
    let shutdown = setup_shutdown_handler();

    // Run service until shutdown
    tokio::select! {
        result = service.run() => {
            if let Err(e) = result {
                error!(error = %e, "Service error");
                return Err(e);
            }
        }
        () = shutdown => {
            info!("Shutdown signal received");
        }
    }

    info!("Ghost Fleet stopped");
    Ok(())
}

// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Initialize the tracing subscriber for logging.
fn init_logging(level: &str, json: bool) -> Result<()> {
    use tracing_subscriber::prelude::*;
    use tracing_subscriber::{fmt, EnvFilter};

    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(level));

    if json {
        tracing_subscriber::registry()
            .with(filter)
            .with(fmt::layer().json())
            .try_init()
            .map_err(|e| anyhow::anyhow!("Failed to init logging: {e}"))?;
    } else {
        tracing_subscriber::registry()
            .with(filter)
            .with(fmt::layer())
            .try_init()
            .map_err(|e| anyhow::anyhow!("Failed to init logging: {e}"))?;
    }

    Ok(())
}

/// Set up graceful shutdown handler for SIGINT/SIGTERM.
async fn setup_shutdown_handler() {
    let ctrl_c = async {
        if let Err(e) = tokio::signal::ctrl_c().await {
            error!(error = %e, "Failed to install Ctrl+C handler");
        }
    };

    #[cfg(unix)]
    let terminate = async {
        match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            Ok(mut signal) => { signal.recv().await; }
            Err(e) => error!(error = %e, "Failed to install SIGTERM handler"),
        }
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        () = ctrl_c => {
            warn!("Received Ctrl+C, initiating graceful shutdown...");
        }
        () = terminate => {
            warn!("Received SIGTERM, initiating graceful shutdown...");
        }
    }
}
