---
type: blueprint-quality
updated: 2026-01-27
tags:
  - type/blueprint
  - blueprint/quality
---

# Quality Requirements

## Overview

GHOSTNET is a real-time survival game on MegaETH where milliseconds matter. These Non-Functional Requirements (NFRs) ensure the system delivers the speed, security, and reliability that a high-stakes game demands.

Quality priorities (in order):
1. **Security** - User funds must be safe
2. **Performance** - Real-time experience (sub-second feedback)
3. **Reliability** - System must be available and recoverable
4. **Scalability** - Handle growth without degradation

---

## Performance (PERF)

| ID | Requirement | Target | Measurement |
|----|-------------|--------|-------------|
| NFR-PERF-001 | UI updates from on-chain events | < 100ms | E2E timing tests |
| NFR-PERF-002 | Transaction confirmation feedback | < 500ms | Client-side metrics |
| NFR-PERF-003 | Feed renders 100+ events | < 16ms frame time | Performance profiling |
| NFR-PERF-004 | Indexer processes blocks | < 1s from finality | Indexer metrics |
| NFR-PERF-005 | Typing game input latency | < 16ms | Input timing tests |
| NFR-PERF-006 | Page initial load | < 3s on 3G | Lighthouse |
| NFR-PERF-007 | Gas ceilings | Per-function limits | Gas reporter |

### NFR-PERF-001: UI Event Latency

**Requirement:** UI must update within 100ms of on-chain event finality.

**Rationale:** MegaETH provides 10ms mini-blocks. Users expect near-instant feedback. Delays >100ms break the "real-time" promise and create information asymmetry.

**Target:** < 100ms from EVM block finality to visible UI update

**Conditions:**
- Normal network conditions
- WebSocket connection active
- User has stable internet (>1Mbps)

**Measurement:**
- E2E tests with timestamp comparison (block timestamp vs UI render)
- Client-side performance monitoring (Real User Monitoring)

**Consequences:**
- Minor breach (100-200ms): Investigate indexer/WebSocket latency
- Major breach (>200ms sustained): Immediate investigation, may indicate infrastructure issue

### NFR-PERF-002: Transaction Confirmation Feedback

**Requirement:** Users must see transaction status feedback within 500ms of wallet confirmation.

**Rationale:** After signing in wallet, users need immediate acknowledgment that their action is being processed. MegaETH's `realtime_sendRawTransaction` returns receipts directly.

**Target:** < 500ms from wallet signature to UI confirmation state

**Implementation:**
- Use MegaETH Realtime API for instant receipt
- Show "pending" state immediately after wallet confirms
- Update to "confirmed" when receipt received

**Measurement:** Client-side timing from wallet callback to state transition

### NFR-PERF-003: Feed Rendering Performance

**Requirement:** Live feed must render 100+ events without frame drops.

**Rationale:** The feed is the "dopamine engine" - constant activity streams showing wins, losses, and network activity. Performance degradation destroys the experience.

**Target:** Maintain 60fps (< 16ms frame time) with 100+ items

**Conditions:**
- Feed virtualized (only visible items in DOM)
- Animations use GPU-accelerated properties
- New items batch-inserted (not one-by-one)

**Measurement:**
- Performance profiling in browser dev tools
- Automated performance tests with synthetic load

### NFR-PERF-004: Indexer Block Processing

**Requirement:** Indexer must process blocks within 1 second of finality.

**Rationale:** The indexer is the source of truth for the web app. Delays cascade to all users. Given MegaETH's 1s EVM blocks, we need to keep up.

**Target:** < 1s from EVM block finality to events indexed and available

**Measurement:**
- Indexer metrics (block_processed_at - block_timestamp)
- Alerting on processing lag > 2s

### NFR-PERF-005: Typing Game Input Latency

**Requirement:** Typing game must respond to keystrokes within 16ms.

**Rationale:** Trace Evasion is a competitive typing game. Any perceptible lag frustrates players and makes the game feel unfair.

**Target:** < 16ms from keydown event to visual feedback

**Conditions:**
- No blocking operations on main thread
- Input handling in requestAnimationFrame where needed

**Measurement:** Browser performance profiling, input latency tests

### NFR-PERF-006: Page Load Time

**Requirement:** Initial page load must complete within 3 seconds on slow connections.

**Rationale:** First impressions matter. Users will abandon if the page doesn't load quickly, especially mobile users.

**Target:** < 3s on 3G connection (simulated 400kbps)

**Measurement:** Lighthouse performance score, Web Vitals (LCP, FID, CLS)

### NFR-PERF-007: Gas Ceilings

**Requirement:** Core contract functions must stay within gas limits for predictable costs.

| Function | Target | Notes |
|----------|--------|-------|
| `jackIn()` | < 150,000 gas | Single position creation |
| `extract()` | < 200,000 gas | Position close + yield calc |
| `triggerScan()` | < 500,000 gas | Per batch of 100 positions |
| `emergencyWithdraw()` | < 100,000 gas | Simple transfer |

**Rationale:** Predictable costs for users and keeper automation. MegaETH has different gas pricing, but ceilings ensure efficiency and prevent DoS via gas exhaustion.

**Measurement:** Gas reporter in Foundry tests (`forge test --gas-report`)

**Status:** 🟣 Ready

---

## Security (SEC)

| ID | Requirement | Target | Verification |
|----|-------------|--------|--------------|
| NFR-SEC-001 | Smart contract audit | Pre-mainnet | External audit report |
| NFR-SEC-002 | No admin fund drainage | Verified | Audit + invariant tests |
| NFR-SEC-003 | Randomness unpredictable | Verified | prevrandao + lock period |
| NFR-SEC-004 | Circuit breaker available | Operational | Integration tests |
| NFR-SEC-005 | Rate limiting on sensitive ops | Implemented | Unit tests |
| NFR-SEC-006 | EIP-7702 safe | Verified | No EOA detection patterns |
| NFR-SEC-007 | Key management ceremony | Documented | Operational procedures |
| NFR-SEC-008 | Anti-cheat (off-chain) | Implemented | Integration tests |

### NFR-SEC-001: Smart Contract Audit

**Requirement:** All smart contracts must be audited by a reputable security firm before mainnet deployment.

**Rationale:** Smart contracts control user funds. Security vulnerabilities could result in total loss. See `docs/architecture/security-audit-scope.md` for full scope.

**Target:** Clean audit with no Critical/High findings unaddressed

**Verification:**
- External audit engagement (2-3 weeks)
- All Critical/High findings fixed and verified
- Audit report published publicly

**Consequences:** No mainnet deployment until audit complete

### NFR-SEC-002: Admin Key Safety

**Requirement:** No administrative function may allow draining user funds.

**Rationale:** "Not your keys, not your coins" - users must trust that admins cannot steal their stakes.

**Implementation:**
- Ownable2Step (prevents accidental ownership transfer)
- Timelock on all admin functions (24h minimum)
- Emergency pause only freezes, doesn't withdraw
- emergencyWithdraw returns funds to users, not treasury

**Verification:**
- Audit scope includes all admin functions
- Invariant tests prove solvency (total_staked == sum_of_positions)
- Public monitoring of admin actions

### NFR-SEC-003: Randomness Security

**Requirement:** Trace scan randomness must be unpredictable and verifiable.

**Rationale:** Players bet their stakes on random outcomes. Predictable or manipulable randomness would allow unfair advantages.

**Implementation:**
- Uses `block.prevrandao` as entropy source
- 60-second lock period after position change (prevents front-running)
- Multi-component seed: prevrandao + timestamp + block.number + nonce
- Anyone can verify `isDead()` calculation on-chain

**Conditions:**
- MegaETH prevrandao changes every ~60 seconds (epoch-based)
- Lock period must exceed prevrandao change frequency

**Verification:**
- Documented in `docs/learnings/001-prevrandao-megaeth.md`
- Verification plan in `docs/architecture/prevrandao-verification-plan.md`

### NFR-SEC-004: Circuit Breaker

**Requirement:** Emergency pause mechanism must exist and be operational.

**Rationale:** If an exploit is discovered, the system must be able to halt to prevent further damage.

**Implementation:**
- `pause()` / `unpause()` functions on core contracts
- Paused state blocks all state-changing operations
- Emergency multisig can pause without timelock
- Unpause requires timelock (prevents hasty resumption)
- `emergencyWithdraw()` available when paused

**Verification:**
- Integration tests for pause/unpause flow
- Runbook in `docs/architecture/emergency-procedures.md`

### NFR-SEC-005: Rate Limiting

**Requirement:** Sensitive operations must have rate limiting to prevent abuse.

**Rationale:** Prevents griefing attacks, spam, and resource exhaustion.

**Implementation:**
- On-chain: Cooldowns on position changes (lock period)
- On-chain: Batch size limits (MAX_BATCH_SIZE = 100)
- Off-chain: API rate limiting (if applicable)
- Flash loan protection via per-block wager limits

**Verification:** Unit tests for cooldown enforcement

### NFR-SEC-006: EIP-7702 Safety

**Requirement:** No code paths may rely on EOA detection patterns.

**Rationale:** EIP-7702 (Pectra upgrade, May 2025) allows EOAs to delegate to smart contracts, breaking traditional detection. See security audit scope section 4.1.1.

**Implementation:**
- No `tx.origin == msg.sender` checks
- No `extcodesize == 0` checks
- No `msg.sender.code.length == 0` checks
- Rate limiting uses time delays, not caller-type assumptions

**Verification:** Audit checklist, static analysis

### NFR-SEC-007: Key Management Ceremony

**Requirement:** Admin and upgrade keys must use secure multi-signature setups.

| Key Type | Requirement | Timelock |
|----------|-------------|----------|
| Admin (pause) | 3-of-5 multisig | None (emergency) |
| Admin (unpause) | 3-of-5 multisig | 24 hours |
| Upgrade | 3-of-5 multisig | 48 hours |
| Treasury | 3-of-5 multisig | 24 hours |

**Rationale:** No single point of compromise. Even if one key is compromised, attacker cannot execute privileged operations alone.

**Implementation:**
- Use Safe (formerly Gnosis Safe) for all multisigs
- Hardware wallet signers required
- Geographic distribution of signers
- Documented key recovery procedures

**Verification:** Operational procedures documented, tested in staging

**Status:** 🟣 Ready

### NFR-SEC-008: Anti-Cheat (Off-chain)

**Requirement:** Mini-game inputs must be validated to prevent cheating.

**Rationale:** Mini-games (Trace Evasion, Hack Runs) provide real economic benefits. Cheating undermines fairness and game integrity.

**Implementation:**
- Server-side validation of game scores
- Cryptographic signature verification for submissions
- Rate limiting on game attempts (max 1 per minute)
- Statistical anomaly detection (impossible WPM, perfect accuracy)
- Replay protection (nonce + timestamp)

**Detection Thresholds:**

| Metric | Suspicious | Auto-reject |
|--------|------------|-------------|
| Typing WPM | > 150 | > 200 |
| Accuracy | 100% sustained | N/A |
| Response time | < 50ms average | < 20ms average |

**Verification:** Integration tests with edge cases, manual review of flagged submissions

**Status:** 🧠 Draft

---

## Reliability (REL)

| ID | Requirement | Target | Measurement |
|----|-------------|--------|-------------|
| NFR-REL-001 | Graceful RPC degradation | Implemented | Failover tests |
| NFR-REL-002 | Indexer crash recovery | Zero data loss | Recovery tests |
| NFR-REL-003 | Read-only mode support | Implemented | Offline tests |
| NFR-REL-004 | Web app uptime | 99.9% | Monitoring |
| NFR-REL-005 | Data consistency | Eventual (< 5s) | Consistency tests |
| NFR-REL-006 | Reorg handling | Graceful | Integration tests |
| NFR-REL-007 | Data retention | 1 year events | Storage policy |

### NFR-REL-001: Graceful RPC Degradation

**Requirement:** System must degrade gracefully when RPC provider fails.

**Rationale:** RPC outages happen. The system should inform users and maintain read-only functionality where possible.

**Implementation:**
- Multiple RPC endpoints with automatic failover
- UI shows clear "connecting..." state
- Cached data remains visible during outage
- Queued transactions retry with exponential backoff

**Verification:**
- Failover integration tests
- Chaos testing (kill RPC connection)

### NFR-REL-002: Indexer Crash Recovery

**Requirement:** Indexer must recover from crashes without data loss.

**Rationale:** The indexer is derived state - it must be rebuildable from chain history. Crashes should not create permanent inconsistencies.

**Implementation:**
- Persistent cursor tracking (last processed block)
- Automatic restart with resume from cursor
- Reorg handling (re-process on chain reorganization)
- Health checks with automatic restart

**Target:** Zero data loss, < 30s to resume processing

**Verification:**
- Kill indexer mid-block, verify clean restart
- Simulate reorg, verify correct state

### NFR-REL-003: Read-Only Mode

**Requirement:** Frontend must function in read-only mode without wallet connected.

**Rationale:** New users should be able to explore the game, watch the feed, and understand mechanics before committing to connect their wallet.

**Implementation:**
- All read operations work without wallet
- Position panel shows "Connect wallet to play"
- Feed, network vitals, leaderboard visible
- Mini-game previews available

**Verification:** E2E tests without wallet connection

### NFR-REL-004: Web App Uptime

**Requirement:** Web application must maintain 99.9% availability.

**Rationale:** Users expect the game to be available. Downtime loses players and trust.

**Target:** 99.9% (< 8.76 hours downtime/year)

**Exclusions:**
- Scheduled maintenance windows (announced 24h in advance)
- Blockchain network outages (MegaETH itself down)

**Measurement:**
- Uptime monitoring (e.g., Checkly, Uptime Robot)
- Incident tracking and postmortems

### NFR-REL-005: Data Consistency

**Requirement:** UI data must be eventually consistent with chain state within 5 seconds.

**Rationale:** Given the event-driven architecture (chain -> indexer -> WebSocket -> UI), some lag is unavoidable. 5s is acceptable for non-critical reads.

**Target:** Eventual consistency within 5 seconds

**Exclusions:**
- Transaction states (these show pending immediately)
- User's own position (polled directly when needed)

**Measurement:** E2E tests comparing UI state to contract state

### NFR-REL-006: Reorg Handling

**Requirement:** System must handle chain reorganizations gracefully.

**Rationale:** Although rare on MegaETH, reorgs can occur. Incorrect handling could show phantom transactions or lose real ones.

**Implementation:**
- Indexer tracks finality (waits for EVM block confirmation)
- UI shows "confirming" state for recent transactions (< 2 blocks)
- Reorg detection triggers re-indexing of affected blocks
- No permanent state corruption from reorgs
- WebSocket pushes "reorg" event to trigger UI refresh

**Target:** Handle reorgs up to 10 blocks deep without data loss

**Verification:** Integration tests simulating reorg scenarios

**Status:** 🧠 Draft

### NFR-REL-007: Data Retention

**Requirement:** Event history and statistics must be retained appropriately.

| Data Type | Retention | Storage |
|-----------|-----------|---------|
| Raw events | 1 year | TimescaleDB |
| Aggregated stats | Indefinite | PostgreSQL |
| Position history | 1 year | TimescaleDB |
| Leaderboard snapshots | 90 days | PostgreSQL |

**Rationale:** Historical data enables analytics, dispute resolution, and user statistics. But unbounded retention is costly.

**Target:** Storage growth < 1GB/month at 10,000 DAU

**Implementation:**
- TimescaleDB automatic compression (after 7 days)
- Continuous aggregation for statistics
- Pruning jobs for expired data
- Archival to cold storage (optional)

**Verification:** Monitor storage growth in production

**Status:** 🧠 Draft

---

## Scalability (SCALE)

| ID | Requirement | Target | Notes |
|----|-------------|--------|-------|
| NFR-SCALE-001 | Concurrent positions | 10,000 | Contract storage design |
| NFR-SCALE-002 | Trace scans per hour | 100 | Gas-bounded batching |
| NFR-SCALE-003 | Feed events per minute | 1,000 | WebSocket throughput |
| NFR-SCALE-004 | Database growth | < 10GB/month | Indexer storage |

### NFR-SCALE-001: Concurrent Positions

**Requirement:** System must support 10,000 concurrent active positions across all levels.

**Rationale:** Growth target for initial success. Must not hit gas limits or performance degradation.

**Implementation:**
- Per-level position tracking (not global enumeration)
- Lazy reward calculation (accRewardsPerShare pattern)
- Batched death processing (MAX_BATCH_SIZE = 100)
- Level capacity limits with culling mechanism

**Verification:**
- Fuzz tests with scaled positions
- Gas profiling at scale

### NFR-SCALE-002: Trace Scan Throughput

**Requirement:** System must handle up to 100 trace scans per hour.

**Rationale:** BLACK ICE scans every 30 minutes, DARKNET every 2 hours, etc. Peak load occurs when multiple levels scan simultaneously.

**Implementation:**
- Trustless death verification (anyone can submit proofs)
- Batched processing with gas bounds
- Keeper system for automation

**Target:** Process 100 scans/hour without gas failures

**Verification:** Integration tests with concurrent scans

### NFR-SCALE-003: Feed Event Throughput

**Requirement:** Live feed must handle 1,000 events per minute.

**Rationale:** High activity periods (launch, after major events) generate bursts of feed items.

**Implementation:**
- WebSocket batching (events grouped per message)
- Client-side throttling (max update frequency)
- Feed virtualization (only render visible items)

**Verification:** Load testing with synthetic events

### NFR-SCALE-004: Database Growth

**Requirement:** Indexer database growth must be sustainable (< 10GB/month).

**Rationale:** Unbounded growth creates operational burden and costs.

**Implementation:**
- TimescaleDB with time-based partitioning
- Compression for historical data
- Retention policies for non-essential data
- Aggregation tables for long-term stats

**Verification:** Monitor database size in production

---

## User Experience (UX)

| ID | Requirement | Target | Status |
|----|-------------|--------|--------|
| NFR-UX-001 | Mobile responsive | Works on phones | 🚧 In Progress |
| NFR-UX-002 | WalletConnect support | Multiple wallets | 🟣 Ready |
| NFR-UX-003 | Settings toggleable | Audio/visual | ✅ Implemented |
| NFR-UX-004 | Colorblind accessibility | Status indicators | 🟣 Ready |
| NFR-UX-005 | Keyboard navigation | Full support | 🚧 In Progress |

### NFR-UX-001: Mobile Responsive

**Requirement:** Game must be playable on mobile phone browsers.

**Rationale:** Significant portion of crypto users are mobile-first.

**Implementation:**
- Responsive CSS grid (single column on mobile)
- Touch-friendly targets (minimum 44px)
- Mobile navigation bar
- Collapsible panels

**Verification:** Test on iPhone SE (375px), iPhone 14 Pro (393px)

### NFR-UX-002: Wallet Compatibility

**Requirement:** Support multiple wallet connection methods.

**Rationale:** Users have different wallet preferences. Don't force MetaMask.

**Implementation:**
- WalletConnect v2 for universal support
- Injected wallets (MetaMask, Rabby)
- Coinbase Wallet SDK
- Safe multisig support

**Verification:** Test connection flow with each wallet type

### NFR-UX-003: Toggleable Effects

**Requirement:** Sound effects and visual effects must be toggleable.

**Rationale:** Some users find CRT effects or sounds annoying/inaccessible. Respect preferences.

**Implementation:**
- Settings persist to localStorage
- Sound: Global mute, volume slider
- Visual: Scanlines toggle, flicker toggle
- Keyboard shortcut for quick mute (M)

**Status:** ✅ Implemented in settings modal

### NFR-UX-004: Colorblind Accessibility

**Requirement:** Status indicators must not rely solely on color.

**Rationale:** ~8% of men have some form of color blindness.

**Implementation:**
- Use shapes/icons in addition to color (✓, ✗, ●, ○)
- Level badges include text labels
- High contrast mode option
- WCAG AA contrast ratios

**Verification:** Colorblind simulation testing

### NFR-UX-005: Keyboard Navigation

**Requirement:** All interactive elements must be keyboard accessible.

**Rationale:** Power users prefer keyboard shortcuts. Also accessibility requirement.

**Implementation:**
- Tab navigation through all interactive elements
- Keyboard shortcuts for common actions (J, E, T, H)
- Focus indicators visible
- Modal trap focus correctly

**Status:** 🚧 Quick actions implemented, full audit in progress

---

## Compliance (COMP)

| ID | Requirement | Standard | Status |
|----|-------------|----------|--------|
| NFR-COMP-001 | Accessibility | WCAG 2.1 AA | 🟣 Ready |
| NFR-COMP-002 | Risk disclosure | Visible | ✅ Implemented |

### NFR-COMP-001: Accessibility

**Requirement:** Meet WCAG 2.1 Level AA for core functionality.

**Rationale:** Accessibility is both ethical and practical (wider user base).

**Implementation:**
- Semantic HTML
- ARIA labels where needed
- Keyboard navigation
- Screen reader announcements for important events
- Sufficient color contrast

**Verification:** Automated accessibility testing (axe-core)

### NFR-COMP-002: Risk Disclosure

**Requirement:** Clear risk disclosure must be visible to all users.

**Rationale:** This is a high-risk game. Users must understand they can lose funds.

**Implementation:**
- Risk warning in Jack In modal
- Level-specific death rate prominently displayed
- "Play at your own risk" in footer
- Full disclosure document linked

**Status:** ✅ Implemented in Jack In modal and help section

---

## Observability (OBS)

| ID | Requirement | Target | Status |
|----|-------------|--------|--------|
| NFR-OBS-001 | Metrics collection | Real-time | 🧠 Draft |
| NFR-OBS-002 | Alerting | < 5min response | 🧠 Draft |

### NFR-OBS-001: Metrics Collection

**Requirement:** System must collect and expose operational metrics.

**Metrics Categories:**

| Category | Metrics | Source |
|----------|---------|--------|
| Contract | TVL, position count, deaths/hour | Indexer |
| API | Latency (p50, p95, p99), error rate | Backend |
| Indexer | Block lag, events/second | Indexer |
| WebSocket | Connected clients, messages/second | Backend |
| Frontend | Web Vitals (LCP, FID, CLS) | Client RUM |

**Implementation:**
- Contract events indexed and queryable via API
- Prometheus metrics endpoint for backend services
- Grafana dashboards for visualization
- Real-time TVL and position counts displayed in UI

**Verification:** Metrics endpoint returns expected data

**Status:** 🧠 Draft

### NFR-OBS-002: Alerting

**Requirement:** Critical events must trigger alerts within 5 minutes.

**Alert Categories:**

| Severity | Events | Response Time |
|----------|--------|---------------|
| Critical | System pause, large withdrawal (>10% TVL), keeper failure | < 5 min |
| Warning | Indexer lag >30s, API error rate >1%, unusual death rate | < 15 min |
| Info | New deployment, config change | Daily digest |

**Implementation:**
- PagerDuty integration for critical alerts
- Discord webhook for warning/info
- Runbook links in alert messages
- Escalation policy for unacknowledged alerts

**Alert Examples:**
- `CRITICAL: System paused by 0x1234... at block 12345678`
- `CRITICAL: Keeper failed to trigger DARKNET scan (30 min overdue)`
- `WARNING: Single withdrawal of 50,000 $DATA (8% of TVL)`
- `WARNING: Indexer block lag is 45 seconds`

**Verification:** Test alerts in staging environment

**Status:** 🧠 Draft

---

## Summary

| Category | Count | Critical |
|----------|-------|----------|
| Performance | 7 | 3 (PERF-001, 002, 005) |
| Security | 8 | 5 (SEC-001, 002, 003, 004, 007) |
| Reliability | 7 | 2 (REL-001, 002) |
| Scalability | 4 | 1 (SCALE-001) |
| User Experience | 5 | 0 |
| Compliance | 2 | 0 |
| Observability | 2 | 1 (OBS-002) |
| **Total** | **35** | **12** |

---

## NFR Status Legend

| Status | Meaning |
|--------|---------|
| ✅ Implemented | Requirement met and verified |
| 🚧 In Progress | Actively being worked on |
| 🟣 Ready | Defined, ready for implementation |
| 🔴 Blocked | Blocked by dependency |

---

## Related Documents

- [[architecture]] - System architecture constraints
- [[capabilities/core]] - Core staking capabilities
- [[manifesto]] - Project goals and non-goals
- `docs/architecture/security-audit-scope.md` - Full security scope
- `docs/architecture/emergency-procedures.md` - Incident response
- `docs/integrations/megaeth.md` - Platform constraints
