/**
 * Daily Operations Mock Data Generator
 * =====================================
 * Generates mock daily check-in progress and mission data.
 *
 * The generator creates realistic daily states including:
 * - Streak progress through the 7-day cycle
 * - Random daily missions from templates
 * - Mission progress tracking
 */

import type { DailyProgress, DailyMission } from '../../../types';
import {
	DAILY_REWARDS,
	MISSION_TEMPLATES,
	getDailyReward,
	getNextResetTime,
} from '../../../types/daily';

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

/** Generate random integer in range (inclusive) */
function randomInt(min: number, max: number): number {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}

/** Weighted random selection */
function weightedRandom<T extends { weight: number }>(items: readonly T[]): T {
	const totalWeight = items.reduce((sum, item) => sum + item.weight, 0);
	let random = Math.random() * totalWeight;

	for (const item of items) {
		random -= item.weight;
		if (random <= 0) return item;
	}

	return items[items.length - 1];
}

// ════════════════════════════════════════════════════════════════
// DAILY PROGRESS GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate mock daily progress state.
 *
 * @param options - Configuration options
 * @param options.currentStreak - Override current streak (1-7)
 * @param options.todayCheckedIn - Override whether checked in today
 * @param options.simulateMissedDay - Simulate a missed day (resets streak)
 */
export function generateMockDailyProgress(options?: {
	currentStreak?: number;
	todayCheckedIn?: boolean;
	simulateMissedDay?: boolean;
}): DailyProgress {
	const now = Date.now();

	// Determine streak
	let currentStreak: number;
	if (options?.simulateMissedDay) {
		currentStreak = 1; // Reset to day 1
	} else if (options?.currentStreak !== undefined) {
		currentStreak = Math.max(1, Math.min(7, options.currentStreak));
	} else {
		// Random streak between 1-7, weighted toward lower values
		const weights = [0.25, 0.2, 0.18, 0.15, 0.1, 0.07, 0.05];
		let cumulative = 0;
		const rand = Math.random();
		currentStreak = 1;
		for (let i = 0; i < weights.length; i++) {
			cumulative += weights[i];
			if (rand < cumulative) {
				currentStreak = i + 1;
				break;
			}
		}
	}

	// Determine if checked in today
	const todayCheckedIn = options?.todayCheckedIn ?? Math.random() < 0.4;

	// Build week progress array as fixed-length tuple
	const weekProgress = Array.from({ length: 7 }, (_, i) => {
		if (i < currentStreak - 1) {
			return true; // Previous days completed
		} else if (i === currentStreak - 1) {
			return todayCheckedIn; // Today
		} else {
			return false; // Future days
		}
	}) as [boolean, boolean, boolean, boolean, boolean, boolean, boolean];

	// Calculate last check-in time
	let lastCheckIn: number | null = null;
	if (todayCheckedIn) {
		// Random time today
		const todayStart = new Date(now);
		todayStart.setUTCHours(0, 0, 0, 0);
		lastCheckIn = todayStart.getTime() + randomInt(0, now - todayStart.getTime());
	} else if (currentStreak > 1 || Math.random() < 0.5) {
		// Yesterday (if streak > 1, must have checked in yesterday)
		const yesterday = new Date(now);
		yesterday.setUTCDate(yesterday.getUTCDate() - 1);
		yesterday.setUTCHours(randomInt(8, 22), randomInt(0, 59), 0, 0);
		lastCheckIn = yesterday.getTime();
	}

	// Next reward is for current streak day (or next day if already claimed)
	const nextRewardDay = todayCheckedIn ? Math.min(currentStreak + 1, 7) : currentStreak;
	const nextReward = getDailyReward(nextRewardDay);

	return {
		currentStreak,
		maxStreak: randomInt(currentStreak, 30), // Max streak is at least current
		lastCheckIn,
		todayCheckedIn,
		nextReward,
		weekProgress,
		nextResetAt: getNextResetTime(now),
	};
}

// ════════════════════════════════════════════════════════════════
// MISSION GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate a single mission from a template.
 *
 * @param template - Mission template to use
 * @param options - Configuration options
 */
function generateMissionFromTemplate(
	template: (typeof MISSION_TEMPLATES)[number],
	options?: {
		forceCompleted?: boolean;
		forceClaimed?: boolean;
		progressPercent?: number;
	}
): DailyMission {
	const now = Date.now();
	const target = randomInt(template.targetRange[0], template.targetRange[1]);

	// Determine progress
	let progress: number;
	let completed: boolean;
	let claimed: boolean;

	if (options?.forceCompleted) {
		progress = target;
		completed = true;
		claimed = options?.forceClaimed ?? Math.random() < 0.5;
	} else if (options?.progressPercent !== undefined) {
		progress = Math.floor(target * options.progressPercent);
		completed = progress >= target;
		claimed = completed && (options?.forceClaimed ?? false);
	} else {
		// Random progress distribution
		const rand = Math.random();
		if (rand < 0.2) {
			// 20% not started
			progress = 0;
		} else if (rand < 0.5) {
			// 30% in progress
			progress = randomInt(1, target - 1);
		} else if (rand < 0.8) {
			// 30% completed but not claimed
			progress = target;
		} else {
			// 20% completed and claimed
			progress = target;
		}
		completed = progress >= target;
		claimed = completed && rand >= 0.8;
	}

	// Generate description from template
	const description = template.descriptionTemplate.replace('{target}', target.toString());

	return {
		id: crypto.randomUUID(),
		missionType: template.missionType,
		title: template.title,
		description,
		progress,
		target,
		reward: { ...template.reward },
		expiresAt: getNextResetTime(now),
		completed,
		claimed,
	};
}

/**
 * Generate daily missions.
 *
 * @param count - Number of missions to generate (default 3)
 * @param options - Configuration options
 */
export function generateMockMissions(
	count = 3,
	options?: {
		/** Ensure at least one mission is completable */
		includeEasy?: boolean;
		/** Ensure at least one mission is completed */
		includeCompleted?: boolean;
	}
): DailyMission[] {
	const missions: DailyMission[] = [];

	// Select random unique mission types
	const selectedTemplates: (typeof MISSION_TEMPLATES)[number][] = [];

	while (selectedTemplates.length < count && selectedTemplates.length < MISSION_TEMPLATES.length) {
		const template = weightedRandom(MISSION_TEMPLATES);
		if (!selectedTemplates.find((t) => t.missionType === template.missionType)) {
			selectedTemplates.push(template);
		}
	}

	// Generate missions from templates
	for (let i = 0; i < selectedTemplates.length; i++) {
		const template = selectedTemplates[i];

		let missionOptions: Parameters<typeof generateMissionFromTemplate>[1] = undefined;

		// First mission: ensure it's easy/completable if requested
		if (i === 0 && options?.includeEasy) {
			missionOptions = { progressPercent: randomInt(60, 90) / 100 };
		}

		// Second mission: ensure it's completed if requested
		if (i === 1 && options?.includeCompleted) {
			missionOptions = { forceCompleted: true, forceClaimed: false };
		}

		missions.push(generateMissionFromTemplate(template, missionOptions));
	}

	return missions;
}

// ════════════════════════════════════════════════════════════════
// COMBINED STATE GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate complete daily operations state.
 *
 * @param options - Configuration options
 */
export function generateMockDailyState(options?: {
	currentStreak?: number;
	todayCheckedIn?: boolean;
	missionCount?: number;
}): {
	progress: DailyProgress;
	missions: DailyMission[];
} {
	return {
		progress: generateMockDailyProgress({
			currentStreak: options?.currentStreak,
			todayCheckedIn: options?.todayCheckedIn,
		}),
		missions: generateMockMissions(options?.missionCount ?? 3, {
			includeEasy: true,
			includeCompleted: true,
		}),
	};
}

// ════════════════════════════════════════════════════════════════
// MISSION PROGRESS SIMULATION
// ════════════════════════════════════════════════════════════════

/**
 * Simulate progress on a mission.
 * Returns a new mission object with updated progress.
 *
 * @param mission - Mission to update
 * @param incrementBy - Amount to increment progress by (default 1)
 */
export function simulateMissionProgress(mission: DailyMission, incrementBy = 1): DailyMission {
	const newProgress = Math.min(mission.target, mission.progress + incrementBy);
	const completed = newProgress >= mission.target;

	return {
		...mission,
		progress: newProgress,
		completed,
	};
}

/**
 * Claim a mission reward.
 * Returns a new mission object with claimed = true.
 *
 * @param mission - Mission to claim
 */
export function claimMission(mission: DailyMission): DailyMission {
	if (!mission.completed) {
		throw new Error('Cannot claim incomplete mission');
	}
	if (mission.claimed) {
		throw new Error('Mission already claimed');
	}

	return {
		...mission,
		claimed: true,
	};
}

// ════════════════════════════════════════════════════════════════
// DAILY CHECK-IN SIMULATION
// ════════════════════════════════════════════════════════════════

/**
 * Simulate checking in for today.
 * Returns updated daily progress.
 *
 * @param progress - Current daily progress
 */
export function simulateCheckIn(progress: DailyProgress): DailyProgress {
	if (progress.todayCheckedIn) {
		throw new Error('Already checked in today');
	}

	const now = Date.now();

	// Update week progress - mark current day as checked
	const weekProgress = [...progress.weekProgress] as typeof progress.weekProgress;
	weekProgress[progress.currentStreak - 1] = true;

	// Calculate new streak
	// On day 7, stay at 7 (week complete). Reset happens on next day via simulateDayPassing.
	const isWeekComplete = progress.currentStreak === 7;
	const newStreak = isWeekComplete ? 7 : progress.currentStreak + 1;

	// Next reward: if week complete, show day 1 preview; otherwise show next day
	const nextRewardDay = isWeekComplete ? 1 : Math.min(newStreak + 1, 7);

	return {
		...progress,
		currentStreak: newStreak,
		maxStreak: Math.max(progress.maxStreak, newStreak),
		lastCheckIn: now,
		todayCheckedIn: true,
		nextReward: getDailyReward(nextRewardDay),
		weekProgress,
	};
}

/**
 * Simulate a day passing (for testing).
 * Checks if streak should be maintained or reset.
 *
 * @param progress - Current daily progress
 * @param checkedInToday - Whether the user checked in today
 */
export function simulateDayPassing(
	progress: DailyProgress,
	checkedInToday: boolean
): DailyProgress {
	const now = Date.now();

	if (!checkedInToday) {
		// Missed a day - reset streak
		return {
			...progress,
			currentStreak: 1,
			todayCheckedIn: false,
			nextReward: getDailyReward(1),
			weekProgress: [false, false, false, false, false, false, false],
			nextResetAt: getNextResetTime(now),
		};
	}

	// Day passed, yesterday was checked in
	// If we completed day 7, reset to day 1 for new week
	const wasWeekComplete = progress.currentStreak === 7 && progress.todayCheckedIn;

	if (wasWeekComplete) {
		return {
			...progress,
			currentStreak: 1,
			todayCheckedIn: false,
			nextReward: getDailyReward(1),
			weekProgress: [false, false, false, false, false, false, false],
			nextResetAt: getNextResetTime(now),
		};
	}

	return {
		...progress,
		todayCheckedIn: false,
		nextResetAt: getNextResetTime(now),
	};
}
