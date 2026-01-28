/**
 * Presale Types
 * ==============
 * TypeScript mirrors of GhostPresale + PresaleClaim contract types.
 * All bigint values match Solidity uint256 (18 decimal fixed-point where noted).
 */

// ════════════════════════════════════════════════════════════════
// CONTRACT ENUMS
// ════════════════════════════════════════════════════════════════

/** Matches GhostPresale.PricingMode */
export enum PricingMode {
	TRANCHE = 0,
	BONDING_CURVE = 1,
}

/** Matches GhostPresale.PresaleState */
export enum PresaleState {
	PENDING = 0,
	OPEN = 1,
	FINALIZED = 2,
	REFUNDING = 3,
}

// ════════════════════════════════════════════════════════════════
// CONTRACT STRUCTS
// ════════════════════════════════════════════════════════════════

export interface TrancheConfig {
	supply: bigint;
	pricePerToken: bigint; // 18-decimal UD60x18
}

export interface CurveConfig {
	startPrice: bigint; // 18-decimal UD60x18
	endPrice: bigint; // 18-decimal UD60x18
	totalSupply: bigint; // 18-decimal
}

export interface PresaleConfig {
	minContribution: bigint; // wei
	maxContribution: bigint; // wei
	maxPerWallet: bigint; // wei
	allowMultipleContributions: boolean;
	startTime: bigint; // unix seconds
	endTime: bigint; // unix seconds
	emergencyDeadline: bigint; // unix seconds
}

export interface PresaleProgress {
	totalSold: bigint; // 18-decimal
	totalSupply: bigint; // 18-decimal
	totalRaised: bigint; // wei
	currentPrice: bigint; // 18-decimal UD60x18
	contributorCount: bigint;
}

export interface ContributionPreview {
	allocation: bigint; // 18-decimal $DATA tokens
	effectivePrice: bigint; // 18-decimal UD60x18
}

// ════════════════════════════════════════════════════════════════
// PAGE STATE
// ════════════════════════════════════════════════════════════════

/**
 * Derived page state from contract reads.
 * Determines which UI section to render.
 */
export type PresalePageState =
	| 'NOT_STARTED' // PENDING or before startTime
	| 'LIVE' // OPEN + within time bounds
	| 'SOLD_OUT' // All supply allocated
	| 'ENDED' // FINALIZED or past endTime
	| 'REFUNDING' // REFUNDING state
	| 'CLAIM_ACTIVE' // PresaleClaim deployed + claiming enabled
	| 'CLAIMED'; // User already claimed

// ════════════════════════════════════════════════════════════════
// FEED EVENTS
// ════════════════════════════════════════════════════════════════

/** Decoded Contributed event from GhostPresale */
export interface ContributedEvent {
	contributor: `0x${string}`;
	ethAmount: bigint; // wei
	allocation: bigint; // 18-decimal $DATA
	totalContributed: bigint; // wei — contributor's cumulative
	totalSold: bigint; // 18-decimal — global cumulative
	timestamp: number; // unix seconds (from block)
	txHash: `0x${string}`;
}

/** Decoded TrancheCompleted event */
export interface TrancheCompletedEvent {
	trancheIndex: bigint;
	trancheSupply: bigint;
	timestamp: number;
	txHash: `0x${string}`;
}

// ════════════════════════════════════════════════════════════════
// USER STATE
// ════════════════════════════════════════════════════════════════

/** Aggregated user position in the presale */
export interface UserPresalePosition {
	allocation: bigint; // 18-decimal $DATA
	contributed: bigint; // wei ETH
	hasClaimed: boolean;
	claimable: bigint; // 18-decimal $DATA (0 if not claim phase)
}

// ════════════════════════════════════════════════════════════════
// CONSTANTS
// ════════════════════════════════════════════════════════════════

/** Whale threshold in ETH (contributions above this get 🐋 in feed) */
export const WHALE_THRESHOLD_ETH = 1n * 10n ** 18n; // 1 ETH

/** Polling interval for contract reads (ms) */
export const POLL_INTERVAL_MS = 5_000;

/** Boot sequence localStorage key */
export const BOOT_SEEN_KEY = 'ghostnet:presale:boot-seen';
