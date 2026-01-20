/**
 * Contract Interaction Utilities
 * ===============================
 * Read/write helpers for GHOSTNET contracts
 * 
 * SSR-SAFE: All browser APIs are guarded
 */

import { browser } from '$app/environment';
import {
	readContract,
	writeContract,
	waitForTransactionReceipt,
	simulateContract
} from '@wagmi/core';
import {
	formatUnits,
	parseUnits,
	UserRejectedRequestError,
	ContractFunctionExecutionError
} from 'viem';
import { requireConfig } from './config';
import { ghostCoreAbi, dataTokenAbi, deadPoolAbi, getContractAddress } from './abis';
import { wallet } from './wallet.svelte';

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

export interface Position {
	positionId: bigint;
	level: number;
	amount: bigint;
	entryTime: bigint;
	lastClaimTime: bigint;
	nextScanTime: bigint;
	ghostStreak: number;
	boostExpiry: bigint;
	boostMultiplier: number;
}

export interface LevelConfig {
	deathRate: number;
	scanInterval: bigint;
	baseYieldRate: bigint;
	minStake: bigint;
	levelCapacity: bigint;
}

export interface TransactionResult {
	hash: `0x${string}`;
	success: boolean;
	error?: string;
}

// ════════════════════════════════════════════════════════════════
// ERROR HANDLING
// ════════════════════════════════════════════════════════════════

/**
 * Parse contract errors into user-friendly messages
 */
export function parseContractError(err: unknown): string {
	if (err instanceof UserRejectedRequestError) {
		return 'Transaction cancelled by user';
	}
	if (err instanceof ContractFunctionExecutionError) {
		// Try to extract revert reason
		const reason = err.shortMessage || err.message;
		// Common contract errors
		if (reason.includes('InsufficientBalance')) return 'Insufficient token balance';
		if (reason.includes('InsufficientAllowance')) return 'Token approval required';
		if (reason.includes('NoActivePosition')) return 'No active position found';
		if (reason.includes('PositionLocked')) return 'Position is locked during scan period';
		if (reason.includes('BelowMinimum')) return 'Amount below minimum stake';
		if (reason.includes('ExceedsCapacity')) return 'Level capacity exceeded';
		return reason;
	}
	if (err instanceof Error) {
		return err.message;
	}
	return 'Transaction failed';
}

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

/**
 * Format $DATA token amount (18 decimals)
 */
export function formatData(amount: bigint, decimals = 2): string {
	return Number(formatUnits(amount, 18)).toLocaleString(undefined, {
		minimumFractionDigits: decimals,
		maximumFractionDigits: decimals
	});
}

/**
 * Parse $DATA token amount (18 decimals)
 */
export function parseData(amount: string): bigint {
	return parseUnits(amount, 18);
}

/**
 * Get contract address or throw
 */
function requireAddress(contract: 'ghostCore' | 'dataToken' | 'deadPool'): `0x${string}` {
	const chainId = wallet.chainId;
	if (!chainId) throw new Error('Not connected to a chain');

	const address = getContractAddress(chainId, contract);
	if (!address) throw new Error(`${contract} not deployed on chain ${chainId}`);

	return address;
}

/**
 * Guard for browser-only operations
 */
function requireBrowser(): void {
	if (!browser) throw new Error('Contract operations require browser environment');
}

// ════════════════════════════════════════════════════════════════
// DATA TOKEN READS
// ════════════════════════════════════════════════════════════════

/**
 * Get $DATA balance for an address
 */
export async function getDataBalance(address: `0x${string}`): Promise<bigint> {
	if (!browser) return 0n;

	const chainId = wallet.chainId;
	if (!chainId) return 0n;

	const tokenAddress = getContractAddress(chainId, 'dataToken');
	if (!tokenAddress) return 0n;

	const config = requireConfig();
	return readContract(config, {
		address: tokenAddress,
		abi: dataTokenAbi,
		functionName: 'balanceOf',
		args: [address]
	}) as Promise<bigint>;
}

/**
 * Get $DATA allowance for GhostCore
 */
export async function getDataAllowance(owner: `0x${string}`): Promise<bigint> {
	if (!browser) return 0n;

	const chainId = wallet.chainId;
	if (!chainId) return 0n;

	const tokenAddress = getContractAddress(chainId, 'dataToken');
	const ghostCoreAddress = getContractAddress(chainId, 'ghostCore');
	if (!tokenAddress || !ghostCoreAddress) return 0n;

	const config = requireConfig();
	return readContract(config, {
		address: tokenAddress,
		abi: dataTokenAbi,
		functionName: 'allowance',
		args: [owner, ghostCoreAddress]
	}) as Promise<bigint>;
}

// ════════════════════════════════════════════════════════════════
// DATA TOKEN WRITES
// ════════════════════════════════════════════════════════════════

/**
 * Approve $DATA for GhostCore
 */
export async function approveData(amount: bigint): Promise<`0x${string}`> {
	requireBrowser();
	const config = requireConfig();
	const ghostCoreAddress = requireAddress('ghostCore');
	const tokenAddress = requireAddress('dataToken');

	const { request } = await simulateContract(config, {
		address: tokenAddress,
		abi: dataTokenAbi,
		functionName: 'approve',
		args: [ghostCoreAddress, amount]
	});

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	const hash = await writeContract(config, request as any);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

// ════════════════════════════════════════════════════════════════
// GHOST CORE READS
// ════════════════════════════════════════════════════════════════

/**
 * Get user's position
 */
export async function getPosition(address: `0x${string}`): Promise<Position | null> {
	requireBrowser();
	const config = requireConfig();
	const ghostCoreAddress = requireAddress('ghostCore');

	const position = (await readContract(config, {
		address: ghostCoreAddress,
		abi: ghostCoreAbi,
		functionName: 'positions',
		args: [address]
	})) as [bigint, number, bigint, bigint, bigint, bigint, number, bigint, number];

	// Check if position exists (amount > 0)
	if (position[2] === 0n) return null;

	return {
		positionId: position[0],
		level: position[1],
		amount: position[2],
		entryTime: position[3],
		lastClaimTime: position[4],
		nextScanTime: position[5],
		ghostStreak: position[6],
		boostExpiry: position[7],
		boostMultiplier: position[8]
	};
}

/**
 * Get level configuration
 */
export async function getLevelConfig(level: number): Promise<LevelConfig> {
	requireBrowser();
	const config = requireConfig();
	const ghostCoreAddress = requireAddress('ghostCore');

	const levelConfig = (await readContract(config, {
		address: ghostCoreAddress,
		abi: ghostCoreAbi,
		functionName: 'levelConfigs',
		args: [level]
	})) as [number, bigint, bigint, bigint, bigint];

	return {
		deathRate: levelConfig[0],
		scanInterval: levelConfig[1],
		baseYieldRate: levelConfig[2],
		minStake: levelConfig[3],
		levelCapacity: levelConfig[4]
	};
}

/**
 * Get pending yield for a position
 */
export async function getPendingYield(address: `0x${string}`): Promise<bigint> {
	requireBrowser();
	const config = requireConfig();
	const ghostCoreAddress = requireAddress('ghostCore');

	return readContract(config, {
		address: ghostCoreAddress,
		abi: ghostCoreAbi,
		functionName: 'calculatePendingYield',
		args: [address]
	}) as Promise<bigint>;
}

/**
 * Get total value locked across all levels
 */
export async function getTotalStaked(): Promise<bigint> {
	requireBrowser();
	const config = requireConfig();
	const ghostCoreAddress = requireAddress('ghostCore');

	return readContract(config, {
		address: ghostCoreAddress,
		abi: ghostCoreAbi,
		functionName: 'totalStaked'
	}) as Promise<bigint>;
}

/**
 * Get staked amount for a specific level
 */
export async function getLevelStaked(level: number): Promise<bigint> {
	requireBrowser();
	const config = requireConfig();
	const ghostCoreAddress = requireAddress('ghostCore');

	return readContract(config, {
		address: ghostCoreAddress,
		abi: ghostCoreAbi,
		functionName: 'levelStaked',
		args: [level]
	}) as Promise<bigint>;
}

// ════════════════════════════════════════════════════════════════
// GHOST CORE WRITES
// ════════════════════════════════════════════════════════════════

/**
 * Jack into a level (stake)
 */
export async function jackIn(level: number, amount: bigint): Promise<`0x${string}`> {
	requireBrowser();
	const config = requireConfig();
	const ghostCoreAddress = requireAddress('ghostCore');

	// Check and set allowance if needed
	const address = wallet.address;
	if (!address) throw new Error('Wallet not connected');

	const allowance = await getDataAllowance(address);
	if (allowance < amount) {
		await approveData(amount);
	}

	const { request } = await simulateContract(config, {
		address: ghostCoreAddress,
		abi: ghostCoreAbi,
		functionName: 'jackIn',
		args: [level, amount]
	});

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	const hash = await writeContract(config, request as any);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Extract position (unstake + claim)
 */
export async function extract(): Promise<`0x${string}`> {
	requireBrowser();
	const config = requireConfig();
	const ghostCoreAddress = requireAddress('ghostCore');

	const { request } = await simulateContract(config, {
		address: ghostCoreAddress,
		abi: ghostCoreAbi,
		functionName: 'extract'
	});

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	const hash = await writeContract(config, request as any);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Claim rewards without extracting
 */
export async function claimRewards(): Promise<`0x${string}`> {
	requireBrowser();
	const config = requireConfig();
	const ghostCoreAddress = requireAddress('ghostCore');

	const { request } = await simulateContract(config, {
		address: ghostCoreAddress,
		abi: ghostCoreAbi,
		functionName: 'claimRewards'
	});

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	const hash = await writeContract(config, request as any);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Upgrade to a higher risk level
 */
export async function upgradeLevel(newLevel: number): Promise<`0x${string}`> {
	requireBrowser();
	const config = requireConfig();
	const ghostCoreAddress = requireAddress('ghostCore');

	const { request } = await simulateContract(config, {
		address: ghostCoreAddress,
		abi: ghostCoreAbi,
		functionName: 'upgradeLevel',
		args: [newLevel]
	});

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	const hash = await writeContract(config, request as any);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Increase stake amount
 */
export async function increaseStake(additionalAmount: bigint): Promise<`0x${string}`> {
	requireBrowser();
	const config = requireConfig();
	const ghostCoreAddress = requireAddress('ghostCore');

	// Check and set allowance if needed
	const address = wallet.address;
	if (!address) throw new Error('Wallet not connected');

	const allowance = await getDataAllowance(address);
	if (allowance < additionalAmount) {
		await approveData(additionalAmount);
	}

	const { request } = await simulateContract(config, {
		address: ghostCoreAddress,
		abi: ghostCoreAbi,
		functionName: 'increaseStake',
		args: [additionalAmount]
	});

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	const hash = await writeContract(config, request as any);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

// ════════════════════════════════════════════════════════════════
// DEAD POOL READS
// ════════════════════════════════════════════════════════════════

/**
 * Get current round info
 */
export async function getCurrentRound(): Promise<{
	roundNumber: bigint;
	level: number;
	line: bigint;
	startTime: bigint;
	endTime: bigint;
	totalUnder: bigint;
	totalOver: bigint;
	resolved: boolean;
	outcome: number;
}> {
	requireBrowser();
	const config = requireConfig();
	const deadPoolAddress = requireAddress('deadPool');

	const roundNumber = (await readContract(config, {
		address: deadPoolAddress,
		abi: deadPoolAbi,
		functionName: 'currentRound'
	})) as bigint;

	const round = (await readContract(config, {
		address: deadPoolAddress,
		abi: deadPoolAbi,
		functionName: 'rounds',
		args: [roundNumber]
	})) as [number, bigint, bigint, bigint, bigint, bigint, boolean, number];

	return {
		roundNumber,
		level: round[0],
		line: round[1],
		startTime: round[2],
		endTime: round[3],
		totalUnder: round[4],
		totalOver: round[5],
		resolved: round[6],
		outcome: round[7]
	};
}

// ════════════════════════════════════════════════════════════════
// DEAD POOL WRITES
// ════════════════════════════════════════════════════════════════

/**
 * Place a bet on the current round
 */
export async function placeBet(isOver: boolean, amount: bigint): Promise<`0x${string}`> {
	requireBrowser();
	const config = requireConfig();
	const deadPoolAddress = requireAddress('deadPool');
	const tokenAddress = requireAddress('dataToken');

	// Check and set allowance
	const address = wallet.address;
	if (!address) throw new Error('Wallet not connected');

	const allowance = (await readContract(config, {
		address: tokenAddress,
		abi: dataTokenAbi,
		functionName: 'allowance',
		args: [address, deadPoolAddress]
	})) as bigint;

	if (allowance < amount) {
		const { request: approveRequest } = await simulateContract(config, {
			address: tokenAddress,
			abi: dataTokenAbi,
			functionName: 'approve',
			args: [deadPoolAddress, amount]
		});
		// eslint-disable-next-line @typescript-eslint/no-explicit-any
		const approveHash = await writeContract(config, approveRequest as any);
		await waitForTransactionReceipt(config, { hash: approveHash });
	}

	const { request } = await simulateContract(config, {
		address: deadPoolAddress,
		abi: deadPoolAbi,
		functionName: 'placeBet',
		args: [isOver, amount]
	});

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	const hash = await writeContract(config, request as any);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/**
 * Claim winnings from a resolved round
 */
export async function claimWinnings(roundNumber: bigint): Promise<`0x${string}`> {
	requireBrowser();
	const config = requireConfig();
	const deadPoolAddress = requireAddress('deadPool');

	const { request } = await simulateContract(config, {
		address: deadPoolAddress,
		abi: deadPoolAbi,
		functionName: 'claim',
		args: [roundNumber]
	});

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	const hash = await writeContract(config, request as any);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}
