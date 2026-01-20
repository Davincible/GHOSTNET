// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { ITraceScan } from "./interfaces/ITraceScan.sol";
import { IGhostCore } from "./interfaces/IGhostCore.sol";

/// @title TraceScanStorage
/// @notice Storage layout for TraceScan upgradeable contract
/// @dev Uses namespaced storage pattern (ERC-7201) for upgrade safety
abstract contract TraceScanStorage {
    // ══════════════════════════════════════════════════════════════════════════════
    // STORAGE NAMESPACE (ERC-7201)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @custom:storage-location erc7201:ghostnet.storage.TraceScan
    struct TraceScanStorageLayout {
        // ─── Core References ─────────────────────────────────────────────────────
        IGhostCore ghostCore;
        // ─── Scan State ──────────────────────────────────────────────────────────
        mapping(IGhostCore.Level level => ITraceScan.Scan scan) currentScans;
        // ─── Nonce for seed generation ───────────────────────────────────────────
        uint256 scanNonce;
        // ─── Configuration ───────────────────────────────────────────────────────
        uint256 submissionWindow; // Time window for death submissions
        uint256 maxBatchSize; // Max deaths per submission tx
        // ─── Epoch-based processed tracking ──────────────────────────────────────
        // processedInScan[level][scanId][user] = true if already processed
        // Using scanId as key avoids O(n) cleanup after finalization
        mapping(IGhostCore.Level => mapping(uint256 => mapping(address => bool))) processedInScan;
        // ─── Reserved for Future Upgrades ────────────────────────────────────────
        uint256[45] __gap;
    }

    // keccak256(abi.encode(uint256(keccak256("ghostnet.storage.TraceScan")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TRACE_SCAN_STORAGE_LOCATION =
        0x4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c00;

    function _getTraceScanStorage() internal pure returns (TraceScanStorageLayout storage $) {
        assembly {
            $.slot := TRACE_SCAN_STORAGE_LOCATION
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Default submission window (120 seconds)
    uint256 internal constant DEFAULT_SUBMISSION_WINDOW = 120 seconds;

    /// @notice Default max batch size (100 deaths per tx)
    uint256 internal constant DEFAULT_MAX_BATCH_SIZE = 100;

    /// @notice Basis points denominator
    uint16 internal constant BPS = 10_000;
}
