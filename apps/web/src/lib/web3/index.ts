/**
 * Web3 Module Exports
 * ====================
 * Public API for web3 functionality
 */

// Chains
export { megaethTestnet, megaethMainnet, localhost, defaultChain, supportedChains } from './chains';

// Config
export { config, getConfig, requireConfig } from './config';

// Wallet
export { wallet, createWalletStore, type WalletState, type WalletStatus } from './wallet.svelte';

// ABIs & Addresses
export {
	dataTokenAbi,
	ghostCoreAbi,
	traceScanAbi,
	deadPoolAbi,
	rewardsDistributorAbi,
	feeRouterAbi,
	teamVestingAbi,
	CONTRACT_ADDRESSES,
	getContractAddress,
} from './abis';

// Contract Interactions
export {
	// Helpers
	formatData,
	parseData,
	parseContractError,
	// DataToken
	getDataBalance,
	getDataAllowance,
	approveData,
	// GhostCore reads
	getPosition,
	getLevelConfig,
	getPendingYield,
	getTotalStaked,
	getLevelStaked,
	// GhostCore writes
	jackIn,
	extract,
	claimRewards,
	upgradeLevel,
	increaseStake,
	// DeadPool
	getCurrentRound,
	placeBet,
	claimWinnings,
	// Types
	type Position,
	type LevelConfig,
} from './contracts';
