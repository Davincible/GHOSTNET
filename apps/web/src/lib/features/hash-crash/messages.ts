/**
 * Hash Crash Terminal Messages
 * ============================
 * Themed messages that appear in the terminal log during gameplay.
 * Creates atmosphere and enhances the hacking/extraction theme.
 */

// ============================================================================
// MESSAGE TYPES
// ============================================================================

export interface TerminalMessage {
	text: string;
	type: 'info' | 'success' | 'warning' | 'danger' | 'system';
	delay?: number; // ms delay before showing
}

// ============================================================================
// PHASE MESSAGES
// ============================================================================

/** Messages shown when a new round starts */
export const ROUND_START_MESSAGES: TerminalMessage[] = [
	{ text: '> INITIATING BREACH PROTOCOL...', type: 'system' },
	{ text: '> Scanning target network...', type: 'info', delay: 300 },
	{ text: '> Vulnerability detected in sector 7G', type: 'info', delay: 600 },
	{ text: '> Establishing secure tunnel...', type: 'info', delay: 900 },
	{ text: '> Bypass protocols: ACTIVE', type: 'success', delay: 1200 },
];

/** Messages shown during betting phase */
export const BETTING_MESSAGES: TerminalMessage[] = [
	{ text: '> Awaiting operator stake...', type: 'info' },
	{ text: '> Set extraction depth to continue', type: 'system' },
	{ text: '> ICE scan in progress...', type: 'warning' },
];

/** Messages shown when betting closes */
export const LOCK_MESSAGES: TerminalMessage[] = [
	{ text: '> BETTING WINDOW CLOSED', type: 'system' },
	{ text: '> Committing breach parameters...', type: 'info', delay: 200 },
	{ text: '> Awaiting network confirmation...', type: 'info', delay: 500 },
];

/** Messages shown when crash point is revealed */
export const REVEAL_MESSAGES: TerminalMessage[] = [
	{ text: '> Block hash acquired', type: 'success' },
	{ text: '> Calculating trace threshold...', type: 'info', delay: 200 },
	{ text: '> BREACH SEQUENCE INITIATED', type: 'system', delay: 500 },
];

// ============================================================================
// DYNAMIC PENETRATION MESSAGES
// ============================================================================

/** Get messages based on current penetration depth */
export function getPenetrationMessage(
	depth: number,
	target: number | null
): TerminalMessage | null {
	// Random chance to show a message (don't spam)
	if (Math.random() > 0.3) return null;

	const messages: TerminalMessage[] = [];

	// Depth-based messages
	if (depth < 1.5) {
		messages.push(
			{ text: '> Penetrating outer firewall...', type: 'info' },
			{ text: '> Bypassing authentication layer...', type: 'info' },
			{ text: '> Initial access established', type: 'success' }
		);
	} else if (depth < 2.5) {
		messages.push(
			{ text: '> Accessing subnet layer 2...', type: 'info' },
			{ text: '> Extracting credential hashes...', type: 'info' },
			{ text: '> Firewall rules modified', type: 'success' }
		);
	} else if (depth < 5) {
		messages.push(
			{ text: '> Deep network access achieved', type: 'success' },
			{ text: '> ICE signatures detected nearby', type: 'warning' },
			{ text: '> Payload injection: 67% complete', type: 'info' }
		);
	} else if (depth < 10) {
		messages.push(
			{ text: '> WARNING: Deep penetration zone', type: 'warning' },
			{ text: '> ICE countermeasures activating...', type: 'danger' },
			{ text: '> System admin alerted', type: 'warning' }
		);
	} else {
		messages.push(
			{ text: '> CRITICAL: Maximum depth reached', type: 'danger' },
			{ text: '> ████ TRACE IMMINENT ████', type: 'danger' },
			{ text: '> Extraction recommended NOW', type: 'warning' }
		);
	}

	// Target proximity messages
	if (target) {
		const progress = depth / target;
		if (progress >= 0.9 && progress < 1) {
			messages.push(
				{ text: '> Approaching exit node...', type: 'warning' },
				{ text: '> Prepare for extraction', type: 'info' }
			);
		} else if (progress >= 1 && progress < 1.1) {
			messages.push(
				{ text: '> EXIT POINT REACHED', type: 'success' },
				{ text: '> Extraction secured!', type: 'success' }
			);
		}
	}

	// Return random message from appropriate pool
	return messages[Math.floor(Math.random() * messages.length)] || null;
}

// ============================================================================
// OUTCOME MESSAGES
// ============================================================================

/** Messages when player wins (passed target before crash) */
export const WIN_MESSAGES: TerminalMessage[] = [
	{ text: '> EXTRACTION COMPLETE', type: 'success' },
	{ text: '> Payload secured', type: 'success', delay: 300 },
	{ text: '> Connection terminated cleanly', type: 'info', delay: 600 },
	{ text: '> Funds transferred to wallet', type: 'success', delay: 900 },
];

/** Messages when player loses (crashed before/at target) */
export const LOSE_MESSAGES: TerminalMessage[] = [
	{ text: '> ████ ICE DETECTED ████', type: 'danger' },
	{ text: '> TRACE LOCK: CONFIRMED', type: 'danger', delay: 200 },
	{ text: '> Connection: SEVERED', type: 'danger', delay: 400 },
	{ text: '> Extraction: FAILED', type: 'danger', delay: 600 },
	{ text: '> Stake burned by network', type: 'warning', delay: 800 },
];

/** Messages when crash occurs (general) */
export const CRASH_MESSAGES: TerminalMessage[] = [
	{ text: '> ████████████████████████████', type: 'danger' },
	{ text: '> ICE COUNTERMEASURE DEPLOYED', type: 'danger', delay: 100 },
	{ text: '> All active connections traced', type: 'danger', delay: 300 },
	{ text: '> Network breach terminated', type: 'system', delay: 500 },
];

// ============================================================================
// DATA STREAM CONTENT
// ============================================================================

/** Generate random hex string */
function randomHex(length: number): string {
	const chars = '0123456789abcdef';
	return Array.from({ length }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
}

/** Generate random binary string */
function randomBinary(length: number): string {
	return Array.from({ length }, () => (Math.random() > 0.5 ? '1' : '0')).join('');
}

/** Data stream line generators for Theme B */
export const DATA_GENERATORS = {
	// Hex addresses
	address: () => `0x${randomHex(8)}`,

	// Binary chunks
	binary: () => randomBinary(12),

	// Memory addresses
	memory: () => `[${randomHex(4)}:${randomHex(4)}]`,

	// File paths
	path: () => {
		const dirs = ['sys', 'var', 'usr', 'etc', 'tmp', 'data', 'vault'];
		const exts = ['dat', 'bin', 'enc', 'key', 'log'];
		const dir = dirs[Math.floor(Math.random() * dirs.length)];
		const ext = exts[Math.floor(Math.random() * exts.length)];
		return `/${dir}/${randomHex(4)}.${ext}`;
	},

	// Encrypted blocks
	encrypted: () => `█${randomHex(6)}█`,

	// Network packets
	packet: () => `PKT:${randomHex(3)}>${randomHex(3)}`,

	// Data volumes
	volume: () => {
		const sizes = ['KB', 'MB', 'GB'];
		const size = sizes[Math.floor(Math.random() * sizes.length)];
		const value = Math.floor(Math.random() * 999) + 1;
		return `${value}${size}`;
	},
};

/** Generate a random data stream line */
export function generateDataLine(): { text: string; type: 'normal' | 'highlight' | 'encrypted' } {
	const generators = Object.values(DATA_GENERATORS);
	const generator = generators[Math.floor(Math.random() * generators.length)];
	const text = generator();

	// Determine type based on content
	let type: 'normal' | 'highlight' | 'encrypted' = 'normal';
	if (text.includes('█')) type = 'encrypted';
	else if (Math.random() > 0.85) type = 'highlight';

	return { text, type };
}

// ============================================================================
// ICE THREAT MESSAGES
// ============================================================================

/** Get ICE threat message based on threat level (0-100) */
export function getIceThreatMessage(threatLevel: number): string {
	if (threatLevel < 20) return 'LOW';
	if (threatLevel < 40) return 'MODERATE';
	if (threatLevel < 60) return 'ELEVATED';
	if (threatLevel < 80) return 'HIGH';
	if (threatLevel < 95) return 'CRITICAL';
	return '████ IMMINENT ████';
}

/** Get ICE threat color class */
export function getIceThreatColor(threatLevel: number): string {
	if (threatLevel < 30) return 'accent';
	if (threatLevel < 60) return 'cyan';
	if (threatLevel < 80) return 'amber';
	return 'red';
}

// ============================================================================
// SCANNING STATUS MESSAGES (50 unique messages for locked phase)
// ============================================================================

/**
 * Thematic scanning messages displayed during the locked/waiting phase.
 * These cycle every 2 seconds to create atmosphere and tension.
 * Based on GHOSTNET's hacker/terminal aesthetic.
 */
export const SCANNING_MESSAGES: string[] = [
	// Network scanning (10)
	'Scanning network topology...',
	'Probing firewall configurations...',
	'Mapping subnet architecture...',
	'Analyzing packet routes...',
	'Detecting ICE signatures...',
	'Querying DNS blackholes...',
	'Tracing proxy chains...',
	'Enumerating open ports...',
	'Sniffing encrypted channels...',
	'Resolving hidden nodes...',

	// Hash/crypto operations (10)
	'Awaiting block confirmation...',
	'Hashing seed parameters...',
	'Validating merkle root...',
	'Computing entropy pool...',
	'Deriving crash threshold...',
	'Sampling random oracle...',
	'Verifying chain state...',
	'Processing commitment hash...',
	'Finalizing block seed...',
	'Extracting VRF output...',

	// System operations (10)
	'Loading breach protocol...',
	'Initializing ghost sequence...',
	'Compiling extraction vectors...',
	'Calibrating trace scanners...',
	'Buffering data streams...',
	'Synchronizing network state...',
	'Allocating secure memory...',
	'Establishing tunnel integrity...',
	'Preparing cascade triggers...',
	'Arming countermeasures...',

	// Security/ICE themed (10)
	'Evading patrol routines...',
	'Bypassing authentication...',
	'Spoofing identity markers...',
	'Masking operator signature...',
	'Disrupting trace protocols...',
	'Injecting noise packets...',
	'Cycling through proxies...',
	'Deploying ghost protocol...',
	'Scrambling location data...',
	'Activating cloak sequence...',

	// Dramatic/tension building (10)
	'The network is watching...',
	'ICE countermeasures active...',
	'Trace scan imminent...',
	'Calculating survival odds...',
	'Processing final parameters...',
	'Point of no return...',
	'Commit sequence locked...',
	'Destiny being computed...',
	'The cascade awaits...',
	'Fate sealed in the chain...',
];

/**
 * Get a random scanning message.
 * Use this for one-time random selection.
 */
export function getRandomScanningMessage(): string {
	return SCANNING_MESSAGES[Math.floor(Math.random() * SCANNING_MESSAGES.length)];
}

/**
 * Get scanning message by index (for sequential cycling).
 * Wraps around when index exceeds array length.
 */
export function getScanningMessageByIndex(index: number): string {
	return SCANNING_MESSAGES[index % SCANNING_MESSAGES.length];
}
