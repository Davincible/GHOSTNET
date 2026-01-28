# ADR-003: Presale Architecture

**Date:** 2026-01-28
**Status:** Accepted
**Context:** GHOSTNET needs a pre-launch token presale for the 15% $DATA allocation

## Decision

Two-contract architecture with configurable dual-pricing support.

### Contracts

1. **GhostPresale** — Accepts ETH, tracks allocations, computes pricing. Deploys pre-launch. Token does not need to exist. Immutable (not upgradeable, no selfdestruct).
2. **PresaleClaim** — Holds $DATA, lets contributors claim at TGE. Reads allocations from GhostPresale with snapshot backup.

### Pricing

Single contract supports two modes, selected at deploy time:
- **Tranche mode**: Ascending fixed-price tiers. Simpler. Clear social signaling.
- **Bonding curve mode**: Linear continuous curve (endPrice must be > startPrice). More GHOSTNET-like. Constant urgency.

All parameters (prices, supply, caps, timing, multi-contribution) are owner-configurable before presale opens.

### State Machine

`PENDING → OPEN → FINALIZED` (happy path) or `OPEN → REFUNDING` (emergency, owner-initiated or dead-man's switch). FINALIZED and REFUNDING are mutually exclusive terminal states. If owner disappears, `emergencyRefunds()` is permissionless after a configurable deadline.

### Frontend

Standalone `/presale` page. Terminal aesthetic. Boot sequence. Live contribution feed. Post-contribution dashboard with rank and TGE countdown.

## Rationale

- **Two contracts, not one**: Separates ETH collection (pre-token) from token distribution (post-token). Clean lifecycle boundary. Token doesn't need to exist during presale.
- **Both pricing modes**: Decision on which to deploy can be deferred to launch prep. One codebase, tested for both.
- **Claim contract reads presale directly**: No merkle tree needed. Single source of truth. Simpler. Snapshot backup provides resilience.
- **Everything configurable**: No parameters hardcoded. Owner can tune up to the moment of opening.
- **PRBMathUD60x18 for curve math**: Audited fixed-point library. Eliminates intermediate truncation bugs. Industry standard.
- **REFUNDING as terminal state**: Prevents refund/finalize race condition where users could lose ETH.
- **Emergency dead-man's switch**: Permissionless `emergencyRefunds()` after configurable deadline. Owner key loss cannot permanently lock user funds. Trust-minimizing design.

## Alternatives Considered

- **Merkle airdrop for claims**: Simpler claim contract but requires off-chain merkle tree generation. Cross-contract read is simpler and trustless.
- **Single contract (presale + claim)**: Mixes ETH handling with token handling. Harder to audit. Token must exist at presale time.
- **Launchpad integration**: Gives up control of the experience. The presale IS the first impression.
- **Inline safe math instead of PRBMath**: Lower dependency count but higher precision risk. PRBMath is worth the dependency for correctness.
- **Polynomial bonding curve**: More flexible but harder to audit and explain. Linear is sufficient for a presale.

## Consequences

- Two deploy steps at TGE (PresaleClaim + DataToken)
- PresaleClaim must be tax-excluded on DataToken
- Bonding curve math requires careful fuzz testing for precision
- Frontend must handle both pricing display modes
- GhostPresale is a permanent runtime dependency for PresaleClaim (mitigated by snapshot backup)
- PRBMath (`@prb/math@^4.0.0`) is an additional dependency (well-audited, widely used)
- Emergency deadline must be set thoughtfully — too short and it limits legitimate presale duration; too long and it delays emergency recovery

## Gas Cost Considerations

MegaETH has different gas costs than vanilla EVM (MegaEVM). Key considerations:

| Operation | Estimated Gas | Notes |
|-----------|--------------|-------|
| `contribute()` — tranche, single tranche | ~60k | Simple: read state, compute price, write allocation |
| `contribute()` — tranche, cross-boundary | ~80-120k | Multiple tranche reads + writes per boundary crossed |
| `contribute()` — bonding curve | ~80-100k | PRBMath sqrt + mul/div operations |
| `contribute()` with ETH refund | +~10k | Additional low-level call for excess ETH |
| `claim()` | ~50k | Cross-contract read + SafeERC20 transfer |
| `preview()` | ~30k (view) | Same math as contribute, no state changes |

On MegaETH, use `--skip-simulation --gas-limit 500000 --legacy` for deployment scripts. The presale contract itself is straightforward enough that gas shouldn't be a concern for users — single external call, no loops over unbounded data.

## Max Raise Scenarios

The presale has no hard raise cap. What happens under different outcomes:

| Scenario | ETH Raised | Implication |
|----------|-----------|-------------|
| Underfill (< 50% sold) | < ~25 ETH | Lower initial liquidity. Consider extending presale or adjusting pricing. |
| Target fill (100% sold) | ~50-80 ETH | Healthy raise. Sufficient for LP seeding + runway. |
| FOMO surge (sells out fast) | ~50-80 ETH | Good signal but early buyers got all supply. Consider if curve was priced too low. |

Since supply is capped (default 15M $DATA), the max raise is bounded by `totalSupply × endPrice` even in bonding curve mode. At suggested parameters (15M tokens, end price $0.010), theoretical max raise ≈ 75 ETH (at ~$2k/ETH). This is a known, bounded outcome.

**If pricing needs adjustment pre-open:** All parameters are configurable in PENDING state. This is why we defer parameter finalization to launch prep.

## Precision Testing Requirements

The bonding curve quadratic solver is the highest-risk component. Required testing:

1. **Fuzz testing**: 100,000+ runs across full parameter space (see spec §8.3 for ranges)
2. **Boundary tests**: 1 wei contribution, max uint128 contribution, supply nearly full, supply empty
3. **Round-trip verification**: For every `_curveTokensForETH(x)` result Z, verify `_curveCostForTokens(Z)` ≈ x (within 1 wei tolerance)
4. **Monotonicity**: Verify `currentPrice()` never decreases after a contribution
5. **Conservation**: Verify `actualCost + refund == msg.value` for every contribution
6. **PRBMath overflow**: Verify no revert for any valid input combination (PRBMath reverts on overflow rather than wrapping)

These tests must pass before any testnet deployment.
