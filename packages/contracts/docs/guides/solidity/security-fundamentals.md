# Security Fundamentals

Smart contract vulnerabilities led to over **$2.3 billion in losses** in H1 2025 alone, with access control issues accounting for $1.6 billion.

**The meta-rule:** Security is a *systems property*, not just a code property. Most real losses come from **system design + operations** (key management, governance, upgrade controls, oracle assumptions)—not a single line of Solidity.

---

## Security Before Code (The Most Important Part)

### The Spec-First Methodology

Before writing any code, create a one-page security specification:

**Assets:** What value moves through the system and where can it end up?

**Authorities:** Which actions require which roles/keys? Map every privileged operation.

**Trust Assumptions:** Document external dependencies explicitly:
- Price oracle provider and failure modes
- L2/sequencer assumptions
- Off-chain signers or keepers
- Governance mechanisms
- Upgrade authorities
- **EIP-7702 delegation status** (Can callers have delegated code?)
- **Account abstraction considerations** (Are smart accounts supported?)
- **Cross-chain message sources** (Which bridges/chains are trusted?)

**Failure Modes:** What happens when things go wrong?
- Oracle freezes or returns stale data
- Admin key is compromised
- L2 sequencer goes down
- Governance attack (flash loan voting)
- **Delegated EOA exploitation**
- **Bundler/Paymaster manipulation** (for AA)
- **Cross-chain message replay**

---

### Define Invariants BEFORE Coding

Invariants are properties that must **never** be false. Write them first because they drive your entire testing strategy.

**Example Invariants (adapt to your protocol):**

```solidity
// Conservation invariants
// totalAssets == sum(userBalances) +/- accruedFees
// totalSupply changes ONLY on mint/burn

// Safety invariants  
// No user can withdraw more than their balance
// All debt positions remain overcollateralized
// Protocol TVL >= sum of all user claims

// Access invariants
// Only MINTER_ROLE can mint
// Upgrades require timelock to have elapsed
// Paused state blocks all user operations

// Account Abstraction invariants (NEW)
// Only EntryPoint can call validateUserOp
// Nonces increment monotonically per key
// Module installations require owner approval
```

**These invariants become your Foundry invariant tests.** If you can't write the invariant, you don't understand your system well enough to build it safely.

---

### Use External Taxonomies to Avoid Blind Spots

Map your threat model against established frameworks:

| Resource | Purpose |
|----------|---------|
| **OWASP Smart Contract Top 10** | Current vulnerability rankings with loss data |
| **SWC Registry** (swcregistry.io) | Comprehensive weakness classification |
| **EIP-7512** (On-chain audit representation) | Standardized audit metadata |
| **ERC-4337 Security Considerations** | Account abstraction threat model |

---

## OWASP Smart Contract Top 10 (2025)

Based on 149 security incidents documenting $1.42B+ in losses:

| Rank | Vulnerability | 2024 Losses | Severity |
|------|--------------|-------------|----------|
| 1 | Access Control Vulnerabilities | $953.2M | Critical |
| 2 | Price Oracle Manipulation | $8.8M | Critical |
| 3 | Logic Errors | $63.8M | High |
| 4 | Lack of Input Validation | $14.6M | High |
| 5 | Reentrancy Attacks | $35.7M | Critical |
| 6 | Unchecked External Calls | $550.7K | High |
| 7 | Flash Loan Attacks | $33.8M | Critical |
| 8 | Integer Overflow/Underflow | Variable | Medium |
| 9 | Insecure Randomness | Variable | Medium |
| 10 | Denial of Service (DoS) | Variable | Medium |

---

## Critical 2025 Updates

These changes **break fundamental assumptions** in existing code:

- **EIP-7702** breaks `tx.origin == msg.sender` (no longer guarantees EOA)
- **Solidity 0.9.0** deprecations require migration NOW (`send`/`transfer`, ABI coder v1, virtual modifiers)
- **Storage array bug** fixed in 0.8.32 - review contracts using 0.8.29-0.8.31
- **Fusaka EVM upgrade** brings new opcodes and security considerations
- **OpenZeppelin 5.x** introduces `ReentrancyGuardTransient` and ERC-7201 namespaced storage
- **ERC-4337/ERC-7579 Account Abstraction** introduces entirely new attack surfaces
- **ECDSA signature malleability protection deprecated** - migrate to nonces NOW
- **Proxy initialization now mandatory** - deployments without init calls will revert
- **Cross-chain security standards** (ERC-7786, CAIP-2/10) for multi-chain protocols

---

## Next Steps

- [vulnerabilities.md](vulnerabilities.md) - Detailed prevention patterns for each vulnerability type
- [modern-solidity.md](modern-solidity.md) - Language features and 0.9.0 migration guide
- [eip7702-account-abstraction.md](eip7702-account-abstraction.md) - New paradigm security considerations
