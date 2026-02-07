---
type: epic
status: ready
created: 2026-02-07
updated: 2026-02-07
depends_on:
  - "[[EPIC-002-ishizue-foundation]]"
tags:
  - type/epic
  - feature/services
  - status/ready
---

# EPIC-004: ghostnet-signer Service

## Summary

Build the `ghostnet-signer` Ishizue service — a greenfield EIP-712 signing and verification service. Five RPC methods, single responsibility, isolated security boundary.

This is the first real handler implementation on Ishizue. It's intentionally small so we learn the framework's patterns (handler wiring, `ServiceBuilder`, config, testing) before tackling the complex `ghostnet-api`.

## Motivation

Daily missions and reward claims require server-side signatures. The signer holds a private key and produces EIP-712 typed data signatures that the smart contracts verify on-chain. Isolating signing into its own service limits the blast radius — if the signer is compromised, it can only sign (not read positions, not move funds).

This service also validates Ishizue's developer experience end-to-end: scaffolding → code generation → handler implementation → testing → running.

## Scope

### In Scope

- Implement `SignerServiceHandler` — 5 RPC methods
- EIP-712 typed data signing using Alloy
- Signature verification (recover signer, compare)
- Secure key loading (environment variable, never config file)
- Unit tests: sign/verify roundtrip, tampered data rejection, Solidity interop
- Integration test: real HTTP endpoint serves public key
- Security hardening: rate limiting, audit logging, no key in logs

### Out of Scope

- HSM/Vault key management (production hardening, later)
- mTLS setup (infrastructure concern, later)

## Success Criteria

- [ ] `SignDailyClaim` produces a valid EIP-712 signature
- [ ] `VerifyDailyClaim` correctly validates signatures and rejects tampered data
- [ ] Signature produced by Rust matches what the Solidity contract expects (cross-language interop test)
- [ ] `GetPublicKey` returns the signer's address and public key
- [ ] HTTP endpoint at `/v1/public-key` responds correctly
- [ ] Private key loaded from env var, never logged
- [ ] Unit tests pass: roundtrip, tampered rejection, Solidity interop
- [ ] Integration test passes: real HTTP request → real response
- [ ] Any Ishizue framework issues logged in `docs/learnings/ishizue-framework-issues.md`

---

## Stories

| Story | Title | Status | Wave |
|-------|-------|--------|------|
| [[STORY-0030-signer-handlers]] | Signer Handler Implementation | 🟣 Ready | 1 |
| [[STORY-0031-signer-security]] | Signer Security Hardening | 🟣 Ready | 2 |

---

## Execution Order

**Pattern:** Sequential — small enough for one wave, but security hardening happens after basic functionality works.

### Wave 1: Core Functionality

- **STORY-0030** — Implement all 5 handler methods, unit tests, integration test.
- **Max agents:** 1

**Test checkpoint:** `cargo test -p ghostnet-signer` passes. `ishizue run ghostnet-signer` serves requests. `curl /v1/public-key` returns valid JSON.

### Wave 2: Hardening

*Requires: Wave 1 complete*

- **STORY-0031** — Rate limiting, audit logging, key never in logs, admin endpoint localhost-only.
- **Max agents:** 1

**Test checkpoint:** Verify rate limiting triggers. Verify audit log entries exist for all sign operations. Verify key is absent from all log output at every level.

| Wave | Stories | Agents | Notes |
|------|---------|--------|-------|
| 1 | 1 | 1 | Core handlers + tests |
| 2 | 1 | 1 | Security hardening |

---

## Technical Approach

**Alloy for all signing:**

```rust
use alloy::signers::local::PrivateKeySigner;
// NOT ethers-rs (deprecated)
```

**Handler structure:**

```
services/ghostnet-signer/src/
├── main.rs          # ServiceBuilder wiring
├── generated/       # DO NOT EDIT (ishizue generate)
├── handlers/
│   └── signer.rs    # SignerServiceHandler implementation
└── signing/
    ├── eip712.rs    # EIP-712 domain separator, type hashes
    └── keys.rs      # Key loading from env
```

**Test strategy:**

| Level | What | Tools |
|-------|------|-------|
| Unit | Sign/verify roundtrip, tampered data rejection, Solidity interop | `TestContext`, hardcoded test vectors |
| Integration | HTTP endpoint responds correctly | `TestHarness` with ephemeral port |

**Critical test — Solidity interop:**

The Solidity contracts verify signatures using `ecrecover`. We need a test that:
1. Hardcodes a known-good EIP-712 signature from the Foundry test suite
2. Signs the same typed data in Rust
3. Asserts byte-for-byte equality

If this test fails, no player can claim rewards on-chain.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Alloy's EIP-712 API differs from what we expect | Low | Medium | Check Alloy docs; we already use Alloy 1.4 in the codebase |
| Ishizue `ServiceBuilder` config patterns unclear | Medium | Low | Consult handbook Section 5; this is the learning objective |
| Signature format mismatch with Solidity | Low | High | The interop test catches this before anything ships |

---

## Notes

This is deliberately the smallest epic. Its real purpose is twofold:
1. Deliver signing functionality we need
2. Validate Ishizue's developer experience with a greenfield service

Every rough edge we find here gets logged and fixed before we build the larger `ghostnet-api`.

Design references:
- `docs/design/services/ishizue-migration-plan.md` — Step 7
- `docs/design/services/ishizue-integration-plan.md` — Section 2.4 (signer proto)
