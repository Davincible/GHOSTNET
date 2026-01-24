/**
 * Hash Crash Contract Interactions
 * =================================
 * Read/write helpers for the HashCrash smart contract.
 *
 * ARCHITECTURE:
 * - HashCrash.sol is the game contract that manages rounds and bets
 * - ArcadeCore.sol holds all tokens and handles payouts
 * - Players approve ArcadeCore (not HashCrash) to spend their DATA tokens
 *
 * SSR-SAFE: All browser APIs are guarded
 */

import { browser } from '$app/environment';
import {
	readContract,
	writeContract,
	waitForTransactionReceipt,
	simulateContract,
	watchContractEvent,
} from '@wagmi/core';
import { parseUnits, formatUnits } from 'viem';
import { requireConfig } from '$lib/web3/config';
import { hashCrashAbi, arcadeCoreAbi, dataTokenAbi, getContractAddress } from '$lib/web3/abis';
import { wallet } from '$lib/web3/wallet.svelte';
import { parseContractError } from '$lib/web3/contracts';

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

/**
 * Session state enum (matches contract)
 */
export enum SessionState {
	NONE = 0,
	BETTING = 1,
	LOCKED = 2,
	ACTIVE = 3, // "Revealed" - ready for settlement
	SETTLED = 4,
	CANCELLED = 5,
	EXPIRED = 6,
}

/**
 * Round data from contract
 */
export interface RoundData {
	state: SessionState;
	bettingEndTime: bigint;
	prizePool: bigint;
	crashMultiplier: bigint; // 0 until revealed (100 = 1.00x)
	totalPaidOut: bigint;
	playerCount: bigint;
}

/**
 * Player bet data from contract
 */
export interface PlayerBetData {
	amount: bigint; // Net amount (after rake)
	grossAmount: bigint; // Original bet
	targetMultiplier: bigint; // Target in basis points (250 = 2.50x)
	settled: boolean;
}

/**
 * Seed info from contract
 */
export interface SeedInfo {
	seedBlock: bigint;
	revealed: boolean;
}

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

/**
 * Get contract address for HashCrash or throw
 */
function requireHashCrashAddress(): `0x${string}` {
	const chainId = wallet.chainId;
	if (!chainId) throw new Error('Not connected to a chain');

	const address = getContractAddress(chainId, 'hashCrash');
	if (!address) throw new Error(`HashCrash not deployed on chain ${chainId}`);

	return address;
}

/**
 * Get contract address for ArcadeCore or throw
 */
function requireArcadeCoreAddress(): `0x${string}` {
	const chainId = wallet.chainId;
	if (!chainId) throw new Error('Not connected to a chain');

	const address = getContractAddress(chainId, 'arcadeCore');
	if (!address) throw new Error(`ArcadeCore not deployed on chain ${chainId}`);

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
 * Format multiplier from contract format (100 = 1.00x) to display format
 */
export function formatMultiplier(value: bigint): number {
	return Number(value) / 100;
}

/**
 * Parse multiplier from display format to contract format
 */
export function parseMultiplier(value: number): bigint {
	return BigInt(Math.round(value * 100));
}

/**
 * Format DATA token amount (18 decimals)
 */
export function formatData(amount: bigint, decimals = 2): string {
	return Number(formatUnits(amount, 18)).toLocaleString(undefined, {
		minimumFractionDigits: decimals,
		maximumFractionDigits: decimals,
	});
}

/**
 * Parse DATA token amount (18 decimals)
 */
export function parseData(amount: string): bigint {
	return parseUnits(amount, 18);
}

// ════════════════════════════════════════════════════════════════
// READ FUNCTIONS
// ════════════════════════════════════════════════════════════════

/**
 * Get current round ID
 */
export async function getCurrentRoundId(): Promise<bigint> {
	if (!browser) return 0n;

	const config = requireConfig();
	const address = requireHashCrashAddress();

	return readContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'currentSessionId',
	}) as Promise<bigint>;
}

/**
 * Get round data
 */
export async function getRound(roundId: bigint): Promise<RoundData> {
	if (!browser) {
		return {
			state: SessionState.NONE,
			bettingEndTime: 0n,
			prizePool: 0n,
			crashMultiplier: 0n,
			totalPaidOut: 0n,
			playerCount: 0n,
		};
	}

	const config = requireConfig();
	const address = requireHashCrashAddress();

	const result = (await readContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'getRound',
		args: [roundId],
	})) as [number, bigint, bigint, bigint, bigint, bigint];

	return {
		state: result[0] as SessionState,
		bettingEndTime: result[1],
		prizePool: result[2],
		crashMultiplier: result[3],
		totalPaidOut: result[4],
		playerCount: result[5],
	};
}

/**
 * Get player's bet in a round
 */
export async function getPlayerBet(roundId: bigint, player: `0x${string}`): Promise<PlayerBetData> {
	if (!browser) {
		return {
			amount: 0n,
			grossAmount: 0n,
			targetMultiplier: 0n,
			settled: false,
		};
	}

	const config = requireConfig();
	const address = requireHashCrashAddress();

	const result = (await readContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'getPlayerBet',
		args: [roundId, player],
	})) as [bigint, bigint, bigint, boolean];

	return {
		amount: result[0],
		grossAmount: result[1],
		targetMultiplier: result[2],
		settled: result[3],
	};
}

/**
 * Get all players in a round
 */
export async function getRoundPlayers(roundId: bigint): Promise<`0x${string}`[]> {
	if (!browser) return [];

	const config = requireConfig();
	const address = requireHashCrashAddress();

	return readContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'getRoundPlayers',
		args: [roundId],
	}) as Promise<`0x${string}`[]>;
}

/**
 * Check if seed is ready for reveal
 */
export async function isSeedReady(roundId: bigint): Promise<boolean> {
	if (!browser) return false;

	const config = requireConfig();
	const address = requireHashCrashAddress();

	return readContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'isSeedReady',
		args: [roundId],
	}) as Promise<boolean>;
}

/**
 * Check if seed has expired
 */
export async function isSeedExpired(roundId: bigint): Promise<boolean> {
	if (!browser) return false;

	const config = requireConfig();
	const address = requireHashCrashAddress();

	return readContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'isSeedExpired',
		args: [roundId],
	}) as Promise<boolean>;
}

/**
 * Get seed info for a round
 */
export async function getSeedInfo(roundId: bigint): Promise<SeedInfo> {
	if (!browser) {
		return { seedBlock: 0n, revealed: false };
	}

	const config = requireConfig();
	const address = requireHashCrashAddress();

	const result = (await readContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'getSeedInfo',
		args: [roundId],
	})) as [bigint, boolean];

	return {
		seedBlock: result[0],
		revealed: result[1],
	};
}

/**
 * Get DATA token balance
 */
export async function getDataBalance(address: `0x${string}`): Promise<bigint> {
	if (!browser) return 0n;

	const config = requireConfig();
	const tokenAddress = requireDataTokenAddress();

	return readContract(config, {
		address: tokenAddress,
		abi: dataTokenAbi,
		functionName: 'balanceOf',
		args: [address],
	}) as Promise<bigint>;
}

/**
 * Get DATA token allowance for ArcadeCore
 */
export async function getArcadeCoreAllowance(owner: `0x${string}`): Promise<bigint> {
	if (!browser) return 0n;

	const config = requireConfig();
	const tokenAddress = requireDataTokenAddress();
	const arcadeCoreAddress = requireArcadeCoreAddress();

	return readContract(config, {
		address: tokenAddress,
		abi: dataTokenAbi,
		functionName: 'allowance',
		args: [owner, arcadeCoreAddress],
	}) as Promise<bigint>;
}

/**
 * Get player's withdrawable balance from ArcadeCore
 */
export async function getWithdrawableBalance(player: `0x${string}`): Promise<bigint> {
	if (!browser) return 0n;

	const config = requireConfig();
	const arcadeCoreAddress = requireArcadeCoreAddress();

	return readContract(config, {
		address: arcadeCoreAddress,
		abi: arcadeCoreAbi,
		functionName: 'pendingWithdrawals',
		args: [player],
	}) as Promise<bigint>;
}

// ════════════════════════════════════════════════════════════════
// WRITE FUNCTIONS
// ════════════════════════════════════════════════════════════════

/**
 * Approve DATA tokens for ArcadeCore
 * @param amount Amount to approve (or MaxUint256 for infinite)
 */
export async function approveDataForArcade(amount: bigint): Promise<`0x${string}`> {
	if (!browser) throw new Error('Browser required');

	const config = requireConfig();
	const tokenAddress = requireDataTokenAddress();
	const arcadeCoreAddress = requireArcadeCoreAddress();

	const { request } = await simulateContract(config, {
		address: tokenAddress,
		abi: dataTokenAbi,
		functionName: 'approve',
		args: [arcadeCoreAddress, amount],
	});

	const hash = await writeContract(config, request);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Start a new betting round
 * @returns Transaction hash
 */
export async function startRound(): Promise<`0x${string}`> {
	if (!browser) throw new Error('Browser required');

	const config = requireConfig();
	const address = requireHashCrashAddress();

	const { request } = await simulateContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'startRound',
	});

	const hash = await writeContract(config, request);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Place a bet with target multiplier
 * @param amount Bet amount in DATA (wei)
 * @param targetMultiplier Target multiplier (e.g., 2.5 for 2.50x)
 * @returns Transaction hash
 */
export async function placeBet(amount: bigint, targetMultiplier: number): Promise<`0x${string}`> {
	if (!browser) throw new Error('Browser required');

	const config = requireConfig();
	const address = requireHashCrashAddress();

	// Convert multiplier to contract format (2.5 -> 250)
	const targetBps = parseMultiplier(targetMultiplier);

	// Check allowance first
	const userAddress = wallet.address;
	if (!userAddress) throw new Error('Wallet not connected');

	const allowance = await getArcadeCoreAllowance(userAddress);
	if (allowance < amount) {
		// Approve max uint256 for convenience
		await approveDataForArcade(
			BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')
		);
	}

	const { request } = await simulateContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'placeBet',
		args: [amount, targetBps],
	});

	const hash = await writeContract(config, request);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Lock the current round (end betting phase)
 * @returns Transaction hash
 */
export async function lockRound(): Promise<`0x${string}`> {
	if (!browser) throw new Error('Browser required');

	const config = requireConfig();
	const address = requireHashCrashAddress();

	const { request } = await simulateContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'lockRound',
	});

	const hash = await writeContract(config, request);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Reveal the crash point
 * @returns Transaction hash
 */
export async function revealCrash(): Promise<`0x${string}`> {
	if (!browser) throw new Error('Browser required');

	const config = requireConfig();
	const address = requireHashCrashAddress();

	const { request } = await simulateContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'revealCrash',
	});

	const hash = await writeContract(config, request);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Settle all players in the current round
 * @returns Transaction hash
 */
export async function settleAll(): Promise<`0x${string}`> {
	if (!browser) throw new Error('Browser required');

	const config = requireConfig();
	const address = requireHashCrashAddress();

	const { request } = await simulateContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'settleAll',
	});

	const hash = await writeContract(config, request);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Withdraw winnings from ArcadeCore
 * @returns Transaction hash
 */
export async function withdraw(): Promise<`0x${string}`> {
	if (!browser) throw new Error('Browser required');

	const config = requireConfig();
	const arcadeCoreAddress = requireArcadeCoreAddress();

	const { request } = await simulateContract(config, {
		address: arcadeCoreAddress,
		abi: arcadeCoreAbi,
		functionName: 'withdraw',
	});

	const hash = await writeContract(config, request);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Handle expired round (refund players)
 * @returns Transaction hash
 */
export async function handleExpiredRound(): Promise<`0x${string}`> {
	if (!browser) throw new Error('Browser required');

	const config = requireConfig();
	const address = requireHashCrashAddress();

	const { request } = await simulateContract(config, {
		address,
		abi: hashCrashAbi,
		functionName: 'handleExpiredRound',
	});

	const hash = await writeContract(config, request);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

// ════════════════════════════════════════════════════════════════
// EVENT WATCHING
// ════════════════════════════════════════════════════════════════

// Event args types
interface BetPlacedArgs {
	roundId: bigint;
	player: `0x${string}`;
	amount: bigint;
	netAmount: bigint;
	targetMultiplier: bigint;
}

interface CrashPointRevealedArgs {
	roundId: bigint;
	crashMultiplier: bigint;
	seed: bigint;
}

interface PlayerWonArgs {
	roundId: bigint;
	player: `0x${string}`;
	targetMultiplier: bigint;
	payout: bigint;
}

interface PlayerLostArgs {
	roundId: bigint;
	player: `0x${string}`;
	targetMultiplier: bigint;
	crashMultiplier: bigint;
}

interface RoundStartedArgs {
	roundId: bigint;
	seedBlock: bigint;
	timestamp: bigint;
}

/**
 * Watch for BetPlaced events
 */
export function watchBetPlaced(
	onBetPlaced: (
		roundId: bigint,
		player: `0x${string}`,
		amount: bigint,
		netAmount: bigint,
		targetMultiplier: bigint
	) => void
): () => void {
	if (!browser) return () => {};

	const config = requireConfig();
	const address = requireHashCrashAddress();

	return watchContractEvent(config, {
		address,
		abi: hashCrashAbi,
		eventName: 'BetPlaced',
		onLogs: (logs) => {
			for (const log of logs) {
				const args = (log as unknown as { args: BetPlacedArgs }).args;
				onBetPlaced(args.roundId, args.player, args.amount, args.netAmount, args.targetMultiplier);
			}
		},
	});
}

/**
 * Watch for CrashPointRevealed events
 */
export function watchCrashPointRevealed(
	onRevealed: (roundId: bigint, crashMultiplier: bigint, seed: bigint) => void
): () => void {
	if (!browser) return () => {};

	const config = requireConfig();
	const address = requireHashCrashAddress();

	return watchContractEvent(config, {
		address,
		abi: hashCrashAbi,
		eventName: 'CrashPointRevealed',
		onLogs: (logs) => {
			for (const log of logs) {
				const args = (log as unknown as { args: CrashPointRevealedArgs }).args;
				onRevealed(args.roundId, args.crashMultiplier, args.seed);
			}
		},
	});
}

/**
 * Watch for PlayerWon events
 */
export function watchPlayerWon(
	onWon: (roundId: bigint, player: `0x${string}`, targetMultiplier: bigint, payout: bigint) => void
): () => void {
	if (!browser) return () => {};

	const config = requireConfig();
	const address = requireHashCrashAddress();

	return watchContractEvent(config, {
		address,
		abi: hashCrashAbi,
		eventName: 'PlayerWon',
		onLogs: (logs) => {
			for (const log of logs) {
				const args = (log as unknown as { args: PlayerWonArgs }).args;
				onWon(args.roundId, args.player, args.targetMultiplier, args.payout);
			}
		},
	});
}

/**
 * Watch for PlayerLost events
 */
export function watchPlayerLost(
	onLost: (
		roundId: bigint,
		player: `0x${string}`,
		targetMultiplier: bigint,
		crashMultiplier: bigint
	) => void
): () => void {
	if (!browser) return () => {};

	const config = requireConfig();
	const address = requireHashCrashAddress();

	return watchContractEvent(config, {
		address,
		abi: hashCrashAbi,
		eventName: 'PlayerLost',
		onLogs: (logs) => {
			for (const log of logs) {
				const args = (log as unknown as { args: PlayerLostArgs }).args;
				onLost(args.roundId, args.player, args.targetMultiplier, args.crashMultiplier);
			}
		},
	});
}

/**
 * Watch for RoundStarted events
 */
export function watchRoundStarted(
	onStarted: (roundId: bigint, seedBlock: bigint, timestamp: bigint) => void
): () => void {
	if (!browser) return () => {};

	const config = requireConfig();
	const address = requireHashCrashAddress();

	return watchContractEvent(config, {
		address,
		abi: hashCrashAbi,
		eventName: 'RoundStarted',
		onLogs: (logs) => {
			for (const log of logs) {
				const args = (log as unknown as { args: RoundStartedArgs }).args;
				onStarted(args.roundId, args.seedBlock, args.timestamp);
			}
		},
	});
}

// Re-export error parser for convenience
export { parseContractError };
