# Ghost Fleet Configuration Reference

Complete reference for all configuration options in Ghost Fleet.

## Configuration File Format

Ghost Fleet uses TOML configuration files. The config path is specified via:
- Command line: `--config /path/to/config.toml`
- Environment variable: `CONFIG_PATH`

## Sections

### [service]

Service-level configuration.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `name` | string | `"ghost-fleet"` | Service name (used in logs) |
| `tick_interval_ms` | u64 | `1000` | Main loop tick interval in milliseconds |
| `health_port` | u16 | `0` | HTTP port for health endpoints (0 = disabled) |

```toml
[service]
name = "ghost-fleet"
tick_interval_ms = 1000
health_port = 8080
```

### [chain]

Blockchain connection configuration.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `chain_id` | u64 | required | Chain ID |
| `rpc_url` | string | required | RPC endpoint URL |
| `chain_type` | string | `"standard"` | Provider type: `"standard"` or `"megaeth"` |
| `gas_limit_override` | u64 | none | Override gas limit for all transactions |
| `use_realtime` | bool | `false` | Use MegaETH realtime API (if available) |

```toml
[chain]
chain_id = 6343
rpc_url = "https://carrot.megaeth.com/rpc"
chain_type = "megaeth"
gas_limit_override = 500000
use_realtime = true
```

### [[wallets]]

Wallet configuration. Can have multiple `[[wallets]]` entries.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `id` | string | required | Unique wallet identifier |
| `address` | address | required | Wallet address (0x...) |
| `profile` | string | required | Behavior profile name |
| `private_key` | string | none | Private key (hex, with or without 0x) |
| `keyfile` | string | none | Path to encrypted keyfile |
| `enabled` | bool | `true` | Whether wallet is active |

```toml
[[wallets]]
id = "wallet-001"
address = "0x742d35Cc6634C0532925a3b844Bc9e7595f8fB8b"
profile = "degen"
private_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
enabled = true

[[wallets]]
id = "wallet-002"
address = "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"
profile = "whale"
keyfile = "keys/wallet-002.enc"
enabled = true
```

### [plugins]

Plugin system configuration.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | string[] | `[]` | List of enabled plugin IDs |

```toml
[plugins]
enabled = ["ghostnet"]
```

### [plugins.ghostnet]

GHOSTNET protocol plugin configuration. Required if `"ghostnet"` is in `plugins.enabled`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `ghost_core` | address | required | GhostCore contract address |
| `hash_crash` | address | required | HashCrash contract address |
| `arcade_core` | address | required | ArcadeCore contract address |
| `data_token` | address | required | DATA token address |
| `min_stake` | string | `"1000000000000000000"` | Minimum stake amount in wei |
| `hashcrash_enabled` | bool | `false` | Enable HashCrash arcade game |

```toml
[plugins.ghostnet]
ghost_core = "0x5FbDB2315678afecb367f032d93F642f64180aa3"
hash_crash = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
arcade_core = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
data_token = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
min_stake = "1000000000000000000"
hashcrash_enabled = true
```

### [safety]

Safety and circuit breaker configuration.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `max_consecutive_errors` | u32 | `5` | Errors before circuit breaker trips |
| `cooldown_secs` | u64 | `3600` | Circuit breaker cooldown (seconds) |
| `max_actions_per_hour` | u32 | `20` | Rate limit per wallet per hour |
| `global_pause` | bool | `false` | Emergency stop all operations |

```toml
[safety]
max_consecutive_errors = 5
cooldown_secs = 3600
max_actions_per_hour = 20
global_pause = false
```

### [profiles.<name>]

Behavior profile definitions. Referenced by wallet `profile` field.

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `risk_tolerance` | f64 | `0.5` | 0.0-1.0 | Risk appetite (higher = riskier) |
| `activity_level` | f64 | `5.0` | 0.0+ | Actions per active period |
| `patience` | f64 | `0.5` | 0.0-1.0 | Willingness to wait for better conditions |
| `action_interval_secs` | u64 | `3600` | 0+ | Base time between actions |
| `action_interval_jitter_pct` | u8 | `50` | 0-100 | Randomization percentage |
| `active_hours_start` | u8 | `8` | 0-23 | Active period start (UTC) |
| `active_hours_end` | u8 | `22` | 0-23 | Active period end (UTC) |
| `off_hours_factor` | f64 | `0.3` | 0.0-1.0 | Activity multiplier outside active hours |
| `afk_probability` | f64 | `0.1` | 0.0-1.0 | Chance of going AFK |
| `afk_min_hours` | u64 | `4` | 0+ | Minimum AFK duration |
| `afk_max_hours` | u64 | `24` | 0+ | Maximum AFK duration |

```toml
[profiles.whale]
risk_tolerance = 0.2
activity_level = 2.0
patience = 0.9
action_interval_secs = 7200
action_interval_jitter_pct = 40
active_hours_start = 9
active_hours_end = 17
off_hours_factor = 0.1
afk_probability = 0.05
afk_min_hours = 8
afk_max_hours = 48

[profiles.degen]
risk_tolerance = 0.8
activity_level = 10.0
patience = 0.2
action_interval_secs = 1800
action_interval_jitter_pct = 60
active_hours_start = 0
active_hours_end = 24
off_hours_factor = 0.8
afk_probability = 0.15
afk_min_hours = 2
afk_max_hours = 12
```

## Complete Example

```toml
# Ghost Fleet Configuration
# MegaETH Testnet

[service]
name = "ghost-fleet-testnet"
tick_interval_ms = 1000
health_port = 8080

[chain]
chain_id = 6343
rpc_url = "https://carrot.megaeth.com/rpc"
chain_type = "megaeth"
gas_limit_override = 500000

[plugins]
enabled = ["ghostnet"]

[plugins.ghostnet]
ghost_core = "0x5FbDB2315678afecb367f032d93F642f64180aa3"
hash_crash = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
arcade_core = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
data_token = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
min_stake = "1000000000000000000"
hashcrash_enabled = false

[safety]
max_consecutive_errors = 5
cooldown_secs = 3600
max_actions_per_hour = 20
global_pause = false

[profiles.conservative]
risk_tolerance = 0.2
activity_level = 3.0
patience = 0.8
action_interval_secs = 7200
action_interval_jitter_pct = 30

[profiles.balanced]
risk_tolerance = 0.5
activity_level = 5.0
patience = 0.5
action_interval_secs = 3600
action_interval_jitter_pct = 50

[profiles.aggressive]
risk_tolerance = 0.8
activity_level = 10.0
patience = 0.2
action_interval_secs = 1800
action_interval_jitter_pct = 60

[[wallets]]
id = "wallet-001"
address = "0x742d35Cc6634C0532925a3b844Bc9e7595f8fB8b"
profile = "conservative"
private_key = "0x..."
enabled = true

[[wallets]]
id = "wallet-002"
address = "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"
profile = "balanced"
private_key = "0x..."
enabled = true

[[wallets]]
id = "wallet-003"
address = "0xdD2FD4581271e230360230F9337D5c0430Bf44C0"
profile = "aggressive"
private_key = "0x..."
enabled = true
```

## Validation

The service validates configuration on startup:

- Required fields must be present
- Profile values must be within valid ranges
- Wallet profiles must exist in `[profiles]`
- Enabled plugins must have configuration

Run validation manually:

```bash
ghost-fleet --config config.toml validate
```

## Environment Variable Overrides

Some settings can be overridden via environment variables:

| Variable | Overrides |
|----------|-----------|
| `GHOST_FLEET_RPC_URL` | `chain.rpc_url` |
| `RUST_LOG` | Log level |

## Security Notes

1. **Never commit private keys** to version control
2. **Restrict config file permissions**: `chmod 600 config.toml`
3. Consider using **encrypted keyfiles** instead of inline private keys
4. The service warns if config permissions are too open on Unix
