/**
 * Hack Run Type Definitions
 * =========================
 * Types for the multi-node exploration mini-game where players
 * navigate through a virtual network, complete typing challenges,
 * and earn temporary yield multipliers.
 */

import type { TypingChallenge } from './index';

// ════════════════════════════════════════════════════════════════
// NODE TYPES
// ════════════════════════════════════════════════════════════════

/** Types of nodes encountered during a hack run */
export type NodeType =
	| 'firewall' // Medium risk, standard reward
	| 'patrol' // Low risk, low reward
	| 'data_cache' // High risk, high reward (bonus loot)
	| 'trap' // Very high risk, skip reward
	| 'ice_wall' // Medium risk, hard typing challenge
	| 'honeypot' // Looks good, might be a trap
	| 'backdoor'; // Skip nodes (risky shortcut)

/** Risk classification for nodes */
export type NodeRisk = 'low' | 'medium' | 'high' | 'extreme';

/** Reward granted upon successful node completion */
export interface NodeReward {
	/** Type of reward */
	type: 'multiplier' | 'loot' | 'skip' | 'none';
	/** Value: 0.2 = +0.2x multiplier, or loot amount in tokens */
	value: number;
	/** Human-readable label */
	label: string;
}

/** A single node in the hack run network */
export interface HackRunNode {
	/** Unique node identifier */
	id: string;
	/** Type determines behavior and appearance */
	type: NodeType;
	/** Position in sequence (1-5) */
	position: number;
	/** Display name (e.g., "SECTOR_7G", "NODE_X42") */
	name: string;
	/** Flavor text describing the node */
	description: string;
	/** Typing challenge to complete this node */
	challenge: TypingChallenge;
	/** Reward for successful completion */
	reward: NodeReward;
	/** Risk level affects failure consequences */
	risk: NodeRisk;
	/** True until adjacent node completed (fog of war) */
	hidden?: boolean;
	/** IDs of nodes this can skip to (for backdoors) */
	alternativePaths?: string[];
}

// ════════════════════════════════════════════════════════════════
// RUN CONFIGURATION
// ════════════════════════════════════════════════════════════════

/** Difficulty tiers for hack runs */
export type HackRunDifficulty = 'easy' | 'medium' | 'hard';

/** Complete configuration for a hack run */
export interface HackRun {
	/** Unique run identifier */
	id: string;
	/** Difficulty determines rewards and challenge intensity */
	difficulty: HackRunDifficulty;
	/** Entry fee in $DATA (burned on failure, refunded on success) */
	entryFee: bigint;
	/** Nodes to navigate through */
	nodes: HackRunNode[];
	/** Base multiplier granted on successful completion */
	baseMultiplier: number;
	/** Total time limit in milliseconds */
	timeLimit: number;
	/** Number of backdoor shortcuts available */
	shortcuts: number;
}

// ════════════════════════════════════════════════════════════════
// GAME STATE
// ════════════════════════════════════════════════════════════════

/** Possible states in the hack run state machine */
export type HackRunStatus =
	| 'idle' // No active run
	| 'selecting' // Choosing difficulty/run
	| 'countdown' // Pre-run countdown
	| 'running' // Navigating between nodes
	| 'node_typing' // Active typing challenge
	| 'node_result' // Showing node completion result
	| 'complete' // Run finished successfully
	| 'failed'; // Run failed (traced/timeout)

/** Progress tracking for a single node */
export interface NodeProgress {
	/** Node this progress refers to */
	nodeId: string;
	/** Current status of this node */
	status: 'pending' | 'current' | 'completed' | 'failed' | 'skipped';
	/** Result if node was attempted */
	result?: NodeResult;
}

/** Result of completing (or failing) a node */
export interface NodeResult {
	/** Whether the typing challenge was passed */
	success: boolean;
	/** Typing accuracy (0-1) */
	accuracy: number;
	/** Words per minute */
	wpm: number;
	/** Time taken in milliseconds */
	timeElapsed: number;
	/** Loot tokens gained (if any) */
	lootGained: bigint;
	/** Multiplier bonus gained (if any) */
	multiplierGained: number;
}

/** Final result of a completed hack run */
export interface HackRunResult {
	/** Whether the run was successful */
	success: boolean;
	/** Number of nodes completed */
	nodesCompleted: number;
	/** Total nodes in the run */
	totalNodes: number;
	/** Final yield multiplier earned */
	finalMultiplier: number;
	/** Total loot gained */
	lootGained: bigint;
	/** Total time elapsed in milliseconds */
	timeElapsed: number;
	/** Experience points gained */
	xpGained: number;
	/** True if entry fee was refunded (success) */
	entryRefunded: boolean;
}

/** Discriminated union for complete state machine */
export type HackRunState =
	| { status: 'idle' }
	| { status: 'selecting'; availableRuns: HackRun[] }
	| { status: 'countdown'; run: HackRun; secondsLeft: number }
	| {
			status: 'running';
			run: HackRun;
			currentNode: number;
			progress: NodeProgress[];
			timeRemaining: number;
	  }
	| {
			status: 'node_typing';
			run: HackRun;
			node: HackRunNode;
			progress: NodeProgress[];
			timeRemaining: number;
	  }
	| {
			status: 'node_result';
			run: HackRun;
			node: HackRunNode;
			result: NodeResult;
			progress: NodeProgress[];
			timeRemaining: number;
	  }
	| { status: 'complete'; run: HackRun; result: HackRunResult }
	| { status: 'failed'; run: HackRun; reason: string; progress: NodeProgress[] };

// ════════════════════════════════════════════════════════════════
// USER STATS
// ════════════════════════════════════════════════════════════════

/** Cumulative user statistics for hack runs */
export interface HackRunUserStats {
	/** Total runs attempted */
	totalRuns: number;
	/** Successfully completed runs */
	successfulRuns: number;
	/** Failed runs */
	failedRuns: number;
	/** Total XP earned from hack runs */
	totalXp: number;
	/** Total loot earned */
	totalLoot: bigint;
	/** Average typing accuracy across all runs */
	averageAccuracy: number;
	/** Average WPM across all runs */
	averageWpm: number;
	/** Best multiplier ever achieved */
	bestMultiplier: number;
	/** Currently active multiplier (if any) */
	currentMultiplier: number;
	/** When current multiplier expires (null if none active) */
	multiplierExpiresAt: number | null;
}

// ════════════════════════════════════════════════════════════════
// HISTORY
// ════════════════════════════════════════════════════════════════

/** Single entry in hack run history */
export interface HackRunHistoryEntry {
	/** Unique entry identifier */
	id: string;
	/** When the run occurred */
	timestamp: number;
	/** Difficulty of the run */
	difficulty: HackRunDifficulty;
	/** Result of the run */
	result: HackRunResult;
}

// ════════════════════════════════════════════════════════════════
// NODE TYPE CONFIGURATION
// ════════════════════════════════════════════════════════════════

/** Configuration for each node type */
export const NODE_TYPE_CONFIG: Record<
	NodeType,
	{
		risk: NodeRisk;
		baseRewardMultiplier: number;
		challengeDifficultyModifier: number;
		description: string;
		icon: string;
	}
> = {
	firewall: {
		risk: 'medium',
		baseRewardMultiplier: 1.0,
		challengeDifficultyModifier: 0,
		description: 'Standard security barrier',
		icon: '[#]'
	},
	patrol: {
		risk: 'low',
		baseRewardMultiplier: 0.5,
		challengeDifficultyModifier: -1,
		description: 'Automated patrol routine',
		icon: '[~]'
	},
	data_cache: {
		risk: 'high',
		baseRewardMultiplier: 2.0,
		challengeDifficultyModifier: 1,
		description: 'Valuable data store',
		icon: '[$]'
	},
	trap: {
		risk: 'extreme',
		baseRewardMultiplier: 0,
		challengeDifficultyModifier: 2,
		description: 'Danger! Possible trap detected',
		icon: '[!]'
	},
	ice_wall: {
		risk: 'medium',
		baseRewardMultiplier: 1.5,
		challengeDifficultyModifier: 2,
		description: 'Intrusion Countermeasures Electronics',
		icon: '[*]'
	},
	honeypot: {
		risk: 'high',
		baseRewardMultiplier: 1.8,
		challengeDifficultyModifier: 1,
		description: 'Too good to be true?',
		icon: '[?]'
	},
	backdoor: {
		risk: 'medium',
		baseRewardMultiplier: 0.3,
		challengeDifficultyModifier: 0,
		description: 'Shortcut through the system',
		icon: '[>]'
	}
};
