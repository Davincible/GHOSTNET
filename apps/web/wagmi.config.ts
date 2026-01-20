import { defineConfig } from '@wagmi/cli';
import DataTokenAbi from './src/lib/contracts/abis/DataToken.json';
import GhostCoreAbi from './src/lib/contracts/abis/GhostCore.json';
import TraceScanAbi from './src/lib/contracts/abis/TraceScan.json';
import DeadPoolAbi from './src/lib/contracts/abis/DeadPool.json';
import RewardsDistributorAbi from './src/lib/contracts/abis/RewardsDistributor.json';
import FeeRouterAbi from './src/lib/contracts/abis/FeeRouter.json';
import TeamVestingAbi from './src/lib/contracts/abis/TeamVesting.json';

export default defineConfig({
	out: 'src/lib/contracts/generated.ts',
	contracts: [
		{
			name: 'DataToken',
			abi: DataTokenAbi as readonly unknown[]
		},
		{
			name: 'GhostCore',
			abi: GhostCoreAbi as readonly unknown[]
		},
		{
			name: 'TraceScan',
			abi: TraceScanAbi as readonly unknown[]
		},
		{
			name: 'DeadPool',
			abi: DeadPoolAbi as readonly unknown[]
		},
		{
			name: 'RewardsDistributor',
			abi: RewardsDistributorAbi as readonly unknown[]
		},
		{
			name: 'FeeRouter',
			abi: FeeRouterAbi as readonly unknown[]
		},
		{
			name: 'TeamVesting',
			abi: TeamVestingAbi as readonly unknown[]
		}
	]
});
