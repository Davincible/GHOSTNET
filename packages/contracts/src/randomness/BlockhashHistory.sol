// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title BlockhashHistory
/// @notice Library for accessing extended blockhash history via EIP-2935 (Prague EVM)
/// @dev EIP-2935 provides access to historical blockhashes beyond the native 256-block limit.
///      On Prague-compatible chains, this enables ~13.6 minutes of history (8191 blocks at 100ms).
///
///      IMPORTANT: This library gracefully degrades if EIP-2935 is unavailable.
///      Always check `isAvailable()` or handle zero returns appropriately.
///
///      MegaETH CONSIDERATIONS:
///      - MegaETH uses 100ms block times, so 256 blocks = 25.6 seconds (native limit)
///      - With EIP-2935: 8191 blocks = ~13.6 minutes of extended history
///      - Verify MegaETH supports Prague EVM before relying on extended history
///
/// @custom:security-contact security@ghostnet.game
library BlockhashHistory {
    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice EIP-2935 system contract address (standardized across all Prague chains)
    /// @dev This address is fixed by the EIP specification
    address internal constant HISTORY_CONTRACT = 0x0000000000000000000000000000000000000935;

    /// @notice Number of blocks available in extended history
    /// @dev EIP-2935 specifies 8191 blocks of history (ring buffer)
    uint256 internal constant HISTORY_WINDOW = 8191;

    /// @notice Native blockhash limit (EVM hard limit)
    uint256 internal constant NATIVE_LIMIT = 256;

    // ══════════════════════════════════════════════════════════════════════════════
    // AVAILABILITY CHECKS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Check if EIP-2935 history contract is available
    /// @dev Checks for code at the system contract address.
    ///      NOTE: This is a heuristic. The contract existing doesn't guarantee
    ///      it's correctly populated or functional.
    /// @return available True if the history contract has code
    function isAvailable() internal view returns (bool available) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            size := extcodesize(HISTORY_CONTRACT)
        }
        return size > 0;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BLOCKHASH RETRIEVAL
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get blockhash for a specific block number using EIP-2935
    /// @dev Queries the system contract via staticcall.
    ///      Returns bytes32(0) if:
    ///      - EIP-2935 is not available
    ///      - Block is outside the history window
    ///      - Block hasn't been recorded yet
    ///      - The staticcall fails
    ///
    ///      SECURITY: The returned hash is trustworthy IF the chain correctly
    ///      implements EIP-2935. For critical operations, consider verifying
    ///      against multiple sources or using commit-reveal patterns.
    ///
    /// @param blockNumber The block number to get the hash for
    /// @return hash The blockhash, or bytes32(0) if unavailable
    function getBlockhash(uint256 blockNumber) internal view returns (bytes32 hash) {
        // Quick rejection: block must be in the past
        if (blockNumber >= block.number) {
            return bytes32(0);
        }

        // Quick rejection: block too old even for extended history
        uint256 age = block.number - blockNumber;
        if (age > HISTORY_WINDOW) {
            return bytes32(0);
        }

        // Check availability (may be expensive, but necessary)
        if (!isAvailable()) {
            return bytes32(0);
        }

        // Query the history contract
        // EIP-2935 spec: Input is the block number as uint256
        // Output is the 32-byte blockhash
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            // Store block number in scratch space
            mstore(0x00, blockNumber)

            // staticcall to history contract
            // - gas: pass all remaining
            // - to: HISTORY_CONTRACT (0x935)
            // - inputOffset: 0x00
            // - inputSize: 0x20 (32 bytes for uint256)
            // - outputOffset: 0x00 (reuse scratch space)
            // - outputSize: 0x20 (32 bytes for hash)
            let success := staticcall(gas(), HISTORY_CONTRACT, 0x00, 0x20, 0x00, 0x20)

            // Only load result if call succeeded
            if success {
                hash := mload(0x00)
            }
        }

        return hash;
    }

    /// @notice Get blockhash using native blockhash() first, falling back to EIP-2935
    /// @dev Attempts native blockhash first (cheaper), falls back to EIP-2935 for older blocks.
    ///      This is the recommended function for general use.
    ///
    ///      Cost breakdown:
    ///      - Native blockhash (age <= 256): ~20 gas
    ///      - EIP-2935 query (age <= 8191): ~2600+ gas (cold) / ~100+ gas (warm)
    ///
    /// @param blockNumber The block number to get the hash for
    /// @return hash The blockhash, or bytes32(0) if unavailable from any source
    /// @return usedExtended True if the hash came from EIP-2935, false if native
    function getBlockhashWithFallback(
        uint256 blockNumber
    ) internal view returns (bytes32 hash, bool usedExtended) {
        // Quick rejection: block must be in the past
        if (blockNumber >= block.number) {
            return (bytes32(0), false);
        }

        uint256 age = block.number - blockNumber;

        // Try native blockhash first (cheaper)
        if (age <= NATIVE_LIMIT) {
            hash = blockhash(blockNumber);
            if (hash != bytes32(0)) {
                return (hash, false);
            }
            // Native returned 0 (shouldn't happen for valid recent blocks, but handle it)
        }

        // Try EIP-2935 extended history
        if (age <= HISTORY_WINDOW) {
            hash = getBlockhash(blockNumber);
            if (hash != bytes32(0)) {
                return (hash, true);
            }
        }

        // Neither source had the hash
        return (bytes32(0), false);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // UTILITY FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get the effective history window based on EIP-2935 availability
    /// @return window The number of blocks of history available
    function getEffectiveWindow() internal view returns (uint256 window) {
        if (isAvailable()) {
            return HISTORY_WINDOW;
        }
        return NATIVE_LIMIT;
    }

    /// @notice Check if a block hash is retrievable (within available history)
    /// @param blockNumber The block number to check
    /// @return retrievable True if the blockhash should be retrievable
    function isBlockHashRetrievable(uint256 blockNumber) internal view returns (bool retrievable) {
        if (blockNumber >= block.number) {
            return false;
        }

        uint256 age = block.number - blockNumber;
        return age <= getEffectiveWindow();
    }

    /// @notice Get the history contract address (for verification/debugging)
    /// @return addr The EIP-2935 system contract address
    function getHistoryContractAddress() internal pure returns (address addr) {
        return HISTORY_CONTRACT;
    }

    /// @notice Get the native blockhash limit
    /// @return limit The number of blocks available via native blockhash()
    function getNativeLimit() internal pure returns (uint256 limit) {
        return NATIVE_LIMIT;
    }

    /// @notice Get the EIP-2935 extended history window
    /// @return window The number of blocks available via EIP-2935
    function getExtendedWindow() internal pure returns (uint256 window) {
        return HISTORY_WINDOW;
    }
}
