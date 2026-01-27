# Circuit Breaker Reset Timelock Design

**Date:** 2026-01-21  
**Category:** Smart Contract Security  
**Status:** Design Complete, Implementation Ready

## Summary

Designed and specified a timelocked circuit breaker reset mechanism for ArcadeCore to address Critical Security Issue #3 from the architecture review. The current `resetCircuitBreaker()` function allows immediate reset by admin, which creates a vulnerability if admin keys are compromised.

## The Problem

An attacker who compromises the admin key can:
1. Trigger an exploit that trips the circuit breaker
2. Immediately reset the circuit breaker
3. Continue the exploit
4. Repeat indefinitely until funds are drained

## Solution: 12-Hour Timelock with Guardian Veto

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Timelock Duration | 12 hours | Balances detection window vs operational recovery |
| Guardian Veto | Yes | Asymmetric security - can only prevent, not cause, resets |
| Partial Reset | Available immediately | Operational flexibility while investigating |
| Re-trip Handling | Invalidates proposals | Changed conditions require new proposal |

### State Machine

```
NORMAL → TRIPPED → PROPOSED → READY → NORMAL
                     ↓
                  VETOED → TRIPPED
```

## Files Created

1. **ADR Document**
   - `/docs/architecture/adr-circuit-breaker-reset-timelock.md`
   - Complete architectural decision record with alternatives analysis

2. **Solidity Implementation**
   - `/packages/contracts/src/arcade/ArcadeCoreCircuitBreakerTimelock.sol`
   - Constants, types, errors, events, and reference implementation

3. **Operational Runbook**
   - `/docs/architecture/runbook-circuit-breaker-response.md`
   - Investigation procedures, response actions, reset procedures

4. **Test Suite**
   - `/packages/contracts/test/CircuitBreakerTimelock.t.sol`
   - Comprehensive tests covering all states and transitions

## Integration Notes

The implementation is designed as a standalone module that can be integrated into ArcadeCore. Key integration points:

1. Add storage fields to `ArcadeCoreStorageLayout`:
   ```solidity
   mapping(bytes32 => PendingCircuitBreakerReset) pendingResets;
   uint256 lastTripTimestamp;
   ```

2. Add `GUARDIAN_ROLE` constant and grant to guardian multisig

3. Update `_tripCircuitBreaker()` to set `lastTripTimestamp`

4. Replace existing `resetCircuitBreaker()` with new timelocked version

## Known Issues

The ArcadeCore contract currently has pre-existing compilation issues unrelated to this work (conflicting `MAX_BATCH_SIZE` definitions). These should be addressed separately before integrating the circuit breaker timelock.

## Testing

The test suite includes:
- Proposal lifecycle tests (propose, cancel, execute)
- Timelock enforcement (cannot execute before 12h)
- Guardian veto functionality
- Partial reset behavior
- Re-trip invalidation
- Attack scenario simulations
- Fuzz tests for time bounds

## Next Steps

1. Fix pre-existing ArcadeCore compilation issues
2. Integrate circuit breaker timelock into ArcadeCore
3. Set up guardian multisig infrastructure
4. Configure monitoring alerts for new events
5. Conduct dry-run exercises with team
