# Reference

Checklists, anti-patterns, case studies, and OpenZeppelin migration guide.

---

## OpenZeppelin 5.x Migration Guide

### Critical Breaking Changes Summary

| Version | Breaking Change | Migration Action |
|---------|----------------|------------------|
| 5.0 | Token hooks removed | Override `_update` instead of `_beforeTokenTransfer` |
| 5.0 | `increaseAllowance`/`decreaseAllowance` removed | Use `approve` or `forceApprove` |
| 5.0 | Namespaced storage (ERC-7201) | Update storage patterns |
| 5.4 | Min pragma 0.8.24 for many contracts | Update compiler version |
| 5.5 | ECDSA malleability protection deprecated | Use nonces/hash invalidation |
| 5.5 | Proxy init mandatory | Add init call to deployments |
| 5.5 | SignerERC7702 -> SignerEIP7702 | Update imports |
| 5.5 | Fallback module data >= 4 bytes | Update ERC-7579 calls |
| 5.5 | validateUserOp signature parameter | Update Account implementations |

### Token Migration (ERC-20/721/1155)

```solidity
// OLD (v4.x): _beforeTokenTransfer hook
function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);
    require(!paused, "Paused");
}

// NEW (v5.x): _update function
function _update(
    address from,
    address to,
    uint256 amount
) internal virtual override {
    require(!paused, "Paused");
    super._update(from, to, amount);
}
```

### Import Path Updates

```solidity
// DEPRECATED: Draft prefixes
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

// CORRECT: Non-draft versions
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

// DEPRECATED: Upgradeable library imports
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

// CORRECT: Base package for libraries
import "@openzeppelin/contracts/utils/Address.sol";

// DEPRECATED: ERC-6909 draft paths (v5.5.0)
import "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";

// CORRECT: Final paths
import "@openzeppelin/contracts/token/ERC6909/ERC6909.sol";
```

### New Utilities Summary

| Utility | Version | Purpose |
|---------|---------|---------|
| `Bytes` library | 5.2.0 | Slice, splice, compare, reverse |
| `Math.saturatingAdd/Sub/Mul` | 5.3.0 | No-overflow arithmetic |
| `Math.mul512/add512` | 5.3.0 | Extended precision |
| `MerkleTree` | 5.1.0 | On-chain tree construction |
| `NoncesKeyed` | 5.2.0 | ERC-4337 compatible nonces |
| `CAIP2/CAIP10` | 5.2.0 | Cross-chain identifiers |
| `RLP` | 5.5.0 | Ethereum RLP encoding |
| `WebAuthn` | 5.5.0 | Passkey verification |
| `ERC7739` | 5.4.0 | Anti-replay signatures |

---

## Anti-Patterns to Ban in Code Review

Print this list and check every PR against it:

| Anti-Pattern | Why It's Dangerous | Correct Approach |
|--------------|-------------------|------------------|
| `tx.origin == msg.sender` check | **Broken by EIP-7702** | Time delays, rate limits, CEI |
| `address.code.length == 0` EOA check | **Broken by EIP-7702** (delegated EOAs have 23 bytes) | Don't rely on caller type |
| EOA admin with direct upgrade power | Single point of failure | Multisig + timelock |
| Unbounded loops over user-controlled data | DoS via gas exhaustion | Pagination, checkpointing |
| External calls mid-accounting | Reentrancy vector | CEI pattern + guards |
| Spot price as oracle | Flash loan manipulation | TWAP or Chainlink |
| Implicit token behavior assumptions | Fee-on-transfer, weird returns | SafeERC20, explicit checks |
| `selfdestruct` usage | Deprecated, unreliable | Pause + drain pattern |
| Signature without nonce/domain | Replay attacks | EIP-712 typed data |
| `transfer()`/`send()` for ETH | **Removed in 0.9.0** | `call{value: x}("")` with CEI |
| "Just add a require" without tests | False confidence | Invariant tests backing every require |
| Storing secrets on-chain | All blockchain data is public | Off-chain secrets, commit-reveal |
| Using `block.timestamp` for randomness | Miner manipulation | Chainlink VRF, commit-reveal |
| Mixing decimals without conversion | Silent truncation | Explicit decimal normalization |
| Using Solidity <0.8.33 | Missing security fixes | Upgrade to latest stable |
| ABI coder v1 pragma | **Removed in 0.9.0** | Remove pragma (v2 default) |
| Virtual modifiers | **Removed in 0.9.0** | Use virtual internal functions |
| **Signatures as unique identifiers** | **Deprecated in OZ v6.0** | Use nonces/hash invalidation |
| **Untrusted ERC-7579 hooks** | DoS attack vector | Only audited module sources |
| **Missing EntryPoint validation** | Unauthorized AA execution | Always check `msg.sender` |

---

## Pre-Deployment Checklist

### Design

- [ ] Threat model enumerated (assets, roles, trust assumptions)
- [ ] Invariants written AND mapped to Foundry invariant tests
- [ ] Failure modes documented (oracle stale, admin compromised, L2 down)
- [ ] EIP-7702 implications considered (no caller-type assumptions)
- [ ] Account abstraction threat model (if applicable)
- [ ] Cross-chain trust assumptions documented
- [ ] One-page spec reviewed by team

### Implementation

- [ ] Solidity >=0.8.33, all compiler warnings resolved
- [ ] All 0.9.0 deprecation warnings fixed (send/transfer, virtual modifiers, etc.)
- [ ] All functions have explicit visibility modifiers
- [ ] RBAC + least privilege; no god-mode EOA
- [ ] CEI + ReentrancyGuard (preferably Transient) on all external call functions
- [ ] SafeERC20 for all token transfers
- [ ] Input validation on all parameters
- [ ] Oracle validity checks (staleness, bounds, decimals)
- [ ] No unbounded loops; pagination where needed
- [ ] No `selfdestruct`
- [ ] No `tx.origin` checks for security
- [ ] No code-size checks for EOA detection
- [ ] ERC-7201 namespaced storage if upgradeable
- [ ] Two-step ownership transfer (Ownable2Step)
- [ ] Events emitted for all state changes
- [ ] NatSpec documentation complete
- [ ] Custom errors used (not string reverts)

### Account Abstraction (if applicable)

- [ ] EntryPoint is verified official deployment
- [ ] All sensitive functions gated to EntryPoint
- [ ] `validateUserOp` returns validation data, not reverts
- [ ] ERC-7579 modules are from audited sources
- [ ] Hook modules cannot DoS the account
- [ ] Fallback module data >= 4 bytes (v5.5.0+)
- [ ] Nonce management uses EntryPoint system

### Signatures

- [ ] **Not using signatures as unique identifiers** (deprecated in OZ v6.0)
- [ ] Using nonces or hash invalidation for replay protection
- [ ] EIP-712 typed data with proper domain separator
- [ ] Consider ERC-7739 for cross-contract replay prevention

### Imports & Compatibility

- [ ] Pragma >= 0.8.24 for affected contracts (Votes, Governor, etc.)
- [ ] No deprecated draft-* imports
- [ ] Libraries imported from base package (not upgradeable)
- [ ] ERC-6909 using non-draft paths (v5.5.0+)

### Proxy/Upgrade Security

- [ ] ERC1967Proxy/TransparentUpgradeableProxy has init call (v5.5.0+)
- [ ] Initializable imported from base package
- [ ] Custom storage slots documented (if using)
- [ ] `_disableInitializers()` called in implementation constructor

### Token Safety

- [ ] `SafeERC20.forceApprove` for USDT-like tokens
- [ ] ERC-1155 event listeners handle TransferSingle for single-item batches
- [ ] ERC-1363 receivers properly implemented (if accepting payable tokens)

### Verification

- [ ] Slither in CI, no high-severity issues
- [ ] Unit tests cover edge cases and revert reasons
- [ ] Fuzz tests for all public entrypoints
- [ ] Invariant tests for system properties
- [ ] Fork tests against mainnet
- [ ] Differential tests for core math (if applicable)
- [ ] EIP-7702 attack scenarios tested
- [ ] Account abstraction scenarios tested (if applicable)
- [ ] Internal security review complete
- [ ] External audit completed
- [ ] All findings addressed and re-verified

### Deployment

- [ ] Testnet deployment successful
- [ ] Contract verified on block explorer
- [ ] Initialize called immediately after proxy deploy
- [ ] Admin addresses are multi-sig + timelock
- [ ] Canary deployment: caps, allowlist, gradual ramp
- [ ] Monitoring and alerting configured
- [ ] Incident response plan documented
- [ ] Bug bounty program active

---

## Real-World Attack Case Studies (2025)

### Cetus DEX (May 2025) - $223M

**Vulnerability:** Integer overflow in unchecked code
**Root Cause:** Missed overflow check in arithmetic operation
**Lesson:** Even in Solidity 0.8+, `unchecked` blocks can overflow. Only use when mathematically provable. Always bound inputs.

### KiloEx DEX (2025) - $7M

**Vulnerability:** Missing access control on admin function
**Root Cause:** Forgot to add `onlyOwner` modifier
**Lesson:** Every function needs explicit access control review. Use RBAC, not ad-hoc checks. Static analysis catches this.

### EIP-7702 Phishing Wave (August 2025) - $12M+

**Vulnerability:** Users tricked into signing malicious delegation authorizations
**Root Cause:** Lack of user awareness about EIP-7702 implications
**Lesson:**
- Never sign authorization tuples you don't understand
- Wallet UIs must prominently flag 7702 approvals
- Treat delegation as equivalent to sharing your private key

### Smart Account Module Attack (2025) - $4M

**Vulnerability:** Malicious hook module installed via social engineering
**Root Cause:** User installed untrusted ERC-7579 hook that blocked all transactions
**Lesson:**
- Only install modules from audited, trusted sources
- Implement module recovery mechanisms
- Monitor ModuleInstalled events

### Penpie Protocol (2024) - $27M

**Vulnerability:** Reentrancy attack
**Root Cause:** Missing CEI pattern and ReentrancyGuard
**Lesson:** CEI pattern and ReentrancyGuard are non-negotiable. Review all callback hooks.

### The DAO (2016) - $60M

**Vulnerability:** Reentrancy in withdrawal function
**Root Cause:** State updated after external call
**Lesson:** The attack that changed Ethereum forever - always update state before external calls.

### PAID Network (2021) - Admin Key Compromise

**Vulnerability:** Single EOA controlled upgrades
**Root Cause:** No multisig, no timelock
**Lesson:** Multi-sig + timelock for ALL admin operations. Defense in depth.

---

## Key Resources

- **OWASP Smart Contract Top 10 (2025)**: scs.owasp.org
- **SWC Registry**: swcregistry.io
- **ERC-7201 Namespaced Storage**: eips.ethereum.org/EIPS/eip-7201
- **EIP-7702 Specification**: eips.ethereum.org/EIPS/eip-7702
- **ERC-4337 Specification**: eips.ethereum.org/EIPS/eip-4337
- **ERC-7579 Specification**: eips.ethereum.org/EIPS/eip-7579
- **Foundry Invariant Testing**: book.getfoundry.sh/forge/invariant-testing
- **Slither Static Analysis**: github.com/crytic/slither
- **OpenZeppelin Contracts 5.x**: docs.openzeppelin.com/contracts/5.x
- **OpenZeppelin Security Center**: contracts.openzeppelin.com
- **Solidity Documentation**: docs.soliditylang.org
- **Ethereum Security**: ethereum.org/developers/docs/smart-contracts/security

---

*Guide compiled from: OWASP Smart Contract Top 10 (2025), SWC Registry, OpenZeppelin Contracts v5.0-v5.5 documentation and changelog, Trail of Bits research, Cyfrin security guides, CertiK EIP-7702 analysis, Foundry documentation, EIP-1153/ERC-7201/EIP-7702/ERC-4337/ERC-7579 specifications, Solidity 0.8.31-0.8.33 changelogs, and analysis of $4B+ in smart contract exploits through 2025.*

**Last Updated:** January 2026 | **Solidity Version:** 0.8.33 | **OpenZeppelin Version:** 5.5.0 | **EVM Target:** Prague (Pectra)
