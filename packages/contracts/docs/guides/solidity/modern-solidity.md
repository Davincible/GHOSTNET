# Modern Solidity Features (2025)

Critical language features, compiler changes, and migration requirements for Solidity 0.8.x and the upcoming 0.9.0 release.

---

## Compiler Baseline

Use **Solidity >=0.8.33** as your minimum. Critical security-relevant features by version:

| Version | Feature | Security Impact |
|---------|---------|-----------------|
| 0.8.0 | Checked arithmetic | Overflow protection by default |
| 0.8.4 | Custom errors | Gas-efficient reverts with data |
| 0.8.24 | Transient storage (EIP-1153) | Cheaper reentrancy guards |
| 0.8.25 | MCOPY opcode | Efficient memory operations |
| 0.8.26 | `require(bool, Error)` | Custom errors in require |
| 0.8.28 | Transient storage (value types) | Full tstore/tload support |
| 0.8.29 | Custom storage layout | Relocate storage arbitrarily |
| **0.8.30** | **Prague EVM default** | **EIP-7702 delegation support** |
| 0.8.31 | Fusaka EVM, CLZ opcode | Latest EVM features |
| **0.8.32** | **Storage array bugfix** | **Critical: Arrays at storage end** |
| 0.8.33 | Constant getter fix | Backwards compatibility fix |

### Prague EVM Target (Solidity 0.8.30+)

Solidity 0.8.30+ defaults to the **Prague** EVM target (Pectra upgrade, May 2025). This is the first EVM version with EIP-7702 support.

```toml
# foundry.toml - explicit Prague targeting
[profile.default]
evm_version = "prague"
solc_version = "0.8.33"
```

```javascript
// hardhat.config.js
module.exports = {
  solidity: {
    version: "0.8.33",
    settings: {
      evmVersion: "prague"
    }
  }
};
```

**If deploying to networks that haven't upgraded to Prague**, set an earlier EVM version explicitly.

### Critical: Solidity 0.8.32 Storage Array Bug

Version 0.8.32 fixes a bug affecting arrays that straddle the end of storage. If you're using 0.8.29-0.8.31, review any contracts with:
- Large storage arrays
- Dynamic arrays that could grow near storage limits
- Complex storage layouts

```solidity
// Potentially affected operations in 0.8.29-0.8.31:
// - Array assignment/initialization
// - delete on arrays
// - push()/pop() operations
// - Copying arrays to storage

// SOLUTION: Upgrade to 0.8.33+
pragma solidity ^0.8.33;
```

---

## Solidity 0.9.0 Migration (CRITICAL - Prepare NOW)

Solidity 0.8.31+ emits deprecation warnings for features being removed in 0.9.0. **Fix these NOW:**

### `send()` and `transfer()` Removal

```solidity
// DEPRECATED (will fail to compile in 0.9.0)
function withdrawOld() external {
    payable(msg.sender).transfer(amount);   // Deprecated!
    payable(msg.sender).send(amount);       // Deprecated!
}

// CORRECT: Use low-level call
function withdraw() external nonReentrant {
    uint256 amount = balances[msg.sender];
    balances[msg.sender] = 0;  // CEI pattern!
    
    (bool success, ) = payable(msg.sender).call{value: amount}("");
    require(success, "Transfer failed");
}
```

**Why removed:** The 2300 gas stipend is unreliable after EIP-1884 (Istanbul) changed opcode costs. `call{value: x}("")` is now the only safe pattern.

### ABI Coder v1 Removal

```solidity
// DEPRECATED (remove this pragma entirely)
pragma abicoder v1;

// ABI coder v2 is default since 0.8.0 - no pragma needed
// v2 supports: structs, nested arrays, better encoding
```

### Virtual Modifier Removal

```solidity
// DEPRECATED: Modifiers can no longer be virtual
contract Base {
    modifier onlyOwner() virtual {  // Will fail in 0.9.0!
        require(msg.sender == owner);
        _;
    }
}

// CORRECT: Use functions for overridable logic
contract Base {
    function _checkOwner() internal view virtual {
        require(msg.sender == owner, "Not owner");
    }
    
    modifier onlyOwner() {
        _checkOwner();  // Calls virtual function
        _;
    }
}

contract Derived is Base {
    function _checkOwner() internal view override {
        // Custom ownership logic
        require(msg.sender == owner || msg.sender == admin, "Not authorized");
    }
}
```

### Contract Comparison Changes

```solidity
// DEPRECATED: Direct contract comparison
function compareContracts(IERC20 tokenA, IERC20 tokenB) external view returns (bool) {
    return tokenA < tokenB;  // Will fail in 0.9.0!
}

// CORRECT: Explicit address casting
function compareContracts(IERC20 tokenA, IERC20 tokenB) external view returns (bool) {
    return address(tokenA) < address(tokenB);
}
```

### Memory-Safe Assembly Annotation

```solidity
// DEPRECATED: Comment-based annotation
/// @solidity memory-safe-assembly
assembly {
    // ...
}

// CORRECT: Use assembly attribute
assembly ("memory-safe") {
    // Memory-safe operations only
    let x := mload(0x40)
    mstore(x, 42)
    mstore(0x40, add(x, 0x20))
}
```

---

## Transient Storage (EIP-1153): Powerful But Dangerous

Transient storage is cleared **at end-of-transaction**, not per-call-frame. This is a critical distinction.

```solidity
// RECOMMENDED: Use OpenZeppelin's TransientReentrancyGuard
import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract ModernVault is ReentrancyGuardTransient {
    // 50%+ gas savings vs storage-based guard
    // Auto-cleared at end of transaction
    
    function withdraw() external nonReentrant {
        // Protected from reentrancy
    }
}

// Manual implementation (if needed)
contract TransientReentrancyGuard {
    bytes32 constant LOCK_SLOT = keccak256("reentrancy.lock");
    
    modifier nonReentrant() {
        assembly {
            if tload(LOCK_SLOT) { revert(0, 0) }
            tstore(LOCK_SLOT, 1)
        }
        _;
        assembly {
            tstore(LOCK_SLOT, 0) // CRITICAL: Clear after execution
        }
    }
}

// DANGEROUS: Not clearing transient storage
modifier brokenNonReentrant() {
    assembly {
        if tload(LOCK_SLOT) { revert(0, 0) }
        tstore(LOCK_SLOT, 1)
    }
    _; 
    // Missing: tstore(LOCK_SLOT, 0)
    // If called multiple times in same tx, subsequent calls fail!
}
```

### Transient Storage Rules

- [ ] ALWAYS clear transient slots before returning (unless intentional)
- [ ] Treat it as "transaction-global mutable state"
- [ ] Never assume it behaves like memory scoping
- [ ] Be extremely careful with multi-call bundles (e.g., multicall patterns)
- [ ] Review ALL transient storage usage manually in audits

---

## EIP-2935: Extended Block Hash History (Prague)

The Prague upgrade introduces EIP-2935, providing access to historical block hashes beyond the 256-block limit.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

library BlockhashHistory {
    // EIP-2935 system contract address
    address constant HISTORY_ADDR = 0x0000F90827F1C53a10Cb7A02335B175320002935;
    uint256 constant WINDOW = 8191; // ~27 hours of blocks
    
    function getBlockhash(uint256 blockNumber) internal view returns (bytes32) {
        // Use native BLOCKHASH for recent blocks (cheaper)
        if (block.number - blockNumber <= 256) {
            return blockhash(blockNumber);
        }
        
        // Use history contract for older blocks (up to ~27 hours)
        require(block.number - blockNumber <= WINDOW, "Block too old");
        
        (bool success, bytes memory data) = HISTORY_ADDR.staticcall(
            abi.encode(blockNumber)
        );
        require(success && data.length == 32, "Query failed");
        return abi.decode(data, (bytes32));
    }
}
```

**Use cases:**
- Cross-chain verification that needs historical state
- Delayed oracle settlement
- On-chain randomness with longer commit-reveal windows

---

## ERC-7201: Namespaced Storage (Critical for Upgrades)

ERC-7201 standardizes storage namespace locations to prevent upgrade collisions.

```solidity
// CORRECT: ERC-7201 namespaced storage pattern
abstract contract ERC7201Example {
    /// @custom:storage-location erc7201:example.main
    struct MainStorage {
        uint256 value;
        mapping(address => uint256) balances;
    }
    
    // keccak256(abi.encode(uint256(keccak256("example.main")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MAIN_STORAGE_LOCATION = 
        0x...; // Computed deterministically
    
    function _getMainStorage() private pure returns (MainStorage storage $) {
        assembly {
            $.slot := MAIN_STORAGE_LOCATION
        }
    }
    
    function getValue() public view returns (uint256) {
        return _getMainStorage().value;
    }
}
```

**Why ERC-7201 Matters:**
- Prevents storage collisions between inherited contracts
- Makes upgrade safety verifiable by tooling
- Required for complex proxy patterns (diamonds)
- OpenZeppelin Contracts 5.x uses this pattern
- Eliminates need for `__gap` variables in most cases

---

## New EVM Features (Fusaka/Osaka)

Solidity 0.8.31+ defaults to **Osaka** EVM (Fusaka upgrade).

### CLZ Opcode (EIP-7939)

```solidity
// Count Leading Zeros - useful for bit manipulation
contract BitOperations {
    function countLeadingZeros(uint256 input) external pure returns (uint256) {
        assembly {
            let result := clz(input)
            mstore(0x00, result)
            return(0x00, 0x20)
        }
    }
    
    // Use cases: efficient log2, bit scanning, packed data
}
```

### Security Considerations

- ModExp precompile cost increased - review gas estimates
- Transaction gas cap: 16.7M (2^24) - affects complex multi-calls
- If deploying to older networks, set EVM version explicitly:

```javascript
// hardhat.config.js
module.exports = {
    solidity: {
        version: "0.8.33",
        settings: {
            evmVersion: "cancun"  // or older if needed
        }
    }
};
```

---

## SELFDESTRUCT is Deprecated

`SELFDESTRUCT` semantics have changed (EIP-6780) and will shrink further:

```solidity
// NEVER DO THIS
function emergencyDestroy() external onlyOwner {
    selfdestruct(payable(owner)); // Deprecated, unreliable
}

// INSTEAD: Use proper emergency patterns
function emergencyWithdraw() external onlyOwner {
    _pause();
    uint256 balance = address(this).balance;
    (bool success, ) = payable(owner).call{value: balance}("");
    require(success, "Withdraw failed");
    // Contract remains, but is paused and drained
}
```

**SELFDESTRUCT Issues:**
- No longer removes code in same-transaction deploys (EIP-6780)
- Future EIPs may remove ETH-sending capability entirely
- Creates unpredictable state for integrators
- Never rely on "code removal" as a security feature

---

## Solidity Version Decision Tree

```
Is this a new project?
├── YES → Use Solidity 0.8.33 (latest stable)
│         └── Ensure pragma >= 0.8.24 for OZ contracts
└── NO → Is it actively maintained?
    ├── YES → Upgrade to 0.8.33
    │         ├── Fix all deprecation warnings
    │         └── Update OZ to 5.x with migration guide
    └── NO → Consider full audit before any changes
```

---

## Next Steps

- [eip7702-account-abstraction.md](eip7702-account-abstraction.md) - EIP-7702 and Account Abstraction security
- [patterns-upgrades.md](patterns-upgrades.md) - Upgradeable contract patterns with ERC-7201
- [reference.md](reference.md) - OpenZeppelin 5.x migration guide
