// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {CommitRevealBase} from "../../src/arcade/randomness/CommitRevealBase.sol";

/// @title CommitRevealBaseTest
/// @notice Tests for the CommitRevealBase contract
contract CommitRevealBaseTest is Test {
    TestCommitReveal public game;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 public constant ROUND_ID = 1;
    uint128 public constant BET_AMOUNT = 100 ether;

    function setUp() public {
        game = new TestCommitReveal();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // COMMITMENT HASH GENERATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GenerateCommitmentHash() public view {
        uint8 choice = 1;
        bytes32 secret = bytes32("secret123");

        bytes32 hash = game.generateCommitmentHash(choice, secret, alice);

        // Hash should be deterministic
        bytes32 expectedHash = keccak256(abi.encodePacked(choice, secret, alice));
        assertEq(hash, expectedHash, "Hash should match expected");
    }

    function test_GenerateCommitmentHash_DifferentChoices() public view {
        bytes32 secret = bytes32("secret123");

        bytes32 hash0 = game.generateCommitmentHash(0, secret, alice);
        bytes32 hash1 = game.generateCommitmentHash(1, secret, alice);

        assertTrue(hash0 != hash1, "Different choices should produce different hashes");
    }

    function test_GenerateCommitmentHash_DifferentSecrets() public view {
        uint8 choice = 1;

        bytes32 hash1 = game.generateCommitmentHash(choice, bytes32("secret1"), alice);
        bytes32 hash2 = game.generateCommitmentHash(choice, bytes32("secret2"), alice);

        assertTrue(hash1 != hash2, "Different secrets should produce different hashes");
    }

    function test_GenerateCommitmentHash_DifferentPlayers() public view {
        uint8 choice = 1;
        bytes32 secret = bytes32("secret123");

        bytes32 hashAlice = game.generateCommitmentHash(choice, secret, alice);
        bytes32 hashBob = game.generateCommitmentHash(choice, secret, bob);

        assertTrue(hashAlice != hashBob, "Different players should produce different hashes");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // COMMIT TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Commit_Success() public {
        bytes32 secret = bytes32("secret123");
        bytes32 commitHash = game.generateCommitmentHash(1, secret, alice);

        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);

        assertTrue(game.hasCommitted(ROUND_ID, alice), "Alice should have committed");
        assertFalse(game.hasRevealed(ROUND_ID, alice), "Alice should not have revealed");

        (uint128 amount, bool revealed, uint8 revealedChoice) = game.getCommitment(ROUND_ID, alice);
        assertEq(amount, BET_AMOUNT, "Amount should match");
        assertFalse(revealed, "Should not be revealed");
        assertEq(revealedChoice, 255, "Revealed choice should be 255 (not revealed)");
    }

    function test_Commit_RevertWhen_ZeroHash() public {
        vm.expectRevert(CommitRevealBase.InvalidCommitmentHash.selector);
        game.commit(ROUND_ID, alice, bytes32(0), BET_AMOUNT);
    }

    function test_Commit_RevertWhen_ZeroAmount() public {
        bytes32 commitHash = game.generateCommitmentHash(1, bytes32("secret"), alice);

        vm.expectRevert(CommitRevealBase.InvalidAmount.selector);
        game.commit(ROUND_ID, alice, commitHash, 0);
    }

    function test_Commit_RevertWhen_AlreadyCommitted() public {
        bytes32 commitHash = game.generateCommitmentHash(1, bytes32("secret"), alice);
        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);

        vm.expectRevert(CommitRevealBase.AlreadyCommitted.selector);
        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);
    }

    function test_Commit_MultiplePlayersSuccess() public {
        bytes32 hashAlice = game.generateCommitmentHash(0, bytes32("secretA"), alice);
        bytes32 hashBob = game.generateCommitmentHash(1, bytes32("secretB"), bob);
        bytes32 hashCharlie = game.generateCommitmentHash(0, bytes32("secretC"), charlie);

        game.commit(ROUND_ID, alice, hashAlice, BET_AMOUNT);
        game.commit(ROUND_ID, bob, hashBob, BET_AMOUNT * 2);
        game.commit(ROUND_ID, charlie, hashCharlie, BET_AMOUNT / 2);

        assertTrue(game.hasCommitted(ROUND_ID, alice));
        assertTrue(game.hasCommitted(ROUND_ID, bob));
        assertTrue(game.hasCommitted(ROUND_ID, charlie));
    }

    function test_Commit_SamePlayerDifferentRounds() public {
        bytes32 hash1 = game.generateCommitmentHash(0, bytes32("secret1"), alice);
        bytes32 hash2 = game.generateCommitmentHash(1, bytes32("secret2"), alice);

        game.commit(1, alice, hash1, BET_AMOUNT);
        game.commit(2, alice, hash2, BET_AMOUNT * 2);

        assertTrue(game.hasCommitted(1, alice));
        assertTrue(game.hasCommitted(2, alice));

        (uint128 amount1,,) = game.getCommitment(1, alice);
        (uint128 amount2,,) = game.getCommitment(2, alice);

        assertEq(amount1, BET_AMOUNT);
        assertEq(amount2, BET_AMOUNT * 2);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REVEAL TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Reveal_Success() public {
        uint8 choice = 1;
        bytes32 secret = bytes32("secret123");
        bytes32 commitHash = game.generateCommitmentHash(choice, secret, alice);

        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);
        uint8 revealed = game.reveal(ROUND_ID, alice, choice, secret);

        assertEq(revealed, choice, "Revealed choice should match");
        assertTrue(game.hasRevealed(ROUND_ID, alice), "Should be marked as revealed");

        (uint128 amount, bool isRevealed, uint8 revealedChoice) = game.getCommitment(ROUND_ID, alice);
        assertEq(amount, BET_AMOUNT, "Amount should be preserved");
        assertTrue(isRevealed, "Should be revealed");
        assertEq(revealedChoice, choice, "Revealed choice should match");
    }

    function test_Reveal_RevertWhen_NotCommitted() public {
        vm.expectRevert(CommitRevealBase.NotCommitted.selector);
        game.reveal(ROUND_ID, alice, 1, bytes32("secret"));
    }

    function test_Reveal_RevertWhen_AlreadyRevealed() public {
        uint8 choice = 1;
        bytes32 secret = bytes32("secret123");
        bytes32 commitHash = game.generateCommitmentHash(choice, secret, alice);

        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);
        game.reveal(ROUND_ID, alice, choice, secret);

        vm.expectRevert(CommitRevealBase.AlreadyRevealed.selector);
        game.reveal(ROUND_ID, alice, choice, secret);
    }

    function test_Reveal_RevertWhen_WrongChoice() public {
        uint8 actualChoice = 1;
        uint8 wrongChoice = 0;
        bytes32 secret = bytes32("secret123");
        bytes32 commitHash = game.generateCommitmentHash(actualChoice, secret, alice);

        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);

        vm.expectRevert(CommitRevealBase.InvalidReveal.selector);
        game.reveal(ROUND_ID, alice, wrongChoice, secret);
    }

    function test_Reveal_RevertWhen_WrongSecret() public {
        uint8 choice = 1;
        bytes32 actualSecret = bytes32("secret123");
        bytes32 wrongSecret = bytes32("wrongsecret");
        bytes32 commitHash = game.generateCommitmentHash(choice, actualSecret, alice);

        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);

        vm.expectRevert(CommitRevealBase.InvalidReveal.selector);
        game.reveal(ROUND_ID, alice, choice, wrongSecret);
    }

    function test_Reveal_MultiplePlayersSuccess() public {
        // Setup commitments
        bytes32 secretA = bytes32("secretA");
        bytes32 secretB = bytes32("secretB");
        bytes32 hashAlice = game.generateCommitmentHash(0, secretA, alice);
        bytes32 hashBob = game.generateCommitmentHash(1, secretB, bob);

        game.commit(ROUND_ID, alice, hashAlice, BET_AMOUNT);
        game.commit(ROUND_ID, bob, hashBob, BET_AMOUNT);

        // Reveal
        uint8 choiceAlice = game.reveal(ROUND_ID, alice, 0, secretA);
        uint8 choiceBob = game.reveal(ROUND_ID, bob, 1, secretB);

        assertEq(choiceAlice, 0, "Alice's choice should be 0");
        assertEq(choiceBob, 1, "Bob's choice should be 1");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FORFEIT TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Forfeit_Success() public {
        bytes32 commitHash = game.generateCommitmentHash(1, bytes32("secret"), alice);
        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);

        uint128 forfeited = game.forfeit(ROUND_ID, alice);

        assertEq(forfeited, BET_AMOUNT, "Should forfeit full amount");
        assertFalse(game.canReveal(ROUND_ID, alice), "Should not be able to reveal after forfeit");
    }

    function test_Forfeit_NoCommitment() public {
        uint128 forfeited = game.forfeit(ROUND_ID, alice);
        assertEq(forfeited, 0, "Should return 0 for non-committed player");
    }

    function test_Forfeit_AlreadyRevealed() public {
        bytes32 secret = bytes32("secret");
        bytes32 commitHash = game.generateCommitmentHash(1, secret, alice);

        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);
        game.reveal(ROUND_ID, alice, 1, secret);

        uint128 forfeited = game.forfeit(ROUND_ID, alice);
        assertEq(forfeited, 0, "Should return 0 for revealed player");
    }

    function test_Forfeit_DoubleForfeit() public {
        bytes32 commitHash = game.generateCommitmentHash(1, bytes32("secret"), alice);
        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);

        uint128 first = game.forfeit(ROUND_ID, alice);
        uint128 second = game.forfeit(ROUND_ID, alice);

        assertEq(first, BET_AMOUNT, "First forfeit should return amount");
        assertEq(second, 0, "Second forfeit should return 0");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CanReveal_BeforeCommit() public view {
        assertFalse(game.canReveal(ROUND_ID, alice), "Should not be able to reveal before commit");
    }

    function test_CanReveal_AfterCommit() public {
        bytes32 commitHash = game.generateCommitmentHash(1, bytes32("secret"), alice);
        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);

        assertTrue(game.canReveal(ROUND_ID, alice), "Should be able to reveal after commit");
    }

    function test_CanReveal_AfterReveal() public {
        bytes32 secret = bytes32("secret");
        bytes32 commitHash = game.generateCommitmentHash(1, secret, alice);

        game.commit(ROUND_ID, alice, commitHash, BET_AMOUNT);
        game.reveal(ROUND_ID, alice, 1, secret);

        assertFalse(game.canReveal(ROUND_ID, alice), "Should not be able to reveal after already revealed");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_CommitReveal_Success(
        uint8 choice,
        bytes32 secret,
        uint128 amount
    ) public {
        vm.assume(amount > 0);
        vm.assume(secret != bytes32(0));

        bytes32 commitHash = game.generateCommitmentHash(choice, secret, alice);

        game.commit(ROUND_ID, alice, commitHash, amount);
        uint8 revealed = game.reveal(ROUND_ID, alice, choice, secret);

        assertEq(revealed, choice, "Revealed choice should match");
    }

    function testFuzz_GenerateCommitmentHash_Deterministic(
        uint8 choice,
        bytes32 secret,
        address player
    ) public view {
        bytes32 hash1 = game.generateCommitmentHash(choice, secret, player);
        bytes32 hash2 = game.generateCommitmentHash(choice, secret, player);

        assertEq(hash1, hash2, "Same inputs should produce same hash");
    }

    function testFuzz_WrongSecret_AlwaysReverts(
        uint8 choice,
        bytes32 actualSecret,
        bytes32 wrongSecret,
        uint128 amount
    ) public {
        vm.assume(amount > 0);
        vm.assume(actualSecret != bytes32(0));
        vm.assume(actualSecret != wrongSecret);

        bytes32 commitHash = game.generateCommitmentHash(choice, actualSecret, alice);
        game.commit(ROUND_ID, alice, commitHash, amount);

        vm.expectRevert(CommitRevealBase.InvalidReveal.selector);
        game.reveal(ROUND_ID, alice, choice, wrongSecret);
    }

    function testFuzz_WrongChoice_AlwaysReverts(
        uint8 actualChoice,
        uint8 wrongChoice,
        bytes32 secret,
        uint128 amount
    ) public {
        vm.assume(amount > 0);
        vm.assume(secret != bytes32(0));
        vm.assume(actualChoice != wrongChoice);

        bytes32 commitHash = game.generateCommitmentHash(actualChoice, secret, alice);
        game.commit(ROUND_ID, alice, commitHash, amount);

        vm.expectRevert(CommitRevealBase.InvalidReveal.selector);
        game.reveal(ROUND_ID, alice, wrongChoice, secret);
    }
}

/// @notice Concrete implementation of CommitRevealBase for testing
contract TestCommitReveal is CommitRevealBase {
    function commit(
        uint256 roundId,
        address player,
        bytes32 commitHash,
        uint128 amount
    ) external {
        _commit(roundId, player, commitHash, amount);
    }

    function reveal(
        uint256 roundId,
        address player,
        uint8 choice,
        bytes32 secret
    ) external returns (uint8) {
        return _reveal(roundId, player, choice, secret);
    }

    function forfeit(uint256 roundId, address player) external returns (uint128) {
        return _forfeit(roundId, player);
    }
}
