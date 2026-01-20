/**
 * GHOSTNET Error Types
 * =====================
 * Unified error handling for wallet, contract, and application errors.
 * Uses GHOSTNET terminology: "jack in", "extract", "traced", "$DATA"
 */

// ════════════════════════════════════════════════════════════════
// ERROR CODES
// ════════════════════════════════════════════════════════════════

/** All possible error codes in GHOSTNET */
export type ErrorCode =
	// Wallet errors
	| 'WALLET_NOT_CONNECTED'
	| 'WALLET_REJECTED'
	| 'PROVIDER_ERROR'
	// Balance errors
	| 'INSUFFICIENT_BALANCE'
	| 'INSUFFICIENT_ALLOWANCE'
	// Transaction errors
	| 'TRANSACTION_FAILED'
	| 'TRANSACTION_REVERTED'
	| 'NETWORK_ERROR'
	// Position errors
	| 'POSITION_NOT_FOUND'
	| 'ALREADY_JACKED_IN'
	// Level errors
	| 'LEVEL_FULL'
	| 'MIN_STAKE_NOT_MET'
	// Timing errors
	| 'COOLDOWN_ACTIVE'
	| 'SCAN_IN_PROGRESS'
	// Fallback
	| 'UNKNOWN_ERROR';

/** Severity levels for error display */
export type ErrorSeverity = 'info' | 'warning' | 'error' | 'critical';

/** Error display configuration */
export interface ErrorDisplay {
	title: string;
	message: string;
	severity: ErrorSeverity;
}

/** Error metadata for each error code */
const ERROR_METADATA: Record<ErrorCode, ErrorDisplay> = {
	// Wallet errors
	WALLET_NOT_CONNECTED: {
		title: 'Wallet Required',
		message: 'Connect your wallet to jack in',
		severity: 'info'
	},
	WALLET_REJECTED: {
		title: 'Rejected',
		message: 'You cancelled the transaction',
		severity: 'warning'
	},
	PROVIDER_ERROR: {
		title: 'Wallet Error',
		message: 'Your wallet encountered an error',
		severity: 'error'
	},

	// Balance errors
	INSUFFICIENT_BALANCE: {
		title: 'Not Enough $DATA',
		message: 'You need more $DATA for this action',
		severity: 'error'
	},
	INSUFFICIENT_ALLOWANCE: {
		title: 'Approval Needed',
		message: 'Approve $DATA spending first',
		severity: 'info'
	},

	// Transaction errors
	TRANSACTION_FAILED: {
		title: 'TX Failed',
		message: "Transaction couldn't be completed",
		severity: 'error'
	},
	TRANSACTION_REVERTED: {
		title: 'TX Reverted',
		message: 'The network rejected this transaction',
		severity: 'error'
	},
	NETWORK_ERROR: {
		title: 'Network Down',
		message: "Can't connect to the network",
		severity: 'critical'
	},

	// Position errors
	POSITION_NOT_FOUND: {
		title: 'No Position',
		message: "You're not jacked in yet",
		severity: 'info'
	},
	ALREADY_JACKED_IN: {
		title: 'Already In',
		message: "You're already jacked into the network",
		severity: 'info'
	},

	// Level errors
	LEVEL_FULL: {
		title: 'Level Full',
		message: 'This security clearance is at capacity',
		severity: 'warning'
	},
	MIN_STAKE_NOT_MET: {
		title: 'Below Minimum',
		message: 'Amount is below minimum for this level',
		severity: 'warning'
	},

	// Timing errors
	COOLDOWN_ACTIVE: {
		title: 'Cooldown',
		message: 'Wait before trying again',
		severity: 'info'
	},
	SCAN_IN_PROGRESS: {
		title: 'Scan Active',
		message: 'A trace scan is in progress - try after',
		severity: 'warning'
	},

	// Fallback
	UNKNOWN_ERROR: {
		title: 'Error',
		message: 'Something went wrong',
		severity: 'error'
	}
};

// ════════════════════════════════════════════════════════════════
// BASE ERROR CLASS
// ════════════════════════════════════════════════════════════════

/**
 * Base error class for all GHOSTNET errors.
 * Provides structured error information with codes and recovery hints.
 *
 * @example
 * ```ts
 * throw new GhostnetError('User rejected transaction', 'WALLET_REJECTED');
 *
 * // With non-recoverable flag
 * throw new GhostnetError('Network unreachable', 'NETWORK_ERROR', false);
 * ```
 */
export class GhostnetError extends Error {
	/** Error code for programmatic handling */
	public readonly code: ErrorCode;

	/** Whether the user can recover from this error (retry, fix, etc.) */
	public readonly recoverable: boolean;

	/** Original error that caused this, if any */
	public readonly cause?: unknown;

	constructor(message: string, code: ErrorCode, recoverable: boolean = true, cause?: unknown) {
		super(message);
		this.name = 'GhostnetError';
		this.code = code;
		this.recoverable = recoverable;
		this.cause = cause;

		// Maintains proper stack trace in V8 environments
		if (Error.captureStackTrace) {
			Error.captureStackTrace(this, GhostnetError);
		}
	}

	/**
	 * Get user-friendly display information for this error
	 */
	getDisplay(): ErrorDisplay {
		return getErrorDisplay(this);
	}
}

// ════════════════════════════════════════════════════════════════
// TRANSACTION STATE
// ════════════════════════════════════════════════════════════════

/** Transaction lifecycle status */
export type TransactionStatus =
	| 'idle'
	| 'preparing'
	| 'awaiting_signature'
	| 'pending'
	| 'confirmed'
	| 'failed';

/**
 * Represents the current state of a transaction.
 * Used for UI feedback during transaction lifecycle.
 */
export interface TransactionState {
	/** Current transaction status */
	status: TransactionStatus;

	/** Transaction hash (available after submission) */
	hash?: `0x${string}`;

	/** Error that caused failure (if status is 'failed') */
	error?: GhostnetError;

	/** Human-readable action name ("Jack In", "Extract", etc.) */
	action?: string;
}

/**
 * Create an idle transaction state
 */
export function createIdleState(): TransactionState {
	return { status: 'idle' };
}

/**
 * Create a transaction state for a specific action
 */
export function createTransactionState(
	action: string,
	status: TransactionStatus = 'preparing'
): TransactionState {
	return { status, action };
}

// ════════════════════════════════════════════════════════════════
// ERROR DISPLAY
// ════════════════════════════════════════════════════════════════

/**
 * Get user-friendly error display information.
 * Returns title, message, and severity for UI rendering.
 *
 * @param error - The GhostnetError to display
 * @returns Display configuration with title, message, and severity
 *
 * @example
 * ```ts
 * const { title, message, severity } = getErrorDisplay(error);
 * // title: "TX Failed"
 * // message: "Transaction couldn't be completed"
 * // severity: "error"
 * ```
 */
export function getErrorDisplay(error: GhostnetError): ErrorDisplay {
	const metadata = ERROR_METADATA[error.code];

	// If we have a custom message that's more specific, use it
	// but keep the standard title and severity
	if (error.message && error.message !== metadata.message) {
		return {
			title: metadata.title,
			message: error.message,
			severity: metadata.severity
		};
	}

	return metadata;
}

/**
 * Get display info for an error code directly
 */
export function getErrorDisplayByCode(code: ErrorCode): ErrorDisplay {
	return ERROR_METADATA[code];
}

// ════════════════════════════════════════════════════════════════
// ERROR PARSING
// ════════════════════════════════════════════════════════════════

/** Patterns for detecting user rejection errors */
const USER_REJECTION_PATTERNS = [
	'user rejected',
	'user denied',
	'rejected by user',
	'user cancelled',
	'user canceled',
	'action_rejected',
	'user refused'
];

/** Patterns for detecting insufficient funds errors */
const INSUFFICIENT_FUNDS_PATTERNS = [
	'insufficient funds',
	'insufficient balance',
	'not enough balance',
	'balance too low',
	'exceeds balance'
];

/** Patterns for detecting network errors */
const NETWORK_ERROR_PATTERNS = [
	'network error',
	'failed to fetch',
	'connection refused',
	'connection failed',
	'timeout',
	'econnrefused',
	'enotfound',
	'could not connect'
];

/** Contract revert reason to error code mapping */
const REVERT_REASON_MAP: Record<string, ErrorCode> = {
	// Common contract errors (match against contract custom errors)
	InsufficientBalance: 'INSUFFICIENT_BALANCE',
	InsufficientAllowance: 'INSUFFICIENT_ALLOWANCE',
	NoActivePosition: 'POSITION_NOT_FOUND',
	PositionExists: 'ALREADY_JACKED_IN',
	AlreadyJackedIn: 'ALREADY_JACKED_IN',
	LevelFull: 'LEVEL_FULL',
	ExceedsCapacity: 'LEVEL_FULL',
	BelowMinimum: 'MIN_STAKE_NOT_MET',
	MinStakeNotMet: 'MIN_STAKE_NOT_MET',
	CooldownActive: 'COOLDOWN_ACTIVE',
	OnCooldown: 'COOLDOWN_ACTIVE',
	ScanInProgress: 'SCAN_IN_PROGRESS',
	PositionLocked: 'SCAN_IN_PROGRESS'
};

/**
 * Check if a string matches any pattern in a list (case-insensitive)
 */
function matchesPattern(str: string, patterns: string[]): boolean {
	const lower = str.toLowerCase();
	return patterns.some((pattern) => lower.includes(pattern));
}

/**
 * Extract revert reason from error message
 */
function extractRevertReason(message: string): string | null {
	// Match common revert patterns
	const patterns = [
		/reverted with reason string '([^']+)'/i,
		/reverted with custom error '([^']+)'/i,
		/reason="([^"]+)"/i,
		/Error: ([A-Z][a-zA-Z]+)\(/,
		/custom error '([^']+)'/i,
		/revert ([A-Z][a-zA-Z]+)/i
	];

	for (const pattern of patterns) {
		const match = message.match(pattern);
		if (match?.[1]) {
			return match[1];
		}
	}

	return null;
}

/**
 * Parse unknown errors into structured GhostnetError.
 * Handles viem errors, wallet errors, contract reverts, and generic errors.
 *
 * @param err - Any error object
 * @returns A structured GhostnetError
 *
 * @example
 * ```ts
 * try {
 *   await contract.jackIn(level, amount);
 * } catch (err) {
 *   const error = parseError(err);
 *   console.log(error.code); // 'WALLET_REJECTED'
 *   console.log(error.recoverable); // true
 * }
 * ```
 */
export function parseError(err: unknown): GhostnetError {
	// Already a GhostnetError - return as-is
	if (err instanceof GhostnetError) {
		return err;
	}

	// Handle Error objects
	if (err instanceof Error) {
		const message = err.message || '';
		const name = err.name || '';
		const fullText = `${name} ${message}`;

		// Check for user rejection (wallet cancelled)
		if (
			name === 'UserRejectedRequestError' ||
			matchesPattern(fullText, USER_REJECTION_PATTERNS)
		) {
			return new GhostnetError('You cancelled the transaction', 'WALLET_REJECTED', true, err);
		}

		// Check for insufficient funds
		if (matchesPattern(fullText, INSUFFICIENT_FUNDS_PATTERNS)) {
			return new GhostnetError(
				'You need more $DATA for this action',
				'INSUFFICIENT_BALANCE',
				true,
				err
			);
		}

		// Check for network errors
		if (matchesPattern(fullText, NETWORK_ERROR_PATTERNS)) {
			return new GhostnetError("Can't connect to the network", 'NETWORK_ERROR', false, err);
		}

		// Check for contract reverts with custom errors
		if (
			name === 'ContractFunctionExecutionError' ||
			name === 'ContractFunctionRevertedError' ||
			message.includes('reverted')
		) {
			const reason = extractRevertReason(fullText);

			if (reason) {
				// Check if we have a mapped error code for this reason
				const mappedCode = REVERT_REASON_MAP[reason];
				if (mappedCode) {
					const display = ERROR_METADATA[mappedCode];
					return new GhostnetError(display.message, mappedCode, true, err);
				}

				// Unknown revert reason - use as message
				return new GhostnetError(reason, 'TRANSACTION_REVERTED', true, err);
			}

			// Generic revert
			return new GhostnetError(
				'The network rejected this transaction',
				'TRANSACTION_REVERTED',
				true,
				err
			);
		}

		// Check for chain mismatch
		if (name === 'ChainMismatchError' || message.includes('chain mismatch')) {
			return new GhostnetError('Please switch to the correct network', 'PROVIDER_ERROR', true, err);
		}

		// Check for provider/connector issues
		if (
			message.includes('No connector found') ||
			message.includes('Connector not found') ||
			message.includes('provider')
		) {
			return new GhostnetError('Your wallet encountered an error', 'PROVIDER_ERROR', true, err);
		}

		// Generic transaction failure
		if (message.includes('transaction failed') || message.includes('Transaction failed')) {
			return new GhostnetError(
				"Transaction couldn't be completed",
				'TRANSACTION_FAILED',
				true,
				err
			);
		}

		// Fall through with original message
		return new GhostnetError(message || 'Something went wrong', 'UNKNOWN_ERROR', true, err);
	}

	// Handle string errors
	if (typeof err === 'string') {
		// Check patterns against string
		if (matchesPattern(err, USER_REJECTION_PATTERNS)) {
			return new GhostnetError('You cancelled the transaction', 'WALLET_REJECTED', true, err);
		}
		if (matchesPattern(err, NETWORK_ERROR_PATTERNS)) {
			return new GhostnetError("Can't connect to the network", 'NETWORK_ERROR', false, err);
		}
		return new GhostnetError(err, 'UNKNOWN_ERROR', true, err);
	}

	// Handle objects with message property
	if (err && typeof err === 'object' && 'message' in err) {
		return parseError(new Error(String((err as { message: unknown }).message)));
	}

	// Fallback for completely unknown errors
	return new GhostnetError('Something went wrong', 'UNKNOWN_ERROR', true, err);
}

// ════════════════════════════════════════════════════════════════
// FACTORY FUNCTIONS
// ════════════════════════════════════════════════════════════════

/**
 * Create a wallet not connected error
 */
export function walletNotConnected(): GhostnetError {
	return new GhostnetError('Connect your wallet to jack in', 'WALLET_NOT_CONNECTED', true);
}

/**
 * Create a position not found error
 */
export function positionNotFound(): GhostnetError {
	return new GhostnetError("You're not jacked in yet", 'POSITION_NOT_FOUND', true);
}

/**
 * Create an insufficient balance error
 * @param required - Amount needed (optional, for custom message)
 * @param available - Amount available (optional, for custom message)
 */
export function insufficientBalance(required?: bigint, available?: bigint): GhostnetError {
	let message = 'You need more $DATA for this action';
	if (required !== undefined && available !== undefined) {
		message = `Need ${required} $DATA but only have ${available}`;
	}
	return new GhostnetError(message, 'INSUFFICIENT_BALANCE', true);
}

/**
 * Create an insufficient allowance error
 */
export function insufficientAllowance(): GhostnetError {
	return new GhostnetError('Approve $DATA spending first', 'INSUFFICIENT_ALLOWANCE', true);
}

/**
 * Create a scan in progress error
 * @param level - The level being scanned (optional)
 */
export function scanInProgress(level?: string): GhostnetError {
	const message = level
		? `Trace scan in progress on ${level} - try after`
		: 'A trace scan is in progress - try after';
	return new GhostnetError(message, 'SCAN_IN_PROGRESS', true);
}

/**
 * Create an already jacked in error
 */
export function alreadyJackedIn(): GhostnetError {
	return new GhostnetError("You're already jacked into the network", 'ALREADY_JACKED_IN', true);
}

// ════════════════════════════════════════════════════════════════
// TYPE GUARDS
// ════════════════════════════════════════════════════════════════

/**
 * Check if an error is a GhostnetError
 */
export function isGhostnetError(err: unknown): err is GhostnetError {
	return err instanceof GhostnetError;
}

/**
 * Check if an error is recoverable
 */
export function isRecoverable(err: unknown): boolean {
	if (err instanceof GhostnetError) {
		return err.recoverable;
	}
	// Most errors are assumed recoverable
	return true;
}

/**
 * Check if an error is a user rejection
 */
export function isUserRejection(err: unknown): boolean {
	if (err instanceof GhostnetError) {
		return err.code === 'WALLET_REJECTED';
	}
	if (err instanceof Error) {
		return matchesPattern(err.message, USER_REJECTION_PATTERNS);
	}
	return false;
}

/**
 * Check if an error is network-related
 */
export function isNetworkError(err: unknown): boolean {
	if (err instanceof GhostnetError) {
		return err.code === 'NETWORK_ERROR';
	}
	if (err instanceof Error) {
		return matchesPattern(err.message, NETWORK_ERROR_PATTERNS);
	}
	return false;
}
