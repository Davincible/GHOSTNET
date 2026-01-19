# Testing & Deployment

Comprehensive testing strategies, security tooling, and deployment best practices.

---

## Part 1: Testing Framework

### Framework Comparison

| Framework | Language | Speed | Fuzzing | Best For |
|-----------|----------|-------|---------|----------|
| **Foundry** | Solidity | Fastest (5x) | Built-in | Production, auditing |
| Hardhat | JS/TS | Moderate | Plugins | Full-stack dApps |
| Brownie | Python | Slow | Via Hypothesis | Python devs |

### Foundry Testing Essentials

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "../src/MyContract.sol";

contract MyContractTest is Test {
    MyContract public target;
    address public attacker = makeAddr("attacker");
    address public user = makeAddr("user");
    
    function setUp() public {
        target = new MyContract();
        vm.deal(user, 100 ether);
    }
    
    // Unit test
    function test_Deposit() public {
        vm.prank(user);
        target.deposit{value: 1 ether}();
        assertEq(target.balances(user), 1 ether);
    }
    
    // Fuzz test - Foundry generates random inputs
    function testFuzz_Deposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 100 ether);
        
        vm.prank(user);
        target.deposit{value: amount}();
        assertEq(target.balances(user), amount);
    }
    
    // Invariant test
    function invariant_TotalSupplyMatchesBalances() public view {
        // This runs after random sequences of function calls
        assertGe(address(target).balance, target.totalDeposits());
    }
    
    // Reentrancy attack simulation
    function test_ReentrancyAttack() public {
        AttackerContract attackerContract = new AttackerContract(target);
        vm.deal(address(attackerContract), 1 ether);
        
        // Attack should fail if protected
        vm.expectRevert();
        attackerContract.attack();
    }
    
    // EIP-7702 delegation test
    function test_DelegatedEOACannotBypassChecks() public {
        // Test that security measures work even with delegated EOAs
        // Use vm.etch to simulate delegated code
        
        address delegatedEOA = makeAddr("delegated");
        vm.deal(delegatedEOA, 10 ether);
        
        // Simulate EIP-7702 delegation by etching code
        bytes memory delegateCode = type(MaliciousDelegate).runtimeCode;
        vm.etch(delegatedEOA, delegateCode);
        
        // Verify contract still protects against attack
        vm.prank(delegatedEOA);
        // ... test security measures
    }
    
    // Account Abstraction test
    function test_OnlyEntryPointCanExecute() public {
        address randomCaller = makeAddr("random");
        
        vm.prank(randomCaller);
        vm.expectRevert("Only EntryPoint or self");
        smartAccount.execute(address(0), 0, "");
    }
}

contract AttackerContract {
    MyContract public target;
    
    constructor(MyContract _target) {
        target = _target;
    }
    
    function attack() external {
        target.deposit{value: 1 ether}();
        target.withdraw(1 ether);
    }
    
    receive() external payable {
        if (address(target).balance >= 1 ether) {
            target.withdraw(1 ether); // Attempt reentrancy
        }
    }
}
```

---

## Part 2: Security Tooling

### Slither (Static Analysis)

Fast, low false-positive static analyzer. Run on every PR.

```bash
# Basic scan
slither .

# JSON output for CI
slither . --json slither-report.json

# Exclude informational/low
slither . --exclude-informational --exclude-low

# Single file in Foundry project
slither src/MyContract.sol
```

**Config file (`slither.config.json`):**

```json
{
  "detectors_to_exclude": "naming-convention,solc-version",
  "exclude_informational": true,
  "exclude_low": false,
  "exclude_medium": false,
  "exclude_high": false,
  "fail_on": "high"
}
```

### Mythril (Symbolic Execution)

Deeper analysis for critical paths. Slower but catches complex bugs.

```bash
# Basic analysis
myth analyze src/MyContract.sol --solc-json mythril.config.json

# Longer execution for thorough analysis
myth analyze src/MyContract.sol --execution-timeout 300

# Docker alternative
docker run -v $(pwd):/tmp mythril/myth analyze /tmp/src/MyContract.sol
```

**Config (`mythril.config.json`):**

```json
{
  "remappings": [
    "forge-std/=lib/forge-std/src/",
    "@openzeppelin/=lib/openzeppelin-contracts/"
  ],
  "optimizer": {
    "enabled": true,
    "runs": 200
  }
}
```

### Medusa (Parallel Fuzzing)

When Foundry's built-in fuzzer isn't enough. Trail of Bits' scalable fuzzer.

```bash
# Install
go install github.com/crytic/medusa@latest

# Initialize config
medusa init

# Run fuzzing campaign
medusa fuzz
```

### Security Tools Checklist

**Static Analysis (Run on every commit):**
- [ ] **Slither** - 93+ vulnerability detectors, fail CI on high severity
- [ ] **Aderyn** - Rust-based, fast AST analysis
- [ ] **Solhint** - Linting and style guide
- [ ] Maintain a small, reviewed suppression list with justifications

**Dynamic Analysis:**
- [ ] **Foundry fuzzing** - Built-in, fast, property-based
- [ ] **Foundry invariant testing** - Stateful sequence testing
- [ ] **Echidna** - Specialized invariant falsification
- [ ] **Medusa** - Parallel fuzzing

**Formal Verification (When TVL/criticality justifies it):**
- [ ] **Certora** - Mathematical proofs
- [ ] **Halmos** - Symbolic execution
- [ ] **Solidity SMTChecker** - Built-in compiler

**AI-Assisted (First-pass only):**
- [ ] **Olympix** - GPT-4 based initial scan
- [ ] **Hexens.ai** - Automated vulnerability detection
- [ ] Never rely solely on AI tools

---

## Part 3: CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/security.yml
name: Security Checks
on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1
      
      - name: Run Slither
        uses: crytic/slither-action@v0.4.0
        continue-on-error: false  # Fail on high severity
        
      - name: Compile
        run: forge build
        
      - name: Quick Fuzz (PR)
        run: forge test --fuzz-runs 1000
        
      - name: Invariant Tests
        run: forge test --match-contract Invariant
        
  deep-fuzz:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: foundry-rs/foundry-toolchain@v1
      - name: Overnight Deep Fuzz
        run: forge test --fuzz-runs 100000
```

---

## Part 4: Deployment Strategy

### Canary Deployment Pattern

```solidity
contract GradualRollout {
    uint256 public depositCap = 100 ether;  // Start small
    uint256 public totalDeposits;
    bool public allowlistOnly = true;
    mapping(address => bool) public allowlist;
    
    function deposit() external payable {
        if (allowlistOnly) {
            require(allowlist[msg.sender], "Not on allowlist");
        }
        require(totalDeposits + msg.value <= depositCap, "Cap reached");
        
        totalDeposits += msg.value;
        // ... deposit logic
    }
    
    // Gradual rollout functions (timelock protected)
    function increaseDepositCap(uint256 newCap) external onlyTimelock {
        require(newCap > depositCap, "Can only increase");
        depositCap = newCap;
        emit CapIncreased(newCap);
    }
    
    function disableAllowlist() external onlyTimelock {
        allowlistOnly = false;
        emit AllowlistDisabled();
    }
}
```

### Deployment Checklist

- [ ] Deploy with conservative caps (start at 1% of target TVL)
- [ ] Enable allowlist for initial users (trusted testers)
- [ ] Monitor for 1-2 weeks before increasing caps
- [ ] Gradual cap increases (2x max per week)
- [ ] Full public access only after monitoring period

### Key Compromise Resilience

Design so that **one key compromise is not catastrophic**:

```solidity
contract ResilientProtocol {
    address public multisig;      // 3-of-5 multisig
    uint256 public timelockDelay = 2 days;
    
    mapping(bytes32 => uint256) public pendingActions;
    
    // Step 1: Propose (requires multisig)
    function proposeUpgrade(address newImpl) external onlyMultisig {
        bytes32 actionId = keccak256(abi.encode("upgrade", newImpl));
        pendingActions[actionId] = block.timestamp + timelockDelay;
        emit UpgradeProposed(newImpl, block.timestamp + timelockDelay);
    }
    
    // Step 2: Execute (after timelock, still requires multisig)
    function executeUpgrade(address newImpl) external onlyMultisig {
        bytes32 actionId = keccak256(abi.encode("upgrade", newImpl));
        require(pendingActions[actionId] != 0, "Not proposed");
        require(block.timestamp >= pendingActions[actionId], "Timelock active");
        
        delete pendingActions[actionId];
        _upgrade(newImpl);
    }
    
    // Emergency: Can pause immediately, but cannot upgrade
    function emergencyPause() external onlyMultisig {
        _pause();  // Immediate, no timelock needed for safety
    }
}
```

---

## Part 5: Post-Deployment Monitoring

Set up alerts for abnormal events:

```solidity
// Emit events for ALL security-relevant actions
event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
event Upgraded(address indexed implementation);
event Paused(address account);
event Unpaused(address account);
event LargeWithdrawal(address indexed user, uint256 amount);

// In your withdrawal function:
function withdraw(uint256 amount) external nonReentrant {
    // ... validation
    
    if (amount > LARGE_WITHDRAWAL_THRESHOLD) {
        emit LargeWithdrawal(msg.sender, amount);
    }
    
    // ... transfer
}
```

### Monitoring Tools

- **Tenderly** - Real-time transaction monitoring
- **OpenZeppelin Defender** - Automated response
- **Forta** - Threat detection network
- **Custom alerting** - The Graph + Discord/Telegram webhooks

---

## Next Steps

- [reference.md](reference.md) - Complete pre-deployment checklist
- [vulnerabilities.md](vulnerabilities.md) - Testing for specific vulnerability types
- [environment-setup.md](environment-setup.md) - CI/CD configuration details
