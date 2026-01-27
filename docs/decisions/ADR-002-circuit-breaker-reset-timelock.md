# ADR: Circuit Breaker Reset Timelock Mechanism

**ADR Number:** ADR-005  
**Status:** Proposed  
**Created:** 2026-01-21  
**Author:** Architecture Team  
**Context:** GHOSTNET Arcade ArcadeCore Contract Security

---

## 1. Context and Problem Statement

### The Problem

The `resetCircuitBreaker()` function in ArcadeCore allows an admin to immediately resume payouts after the circuit breaker has tripped. This creates a critical security vulnerability:

```solidity
// CURRENT: Vulnerable pattern
function resetCircuitBreaker() external onlyRole(DEFAULT_ADMIN_ROLE) {
    ArcadeCoreStorage storage $ = _getStorage();
    $.circuitBreakerTripped = false;  // Immediate effect!
    $.hourlyPayouts = 0;
    $.dailyPayouts = 0;
    $.lastHourTimestamp = block.timestamp;
    $.lastDayTimestamp = block.timestamp;
    emit CircuitBreakerReset(msg.sender);
}
```

### Attack Scenario

```
Timeline of Attack:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

T+0:    Attacker compromises admin private key
T+1:    Attacker exploits game contract bug, drains 4.9M DATA
T+2:    Circuit breaker TRIPS (hourly limit exceeded)
T+3:    Attacker calls resetCircuitBreaker() - IMMEDIATE RESET
T+4:    Attacker continues exploit, drains another 4.9M DATA
T+5:    Circuit breaker TRIPS again
T+6:    Attacker resets AGAIN
...
T+N:    Contract fully drained before team can respond

Total time: < 1 minute
Total loss: Entire contract balance
```

### Why This Matters

The circuit breaker exists specifically to provide a **defense-in-depth** against exploitation. If an attacker who compromises the admin key can immediately reset it, the circuit breaker provides zero additional protection beyond access control.

---

## 2. Decision Drivers

### Security Requirements

1. **Compromise Containment**: A compromised admin key should not allow immediate full drainage
2. **Detection Window**: Team must have time to detect and respond to suspicious activity
3. **Defense in Depth**: Circuit breaker must provide protection *beyond* access control
4. **Key Recovery**: If admin key is compromised, there must be time to revoke or migrate

### Operational Requirements

1. **False Positive Recovery**: Legitimate circuit breaker trips (high legitimate activity) must be recoverable
2. **Reasonable Downtime**: Players shouldn't be locked out for extended periods for false positives
3. **Graduated Response**: Not all resets are equal - some situations need faster recovery
4. **Transparency**: All reset attempts must be publicly visible and auditable

### System Constraints

1. **Gas Efficiency**: Solution must not significantly increase gas costs
2. **Existing Patterns**: Should reuse established patterns (like upgrade timelock)
3. **Backwards Compatibility**: Must work with existing circuit breaker implementation
4. **Upgrade Safety**: Must be compatible with UUPS proxy pattern

---

## 3. Considered Options

### Option A: Simple Timelock (Single-Phase)

```solidity
// Propose reset → Wait N hours → Execute reset
function proposeCircuitBreakerReset() external onlyRole(DEFAULT_ADMIN_ROLE);
function executeCircuitBreakerReset() external onlyRole(DEFAULT_ADMIN_ROLE);
```

**Timelock Duration:** 24 hours

| Pros | Cons |
|------|------|
| Simple to implement | One-size-fits-all may be too slow for false positives |
| Consistent with upgrade timelock pattern | No way to expedite legitimate emergencies |
| Provides 24h detection window | 24h downtime hurts user experience |
| Easy to audit | |

### Option B: Two-Tier Timelock (Standard + Emergency)

```solidity
// Standard: 24h timelock
function proposeCircuitBreakerReset() external onlyRole(DEFAULT_ADMIN_ROLE);
function executeCircuitBreakerReset() external onlyRole(DEFAULT_ADMIN_ROLE);

// Emergency: 6h timelock + requires GUARDIAN_ROLE signature
function proposeEmergencyReset() external onlyRole(DEFAULT_ADMIN_ROLE);
function confirmEmergencyReset() external onlyRole(GUARDIAN_ROLE);
function executeEmergencyReset() external;
```

| Pros | Cons |
|------|------|
| Faster recovery for confirmed false positives | More complex |
| Guardian role provides additional oversight | Requires trusted guardian setup |
| Flexible for different scenarios | Two code paths to audit |
| Still provides minimum 6h window | Guardian key becomes attack target |

### Option C: Multi-Sig Required Reset

```solidity
// Requires M-of-N signatures to reset
function proposeCircuitBreakerReset() external onlyRole(DEFAULT_ADMIN_ROLE);
function confirmReset() external; // Called by each signer
function executeCircuitBreakerReset() external; // After threshold reached
```

| Pros | Cons |
|------|------|
| Very secure - requires multiple compromises | Operational complexity |
| No timelock needed if keys are distributed | Coordination overhead for false positives |
| Common industry practice | Single point of failure if signers unavailable |
| | Doesn't address detection window |

### Option D: Timelock with Guardian Veto (Recommended)

```solidity
// Standard: 12h timelock
function proposeCircuitBreakerReset() external onlyRole(DEFAULT_ADMIN_ROLE);
function executeCircuitBreakerReset() external onlyRole(DEFAULT_ADMIN_ROLE);

// Guardian can veto during timelock period
function vetoCircuitBreakerReset(bytes32 resetId) external onlyRole(GUARDIAN_ROLE);

// Partial reset available immediately (counter reset only, breaker stays armed)
function resetPayoutCounters() external onlyRole(DEFAULT_ADMIN_ROLE);
```

| Pros | Cons |
|------|------|
| 12h provides good detection window | Requires guardian infrastructure |
| Guardian veto adds defense layer | |
| Partial reset allows counter management | |
| Consistent with upgrade timelock pattern | |
| Balanced security/usability tradeoff | |

---

## 4. Decision: Option D - Timelock with Guardian Veto

### Rationale

**Why 12 hours?**

1. **Detection Time**: Most security incidents are detected within 1-4 hours through:
   - On-chain monitoring alerts (automatic)
   - Community reports (manual)
   - Internal dashboards (continuous)

2. **Response Time**: Team needs time to:
   - Verify the alert (30 min - 2 hours)
   - Investigate root cause (1-4 hours)
   - Coordinate response (1-2 hours)
   - Execute mitigation (immediate once decided)

3. **Operational Impact**: 12 hours is:
   - Short enough to recover from false positives same-day
   - Long enough to detect and respond to attacks
   - Aligned with business hours for most time zones

**Why Guardian Veto?**

The guardian role provides **asymmetric security**:
- Guardian can only **prevent** resets (defensive action)
- Guardian cannot **cause** resets (no offensive capability)
- A compromised guardian key = minor inconvenience (delays recovery)
- A compromised admin key = attacker blocked by timelock + guardian veto

**Why Partial Reset?**

The payout counters (hourly/daily) naturally reset over time. A partial reset that only resets counters (without disabling the breaker) allows:
- Continued monitoring with breaker "armed"
- Resumption of limited activity while investigating
- No security risk (breaker still active)

---

## 5. Detailed Design

### 5.1 State Machine

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CIRCUIT BREAKER STATE MACHINE                          │
└─────────────────────────────────────────────────────────────────────────────┘

                                    ┌────────────┐
                                    │   NORMAL   │
                                    │  Operating │
                                    └─────┬──────┘
                                          │
                        ┌─────────────────┼─────────────────┐
                        │                 │                 │
                  Hourly limit      Daily limit       Single payout
                   exceeded          exceeded           too large
                        │                 │                 │
                        └─────────────────┼─────────────────┘
                                          │
                                          ▼
                                    ┌────────────┐
                                    │  TRIPPED   │
                                    │  (Frozen)  │◄─────────────┐
                                    └─────┬──────┘              │
                                          │                     │
                     ┌────────────────────┼────────────────┐    │
                     │                    │                │    │
              proposeReset()       resetCounters()         │    │
                     │            (partial, immediate)     │    │
                     ▼                    │                │    │
              ┌─────────────┐             │                │    │
              │  PROPOSED   │             │                │    │
              │ (12h Timer) │             │                │    │
              └─────┬───────┘             │                │    │
                    │                     │                │    │
         ┌──────────┼──────────┐          │                │    │
         │          │          │          │                │    │
    Timer elapsed   │    vetoReset()      │          Limit hit  │
         │          │     (Guardian)      │          while      │
         │          │          │          │          PROPOSED   │
         │          │          │          │                │    │
         ▼          │          ▼          │                │    │
  ┌────────────┐    │    ┌─────────┐      │                │    │
  │   READY    │    │    │ VETOED  │──────┴────────────────┴────┘
  │ (Execute)  │    │    │         │    (Back to TRIPPED, 
  └─────┬──────┘    │    └─────────┘     reset proposal cleared)
        │           │
        │     cancelReset()
        │      (Admin)
        │           │
        │           ▼
        │     ┌─────────┐
        │     │CANCELLED│
        │     └────┬────┘
        │          │
        │          │
        ▼          ▼
  ┌────────────────────┐
  │      NORMAL        │
  │    (Operating)     │
  └────────────────────┘
```

### 5.2 Reset Types

| Reset Type | Timelock | Effect | Use Case |
|------------|----------|--------|----------|
| **Full Reset** | 12 hours | Clears `circuitBreakerTripped` + all counters | Confirmed false positive or post-incident recovery |
| **Partial Reset** | None | Resets counters only, breaker stays active | Allow limited activity while investigating |

### 5.3 Roles

| Role | Permissions | Trust Assumptions |
|------|-------------|-------------------|
| `DEFAULT_ADMIN_ROLE` | Propose reset, execute reset, cancel reset, partial reset | Highest trust, should be timelock controller |
| `GUARDIAN_ROLE` | Veto pending resets | Can only prevent, not cause, resets. Can be multisig or trusted third party |
| `PAUSER_ROLE` | Pause/unpause contract | Operational role, separate from reset authority |

### 5.4 Events for Monitoring

```solidity
// Proposal lifecycle
event CircuitBreakerResetProposed(bytes32 indexed resetId, address indexed proposer, uint256 executeAfter);
event CircuitBreakerResetVetoed(bytes32 indexed resetId, address indexed guardian, string reason);
event CircuitBreakerResetCancelled(bytes32 indexed resetId, address indexed canceller);
event CircuitBreakerResetExecuted(bytes32 indexed resetId, address indexed executor);

// Partial reset
event PayoutCountersReset(address indexed admin);

// Trip events (existing, enhanced)
event CircuitBreakerTripped(string reason, uint256 value, uint256 timestamp);
```

---

## 6. Implementation

See accompanying Solidity implementation file: `ArcadeCoreCircuitBreakerTimelock.sol`

Key implementation notes:

1. **Storage**: Uses ERC-7201 namespaced storage to avoid conflicts
2. **Reset ID**: `keccak256(abi.encode(proposer, proposalTime, resetType))`
3. **Cleanup**: Old proposals auto-expire after 48 hours (no manual cleanup needed)
4. **Re-trip Handling**: If breaker trips during pending proposal, proposal is invalidated

---

## 7. Operational Procedures

### 7.1 Responding to Circuit Breaker Trip

See accompanying runbook: `runbook-circuit-breaker-response.md`

### 7.2 Monitoring Requirements

| Alert | Trigger | Priority | Response Time |
|-------|---------|----------|---------------|
| Circuit breaker tripped | `CircuitBreakerTripped` event | P1 - Critical | Immediate |
| Reset proposed | `CircuitBreakerResetProposed` event | P2 - High | < 1 hour |
| Reset approaching execution | 2 hours before `executeAfter` | P2 - High | Before execution |
| Unexpected proposer | Proposal from non-known admin | P1 - Critical | Immediate |

---

## 8. Migration Plan

### Phase 1: Deploy (Day 1)
1. Deploy new implementation with timelock logic
2. Test on staging with simulated trips/resets
3. Propose upgrade via existing upgrade timelock

### Phase 2: Upgrade (Day 3)
1. Execute upgrade after 2-day upgrade timelock
2. Verify new functions accessible
3. Verify existing circuit breaker state preserved

### Phase 3: Guardian Setup (Day 3-5)
1. Deploy guardian multisig (recommend 2-of-3)
2. Grant `GUARDIAN_ROLE` to guardian multisig
3. Test veto functionality on testnet

### Phase 4: Operational Readiness (Day 5-7)
1. Set up monitoring for all new events
2. Train team on new procedures
3. Document emergency contacts
4. Conduct dry-run exercise

---

## 9. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Legitimate trip delays recovery | Medium | Medium | Partial reset available immediately; 12h is reasonable |
| Guardian key compromised | Low | Low | Guardian can only veto (defensive); doesn't enable attacks |
| Guardian unavailable for veto | Low | Medium | Guardian absence = normal operation; only matters during attacks |
| Admin key compromised | Low | High | 12h timelock + guardian veto provides double protection |
| Implementation bug | Low | Critical | Extensive testing; formal verification recommended |

---

## 10. Alternatives Not Chosen

### "Cooling Off" Period Instead of Timelock

Some systems use a "cooling off" period where the breaker auto-resets after N hours. This was rejected because:
- Doesn't provide the security we need during active exploitation
- Attacker can wait out the cooling period
- No opportunity for human judgment

### Requiring On-Chain Vote for Reset

Democratic governance for resets was considered but rejected:
- Too slow for operational needs
- Token-weighted voting doesn't match security requirements
- Introduces governance attack surface

### Hardware Security Module (HSM) for Reset

Requiring HSM-stored key for reset was considered:
- Good security but poor availability
- Doesn't address detection window (still instant)
- Operational complexity

---

## 11. References

- [OpenZeppelin TimelockController](https://docs.openzeppelin.com/contracts/4.x/api/governance#TimelockController)
- [MakerDAO Emergency Shutdown Module](https://docs.makerdao.com/smart-contract-modules/shutdown)
- [Compound Governor Bravo](https://docs.compound.finance/v2/governance/)
- [GHOSTNET Arcade Architecture Plan](./arcade-contracts-plan.md)
- [EIP-7201: Namespaced Storage Layout](https://eips.ethereum.org/EIPS/eip-7201)

---

## 12. Decision Record

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-21 | Chose 12h timelock | Balance of security (detection window) and usability (same-day recovery) |
| 2026-01-21 | Added guardian veto | Asymmetric security - defensive only capability |
| 2026-01-21 | Added partial reset | Operational flexibility while maintaining security |
| 2026-01-21 | Rejected multi-sig requirement | Adds operational overhead; timelock + veto provides equivalent security |
