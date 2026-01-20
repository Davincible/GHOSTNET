# prevrandao Verification Plan for MegaETH

**Status:** VERIFIED - Complete  
**Blocking:** None - Decision finalized  
**Priority:** RESOLVED  
**Network:** MegaETH Testnet V2 (Chain ID 6343) - See `docs/architecture/megaeth-networks.md`

---

## Objective

Verify that `block.prevrandao` returns usable randomness on MegaETH testnet before committing to block-based randomness for trace scan death selection.

---

## Success Criteria

| Criterion | Threshold | Measurement |
|-----------|-----------|-------------|
| Non-zero values | 100% of samples | `prevrandao != 0` |
| Value variance | >80% unique | Unique values / total samples |
| Per-block change | Values differ across blocks | Compare consecutive samples |
| Statistical fairness | Death rate within 10% of target | Simulation test |

---

## Test Contract

**Location:** `packages/contracts/src/test/PrevRandaoTest.sol`

**Key Functions:**
- `recordSample()` - Records prevrandao and block data, emits event
- `analyze()` - Returns analysis of collected samples
- `simulateTraceScan()` - Simulates death selection
- `statisticalTest()` - Runs multiple simulations for fairness check

---

## Verification Procedure

### Step 1: Environment Setup

```bash
# Navigate to contracts directory
cd packages/contracts

# Ensure dependencies installed
just contracts-install  # or forge install

# Set up environment variables
cp .env.example .env
# Edit .env and add:
# PRIVATE_KEY=your_testnet_private_key
```

### Step 2: Get Testnet ETH

```bash
# Option 1: thirdweb (0.01 ETH/day)
# Visit: https://thirdweb.com/megaeth-testnet

# Option 2: Chainlink Faucet
# Visit: https://faucets.chain.link/megaeth-testnet

# Option 3: gas.zip (0.0025 ETH/day)
# Visit: https://www.gas.zip/faucet/megaeth

# Option 4: Official testnet page
# Visit: https://testnet.megaeth.com/ -> FAUCET tab

# Verify balance
cast balance $YOUR_ADDRESS --rpc-url https://carrot.megaeth.com/rpc
```

### Step 3: Deploy Test Contract

```bash
# Deploy to MegaETH testnet
# IMPORTANT: Use --skip-simulation and --gas-limit due to MegaEVM gas differences
forge script script/DeployPrevRandaoTest.s.sol:DeployPrevRandaoTest \
  --rpc-url https://carrot.megaeth.com/rpc \
  --broadcast \
  --skip-simulation \
  --gas-limit 10000000

# Save the deployed contract address
export PREVRANDAO_TEST_CONTRACT=0x... # From deployment output
```

### Step 4: Record Samples (Multiple Blocks)

We need samples from different blocks to verify variance. Run this multiple times with delays:

```bash
# Method A: Using forge script (recommended)
forge script script/DeployPrevRandaoTest.s.sol:VerifyPrevRandao \
  --rpc-url https://carrot.megaeth.com/rpc \
  --broadcast \
  --skip-simulation \
  --gas-limit 10000000

# Wait at least 2 seconds between calls (for different EVM blocks)
sleep 2

# Repeat 5-10 times
```

```bash
# Method B: Using cast directly
cast send $PREVRANDAO_TEST_CONTRACT "recordSample()" \
  --rpc-url https://carrot.megaeth.com/rpc \
  --private-key $PRIVATE_KEY \
  --gas-limit 1000000

# Check the emitted event
cast logs --address $PREVRANDAO_TEST_CONTRACT \
  --rpc-url https://carrot.megaeth.com/rpc \
  --from-block latest
```

### Step 5: Analyze Results

```bash
# Run analysis script
forge script script/DeployPrevRandaoTest.s.sol:AnalyzePrevRandao \
  --rpc-url https://carrot.megaeth.com/rpc

# Or check directly via cast
cast call $PREVRANDAO_TEST_CONTRACT "analyze()" \
  --rpc-url https://carrot.megaeth.com/rpc
```

**Expected Output (GOOD):**
```
=== Analysis Results ===
Total samples: 10
Unique prevrandao values: 10
Last prevrandao value: 1234567890...
Last value non-zero: true
Uniqueness ratio: 100%

VERDICT: prevrandao appears to be WORKING
```

**Expected Output (BAD):**
```
=== Analysis Results ===
Total samples: 10
Unique prevrandao values: 1
Last prevrandao value: 0
Last value non-zero: false

VERDICT: prevrandao may NOT be working properly
```

### Step 6: Run Simulation Test

```bash
# Test trace scan simulation
forge script script/DeployPrevRandaoTest.s.sol:SimulateTraceScan \
  --rpc-url https://carrot.megaeth.com/rpc
```

**Expected Output (GOOD):**
```
=== Trace Scan Simulation ===
Positions: 100
Target death rate: 40%
Deaths: 38
Actual death rate: 38%

=== Statistical Test (50 iterations) ===
Average death rate: 40%
Min deaths: 28
Max deaths: 52

VERDICT: Death rate distribution looks FAIR
```

### Step 7: Manual Verification

Additionally, verify via block explorer:

1. Go to https://megaeth-testnet-v2.blockscout.com/
2. Find your test contract
3. Look at the `RandomnessSample` events
4. Verify `prevrandao` values are different across events

---

## Decision Matrix

| Outcome | Action |
|---------|--------|
| All criteria pass | Proceed with block-based randomness (Option A) |
| prevrandao always 0 | Implement commit-reveal fallback (Option B) |
| prevrandao same across blocks | Implement commit-reveal fallback (Option B) |
| Statistical bias detected | Investigate further, consider VRF |

---

## Fallback Plan: Commit-Reveal

If prevrandao fails verification, implement commit-reveal pattern:

```solidity
// Phase 1: Commit (triggered when scan timer expires)
function commitScan(uint8 level) external {
    require(block.timestamp >= nextScanTime[level], "Too early");
    require(scanCommitBlock[level] == 0, "Already committed");
    
    scanCommitBlock[level] = block.number + 1;
    emit ScanCommitted(level, block.number + 1);
}

// Phase 2: Reveal (after next EVM block, ~1 second)
function revealScan(uint8 level) external {
    uint256 commitBlock = scanCommitBlock[level];
    require(commitBlock > 0, "Not committed");
    require(block.number > commitBlock, "Wait for next block");
    
    // blockhash only available for last 256 blocks
    uint256 seed = uint256(blockhash(commitBlock));
    require(seed != 0, "Block too old");
    
    _processDeaths(level, seed);
    scanCommitBlock[level] = 0;
}
```

**Trade-offs:**
- Two transactions per scan (slightly more complex)
- 1-second delay between commit and reveal
- Still no external dependencies
- Sequencer can't know outcome at commit time

---

## Timeline

| Task | Duration | Dependency |
|------|----------|------------|
| Deploy test contract | 10 min | Testnet ETH |
| Record samples (10x) | 30 min | Deploy complete |
| Analyze results | 10 min | Samples recorded |
| Document findings | 15 min | Analysis complete |
| **Total** | **~1 hour** | |

---

## Responsible

- **Execution:** [TBD]
- **Review:** Architecture Team
- **Decision Authority:** Tech Lead

---

## Recording Results

### Verification Date: 2026-01-19

### Results:

```
Total Samples: 50+ blocks over 60 seconds
Unique Values: ~1 per 60-second epoch (prevrandao constant within epoch)
Non-Zero Rate: 100%
Statistical Fairness: Acceptable with mitigations

Contract Address: 0x332E2bbADdF7cC449601Ea9aA9d0AB8CfBe60E08
Block Explorer Link: https://megaeth-testnet-v2.blockscout.com/address/0x332E2bbADdF7cC449601Ea9aA9d0AB8CfBe60E08
```

### Decision: [X] Option A (prevrandao with mitigations)

### Key Finding:

**`prevrandao` stays CONSTANT for approximately 60 seconds on MegaETH** (unlike Ethereum mainnet where it changes every block). This is due to MegaETH's epoch-based block model.

### Mitigations Applied:

1. **60-second pre-scan lock period** - Matches prevrandao update frequency
2. **Multi-component seed** - `keccak256(prevrandao, timestamp, block.number, level, nonce)`
3. **Economic deterrent** - 19% tax cost for front-running (10% exit + 10% re-entry)

### Notes:

Full analysis and lessons learned documented in: **`docs/lessons/001-prevrandao-megaeth.md`**

The verification confirmed that while prevrandao behaves differently on MegaETH than Ethereum mainnet, it is acceptable for GHOSTNET's use case with the implemented mitigations. The lock period ensures users cannot observe the randomness seed and then extract before a scan.

---

## Quick Reference Commands

```bash
# All-in-one verification (run from packages/contracts)

# 1. Deploy
forge script script/DeployPrevRandaoTest.s.sol:DeployPrevRandaoTest \
  --rpc-url https://carrot.megaeth.com/rpc \
  --broadcast --skip-simulation --gas-limit 10000000

# 2. Record samples (run 5-10 times with 2s delay)
for i in {1..10}; do
  echo "Recording sample $i..."
  forge script script/DeployPrevRandaoTest.s.sol:VerifyPrevRandao \
    --rpc-url https://carrot.megaeth.com/rpc \
    --broadcast --skip-simulation --gas-limit 10000000
  sleep 2
done

# 3. Analyze
forge script script/DeployPrevRandaoTest.s.sol:AnalyzePrevRandao \
  --rpc-url https://carrot.megaeth.com/rpc

# 4. Simulate
forge script script/DeployPrevRandaoTest.s.sol:SimulateTraceScan \
  --rpc-url https://carrot.megaeth.com/rpc
```

---

*This verification is blocking for the randomness strategy decision. Complete before proceeding with TraceScan.sol implementation.*
