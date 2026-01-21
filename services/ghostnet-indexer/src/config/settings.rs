//! Settings structs and loading logic.
//!
//! All settings have sensible defaults and can be overridden via
//! environment variables or configuration files.

use std::path::Path;
use std::time::Duration;

use config::{Config, ConfigError, Environment, File};
use serde::Deserialize;

/// Root configuration structure.
#[derive(Debug, Clone, Deserialize)]
pub struct Settings {
    /// Ethereum RPC configuration.
    pub rpc: RpcSettings,
    /// Database configuration.
    pub database: DatabaseSettings,
    /// Apache Iggy streaming configuration.
    pub iggy: IggySettings,
    /// API server configuration.
    pub api: ApiSettings,
    /// In-memory cache configuration.
    pub cache: CacheSettings,
    /// Logging configuration.
    pub logging: LoggingSettings,
    /// Metrics configuration.
    pub metrics: MetricsSettings,
    /// Smart contract addresses.
    pub contracts: ContractAddresses,
}

impl Settings {
    /// Load settings from configuration files and environment variables.
    ///
    /// Files are loaded in this order (later overrides earlier):
    /// 1. `config/default.toml`
    /// 2. `config/{environment}.toml` (if exists)
    /// 3. Environment variables with `INDEXER_` prefix
    ///
    /// # Arguments
    /// * `environment` - Environment name (e.g., "development", "production")
    ///
    /// # Errors
    /// Returns `ConfigError` if configuration is invalid or cannot be loaded.
    pub fn load(environment: &str) -> Result<Self, ConfigError> {
        let config_dir = std::env::var("CONFIG_DIR").unwrap_or_else(|_| "config".into());

        let builder = Config::builder()
            // Start with default values
            .set_default("rpc.url", "http://localhost:8545")?
            .set_default("rpc.ws_url", "ws://localhost:8546")?
            .set_default("rpc.chain_id", 1)?
            .set_default("rpc.poll_interval_ms", 1000)?
            .set_default("rpc.max_retries", 3)?
            .set_default("rpc.retry_delay_ms", 1000)?
            .set_default("rpc.request_timeout_ms", 30000)?
            .set_default("rpc.batch_size", 100)?
            .set_default("database.url", "postgres://localhost/ghostnet")?
            .set_default("database.max_connections", 10)?
            .set_default("database.min_connections", 1)?
            .set_default("database.connect_timeout_ms", 5000)?
            .set_default("database.idle_timeout_ms", 600_000)?
            .set_default("iggy.url", "tcp://localhost:8090")?
            .set_default("iggy.stream_name", "ghostnet")?
            .set_default("iggy.partition_count", 3)?
            .set_default("iggy.replication_factor", 1)?
            .set_default("iggy.username", "iggy")?
            .set_default("iggy.password", "iggy")?
            .set_default("api.host", "0.0.0.0")?
            .set_default("api.port", 8080)?
            .set_default("api.cors_origins", vec!["http://localhost:5173"])?
            .set_default("api.request_timeout_ms", 30000)?
            .set_default("api.websocket.max_connections", 10000)?
            .set_default("api.websocket.ping_interval_ms", 30000)?
            .set_default("api.websocket.pong_timeout_ms", 10000)?
            .set_default("api.rate_limit.requests_per_second", 100)?
            .set_default("api.rate_limit.burst_size", 200)?
            .set_default("cache.positions_ttl_ms", 5000)?
            .set_default("cache.positions_max_capacity", 100_000)?
            .set_default("cache.leaderboard_ttl_ms", 60000)?
            .set_default("cache.leaderboard_max_capacity", 1000)?
            .set_default("cache.stats_ttl_ms", 10000)?
            .set_default("logging.level", "info")?
            .set_default("logging.format", "json")?
            .set_default("logging.file_path", Option::<String>::None)?
            .set_default("metrics.enabled", true)?
            .set_default("metrics.host", "0.0.0.0")?
            .set_default("metrics.port", 9090)?
            // Contract addresses - these MUST be set in production config
            .set_default("contracts.ghost_core", "0x0000000000000000000000000000000000000001")?
            .set_default("contracts.trace_scan", "0x0000000000000000000000000000000000000002")?
            .set_default("contracts.dead_pool", "0x0000000000000000000000000000000000000003")?
            .set_default("contracts.data_token", "0x0000000000000000000000000000000000000004")?
            .set_default("contracts.fee_router", "0x0000000000000000000000000000000000000005")?
            .set_default("contracts.rewards_distributor", "0x0000000000000000000000000000000000000006")?
            // Load default configuration file
            .add_source(File::with_name(&format!("{config_dir}/default")).required(false))
            // Load environment-specific file
            .add_source(File::with_name(&format!("{config_dir}/{environment}")).required(false))
            // Override with environment variables (INDEXER_ prefix)
            .add_source(
                Environment::with_prefix("INDEXER")
                    .separator("__")
                    .try_parsing(true),
            );

        builder.build()?.try_deserialize()
    }

    /// Load settings from a specific file path.
    ///
    /// # Errors
    /// Returns `ConfigError` if the file cannot be read or parsed.
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self, ConfigError> {
        Config::builder()
            .add_source(File::from(path.as_ref()))
            .build()?
            .try_deserialize()
    }

    /// Validate settings and return any validation errors.
    ///
    /// # Errors
    /// Returns a list of validation error messages.
    pub fn validate(&self) -> Result<(), Vec<String>> {
        let mut errors = Vec::new();

        // RPC validation
        if self.rpc.url.is_empty() {
            errors.push("rpc.url cannot be empty".into());
        }
        if self.rpc.chain_id == 0 {
            errors.push("rpc.chain_id must be non-zero".into());
        }
        if self.rpc.batch_size == 0 {
            errors.push("rpc.batch_size must be non-zero".into());
        }

        // Database validation
        if self.database.url.is_empty() {
            errors.push("database.url cannot be empty".into());
        }
        if self.database.max_connections == 0 {
            errors.push("database.max_connections must be non-zero".into());
        }
        if self.database.min_connections > self.database.max_connections {
            errors.push("database.min_connections cannot exceed max_connections".into());
        }

        // API validation
        if self.api.port == 0 {
            errors.push("api.port must be non-zero".into());
        }
        if self.api.rate_limit.requests_per_second == 0 {
            errors.push("api.rate_limit.requests_per_second must be non-zero".into());
        }

        // Cache validation
        if self.cache.positions_max_capacity == 0 {
            errors.push("cache.positions_max_capacity must be non-zero".into());
        }

        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }
}

/// Ethereum RPC configuration.
#[derive(Debug, Clone, Deserialize)]
pub struct RpcSettings {
    /// HTTP RPC endpoint URL.
    pub url: String,
    /// WebSocket RPC endpoint URL (for subscriptions).
    pub ws_url: String,
    /// Chain ID (for validation).
    pub chain_id: u64,
    /// Polling interval in milliseconds.
    pub poll_interval_ms: u64,
    /// Maximum retry attempts for failed requests.
    pub max_retries: u32,
    /// Delay between retries in milliseconds.
    pub retry_delay_ms: u64,
    /// Request timeout in milliseconds.
    pub request_timeout_ms: u64,
    /// Number of logs to fetch per request.
    pub batch_size: u64,
}

impl RpcSettings {
    /// Get the polling interval as a `Duration`.
    #[must_use]
    pub const fn poll_interval(&self) -> Duration {
        Duration::from_millis(self.poll_interval_ms)
    }

    /// Get the retry delay as a `Duration`.
    #[must_use]
    pub const fn retry_delay(&self) -> Duration {
        Duration::from_millis(self.retry_delay_ms)
    }

    /// Get the request timeout as a `Duration`.
    #[must_use]
    pub const fn request_timeout(&self) -> Duration {
        Duration::from_millis(self.request_timeout_ms)
    }
}

/// Database configuration.
#[derive(Debug, Clone, Deserialize)]
pub struct DatabaseSettings {
    /// `PostgreSQL` connection URL.
    pub url: String,
    /// Maximum connections in the pool.
    pub max_connections: u32,
    /// Minimum connections to maintain.
    pub min_connections: u32,
    /// Connection timeout in milliseconds.
    pub connect_timeout_ms: u64,
    /// Idle connection timeout in milliseconds.
    pub idle_timeout_ms: u64,
}

impl DatabaseSettings {
    /// Get the connection timeout as a `Duration`.
    #[must_use]
    pub const fn connect_timeout(&self) -> Duration {
        Duration::from_millis(self.connect_timeout_ms)
    }

    /// Get the idle timeout as a `Duration`.
    #[must_use]
    pub const fn idle_timeout(&self) -> Duration {
        Duration::from_millis(self.idle_timeout_ms)
    }
}

/// Apache Iggy streaming configuration.
#[derive(Debug, Clone, Deserialize)]
pub struct IggySettings {
    /// Iggy server URL.
    pub url: String,
    /// Stream name for GHOSTNET events.
    pub stream_name: String,
    /// Number of partitions for the stream.
    pub partition_count: u32,
    /// Replication factor.
    pub replication_factor: u32,
    /// Username for authentication.
    pub username: String,
    /// Password for authentication.
    pub password: String,
}

/// API server configuration.
#[derive(Debug, Clone, Deserialize)]
pub struct ApiSettings {
    /// Host to bind to.
    pub host: String,
    /// Port to listen on.
    pub port: u16,
    /// Allowed CORS origins.
    pub cors_origins: Vec<String>,
    /// Request timeout in milliseconds.
    pub request_timeout_ms: u64,
    /// WebSocket settings.
    pub websocket: WebSocketSettings,
    /// Rate limiting settings.
    pub rate_limit: RateLimitSettings,
}

impl ApiSettings {
    /// Get the request timeout as a `Duration`.
    #[must_use]
    pub const fn request_timeout(&self) -> Duration {
        Duration::from_millis(self.request_timeout_ms)
    }

    /// Get the socket address string.
    #[must_use]
    pub fn socket_addr(&self) -> String {
        format!("{}:{}", self.host, self.port)
    }
}

/// WebSocket configuration.
#[derive(Debug, Clone, Deserialize)]
pub struct WebSocketSettings {
    /// Maximum concurrent WebSocket connections.
    pub max_connections: usize,
    /// Ping interval in milliseconds.
    pub ping_interval_ms: u64,
    /// Pong timeout in milliseconds.
    pub pong_timeout_ms: u64,
}

impl WebSocketSettings {
    /// Get the ping interval as a `Duration`.
    #[must_use]
    pub const fn ping_interval(&self) -> Duration {
        Duration::from_millis(self.ping_interval_ms)
    }

    /// Get the pong timeout as a `Duration`.
    #[must_use]
    pub const fn pong_timeout(&self) -> Duration {
        Duration::from_millis(self.pong_timeout_ms)
    }
}

/// Rate limiting configuration.
#[derive(Debug, Clone, Deserialize)]
pub struct RateLimitSettings {
    /// Maximum requests per second per client.
    pub requests_per_second: u32,
    /// Burst size (allows temporary spikes).
    pub burst_size: u32,
}

/// In-memory cache configuration.
#[derive(Debug, Clone, Deserialize)]
pub struct CacheSettings {
    /// TTL for position cache entries in milliseconds.
    pub positions_ttl_ms: u64,
    /// Maximum capacity for position cache.
    pub positions_max_capacity: u64,
    /// TTL for leaderboard cache entries in milliseconds.
    pub leaderboard_ttl_ms: u64,
    /// Maximum capacity for leaderboard cache.
    pub leaderboard_max_capacity: u64,
    /// TTL for stats cache entries in milliseconds.
    pub stats_ttl_ms: u64,
}

impl CacheSettings {
    /// Get the positions TTL as a `Duration`.
    #[must_use]
    pub const fn positions_ttl(&self) -> Duration {
        Duration::from_millis(self.positions_ttl_ms)
    }

    /// Get the leaderboard TTL as a `Duration`.
    #[must_use]
    pub const fn leaderboard_ttl(&self) -> Duration {
        Duration::from_millis(self.leaderboard_ttl_ms)
    }

    /// Get the stats TTL as a `Duration`.
    #[must_use]
    pub const fn stats_ttl(&self) -> Duration {
        Duration::from_millis(self.stats_ttl_ms)
    }
}

/// Logging configuration.
#[derive(Debug, Clone, Deserialize)]
pub struct LoggingSettings {
    /// Log level (trace, debug, info, warn, error).
    pub level: String,
    /// Log format (json, pretty).
    pub format: String,
    /// Optional file path for log output.
    pub file_path: Option<String>,
}

/// Metrics configuration.
#[derive(Debug, Clone, Deserialize)]
pub struct MetricsSettings {
    /// Whether metrics are enabled.
    pub enabled: bool,
    /// Host to bind metrics server to.
    pub host: String,
    /// Port for metrics server.
    pub port: u16,
}

impl MetricsSettings {
    /// Get the metrics socket address string.
    #[must_use]
    pub fn socket_addr(&self) -> String {
        format!("{}:{}", self.host, self.port)
    }
}

/// GHOSTNET smart contract addresses.
///
/// These addresses point to the deployed contracts on MegaETH.
/// All addresses should be checksummed.
#[derive(Debug, Clone, Deserialize)]
pub struct ContractAddresses {
    /// GhostCore contract - main game logic.
    pub ghost_core: String,
    /// TraceScan contract - scan execution.
    pub trace_scan: String,
    /// DeadPool contract - prediction market.
    pub dead_pool: String,
    /// DataToken contract - $DATA ERC20.
    pub data_token: String,
    /// FeeRouter contract - fee collection.
    pub fee_router: String,
    /// RewardsDistributor contract - emissions.
    pub rewards_distributor: String,
}

impl ContractAddresses {
    /// Get all contract addresses as a vector.
    ///
    /// Useful for building log filters covering all contracts.
    #[must_use]
    pub fn all(&self) -> Vec<&str> {
        vec![
            &self.ghost_core,
            &self.trace_scan,
            &self.dead_pool,
            &self.data_token,
            &self.fee_router,
            &self.rewards_distributor,
        ]
    }

    /// Parse all addresses into Alloy Address types.
    ///
    /// # Errors
    /// Returns an error if any address is invalid.
    pub fn parse_all(&self) -> Result<Vec<alloy::primitives::Address>, String> {
        use std::str::FromStr;
        self.all()
            .into_iter()
            .map(|s| {
                alloy::primitives::Address::from_str(s)
                    .map_err(|e| format!("Invalid address '{}': {}", s, e))
            })
            .collect()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used)]
mod tests {
    use super::*;

    #[test]
    fn rpc_durations() {
        let rpc = RpcSettings {
            url: "http://localhost:8545".into(),
            ws_url: "ws://localhost:8546".into(),
            chain_id: 1,
            poll_interval_ms: 1000,
            max_retries: 3,
            retry_delay_ms: 500,
            request_timeout_ms: 30000,
            batch_size: 100,
        };

        assert_eq!(rpc.poll_interval(), Duration::from_millis(1000));
        assert_eq!(rpc.retry_delay(), Duration::from_millis(500));
        assert_eq!(rpc.request_timeout(), Duration::from_millis(30000));
    }

    #[test]
    fn api_socket_addr() {
        let api = ApiSettings {
            host: "127.0.0.1".into(),
            port: 8080,
            cors_origins: vec![],
            request_timeout_ms: 30000,
            websocket: WebSocketSettings {
                max_connections: 1000,
                ping_interval_ms: 30000,
                pong_timeout_ms: 10000,
            },
            rate_limit: RateLimitSettings {
                requests_per_second: 100,
                burst_size: 200,
            },
        };

        assert_eq!(api.socket_addr(), "127.0.0.1:8080");
    }

    #[test]
    fn validation_catches_zero_connections() {
        let mut settings = create_valid_settings();
        settings.database.max_connections = 0;

        let result = settings.validate();
        assert!(result.is_err());
        let errors = result.unwrap_err();
        assert!(errors.iter().any(|e| e.contains("max_connections")));
    }

    #[test]
    fn validation_catches_min_exceeds_max() {
        let mut settings = create_valid_settings();
        settings.database.min_connections = 20;
        settings.database.max_connections = 10;

        let result = settings.validate();
        assert!(result.is_err());
        let errors = result.unwrap_err();
        assert!(errors.iter().any(|e| e.contains("min_connections")));
    }

    fn create_valid_settings() -> Settings {
        Settings {
            rpc: RpcSettings {
                url: "http://localhost:8545".into(),
                ws_url: "ws://localhost:8546".into(),
                chain_id: 1,
                poll_interval_ms: 1000,
                max_retries: 3,
                retry_delay_ms: 1000,
                request_timeout_ms: 30000,
                batch_size: 100,
            },
            database: DatabaseSettings {
                url: "postgres://localhost/test".into(),
                max_connections: 10,
                min_connections: 1,
                connect_timeout_ms: 5000,
                idle_timeout_ms: 600_000,
            },
            iggy: IggySettings {
                url: "tcp://localhost:8090".into(),
                stream_name: "ghostnet".into(),
                partition_count: 3,
                replication_factor: 1,
                username: "iggy".into(),
                password: "iggy".into(),
            },
            api: ApiSettings {
                host: "0.0.0.0".into(),
                port: 8080,
                cors_origins: vec![],
                request_timeout_ms: 30000,
                websocket: WebSocketSettings {
                    max_connections: 10000,
                    ping_interval_ms: 30000,
                    pong_timeout_ms: 10000,
                },
                rate_limit: RateLimitSettings {
                    requests_per_second: 100,
                    burst_size: 200,
                },
            },
            cache: CacheSettings {
                positions_ttl_ms: 5000,
                positions_max_capacity: 100_000,
                leaderboard_ttl_ms: 60000,
                leaderboard_max_capacity: 1000,
                stats_ttl_ms: 10000,
            },
            logging: LoggingSettings {
                level: "info".into(),
                format: "json".into(),
                file_path: None,
            },
            metrics: MetricsSettings {
                enabled: true,
                host: "0.0.0.0".into(),
                port: 9090,
            },
            contracts: ContractAddresses {
                ghost_core: "0x0000000000000000000000000000000000000001".into(),
                trace_scan: "0x0000000000000000000000000000000000000002".into(),
                dead_pool: "0x0000000000000000000000000000000000000003".into(),
                data_token: "0x0000000000000000000000000000000000000004".into(),
                fee_router: "0x0000000000000000000000000000000000000005".into(),
                rewards_distributor: "0x0000000000000000000000000000000000000006".into(),
            },
        }
    }
}
