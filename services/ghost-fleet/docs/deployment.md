# Ghost Fleet Deployment Guide

This guide covers deploying the Ghost Fleet service for production use.

## Prerequisites

- Rust 1.85+ (for building from source)
- Docker (for containerized deployment)
- Access to MegaETH RPC endpoint
- Funded wallets with ETH and DATA tokens

## Deployment Options

### Option 1: Docker (Recommended)

Build and run using Docker:

```bash
# Build the image
cd services
docker build -t ghost-fleet:latest -f ghost-fleet/Dockerfile .

# Run with config mounted
docker run -d \
  --name ghost-fleet \
  -v /path/to/config.toml:/etc/ghost-fleet/config.toml:ro \
  -p 8080:8080 \
  ghost-fleet:latest
```

### Option 2: Binary

Build and run the binary directly:

```bash
# Build release binary
cd services
cargo build --release -p ghost-fleet

# Run
./target/release/ghost-fleet --config /path/to/config.toml
```

### Option 3: Docker Compose

Create a `docker-compose.yml`:

```yaml
version: '3.8'

services:
  ghost-fleet:
    build:
      context: ./services
      dockerfile: ghost-fleet/Dockerfile
    volumes:
      - ./config/production.toml:/etc/ghost-fleet/config.toml:ro
    ports:
      - "8080:8080"
    restart: unless-stopped
    environment:
      - RUST_LOG=info,ghost_fleet=debug
    healthcheck:
      test: ["CMD", "ghost-fleet", "--config", "/etc/ghost-fleet/config.toml", "health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## Configuration Setup

### 1. Generate Wallets

Use the wallet generation script:

```bash
cd services/ghost-fleet

# Generate 50 wallets
./scripts/generate-wallets.sh 50 ./wallets degen

# Output:
#   wallets/wallets.json
#   wallets/wallets.toml
#   wallets/wallets.csv
```

### 2. Create Configuration File

Copy the example config and customize:

```bash
cp config/example.toml config/production.toml
```

Key settings to configure:

```toml
[chain]
chain_id = 6343  # MegaETH testnet
rpc_url = "https://carrot.megaeth.com/rpc"

[plugins.ghostnet]
ghost_core = "0x..."  # Your GhostCore contract
hash_crash = "0x..."  # HashCrash contract
arcade_core = "0x..." # ArcadeCore contract
data_token = "0x..."  # DATA token address
```

### 3. Fund Wallets

Ensure each wallet has:
- Minimum 0.01 ETH for gas
- Minimum stake amount in DATA tokens

You can use a funding script or manual transfers.

## Security Considerations

### Config File Permissions

The config file contains sensitive data. Set restrictive permissions:

```bash
chmod 600 config/production.toml
chown ghostfleet:ghostfleet config/production.toml
```

The service will warn if permissions are too open on Unix systems.

### Private Keys

**Never commit private keys to version control.**

Options for key management:
1. Environment variables (basic)
2. Encrypted keyfiles (better)
3. Hardware security modules (best)

### Network Security

- Run behind a firewall
- Only expose health endpoints if needed
- Use TLS for RPC connections

## Environment Variables

The following environment variables can override config:

| Variable | Description |
|----------|-------------|
| `RUST_LOG` | Log level (e.g., `info,ghost_fleet=debug`) |
| `CONFIG_PATH` | Path to config file |

## Health Checks

The service exposes health endpoints (when `health_port` is configured):

```bash
# Liveness check
curl http://localhost:8080/health

# Readiness check  
curl http://localhost:8080/health/ready

# Metrics (Prometheus format)
curl http://localhost:8080/metrics
```

## Monitoring

### Logs

Logs are written to stdout in JSON format when `RUST_LOG` is set.

Recommended logging config:
```bash
RUST_LOG=info,ghost_fleet=debug,evm_provider=info
```

### Metrics

Prometheus metrics are exposed on the health port:

- `ghost_fleet_actions_total` - Total actions executed
- `ghost_fleet_errors_total` - Total errors
- `ghost_fleet_wallet_balance` - Wallet balances
- `ghost_fleet_circuit_breaker_trips` - Circuit breaker activations

### Alerts

Recommended alerts:

1. **Service down**: Health check fails for > 5 minutes
2. **High error rate**: > 10% error rate over 15 minutes
3. **Low balance**: Wallet ETH balance < 0.005
4. **Circuit breaker**: Any wallet circuit breaker trips

## Upgrades

### Rolling Update (Docker)

```bash
# Pull/build new image
docker build -t ghost-fleet:new -f ghost-fleet/Dockerfile .

# Stop old container
docker stop ghost-fleet

# Start new container
docker run -d --name ghost-fleet-new ... ghost-fleet:new

# Verify health
curl http://localhost:8080/health

# Remove old container
docker rm ghost-fleet
docker rename ghost-fleet-new ghost-fleet
```

### Binary Update

```bash
# Build new binary
cargo build --release -p ghost-fleet

# Stop service (via systemd or supervisor)
systemctl stop ghost-fleet

# Replace binary
cp target/release/ghost-fleet /usr/local/bin/

# Start service
systemctl start ghost-fleet
```

## Troubleshooting

### Service Won't Start

1. Check config file syntax: `ghost-fleet --config config.toml validate`
2. Verify RPC URL is reachable
3. Check file permissions on config

### High Error Rate

1. Check RPC endpoint health
2. Verify wallet balances (gas)
3. Check circuit breaker status
4. Review logs for specific errors

### Wallets Not Acting

1. Verify `enabled = true` for wallets
2. Check `global_pause` is `false`
3. Verify profiles are configured correctly
4. Check circuit breaker status

## Systemd Service (Linux)

Create `/etc/systemd/system/ghost-fleet.service`:

```ini
[Unit]
Description=Ghost Fleet Service
After=network.target

[Service]
Type=simple
User=ghostfleet
Group=ghostfleet
ExecStart=/usr/local/bin/ghost-fleet --config /etc/ghost-fleet/config.toml
Restart=always
RestartSec=10
Environment=RUST_LOG=info,ghost_fleet=debug

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable ghost-fleet
sudo systemctl start ghost-fleet
```
