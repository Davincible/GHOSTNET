# Design Patterns & Upgradeable Contracts

Secure design patterns, upgradeable contract architectures, and cross-chain security considerations.

---

## Part 1: Secure Design Patterns

### Pull Over Push Payments

Never send ETH to untrusted addresses in a loop. Let users withdraw their own funds.

```solidity
// VULNERABLE: Push pattern (DoS risk)
function distributeRewards(address[] calldata winners) external {
    for (uint256 i = 0; i < winners.length; i++) {
        (bool success, ) = payable(winners[i]).call{value: reward}("");
        require(success); // One failure blocks all
    }
}

// SECURE: Pull pattern
contract PullPayment is ReentrancyGuard {
    mapping(address => uint256) public pendingWithdrawals;
    
    function _asyncTransfer(address dest, uint256 amount) internal {
        pendingWithdrawals[dest] += amount;
    }
    
    function withdrawPayment() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending payment");
        
        pendingWithdrawals[msg.sender] = 0;  // Effect first
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
    }
    
    function distributeRewards(address[] calldata winners, uint256 amount) external {
        for (uint256 i = 0; i < winners.length; ) {
            _asyncTransfer(winners[i], amount);
            unchecked { ++i; }
        }
    }
}
```

### Emergency Stop (Circuit Breaker)

```solidity
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract EmergencyStop is Pausable, Ownable2Step {
    constructor() Ownable(msg.sender) {}
    
    function deposit() external payable whenNotPaused {
        // Normal operation
    }
    
    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        // Normal operation
    }
    
    // Emergency functions
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // Emergency withdrawal (even when paused)
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");
    }
}
```

### Rate Limiting

```solidity
contract RateLimited {
    struct RateLimit {
        uint256 lastAction;
        uint256 actionCount;
    }
    
    mapping(address => RateLimit) public rateLimits;
    
    uint256 public constant MAX_ACTIONS_PER_HOUR = 10;
    uint256 public constant RATE_LIMIT_WINDOW = 1 hours;
    
    modifier rateLimit() {
        RateLimit storage limit = rateLimits[msg.sender];
        
        if (block.timestamp - limit.lastAction >= RATE_LIMIT_WINDOW) {
            limit.actionCount = 0;
            limit.lastAction = block.timestamp;
        }
        
        require(limit.actionCount < MAX_ACTIONS_PER_HOUR, "Rate limit exceeded");
        limit.actionCount++;
        _;
    }
    
    function sensitiveAction() external rateLimit {
        // Protected action
    }
}
```

### Commitment Scheme (Commit-Reveal)

For sensitive operations that could be front-run:

```solidity
contract CommitReveal {
    struct Commitment {
        bytes32 hash;
        uint256 block;
        bool revealed;
    }
    
    mapping(address => Commitment) public commitments;
    uint256 public constant REVEAL_WINDOW = 256; // blocks
    
    function commit(bytes32 hash) external {
        commitments[msg.sender] = Commitment({
            hash: hash,
            block: block.number,
            revealed: false
        });
    }
    
    function reveal(uint256 value, bytes32 salt) external {
        Commitment storage c = commitments[msg.sender];
        
        require(!c.revealed, "Already revealed");
        require(block.number > c.block, "Same block reveal");
        require(block.number <= c.block + REVEAL_WINDOW, "Reveal window expired");
        require(keccak256(abi.encodePacked(value, salt)) == c.hash, "Invalid reveal");
        
        c.revealed = true;
        
        // Execute action with revealed value
        _executeAction(value);
    }
}
```

### Two-Step Ownership Transfer

```solidity
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract SecureOwnable is Ownable2Step {
    constructor() Ownable(msg.sender) {}
    
    // Ownership transfer requires:
    // 1. Current owner calls transferOwnership(newOwner)
    // 2. New owner calls acceptOwnership()
    // This prevents accidental transfer to wrong address
}
```

### AccessControlDefaultAdminRules

Enhanced security for the DEFAULT_ADMIN_ROLE:

```solidity
import "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

contract SecureAccessControl is AccessControlDefaultAdminRules {
    constructor()
        AccessControlDefaultAdminRules(
            3 days,      // Initial delay for admin transfers
            msg.sender   // Initial admin
        )
    {}
    
    // Admin transfers now require:
    // 1. pendingDefaultAdmin() to be set
    // 2. Wait for delay to pass
    // 3. New admin accepts the role
}
```

---

## Part 2: Upgradeable Contract Security

### UUPS vs Transparent Proxy

| Aspect | UUPS | Transparent Proxy |
|--------|------|-------------------|
| Upgrade Logic | In implementation | In proxy |
| Gas Cost | Lower deployment | Higher deployment |
| Risk | Can lose upgradeability | Safer |
| Recommended | Yes (by OpenZeppelin) | Legacy |

### UUPS Implementation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyContractV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // Prevent implementation initialization
    }
    
    function initialize(uint256 _value) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        value = _value;
    }
    
    function setValue(uint256 _value) external onlyOwner {
        value = _value;
    }
    
    // CRITICAL: Must implement this with proper access control
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

// V2 - Adding new functionality
contract MyContractV2 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;
    uint256 public newValue; // New state variable - MUST be at end
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(uint256 _value) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        value = _value;
    }
    
    function setNewValue(uint256 _newValue) external onlyOwner {
        newValue = _newValue;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
```

### Mandatory Proxy Initialization (v5.5.0 Breaking Change)

**CRITICAL:** ERC1967Proxy and TransparentUpgradeableProxy now **revert** if deployed without initialization:

```solidity
// OLD: Could deploy without initialization
new ERC1967Proxy(implementation, "");  // Was silent
// NOW: Reverts with ERC1967ProxyUninitialized

// CORRECT: Always provide initialization data
new ERC1967Proxy(
    implementation,
    abi.encodeCall(Implementation.initialize, (param1, param2))
);

// Exception: Override _unsafeAllowUninitialized() to return true
// (NOT RECOMMENDED - defeats purpose of protection)
```

### Proxy Security Checklist

- [ ] **Never use constructors** in implementation contracts
- [ ] Always use `initializer` modifier on initialization functions
- [ ] Call `_disableInitializers()` in implementation constructor
- [ ] **Initialize implementation contracts** immediately after deployment
- [ ] New state variables must be added at the END (storage layout)
- [ ] Never remove or reorder existing state variables
- [ ] Never change types of existing state variables
- [ ] Use ERC-7201 namespaced storage for complex inheritance
- [ ] Protect the `_authorizeUpgrade` function properly
- [ ] Test upgrades on testnets thoroughly
- [ ] Use timelock for production upgrades
- [ ] Use OpenZeppelin Upgrade Plugins for automated checks
- [ ] **Provide init data to proxy deployment** (v5.5.0+)

### ERC-7201 Namespaced Storage

```solidity
// Modern approach - ERC-7201 namespaced storage
contract MyContract {
    /// @custom:storage-location erc7201:mycontract.main
    struct MainStorage {
        uint256 value;
        mapping(address => uint256) balances;
    }
    
    // Computed: keccak256(abi.encode(uint256(keccak256("mycontract.main")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MAIN_STORAGE_LOCATION = 0x...;
    
    function _getMainStorage() private pure returns (MainStorage storage $) {
        assembly { $.slot := MAIN_STORAGE_LOCATION }
    }
}

// Legacy approach - storage gaps (still valid but less flexible)
contract MyContractLegacy {
    uint256 public value;
    
    // Reserve 50 slots for future upgrades
    uint256[50] private __gap;
}
```

### Initializable Updates

**Import Path Changes (v5.5.0):**
```solidity
// Initializable and UUPSUpgradeable are no longer transpiled
// Update imports from:
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// To (recommended):
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// Alias exists in upgradeable package but will be removed in v6.0
```

**Custom Storage Slot (v5.3.0):**
```solidity
// New: Can customize Initializable storage slot
function _initializableStorageSlot() internal pure override returns (bytes32) {
    return keccak256("custom.initializable.slot");
}
```

---

## Part 3: Cross-Chain Security

### CAIP Identifiers (v5.2.0)

Chain-agnostic identifiers for cross-chain safety:

```solidity
import "@openzeppelin/contracts/utils/CAIP2.sol";
import "@openzeppelin/contracts/utils/CAIP10.sol";

// CAIP-2: Chain identification
// Format: "namespace:reference" (e.g., "eip155:1" for Ethereum mainnet)
string memory chainId = CAIP2.format("eip155", "1");
(string memory namespace, string memory reference) = CAIP2.parse(chainId);

// CAIP-10: Account identification  
// Format: "chainId:address" (e.g., "eip155:1:0x123...")
string memory accountId = CAIP10.format("eip155:1", address(this));
(string memory chain, address account) = CAIP10.parse(accountId);
```

### ERC-7786 Cross-Chain Messaging (v5.5.0)

```solidity
import "@openzeppelin/contracts/crosschain/IERC7786.sol";
import "@openzeppelin/contracts/crosschain/ERC7786Recipient.sol";

// Generic cross-chain message recipient
contract MyCrossChainReceiver is ERC7786Recipient {
    mapping(string => bool) public trustedChains;
    mapping(bytes => bool) public trustedSenders;
    
    function _processMessage(
        bytes32 messageId,
        string calldata sourceChain,
        bytes calldata sender,
        bytes calldata message
    ) internal override {
        // CRITICAL: Validate source chain and sender
        require(trustedChains[sourceChain], "Untrusted chain");
        require(trustedSenders[sender], "Untrusted sender");
        
        // Process cross-chain message
        _handleMessage(message);
    }
}
```

### InteroperableAddress (v5.5.0 - ERC-7930)

```solidity
import "@openzeppelin/contracts/utils/InteroperableAddress.sol";

// Format and parse ERC-7930 interoperable addresses
// for cross-chain compatibility
```

### Cross-Chain Security Checklist

- [ ] Validate source chain in all cross-chain message handlers
- [ ] Maintain whitelist of trusted sender addresses per chain
- [ ] Use CAIP identifiers for unambiguous chain/account references
- [ ] Implement replay protection for cross-chain messages
- [ ] Consider finality differences between chains
- [ ] Handle bridge failures gracefully
- [ ] Test cross-chain scenarios with multiple bridge providers

---

## Next Steps

- [testing-deployment.md](testing-deployment.md) - Testing upgrade scenarios
- [reference.md](reference.md) - Pre-deployment checklists for upgradeable contracts
- [vulnerabilities.md](vulnerabilities.md) - Upgrade-specific vulnerabilities
