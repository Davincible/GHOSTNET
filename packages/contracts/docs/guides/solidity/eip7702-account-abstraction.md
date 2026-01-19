# EIP-7702 & Account Abstraction Security

Critical security considerations for EIP-7702 delegated EOAs and ERC-4337/ERC-7579 smart accounts.

---

## Part 1: EIP-7702 Security (CRITICAL)

### The Broken Assumption

**EIP-7702 (Pectra upgrade, May 2025) fundamentally changes Ethereum's security model.**

Previously, these patterns were safe assumptions:
- `tx.origin == msg.sender` -> Caller is an EOA
- `address.code.length == 0` -> Address is an EOA
- EOAs cannot execute complex logic
- EOAs cannot be reentered

**ALL of these assumptions are now BROKEN.**

EIP-7702 allows EOAs to delegate execution to smart contracts. An EOA can now:
- Execute arbitrary contract logic as itself
- Have code attached temporarily or persistently
- Trigger callbacks (ERC-721, ERC-777, ERC-1363)
- Be used in complex attacks

### Vulnerable Patterns to Eliminate

```solidity
// CRITICALLY VULNERABLE: tx.origin == msg.sender check
contract VulnerableBot {
    // This pattern was used to prevent contract callers
    // It NO LONGER WORKS after EIP-7702!
    
    function onlyHumans() external {
        require(tx.origin == msg.sender, "No contracts");  // BROKEN!
        // Attacker with delegated EOA bypasses this
    }
}

// CRITICALLY VULNERABLE: Code size check
contract VulnerableCheck {
    function isEOA(address addr) public view returns (bool) {
        return addr.code.length == 0;  // BROKEN!
        // Delegated EOAs have code but still pass this in some contexts
    }
    
    function restrictToEOA() external {
        require(msg.sender.code.length == 0, "No contracts");  // BROKEN!
    }
}

// VULNERABLE: Assuming EOAs can't trigger callbacks
contract VulnerableNFT {
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        // This assumes only contracts need onERC721Received callback
        if (to.code.length > 0) {
            // Call onERC721Received
        }
        // PROBLEM: Delegated EOAs may need/trigger callbacks too!
    }
}
```

### Secure Patterns Post-EIP-7702

```solidity
// CORRECT: Don't rely on caller type for security
contract SecureProtocol {
    // Instead of blocking contracts, use proper security measures:
    
    // 1. Use reentrancy guards
    // 2. Follow CEI pattern
    // 3. Rate limit with time delays
    // 4. Use economic incentives that make attacks unprofitable
    
    mapping(address => uint256) public lastAction;
    uint256 public constant MIN_DELAY = 1; // blocks
    
    function protectedAction() external nonReentrant {
        // Time-based rate limiting (works regardless of caller type)
        require(
            block.number > lastAction[msg.sender] + MIN_DELAY,
            "Too soon"
        );
        lastAction[msg.sender] = block.number;
        
        // ... action logic with CEI pattern
    }
}

// CORRECT: Handle all addresses as potentially having code
contract SafeTokenTransfer {
    function safeTransfer(address to, uint256 amount) external {
        // Always handle potential code execution on recipient
        // Don't assume EOAs are "simple"
        
        balances[msg.sender] -= amount;  // Effects first
        balances[to] += amount;
        
        // If using callbacks, be prepared for any address to have code
    }
}

// CORRECT: Replace bot/MEV protection patterns
contract FlashLoanResistant {
    // Don't use tx.origin checks - use economic/time-based protections
    
    mapping(address => uint256) public depositTimestamp;
    
    function deposit() external payable {
        depositTimestamp[msg.sender] = block.timestamp;
        balances[msg.sender] += msg.value;
    }
    
    function withdraw() external {
        // Time delay makes flash loan attacks uneconomical
        require(
            block.timestamp >= depositTimestamp[msg.sender] + 1,
            "Minimum delay required"
        );
        // ...
    }
}
```

### EIP-7702 Security Checklist

- [ ] **Remove ALL `tx.origin == msg.sender` checks** - they no longer work
- [ ] **Remove ALL `address.code.length == 0` EOA checks** - unreliable
- [ ] **Review reentrancy protection** - delegated EOAs can reenter
- [ ] **Review callback assumptions** - EOAs may now have callbacks
- [ ] **Update bot/MEV protection** - use time delays, not caller checks
- [ ] **Test with delegated EOAs** - add test cases for 7702 scenarios
- [ ] **Audit all assumptions** about EOA behavior

### Real-World EIP-7702 Attacks (2025)

**Phishing via Delegation:** Over $12M stolen through fake DeFi interfaces that tricked users into signing EIP-7702 delegation authorizations. Attackers then used delegated authority to drain wallets.

**Lessons:**
1. Never sign authorization tuples you don't understand
2. Wallet UIs should prominently flag 7702 approvals
3. Use only audited, purpose-built 7702 delegation contracts
4. Treat any 7702 delegation as equivalent to giving away your private key

---

## Part 2: EIP-7702 Practical Implementation

### When to Use EIP-7702 vs Pure ERC-4337

| Use Case | Best Choice |
|----------|-------------|
| Instant smart account UX for existing EOAs | EIP-7702 |
| Consistent addresses across chains | EIP-7702 |
| Batch approve+swap in single transaction | EIP-7702 |
| Full programmability from day one | Pure ERC-4337 |
| Complex recovery/multi-sig policies | Pure ERC-4337 |
| Parallel transactions via multidimensional nonces | Pure ERC-4337 |

**Recommended**: Combine both - EIP-7702 transforms EOA into smart account, then use ERC-4337 bundlers for relaying and gas sponsorship.

### Toolchain Setup

```bash
# Solidity 0.8.30+ defaults to Prague EVM (use 0.8.33 for latest fixes)
solc --version  # Should be 0.8.33

# Foundry
foundryup && forge --version
```

```toml
# foundry.toml
[profile.default]
evm_version = "prague"
solc_version = "0.8.33"
```

```bash
# Install viem for best EIP-7702 DX
npm install viem@latest
```

### Basic EIP-7702 Transaction (viem)

```typescript
import { createWalletClient, http, encodeFunctionData } from "viem";
import { mainnet } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";

const eoa = privateKeyToAccount(process.env.EOA_PK as `0x${string}`);
const client = createWalletClient({
  account: eoa,
  chain: mainnet,
  transport: http(),
});

// Sign authorization - EOA will delegate to this contract
const authorization = await client.signAuthorization({
  contractAddress: "0xYourBatchExecutorContract",
  // CRITICAL: If EOA itself sends the tx, use executor: 'self'
  // This handles nonce math automatically
  executor: "self",
});

// Send type-4 transaction
const hash = await client.sendTransaction({
  to: eoa.address, // Transaction TO is the EOA itself
  authorizationList: [authorization],
  data: encodeFunctionData({
    abi: batchExecutorAbi,
    functionName: "executeBatch",
    args: [[
      { target: tokenAddress, value: 0n, data: approveCalldata },
      { target: dexAddress, value: 0n, data: swapCalldata },
    ]],
  }),
});
```

### Minimal Delegate Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

contract BatchCallDelegator {
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    function executeBatch(Call[] calldata calls) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, ) = calls[i].target.call{value: calls[i].value}(
                calls[i].data
            );
            require(success, "Call failed");
        }
    }

    // Revoke delegation by sending another 7702 tx
    // with authorization to address(0)
}
```

### Gas Sponsorship Flow (Relayer Pattern)

```typescript
// Relayer sponsors gas for user's 7702 transaction
const relayer = privateKeyToAccount(process.env.RELAYER_PK);
const user = privateKeyToAccount(process.env.USER_PK);

// User signs authorization (no executor: 'self' - relayer is sending)
const authorization = await user.signAuthorization({
  contractAddress: delegateContract,
});

// Relayer broadcasts and pays gas
const relayerClient = createWalletClient({
  account: relayer,
  chain: mainnet,
  transport: http(),
});

const hash = await relayerClient.sendTransaction({
  to: user.address,
  authorizationList: [authorization],
  data: batchCallData,
});
```

### Cross-Chain Delegation (Careful!)

```typescript
// Authorization can set chainId: 0 to be valid across all EVM chains
const authorization = await client.signAuthorization({
  contractAddress: delegateContract,
  chainId: 0, // Valid on ALL chains - DANGEROUS
});
```

**Risk**: If you deploy the same delegate contract to different chains, one authorization works everywhere. Only use when you explicitly want cross-chain behavior.

---

## Part 3: EIP-7702 Critical Gotchas

### 1. Nonce Math for Self-Sponsored Transactions

When the EOA itself broadcasts the 7702 transaction, Ethereum increments the nonce *before* validating the authorization. Your authorization nonce must be `tx.nonce + 1`.

```typescript
// Viem handles this with executor: 'self'
// If rolling your own:
const txNonce = await client.getTransactionCount({ address: eoa.address });
const authorizationNonce = txNonce + 1n;
```

### 2. NFT/Token Transfers to Delegated EOAs Can Fail

ERC-721 `safeTransferFrom` and ERC-777 check for code and call receiver hooks. A delegated EOA is seen as a contract. If the delegate doesn't implement `onERC721Received`, the transfer reverts.

**Solution**: Implement receiver hooks in your delegate contract:

```solidity
contract SafeDelegator {
    function onERC721Received(
        address, address, uint256, bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    function onERC1155Received(
        address, address, uint256, uint256, bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
```

### 3. Private Key Still Has God Mode

EIP-7702 delegation is overridable. The EOA's private key can always submit a new 7702 transaction to change or revoke delegation. Social recovery, spending limits, etc. implemented via delegation can be bypassed by the original key.

**This is fundamental - not a bug, but a security model shift.** Don't advertise 7702-based features as "secure against key compromise."

### 4. Storage Collision on Re-Delegation

If a user switches delegate contracts, storage layouts may conflict. **Use EIP-7201 namespaced storage**:

```solidity
// Use unique storage slots per implementation
bytes32 constant MY_STORAGE_LOCATION = 
    keccak256(abi.encode(uint256(keccak256("myapp.storage.v1")) - 1)) 
    & ~bytes32(uint256(0xff));

function _getMyStorage() private pure returns (MyStorage storage $) {
    assembly { $.slot := MY_STORAGE_LOCATION }
}
```

### 5. `EXTCODESIZE` Returns 23 Bytes for Delegated EOAs

Pre-7702, `extcodesize == 0` meant EOA. Now, a delegated EOA has code `0xef0100 || address` (23 bytes).

```solidity
// This check is BROKEN:
function isEOA(address account) internal view returns (bool) {
    uint256 size;
    assembly { size := extcodesize(account) }
    return size == 0; // Delegated EOAs have 23 bytes of code!
}
```

---

## Part 4: EIP-7702 Production Checklist

### Smart Contract Updates

- [ ] Audit all `tx.origin` usage - replace with signatures or remove
- [ ] Audit all `extcodesize` checks - they no longer identify EOAs
- [ ] Test token transfers to addresses that might have delegation
- [ ] Implement EIP-7201 namespaced storage for delegate contracts
- [ ] Add receiver hooks (`onERC721Received`, etc.) to delegate contracts

### Toolchain

- [ ] Update Solidity to 0.8.33 (0.8.30 minimum for Prague)
- [ ] Update Foundry/Hardhat configs to `prague` EVM version
- [ ] Update viem/ethers to latest versions
- [ ] Update node infrastructure to Pectra-compatible client versions

### Testing

- [ ] Add test cases for delegated EOA scenarios
- [ ] Test nonce handling for self-sponsored transactions
- [ ] Test re-delegation storage collision scenarios
- [ ] Test NFT/token transfers to delegated addresses

---

## Part 5: ERC-4337 Smart Account Security

ERC-4337 enables smart contract wallets ("smart accounts") without protocol changes. This introduces entirely new attack surfaces.

### Architecture Overview

```
User -> UserOperation -> Bundler -> EntryPoint Contract -> Smart Account
                                         |
                                    Paymaster (optional)
```

**Critical Components:**
- **UserOperation**: Pseudo-transaction containing intent + signature
- **Bundler**: Off-chain actor that submits UserOps to EntryPoint
- **EntryPoint**: Singleton contract that validates and executes UserOps
- **Smart Account**: User's contract wallet implementing validation logic
- **Paymaster**: Optional sponsor for gas fees

### Secure Implementation

```solidity
// SECURE: ERC-4337 Account Implementation
import "@openzeppelin/contracts/account/Account.sol";
import "@openzeppelin/contracts/account/utils/draft-ERC4337Utils.sol";

contract SecureSmartAccount is Account {
    using ERC4337Utils for PackedUserOperation;
    
    address public owner;
    
    // CRITICAL: Validate the EntryPoint is the official one
    constructor(IEntryPoint _entryPoint, address _owner) Account(_entryPoint) {
        owner = _owner;
    }
    
    // CRITICAL: Override _validateUserOp with proper signature verification
    // NOTE: In v5.5.0+, signature is now a parameter
    function _validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        bytes calldata signature = userOp.signature;
        
        // Recover signer from signature
        address signer = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(userOpHash),
            signature
        );
        
        // CRITICAL: Return SIG_VALIDATION_FAILED, don't revert
        if (signer != owner) {
            return SIG_VALIDATION_FAILED;
        }
        
        return 0; // Valid - no time restrictions
    }
    
    // CRITICAL: Gate all sensitive functions to EntryPoint
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable virtual {
        require(
            msg.sender == address(entryPoint()) || msg.sender == address(this),
            "Only EntryPoint or self"
        );
        _call(target, value, data);
    }
    
    // Batch execution
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external payable {
        require(
            msg.sender == address(entryPoint()) || msg.sender == address(this),
            "Only EntryPoint or self"
        );
        require(
            targets.length == values.length && values.length == datas.length,
            "Length mismatch"
        );
        
        for (uint256 i = 0; i < targets.length; i++) {
            _call(targets[i], values[i], datas[i]);
        }
    }
    
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
```

### ERC-4337 Security Vulnerabilities

| Vulnerability | Impact | Mitigation |
|--------------|--------|------------|
| Missing EntryPoint check | Unauthorized execution | Always verify `msg.sender == entryPoint()` |
| Reverting in validateUserOp | DoS for bundlers | Return `SIG_VALIDATION_FAILED` instead |
| Weak signature validation | Account takeover | Use OpenZeppelin's ECDSA library |
| Missing nonce validation | Replay attacks | EntryPoint handles nonces, but verify |
| Paymaster trust | Gas draining | Validate paymaster reputation |

### ERC-4337 Security Checklist

- [ ] All external functions check `msg.sender == entryPoint()` or use proper access control
- [ ] `validateUserOp` returns `SIG_VALIDATION_FAILED` (not revert) for invalid signatures
- [ ] Nonces are properly managed through EntryPoint's keyed nonce system
- [ ] Paymaster interactions are validated and don't allow draining
- [ ] Gas limits in validation phase are respected (cannot access external state freely)
- [ ] Use OpenZeppelin's `ERC4337Utils` for UserOperation parsing
- [ ] Account implements `IAccount` interface correctly

---

## Part 6: ERC-7579 Modular Smart Accounts

ERC-7579 standardizes modular account architecture with plug-and-play modules.

### Module Types and Security Risks

| Module Type | ID | Purpose | Security Risk |
|------------|-----|---------|---------------|
| Validator | 1 | Signature/auth verification | Compromised validator = account takeover |
| Executor | 2 | Execute transactions on behalf | Unauthorized actions |
| Fallback | 3 | Handle unknown function calls | Unexpected behavior |
| Hook | 4 | Pre/post transaction logic | **DoS via malicious hooks** |

```solidity
// SECURE: ERC-7579 Account Implementation
import "@openzeppelin/contracts/account/AccountERC7579.sol";

contract ModularAccount is AccountERC7579 {
    mapping(address => bool) public trustedModules;
    
    constructor(IEntryPoint _entryPoint) AccountERC7579(_entryPoint) {}
    
    // CRITICAL: Module installation needs protection
    function installModule(
        uint256 moduleType,
        address module,
        bytes calldata initData
    ) external override {
        // Only allow from EntryPoint or self
        require(
            msg.sender == address(entryPoint()) || msg.sender == address(this),
            "Unauthorized"
        );
        
        // Validate module is from trusted registry
        require(trustedModules[module], "Untrusted module");
        
        // CRITICAL: For fallback modules, initData must be >= 4 bytes (v5.5.0+)
        if (moduleType == 3) { // Fallback
            require(initData.length >= 4, "Fallback data too short");
        }
        
        super.installModule(moduleType, module, initData);
    }
    
    // Add module to whitelist (owner-only)
    function addTrustedModule(address module) external onlyOwner {
        trustedModules[module] = true;
    }
}
```

### Hook Module Dangers

```solidity
// WARNING: Malicious hooks can DoS your entire account!

// A hook that always reverts will block ALL transactions
contract MaliciousHook is IHook {
    function preCheck(
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes memory) {
        revert("Blocked!"); // Account is now unusable
    }
    
    function postCheck(bytes calldata) external pure {
        revert("Blocked!");
    }
}

// MITIGATION: Only install hooks from audited sources
// Consider hook timeout/removal mechanisms
```

### ERC-7579 Breaking Change (v5.5.0)

```solidity
// Fallback module init/deInit data must now be >= 4 bytes
// (matching the selector being registered)

// OLD: Empty data was treated as 0x00000000
installModule(3, fallbackModule, "");

// NEW: Reverts with ERC7579CannotDecodeFallbackData
// Must provide at least 4-byte selector
installModule(3, fallbackModule, abi.encodePacked(bytes4(0x12345678)));
```

### ERC-7579 Security Checklist

- [ ] **Never install untrusted hooks** - malicious hooks can DoS your account
- [ ] Maintain a whitelist/registry of audited modules
- [ ] Fallback module data must be >= 4 bytes (v5.5.0+)
- [ ] Test module interactions thoroughly - modules can conflict
- [ ] Monitor for `ModuleInstalled`/`ModuleUninstalled` events
- [ ] Use `isModuleInstalled` to verify expected modules are active
- [ ] Consider implementing hook removal/timeout mechanisms

---

## Part 7: Paymaster Security

Paymasters sponsor gas fees but introduce trust assumptions:

```solidity
// SECURE: Paymaster validation in account
contract SecureAccount is Account {
    mapping(address => bool) public trustedPaymasters;
    
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external view returns (bytes memory context, uint256 validationData) {
        address paymaster = address(bytes20(userOp.paymasterAndData[:20]));
        
        // Only allow trusted paymasters
        if (!trustedPaymasters[paymaster]) {
            return ("", SIG_VALIDATION_FAILED);
        }
        
        // Additional validation...
        return ("", 0);
    }
}
```

---

## Part 8: SignerEIP7702 (EIP-7702 Utility)

OpenZeppelin provides a dedicated signer for EIP-7702 delegated EOAs:

```solidity
import "@openzeppelin/contracts/utils/cryptography/SignerEIP7702.sol";

// Use for EOAs with EIP-7702 delegation
// Renamed from SignerERC7702 -> SignerEIP7702 in v5.5.0
contract DelegatedEOAAccount is SignerEIP7702 {
    // Proper signature verification for delegated EOAs
}
```

---

## ERC-4337/7579 Quick Reference

```
UserOperation Flow:
User -> Creates UserOp -> Bundler -> EntryPoint -> Account.validateUserOp()
                                         |
                                  Account.execute()
                                         |
                                 Target Contract

Module Types (ERC-7579):
- Type 1: Validator (signature verification)
- Type 2: Executor (action execution)
- Type 3: Fallback (unknown selectors)
- Type 4: Hook (pre/post checks) [!] DoS risk
```

---

## Part 9: Anti-Patterns to Avoid

**Don't assume EOAs can't execute code.** The fundamental invariant is gone.

**Don't use EIP-7702 as "add smart wallet features, keep EOA security."** The private key is still the ultimate authority. If the key leaks, all 7702 protections are bypassed.

**Don't ask users to sign arbitrary delegation designators.** Wallets should whitelist approved implementation contracts. This is why MetaMask and Ledger are implementing whitelisting.

**Don't implement approve+spend as separate 7702 calls.** Batch them atomically - that's the whole point.

**Don't ignore ERC-4337 infrastructure.** 7702 is best used *with* 4337 bundlers for gas sponsorship and relaying, not as a replacement.

**Don't store sensitive data in delegate contract storage without namespacing.** Re-delegation can expose or corrupt it.

---

## Resources

**Official**:
- [EIP-7702 specification](https://eips.ethereum.org/EIPS/eip-7702)
- [ERC-4337 specification](https://eips.ethereum.org/EIPS/eip-4337)
- [ERC-7579 specification](https://eips.ethereum.org/EIPS/eip-7579)

**Implementation Guides**:
- [Viem EIP-7702 docs](https://viem.sh/docs/eip7702)
- [QuickNode EIP-7702 Guide](https://www.quicknode.com/guides/ethereum-development/smart-contracts/eip-7702-smart-accounts)

**Security**:
- [Halborn EIP-7702 Security Considerations](https://www.halborn.com/blog/post/eip-7702-security-considerations)
- [CertiK EIP-7702 Analysis](https://www.certik.com/resources/blog/pectras-eip-7702-redefining-trust-assumptions-of-externally-owned-accounts)

---

## Next Steps

- [cryptography-signatures.md](cryptography-signatures.md) - Signature verification patterns
- [patterns-upgrades.md](patterns-upgrades.md) - Design patterns for smart accounts
- [reference.md](reference.md) - Account Abstraction checklists
