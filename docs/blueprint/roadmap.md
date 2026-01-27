---
type: blueprint-roadmap
updated: 2026-01-27
tags:
  - type/blueprint
  - blueprint/roadmap
---

# Roadmap

## Current Focus

*What we're actively working on right now*

| Priority | Capability | Status | Target |
|----------|------------|--------|--------|
| 1 | MVP Core Loop | 🚧 In Progress | Week 4 |
| 2 | Indexer Implementation | 🚧 In Progress | Week 4 |
| 3 | Phase 3A Games (Arcade) | 🚧 In Progress | Week 6 |

### Active Work Streams

```
MVP END-TO-END LOOP
═══════════════════════════════════════════════════════════════════════════
Web App ─────► Core Contracts ─────► Indexer ─────► Web App (real-time)
   │               │                    │               │
   │ Jack In       │ GhostCore.sol      │ TimescaleDB   │ Live Feed
   │ Extract       │ TraceScan.sol      │ WebSocket     │ Position Update
   │ View Feed     │ DataToken.sol      │ Event Decode  │ Network Vitals
   │               │                    │               │
   ▼               ▼                    ▼               ▼
🚧 70%           ✅ 100%              🚧 50%          🚧 80%
```

**MVP Definition:** `docs/architecture/mvp-scope.md`

---

## Horizons

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GHOSTNET ROADMAP                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  H1: FOUNDATION          H2: ENGAGEMENT         H3: GROWTH         H4: SCALE│
│  Weeks 1-4               Weeks 5-8              Weeks 9-16         Post-     │
│                                                                    Launch    │
│  ════════════════════════════════════════════════════════════════════════  │
│                                                                              │
│  ┌─────────────┐         ┌─────────────┐       ┌─────────────┐             │
│  │ Core Loop   │         │ Mini-Games  │       │ Advanced    │    ┌───────┐│
│  │ ▪ Staking   │────────►│ ▪ Hash Crash│──────►│ ▪ Ice Break │───►│Multi- ││
│  │ ▪ Scans     │         │ ▪ Code Duel │       │ ▪ Binary Bet│    │Pool   ││
│  │ ▪ Extract   │         │ ▪ Daily Ops │       │ ▪ Bounty    │    │       ││
│  │ ▪ Feed      │         │             │       │             │    │Govern-││
│  └─────────────┘         └─────────────┘       └─────────────┘    │ance   ││
│                                                                    └───────┘│
│  ┌─────────────┐         ┌─────────────┐       ┌─────────────┐             │
│  │ Contracts   │         │ Social      │       │ Team Games  │             │
│  │ ▪ GhostCore │         │ ▪ Crews     │       │ ▪ Proxy War │             │
│  │ ▪ TraceScan │         │ ▪ Leaderbd  │       │ ▪ Zero Day  │             │
│  │ ▪ DataToken │         │ ▪ Dead Pool │       │ ▪ Shadow    │             │
│  └─────────────┘         └─────────────┘       └─────────────┘             │
│                                                                              │
│  ┌─────────────┐         ┌─────────────┐                                    │
│  │ Indexer     │         │ Consumables │                                    │
│  │ ▪ Events    │         │ ▪ Stimpacks │                                    │
│  │ ▪ WebSocket │         │ ▪ EMPs      │                                    │
│  │ ▪ API       │         │ ▪ Shields   │                                    │
│  └─────────────┘         └─────────────┘                                    │
│                                                                              │
│  ──────────────────────────────────────────────────────────────────────────│
│  MILESTONE:              MILESTONE:            MILESTONE:        MILESTONE: │
│  MVP Testnet             Phase 3A Launch       Mainnet Launch    v2.0      │
│  ▼                       ▼                     ▼                 ▼         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

| Horizon | Timeframe | Focus | Key Deliverable |
|---------|-----------|-------|-----------------|
| H1: Foundation | Weeks 1-4 | Core game loop, contracts, indexer | MVP on testnet |
| H2: Engagement | Weeks 5-8 | Mini-games (Phase 3A), social features | Phase 3A launch |
| H3: Growth | Weeks 9-16 | Advanced games (Phase 3B/3C), crews, PvP | Mainnet launch |
| H4: Scale | Post-launch | Multi-pool, governance, ecosystem | Platform maturity |

---

## H1: Foundation (Weeks 1-4)

*Core game loop that proves the concept works end-to-end*

### Contracts ✅ Complete

| Deliverable | Status | Notes |
|-------------|--------|-------|
| DataToken.sol | ✅ | ERC20 with 10% transfer tax |
| GhostCore.sol | ✅ | Staking, positions, cascade |
| TraceScan.sol | ✅ | Death rolls, batch processing |
| RewardsDistributor.sol | ✅ | Emission distribution |
| FeeRouter.sol | ✅ | Fee handling, burns |

**Test Coverage:** 1275+ tests passing

### Web App 🚧 In Progress

| Deliverable | Status | Notes |
|-------------|--------|-------|
| Command Center UI | ✅ | Feed, position, vitals panels |
| Wallet Connection | ✅ | WalletConnect, injected |
| Jack In Modal | ✅ | Level selection, amount |
| Extract Modal | ✅ | Withdrawal flow |
| Settings | ✅ | Audio, visual toggles |
| Trace Evasion | ✅ | Typing mini-game |
| Contract Integration | 🚧 | viem/wagmi hooks |
| Real-time Feed | 🚧 | WebSocket to indexer |

### Indexer 🚧 In Progress

| Deliverable | Status | Notes |
|-------------|--------|-------|
| Block ingestion | 🚧 | MegaETH WS/HTTP |
| Event decoding | 🚧 | Core contract events |
| TimescaleDB storage | 🚧 | Positions, events, stats |
| WebSocket API | 🟣 | Feed streaming |
| REST API | 🟣 | Query endpoints |

**Architecture:** `docs/architecture/backend/indexer-architecture.md`

---

## H2: Engagement (Weeks 5-8)

*Social features and mini-games that drive retention*

### Phase 3A Games

| Game | Category | Status | Notes |
|------|----------|--------|-------|
| Hash Crash | Casino | 🚧 Frontend Done | Crash gambling, 3% burn |
| Code Duel | Competitive | 🚧 Contract Done | 1v1 typing races |
| Daily Ops | Progression | 🚧 Frontend Done | Streak rewards |

**Spec:** `docs/archive/product/phase-3-minigames/OVERVIEW.md`

### Social Features

| Feature | Status | Notes |
|---------|--------|-------|
| Crew System | ✅ UI Done | Mock data, needs contracts |
| Leaderboard | ✅ UI Done | Multiple categories |
| Dead Pool | ✅ UI Done | Prediction market |

### Consumables (Black Market)

| Feature | Status | Notes |
|---------|--------|-------|
| Stimpack (yield boost) | ✅ UI Done | Needs contract |
| EMP Jammer (timer) | ✅ UI Done | Needs contract |
| Ghost Protocol | ✅ UI Done | Skip scan |

---

## H3: Growth (Weeks 9-16)

*Advanced games and competitive features*

### Phase 3B Games

| Game | Category | Status | Target |
|------|----------|--------|--------|
| ICE Breaker | Skill | 🟣 Planned | Week 10 |
| Binary Bet | Casino | 🟣 Planned | Week 11 |
| Bounty Hunt | Strategy | 🟣 Planned | Week 12 |

### Phase 3C Games

| Game | Category | Status | Target |
|------|----------|--------|--------|
| Proxy War | Team | 🟣 Planned | Week 14 |
| Zero Day | Skill | 🟣 Planned | Week 15 |
| Shadow Protocol | Meta | 🟣 Planned | Week 16 |

### Mainnet Preparation

| Task | Status | Notes |
|------|--------|-------|
| Security Audit | 🟣 Planned | External firm |
| Testnet Beta | 🟣 Planned | Public testing |
| Documentation | 🚧 In Progress | User guides |
| Mainnet Deploy | 🟣 Planned | MegaETH mainnet |

---

## H4: Scale (Post-Launch)

*Platform evolution and ecosystem expansion*

### Medium-Term (3-6 months)

- **Multi-Pool System** — Multiple $DATA pools with different parameters
- **Governance** — Community voting on parameters
- **SDK/API** — Third-party integrations
- **Mobile App** — Native iOS/Android (stretch goal)

### Long-Term (6+ months)

- **Cross-chain** — Expand beyond MegaETH
- **Token Ecosystem** — Additional utility tokens
- **Partner Integrations** — Other MegaETH protocols
- **DAO Transition** — Progressive decentralization

---

## Not Planned

*Explicitly out of scope for foreseeable future*

- **Native Mobile Apps** — Web responsive is sufficient for MVP
- **Fiat Onramp** — Use existing bridges/exchanges
- **Traditional Gaming (Unity/Unreal)** — Web-first strategy
- **Self-hosted Option** — Complexity without benefit
- **Multi-language Support** — English-first, i18n later

See [[manifesto#non-goals]] for rationale.

---

## Milestones

| Milestone | Target | Key Capabilities | Status |
|-----------|--------|------------------|--------|
| **MVP Testnet** | Week 4 | Core loop E2E | 🚧 In Progress |
| **Phase 3A Alpha** | Week 6 | Hash Crash, Daily Ops live | 🟣 Planned |
| **Public Testnet Beta** | Week 8 | All H2 features | 🟣 Planned |
| **Security Audit Complete** | Week 12 | Clean audit report | 🟣 Planned |
| **Mainnet Launch** | Week 14-16 | Production ready | 🟣 Planned |

### MVP Testnet (Week 4)

Definition of Done:
- [ ] User can jack in using web UI
- [ ] User can extract using web UI
- [ ] Core contract events appear in feed via indexer
- [ ] Position updates in real-time
- [ ] Trace scan executes and shows deaths in feed

### Phase 3A Alpha (Week 6)

Definition of Done:
- [ ] Hash Crash playable on testnet
- [ ] Daily Ops claimable
- [ ] Code Duel matchmaking works

### Mainnet Launch (Week 14-16)

Definition of Done:
- [ ] Security audit complete, findings addressed
- [ ] Load testing passed
- [ ] Monitoring and alerting operational
- [ ] Emergency procedures documented and tested
- [ ] Public documentation complete

---

## Recently Completed

| Capability | Completed | Notes |
|------------|-----------|-------|
| Phase 2 UI (all features) | 2026-01-21 | 9 phases complete |
| Smart Contract Core | 2026-01-22 | ArcadeCore, GameRegistry |
| Randomness Contracts | 2026-01-23 | FutureBlockRandomness |
| Hash Crash Contract | 2026-01-23 | 84 tests passing |
| Code Duel Contract | 2026-01-24 | 101 tests passing |
| Daily Ops Contract | 2026-01-24 | 36 tests passing |
| Testnet Deployment | 2026-01-23 | ArcadeCore, HashCrash |
| EIP-2935 Verification | 2026-01-23 | 8191 block window confirmed |
| Hash Crash Frontend | 2026-01-25 | Full UI with themes |
| Daily Ops Frontend | 2026-01-25 | Full UI with calendar |

---

## Dependencies

### Critical Path

```
Contracts ──► Indexer ──► WebSocket ──► Web App Real-time
    │            │
    │            └──► REST API ──► Web App Queries
    │
    └──► ABI Export ──► TypeScript Types ──► Web App Writes
```

### External Dependencies

| Dependency | Risk | Mitigation |
|------------|------|------------|
| MegaETH Mainnet Access | Medium | On waitlist, testnet sufficient for now |
| Audit Firm Availability | Medium | Begin outreach in Week 6 |
| Oracle Service (future) | Low | Using block hash for now |

### Internal Dependencies

| Blocked | Waiting On | Notes |
|---------|------------|-------|
| Web real-time feed | Indexer WebSocket | Using mock data |
| Contract writes | ABI export automation | Manual process works |
| Mainnet deploy | Security audit | Hard blocker |

---

## Key Metrics (Targets)

| Metric | Week 4 | Week 8 | Launch |
|--------|--------|--------|--------|
| Test Coverage | >90% | >95% | >95% |
| Contract Tests | 1275+ | 1500+ | 2000+ |
| Web Tests | 400+ | 500+ | 600+ |
| Daily Volume (testnet) | -- | $10k sim | -- |
| Active Testers | 5 | 50 | 500 |

---

## References

- [[capabilities/]] - Detailed capability specifications
- [[quality]] - Non-functional requirements
- [[architecture]] - System architecture
- `docs/architecture/mvp-scope.md` - MVP definition
- `docs/architecture/phase2-implementation-plan.md` - Phase 2 status
- `docs/archive/product/phase-3-minigames/OVERVIEW.md` - Phase 3 tracker
- `docs/archive/product/master-design.md` Section 18 - Original 8-week roadmap

---

## Status Legend

| Status | Meaning |
|--------|---------|
| ✅ Complete | Done and verified |
| 🚧 In Progress | Actively being worked on |
| 🟣 Planned | Defined, not yet started |
| 🔴 Blocked | Waiting on dependency |
| ❌ Cancelled | Removed from scope |

---

*Last updated: 2026-01-27. Update this document during sprint planning and after milestone completions.*
