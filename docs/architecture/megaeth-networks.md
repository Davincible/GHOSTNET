# MegaETH Network Reference

**Last Verified:** January 2026

---

## Network Summary

| Network | Chain ID | Status | ETH Source | Use For |
|---------|----------|--------|------------|---------|
| **Testnet V2** | 6343 | Public | Free faucets | Development, testing |
| **Mainnet (Frontier)** | 4326 | Developer beta | Bridge from L1 | Production (when ready) |

---

## Testnet V2 (Recommended for Development)

```
Chain ID:        6343
RPC URL:         https://carrot.megaeth.com/rpc
Block Explorer:  https://megaeth-testnet-v2.blockscout.com/
Block Time:      10ms mini / 1s EVM
Gas Price:       ~0.001 gwei
```

### Getting Testnet ETH

| Faucet | Amount | URL |
|--------|--------|-----|
| thirdweb | 0.01 ETH/day | https://thirdweb.com/megaeth-testnet |
| Chainlink | varies | https://faucets.chain.link/megaeth-testnet |
| gas.zip | 0.0025 ETH/day | https://www.gas.zip/faucet/megaeth |
| Official | varies | https://testnet.megaeth.com/ (FAUCET tab) |

### Quick Commands

```bash
# Check balance
cast balance <ADDRESS> --rpc-url https://carrot.megaeth.com/rpc

# Check block number
cast block-number --rpc-url https://carrot.megaeth.com/rpc

# Deploy contract
forge script <SCRIPT> \
  --rpc-url https://carrot.megaeth.com/rpc \
  --broadcast --skip-simulation --gas-limit 10000000
```

---

## Mainnet "Frontier" (Developer Beta)

```
Chain ID:        4326
RPC URL:         https://mainnet.megaeth.com/rpc (public, whitelisted)
                 https://megaeth-mainnet.g.alchemy.com/v2/<KEY> (Alchemy)
Block Explorer:  https://megaeth.blockscout.com/
Block Time:      10ms mini / 1s EVM
Gas Price:       ~0.001 gwei
```

### Getting Mainnet ETH

**Requires bridging real ETH from Ethereum L1:**

```bash
# L1 Bridge Contract (Ethereum Mainnet):
# L1StandardBridgeProxy: 0x0CA3A2FBC3D770b578223FBB6b062fa875a2eE75

# Simple bridge (send ETH directly to bridge contract)
cast send 0x0CA3A2FBC3D770b578223FBB6b062fa875a2eE75 \
  --value 0.1ether \
  --rpc-url https://eth.llamarpc.com
```

**Warning:** This costs real money. Only use for production deployment.

### Access Status

As of January 2026:
- Mainnet is **live but restricted** to whitelisted developers
- Full public mainnet expected early 2026
- Alchemy provides RPC access for whitelisted projects

---

## Project Configuration

### Foundry (foundry.toml)

```toml
[rpc_endpoints]
megaeth = "${MEGAETH_RPC_URL}"                    # Defaults to testnet
megaeth_testnet = "https://carrot.megaeth.com/rpc"
megaeth_mainnet = "${MEGAETH_MAINNET_RPC_URL}"
```

### Environment (.env)

```bash
# Default to testnet for development
MEGAETH_RPC_URL=https://carrot.megaeth.com/rpc

# Mainnet (only when needed for production)
MEGAETH_MAINNET_RPC_URL=https://megaeth-mainnet.g.alchemy.com/v2/<YOUR_KEY>
```

### Usage

```bash
# Development (testnet) - DEFAULT
forge script Deploy.s.sol --rpc-url megaeth --broadcast --skip-simulation --gas-limit 10000000

# Explicit testnet
forge script Deploy.s.sol --rpc-url megaeth_testnet --broadcast --skip-simulation --gas-limit 10000000

# Production (mainnet) - requires real ETH
forge script Deploy.s.sol --rpc-url megaeth_mainnet --broadcast --skip-simulation --gas-limit 10000000
```

---

## Key Differences

| Aspect | Testnet | Mainnet |
|--------|---------|---------|
| Real value | No | Yes |
| Faucets | Yes | No |
| Public access | Yes | Whitelisted |
| State persistence | May reset | Permanent |
| For production | No | Yes |

---

## Gotchas

1. **Gas estimation fails** - Always use `--skip-simulation --gas-limit 10000000`
2. **RPC URL changed** - Was `timothy.megaeth.com`, now `carrot.megaeth.com`
3. **Old chain ID** - Was 6342, now 6343 (testnet)
4. **Mainnet requires bridge** - No faucets, must bridge from Ethereum L1

---

## Verification (January 2026)

```bash
# Testnet
$ cast chain-id --rpc-url https://carrot.megaeth.com/rpc
6343

$ cast block-number --rpc-url https://carrot.megaeth.com/rpc
9147880

# Mainnet (via Alchemy)
$ cast chain-id --rpc-url https://megaeth-mainnet.g.alchemy.com/v2/...
4326

$ cast block-number --rpc-url https://megaeth-mainnet.g.alchemy.com/v2/...
6061324

$ cast client --rpc-url https://megaeth-mainnet.g.alchemy.com/v2/...
mega-reth/v2.0.9-2f0fd31@megaeth-archive-mainnet-euc1-0
```

Both networks are live and operational.

---

*For the latest official info, see: https://docs.megaeth.com*
