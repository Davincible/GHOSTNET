//! Configuration loading and validation for the GHOSTNET Event Indexer.
//!
//! Configuration is loaded from multiple sources in order of precedence:
//! 1. Environment variables (highest)
//! 2. Environment-specific file (e.g., `development.toml`)
//! 3. Default file (`default.toml`)
//!
//! # Example
//!
//! ```ignore
//! use ghostnet_indexer::config::Settings;
//!
//! let settings = Settings::load("development")?;
//! println!("RPC URL: {}", settings.rpc.url);
//! ```

mod settings;

pub use settings::{
    ApiSettings, CacheSettings, DatabaseSettings, IggySettings, LoggingSettings, MetricsSettings,
    RateLimitSettings, RpcSettings, Settings, WebSocketSettings,
};
