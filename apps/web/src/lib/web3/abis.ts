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

// Arcade contracts
import ArcadeCoreAbi from '$lib/contracts/abis/ArcadeCore.json';
import HashCrashAbi from '$lib/contracts/abis/HashCrash.json';
import DailyOpsAbi from '$lib/contracts/abis/DailyOps.json';

// Presale contracts
import GhostPresaleAbi from '$lib/contracts/abis/GhostPresale.json';
import PresaleClaimAbi from '$lib/contracts/abis/PresaleClaim.json';

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

// Arcade contracts
export const arcadeCoreAbi = ArcadeCoreAbi as typeof ArcadeCoreAbi;
export const hashCrashAbi = HashCrashAbi as typeof HashCrashAbi;
export const dailyOpsAbi = DailyOpsAbi as typeof DailyOpsAbi;

// Presale contracts
export const ghostPresaleAbi = GhostPresaleAbi as typeof GhostPresaleAbi;
export const presaleClaimAbi = PresaleClaimAbi as typeof PresaleClaimAbi;

// ════════════════════════════════════════════════════════════════
// CONTRACT ADDRESSES
// ════════════════════════════════════════════════════════════════

/**
 * Contract addresses per chain.
 * Update after deployment.
 */
export const CONTRACT_ADDRESSES = {
	// MegaETH Testnet (6343)
	// Deployed 2026-01-23
	6343: {
		dataToken: '0xf278eb6Cd5255dC67CFBcdbD57F91baCB3735804' as `0x${string}`, // MockERC20 (mDATA)
		ghostCore: '' as `0x${string}`,
		traceScan: '' as `0x${string}`,
		deadPool: '' as `0x${string}`,
		rewardsDistributor: '' as `0x${string}`,
		feeRouter: '' as `0x${string}`,
		teamVesting: '' as `0x${string}`,
		// Arcade contracts
		arcadeCore: '0xC65338Eda8F8AEaDf89bA95042b99116dD899BD0' as `0x${string}`,
		hashCrash: '0x037e0554f10e5447e08e4EDdbB16d8D8F402F785' as `0x${string}`,
		dailyOps: '' as `0x${string}`, // TODO: Deploy and update
		// Presale contracts
		ghostPresale: '' as `0x${string}`, // TODO: Deploy and update
		presaleClaim: '' as `0x${string}`, // TODO: Deploy at TGE
	},
	// MegaETH Mainnet (4326)
	4326: {
		dataToken: '' as `0x${string}`,
		ghostCore: '' as `0x${string}`,
		traceScan: '' as `0x${string}`,
		deadPool: '' as `0x${string}`,
		rewardsDistributor: '' as `0x${string}`,
		feeRouter: '' as `0x${string}`,
		teamVesting: '' as `0x${string}`,
		// Arcade contracts
		arcadeCore: '' as `0x${string}`,
		hashCrash: '' as `0x${string}`,
		dailyOps: '' as `0x${string}`,
		// Presale contracts
		ghostPresale: '' as `0x${string}`,
		presaleClaim: '' as `0x${string}`,
	},
	// Localhost (31337)
	31337: {
		dataToken: '' as `0x${string}`,
		ghostCore: '' as `0x${string}`,
		traceScan: '' as `0x${string}`,
		deadPool: '' as `0x${string}`,
		rewardsDistributor: '' as `0x${string}`,
		feeRouter: '' as `0x${string}`,
		teamVesting: '' as `0x${string}`,
		// Arcade contracts
		arcadeCore: '' as `0x${string}`,
		hashCrash: '' as `0x${string}`,
		dailyOps: '' as `0x${string}`,
		// Presale contracts
		ghostPresale: '' as `0x${string}`,
		presaleClaim: '' as `0x${string}`,
	},
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
