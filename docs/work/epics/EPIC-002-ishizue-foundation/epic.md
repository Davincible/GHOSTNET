---
type: epic
status: ready
created: 2026-02-07
updated: 2026-02-07
tags:
  - type/epic
  - feature/services
  - status/ready
---

# EPIC-002: Ishizue Foundation

## Summary

Create the Ishizue workspace, proto definitions, domain crate, and infrastructure crate migration. This epic produces the scaffolding that all three services build on. At the end, `ishizue generate` runs, `cargo build --workspace` succeeds, and the domain crate has full test coverage on extracted types.

## Motivation

Everything else depends on this workspace existing and compiling. We build on Ishizue from day one — no legacy scaffolding, no hand-wired workspace. The domain crate (`ghostnet-domain`) is the shared type system that all services import.

We are also the developers of Ishizue. This is the first real-world use of the framework. Every friction point discovered here gets fixed in the framework itself.

## Scope

### In Scope

- Scaffold Ishizue workspace with `ishizue init`
- Write all proto definitions (common types, API, signer, fleet)
- Run `ishizue generate` and verify compilation
- Create `ghostnet-domain` library crate with extracted domain types, enums, entities, port traits
- Copy infrastructure crates (`megaeth-rpc`, `evm-provider`, `fleet-core`, `ghostnet-actions`) into workspace
- Configure workspace lints, Rust edition, toolchain
- Full unit test suite on domain crate

### Out of Scope

- Handler implementations (that's EPIC-003 and EPIC-004)
- Database adapters, ingestion pipeline (EPIC-003)
- Deployment, Docker, CI (later)

## Success Criteria

- [ ] `ishizue init` runs successfully; workspace structure adopted
- [ ] All four proto files compile (`ishizue generate` succeeds)
- [ ] `cargo build --workspace` passes with zero warnings
- [ ] `ghostnet-domain` crate has unit tests for all types (enums, entities, primitives)
- [ ] Port traits compile with native `async fn in trait` (no `async_trait` macro)
- [ ] Infrastructure crates (`megaeth-rpc`, `evm-provider`, `fleet-core`) compile in the new workspace
- [ ] Workspace lints match our standards (`unsafe_code = "forbid"`, `unwrap_used = "deny"`, etc.)
- [ ] Any Ishizue framework issues logged in `docs/learnings/ishizue-framework-issues.md`

---

## Stories

| Story | Title | Status | Wave |
|-------|-------|--------|------|
| [[STORY-0010-scaffold-workspace]] | Scaffold Ishizue Workspace | 🟣 Ready | 1 |
| [[STORY-0011-proto-definitions]] | Write Proto Definitions | 🟣 Ready | 1 |
| [[STORY-0012-domain-crate]] | Create Domain Crate | 🟣 Ready | 2 |
| [[STORY-0013-infra-crates]] | Migrate Infrastructure Crates | 🟣 Ready | 2 |

---

## Execution Order

**Pattern:** Waves

### Wave 1: Scaffold (Sequential)

- **STORY-0010** → **STORY-0011** — Workspace must exist before protos. Protos must compile before anything else.
- **Max agents:** 1 (these are fast, sequential steps)

### Wave 2: Crates (Parallel)

*Requires: Wave 1 complete (workspace exists and compiles)*

- **STORY-0012** ∥ **STORY-0013** — Domain crate and infrastructure crates are independent.
- **Max agents:** 2

| Wave | Stories | Agents | Notes |
|------|---------|--------|-------|
| 1 | 2 | 1 | Scaffold workspace, write protos |
| 2 | 2 | 2 | Domain crate + infra crates in parallel |

---

## Technical Approach

**Step-by-step, tested at each step:**

1. Run `ishizue init` in temp dir, inspect output, adopt into `services/`
2. Write proto files, run `ishizue generate`, verify `cargo build`
3. Cherry-pick domain types from old indexer into `libs/ghostnet-domain/`
4. Remove `sqlx::Type` (add behind feature flag), remove `async_trait`, keep tests
5. Copy infra crates, verify they compile in new workspace
6. Run `cargo test --workspace` — everything green

**Testing checkpoint after each story:**

| After | Test |
|-------|------|
| STORY-0010 | `cargo build --workspace` passes (placeholder services) |
| STORY-0011 | `ishizue generate` succeeds, `cargo build --workspace` passes |
| STORY-0012 | `cargo test -p ghostnet-domain` — all domain type tests pass |
| STORY-0013 | `cargo check -p megaeth-rpc -p evm-provider -p fleet-core` passes |

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| `ishizue init` generates unexpected structure | Medium | Medium | Inspect in temp dir first, adapt |
| Proto auto-discovery doesn't match our naming | Low | Low | Already decided: match dirs to service names |
| Workspace lints conflict with generated code | Medium | Low | Configure `#[allow]` in generated modules only |
| Edition 2024 async traits incompatible with Ishizue codegen | Medium | Medium | Fall back to `async_trait` in ports if needed; file Ishizue issue |

---

## Notes

This epic is foundational infrastructure. It produces no user-visible functionality, but everything depends on it. The domain crate and workspace structure are the ground truth for all subsequent service work.

Design references:
- `docs/design/services/ishizue-migration-plan.md` — Steps 1–6
- `docs/design/services/ishizue-integration-plan.md` — Proto definitions, workspace config
