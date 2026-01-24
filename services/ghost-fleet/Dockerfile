# Ghost Fleet Service Dockerfile
# Multi-stage build for minimal production image

# ═══════════════════════════════════════════════════════════════════════════════
# STAGE 1: Build
# ═══════════════════════════════════════════════════════════════════════════════

FROM rust:1.85-slim-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy workspace manifests first for better layer caching
COPY Cargo.toml Cargo.lock ./
COPY crates/ crates/
COPY ghost-fleet/Cargo.toml ghost-fleet/
COPY ghostnet-actions/Cargo.toml ghostnet-actions/

# Create dummy source files for dependency caching
RUN mkdir -p crates/evm-provider/src crates/fleet-core/src crates/megaeth-rpc/src \
    ghost-fleet/src ghostnet-actions/src \
    && echo "fn main() {}" > ghost-fleet/src/main.rs \
    && echo "" > crates/evm-provider/src/lib.rs \
    && echo "" > crates/fleet-core/src/lib.rs \
    && echo "" > crates/megaeth-rpc/src/lib.rs \
    && echo "" > ghostnet-actions/src/lib.rs

# Build dependencies only (cached layer)
RUN cargo build --release -p ghost-fleet 2>/dev/null || true

# Copy actual source code
COPY crates/ crates/
COPY ghost-fleet/ ghost-fleet/
COPY ghostnet-actions/ ghostnet-actions/

# Touch source files to invalidate cache
RUN touch crates/*/src/lib.rs ghost-fleet/src/main.rs ghostnet-actions/src/lib.rs

# Build the actual binary
RUN cargo build --release -p ghost-fleet

# ═══════════════════════════════════════════════════════════════════════════════
# STAGE 2: Runtime
# ═══════════════════════════════════════════════════════════════════════════════

FROM debian:bookworm-slim AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd --create-home --user-group ghostfleet

# Copy binary from builder
COPY --from=builder /app/target/release/ghost-fleet /usr/local/bin/ghost-fleet

# Create config directory
RUN mkdir -p /etc/ghost-fleet && chown ghostfleet:ghostfleet /etc/ghost-fleet

# Switch to non-root user
USER ghostfleet
WORKDIR /home/ghostfleet

# Default config location
ENV CONFIG_PATH=/etc/ghost-fleet/config.toml

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ghost-fleet --config $CONFIG_PATH health || exit 1

# Run the service
ENTRYPOINT ["ghost-fleet"]
CMD ["--config", "/etc/ghost-fleet/config.toml"]
