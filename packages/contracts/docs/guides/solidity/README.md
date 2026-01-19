# Solidity Development & Security Guide

A comprehensive guide for secure Solidity smart contract development, covering environment setup, security best practices, modern language features, and deployment workflows.

**Last Updated:** January 2026 | **Solidity Version:** 0.8.33 | **OpenZeppelin Version:** 5.5.0

---

## Quick Start

```bash
# Drop into the dev environment
nix-shell

# Initialize a new project
forge init my-project && cd my-project

# Build, test, format
forge build
forge test -vvv
forge fmt
```

---

## Document Index

| Document | Description |
|----------|-------------|
| [environment-setup.md](environment-setup.md) | Nix, Foundry, Neovim, project structure, CI/CD |
| [security-fundamentals.md](security-fundamentals.md) | Threat modeling, OWASP Top 10, invariants |
| [vulnerabilities.md](vulnerabilities.md) | Access control, reentrancy, oracles, input validation |
| [modern-solidity.md](modern-solidity.md) | 0.8.x features, 0.9.0 migration, transient storage |
| [eip7702-account-abstraction.md](eip7702-account-abstraction.md) | EIP-7702, ERC-4337, ERC-7579 smart accounts |
| [cryptography-signatures.md](cryptography-signatures.md) | ECDSA, EIP-712, P256, WebAuthn |
| [patterns-upgrades.md](patterns-upgrades.md) | Design patterns, upgradeable contracts, cross-chain |
| [gas-optimization.md](gas-optimization.md) | Safe vs dangerous optimizations, gas costs |
| [testing-deployment.md](testing-deployment.md) | Testing frameworks, security tools, deployment |
| [reference.md](reference.md) | Checklists, anti-patterns, case studies, OZ migration |

---

## Quick Reference

### Essential Foundry Commands

| Task | Command |
|------|---------|
| Init project | `forge init` |
| Build | `forge build` |
| Test | `forge test -vvv` |
| Test specific | `forge test --match-test testName` |
| Format | `forge fmt` |
| Coverage | `forge coverage` |
| Gas report | `forge test --gas-report` |
| Local node | `anvil` |
| Fork mainnet | `anvil --fork-url $RPC` |
| Deploy | `forge script script/Deploy.s.sol --broadcast` |
| Verify | `forge verify-contract` |
| Interact | `cast call/send` |
| Slither | `slither .` |
| Solhint | `solhint 'src/**/*.sol'` |

### Essential OpenZeppelin Imports

```solidity
// Access Control
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// Security
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// Token Safety
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Upgrades
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// Cryptography
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Account Abstraction
import "@openzeppelin/contracts/account/Account.sol";
import "@openzeppelin/contracts/account/AccountERC7579.sol";
```

### Gas Costs Reference (Post-Cancun)

| Operation | Gas Cost |
|-----------|----------|
| SSTORE (new non-zero) | ~20,000 |
| SSTORE (update) | ~5,000 |
| SLOAD (cold) | ~2,100 |
| SLOAD (warm) | ~100 |
| TSTORE (transient) | ~100 |
| TLOAD (transient) | ~100 |
| External call (cold) | ~2,600+ |
| External call (warm) | ~100+ |
| Calldata (non-zero byte) | 16 |
| Calldata (zero byte) | 4 |

### Visibility Modifiers

| Modifier | Contract | Derived | External |
|----------|----------|---------|----------|
| public | Yes | Yes | Yes |
| external | No | No | Yes |
| internal | Yes | Yes | No |
| private | Yes | No | No |

---

## Key Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts 5.x](https://docs.openzeppelin.com/contracts/5.x)
- [OWASP Smart Contract Top 10](https://scs.owasp.org)
- [SWC Registry](https://swcregistry.io/)
- [Solidity Documentation](https://docs.soliditylang.org)
