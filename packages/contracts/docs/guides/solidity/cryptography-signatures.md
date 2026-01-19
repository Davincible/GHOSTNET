# Cryptography & Signatures

Secure signature verification, ECDSA updates, and modern cryptographic primitives for smart contracts.

---

## ECDSA Signature Malleability Deprecation

**CRITICAL DEPRECATION (v5.5.0):**

The ECDSA malleability protection is being **deprecated** and will be **removed in v6.0**. If you use signatures as unique identifiers, you must migrate NOW.

```solidity
// DEPRECATED PATTERN: Using signature as unique identifier
// This WILL BREAK in OpenZeppelin v6.0!
mapping(bytes => bool) public usedSignatures;

function claimWithSignature(bytes calldata signature) external {
    require(!usedSignatures[signature], "Already used");
    usedSignatures[signature] = true;  // VULNERABLE!
    // ... claim logic
}

// CORRECT: Use hash invalidation or nonces
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

contract SecureSignatures is Nonces {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    
    mapping(bytes32 => bool) public usedHashes;
    
    function claimWithSignature(
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) external {
        // Create unique hash including nonce
        bytes32 messageHash = keccak256(abi.encode(
            msg.sender,
            amount,
            nonce,
            block.chainid,
            address(this)
        ));
        
        // Verify nonce
        require(nonce == _useNonce(msg.sender), "Invalid nonce");
        
        // Verify hash hasn't been used
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        require(!usedHashes[ethSignedHash], "Already used");
        
        // Recover and verify signer
        address signer = ethSignedHash.recover(signature);
        require(signer == expectedSigner, "Invalid signature");
        
        // Mark hash as used
        usedHashes[ethSignedHash] = true;
        
        // ... claim logic
    }
}
```

### New ECDSA Functions (v5.5.0)

```solidity
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// New: Parse signatures into components
(uint8 v, bytes32 r, bytes32 s) = ECDSA.parse(signature);
(v, r, s) = ECDSA.parseCalldata(signature);  // Gas efficient for calldata

// New: Calldata-optimized recovery
address signer = ECDSA.recoverCalldata(hash, signature);
(address signer, ECDSA.RecoverError error, bytes32 errorArg) = 
    ECDSA.tryRecoverCalldata(hash, signature);
```

---

## EIP-712 Typed Data Signatures

Always use EIP-712 for structured data signatures:

```solidity
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract TypedSignatures is EIP712 {
    bytes32 private constant CLAIM_TYPEHASH = 
        keccak256("Claim(address user,uint256 amount,uint256 nonce,uint256 deadline)");
    
    constructor() EIP712("MyProtocol", "1") {}
    
    function claim(
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, "Signature expired");
        
        bytes32 structHash = keccak256(abi.encode(
            CLAIM_TYPEHASH,
            msg.sender,
            amount,
            nonce,
            deadline
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        
        require(signer == trustedSigner, "Invalid signature");
        // ... claim logic
    }
}
```

---

## ERC-7739 Signature Validation (Anti-Replay)

ERC-7739 implements defensive rehashing to prevent signature replay across contracts:

```solidity
import "@openzeppelin/contracts/utils/cryptography/ERC7739.sol";
import "@openzeppelin/contracts/utils/cryptography/ERC7739Utils.sol";

// Automatic domain separation prevents cross-contract replay
contract SecureSignatureVerifier is ERC7739 {
    function _domainNameAndVersion() 
        internal view virtual override 
        returns (string memory name, string memory version) 
    {
        return ("MyContract", "1");
    }
    
    // Signatures are automatically domain-bound
    function verifySignature(
        bytes32 structHash,
        bytes calldata signature
    ) external view returns (bool) {
        return _validateSignature(structHash, signature);
    }
}
```

---

## Signer Contracts

OpenZeppelin 5.4+ introduces abstract signer contracts for various signature schemes:

```solidity
// Standard ECDSA signer
import "@openzeppelin/contracts/utils/cryptography/SignerECDSA.sol";

// P256 (secp256r1) for WebAuthn/Passkeys/Hardware tokens
import "@openzeppelin/contracts/utils/cryptography/SignerP256.sol";

// RSA signatures (corporate PKI)
import "@openzeppelin/contracts/utils/cryptography/SignerRSA.sol";

// WebAuthn with P256 fallback (v5.5.0)
import "@openzeppelin/contracts/utils/cryptography/SignerWebAuthn.sol";

// ERC-7913 workflow (multiple signers)
import "@openzeppelin/contracts/utils/cryptography/SignerERC7913.sol";
import "@openzeppelin/contracts/utils/cryptography/MultiSignerERC7913.sol";
import "@openzeppelin/contracts/utils/cryptography/MultiSignerERC7913Weighted.sol";
```

### Use Cases

- `SignerP256`: Hardware security modules, Apple Secure Enclave, WebAuthn
- `SignerRSA`: Corporate PKI integration
- `MultiSignerERC7913Weighted`: Flexible governance with weighted voting

---

## P256 (secp256r1) Verification

```solidity
import "@openzeppelin/contracts/utils/cryptography/P256.sol";

// Verify P256 signatures (WebAuthn, passkeys, hardware tokens)
bool valid = P256.verify(hash, r, s, qx, qy);

// With RIP-7212 precompile support
// Handles both native precompile and fallback gracefully

// v5.3.0 FIX: verifyNative now handles empty returndata correctly
// Previously would revert with MissingPrecompile on some chains
```

---

## BLS12-381 Precompiles (EIP-2537, Prague)

The Prague upgrade (May 2025) introduces native BLS12-381 precompiles, making ZK proofs and BLS signature verification practical on-chain.

### Precompile Addresses

```solidity
// EIP-2537 BLS12-381 precompile addresses
address constant BLS12_G1ADD = 0x000000000000000000000000000000000000000b;
address constant BLS12_G1MSM = 0x000000000000000000000000000000000000000c;
address constant BLS12_G2ADD = 0x000000000000000000000000000000000000000d;
address constant BLS12_G2MSM = 0x000000000000000000000000000000000000000e;
address constant BLS12_PAIRING = 0x000000000000000000000000000000000000000f;
address constant BLS12_MAP_FP_TO_G1 = 0x0000000000000000000000000000000000000010;
address constant BLS12_MAP_FP2_TO_G2 = 0x0000000000000000000000000000000000000011;
```

### Gas Costs

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| G1ADD | 375 | Point addition on G1 |
| G2ADD | 600 | Point addition on G2 |
| G1MSM | Variable | Multi-scalar multiplication |
| G2MSM | Variable | Multi-scalar multiplication |
| Pairing | Variable | ~23,800 base + per-pair cost |
| MAP_FP_TO_G1 | 5,500 | Hash to G1 |
| MAP_FP2_TO_G2 | 23,800 | Hash to G2 |

Previously, BLS operations in pure Solidity cost 140,000+ gas. Native precompiles reduce this by 95%+.

### Use Cases

- **ZK proof verification**: Groth16, PLONK proofs use BLS12-381 pairings
- **BLS signature aggregation**: Aggregate thousands of signatures into one
- **Threshold cryptography**: Multi-party computation schemes
- **Cross-chain bridges**: Light client verification

### Example: BLS Signature Verification

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

library BLS12381 {
    address constant PAIRING = 0x000000000000000000000000000000000000000f;
    
    /// @notice Verify a BLS signature
    /// @param pubkey The public key (G1 point, 128 bytes)
    /// @param signature The signature (G2 point, 256 bytes)
    /// @param message The message hash mapped to G2 (256 bytes)
    function verify(
        bytes memory pubkey,
        bytes memory signature,
        bytes memory message
    ) internal view returns (bool) {
        // Pairing check: e(pubkey, message) == e(G1_generator, signature)
        // Rearranged: e(pubkey, message) * e(-G1_generator, signature) == 1
        
        bytes memory input = abi.encodePacked(
            pubkey,      // G1 point (public key)
            message,     // G2 point (hashed message)
            G1_NEG_GENERATOR, // -G1 generator
            signature    // G2 point (signature)
        );
        
        (bool success, bytes memory result) = PAIRING.staticcall(input);
        if (!success || result.length != 32) return false;
        
        return abi.decode(result, (bool));
    }
}
```

**Note**: Production BLS implementations should use audited libraries. The above is illustrative.

---

## WebAuthn Library (v5.5.0)

```solidity
import "@openzeppelin/contracts/utils/cryptography/WebAuthn.sol";

// Verify WebAuthn Authentication Assertions
bool valid = WebAuthn.verify(
    authenticatorData,
    clientDataJSON,
    challenge,
    publicKey
);
```

---

## SignatureChecker Updates

```solidity
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

// Now supports:
// 1. ECDSA signatures (EOAs)
// 2. ERC-1271 signatures (smart contracts)
// 3. ERC-7913 signatures (v5.4.0+)

bool valid = SignatureChecker.isValidSignatureNow(signer, hash, signature);

// Calldata-optimized (v5.1.0+)
bool valid = SignatureChecker.isValidSignatureNowCalldata(signer, hash, signature);
```

---

## Signature Security Checklist

- [ ] **Never use signatures as unique identifiers** (deprecated in OZ v6.0)
- [ ] Use nonces or hash invalidation for replay protection
- [ ] Include `block.chainid` in signed data for cross-chain replay prevention
- [ ] Include contract address in signed data for cross-contract replay prevention
- [ ] Use EIP-712 for structured data (human-readable in wallets)
- [ ] Implement signature expiration (deadline parameter)
- [ ] Consider ERC-7739 for automatic domain separation
- [ ] Validate recovered address is not `address(0)`
- [ ] Use OpenZeppelin's ECDSA library (handles edge cases)

---

## Common Signature Vulnerabilities

### Missing Chain ID

```solidity
// VULNERABLE: No chain ID
bytes32 hash = keccak256(abi.encode(user, amount, nonce));

// SECURE: Include chain ID
bytes32 hash = keccak256(abi.encode(
    user, 
    amount, 
    nonce, 
    block.chainid,  // Prevents replay on other chains
    address(this)   // Prevents replay on other contracts
));
```

### Missing Deadline

```solidity
// VULNERABLE: Signature valid forever
function claim(bytes calldata signature) external {
    // Old signatures can be used indefinitely
}

// SECURE: Include expiration
function claim(uint256 deadline, bytes calldata signature) external {
    require(block.timestamp <= deadline, "Expired");
    // Signature must include deadline
}
```

### Signature Replay in Upgrades

```solidity
// VULNERABLE: Contract upgrade resets nonces
// Old signatures become valid again

// SECURE: Use EIP-712 with version in domain separator
// Update version string on each upgrade
constructor() EIP712("MyContract", "2") {} // Increment on upgrade
```

---

## Next Steps

- [patterns-upgrades.md](patterns-upgrades.md) - Two-step ownership and access control patterns
- [reference.md](reference.md) - Signature verification checklists
- [eip7702-account-abstraction.md](eip7702-account-abstraction.md) - Account Abstraction signature validation
