// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title CommitRevealBase
/// @notice Base contract for games with player choice commitment
/// @dev Inherit this for games where players make hidden choices (e.g., BINARY BET).
///
/// Pattern:
///   1. COMMIT PHASE: Players submit hash(choice, secret, player)
///   2. LOCK PHASE: Betting closes, seed block committed (use with FutureBlockRandomness)
///   3. REVEAL PHASE: Players reveal choice + secret to prove their commitment
///   4. RESOLUTION: Compare revealed choices against winning outcome
///
/// Security Properties:
///   - Choices are hidden until reveal (commitment hiding)
///   - Players cannot change choice after commit (commitment binding)
///   - Player address included in hash prevents commitment copying
///   - Non-reveals result in forfeiture (anti-griefing)
///
/// Usage with FutureBlockRandomness:
///   contract BinaryBet is CommitRevealBase, FutureBlockRandomness {
///       function endCommitPhase(uint256 roundId) external {
///           _commitSeedBlock(roundId);  // Lock in the seed
///       }
///       // Then players reveal, seed is revealed, winners determined
///   }
///
/// @custom:security-contact security@ghostnet.game
abstract contract CommitRevealBase {
    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Sentinel value indicating choice has not been revealed
    uint8 internal constant NOT_REVEALED = 255;

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Player has already committed to this round
    error AlreadyCommitted();

    /// @notice Player has not committed to this round
    error NotCommitted();

    /// @notice Player has already revealed their commitment
    error AlreadyRevealed();

    /// @notice Revealed choice/secret does not match commitment hash
    error InvalidReveal();

    /// @notice Invalid commitment hash (zero)
    error InvalidCommitmentHash();

    /// @notice Invalid bet amount (zero)
    error InvalidAmount();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a player commits to a choice
    /// @param roundId The round identifier
    /// @param player The player address
    /// @param amount The bet amount
    event Committed(uint256 indexed roundId, address indexed player, uint256 amount);

    /// @notice Emitted when a player reveals their choice
    /// @param roundId The round identifier
    /// @param player The player address
    /// @param choice The revealed choice
    event Revealed(uint256 indexed roundId, address indexed player, uint8 choice);

    /// @notice Emitted when a player forfeits by not revealing
    /// @param roundId The round identifier
    /// @param player The player address
    /// @param amount The forfeited amount
    event Forfeited(uint256 indexed roundId, address indexed player, uint256 amount);

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Player commitment for a round
    /// @dev Storage layout (2 slots total):
    ///      - Slot 0: bytes32 hash (32 bytes)
    ///      - Slot 1: uint128 amount (16) + uint8 revealedChoice (1) + bool revealed (1) = 18 bytes packed
    struct Commitment {
        bytes32 hash;           // keccak256(choice, secret, player)
        uint128 amount;         // Bet amount (0 after forfeit)
        uint8 revealedChoice;   // Revealed choice (255 = not revealed)
        bool revealed;          // Whether choice has been revealed
    }

    /// @notice Mapping from roundId => player => commitment
    mapping(uint256 roundId => mapping(address player => Commitment)) internal _commitments;

    // ══════════════════════════════════════════════════════════════════════════════
    // PURE FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Generate commitment hash (call off-chain before committing)
    /// @dev Include player address to prevent commitment copying between players
    /// @param choice The player's choice (game-specific, typically 0 or 1)
    /// @param secret A random bytes32 secret known only to the player
    /// @param player The player's address
    /// @return commitHash The hash to submit during commit phase
    function generateCommitmentHash(
        uint8 choice,
        bytes32 secret,
        address player
    ) external pure returns (bytes32 commitHash) {
        return keccak256(abi.encode(choice, secret, player));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Record a player's commitment
    /// @dev Call during commit phase after validating phase and collecting tokens
    /// @param roundId The round identifier
    /// @param player The player address
    /// @param commitHash The commitment hash (from generateCommitmentHash)
    /// @param amount The bet amount
    function _commit(
        uint256 roundId,
        address player,
        bytes32 commitHash,
        uint128 amount
    ) internal {
        if (commitHash == bytes32(0)) revert InvalidCommitmentHash();
        if (amount == 0) revert InvalidAmount();

        Commitment storage c = _commitments[roundId][player];
        if (c.amount > 0) revert AlreadyCommitted();

        c.hash = commitHash;
        c.amount = amount;
        c.revealedChoice = NOT_REVEALED;

        emit Committed(roundId, player, amount);
    }

    /// @notice Reveal a player's commitment
    /// @dev Call during reveal phase. Verifies hash matches commitment.
    /// @param roundId The round identifier
    /// @param player The player address
    /// @param choice The player's revealed choice
    /// @param secret The secret used in commitment
    /// @return revealedChoice The validated choice
    function _reveal(
        uint256 roundId,
        address player,
        uint8 choice,
        bytes32 secret
    ) internal returns (uint8 revealedChoice) {
        Commitment storage c = _commitments[roundId][player];

        if (c.amount == 0) revert NotCommitted();
        if (c.revealed) revert AlreadyRevealed();

        // Verify the reveal matches the commitment
        bytes32 expected = keccak256(abi.encode(choice, secret, player));
        if (expected != c.hash) revert InvalidReveal();

        c.revealed = true;
        c.revealedChoice = choice;

        emit Revealed(roundId, player, choice);
        return choice;
    }

    /// @notice Forfeit a player's unrevealed commitment
    /// @dev Call after reveal period ends for players who didn't reveal.
    ///      The forfeited amount should be burned or added to winners' pool.
    /// @param roundId The round identifier
    /// @param player The player address
    /// @return amount The forfeited amount (0 if already revealed or no commitment)
    function _forfeit(uint256 roundId, address player) internal returns (uint128 amount) {
        Commitment storage c = _commitments[roundId][player];

        // Nothing to forfeit if no commitment or already revealed
        if (c.amount == 0 || c.revealed) return 0;

        amount = c.amount;
        // Clear amount to prevent double-forfeit
        c.amount = 0;

        emit Forfeited(roundId, player, amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Check if a player has an active commitment (with stake at risk)
    /// @dev Returns false after forfeit since amount becomes 0.
    ///      Use `hasEverCommitted()` to check if a player submitted a commitment regardless of forfeit.
    /// @param roundId The round identifier
    /// @param player The player address
    /// @return committed True if player has active commitment with stake
    function hasCommitted(uint256 roundId, address player) external view returns (bool committed) {
        return _commitments[roundId][player].amount > 0;
    }

    /// @notice Check if a player ever submitted a commitment (even if forfeited)
    /// @dev Returns true even after forfeit since hash is never cleared.
    /// @param roundId The round identifier
    /// @param player The player address
    /// @return everCommitted True if player ever submitted a commitment hash
    function hasEverCommitted(uint256 roundId, address player) external view returns (bool everCommitted) {
        return _commitments[roundId][player].hash != bytes32(0);
    }

    /// @notice Check if a player has revealed their commitment
    /// @param roundId The round identifier
    /// @param player The player address
    /// @return revealed True if player has revealed
    function hasRevealed(uint256 roundId, address player) external view returns (bool revealed) {
        return _commitments[roundId][player].revealed;
    }

    /// @notice Get a player's commitment details
    /// @param roundId The round identifier
    /// @param player The player address
    /// @return amount The bet amount
    /// @return revealed Whether the commitment was revealed
    /// @return revealedChoice The revealed choice (255 if not revealed)
    function getCommitment(
        uint256 roundId,
        address player
    ) external view returns (uint128 amount, bool revealed, uint8 revealedChoice) {
        Commitment storage c = _commitments[roundId][player];
        return (c.amount, c.revealed, c.revealedChoice);
    }

    /// @notice Check if a player can still reveal (has commitment, not revealed)
    /// @param roundId The round identifier
    /// @param player The player address
    /// @return canReveal True if player can reveal
    function canReveal(uint256 roundId, address player) external view returns (bool) {
        Commitment storage c = _commitments[roundId][player];
        return c.amount > 0 && !c.revealed;
    }
}
