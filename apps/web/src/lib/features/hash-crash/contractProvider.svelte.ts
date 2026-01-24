/**
 * Hash Crash Contract Provider
 * =============================
 * Provides contract-backed data for the Hash Crash game.
 * Polls contract state and watches events for real-time updates.
 *
 * ARCHITECTURE:
 * - This provider is an alternative to WebSocket for data
 * - The store consumes from this provider (or simulation)
 * - Clean separation: provider handles blockchain, store handles UI
 *
 * USAGE:
 * ```ts
 * const provider = createContractProvider();
 * provider.connect();
 * // Access state via provider.state
 * // Place bet via provider.placeBet(amount, target)
 * ```
 */

import { browser } from '$app/environment';
import { wallet } from '$lib/web3/wallet.svelte';
import {
	getCurrentRoundId,
	getRound,
	getPlayerBet,
	getRoundPlayers,
	isSeedReady,
	getDataBalance,
	getWithdrawableBalance,
	startRound as contractStartRound,
	placeBet as contractPlaceBet,
	lockRound as contractLockRound,
	revealCrash as contractRevealCrash,
	settleAll as contractSettleAll,
	withdraw as contractWithdraw,
	watchBetPlaced,
	watchCrashPointRevealed,
	watchPlayerWon,
	watchRoundStarted,
	parseContractError,
	formatMultiplier,
	SessionState,
	type RoundData,
	type PlayerBetData,
} from './contracts';

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

export interface ContractProviderState {
	/** Current round ID */
	roundId: bigint;
	/** Round data from contract */
	round: RoundData | null;
	/** Player's bet in current round */
	playerBet: PlayerBetData | null;
	/** All players in current round */
	players: PlayerInfo[];
	/** Player's DATA balance */
	balance: bigint;
	/** Player's withdrawable winnings */
	withdrawable: bigint;
	/** Whether seed is ready for reveal */
	seedReady: boolean;
	/** Connection status */
	isConnected: boolean;
	/** Loading state for transactions */
	isLoading: boolean;
	/** Current transaction hash (if any) */
	pendingTx: `0x${string}` | null;
	/** Error message if any */
	error: string | null;
	/** Last poll timestamp */
	lastPoll: number;
}

export interface PlayerInfo {
	address: `0x${string}`;
	amount: bigint;
	targetMultiplier: number;
	settled: boolean;
	won?: boolean;
	payout?: bigint;
}

export interface ContractProvider {
	/** Reactive state */
	readonly state: ContractProviderState;

	/** Derived: Can place bet (betting phase, no existing bet, wallet connected) */
	readonly canBet: boolean;

	/** Derived: Current phase as string */
	readonly phase: 'none' | 'betting' | 'locked' | 'revealed' | 'settled' | 'cancelled' | 'expired';

	/** Derived: Crash point (0 if not revealed) */
	readonly crashPoint: number;

	/** Derived: Time remaining in betting phase (ms) */
	readonly bettingTimeRemaining: number;

	/** Derived: Player result */
	readonly playerResult: 'pending' | 'won' | 'lost';

	/** Connect to contract (start polling/watching) */
	connect(): () => void;

	/** Disconnect (stop polling/watching) */
	disconnect(): void;

	/** Start a new round */
	startRound(): Promise<void>;

	/** Place a bet */
	placeBet(amount: bigint, targetMultiplier: number): Promise<void>;

	/** Lock the round (end betting) */
	lockRound(): Promise<void>;

	/** Reveal the crash point */
	revealCrash(): Promise<void>;

	/** Settle all players */
	settleAll(): Promise<void>;

	/** Withdraw winnings */
	withdraw(): Promise<void>;

	/** Force refresh state */
	refresh(): Promise<void>;
}

// ════════════════════════════════════════════════════════════════
// CONFIGURATION
// ════════════════════════════════════════════════════════════════

/** Poll interval in ms (how often to check contract state) */
const POLL_INTERVAL = 2000;

/** Fast poll interval during locked phase (waiting for seed) */
const FAST_POLL_INTERVAL = 500;

// ════════════════════════════════════════════════════════════════
// PROVIDER FACTORY
// ════════════════════════════════════════════════════════════════

export function createContractProvider(): ContractProvider {
	// ─────────────────────────────────────────────────────────────
	// STATE
	// ─────────────────────────────────────────────────────────────

	let state = $state<ContractProviderState>({
		roundId: 0n,
		round: null,
		playerBet: null,
		players: [],
		balance: 0n,
		withdrawable: 0n,
		seedReady: false,
		isConnected: false,
		isLoading: false,
		pendingTx: null,
		error: null,
		lastPoll: 0,
	});

	// Polling and event cleanup functions
	let pollInterval: ReturnType<typeof setInterval> | null = null;
	let unwatchBetPlaced: (() => void) | null = null;
	let unwatchCrashRevealed: (() => void) | null = null;
	let unwatchPlayerWon: (() => void) | null = null;
	let unwatchRoundStarted: (() => void) | null = null;

	// Track if provider is active (connect() was called)
	let isProviderActive = false;

	// ─────────────────────────────────────────────────────────────
	// EFFECTS
	// ─────────────────────────────────────────────────────────────

	// Start event watching when wallet connects (if provider is active)
	$effect(() => {
		if (isProviderActive && wallet.isConnected && wallet.chainId) {
			// Wallet just connected - try to start watching events
			startWatching();
		}
	});

	// ─────────────────────────────────────────────────────────────
	// DERIVED STATE
	// ─────────────────────────────────────────────────────────────

	const canBet = $derived(
		state.round?.state === SessionState.BETTING &&
			state.playerBet === null &&
			!state.isLoading &&
			wallet.isConnected
	);

	const phase = $derived.by(() => {
		if (!state.round) return 'none';
		switch (state.round.state) {
			case SessionState.BETTING:
				return 'betting';
			case SessionState.LOCKED:
				return 'locked';
			case SessionState.ACTIVE:
				return 'revealed';
			case SessionState.SETTLED:
				return 'settled';
			case SessionState.CANCELLED:
				return 'cancelled';
			case SessionState.EXPIRED:
				return 'expired';
			default:
				return 'none';
		}
	});

	const crashPoint = $derived(
		state.round?.crashMultiplier ? formatMultiplier(state.round.crashMultiplier) : 0
	);

	const bettingTimeRemaining = $derived.by(() => {
		if (!state.round || state.round.state !== SessionState.BETTING) return 0;
		const endTime = Number(state.round.bettingEndTime) * 1000; // Convert to ms
		const remaining = endTime - Date.now();
		return Math.max(0, remaining);
	});

	const playerResult = $derived.by((): 'pending' | 'won' | 'lost' => {
		if (!state.playerBet || state.playerBet.amount === 0n) return 'pending';
		if (!state.round || state.round.crashMultiplier === 0n) return 'pending';

		const target = formatMultiplier(state.playerBet.targetMultiplier);
		const crash = formatMultiplier(state.round.crashMultiplier);

		return target < crash ? 'won' : 'lost';
	});

	// ─────────────────────────────────────────────────────────────
	// POLLING
	// ─────────────────────────────────────────────────────────────

	async function poll(): Promise<void> {
		if (!browser || !wallet.isConnected) return;

		try {
			const roundId = await getCurrentRoundId();
			const round = await getRound(roundId);

			// Get player's bet if wallet connected
			let playerBet: PlayerBetData | null = null;
			if (wallet.address) {
				playerBet = await getPlayerBet(roundId, wallet.address);
				// Normalize: if amount is 0, treat as no bet
				if (playerBet.amount === 0n) {
					playerBet = null;
				}
			}

			// Check seed readiness during locked phase
			let seedReady = false;
			if (round.state === SessionState.LOCKED) {
				seedReady = await isSeedReady(roundId);
			}

			// Get player balances
			let balance = 0n;
			let withdrawable = 0n;
			if (wallet.address) {
				[balance, withdrawable] = await Promise.all([
					getDataBalance(wallet.address),
					getWithdrawableBalance(wallet.address),
				]);
			}

			// Fetch all players
			const playerAddresses = await getRoundPlayers(roundId);
			const players: PlayerInfo[] = await Promise.all(
				playerAddresses.map(async (addr) => {
					const bet = await getPlayerBet(roundId, addr);
					return {
						address: addr,
						amount: bet.amount,
						targetMultiplier: formatMultiplier(bet.targetMultiplier),
						settled: bet.settled,
						// Calculate won/payout if round is revealed
						won:
							round.crashMultiplier > 0n ? bet.targetMultiplier < round.crashMultiplier : undefined,
						payout:
							round.crashMultiplier > 0n && bet.targetMultiplier < round.crashMultiplier
								? (bet.amount * bet.targetMultiplier) / 100n
								: undefined,
					};
				})
			);

			state = {
				...state,
				roundId,
				round,
				playerBet,
				players,
				balance,
				withdrawable,
				seedReady,
				lastPoll: Date.now(),
				error: null,
			};
		} catch (err) {
			console.error('[ContractProvider] Poll error:', err);
			// Don't overwrite state on poll errors, just log
		}
	}

	function startPolling(): void {
		if (pollInterval) return;

		// Initial poll
		poll();

		// Set up interval
		pollInterval = setInterval(() => {
			// Use faster polling during locked phase
			const interval =
				state.round?.state === SessionState.LOCKED ? FAST_POLL_INTERVAL : POLL_INTERVAL;

			// Adjust interval if needed
			if (pollInterval) {
				clearInterval(pollInterval);
				pollInterval = setInterval(poll, interval);
			}

			poll();
		}, POLL_INTERVAL);
	}

	function stopPolling(): void {
		if (pollInterval) {
			clearInterval(pollInterval);
			pollInterval = null;
		}
	}

	// ─────────────────────────────────────────────────────────────
	// EVENT WATCHING
	// ─────────────────────────────────────────────────────────────

	function startWatching(): void {
		// Guard: Only start watching if wallet is connected (we need chainId for contract address)
		if (!wallet.isConnected || !wallet.chainId) {
			return;
		}

		// Already watching
		if (unwatchBetPlaced) {
			return;
		}

		try {
			// Watch for new bets
			unwatchBetPlaced = watchBetPlaced((roundId, player, amount, _netAmount, targetMultiplier) => {
				if (roundId !== state.roundId) return;

				// Add player to list
				const newPlayer: PlayerInfo = {
					address: player,
					amount,
					targetMultiplier: formatMultiplier(targetMultiplier),
					settled: false,
				};

				state = {
					...state,
					players: [...state.players.filter((p) => p.address !== player), newPlayer],
				};

				// If this is our bet, update playerBet
				if (wallet.address && player.toLowerCase() === wallet.address.toLowerCase()) {
					state = {
						...state,
						playerBet: {
							amount,
							grossAmount: amount,
							targetMultiplier,
							settled: false,
						},
						isLoading: false,
						pendingTx: null,
					};
				}
			});

			// Watch for crash reveals
			unwatchCrashRevealed = watchCrashPointRevealed((roundId, crashMultiplier, _seed) => {
				if (roundId !== state.roundId) return;

				state = {
					...state,
					round: state.round
						? {
								...state.round,
								state: SessionState.ACTIVE,
								crashMultiplier,
							}
						: null,
				};
			});

			// Watch for wins
			unwatchPlayerWon = watchPlayerWon((roundId, player, _targetMultiplier, payout) => {
				if (roundId !== state.roundId) return;

				state = {
					...state,
					players: state.players.map((p) =>
						p.address.toLowerCase() === player.toLowerCase()
							? { ...p, won: true, payout, settled: true }
							: p
					),
				};
			});

			// Watch for new rounds
			unwatchRoundStarted = watchRoundStarted((roundId, _seedBlock, _timestamp) => {
				// Refresh state for new round
				if (roundId > state.roundId) {
					poll();
				}
			});
		} catch (err) {
			// Contract not available on this chain - that's OK, we'll poll instead
			console.warn('[ContractProvider] Event watching not available:', err);
		}
	}

	function stopWatching(): void {
		unwatchBetPlaced?.();
		unwatchCrashRevealed?.();
		unwatchPlayerWon?.();
		unwatchRoundStarted?.();
		unwatchBetPlaced = null;
		unwatchCrashRevealed = null;
		unwatchPlayerWon = null;
		unwatchRoundStarted = null;
	}

	// ─────────────────────────────────────────────────────────────
	// CONNECTION
	// ─────────────────────────────────────────────────────────────

	function connect(): () => void {
		if (!browser) return () => {};

		isProviderActive = true;
		state = { ...state, isConnected: true, error: null };

		startPolling();
		// startWatching will be called by $effect when wallet connects
		// Try immediately in case wallet is already connected
		startWatching();

		return () => disconnect();
	}

	function disconnect(): void {
		isProviderActive = false;
		stopPolling();
		stopWatching();
		state = { ...state, isConnected: false };
	}

	// ─────────────────────────────────────────────────────────────
	// ACTIONS
	// ─────────────────────────────────────────────────────────────

	async function startRound(): Promise<void> {
		if (state.isLoading) return;

		state = { ...state, isLoading: true, error: null };

		try {
			const hash = await contractStartRound();
			state = { ...state, pendingTx: hash };

			// Refresh after tx
			await poll();
		} catch (err) {
			state = { ...state, error: parseContractError(err) };
		} finally {
			state = { ...state, isLoading: false, pendingTx: null };
		}
	}

	async function placeBet(amount: bigint, targetMultiplier: number): Promise<void> {
		if (!canBet || state.isLoading) return;

		state = { ...state, isLoading: true, error: null };

		try {
			const hash = await contractPlaceBet(amount, targetMultiplier);
			state = { ...state, pendingTx: hash };

			// Event watcher will update state, but poll for safety
			await poll();
		} catch (err) {
			state = { ...state, error: parseContractError(err) };
		} finally {
			state = { ...state, isLoading: false, pendingTx: null };
		}
	}

	async function lockRound(): Promise<void> {
		if (state.isLoading) return;

		state = { ...state, isLoading: true, error: null };

		try {
			const hash = await contractLockRound();
			state = { ...state, pendingTx: hash };
			await poll();
		} catch (err) {
			state = { ...state, error: parseContractError(err) };
		} finally {
			state = { ...state, isLoading: false, pendingTx: null };
		}
	}

	async function revealCrash(): Promise<void> {
		if (state.isLoading) return;

		state = { ...state, isLoading: true, error: null };

		try {
			const hash = await contractRevealCrash();
			state = { ...state, pendingTx: hash };
			await poll();
		} catch (err) {
			state = { ...state, error: parseContractError(err) };
		} finally {
			state = { ...state, isLoading: false, pendingTx: null };
		}
	}

	async function settleAll(): Promise<void> {
		if (state.isLoading) return;

		state = { ...state, isLoading: true, error: null };

		try {
			const hash = await contractSettleAll();
			state = { ...state, pendingTx: hash };
			await poll();
		} catch (err) {
			state = { ...state, error: parseContractError(err) };
		} finally {
			state = { ...state, isLoading: false, pendingTx: null };
		}
	}

	async function withdraw(): Promise<void> {
		if (state.isLoading) return;

		state = { ...state, isLoading: true, error: null };

		try {
			const hash = await contractWithdraw();
			state = { ...state, pendingTx: hash };
			await poll();
		} catch (err) {
			state = { ...state, error: parseContractError(err) };
		} finally {
			state = { ...state, isLoading: false, pendingTx: null };
		}
	}

	async function refresh(): Promise<void> {
		await poll();
	}

	// ─────────────────────────────────────────────────────────────
	// RETURN INTERFACE
	// ─────────────────────────────────────────────────────────────

	return {
		get state() {
			return state;
		},
		get canBet() {
			return canBet;
		},
		get phase() {
			return phase;
		},
		get crashPoint() {
			return crashPoint;
		},
		get bettingTimeRemaining() {
			return bettingTimeRemaining;
		},
		get playerResult() {
			return playerResult;
		},
		connect,
		disconnect,
		startRound,
		placeBet,
		lockRound,
		revealCrash,
		settleAll,
		withdraw,
		refresh,
	};
}
