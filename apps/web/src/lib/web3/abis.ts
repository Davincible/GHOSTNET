/**
 * Contract ABI Exports
 * =====================
 * Type-safe ABI imports for all GHOSTNET contracts
 */

// Import ABIs as const for type inference
import DataTokenAbi from '$lib/contracts/abis/DataToken.json';
import GhostCoreAbi from '$lib/contracts/abis/GhostCore.json';
import TraceScanAbi from '$lib/contracts/abis/TraceScan.json';
import DeadPoolAbi from '$lib/contracts/abis/DeadPool.json';
import RewardsDistributorAbi from '$lib/contracts/abis/RewardsDistributor.json';
import FeeRouterAbi from '$lib/contracts/abis/FeeRouter.json';
import TeamVestingAbi from '$lib/contracts/abis/TeamVesting.json';

// ════════════════════════════════════════════════════════════════
// ABI EXPORTS
// ════════════════════════════════════════════════════════════════

export const dataTokenAbi = DataTokenAbi as typeof DataTokenAbi;
export const ghostCoreAbi = GhostCoreAbi as typeof GhostCoreAbi;
export const traceScanAbi = TraceScanAbi as typeof TraceScanAbi;
export const deadPoolAbi = DeadPoolAbi as typeof DeadPoolAbi;
export const rewardsDistributorAbi = RewardsDistributorAbi as typeof RewardsDistributorAbi;
export const feeRouterAbi = FeeRouterAbi as typeof FeeRouterAbi;
export const teamVestingAbi = TeamVestingAbi as typeof TeamVestingAbi;

// ════════════════════════════════════════════════════════════════
// CONTRACT ADDRESSES
// ════════════════════════════════════════════════════════════════

/**
 * Contract addresses per chain.
 * Update after deployment.
 */
export const CONTRACT_ADDRESSES = {
	// MegaETH Testnet (6343)
	6343: {
		dataToken: '' as `0x${string}`,
		ghostCore: '' as `0x${string}`,
		traceScan: '' as `0x${string}`,
		deadPool: '' as `0x${string}`,
		rewardsDistributor: '' as `0x${string}`,
		feeRouter: '' as `0x${string}`,
		teamVesting: '' as `0x${string}`
	},
	// MegaETH Mainnet (4326)
	4326: {
		dataToken: '' as `0x${string}`,
		ghostCore: '' as `0x${string}`,
		traceScan: '' as `0x${string}`,
		deadPool: '' as `0x${string}`,
		rewardsDistributor: '' as `0x${string}`,
		feeRouter: '' as `0x${string}`,
		teamVesting: '' as `0x${string}`
	},
	// Localhost (31337)
	31337: {
		dataToken: '' as `0x${string}`,
		ghostCore: '' as `0x${string}`,
		traceScan: '' as `0x${string}`,
		deadPool: '' as `0x${string}`,
		rewardsDistributor: '' as `0x${string}`,
		feeRouter: '' as `0x${string}`,
		teamVesting: '' as `0x${string}`
	}
} as const;

export type ChainId = keyof typeof CONTRACT_ADDRESSES;
export type ContractName = keyof (typeof CONTRACT_ADDRESSES)[ChainId];

/**
 * Track which missing contracts have already been warned about
 * to avoid spamming the console in development.
 */
const warnedMissing = new Set<string>();

/**
 * Get contract address for a chain
 */
export function getContractAddress(chainId: number, contract: ContractName): `0x${string}` | null {
	const addresses = CONTRACT_ADDRESSES[chainId as ChainId];
	if (!addresses) return null;
	const addr = addresses[contract];
	// Check if address is set (not empty string)
	if (!addr || addr.length < 3) {
		const key = `${chainId}-${contract}`;
		if (import.meta.env.DEV && !warnedMissing.has(key)) {
			warnedMissing.add(key);
			console.warn(
				`[Contracts] ${contract} not deployed on chain ${chainId}. Run 'just contracts-deploy-local' to deploy.`
			);
		}
		return null;
	}
	return addr;
}
