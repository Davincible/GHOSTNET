# GHOSTNET Emergency Procedures

**Version:** 1.0  
**Status:** Planning  
**Last Updated:** 2026-01-20

---

## Table of Contents

1. [Overview](#1-overview)
2. [Severity Levels](#2-severity-levels)
3. [Incident Response Team](#3-incident-response-team)
4. [Emergency Procedures](#4-emergency-procedures)
5. [Contract Pause Procedures](#5-contract-pause-procedures)
6. [Emergency Upgrade Procedures](#6-emergency-upgrade-procedures)
7. [Communication Templates](#7-communication-templates)
8. [Post-Incident Procedures](#8-post-incident-procedures)
9. [Runbooks](#9-runbooks)
10. [Contact Information](#10-contact-information)

---

## 1. Overview

### Purpose

This document defines procedures for responding to security incidents, critical bugs, and emergency situations in the GHOSTNET protocol. All team members with operational responsibilities must be familiar with these procedures.

### Scope

Covers all deployed GHOSTNET contracts:
- **GhostCore.sol** (UUPS) - Core game logic
- **TraceScan.sol** (UUPS) - Death selection
- **RewardsDistributor.sol** (UUPS) - Emissions
- **DeadPool.sol** (UUPS) - Prediction market
- **DataToken.sol** (Immutable) - Token contract
- **FeeRouter.sol** - Fee handling

### Key Contacts

| Role | Responsibility | Contact |
|------|----------------|---------|
| Incident Commander | Overall coordination | [TBD] |
| Technical Lead | Contract diagnosis | [TBD] |
| Communications Lead | User updates | [TBD] |
| Multisig Signers | Emergency actions | [TBD - 3 of 5] |

---

## 2. Severity Levels

### SEV-1: Critical (Funds at Immediate Risk)

**Definition:** Active exploit draining funds, or imminent loss of user funds.

**Examples:**
- Active drain of protocol funds
- Reentrancy attack in progress
- Oracle manipulation stealing funds
- Compromised admin key being used

**Response Time:** Immediate (< 15 minutes)

**Actions:**
1. PAUSE all contracts immediately
2. Alert all incident response team members
3. Begin active monitoring of exploit transactions
4. Coordinate multisig for emergency actions

### SEV-2: High (Vulnerability Discovered)

**Definition:** Exploitable vulnerability discovered but not yet exploited.

**Examples:**
- Critical bug found in death calculation
- Signature replay vulnerability identified
- Access control flaw discovered
- Economic exploit vector identified

**Response Time:** < 1 hour

**Actions:**
1. Assess if pause is needed
2. Gather incident response team
3. Evaluate fix options
4. Prepare emergency upgrade if needed

### SEV-3: Medium (Degraded Functionality)

**Definition:** System functionality impaired but funds not at risk.

**Examples:**
- TraceScan keeper failing to execute scans
- Rewards distribution delayed
- WebSocket gateway down
- Indexer lagging significantly

**Response Time:** < 4 hours

**Actions:**
1. Diagnose root cause
2. Implement temporary workaround
3. Schedule proper fix
4. Monitor for escalation

### SEV-4: Low (Minor Issue)

**Definition:** Minor issues not affecting core functionality.

**Examples:**
- UI display bugs
- Non-critical event emission issues
- Documentation errors
- Minor gas inefficiencies

**Response Time:** < 24 hours

**Actions:**
1. Log issue
2. Schedule fix in next release
3. No emergency procedures needed

---

## 3. Incident Response Team

### Roles

```
                    ┌─────────────────────────┐
                    │   Incident Commander    │
                    │   (Overall authority)   │
                    └───────────┬─────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          │                     │                     │
          ▼                     ▼                     ▼
┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
│   Technical Lead    │ │  Communications     │ │   Operations        │
│   ────────────────  │ │  Lead               │ │   Lead              │
│ • Diagnose issue    │ │  ──────────────     │ │   ──────────────    │
│ • Coordinate fix    │ │ • User updates      │ │ • Monitor systems   │
│ • Execute upgrades  │ │ • Social media      │ │ • Coordinate signers│
│ • Verify resolution │ │ • Partner comms     │ │ • Log timeline      │
└─────────────────────┘ └─────────────────────┘ └─────────────────────┘
```

### Incident Commander Responsibilities

1. **Declare incident** and assign severity level
2. **Coordinate** all response activities
3. **Make decisions** when team disagrees
4. **Authorize** emergency actions (pause, upgrade)
5. **Declare resolution** when incident is over

### Escalation Path

```
Developer finds issue
        │
        ▼
    Is it SEV-1?
    ┌───┴───┐
    │       │
   YES      NO
    │       │
    ▼       ▼
 PAUSE    Is it SEV-2?
 FIRST    ┌───┴───┐
    │     │       │
    │    YES      NO
    │     │       │
    │     ▼       ▼
    │  Alert    Standard
    │  Team     Process
    │     │
    └──►──┴──► Incident Commander
                takes control
```

---

## 4. Emergency Procedures

### 4.1 SEV-1: Active Exploit Response

**Time-Critical Checklist:**

```
[ ] 1. PAUSE GhostCore (highest priority)
       Command: cast send $GHOST_CORE "pause()" --private-key $ADMIN_KEY
       
[ ] 2. PAUSE TraceScan
       Command: cast send $TRACE_SCAN "pause()" --private-key $ADMIN_KEY
       
[ ] 3. PAUSE DeadPool
       Command: cast send $DEAD_POOL "pause()" --private-key $ADMIN_KEY

[ ] 4. Alert incident response team (all channels)

[ ] 5. Monitor attacker transactions
       Block explorer: https://megaeth-testnet-v2.blockscout.com/
       
[ ] 6. Document timeline (start incident log)

[ ] 7. Assess damage
       - How much drained?
       - Which addresses affected?
       - Is attack ongoing?

[ ] 8. Post initial communication (use template)

[ ] 9. Begin fix development (parallel track)

[ ] 10. Coordinate multisig for any required actions
```

### 4.2 SEV-2: Vulnerability Response

**Checklist:**

```
[ ] 1. Assess exploitability
       - Can it be exploited now?
       - What's required to exploit?
       - Who knows about it?

[ ] 2. Decide on pause
       - If easily exploitable → PAUSE
       - If complex/unlikely → Monitor closely

[ ] 3. Document vulnerability
       - Root cause
       - Attack vector
       - Potential impact

[ ] 4. Develop fix
       - Code fix
       - Test fix
       - Review fix

[ ] 5. Decide on upgrade path
       - Standard timelock (48h) if not urgent
       - Emergency bypass if critical

[ ] 6. Prepare communications

[ ] 7. Execute fix

[ ] 8. Verify resolution

[ ] 9. Post-mortem
```

### 4.3 Emergency Contacts Activation

**SEV-1 Activation:**
1. Phone call to Incident Commander
2. Simultaneous message to all multisig signers
3. Alert in private team channel
4. NO public communication until pause confirmed

**SEV-2 Activation:**
1. Message to Incident Commander
2. Team channel alert
3. Scheduled call within 1 hour

---

## 5. Contract Pause Procedures

### 5.1 Who Can Pause

| Contract | Pause Authority | Recovery Authority |
|----------|-----------------|-------------------|
| GhostCore | DEFAULT_ADMIN_ROLE (Timelock or Emergency Multisig) | Same |
| TraceScan | DEFAULT_ADMIN_ROLE | Same |
| DeadPool | DEFAULT_ADMIN_ROLE | Same |
| RewardsDistributor | DEFAULT_ADMIN_ROLE | Same |

### 5.2 Pause Commands

**Using cast (Foundry):**

```bash
# Set environment variables
export GHOST_CORE=0x...
export TRACE_SCAN=0x...
export DEAD_POOL=0x...
export ADMIN_KEY=... # NEVER commit this

# Pause GhostCore
cast send $GHOST_CORE "pause()" \
  --rpc-url https://carrot.megaeth.com/rpc \
  --private-key $ADMIN_KEY

# Pause TraceScan
cast send $TRACE_SCAN "pause()" \
  --rpc-url https://carrot.megaeth.com/rpc \
  --private-key $ADMIN_KEY

# Pause DeadPool  
cast send $DEAD_POOL "pause()" \
  --rpc-url https://carrot.megaeth.com/rpc \
  --private-key $ADMIN_KEY
```

**Using Safe (Gnosis):**
1. Go to Safe interface
2. New Transaction → Contract Interaction
3. Enter contract address
4. Select `pause()` function
5. Execute (requires 3 of 5 signatures)

### 5.3 Pause Effects

**GhostCore paused:**
- `jackIn()` - Blocked
- `extract()` - Blocked (use `emergencyWithdraw()` instead)
- `claimRewards()` - Blocked
- `addStake()` - Blocked
- `applyBoost()` - Blocked
- `emergencyWithdraw()` - **ENABLED** (allows exit without rewards)

**TraceScan paused:**
- `executeScan()` - Blocked
- `submitDeaths()` - Blocked
- `finalizeScan()` - Blocked
- No automatic scans

**DeadPool paused:**
- `placeBet()` - Blocked
- `claimWinnings()` - Blocked
- `resolveRound()` - Blocked

### 5.4 Emergency Withdraw

When GhostCore is paused, users can exit via `emergencyWithdraw()`:

```solidity
function emergencyWithdraw() external whenPaused {
    Position storage pos = positions[msg.sender];
    require(pos.amount > 0, "No position");
    
    uint256 amount = pos.amount;
    delete positions[msg.sender];
    
    // Transfer principal only (no rewards)
    dataToken.transfer(msg.sender, amount);
    
    emit EmergencyWithdrawn(msg.sender, amount);
}
```

**Important:** Users forfeit pending rewards but recover principal.

### 5.5 Unpause Procedure

**Requirements:**
- Root cause identified
- Fix deployed OR risk mitigated
- Team consensus on safety
- Post-mortem scheduled

**Commands:**

```bash
# Unpause GhostCore
cast send $GHOST_CORE "unpause()" \
  --rpc-url https://carrot.megaeth.com/rpc \
  --private-key $ADMIN_KEY
```

---

## 6. Emergency Upgrade Procedures

### 6.1 Standard Upgrade Path (48-hour Timelock)

```
Developer → Propose → 48h Wait → Execute → Verify
                         ↑
                    Public notice
```

**Steps:**

1. **Prepare upgrade**
   ```bash
   # Deploy new implementation
   forge script script/DeployUpgrade.s.sol:DeployGhostCoreV2 \
     --rpc-url https://carrot.megaeth.com/rpc \
     --broadcast
   ```

2. **Propose via Timelock**
   ```bash
   # Queue upgrade (starts 48h timer)
   cast send $TIMELOCK "schedule(address,uint256,bytes,bytes32,bytes32,uint256)" \
     $GHOST_CORE \
     0 \
     $(cast calldata "upgradeToAndCall(address,bytes)" $NEW_IMPL "0x") \
     0x0 \
     0x0 \
     172800 \  # 48 hours
     --private-key $PROPOSER_KEY
   ```

3. **Wait 48 hours**

4. **Execute upgrade**
   ```bash
   cast send $TIMELOCK "execute(address,uint256,bytes,bytes32,bytes32)" \
     $GHOST_CORE \
     0 \
     $(cast calldata "upgradeToAndCall(address,bytes)" $NEW_IMPL "0x") \
     0x0 \
     0x0 \
     --private-key $EXECUTOR_KEY
   ```

5. **Verify**
   ```bash
   cast call $GHOST_CORE "implementation()" --rpc-url https://carrot.megaeth.com/rpc
   ```

### 6.2 Emergency Upgrade Path (Bypass Timelock)

**ONLY USE WHEN:**
- Funds are actively at risk (SEV-1)
- Waiting 48 hours would result in significant losses
- Fix is ready and tested
- 3 of 5 multisig signers agree

**Emergency Multisig Setup:**

The Emergency Multisig has `DEFAULT_ADMIN_ROLE` on all upgradeable contracts, allowing immediate upgrades without timelock.

**Steps:**

1. **Deploy fix**
   ```bash
   forge script script/DeployEmergencyFix.s.sol \
     --rpc-url https://carrot.megaeth.com/rpc \
     --broadcast
   ```

2. **Coordinate multisig** (requires 3 of 5)
   - Share new implementation address
   - Verify bytecode hash matches expected
   - Each signer reviews and signs

3. **Execute via Safe**
   - Contract: GhostCore proxy address
   - Function: `upgradeToAndCall(address,bytes)`
   - Parameters: new implementation, `0x` (no init data)

4. **Verify immediately**
   ```bash
   # Check implementation changed
   cast call $GHOST_CORE "implementation()"
   
   # Run verification tests
   forge test --match-contract GhostCoreV2Test
   ```

### 6.3 Emergency Upgrade Conditions

| Condition | Required? |
|-----------|-----------|
| Funds actively at risk | Yes |
| Fix tested on testnet | Yes |
| 3 of 5 multisig approval | Yes |
| Incident Commander approval | Yes |
| Public announcement within 24h | Yes |
| Post-mortem within 7 days | Yes |

---

## 7. Communication Templates

### 7.1 Initial Incident Notice (SEV-1)

```markdown
**GHOSTNET Security Notice**

We have identified an issue affecting the GHOSTNET protocol.

**Status:** Protocol is PAUSED for user safety
**Impact:** [Brief description - no technical details]
**User Action:** No action required. Your funds are safe.

We are actively investigating and will provide updates every [30 minutes / 1 hour].

Next update: [TIME]

Questions: [SUPPORT CHANNEL]
```

### 7.2 Progress Update

```markdown
**GHOSTNET Incident Update #[N]**

**Status:** [PAUSED / PARTIALLY OPERATIONAL / RESOLVED]
**Time since pause:** [X hours]

**Update:**
[Brief progress description]

**What we know:**
- [Bullet points]

**What we're doing:**
- [Bullet points]

**ETA to resolution:** [TIME or "investigating"]

Next update: [TIME]
```

### 7.3 Resolution Notice

```markdown
**GHOSTNET Incident Resolved**

The issue affecting GHOSTNET has been resolved. The protocol is now fully operational.

**Summary:**
- Issue detected: [TIME]
- Protocol paused: [TIME]  
- Issue resolved: [TIME]
- Total downtime: [DURATION]

**What happened:**
[Non-technical summary]

**Impact:**
- Users affected: [NUMBER / NONE]
- Funds at risk: [AMOUNT / NONE]
- Funds lost: [AMOUNT / NONE]

**Actions taken:**
- [Summary of fix]

**Next steps:**
- Full post-mortem will be published within 7 days
- [Any user actions needed]

We apologize for any inconvenience and thank you for your patience.
```

### 7.4 Post-Mortem Template

```markdown
# GHOSTNET Post-Mortem: [INCIDENT NAME]

**Date:** [DATE]
**Duration:** [START] to [END]
**Severity:** [SEV-1/2/3/4]
**Author:** [NAME]

## Executive Summary
[2-3 sentences describing what happened and impact]

## Timeline
| Time (UTC) | Event |
|------------|-------|
| HH:MM | Issue first detected |
| HH:MM | Incident declared |
| HH:MM | Contracts paused |
| ... | ... |
| HH:MM | Resolution confirmed |

## Root Cause
[Technical description of what went wrong]

## Impact
- **Users affected:** [NUMBER]
- **Funds at risk:** [AMOUNT]
- **Funds lost:** [AMOUNT]
- **Downtime:** [DURATION]

## Resolution
[What was done to fix the issue]

## Lessons Learned
### What went well
- [Bullet points]

### What went poorly
- [Bullet points]

### Where we got lucky
- [Bullet points]

## Action Items
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| [Action] | [Name] | [Date] | [Status] |

## Prevention
[How we'll prevent this from happening again]
```

---

## 8. Post-Incident Procedures

### 8.1 Immediate (Within 24 hours)

- [ ] Verify fix is holding
- [ ] Monitor for related issues
- [ ] Publish resolution notice
- [ ] Begin incident documentation
- [ ] Schedule post-mortem meeting

### 8.2 Short-term (Within 7 days)

- [ ] Complete and publish post-mortem
- [ ] Implement quick-win preventions
- [ ] Review monitoring/alerting gaps
- [ ] Update runbooks if needed
- [ ] Thank responders

### 8.3 Long-term (Within 30 days)

- [ ] Complete all action items from post-mortem
- [ ] Conduct tabletop exercise for similar scenarios
- [ ] Review and update emergency procedures
- [ ] Consider additional audits if warranted

---

## 9. Runbooks

### 9.1 TraceScan Keeper Failure

**Symptoms:**
- Scans not executing on schedule
- `canExecuteScan()` returns true but no execution

**Diagnosis:**
```bash
# Check if scan is due
cast call $TRACE_SCAN "canExecuteScan(uint8)" 3  # Level 3

# Check Gelato task status (if using Gelato)
# Visit: https://app.gelato.network/
```

**Resolution:**
```bash
# Manual execution (anyone can call)
cast send $TRACE_SCAN "executeScan(uint8)" 3 \
  --rpc-url https://carrot.megaeth.com/rpc \
  --private-key $ANY_KEY
```

### 9.2 Stuck Rewards Distribution

**Symptoms:**
- `getPendingRewards()` shows 0 for active positions
- `accRewardsPerShare` not increasing

**Diagnosis:**
```bash
# Check RewardsDistributor last distribution time
cast call $REWARDS_DIST "lastDistributionTime()"

# Check if distribution is callable
cast call $REWARDS_DIST "canDistribute()"
```

**Resolution:**
```bash
# Trigger manual distribution
cast send $REWARDS_DIST "distribute()" \
  --rpc-url https://carrot.megaeth.com/rpc \
  --private-key $KEEPER_KEY
```

### 9.3 System Reset Approaching

**Symptoms:**
- `systemReset.deadline` approaching
- No recent deposits extending it

**Monitoring:**
```bash
# Check deadline
cast call $GHOST_CORE "getSystemResetInfo()"

# Calculate time remaining
# deadline - block.timestamp
```

**If Reset is Desired:**
- Let it trigger naturally
- Anyone can call `triggerSystemReset()` after deadline

**If Reset Should Be Avoided:**
- Encourage deposits via social channels
- Consider protocol deposit if critical

---

## 10. Contact Information

### Emergency Contacts

| Role | Name | Phone | Telegram | Available |
|------|------|-------|----------|-----------|
| Incident Commander | [TBD] | [TBD] | [TBD] | 24/7 |
| Technical Lead | [TBD] | [TBD] | [TBD] | 24/7 |
| Communications | [TBD] | [TBD] | [TBD] | 24/7 |
| Multisig Signer 1 | [TBD] | [TBD] | [TBD] | [TBD] |
| Multisig Signer 2 | [TBD] | [TBD] | [TBD] | [TBD] |
| Multisig Signer 3 | [TBD] | [TBD] | [TBD] | [TBD] |
| Multisig Signer 4 | [TBD] | [TBD] | [TBD] | [TBD] |
| Multisig Signer 5 | [TBD] | [TBD] | [TBD] | [TBD] |

### External Contacts

| Service | Contact | Purpose |
|---------|---------|---------|
| MegaETH Team | [TBD] | Chain-level issues |
| Audit Firm | [TBD] | Security consultation |
| Legal Counsel | [TBD] | Regulatory concerns |

### Communication Channels

| Channel | URL | Purpose |
|---------|-----|---------|
| Team Private | [TBD] | Incident coordination |
| Public Discord | [TBD] | User updates |
| Twitter/X | [TBD] | Public announcements |
| Status Page | [TBD] | System status |

---

## Appendix: Quick Reference

### Contract Addresses (Testnet)

```
DataToken:          [TBD]
GhostCore:          [TBD]
TraceScan:          [TBD]
RewardsDistributor: [TBD]
DeadPool:           [TBD]
FeeRouter:          [TBD]
Timelock:           [TBD]
Emergency Multisig: [TBD]
```

### Key Commands

```bash
# Pause all (run in sequence)
cast send $GHOST_CORE "pause()" --private-key $ADMIN_KEY
cast send $TRACE_SCAN "pause()" --private-key $ADMIN_KEY
cast send $DEAD_POOL "pause()" --private-key $ADMIN_KEY

# Check pause status
cast call $GHOST_CORE "paused()"
cast call $TRACE_SCAN "paused()"
cast call $DEAD_POOL "paused()"

# Check TVL
cast call $GHOST_CORE "getTotalValueLocked()"

# Check active positions per level
for i in 1 2 3 4 5; do
  echo "Level $i:"
  cast call $GHOST_CORE "getLevelConfig(uint8)" $i
done
```

---

*This document must be reviewed and updated quarterly, or after any incident requiring emergency procedures.*
