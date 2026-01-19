# Gas Optimization (Security-Conscious)

Gas optimization is important, but never at the expense of security. This guide covers safe optimizations and dangerous anti-patterns to avoid.

**The golden rule:** 100 gas saved is meaningless if you lose $1M to a hack.

---

## Safe Optimizations

### Use `unchecked` for Known-Safe Operations

```solidity
// Safe: Loop counter can't overflow
function sum(uint256[] calldata values) external pure returns (uint256 total) {
    uint256 len = values.length;
    
    for (uint256 i; i < len; ) {
        total += values[i];  // Could overflow if sum > 2^256
        unchecked { ++i; }   // Loop counter can't overflow
    }
}

// Safer: Check total won't overflow
function sumSafe(uint256[] calldata values) external pure returns (uint256 total) {
    uint256 len = values.length;
    
    for (uint256 i; i < len; ) {
        uint256 newTotal = total + values[i];
        require(newTotal >= total, "Overflow");  // Or just don't use unchecked
        total = newTotal;
        unchecked { ++i; }
    }
}
```

### Pack Storage Variables

Packing saves ~20,000 gas per storage slot.

```solidity
// BAD: 3 storage slots
contract Unpacked {
    uint256 a;    // Slot 0
    uint8 b;      // Slot 1
    uint256 c;    // Slot 2
}

// GOOD: 2 storage slots
contract Packed {
    uint256 a;    // Slot 0
    uint256 c;    // Slot 1
    uint8 b;      // Slot 1 (packed with padding)
}

// BETTER: Explicit packing
contract ExplicitPacking {
    uint128 a;    // Slot 0 (left half)
    uint128 b;    // Slot 0 (right half)
    uint256 c;    // Slot 1
}
```

### Use `calldata` for Read-Only Arrays

```solidity
// calldata is cheaper than memory for external function parameters
function process(uint256[] calldata data) external pure returns (uint256) {
    // calldata: read directly from transaction data
    // memory: copies data, costs more gas
}
```

### Use Custom Errors

Custom errors are ~12% cheaper to deploy than string revert messages.

```solidity
// BAD: String reverts
function withdraw(uint256 amount) external {
    require(balances[msg.sender] >= amount, "Insufficient balance");
}

// GOOD: Custom errors
error InsufficientBalance(uint256 available, uint256 required);

function withdraw(uint256 amount) external {
    if (balances[msg.sender] < amount) {
        revert InsufficientBalance(balances[msg.sender], amount);
    }
}
```

### Cache Storage Reads

Each SLOAD costs ~2,100 gas (cold) or ~100 gas (warm).

```solidity
// BAD: Multiple storage reads
function processMultipleBad() external {
    for (uint256 i; i < 10; ++i) {
        doSomething(value); // Reads `value` from storage each iteration
    }
}

// GOOD: Cache storage read
function processMultiple() external {
    uint256 _value = value; // Cache storage read (2100 gas once)
    
    for (uint256 i; i < 10; ++i) {
        doSomething(_value); // Use cached value (3 gas each)
    }
}
```

### Use `immutable` for Constructor-Set Values

`immutable` variables are embedded in bytecode, cheaper to read than storage.

```solidity
contract Efficient {
    address public immutable owner;  // Set once, read cheaply
    uint256 public immutable createdAt;
    
    constructor() {
        owner = msg.sender;
        createdAt = block.timestamp;
    }
}
```

---

## Dangerous "Optimizations" to Avoid

### Never Remove Necessary Checks

```solidity
// DANGEROUS: Removed zero-address check to "save gas"
function unsafeTransfer(address to, uint256 amount) external {
    // Missing: require(to != address(0));
    balances[msg.sender] -= amount;
    balances[to] += amount;
}
```

### Avoid Unnecessary Assembly

Assembly bypasses Solidity's safety checks and is error-prone. Only use when absolutely necessary and always audit thoroughly.

```solidity
// Prefer Solidity unless you have a specific, measured need for assembly
// Assembly errors are subtle and can be catastrophic
```

### Never Use `unchecked` for User-Controlled Arithmetic

```solidity
// DANGEROUS: User-controlled values can overflow silently
function dangerousSum(uint256[] calldata values) external pure returns (uint256 total) {
    unchecked {
        for (uint256 i; i < values.length; ++i) {
            total += values[i];  // Can overflow silently!
        }
    }
}

// SAFE: Let Solidity check for overflow
function safeSum(uint256[] calldata values) external pure returns (uint256 total) {
    for (uint256 i; i < values.length; ) {
        total += values[i];  // Solidity 0.8+ checks overflow
        unchecked { ++i; }   // Only loop counter is unchecked
    }
}
```

### Don't Sacrifice Security for Micro-Optimizations

```solidity
// The cost of a security audit finding: $5,000-$50,000
// The cost of a hack: $1,000,000+
// The gas saved by removing a check: ~200 gas (~$0.01)

// Always prioritize security over gas savings
```

---

## Gas Costs Reference (Prague/Pectra)

| Operation | Gas Cost |
|-----------|----------|
| SSTORE (new non-zero) | ~20,000 |
| SSTORE (update) | ~5,000 |
| SSTORE (zero -> non-zero) | ~20,000 |
| SSTORE (non-zero -> zero) | ~5,000 + 15,000 refund |
| SLOAD (cold) | ~2,100 |
| SLOAD (warm) | ~100 |
| TSTORE (transient) | ~100 |
| TLOAD (transient) | ~100 |
| External call (cold) | ~2,600+ |
| External call (warm) | ~100+ |
| Memory word | 3 |
| Calldata (non-zero byte) | 16 |
| Calldata (zero byte) | 4 |
| MCOPY (per word) | 3 |

### Blob Capacity (Pectra Upgrade)

The Pectra upgrade doubled blob capacity:
- **Target**: 3 -> 6 blobs per block
- **Maximum**: 6 -> 9 blobs per block

**Impact for L2/Rollup operators:**
- L2 fees dropped significantly post-upgrade
- Rollup throughput increased without protocol changes
- If you're running a rollup, this is free scaling

**For most contract developers:** Blob pricing doesn't directly affect execution gas, but cheaper L2 fees benefit the entire ecosystem.

---

## Optimization Checklist

- [ ] Only use `unchecked` for provably safe operations (loop counters, known bounds)
- [ ] Pack storage variables when possible
- [ ] Use `calldata` for read-only external array parameters
- [ ] Use custom errors instead of revert strings
- [ ] Cache storage reads in local variables when accessed multiple times
- [ ] Use `immutable` for values set once in constructor
- [ ] Never remove safety checks for gas savings
- [ ] Avoid assembly unless absolutely necessary
- [ ] Profile gas usage with `forge test --gas-report` before optimizing
- [ ] Prioritize security over micro-optimizations

---

## Next Steps

- [vulnerabilities.md](vulnerabilities.md) - Security patterns that may impact gas
- [modern-solidity.md](modern-solidity.md) - Transient storage for cheaper reentrancy guards
- [testing-deployment.md](testing-deployment.md) - Gas reporting with Foundry
