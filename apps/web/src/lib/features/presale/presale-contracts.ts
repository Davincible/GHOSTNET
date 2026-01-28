/**
 * Presale Contract Interactions
 * ==============================
 * Read/write helpers for GhostPresale + PresaleClaim.
 *
 * SSR-SAFE: All browser APIs are guarded.
 * Follows the same pattern as web3/contracts.ts.
 */

import { browser } from '$app/environment';
import {
	readContract,
	writeContract,
	waitForTransactionReceipt,
	simulateContract,
} from '@wagmi/core';
import { requireConfig } from '$lib/web3/config';
import { ghostPresaleAbi, presaleClaimAbi, getContractAddress } from '$lib/web3/abis';
import { wallet } from '$lib/web3/wallet.svelte';
import type {
	PresaleConfig,
	PresaleProgress,
	CurveConfig,
	TrancheConfig,
	ContributionPreview,
} from './types';
import { PricingMode, PresaleState } from './types';

// ════════════════════════════════════════════════════════════════
// ADDRESS HELPERS
// ════════════════════════════════════════════════════════════════

function getPresaleAddress(): `0x${string}` | null {
	const chainId = wallet.chainId;
	if (!chainId) return null;
	return getContractAddress(chainId, 'ghostPresale');
}

function getClaimAddress(): `0x${string}` | null {
	const chainId = wallet.chainId;
	if (!chainId) return null;
	return getContractAddress(chainId, 'presaleClaim');
}

function requirePresaleAddress(): `0x${string}` {
	const addr = getPresaleAddress();
	if (!addr) throw new Error('GhostPresale not deployed on current chain');
	return addr;
}

function requireClaimAddress(): `0x${string}` {
	const addr = getClaimAddress();
	if (!addr) throw new Error('PresaleClaim not deployed on current chain');
	return addr;
}

// ════════════════════════════════════════════════════════════════
// PRESALE READS
// ════════════════════════════════════════════════════════════════

/** Current presale state (PENDING, OPEN, FINALIZED, REFUNDING) */
export async function getPresaleState(): Promise<PresaleState> {
	if (!browser) return PresaleState.PENDING;
	const addr = getPresaleAddress();
	if (!addr) return PresaleState.PENDING;

	const config = requireConfig();
	const result = await readContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'state',
	});
	return Number(result) as PresaleState;
}

/** Pricing mode (TRANCHE or BONDING_CURVE) — immutable */
export async function getPricingMode(): Promise<PricingMode> {
	if (!browser) return PricingMode.TRANCHE;
	const addr = getPresaleAddress();
	if (!addr) return PricingMode.TRANCHE;

	const config = requireConfig();
	const result = await readContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'pricingMode',
	});
	return Number(result) as PricingMode;
}

/** Current presale config */
export async function getPresaleConfig(): Promise<PresaleConfig> {
	if (!browser) return defaultConfig();

	const addr = getPresaleAddress();
	if (!addr) return defaultConfig();

	const config = requireConfig();
	const result = (await readContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'config',
	})) as [bigint, bigint, bigint, boolean, bigint, bigint, bigint];

	return {
		minContribution: result[0],
		maxContribution: result[1],
		maxPerWallet: result[2],
		allowMultipleContributions: result[3],
		startTime: result[4],
		endTime: result[5],
		emergencyDeadline: result[6],
	};
}

/** Aggregate progress: totalSold, totalSupply, totalRaised, currentPrice, contributorCount */
export async function getPresaleProgress(): Promise<PresaleProgress> {
	if (!browser) return defaultProgress();

	const addr = getPresaleAddress();
	if (!addr) return defaultProgress();

	const config = requireConfig();
	const result = (await readContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'progress',
	})) as [bigint, bigint, bigint, bigint, bigint];

	return {
		totalSold: result[0],
		totalSupply: result[1],
		totalRaised: result[2],
		currentPrice: result[3],
		contributorCount: result[4],
	};
}

/** Preview contribution: returns (allocation, effectivePrice) for a given ETH amount */
export async function previewContribution(ethAmount: bigint): Promise<ContributionPreview> {
	if (!browser) return { allocation: 0n, effectivePrice: 0n };

	const config = requireConfig();
	const addr = requirePresaleAddress();

	const result = (await readContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'preview',
		args: [ethAmount],
	})) as [bigint, bigint];

	return {
		allocation: result[0],
		effectivePrice: result[1],
	};
}

/** User's $DATA allocation */
export async function getUserAllocation(account: `0x${string}`): Promise<bigint> {
	if (!browser) return 0n;

	const addr = getPresaleAddress();
	if (!addr) return 0n;

	const config = requireConfig();
	return readContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'allocations',
		args: [account],
	}) as Promise<bigint>;
}

/** User's ETH contribution */
export async function getUserContribution(account: `0x${string}`): Promise<bigint> {
	if (!browser) return 0n;

	const addr = getPresaleAddress();
	if (!addr) return 0n;

	const config = requireConfig();
	return readContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'contributions',
		args: [account],
	}) as Promise<bigint>;
}

/** Current price (UD60x18) */
export async function getCurrentPrice(): Promise<bigint> {
	if (!browser) return 0n;

	const addr = getPresaleAddress();
	if (!addr) return 0n;

	const config = requireConfig();
	return readContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'currentPrice',
	}) as Promise<bigint>;
}

/** Bonding curve config */
export async function getCurveConfig(): Promise<CurveConfig> {
	if (!browser) return { startPrice: 0n, endPrice: 0n, totalSupply: 0n };

	const addr = getPresaleAddress();
	if (!addr) return { startPrice: 0n, endPrice: 0n, totalSupply: 0n };

	const config = requireConfig();
	const result = (await readContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'curve',
	})) as [bigint, bigint, bigint];

	return {
		startPrice: result[0],
		endPrice: result[1],
		totalSupply: result[2],
	};
}

/** Get tranche at index */
export async function getTranche(index: number): Promise<TrancheConfig> {
	if (!browser) return { supply: 0n, pricePerToken: 0n };

	const config = requireConfig();
	const addr = requirePresaleAddress();

	const result = (await readContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'tranches',
		args: [BigInt(index)],
	})) as [bigint, bigint];

	return {
		supply: result[0],
		pricePerToken: result[1],
	};
}

/** Total presale supply */
export async function getTotalPresaleSupply(): Promise<bigint> {
	if (!browser) return 0n;

	const addr = getPresaleAddress();
	if (!addr) return 0n;

	const config = requireConfig();
	return readContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'totalPresaleSupply',
	}) as Promise<bigint>;
}

// ════════════════════════════════════════════════════════════════
// PRESALE WRITES
// ════════════════════════════════════════════════════════════════

/**
 * Contribute ETH to the presale.
 * @param ethAmount - Wei to send
 * @param minAllocation - Minimum $DATA tokens expected (slippage protection)
 * @returns Transaction hash
 */
export async function contribute(
	ethAmount: bigint,
	minAllocation: bigint,
): Promise<`0x${string}`> {
	if (!browser) throw new Error('Requires browser');

	const config = requireConfig();
	const addr = requirePresaleAddress();

	const { request } = await simulateContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'contribute',
		args: [minAllocation],
		value: ethAmount,
	});

	const hash = await writeContract(config, request);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

/** Refund ETH (only in REFUNDING state) */
export async function refund(): Promise<`0x${string}`> {
	if (!browser) throw new Error('Requires browser');

	const config = requireConfig();
	const addr = requirePresaleAddress();

	const { request } = await simulateContract(config, {
		address: addr,
		abi: ghostPresaleAbi,
		functionName: 'refund',
	});

	const hash = await writeContract(config, request);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

// ════════════════════════════════════════════════════════════════
// CLAIM READS
// ════════════════════════════════════════════════════════════════

/** Whether claiming is enabled on PresaleClaim */
export async function isClaimingEnabled(): Promise<boolean> {
	if (!browser) return false;

	const addr = getClaimAddress();
	if (!addr) return false;

	const config = requireConfig();
	return readContract(config, {
		address: addr,
		abi: presaleClaimAbi,
		functionName: 'claimingEnabled',
	}) as Promise<boolean>;
}

/** Amount claimable by account */
export async function getClaimable(account: `0x${string}`): Promise<bigint> {
	if (!browser) return 0n;

	const addr = getClaimAddress();
	if (!addr) return 0n;

	const config = requireConfig();
	return readContract(config, {
		address: addr,
		abi: presaleClaimAbi,
		functionName: 'claimable',
		args: [account],
	}) as Promise<bigint>;
}

/** Whether account has already claimed */
export async function hasClaimed(account: `0x${string}`): Promise<boolean> {
	if (!browser) return false;

	const addr = getClaimAddress();
	if (!addr) return false;

	const config = requireConfig();
	return readContract(config, {
		address: addr,
		abi: presaleClaimAbi,
		functionName: 'claimed',
		args: [account],
	}) as Promise<boolean>;
}

// ════════════════════════════════════════════════════════════════
// CLAIM WRITES
// ════════════════════════════════════════════════════════════════

/** Claim $DATA allocation from PresaleClaim */
export async function claimTokens(): Promise<`0x${string}`> {
	if (!browser) throw new Error('Requires browser');

	const config = requireConfig();
	const addr = requireClaimAddress();

	const { request } = await simulateContract(config, {
		address: addr,
		abi: presaleClaimAbi,
		functionName: 'claim',
	});

	const hash = await writeContract(config, request);
	await waitForTransactionReceipt(config, { hash });
	return hash;
}

// ════════════════════════════════════════════════════════════════
// DEFAULTS (SSR / no contract)
// ════════════════════════════════════════════════════════════════

function defaultConfig(): PresaleConfig {
	return {
		minContribution: 0n,
		maxContribution: 0n,
		maxPerWallet: 0n,
		allowMultipleContributions: false,
		startTime: 0n,
		endTime: 0n,
		emergencyDeadline: 0n,
	};
}

function defaultProgress(): PresaleProgress {
	return {
		totalSold: 0n,
		totalSupply: 0n,
		totalRaised: 0n,
		currentPrice: 0n,
		contributorCount: 0n,
	};
}
