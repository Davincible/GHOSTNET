/**
 * Formatting Utilities
 * ====================
 * Shared formatting functions for time, numbers, and display values.
 */

/**
 * Format milliseconds as MM:SS countdown timer
 * @example formatCountdown(125000) => "02:05"
 */
export function formatCountdown(ms: number): string {
	if (ms <= 0) return '00:00';
	const totalSeconds = Math.floor(ms / 1000);
	const minutes = Math.floor(totalSeconds / 60);
	const seconds = totalSeconds % 60;
	return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

/**
 * Format milliseconds as human-readable duration with hours
 * @example formatDuration(125000) => "02:05"
 * @example formatDuration(3725000) => "1h 02m"
 */
export function formatDuration(ms: number): string {
	if (ms <= 0) return '0:00';
	const totalSeconds = Math.floor(ms / 1000);
	const minutes = Math.floor(totalSeconds / 60);
	const seconds = totalSeconds % 60;

	if (minutes >= 60) {
		const hours = Math.floor(minutes / 60);
		const mins = minutes % 60;
		return `${hours}h ${mins.toString().padStart(2, '0')}m`;
	}

	return `${minutes}:${seconds.toString().padStart(2, '0')}`;
}

/**
 * Format milliseconds as hours for display
 * @example formatHours(14400000) => "4 HOURS"
 */
export function formatHours(ms: number): string {
	const hours = Math.floor(ms / 3600000);
	return `${hours} ${hours === 1 ? 'HOUR' : 'HOURS'}`;
}

/**
 * Format a timestamp as relative time
 * @example formatRelativeTime(Date.now() - 300000) => "5m ago"
 */
export function formatRelativeTime(timestamp: number): string {
	const now = Date.now();
	const diffMs = now - timestamp;
	const diffMins = Math.floor(diffMs / 60000);
	const diffHours = Math.floor(diffMins / 60);
	const diffDays = Math.floor(diffHours / 24);

	if (diffMins < 1) return 'just now';
	if (diffMins < 60) return `${diffMins}m ago`;
	if (diffHours < 24) return `${diffHours}h ago`;
	if (diffDays < 7) return `${diffDays}d ago`;

	return new Date(timestamp).toLocaleDateString();
}

/**
 * Format elapsed time from a start timestamp
 * @example formatElapsed(Date.now() - 65000) => "1:05"
 */
export function formatElapsed(startTime: number): string {
	const elapsed = Date.now() - startTime;
	return formatCountdown(elapsed);
}

/**
 * Calculate and format WPM (words per minute)
 * Standard: 5 characters = 1 word
 */
export function calculateWPM(charCount: number, elapsedMs: number): number {
	if (elapsedMs <= 0 || charCount <= 0) return 0;
	const minutes = elapsedMs / 60000;
	const words = charCount / 5;
	return Math.round(words / minutes);
}

/**
 * Calculate typing accuracy
 * @returns Accuracy as a decimal (0-1)
 */
export function calculateAccuracy(typed: string, target: string): number {
	if (typed.length === 0) return 1;

	let correct = 0;
	const compareLength = Math.min(typed.length, target.length);

	for (let i = 0; i < compareLength; i++) {
		if (typed[i] === target[i]) {
			correct++;
		}
	}

	return correct / typed.length;
}

/**
 * Format a percentage (0-1) as display string
 * @example formatPercent(0.856) => "86%"
 */
export function formatPercent(value: number): string {
	return `${Math.round(value * 100)}%`;
}
