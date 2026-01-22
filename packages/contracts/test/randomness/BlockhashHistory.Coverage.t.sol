// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { BlockhashHistory } from "../../src/randomness/BlockhashHistory.sol";

/// @title BlockhashHistoryCoverageTest
/// @notice Additional tests to achieve >90% coverage
contract BlockhashHistoryCoverageTest is Test {
    function setUp() public {
        vm.roll(10_000);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constants() public pure {
        assertEq(BlockhashHistory.getHistoryContractAddress(), address(0x0000F90827F1C53a10cb7A02335B175320002935));
        assertEq(BlockhashHistory.getNativeLimit(), 256);
        assertEq(BlockhashHistory.getExtendedWindow(), 8191);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // AVAILABILITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_IsAvailable_NoCode() public view {
        assertFalse(BlockhashHistory.isAvailable());
    }

    function test_IsAvailable_WithCode() public {
        vm.etch(address(0x0000F90827F1C53a10cb7A02335B175320002935), hex"6001");
        assertTrue(BlockhashHistory.isAvailable());
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GET BLOCKHASH EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetBlockhash_FutureBlock() public view {
        bytes32 hash = BlockhashHistory.getBlockhash(block.number + 1);
        assertEq(hash, bytes32(0));
    }

    function test_GetBlockhash_CurrentBlock() public view {
        bytes32 hash = BlockhashHistory.getBlockhash(block.number);
        assertEq(hash, bytes32(0));
    }

    function test_GetBlockhash_TooOld_NoEIP2935() public view {
        // Block older than 8191 blocks
        bytes32 hash = BlockhashHistory.getBlockhash(1);
        assertEq(hash, bytes32(0));
    }

    function test_GetBlockhash_WithinNative_NoEIP2935() public view {
        // Recent block without EIP-2935 - should still return 0 since
        // we call EIP-2935 contract which doesn't exist
        bytes32 hash = BlockhashHistory.getBlockhash(block.number - 10);
        assertEq(hash, bytes32(0));
    }

    function test_GetBlockhash_WithMockEIP2935() public {
        // Deploy mock at EIP-2935 address
        MockEIP2935 mock = new MockEIP2935();
        vm.etch(address(0x0000F90827F1C53a10cb7A02335B175320002935), address(mock).code);

        bytes32 hash = BlockhashHistory.getBlockhash(block.number - 100);
        // Mock returns keccak256 of block number
        assertEq(hash, keccak256(abi.encode(block.number - 100)));
    }

    function test_GetBlockhash_MockStaticCallFails() public {
        // Deploy mock that reverts
        RevertingMock mock = new RevertingMock();
        vm.etch(address(0x0000F90827F1C53a10cb7A02335B175320002935), address(mock).code);

        bytes32 hash = BlockhashHistory.getBlockhash(block.number - 100);
        // Should return 0 on failed staticcall
        assertEq(hash, bytes32(0));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GET BLOCKHASH WITH FALLBACK TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetBlockhashWithFallback_FutureBlock() public view {
        (bytes32 hash, bool usedExtended) =
            BlockhashHistory.getBlockhashWithFallback(block.number + 1);
        assertEq(hash, bytes32(0));
        assertFalse(usedExtended);
    }

    function test_GetBlockhashWithFallback_CurrentBlock() public view {
        (bytes32 hash, bool usedExtended) = BlockhashHistory.getBlockhashWithFallback(block.number);
        assertEq(hash, bytes32(0));
        assertFalse(usedExtended);
    }

    function test_GetBlockhashWithFallback_RecentBlock_Native() public view {
        // Within 256 blocks - should try native first
        (bytes32 hash, bool usedExtended) =
            BlockhashHistory.getBlockhashWithFallback(block.number - 10);
        // May or may not return hash depending on Foundry's blockhash behavior
        assertFalse(usedExtended); // If returned, should be from native
    }

    function test_GetBlockhashWithFallback_OldBlock_NoEIP2935() public view {
        // Older than 256 but without EIP-2935
        (bytes32 hash, bool usedExtended) =
            BlockhashHistory.getBlockhashWithFallback(block.number - 500);
        assertEq(hash, bytes32(0));
        assertFalse(usedExtended);
    }

    function test_GetBlockhashWithFallback_OldBlock_WithEIP2935() public {
        // Deploy mock at EIP-2935 address
        MockEIP2935 mock = new MockEIP2935();
        vm.etch(address(0x0000F90827F1C53a10cb7A02335B175320002935), address(mock).code);

        (bytes32 hash, bool usedExtended) =
            BlockhashHistory.getBlockhashWithFallback(block.number - 500);

        assertEq(hash, keccak256(abi.encode(block.number - 500)));
        assertTrue(usedExtended);
    }

    function test_GetBlockhashWithFallback_TooOld_WithEIP2935() public {
        // Deploy mock at EIP-2935 address
        MockEIP2935 mock = new MockEIP2935();
        vm.etch(address(0x0000F90827F1C53a10cb7A02335B175320002935), address(mock).code);

        // Roll to make block 1 too old even for EIP-2935 (8191 blocks)
        vm.roll(10_000);

        (bytes32 hash, bool usedExtended) = BlockhashHistory.getBlockhashWithFallback(1);
        assertEq(hash, bytes32(0));
        assertFalse(usedExtended);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EFFECTIVE WINDOW TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetEffectiveWindow_NoEIP2935() public view {
        assertEq(BlockhashHistory.getEffectiveWindow(), 256);
    }

    function test_GetEffectiveWindow_WithEIP2935() public {
        vm.etch(address(0x0000F90827F1C53a10cb7A02335B175320002935), hex"6001");
        assertEq(BlockhashHistory.getEffectiveWindow(), 8191);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // RETRIEVABILITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_IsBlockHashRetrievable_Future() public view {
        assertFalse(BlockhashHistory.isBlockHashRetrievable(block.number + 1));
    }

    function test_IsBlockHashRetrievable_Current() public view {
        assertFalse(BlockhashHistory.isBlockHashRetrievable(block.number));
    }

    function test_IsBlockHashRetrievable_Recent_NoEIP2935() public view {
        assertTrue(BlockhashHistory.isBlockHashRetrievable(block.number - 100));
    }

    function test_IsBlockHashRetrievable_Old_NoEIP2935() public view {
        assertFalse(BlockhashHistory.isBlockHashRetrievable(block.number - 500));
    }

    function test_IsBlockHashRetrievable_Old_WithEIP2935() public {
        vm.etch(address(0x0000F90827F1C53a10cb7A02335B175320002935), hex"6001");
        assertTrue(BlockhashHistory.isBlockHashRetrievable(block.number - 500));
    }

    function test_IsBlockHashRetrievable_TooOld_WithEIP2935() public {
        vm.etch(address(0x0000F90827F1C53a10cb7A02335B175320002935), hex"6001");
        vm.roll(20_000);
        assertFalse(BlockhashHistory.isBlockHashRetrievable(1));
    }

    function test_IsBlockHashRetrievable_AtEdge_NoEIP2935() public {
        assertTrue(BlockhashHistory.isBlockHashRetrievable(block.number - 256));
        assertFalse(BlockhashHistory.isBlockHashRetrievable(block.number - 257));
    }

    function test_IsBlockHashRetrievable_AtEdge_WithEIP2935() public {
        vm.etch(address(0x0000F90827F1C53a10cb7A02335B175320002935), hex"6001");
        assertTrue(BlockhashHistory.isBlockHashRetrievable(block.number - 8191));
        assertFalse(BlockhashHistory.isBlockHashRetrievable(block.number - 8192));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_GetBlockhash_NeverReverts(
        uint256 blockNum
    ) public view {
        bytes32 hash = BlockhashHistory.getBlockhash(blockNum);
        // Just checking it doesn't revert
        assertTrue(true);
        hash; // Silence warning
    }

    function testFuzz_GetBlockhashWithFallback_NeverReverts(
        uint256 blockNum
    ) public view {
        (bytes32 hash, bool usedExtended) = BlockhashHistory.getBlockhashWithFallback(blockNum);
        assertTrue(true);
        hash;
        usedExtended;
    }

    function testFuzz_IsBlockHashRetrievable_NeverReverts(
        uint256 blockNum
    ) public view {
        bool retrievable = BlockhashHistory.isBlockHashRetrievable(blockNum);
        assertTrue(true);
        retrievable;
    }
}

/// @notice Mock EIP-2935 contract for testing
contract MockEIP2935 {
    fallback(
        bytes calldata input
    ) external returns (bytes memory) {
        require(input.length == 32, "Invalid input");
        uint256 blockNumber = abi.decode(input, (uint256));
        return abi.encode(keccak256(abi.encode(blockNumber)));
    }
}

/// @notice Mock that always reverts
contract RevertingMock {
    fallback() external {
        revert("MockRevert");
    }
}
