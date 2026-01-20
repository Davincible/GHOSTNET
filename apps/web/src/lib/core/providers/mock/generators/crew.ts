/**
 * Crew Mock Data Generator
 * ========================
 * Generates realistic mock crew data for development
 */

import type {
	Crew,
	CrewMember,
	CrewBonus,
	CrewInvite,
	CrewActivity,
	CrewActivityType,
	CrewRole,
	Level,
} from '../../../types';
import { LEVELS } from '../../../types';

// ════════════════════════════════════════════════════════════════
// CONSTANTS
// ════════════════════════════════════════════════════════════════

/** Predefined crew names and tags */
const CREW_NAMES: Array<{ name: string; tag: string }> = [
	{ name: 'Phantoms', tag: 'PHTM' },
	{ name: 'Void Runners', tag: 'VOID' },
	{ name: 'Black Ice Cartel', tag: 'BIC' },
	{ name: 'Ghost Protocol', tag: 'GHST' },
	{ name: 'Neural Network', tag: 'NNET' },
	{ name: 'Darknet Syndicate', tag: 'DARK' },
	{ name: 'System Crashers', tag: 'CRSH' },
	{ name: 'Zero Day', tag: '0DAY' },
	{ name: 'Cipher Collective', tag: 'CPHR' },
	{ name: 'Shadow Brokers', tag: 'SHDB' },
	{ name: 'Root Access', tag: 'ROOT' },
	{ name: 'Packet Storm', tag: 'PSTM' },
];

/** Crew descriptions */
const CREW_DESCRIPTIONS: string[] = [
	'Elite operators who thrive in the shadows. We survive together.',
	'High-risk, high-reward. Only the bold need apply.',
	'Methodical. Calculated. Unstoppable.',
	'We dont just survive the trace - we mock it.',
	'United we stand, traced we fall. Join the resistance.',
	'Where legends are made and fortunes are lost.',
	'The deeper we go, the harder we hit.',
	'Trust the protocol. Trust each other.',
];

/** ENS-like names for members */
const ENS_NAMES: string[] = [
	'vitalik.eth',
	'ghost.eth',
	'runner.eth',
	'cipher.eth',
	'neural.eth',
	'shadow.eth',
	'zero.eth',
	'darknet.eth',
	'trace.eth',
	'phantom.eth',
	'ice.eth',
	'void.eth',
	'storm.eth',
	'root.eth',
	'hack.eth',
];

/** Bonus templates with calculation logic */
interface BonusTemplate {
	id: string;
	name: string;
	condition: string;
	effect: string;
	effectType: 'death_rate' | 'yield_multiplier';
	effectValue: number;
	requiredValue: number;
	checkFn: (members: CrewMember[]) => number;
}

const BONUS_TEMPLATES: BonusTemplate[] = [
	{
		id: 'safety_numbers',
		name: 'Safety in Numbers',
		condition: '>10 members online',
		effect: '-5% death rate',
		effectType: 'death_rate',
		effectValue: -0.05,
		requiredValue: 10,
		checkFn: (members) => members.filter((m) => m.isOnline).length,
	},
	{
		id: 'whale_shield',
		name: 'Whale Shield',
		condition: 'Crew TVL >100k $DATA',
		effect: '-10% death rate',
		effectType: 'death_rate',
		effectValue: -0.1,
		requiredValue: 100000,
		checkFn: (members) => {
			const totalWei = members.reduce((sum, m) => sum + m.stakedAmount, 0n);
			return Number(totalWei / 10n ** 18n);
		},
	},
	{
		id: 'ghost_collective',
		name: 'Ghost Collective',
		condition: '5+ members with ghost streaks',
		effect: '+5% yield',
		effectType: 'yield_multiplier',
		effectValue: 0.05,
		requiredValue: 5,
		checkFn: (members) => members.filter((m) => m.ghostStreak > 0).length,
	},
	{
		id: 'risk_lovers',
		name: 'Risk Lovers',
		condition: '3+ members in BLACK_ICE',
		effect: '+15% yield',
		effectType: 'yield_multiplier',
		effectValue: 0.15,
		requiredValue: 3,
		checkFn: (members) => members.filter((m) => m.level === 'BLACK_ICE').length,
	},
	{
		id: 'full_house',
		name: 'Full House',
		condition: '40+ active members',
		effect: '-8% death rate',
		effectType: 'death_rate',
		effectValue: -0.08,
		requiredValue: 40,
		checkFn: (members) => members.filter((m) => m.level !== null).length,
	},
	{
		id: 'streak_masters',
		name: 'Streak Masters',
		condition: 'Average streak >5',
		effect: '+10% yield',
		effectType: 'yield_multiplier',
		effectValue: 0.1,
		requiredValue: 5,
		checkFn: (members) => {
			const activeMembers = members.filter((m) => m.level !== null);
			if (activeMembers.length === 0) return 0;
			const totalStreak = activeMembers.reduce((sum, m) => sum + m.ghostStreak, 0);
			return totalStreak / activeMembers.length;
		},
	},
];

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

/** Generate a random Ethereum address */
function generateRandomAddress(): `0x${string}` {
	const chars = '0123456789abcdef';
	let addr = '0x';
	for (let i = 0; i < 40; i++) {
		addr += chars[Math.floor(Math.random() * chars.length)];
	}
	return addr as `0x${string}`;
}

/** Pick a random item from an array */
function pickRandom<T>(arr: readonly T[]): T {
	return arr[Math.floor(Math.random() * arr.length)];
}

/** Generate random integer in range (inclusive) */
function randomInt(min: number, max: number): number {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}

/** Generate a random token amount (in wei) */
function randomAmount(min: number, max: number): bigint {
	const value = Math.floor(Math.random() * (max - min) + min);
	return BigInt(value) * 10n ** 18n;
}

/** Pick a random level or null (not jacked in), weighted */
function pickRandomLevelOrNull(): Level | null {
	// 20% chance not jacked in
	if (Math.random() < 0.2) return null;

	const weights = [0.15, 0.2, 0.3, 0.25, 0.1]; // VAULT to BLACK_ICE
	const rand = Math.random();
	let cumulative = 0;
	for (let i = 0; i < LEVELS.length; i++) {
		cumulative += weights[i];
		if (rand < cumulative) return LEVELS[i];
	}
	return 'SUBNET';
}

/** Pick a weighted role (most are members) */
function pickRandomRole(isLeader: boolean): CrewRole {
	if (isLeader) return 'leader';
	// 10% officers, 90% members
	return Math.random() < 0.1 ? 'officer' : 'member';
}

// ════════════════════════════════════════════════════════════════
// MEMBER GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate a single mock crew member
 * @param isYou - Whether this member is the current user
 * @param isLeader - Whether this member is the crew leader
 */
export function generateMockMember(isYou = false, isLeader = false): CrewMember {
	const now = Date.now();
	const level = pickRandomLevelOrNull();
	const isOnline = level !== null ? Math.random() > 0.3 : Math.random() > 0.7;
	const hasEns = Math.random() < 0.3; // 30% have ENS

	return {
		address: generateRandomAddress(),
		ensName: hasEns ? pickRandom(ENS_NAMES) : undefined,
		level,
		stakedAmount: level !== null ? randomAmount(50, 5000) : 0n,
		ghostStreak: level !== null ? randomInt(0, 25) : 0,
		isOnline,
		isYou,
		role: pickRandomRole(isLeader),
		joinedAt: now - randomInt(1, 90) * 24 * 60 * 60 * 1000, // 1-90 days ago
		weeklyContribution: randomAmount(10, 1000),
	};
}

/**
 * Generate multiple mock crew members
 * @param count - Number of members to generate
 * @param includeYou - Whether to include the current user as a member
 */
export function generateMockMembers(count: number, includeYou = false): CrewMember[] {
	const members: CrewMember[] = [];

	// First member is always the leader
	const leader = generateMockMember(false, true);
	members.push(leader);

	// Generate remaining members
	for (let i = 1; i < count; i++) {
		// If includeYou, make one random non-leader member "you"
		const shouldBeYou = includeYou && i === Math.floor(count / 2);
		members.push(generateMockMember(shouldBeYou, false));
	}

	// Sort: leader first, then officers, then members; online first within each group
	return members.sort((a, b) => {
		const roleOrder = { leader: 0, officer: 1, member: 2 };
		const roleDiff = roleOrder[a.role] - roleOrder[b.role];
		if (roleDiff !== 0) return roleDiff;
		if (a.isOnline !== b.isOnline) return a.isOnline ? -1 : 1;
		return Number(b.stakedAmount - a.stakedAmount);
	});
}

// ════════════════════════════════════════════════════════════════
// BONUS CALCULATION
// ════════════════════════════════════════════════════════════════

/**
 * Calculate crew bonuses based on current member state
 * @param members - Array of crew members
 */
export function calculateBonuses(members: CrewMember[]): CrewBonus[] {
	return BONUS_TEMPLATES.map((template) => {
		const currentValue = template.checkFn(members);
		const progress = Math.min(1, currentValue / template.requiredValue);
		const active = currentValue >= template.requiredValue;

		return {
			id: template.id,
			name: template.name,
			condition: template.condition,
			effect: template.effect,
			effectType: template.effectType,
			effectValue: template.effectValue,
			active,
			progress,
			requiredValue: template.requiredValue,
			currentValue,
		};
	});
}

// ════════════════════════════════════════════════════════════════
// CREW GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate a complete mock crew with members and bonuses
 * @param options - Configuration options
 */
export function generateMockCrew(options?: {
	memberCount?: number;
	includeYou?: boolean;
}): Crew {
	const memberCount = options?.memberCount ?? randomInt(15, 45);
	const members = generateMockMembers(memberCount, options?.includeYou);
	const bonuses = calculateBonuses(members);

	const crewInfo = pickRandom(CREW_NAMES);
	const now = Date.now();

	// Calculate totals from members
	const totalStaked = members.reduce((sum, m) => sum + m.stakedAmount, 0n);
	const weeklyExtracted = members.reduce((sum, m) => sum + m.weeklyContribution, 0n);

	// Find leader
	const leader = members.find((m) => m.role === 'leader')!;

	return {
		id: crypto.randomUUID(),
		name: crewInfo.name,
		tag: crewInfo.tag,
		description: pickRandom(CREW_DESCRIPTIONS),
		memberCount: members.length,
		maxMembers: 50,
		rank: randomInt(1, 500),
		totalStaked,
		weeklyExtracted,
		bonuses,
		leader: leader.address,
		createdAt: now - randomInt(30, 365) * 24 * 60 * 60 * 1000, // 30-365 days ago
		isPublic: Math.random() < 0.6, // 60% public
	};
}

// ════════════════════════════════════════════════════════════════
// INVITE GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate mock crew invites
 * @param count - Number of invites to generate
 */
export function generateMockInvites(count: number): CrewInvite[] {
	const invites: CrewInvite[] = [];
	const now = Date.now();

	for (let i = 0; i < count; i++) {
		const crewInfo = CREW_NAMES[i % CREW_NAMES.length];
		const hasInviterName = Math.random() < 0.4;

		invites.push({
			id: crypto.randomUUID(),
			crewId: crypto.randomUUID(),
			crewName: crewInfo.name,
			crewTag: crewInfo.tag,
			inviterAddress: generateRandomAddress(),
			inviterName: hasInviterName ? pickRandom(ENS_NAMES) : undefined,
			expiresAt: now + randomInt(1, 7) * 24 * 60 * 60 * 1000, // 1-7 days from now
			createdAt: now - randomInt(1, 24) * 60 * 60 * 1000, // 1-24 hours ago
		});
	}

	// Sort by creation time, newest first
	return invites.sort((a, b) => b.createdAt - a.createdAt);
}

// ════════════════════════════════════════════════════════════════
// ACTIVITY GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate a human-readable message for a crew activity
 * @param type - Activity type
 * @param data - Partial activity data
 */
export function generateActivityMessage(
	type: CrewActivityType,
	data: Partial<CrewActivity>
): string {
	const actorName = data.actorName ?? formatAddress(data.actorAddress);
	const targetName = data.targetName ?? formatAddress(data.targetAddress);

	switch (type) {
		case 'member_joined':
			return `${actorName} joined the crew`;
		case 'member_left':
			return `${actorName} left the crew`;
		case 'member_kicked':
			return `${actorName} kicked ${targetName} from the crew`;
		case 'bonus_activated':
			return `${data.bonusName ?? 'Bonus'} activated!`;
		case 'bonus_deactivated':
			return `${data.bonusName ?? 'Bonus'} deactivated`;
		case 'member_survived':
			return `${actorName} survived trace scan in ${data.level}`;
		case 'member_traced':
			return `${actorName} was traced in ${data.level} - lost ${formatAmount(data.amount)}`;
		case 'member_extracted':
			return `${actorName} extracted ${formatAmount(data.amount)}`;
		case 'raid_started':
			return `Crew raid initiated by ${actorName}`;
		case 'raid_completed':
			return `Crew raid completed! +${formatAmount(data.amount)} bonus`;
		default:
			return 'Unknown activity';
	}
}

/** Format an address for display */
function formatAddress(address?: `0x${string}`): string {
	if (!address) return 'Unknown';
	return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/** Format a bigint amount for display */
function formatAmount(amount?: bigint): string {
	if (amount === undefined) return '0 $DATA';
	const value = Number(amount / 10n ** 18n);
	return `${value.toLocaleString()} $DATA`;
}

/**
 * Generate mock crew activity events
 * @param count - Number of activities to generate
 */
export function generateMockActivity(count: number): CrewActivity[] {
	const activities: CrewActivity[] = [];
	const now = Date.now();

	const activityTypes: CrewActivityType[] = [
		'member_joined',
		'member_left',
		'bonus_activated',
		'bonus_deactivated',
		'member_survived',
		'member_traced',
		'member_extracted',
		'raid_completed',
	];

	// Weighted distribution - survival and extraction most common
	const weights = [0.05, 0.03, 0.08, 0.04, 0.35, 0.15, 0.25, 0.05];

	for (let i = 0; i < count; i++) {
		// Pick weighted random type
		const rand = Math.random();
		let cumulative = 0;
		let type: CrewActivityType = 'member_survived';
		for (let j = 0; j < activityTypes.length; j++) {
			cumulative += weights[j];
			if (rand < cumulative) {
				type = activityTypes[j];
				break;
			}
		}

		const hasActorEns = Math.random() < 0.3;
		const hasTargetEns = Math.random() < 0.3;
		const actorAddress = generateRandomAddress();
		const targetAddress = generateRandomAddress();
		const actorName = hasActorEns ? pickRandom(ENS_NAMES) : undefined;
		const targetName = hasTargetEns ? pickRandom(ENS_NAMES) : undefined;

		const activityData: Partial<CrewActivity> = {
			actorAddress,
			actorName,
			targetAddress: type === 'member_kicked' ? targetAddress : undefined,
			targetName: type === 'member_kicked' ? targetName : undefined,
			level: ['member_survived', 'member_traced'].includes(type)
				? pickRandom(['SUBNET', 'DARKNET', 'BLACK_ICE'] as const)
				: undefined,
			amount: ['member_traced', 'member_extracted', 'raid_completed'].includes(type)
				? randomAmount(50, 2000)
				: undefined,
			bonusId: ['bonus_activated', 'bonus_deactivated'].includes(type)
				? pickRandom(BONUS_TEMPLATES).id
				: undefined,
			bonusName: ['bonus_activated', 'bonus_deactivated'].includes(type)
				? pickRandom(BONUS_TEMPLATES).name
				: undefined,
		};

		activities.push({
			id: crypto.randomUUID(),
			type,
			timestamp: now - i * randomInt(30, 300) * 1000, // Spread out over time
			...activityData,
			message: generateActivityMessage(type, activityData),
		} as CrewActivity);
	}

	// Sort by timestamp, newest first
	return activities.sort((a, b) => b.timestamp - a.timestamp);
}

// ════════════════════════════════════════════════════════════════
// RANKINGS GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate crew rankings (leaderboard)
 * @param count - Number of crews to generate
 */
export function generateCrewRankings(count: number): Array<{ crew: Crew; position: number }> {
	const rankings: Array<{ crew: Crew; position: number }> = [];

	for (let i = 0; i < count; i++) {
		const crew = generateMockCrew({
			memberCount: randomInt(10, 50),
		});

		// Override rank to match position
		crew.rank = i + 1;

		// Scale stats based on rank (higher rank = more activity)
		const multiplier = Math.max(0.2, 1 - i * 0.05);
		crew.totalStaked = (crew.totalStaked * BigInt(Math.floor(multiplier * 100))) / 100n;
		crew.weeklyExtracted = (crew.weeklyExtracted * BigInt(Math.floor(multiplier * 100))) / 100n;

		rankings.push({
			crew,
			position: i + 1,
		});
	}

	return rankings;
}

// ════════════════════════════════════════════════════════════════
// USER STATUS GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate mock user crew status
 * @param inCrew - Whether the user is in a crew
 */
export function generateMockUserCrewStatus(inCrew = true): {
	crew: Crew | null;
	role: CrewRole | null;
	pendingInvites: CrewInvite[];
	canCreateCrew: boolean;
} {
	if (!inCrew) {
		return {
			crew: null,
			role: null,
			pendingInvites: generateMockInvites(randomInt(0, 3)),
			canCreateCrew: true,
		};
	}

	const crew = generateMockCrew({ includeYou: true });
	const roles: CrewRole[] = ['leader', 'officer', 'member'];
	const roleWeights = [0.05, 0.15, 0.8]; // Most users are members

	let role: CrewRole = 'member';
	const rand = Math.random();
	let cumulative = 0;
	for (let i = 0; i < roles.length; i++) {
		cumulative += roleWeights[i];
		if (rand < cumulative) {
			role = roles[i];
			break;
		}
	}

	return {
		crew,
		role,
		pendingInvites: [], // No invites if already in a crew
		canCreateCrew: false,
	};
}
