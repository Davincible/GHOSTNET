# Common Vulnerabilities & Prevention

Detailed patterns for preventing the most common and costly smart contract vulnerabilities.

---

## 1. Access Control (The #1 Threat)

Access control flaws allow unauthorized users to execute privileged functions. This is the most devastating vulnerability class, responsible for **$953M+ in 2024 losses**.

### Common Mistakes

- Missing function modifiers
- Using `tx.origin` for authentication
- **Using `tx.origin == msg.sender` to detect EOAs (BROKEN by EIP-7702)**
- **Using `extcodesize == 0` to detect EOAs (BROKEN by EIP-7702)**
- Simple `require(msg.sender == owner)` that gets overlooked during upgrades
- Unprotected initialization functions
- Exposed admin functions

### CRITICAL: EIP-7702 Breaks EOA Detection (Pectra Upgrade)

**EIP-7702 (May 2025) fundamentally changed Ethereum's security model.** EOAs can now delegate to smart contracts, which means:

1. **`tx.origin == msg.sender` no longer means "caller is an EOA"** - a delegated EOA passes this check while executing contract code
2. **`extcodesize == 0` no longer means "address is an EOA"** - delegated EOAs have 23 bytes of code (`0xef0100 || delegateAddress`)

**Over $5.3M was stolen via these broken assumptions in the months following the upgrade.**

```solidity
// CRITICALLY VULNERABLE: tx.origin == msg.sender check
contract VulnerableBot {
    function onlyHumans() external {
        require(tx.origin == msg.sender, "No contracts");  // BROKEN!
        // Attacker with delegated EOA bypasses this completely
    }
}

// CRITICALLY VULNERABLE: Code size check for EOA detection
contract VulnerableCheck {
    function isEOA(address addr) public view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size == 0;  // BROKEN! Delegated EOAs have 23 bytes of code
    }
    
    function restrictToEOA() external {
        require(msg.sender.code.length == 0, "No contracts");  // BROKEN!
    }
}
```

**Secure alternatives:**
- Use time delays and rate limiting instead of caller-type checks
- Use economic incentives that make attacks unprofitable
- Use EIP-712 signatures for authorization
- Accept that EOAs can now execute arbitrary code

See [eip7702-account-abstraction.md](eip7702-account-abstraction.md) for complete EIP-7702 security guidance.

### Best Practices

```solidity
// WRONG: Using tx.origin (phishing + broken by EIP-7702)
function withdraw() external {
    require(tx.origin == owner, "Not owner"); // Vulnerable!

// WRONG: Missing access control
function mint(address to, uint256 amount) external {
    _mint(to, amount); // Anyone can mint!
}

// CORRECT: Role-based access control (RBAC)
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SecureToken is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
    
    function setMinter(address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, account);
    }
}
```

### Access Control Checklist

- [ ] Every state-changing function has explicit access control
- [ ] Use OpenZeppelin's `AccessControl` or `Ownable2Step` contracts
- [ ] Never use `tx.origin` for authentication
- [ ] **Remove ALL `tx.origin == msg.sender` EOA checks** (broken by EIP-7702)
- [ ] **Remove ALL `extcodesize == 0` EOA checks** (broken by EIP-7702)
- [ ] Implement principle of least privilege
- [ ] Use multi-sig for critical operations
- [ ] Add time-locks for sensitive admin functions
- [ ] Document all privileged roles and their capabilities
- [ ] Consider `AccessControlDefaultAdminRules` for enhanced admin security

---

## 2. Reentrancy Prevention

Reentrancy occurs when external calls allow attackers to re-enter your contract before state updates complete.

### Types of Reentrancy

1. **Single-function**: Same function called recursively
2. **Cross-function**: Different functions sharing state
3. **Cross-contract**: Multiple contracts with shared state
4. **Read-only**: External calls that read stale state

### The Checks-Effects-Interactions (CEI) Pattern

```solidity
// VULNERABLE: Interaction before effects
function withdraw() external {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance");
    
    // INTERACTION first - vulnerable!
    (bool success, ) = msg.sender.call{value: balance}("");
    require(success, "Transfer failed");
    
    // EFFECT after - too late!
    balances[msg.sender] = 0;
}

// SECURE: CEI Pattern
function withdraw() external {
    // 1. CHECKS
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance");
    
    // 2. EFFECTS (update state BEFORE external call)
    balances[msg.sender] = 0;
    
    // 3. INTERACTIONS (external call LAST)
    (bool success, ) = msg.sender.call{value: balance}("");
    require(success, "Transfer failed");
}

// BEST: CEI + ReentrancyGuard
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SecureVault is ReentrancyGuard {
    mapping(address => uint256) public balances;
    
    function withdraw() external nonReentrant {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance");
        
        balances[msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
    }
}

// BEST (2025): Transient Storage ReentrancyGuard (cheaper)
import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract ModernVault is ReentrancyGuardTransient {
    // Uses EIP-1153 transient storage - ~50% gas savings
    // Requires Cancun+ EVM (default since 0.8.25)
    
    function withdraw() external nonReentrant {
        // ... same pattern
    }
}
```

### Cross-Function Reentrancy Example

```solidity
// VULNERABLE: Shared state between functions
contract Vulnerable {
    mapping(address => uint256) public balances;
    
    function transfer(address to, uint256 amount) external {
        require(balances[msg.sender] >= amount);
        balances[to] += amount;
        balances[msg.sender] -= amount; // State update after transfer logic
    }
    
    function withdraw() external {
        uint256 balance = balances[msg.sender];
        (bool success, ) = msg.sender.call{value: balance}("");
        // Attacker's fallback calls transfer() before this executes
        balances[msg.sender] = 0;
    }
}

// SECURE: All functions follow CEI
contract Secure is ReentrancyGuard {
    mapping(address => uint256) public balances;
    
    function transfer(address to, uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount; // Effect first
        balances[to] += amount;
    }
    
    function withdraw() external nonReentrant {
        uint256 balance = balances[msg.sender];
        balances[msg.sender] = 0; // Effect first
        
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
    }
}
```

### Reentrancy Checklist

- [ ] Apply CEI pattern to ALL functions with external calls
- [ ] Use `nonReentrant` modifier from OpenZeppelin
- [ ] Consider `ReentrancyGuardTransient` for gas savings (Cancun+ EVM)
- [ ] Mark `nonReentrant` functions as `external` (internal calls bypass the guard)
- [ ] Consider cross-function and cross-contract reentrancy
- [ ] Use pull payments over push payments when possible
- [ ] Be cautious with callback functions (ERC-721 `onERC721Received`, ERC-777 hooks, ERC-1363)

---

## 3. Oracle Security & Price Manipulation

Flash loan-powered oracle attacks cost DeFi **$380M+ in 2024-2025**.

### Why Spot Prices Are Dangerous

```solidity
// CATASTROPHICALLY VULNERABLE: Spot price from DEX
contract BadLending {
    IUniswapV2Pair public pair;
    
    function getPrice() internal view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        return (reserve1 * 1e18) / reserve0; // Instant manipulation via flash loan
    }
    
    function borrow(uint256 collateral) external {
        uint256 price = getPrice();
        uint256 borrowLimit = (collateral * price) / 1e18;
        // Attacker: flash loan -> manipulate pool -> borrow max -> repay loan
    }
}
```

### Secure Oracle Patterns

```solidity
// OPTION 1: Chainlink Price Feeds (Recommended)
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SecureLending {
    AggregatorV3Interface internal priceFeed;
    
    uint256 public constant MAX_STALENESS = 3600; // 1 hour
    uint256 public constant MIN_PRICE = 1e6;      // Sanity floor
    uint256 public constant MAX_PRICE = 1e30;     // Sanity ceiling
    
    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }
    
    function getPrice() public view returns (uint256) {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        
        // CRITICAL: Validate oracle data
        require(price > 0, "Invalid price: negative or zero");
        require(updatedAt > block.timestamp - MAX_STALENESS, "Stale price");
        require(answeredInRound >= roundId, "Stale round");
        require(uint256(price) >= MIN_PRICE, "Price below minimum");
        require(uint256(price) <= MAX_PRICE, "Price above maximum");
        
        return uint256(price);
    }
}

// OPTION 2: TWAP (Time-Weighted Average Price)
contract TWAPOracle {
    uint256 public constant TWAP_PERIOD = 30 minutes;
    
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public blockTimestampLast;
    uint256 public price0Average;
    
    function update() external {
        uint32 timeElapsed = uint32(block.timestamp) - blockTimestampLast;
        require(timeElapsed >= TWAP_PERIOD, "Period not elapsed");
        
        // Get cumulative prices from Uniswap
        (uint256 price0Cumulative, uint256 price1Cumulative, ) = 
            UniswapV2OracleLibrary.currentCumulativePrices(pair);
        
        // Calculate TWAP
        price0Average = (price0Cumulative - price0CumulativeLast) / timeElapsed;
        
        price0CumulativeLast = price0Cumulative;
        blockTimestampLast = uint32(block.timestamp);
    }
}

// OPTION 3: Multiple Oracle Sources with Circuit Breaker
contract MultiOracle {
    AggregatorV3Interface public chainlinkOracle;
    ITWAPOracle public twapOracle;
    
    uint256 public constant MAX_DEVIATION = 5; // 5%
    bool public circuitBreakerTripped;
    
    event CircuitBreakerTripped(uint256 chainlinkPrice, uint256 twapPrice);
    
    function getPrice() public view returns (uint256) {
        require(!circuitBreakerTripped, "Circuit breaker active");
        
        uint256 chainlinkPrice = getChainlinkPrice();
        uint256 twapPrice = twapOracle.consult();
        
        // Validate prices are within acceptable deviation
        uint256 deviation = calculateDeviation(chainlinkPrice, twapPrice);
        require(deviation <= MAX_DEVIATION, "Price deviation too high");
        
        // Use average or median
        return (chainlinkPrice + twapPrice) / 2;
    }
    
    function tripCircuitBreaker() external {
        // Called by monitoring system when anomalies detected
        circuitBreakerTripped = true;
    }
}
```

### Oracle Security Checklist

- [ ] Never use spot prices from DEX pools directly
- [ ] Use Chainlink or other decentralized oracle networks
- [ ] Implement TWAP for DEX-based pricing
- [ ] Validate oracle freshness (staleness check)
- [ ] Check for valid price ranges (min/max bounds)
- [ ] Use multiple oracle sources for critical operations
- [ ] Implement circuit breakers for price anomalies
- [ ] Consider using median of multiple sources
- [ ] Handle oracle revert gracefully (try/catch)

---

## 4. Input Validation

Never trust user input. Every external function parameter must be validated.

```solidity
// VULNERABLE: No input validation
function transfer(address to, uint256 amount) external {
    balances[msg.sender] -= amount;
    balances[to] += amount;
}

// SECURE: Comprehensive validation
function transfer(address to, uint256 amount) external {
    // Validate recipient
    require(to != address(0), "Invalid recipient: zero address");
    require(to != address(this), "Invalid recipient: self");
    
    // Validate amount
    require(amount > 0, "Invalid amount: zero");
    require(amount <= balances[msg.sender], "Insufficient balance");
    require(amount <= MAX_TRANSFER, "Amount exceeds limit");
    
    // Validate state
    require(!paused, "Contract paused");
    require(!blacklisted[msg.sender], "Sender blacklisted");
    require(!blacklisted[to], "Recipient blacklisted");
    
    balances[msg.sender] -= amount;
    balances[to] += amount;
    
    emit Transfer(msg.sender, to, amount);
}

// Using custom errors (gas efficient - 12%+ cheaper deployment)
error InvalidAddress(address addr);
error InvalidAmount(uint256 amount);
error InsufficientBalance(uint256 available, uint256 required);

function transferOptimized(address to, uint256 amount) external {
    if (to == address(0)) revert InvalidAddress(to);
    if (amount == 0) revert InvalidAmount(amount);
    if (balances[msg.sender] < amount) 
        revert InsufficientBalance(balances[msg.sender], amount);
    
    balances[msg.sender] -= amount;
    balances[to] += amount;
}
```

### Array Input Validation

```solidity
// VULNERABLE: Unbounded loops
function airdrop(address[] calldata recipients, uint256[] calldata amounts) external {
    for (uint256 i = 0; i < recipients.length; i++) {
        _transfer(recipients[i], amounts[i]); // DoS if array too large
    }
}

// SECURE: Bounded operations
uint256 public constant MAX_BATCH_SIZE = 100;

function airdrop(address[] calldata recipients, uint256[] calldata amounts) external {
    require(recipients.length == amounts.length, "Array length mismatch");
    require(recipients.length <= MAX_BATCH_SIZE, "Batch too large");
    require(recipients.length > 0, "Empty batch");
    
    for (uint256 i = 0; i < recipients.length; ) {
        require(recipients[i] != address(0), "Invalid recipient");
        require(amounts[i] > 0, "Invalid amount");
        _transfer(recipients[i], amounts[i]);
        unchecked { ++i; }
    }
}
```

---

## 5. External Call Safety

External calls can fail silently if not properly checked.

```solidity
// VULNERABLE: Unchecked low-level call
function sendEther(address payable to, uint256 amount) external {
    to.call{value: amount}(""); // Return value ignored!
}

// VULNERABLE: Unchecked token transfer
function transferToken(IERC20 token, address to, uint256 amount) external {
    token.transfer(to, amount); // Some tokens don't return bool!
}

// SECURE: Check return values
function sendEtherSafe(address payable to, uint256 amount) external {
    (bool success, ) = to.call{value: amount}("");
    require(success, "ETH transfer failed");
}

// SECURE: Use SafeERC20
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SecureTransfer {
    using SafeERC20 for IERC20;
    
    function transferToken(IERC20 token, address to, uint256 amount) external {
        token.safeTransfer(to, amount); // Handles non-standard tokens
    }
    
    // For USDT-like tokens that require zero allowance first
    function approveToken(IERC20 token, address spender, uint256 amount) external {
        token.forceApprove(spender, amount); // v4.9.0+
    }
}

// SECURE: Verify contract existence before call
function callExternal(address target, bytes memory data) external {
    require(target.code.length > 0, "Target is not a contract");
    (bool success, bytes memory returnData) = target.call(data);
    require(success, "External call failed");
}
```

---

## 6. Flash Loan Defense

Flash loans enable attackers to temporarily command massive capital for single-transaction exploits.

```solidity
// Defense: Same-block deposit/withdrawal restriction
contract FlashLoanResistant {
    mapping(address => uint256) public depositBlock;
    mapping(address => uint256) public balances;
    
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        depositBlock[msg.sender] = block.number;
    }
    
    function withdraw(uint256 amount) external {
        require(block.number > depositBlock[msg.sender], "Same block withdrawal");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        balances[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }
}

// Defense: Snapshot-based governance
contract FlashLoanResistantGovernance {
    mapping(address => uint256) public votingPowerSnapshot;
    uint256 public snapshotBlock;
    
    function createProposal() external {
        // Snapshot voting power at proposal creation
        snapshotBlock = block.number;
    }
    
    function vote(uint256 proposalId) external {
        // Use historical balance, not current
        uint256 votingPower = getBalanceAt(msg.sender, snapshotBlock);
        require(votingPower > 0, "No voting power at snapshot");
        // ... voting logic
    }
}
```

---

## Next Steps

- [patterns-upgrades.md](patterns-upgrades.md) - Secure design patterns and upgrade safety
- [testing-deployment.md](testing-deployment.md) - Security testing and tools
- [reference.md](reference.md) - Pre-deployment checklists
