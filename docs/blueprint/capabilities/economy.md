---
type: capability
domain: economy
updated: 2026-01-27
tags:
  - type/capability
  - domain/economy
---

# Economy

## Overview

GHOSTNET's economy is designed to be **self-correcting and deflationary**. Unlike "Ponzi-Games" that rely on inflation to pay yield, GHOSTNET harvests "dead capital" through redistribution. The protocol operates as a **Reverse Pyramid** where high-risk players (degens) generate sustainable yield for risk-averse players (whales).

The economic engine has multiple burn mechanisms (the "Hyper-Furnace") that create constant deflationary pressure on the $DATA token supply.

## Concepts

### The Reverse Pyramid

Capital flows UP from high-risk zones to safe zones:

```
BLACK ICE deaths    -> Split among VAULT, MAINFRAME, SUBNET, DARKNET
DARKNET deaths      -> Split among VAULT, MAINFRAME, SUBNET
SUBNET deaths       -> Split among VAULT, MAINFRAME
MAINFRAME deaths    -> Split to VAULT only
VAULT deaths        -> N/A (0% death rate)
```

This creates sustainable yield without inflation:
- High-risk players (degens) feed low-risk players (whales)
- The VAULT earns yield from ALL deaths below
- More degen activity = higher whale yields

### The Hyper-Furnace

A multi-engine buyback & burn system that creates constant deflationary pressure:

1. **The Cascade** - 30% of all deaths burned
2. **ETH Toll Booth** - Protocol actions cost ETH, converted to burns
3. **Trading Tax** - 10% tax on DEX trades, 9% burned
4. **Dead Pool Rake** - 5% of all betting pools burned
5. **Consumables** - Items purchased with $DATA are burned

---

## Capabilities

### 🟣 FR-ECON-001: The Cascade

**What:** When a player is traced, their capital is redistributed via the 60/30/10 rule.

**How it works:**

For a traced position of 100 $DATA:

```
60% -> THE REWARD POOL (60 $DATA)
       Split between:
       - 30 $DATA -> Survivors of SAME level (Jackpot)
       - 30 $DATA -> Sent UPWARD to safer levels (Yield)

30% -> THE FURNACE (30 $DATA)
       Action: Sent immediately to burn address
       Result: Permanent supply reduction (DEFLATION)

10% -> PROTOCOL REVENUE (10 $DATA)
       Action: Sent to Protocol Treasury
       Use: Operations, development, marketing
```

**Feed Visualization:**

```
> 0x9c2d TRACED [DARKNET] -100 $DATA
> CASCADE INITIATED:
>   -> 30 $DATA to DARKNET survivors
>   -> 10 $DATA to SUBNET holders
>   -> 10 $DATA to MAINFRAME holders
>   -> 10 $DATA to VAULT holders
>   -> 30 $DATA BURNED
>   -> 10 $DATA to Protocol
```

**Upward Stream Logic:**

| Source Level | Recipients |
|--------------|------------|
| BLACK ICE | VAULT, MAINFRAME, SUBNET, DARKNET |
| DARKNET | VAULT, MAINFRAME, SUBNET |
| SUBNET | VAULT, MAINFRAME |
| MAINFRAME | VAULT only |

**Related:** [[FR-CORE-006]], [[FR-ECON-003]]

---

### 🟣 FR-ECON-002: Burn Engine - Protocol Fee

**What:** 5% fee on all extractions, contributing to protocol revenue and burns.

**How it works:**

1. Player extracts position (stake + yield)
2. 5% deducted from total extracted amount
3. Fee goes to protocol treasury
4. Treasury periodically converts to burns

**Example:**

```
Extraction: 1,000 $DATA total
Protocol Fee: 50 $DATA (5%)
Player Receives: 950 $DATA
```

**Constraints:**

- Fee cannot be avoided
- Applied after yield calculation
- Does not compound with other fees

**Related:** [[FR-CORE-002]]

---

### 🟣 FR-ECON-003: Burn Engine - Death Tax

**What:** 30% of all traced positions are permanently burned as part of The Cascade.

**How it works:**

1. Position gets traced
2. The Cascade splits the dead capital:
   - 30% to same-level survivors (Jackpot)
   - 30% to higher-level survivors (Upward stream)
   - **30% burned permanently** (sent to 0xdead)
   - 10% to protocol treasury
3. Burn is atomic with death event

**Impact Calculation:**

At $100,000 daily protocol volume with ~$30k in deaths:
- Death burn: ~9,000 $DATA/day (30% of $30k)

**Related:** [[FR-ECON-001]], [[FR-CORE-006]]

---

### 🧠 FR-ECON-004: Burn Engine - Risk Boost

**What:** Burns required when purchasing risk-reduction items or upgrades.

**Planned approach:**

Consumable items purchased from the "Black Market" are burned:

| Item | Cost (Burned) | Effect |
|------|---------------|--------|
| Stimpack | 50 $DATA | +25% yield for 4h |
| EMP | 100 $DATA | Pause your timer 1h |
| Ghost Protocol | 200 $DATA | Skip one trace scan |
| Exploit Kit | 75 $DATA | Unlock hack run paths |
| ICE Breaker | 150 $DATA | -10% trace rate for 24h |

**Notes:**

Still being defined. Need to balance item power with burn amounts.

**Related:** [[FR-GAME-002]]

---

### 🧠 FR-ECON-005: Burn Engine - Crew Tax

**What:** $DATA burned when forming or maintaining crews.

**Planned approach:**

- Crew formation: One-time burn (amount TBD)
- Crew upgrades: Burns to unlock bonus tiers
- Crew raids: Entry burns

**Notes:**

Crew system is still in draft. Burn amounts TBD.

**Related:** [[FR-SOCIAL-003]]

---

### 🚧 FR-ECON-006: Burn Engine - Mini-game Entry

**What:** Entry fees for arcade games are burned.

**How it works:**

Each arcade game has an entry fee structure:

| Game | Entry Fee | Burn % |
|------|-----------|--------|
| Hash Crash | 10-1000 $DATA | 3% rake |
| Code Duel | 50-500 $DATA | 10% burn |
| Daily Ops | Free | Streak rewards from treasury |
| ICE Breaker | 25 $DATA | 100% entry |
| Binary Bet | 10-500 $DATA | 5% rake |
| Bounty Hunt | 50-500 $DATA | 100% entry |

**Implementation Status:**

- Hash Crash: Contract complete, frontend complete
- Code Duel: Contract complete, awaiting matchmaking service
- Daily Ops: Contract complete, frontend complete

See [[design/arcade/]] for detailed specifications.

**Related:** [[FR-GAME-001]] through [[FR-GAME-009]]

---

### 🟣 FR-ECON-007: Token Supply

**What:** $DATA has a fixed 100M supply with deflationary mechanics.

**Token Distribution:**

| Allocation | % | Amount | Vesting |
|------------|---|--------|---------|
| The Mine (Game Rewards) | 60% | 60,000,000 | 24-month linear |
| Presale | 15% | 15,000,000 | 100% at TGE |
| Liquidity | 9% | 9,000,000 | BURNED at launch |
| Team | 8% | 8,000,000 | 1-month cliff, 24-month linear |
| Treasury | 8% | 8,000,000 | Unlocked |

**Key Properties:**

- Total Supply: 100,000,000 $DATA (fixed, never increases)
- Launch FDV: $500,000
- Initial Price: $0.005 per $DATA
- Network: MegaETH

**Sustainability Analysis:**

```
Daily Emission (from Mine): ~82,000 $DATA

BURN SOURCES (at $100k daily volume):
- Game Deaths (30% of ~$30k):     ~9,000 $DATA
- ETH Toll ($1.80 x ~2000 txns):  ~3,600 $DATA (via buyback)
- Trading Tax (9% of ~$50k):      ~4,500 $DATA
- Dead Pool Rake (5% of ~$10k):   ~500 $DATA
- Consumables:                    ~1,000 $DATA
                                  ─────────────
TOTAL DAILY BURN:                 ~18,600 $DATA

BREAK-EVEN POINT:
At ~$175k daily volume, burns exceed emissions = NET DEFLATION
```

**Related:** [[FR-ECON-001]] through [[FR-ECON-009]]

---

### 🧠 FR-ECON-008: ETH Toll Booth

**What:** $2.00 flat fee in ETH for every protocol interaction.

**Planned approach:**

Triggered by:
- Jack In (Deposit)
- Extract (Withdraw)
- Claim Rewards
- Enter Hack Run
- Place Dead Pool Bet

Fee Distribution:
- 90% ($1.80) -> AUTO-BUYBACK (swaps ETH for $DATA, burns it)
- 10% ($0.20) -> OPERATIONS (server costs, gas reserves)

**Notes:**

This creates a floor on burn activity independent of $DATA price. If token price dumps, trading tax burns less but ETH toll still burns.

---

### 🧠 FR-ECON-009: Trading Tax

**What:** 10% tax on all $DATA DEX trades.

**Planned approach:**

On every buy/sell:
- 9% -> THE FURNACE (burned directly)
- 1% -> TREASURY (marketing, CEX listings)

**The Dual-Engine Effect:**

- If token price dumps -> Trading Tax burns more supply
- If price stable but people play -> ETH Toll burns supply
- Both actions create buy pressure and reduce supply
- "This is why the chart pumps regardless of direction"

---

### 🧠 FR-ECON-010: Claim Rewards Without Extract

**Summary:** Users can claim accrued yield without closing their position.

**Planned Behavior:**

1. User calls `claimYield()`
2. Contract calculates accumulated yield
3. Protocol fee (5%) deducted from yield
4. Remaining yield transferred to user
5. Position remains active with reset yield counter
6. Event emitted: `YieldClaimed(address user, uint256 level, uint256 amount)`

**Constraints:**

- Only accumulated yield is claimed, principal stays staked
- 5% protocol fee applies (same as extraction)
- Cannot claim during lock period (60 seconds before scan)
- Minimum claim threshold (e.g., 10 $DATA) to prevent gas griefing

**Rationale:** Allows users to take profits while staying in the game. Useful for long-term players who want to realize gains without losing their position or risk level.

**Design Decision Needed:** Should this reset survival streak? Arguments both ways.

**Related:**
- [[FR-CORE-002]] - Extract (full withdrawal)
- [[FR-CORE-005]] - Yield Accrual

---

### 🟣 FR-ECON-011: Protocol Fee Distribution

**Summary:** Fees collected are transparently distributed to treasury and burns.

**Behavior:**

Protocol revenue sources:
- 5% extraction fee (FR-ECON-002)
- 10% of Cascade (FR-ECON-001)
- 10% of Collapse penalty (FR-CORE-007)
- ETH Toll operations portion (FR-ECON-008)

Revenue distribution:
- Treasury receives fees in $DATA and ETH
- Treasury is a multisig (3-of-5 minimum)
- Periodic buyback and burn from treasury (manual or automated)
- Transparent accounting via on-chain events

**Events:**

- `FeeCollected(address source, uint256 amount, string feeType)`
- `TreasuryWithdraw(address destination, uint256 amount)`
- `TreasuryBurn(uint256 amount)`

**Rationale:** Transparent fee accounting builds trust. Users can verify that protocol revenue is handled as documented.

**Related:**
- [[FR-ECON-002]] - Protocol fee on extractions
- [[quality#NFR-SEC-007]] - Key management

---

## Domain Rules

### Business Rules

| Rule | Description |
|------|-------------|
| Burns are immediate | Tokens sent to burn address atomically with triggering event |
| Cascade is deterministic | Same death always produces same split |
| No mint function | $DATA supply can only decrease, never increase |
| Treasury is multisig | Protocol revenue requires multi-signature withdrawal |

### Validation Rules

| Field | Rule | Error |
|-------|------|-------|
| Burn amount | > 0 | "Cannot burn zero tokens" |
| Cascade recipient | Valid address | "Invalid cascade recipient" |

---

## Domain Invariants

> [!warning] Must Always Be True

1. **Sum of cascade = 100%** - 60% + 30% + 10% must equal traced amount
2. **Burns are irreversible** - Once burned, tokens cannot be recovered
3. **Supply only decreases** - No mechanism exists to mint new $DATA
4. **Protocol fee consistent** - 5% on all extractions, no exceptions

---

## Integration Points

### With Core Domain

- Deaths trigger The Cascade
- Extractions trigger protocol fee
- All staking actions trigger ETH Toll

### With Mini-Games Domain

- Entry fees contribute to burns
- Rake from pools contributes to burns
- Consumable purchases burn tokens

### With Social Domain

- Crew formation burns tokens
- Crew upgrades burn tokens

---

## Related

- [[architecture#economic-engine]]
- [[core#death-handling]]
- [[design/arcade/]] - Mini-game burn rates
