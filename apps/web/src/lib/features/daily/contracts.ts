/**
 * DailyOps Contract Interactions
 * ==============================
 * Low-level viem/wagmi functions for interacting with the DailyOps contract.
 * This module provides type-safe read/write operations.
 *
 * SSR-SAFE: All browser APIs are guarded
 */

import { browser } from '$app/environment';
import {
	readContract,
	writeContract,
	waitForTransactionReceipt,
	watchContractEvent,
} from '@wagmi/core';
import { formatUnits, parseUnits, type Address } from 'viem';
import { requireConfig } from '$lib/web3/config';
import { dailyOpsAbi, dataTokenAbi, getContractAddress } from '$lib/web3/abis';
import { wallet } from '$lib/web3/wallet.svelte';

// ════════════════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════════════════

/** Raw streak data from contract */
export interface RawPlayerStreak {
	currentStreak: number;
	longestStreak: number;
	lastClaimDay: bigint;
	shieldExpiryDay: bigint;
	totalClaimed: bigint;
	totalMissionsCompleted: bigint;
}

/** Raw badge data from contract */
export interface RawBadge {
	badgeId: `0x${string}`;
	earnedAt: bigint;
}

/** Claim parameters */
export interface ClaimParams {
	day: bigint;
	missionId: `0x${string}`;
	rewardAmount: bigint;
	nonce: `0x${string}`;
	signature: `0x${string}`;
}

// ════════════════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════════════════

/**
 * Get contract address for DailyOps or throw
 */
function requireDailyOpsAddress(): `0x${string}` {
	const chainId = wallet.chainId;
	if (!chainId) throw new Error('Not connected to a chain');

	const address = getContractAddress(chainId, 'dailyOps');
	if (!address) throw new Error(`DailyOps not deployed on chain ${chainId}`);

	return address;
}

/**
 * Get DATA token address or throw
 */
function requireDataTokenAddress(): `0x${string}` {
	const chainId = wallet.chainId;
	if (!chainId) throw new Error('Not connected to a chain');

	const address = getContractAddress(chainId, 'dataToken');
	if (!address) throw new Error(`DataToken not deployed on chain ${chainId}`);

	return address;
}

/**
 * Format DATA amount for display (18 decimals)
 */
export function formatData(amount: bigint, decimals = 2): string {
	return parseFloat(formatUnits(amount, 18)).toFixed(decimals);
}

/**
 * Parse DATA amount from user input
 */
export function parseData(amount: string): bigint {
	return parseUnits(amount, 18);
}

// ════════════════════════════════════════════════════════════════════════════
// READ FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════

/**
 * Get player's streak data
 */
export async function getStreak(player: Address): Promise<RawPlayerStreak> {
	if (!browser) throw new Error('Cannot call getStreak on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	const result = await readContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'getStreak',
		args: [player],
	});

	// Contract returns struct as object
	const streak = result as {
		currentStreak: number;
		longestStreak: number;
		lastClaimDay: bigint;
		shieldExpiryDay: bigint;
		totalClaimed: bigint;
		totalMissionsCompleted: bigint;
	};

	return {
		currentStreak: streak.currentStreak,
		longestStreak: streak.longestStreak,
		lastClaimDay: streak.lastClaimDay,
		shieldExpiryDay: streak.shieldExpiryDay,
		totalClaimed: streak.totalClaimed,
		totalMissionsCompleted: streak.totalMissionsCompleted,
	};
}

/**
 * Get player's badges
 */
export async function getBadges(player: Address): Promise<RawBadge[]> {
	if (!browser) throw new Error('Cannot call getBadges on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	const result = await readContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'getBadges',
		args: [player],
	});

	const badges = result as Array<{ badgeId: `0x${string}`; earnedAt: bigint }>;
	return badges.map((b) => ({
		badgeId: b.badgeId,
		earnedAt: b.earnedAt,
	}));
}

/**
 * Get current UTC day number
 */
export async function getCurrentDay(): Promise<bigint> {
	if (!browser) throw new Error('Cannot call getCurrentDay on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return readContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'getCurrentDay',
	}) as Promise<bigint>;
}

/**
 * Check if player has claimed for a specific day
 */
export async function hasClaimedDay(player: Address, day: bigint): Promise<boolean> {
	if (!browser) throw new Error('Cannot call hasClaimedDay on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return readContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'hasClaimedDay',
		args: [player, day],
	}) as Promise<boolean>;
}

/**
 * Check if player's shield is active
 */
export async function isShieldActive(player: Address): Promise<boolean> {
	if (!browser) throw new Error('Cannot call isShieldActive on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return readContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'isShieldActive',
		args: [player],
	}) as Promise<boolean>;
}

/**
 * Get death rate reduction for a player (in basis points)
 */
export async function getDeathRateReduction(player: Address): Promise<number> {
	if (!browser) throw new Error('Cannot call getDeathRateReduction on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return readContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'getDeathRateReduction',
		args: [player],
	}) as Promise<number>;
}

/**
 * Get treasury balance
 */
export async function getTreasuryBalance(): Promise<bigint> {
	if (!browser) throw new Error('Cannot call getTreasuryBalance on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return readContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'getTreasuryBalance',
	}) as Promise<bigint>;
}

/**
 * Get total rewards distributed
 */
export async function getTotalDistributed(): Promise<bigint> {
	if (!browser) throw new Error('Cannot call getTotalDistributed on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return readContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'totalDistributed',
	}) as Promise<bigint>;
}

/**
 * Get total tokens burned (from shield purchases)
 */
export async function getTotalBurned(): Promise<bigint> {
	if (!browser) throw new Error('Cannot call getTotalBurned on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return readContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'totalBurned',
	}) as Promise<bigint>;
}

/**
 * Check if a nonce has been used
 */
export async function isNonceUsed(nonce: `0x${string}`): Promise<boolean> {
	if (!browser) throw new Error('Cannot call isNonceUsed on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return readContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'usedNonces',
		args: [nonce],
	}) as Promise<boolean>;
}

/**
 * Check if a milestone has been claimed
 */
export async function isMilestoneClaimed(player: Address, milestone: number): Promise<boolean> {
	if (!browser) throw new Error('Cannot call isMilestoneClaimed on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return readContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'milestonesClaimed',
		args: [player, milestone],
	}) as Promise<boolean>;
}

/**
 * Get player's DATA token balance
 */
export async function getDataBalance(player: Address): Promise<bigint> {
	if (!browser) throw new Error('Cannot call getDataBalance on server');

	const config = requireConfig();
	const dataTokenAddress = requireDataTokenAddress();

	return readContract(config, {
		address: dataTokenAddress,
		abi: dataTokenAbi,
		functionName: 'balanceOf',
		args: [player],
	}) as Promise<bigint>;
}

/**
 * Get player's DATA allowance for DailyOps
 */
export async function getDataAllowance(player: Address): Promise<bigint> {
	if (!browser) throw new Error('Cannot call getDataAllowance on server');

	const config = requireConfig();
	const dataTokenAddress = requireDataTokenAddress();
	const dailyOpsAddress = requireDailyOpsAddress();

	return readContract(config, {
		address: dataTokenAddress,
		abi: dataTokenAbi,
		functionName: 'allowance',
		args: [player, dailyOpsAddress],
	}) as Promise<bigint>;
}

// ════════════════════════════════════════════════════════════════════════════
// WRITE FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════

/**
 * Approve DATA tokens for DailyOps (for shield purchases)
 */
export async function approveDataForDailyOps(amount: bigint): Promise<`0x${string}`> {
	if (!browser) throw new Error('Cannot call approveDataForDailyOps on server');

	const config = requireConfig();
	const dataTokenAddress = requireDataTokenAddress();
	const dailyOpsAddress = requireDailyOpsAddress();

	const hash = await writeContract(config, {
		address: dataTokenAddress,
		abi: dataTokenAbi,
		functionName: 'approve',
		args: [dailyOpsAddress, amount],
	});

	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Claim daily reward with server-signed authorization
 */
export async function claimDailyReward(params: ClaimParams): Promise<`0x${string}`> {
	if (!browser) throw new Error('Cannot call claimDailyReward on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	const hash = await writeContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'claimDailyReward',
		args: [params.day, params.missionId, params.rewardAmount, params.nonce, params.signature],
	});

	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Purchase a streak shield (burns DATA tokens)
 */
export async function purchaseShield(days: 1 | 7): Promise<`0x${string}`> {
	if (!browser) throw new Error('Cannot call purchaseShield on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	const hash = await writeContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'purchaseShield',
		args: [days],
	});

	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Fund the treasury (for reward distribution)
 */
export async function fundTreasury(amount: bigint): Promise<`0x${string}`> {
	if (!browser) throw new Error('Cannot call fundTreasury on server');

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	const hash = await writeContract(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		functionName: 'fundTreasury',
		args: [amount],
	});

	await waitForTransactionReceipt(config, { hash });
	return hash;
}

// ════════════════════════════════════════════════════════════════════════════
// EVENT TYPES
// ════════════════════════════════════════════════════════════════════════════

export interface DailyRewardClaimedEvent {
	player: Address;
	day: bigint;
	missionId: `0x${string}`;
	reward: bigint;
	newStreak: number;
}

export interface MilestoneReachedEvent {
	player: Address;
	streak: number;
	bonusReward: bigint;
}

export interface BadgeEarnedEvent {
	player: Address;
	badgeId: `0x${string}`;
}

export interface StreakBrokenEvent {
	player: Address;
	previousStreak: number;
}

export interface ShieldPurchasedEvent {
	player: Address;
	days: number;
	expiryDay: bigint;
	cost: bigint;
}

// ════════════════════════════════════════════════════════════════════════════
// EVENT ARGUMENT TYPES (for type-safe event parsing)
// ════════════════════════════════════════════════════════════════════════════

interface DailyRewardClaimedArgs {
	player: Address;
	day: bigint;
	missionId: `0x${string}`;
	reward: bigint;
	newStreak: number;
}

interface MilestoneReachedArgs {
	player: Address;
	streak: number;
	bonusReward: bigint;
}

interface BadgeEarnedArgs {
	player: Address;
	badgeId: `0x${string}`;
}

interface StreakBrokenArgs {
	player: Address;
	previousStreak: number;
}

interface ShieldPurchasedArgs {
	player: Address;
	days_: number;
	expiryDay: bigint;
	cost: bigint;
}

// ════════════════════════════════════════════════════════════════════════════
// EVENT WATCHERS
// ════════════════════════════════════════════════════════════════════════════

/**
 * Watch for DailyRewardClaimed events
 */
export function watchDailyRewardClaimed(
	callback: (event: DailyRewardClaimedEvent) => void,
	player?: Address
): () => void {
	if (!browser) return () => {};

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return watchContractEvent(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		eventName: 'DailyRewardClaimed',
		args: player ? { player } : undefined,
		onLogs: (logs) => {
			for (const log of logs) {
				const args = (log as unknown as { args: DailyRewardClaimedArgs }).args;
				callback({
					player: args.player,
					day: args.day,
					missionId: args.missionId,
					reward: args.reward,
					newStreak: args.newStreak,
				});
			}
		},
	});
}

/**
 * Watch for MilestoneReached events
 */
export function watchMilestoneReached(
	callback: (event: MilestoneReachedEvent) => void,
	player?: Address
): () => void {
	if (!browser) return () => {};

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return watchContractEvent(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		eventName: 'MilestoneReached',
		args: player ? { player } : undefined,
		onLogs: (logs) => {
			for (const log of logs) {
				const args = (log as unknown as { args: MilestoneReachedArgs }).args;
				callback({
					player: args.player,
					streak: args.streak,
					bonusReward: args.bonusReward,
				});
			}
		},
	});
}

/**
 * Watch for BadgeEarned events
 */
export function watchBadgeEarned(
	callback: (event: BadgeEarnedEvent) => void,
	player?: Address
): () => void {
	if (!browser) return () => {};

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return watchContractEvent(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		eventName: 'BadgeEarned',
		args: player ? { player } : undefined,
		onLogs: (logs) => {
			for (const log of logs) {
				const args = (log as unknown as { args: BadgeEarnedArgs }).args;
				callback({
					player: args.player,
					badgeId: args.badgeId,
				});
			}
		},
	});
}

/**
 * Watch for StreakBroken events
 */
export function watchStreakBroken(
	callback: (event: StreakBrokenEvent) => void,
	player?: Address
): () => void {
	if (!browser) return () => {};

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return watchContractEvent(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		eventName: 'StreakBroken',
		args: player ? { player } : undefined,
		onLogs: (logs) => {
			for (const log of logs) {
				const args = (log as unknown as { args: StreakBrokenArgs }).args;
				callback({
					player: args.player,
					previousStreak: args.previousStreak,
				});
			}
		},
	});
}

/**
 * Watch for ShieldPurchased events
 */
export function watchShieldPurchased(
	callback: (event: ShieldPurchasedEvent) => void,
	player?: Address
): () => void {
	if (!browser) return () => {};

	const config = requireConfig();
	const dailyOpsAddress = requireDailyOpsAddress();

	return watchContractEvent(config, {
		address: dailyOpsAddress,
		abi: dailyOpsAbi,
		eventName: 'ShieldPurchased',
		args: player ? { player } : undefined,
		onLogs: (logs) => {
			for (const log of logs) {
				const args = (log as unknown as { args: ShieldPurchasedArgs }).args;
				callback({
					player: args.player,
					days: args.days_,
					expiryDay: args.expiryDay,
					cost: args.cost,
				});
			}
		},
	});
}

// ════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ════════════════════════════════════════════════════════════════════════════

/**
 * Calculate UTC day number from timestamp
 */
export function timestampToDay(timestamp: number): bigint {
	return BigInt(Math.floor(timestamp / 86400000));
}

/**
 * Convert UTC day number to timestamp (start of day)
 */
export function dayToTimestamp(day: bigint): number {
	return Number(day) * 86400000;
}

/**
 * Get current UTC day number (client-side calculation)
 */
export function getCurrentDayLocal(): bigint {
	return BigInt(Math.floor(Date.now() / 86400000));
}

/**
 * Calculate time until next day reset
 */
export function getTimeUntilReset(): number {
	const now = Date.now();
	const nextDayStart = (Math.floor(now / 86400000) + 1) * 86400000;
	return nextDayStart - now;
}

/**
 * Format time until reset as HH:MM:SS
 */
export function formatTimeUntilReset(): string {
	const ms = getTimeUntilReset();
	const hours = Math.floor(ms / 3600000);
	const minutes = Math.floor((ms % 3600000) / 60000);
	const seconds = Math.floor((ms % 60000) / 1000);
	return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}
