# Learnings

This directory captures learnings from difficult problems encountered during development.

## Purpose

When we encounter and solve sticky issues (3+ attempts to fix), we document:
- What the problem was
- What we tried that didn't work
- What ultimately solved it
- Why the solution works

This prevents re-learning the same lessons.

## Learnings

| # | Title | Category | Summary |
|---|-------|----------|---------|
| [001](./001-prevrandao-megaeth.md) | prevrandao on MegaETH | Smart Contracts | `block.prevrandao` stays constant for ~60s on MegaETH, unlike Ethereum. Mitigated with lock period. |
| [004](./004-timescaledb-hypertable-entity-antipattern.md) | Hypertables for Entities is Antipattern | Database/TimescaleDB | Entity tables with updates (positions) should NOT be hypertables. Append-only event tables (deaths) SHOULD be. |
| [005](./005-token-amount-bigdecimal-scale-mismatch.md) | TokenAmount BigDecimal Scale Mismatch | Database/Rust | `to_bigdecimal()` must convert human units to wei when schema uses `NUMERIC(78, 0)` (integers). |
| [2026-01-23](./2026-01-23-megaeth-foundry-deployment.md) | MegaETH Foundry Deployment | Smart Contracts/MegaETH | MegaEVM has different gas costs. Use `--skip-simulation --gas-limit 10000000 --legacy` for all Foundry deployments. |
| [2026-01-20](./2026-01-20-evm-rust-guide-alignment.md) | EVM Rust Guide Alignment | Architecture/Dependencies | Keep Rust MSRV + Alloy versions aligned across docs/specs/CI. |

## Template

When adding a learning:

```markdown
# Learning: [Short Title]

**Date:** YYYY-MM-DD  
**Category:** [Svelte/Web3/Testing/Build/etc.]  
**Difficulty:** [Hours spent]

## Problem

What was the issue?

## What Didn't Work

1. First attempt and why it failed
2. Second attempt and why it failed
3. etc.

## Solution

What actually fixed it.

## Why It Works

Technical explanation of the root cause and fix.

## Prevention

How to avoid this in the future.
```
