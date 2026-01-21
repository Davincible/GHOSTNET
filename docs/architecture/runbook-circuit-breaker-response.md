# Operational Runbook: Circuit Breaker Response

**Document Version:** 1.0  
**Last Updated:** 2026-01-21  
**Owner:** GHOSTNET Security Team  
**Classification:** Internal Operations

---

## Table of Contents

1. [Overview](#1-overview)
2. [Alert Triage](#2-alert-triage)
3. [Investigation Procedures](#3-investigation-procedures)
4. [Response Actions](#4-response-actions)
5. [Reset Procedures](#5-reset-procedures)
6. [Post-Incident](#6-post-incident)
7. [Contact Information](#7-contact-information)

---

## 1. Overview

### What is the Circuit Breaker?

The circuit breaker is an automated safety mechanism that halts all payouts from ArcadeCore when anomalous activity is detected:

| Limit Type | Threshold | Trigger |
|------------|-----------|---------|
| Single Payout | 500,000 DATA | Any single payout exceeds this |
| Hourly Payouts | 5,000,000 DATA | Total payouts in 1 hour exceed this |
| Daily Payouts | 20,000,000 DATA | Total payouts in 24 hours exceed this |

### What Happens When It Trips?

```
TRIPPED STATE:
- All creditPayout() calls REVERT
- New game entries are BLOCKED
- Existing pending payouts CAN still be withdrawn
- Player funds are NEVER locked
```

### Reset Process

```
Full Reset Timeline:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Trip Event          Proposal           12h Timelock              Execution
    │                  │                    │                        │
    ▼                  ▼                    ▼                        ▼
┌────────┐        ┌────────┐          ┌──────────┐             ┌────────┐
│ DETECT │  ───►  │PROPOSE │  ───►    │  WAIT    │     ───►    │EXECUTE │
│        │        │ RESET  │          │ (12hrs)  │             │ RESET  │
└────────┘        └────────┘          └──────────┘             └────────┘
                                           │
                                     Guardian can
                                       VETO here
```

---

## 2. Alert Triage

### 2.1 Initial Alert Receipt

When you receive a `CircuitBreakerTripped` alert:

1. **Acknowledge** the alert in monitoring system
2. **Note the time** - you have 12+ hours, but act promptly
3. **Gather initial context**:

```bash
# Quick status check (run from safe machine)
cast call $ARCADE_CORE "isCircuitBreakerTripped()" --rpc-url $RPC

# Get trip details from events
cast logs --address $ARCADE_CORE \
  "CircuitBreakerTrippedWithTimestamp(string,uint256,uint256)" \
  --from-block -1000 --rpc-url $RPC
```

### 2.2 Classification Matrix

| Scenario | Priority | Initial Response |
|----------|----------|------------------|
| Trip during expected high activity (product launch, airdrop) | P3 | Investigate, likely false positive |
| Trip during normal hours, no known cause | P2 | Investigate urgently |
| Trip with suspicious on-chain activity | P1 | ASSUME COMPROMISE |
| Multiple trips in short succession | P1 | ASSUME COMPROMISE |
| Trip + admin action you didn't authorize | P0 | ACTIVE INCIDENT |

### 2.3 P0/P1 Immediate Actions

If classified as P0 or P1:

1. **DO NOT propose reset** - assume admin key may be compromised
2. **Notify guardian** immediately to be ready to veto any unauthorized proposals
3. **Check for unauthorized proposals**:

```bash
# Check recent proposals
cast logs --address $ARCADE_CORE \
  "CircuitBreakerResetProposed(bytes32,address,uint256,uint256)" \
  --from-block -1000 --rpc-url $RPC
```

4. **Escalate to security lead** - do not attempt to fix alone

---

## 3. Investigation Procedures

### 3.1 Data Collection

Gather the following data:

```bash
# 1. Current contract state
cast call $ARCADE_CORE "getPayoutLimits()(uint256,uint256,uint256,uint256,uint256)" --rpc-url $RPC
# Returns: hourlyUsed, dailyUsed, hourlyMax, dailyMax, singleMax

# 2. Recent large payouts (last 1000 blocks)
cast logs --address $ARCADE_CORE \
  "PayoutCredited(address,address,uint256,uint256)" \
  --from-block -1000 --rpc-url $RPC | \
  jq 'select(.topics[2] != null) | {player: .topics[1], amount: .data}' | \
  sort -k2 -rn | head -20

# 3. Recent game settlements
cast logs --address $ARCADE_CORE \
  "GameSettled(address,address,uint256,uint256,uint256,bool)" \
  --from-block -1000 --rpc-url $RPC

# 4. Check for flash loan indicators (multiple large wagers same block)
# This requires indexer query - see Section 3.3
```

### 3.2 Root Cause Categories

| Category | Indicators | Typical Cause |
|----------|------------|---------------|
| **Legitimate Activity** | Gradual increase, many small payouts, known event | Product launch, promotion, whale activity |
| **Game Bug** | Single game, unusual payout patterns | Logic error in game contract |
| **Exploit** | Rapid, large payouts, unusual patterns | Vulnerability being exploited |
| **Oracle Manipulation** | Randomness-dependent games affected | Seed prediction attack |
| **Admin Compromise** | Unauthorized transactions from admin | Key compromise |

### 3.3 Indexer Queries

```sql
-- Large payouts in the last hour
SELECT 
    game_address,
    player_address,
    amount,
    session_id,
    block_timestamp
FROM arcade_payouts
WHERE block_timestamp > NOW() - INTERVAL '1 hour'
ORDER BY amount DESC
LIMIT 50;

-- Wagers per block by player (flash loan detection)
SELECT 
    player_address,
    block_number,
    SUM(amount) as total_wagered,
    COUNT(*) as wager_count
FROM arcade_entries
WHERE block_timestamp > NOW() - INTERVAL '1 hour'
GROUP BY player_address, block_number
HAVING SUM(amount) > 10000 * 1e18  -- 10k DATA threshold
ORDER BY total_wagered DESC;

-- Game-by-game breakdown
SELECT 
    game_address,
    COUNT(*) as settlement_count,
    SUM(payout) as total_payouts,
    AVG(payout) as avg_payout
FROM arcade_settlements
WHERE block_timestamp > NOW() - INTERVAL '1 hour'
GROUP BY game_address
ORDER BY total_payouts DESC;
```

### 3.4 Investigation Checklist

- [ ] What limit was exceeded? (single/hourly/daily)
- [ ] Which game(s) are involved?
- [ ] Is activity spread across many users or concentrated?
- [ ] Are payouts within expected ranges for the game?
- [ ] Any unusual seed/randomness patterns?
- [ ] Any new or recently updated game contracts involved?
- [ ] Any admin transactions you didn't authorize?
- [ ] Any pending proposals you didn't create?

---

## 4. Response Actions

### 4.1 Decision Tree

```
Investigation Complete
         │
         ▼
   Is it legitimate?
         │
    ┌────┴────┐
    ▼         ▼
   YES        NO
    │          │
    ▼          ▼
Propose     What type?
 Reset         │
               ├── Game Bug ──► Pause game, then propose reset
               │
               ├── Exploit ──► DO NOT RESET, containment mode
               │
               └── Admin Compromise ──► Revoke keys, guardian alert
```

### 4.2 Action: False Positive Recovery

If investigation confirms legitimate activity:

1. **Document findings** in incident log
2. **Consider raising limits** if activity is expected to continue
3. **Propose reset**:

```bash
# Propose circuit breaker reset
cast send $ARCADE_CORE "proposeCircuitBreakerReset()" \
  --private-key $ADMIN_KEY --rpc-url $RPC

# Save the reset ID from events
cast logs --address $ARCADE_CORE \
  "CircuitBreakerResetProposed(bytes32,address,uint256,uint256)" \
  --from-block -1 --rpc-url $RPC
```

4. **Notify team** that reset is proposed
5. **Set reminder** for 12h execution window

### 4.3 Action: Game Bug Containment

If a specific game has a bug:

1. **Pause the problematic game**:

```bash
cast send $GAME_REGISTRY "pauseGame(address)" $BUGGY_GAME \
  --private-key $ADMIN_KEY --rpc-url $RPC
```

2. **Assess impact** - are pending payouts legitimate?
3. **If bug is contained**, propose circuit breaker reset
4. **Schedule game fix** and security review

### 4.4 Action: Active Exploit

If an exploit is confirmed:

1. **DO NOT RESET CIRCUIT BREAKER** - it's doing its job
2. **Pause the entire contract** if needed:

```bash
cast send $ARCADE_CORE "pause()" \
  --private-key $PAUSER_KEY --rpc-url $RPC
```

3. **Alert guardian** to veto any pending resets
4. **Document all attacker addresses**
5. **Prepare incident report**
6. **Engage security partners** (auditors, white hats)

### 4.5 Action: Admin Key Compromise

If admin key may be compromised:

1. **Alert guardian IMMEDIATELY** - they must veto any unauthorized proposals
2. **Verify guardian key is secure** (separate storage/custody)
3. **Check for pending proposals** and have guardian veto all
4. **Begin key rotation** via AccessControlDefaultAdminRules:

```bash
# This takes 3 days (admin delay)
cast send $ARCADE_CORE "beginDefaultAdminTransfer(address)" $NEW_ADMIN \
  --private-key $OLD_ADMIN_KEY --rpc-url $RPC
```

5. **Monitor for unauthorized actions** during transfer period

---

## 5. Reset Procedures

### 5.1 Full Reset (After 12h Timelock)

**Prerequisites:**
- Investigation complete
- Root cause identified and addressed
- 12 hours have elapsed since proposal
- Guardian has not vetoed

**Steps:**

```bash
# 1. Verify proposal is ready
cast call $ARCADE_CORE "canExecuteReset(bytes32)(bool,string)" $RESET_ID --rpc-url $RPC

# 2. Verify no re-trips occurred
cast call $ARCADE_CORE "getLastTripTimestamp()" --rpc-url $RPC

# 3. Execute reset
cast send $ARCADE_CORE "executeCircuitBreakerReset(bytes32)" $RESET_ID \
  --private-key $ADMIN_KEY --rpc-url $RPC

# 4. Verify reset successful
cast call $ARCADE_CORE "isCircuitBreakerTripped()" --rpc-url $RPC
```

### 5.2 Partial Reset (Counters Only)

Use when you want to allow limited activity while investigation continues:

```bash
# Reset counters but keep breaker armed
cast send $ARCADE_CORE "resetPayoutCounters()" \
  --private-key $ADMIN_KEY --rpc-url $RPC
```

**Important:** After partial reset, the breaker will trip again at the same thresholds. Use this only to:
- Allow some legitimate activity to continue
- Test if the problematic pattern repeats
- Buy time while preparing a full reset proposal

### 5.3 Guardian Veto

If guardian needs to veto a proposal:

```bash
cast send $ARCADE_CORE "vetoCircuitBreakerReset(bytes32,string)" \
  $RESET_ID "Unauthorized proposal during investigation" \
  --private-key $GUARDIAN_KEY --rpc-url $RPC
```

---

## 6. Post-Incident

### 6.1 Immediate Post-Reset

- [ ] Verify all games are operational
- [ ] Check player withdrawal backlog (help anyone stuck)
- [ ] Update monitoring thresholds if needed
- [ ] Close incident in tracking system

### 6.2 Within 24 Hours

- [ ] Complete incident report
- [ ] Identify any process improvements
- [ ] Update this runbook if needed
- [ ] Notify affected users if appropriate

### 6.3 Incident Report Template

```markdown
# Circuit Breaker Incident Report

**Date:** YYYY-MM-DD
**Duration:** HH:MM - HH:MM (X hours)
**Classification:** [False Positive / Bug / Exploit / Unknown]

## Timeline
- HH:MM - Circuit breaker tripped (reason)
- HH:MM - Alert acknowledged by (name)
- HH:MM - Investigation started
- HH:MM - Root cause identified
- HH:MM - Reset proposed
- HH:MM - Reset executed

## Root Cause
[Description of what caused the trip]

## Impact
- Players affected: N
- Total payouts delayed: X DATA
- Games affected: [list]

## Resolution
[What was done to resolve]

## Prevention
[Changes to prevent recurrence]

## Lessons Learned
[What we learned]
```

---

## 7. Contact Information

### On-Call Rotation

| Role | Primary | Backup |
|------|---------|--------|
| Security Lead | [REDACTED] | [REDACTED] |
| Engineering Lead | [REDACTED] | [REDACTED] |
| Guardian Holder #1 | [REDACTED] | [REDACTED] |
| Guardian Holder #2 | [REDACTED] | [REDACTED] |

### External Contacts

| Service | Contact | When to Use |
|---------|---------|-------------|
| Audit Partner | [REDACTED] | Suspected exploit |
| Legal | [REDACTED] | Any incident involving potential loss |
| Comms | [REDACTED] | User-facing impact |

### Key Addresses

```
ARCADE_CORE:     0x... [FILL IN AFTER DEPLOYMENT]
GAME_REGISTRY:   0x... [FILL IN AFTER DEPLOYMENT]
GUARDIAN_MSIG:   0x... [FILL IN AFTER DEPLOYMENT]
ADMIN_TIMELOCK:  0x... [FILL IN AFTER DEPLOYMENT]
```

---

## Appendix A: Quick Reference Card

```
┌──────────────────────────────────────────────────────────────────────┐
│                    CIRCUIT BREAKER QUICK REFERENCE                   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  CHECK STATUS:                                                       │
│    cast call $ARCADE_CORE "isCircuitBreakerTripped()" --rpc-url $RPC│
│                                                                      │
│  PROPOSE RESET (starts 12h timer):                                   │
│    cast send $ARCADE_CORE "proposeCircuitBreakerReset()" ...        │
│                                                                      │
│  EXECUTE RESET (after 12h):                                          │
│    cast send $ARCADE_CORE "executeCircuitBreakerReset(bytes32)" ... │
│                                                                      │
│  PARTIAL RESET (counters only, immediate):                           │
│    cast send $ARCADE_CORE "resetPayoutCounters()" ...               │
│                                                                      │
│  GUARDIAN VETO:                                                      │
│    cast send $ARCADE_CORE "vetoCircuitBreakerReset(bytes32,string)" │
│                                                                      │
│  EMERGENCY PAUSE:                                                    │
│    cast send $ARCADE_CORE "pause()" --private-key $PAUSER_KEY       │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│  LIMITS: Single 500k | Hourly 5M | Daily 20M                        │
│  TIMELOCK: 12 hours | EXPIRY: 48 hours                              │
└──────────────────────────────────────────────────────────────────────┘
```

---

*This document is maintained by the GHOSTNET Security Team. Report issues to security@ghostnet.game*
