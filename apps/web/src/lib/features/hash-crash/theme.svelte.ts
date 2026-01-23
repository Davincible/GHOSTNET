/**
 * Hash Crash Theme Store
 * =======================
 * Manages visual theme selection for Hash Crash game.
 *
 * Themes:
 * - network-penetration: Horizontal firewall breach visualization
 * - data-stream: Vertical data extraction with scrolling hex
 */

import { browser } from '$app/environment';

// ============================================================================
// TYPES
// ============================================================================

export type HashCrashTheme = 'network-penetration' | 'data-stream' | 'classic';

export interface ThemeConfig {
	id: HashCrashTheme;
	name: string;
	description: string;
}

// ============================================================================
// THEME DEFINITIONS
// ============================================================================

export const THEMES: Record<HashCrashTheme, ThemeConfig> = {
	'network-penetration': {
		id: 'network-penetration',
		name: 'ICE BREAKER',
		description: 'Horizontal firewall penetration visualization',
	},
	'data-stream': {
		id: 'data-stream',
		name: 'DATA EXTRACTION',
		description: 'Vertical data stream with extraction curve',
	},
	classic: {
		id: 'classic',
		name: 'CLASSIC',
		description: 'Traditional crash game visualization',
	},
};

// ============================================================================
// TERMINOLOGY MAPPING
// ============================================================================

/** Maps generic crash game terms to themed equivalents */
export const TERMINOLOGY = {
	multiplier: 'Penetration Depth',
	crash: 'Traced',
	crashPoint: 'Trace Point',
	target: 'Exit Point',
	cashOut: 'Extract',
	bet: 'Stake',
	win: 'Safe',
	lose: 'Traced',
	round: 'Breach Attempt',
} as const;

/** Format multiplier as themed depth */
export function formatDepth(value: number): string {
	return `${value.toFixed(2)}x`;
}

/** Get status text based on game state */
export function getStatusText(
	phase: string,
	multiplier: number,
	target: number | null,
	crashed: boolean
): string {
	if (crashed) return '████ TRACED ████';
	if (!target) return 'SCANNING...';

	if (phase === 'betting') return 'AWAITING BREACH';
	if (phase === 'locked') return 'INITIATING...';

	if (multiplier >= target) {
		return '✓ EXIT SECURED';
	}

	const progress = (multiplier / target) * 100;
	if (progress > 80) return '! APPROACHING EXIT';
	if (progress > 50) return 'PENETRATING...';
	return 'BREACH ACTIVE';
}

// ============================================================================
// THEME STORE
// ============================================================================

const STORAGE_KEY = 'ghostnet-hashcrash-theme';

export function createThemeStore() {
	// Default theme
	let theme = $state<HashCrashTheme>('network-penetration');

	// Load from localStorage on init
	if (browser) {
		const saved = localStorage.getItem(STORAGE_KEY);
		if (saved === 'data-stream' || saved === 'network-penetration' || saved === 'classic') {
			theme = saved;
		}
	}

	return {
		get theme() {
			return theme;
		},

		get config() {
			return THEMES[theme];
		},

		set(newTheme: HashCrashTheme) {
			theme = newTheme;
			if (browser) {
				localStorage.setItem(STORAGE_KEY, newTheme);
			}
		},

		toggle() {
			const newTheme = theme === 'network-penetration' ? 'data-stream' : 'network-penetration';
			this.set(newTheme);
		},

		isNetworkPenetration() {
			return theme === 'network-penetration';
		},

		isDataStream() {
			return theme === 'data-stream';
		},
	};
}

export type ThemeStore = ReturnType<typeof createThemeStore>;
