//! Container configurations for integration tests.
//!
//! Provides pre-configured containers for testing against real databases.

use std::collections::HashMap;

use testcontainers::Image;
use testcontainers::core::{ContainerPort, WaitFor};

/// TimescaleDB container image.
///
/// Uses the official TimescaleDB image with PostgreSQL 16.
/// This image includes the TimescaleDB extension pre-installed.
#[derive(Debug, Clone)]
pub struct TimescaleDb {
    env_vars: HashMap<String, String>,
}

impl Default for TimescaleDb {
    fn default() -> Self {
        let mut env_vars = HashMap::new();
        env_vars.insert("POSTGRES_USER".to_string(), "postgres".to_string());
        env_vars.insert("POSTGRES_PASSWORD".to_string(), "postgres".to_string());
        env_vars.insert("POSTGRES_DB".to_string(), "ghostnet_test".to_string());
        Self { env_vars }
    }
}

impl TimescaleDb {
    /// Set a custom database name.
    #[must_use]
    pub fn with_db_name(mut self, name: &str) -> Self {
        self.env_vars
            .insert("POSTGRES_DB".to_string(), name.to_string());
        self
    }

    /// Set a custom password.
    #[must_use]
    pub fn with_password(mut self, password: &str) -> Self {
        self.env_vars
            .insert("POSTGRES_PASSWORD".to_string(), password.to_string());
        self
    }
}

impl Image for TimescaleDb {
    fn name(&self) -> &str {
        "timescale/timescaledb"
    }

    fn tag(&self) -> &str {
        "latest-pg16"
    }

    fn ready_conditions(&self) -> Vec<WaitFor> {
        vec![WaitFor::message_on_stderr(
            "database system is ready to accept connections",
        )]
    }

    fn env_vars(
        &self,
    ) -> impl IntoIterator<
        Item = (
            impl Into<std::borrow::Cow<'_, str>>,
            impl Into<std::borrow::Cow<'_, str>>,
        ),
    > {
        self.env_vars.iter().map(|(k, v)| (k.as_str(), v.as_str()))
    }

    fn expose_ports(&self) -> &[ContainerPort] {
        &[ContainerPort::Tcp(5432)]
    }
}

/// Build a connection string for a running TimescaleDB container.
pub fn build_connection_string(host: &str, port: u16) -> String {
    format!("postgres://postgres:postgres@{host}:{port}/ghostnet_test")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn timescaledb_default_config() {
        let ts = TimescaleDb::default();
        assert_eq!(ts.name(), "timescale/timescaledb");
        assert_eq!(ts.tag(), "latest-pg16");
    }

    #[test]
    fn connection_string_format() {
        let conn = build_connection_string("localhost", 5432);
        assert_eq!(
            conn,
            "postgres://postgres:postgres@localhost:5432/ghostnet_test"
        );
    }
}
