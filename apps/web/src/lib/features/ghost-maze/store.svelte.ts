/**
 * Ghost Maze Game Store
 * ======================
 * Central state management for the Ghost Maze game.
 * Orchestrates the game engine, game loop, maze, tracers, scoring, and input.
 *
 * Uses Svelte 5 runes for reactivity.
 */

import { browser } from '$app/environment';
import type {
	Coord,
	Direction,
	MazeGrid,
	TracerState,
	TracerType,
	GhostMazePhase,
	EntryTier,
	InputRecord,
	RenderEntity,
	HunterTracerData,
	PhantomTracerData,
	PatrolTracerData,
	SwarmTracerData,
} from './types';
import { DIRECTION_VECTORS, OPPOSITE_DIRECTION, MAZE_CHARS } from './types';
import {
	generateMaze,
	getCell,
	getCellIndex,
	createRng,
	createInputHandler,
	canMove,
	tryMove,
	overlaps,
	getValidDirections,
	createGameLoop,
	shouldTracerMove,
	updatePatrol,
	updateHunter,
	updateSwarm,
	updateFrightened,
	updatePhantom,
	generatePatrolWaypoints,
} from './engine';
import type { PhantomAction } from './engine';
import {
	LEVELS,
	TOTAL_LEVELS,
	INITIAL_LIVES,
	MAX_LIVES,
	EXTRA_LIFE_SCORE,
	RESPAWN_INVINCIBILITY_TICKS,
	DEATH_ANIMATION_TICKS,
	GHOST_MODE_TICKS,
	GHOST_MODE_WARNING_TICKS,
	TRACER_RESPAWN_TICKS,
	EMP_FREEZE_TICKS,
	TICK_RATE,
	COMBO_DECAY_TICKS,
	COMBO_MULTIPLIERS,
	SCORE_DATA_PACKET,
	SCORE_TRACER_DESTROY_BASE,
	SCORE_LEVEL_CLEAR,
	SCORE_PERFECT_CLEAR,
	SCORE_TIME_BONUS_PER_SECOND,
	SCORE_NO_HIT_BONUS,
	SCORE_FULL_RUN,
	SCORE_FULL_RUN_PERFECT,
	LEVEL_INTRO_TICKS,
	LEVEL_CLEAR_TICKS,
	PHANTOM_TELEPORT_TICKS,
} from './constants';
import { createFrameLoop } from '$lib/features/arcade/engine';

// ============================================================================
// STATE INTERFACE
// ============================================================================

export interface GhostMazeState {
	phase: GhostMazePhase;
	currentLevel: number;
	maze: MazeGrid | null;
	dataRemaining: number;
	dataTotal: number;

	playerPos: Coord;
	playerDir: Direction;
	lives: number;
	isInvincible: boolean;
	hasEmp: boolean;

	ghostModeActive: boolean;
	ghostModeRemaining: number;

	tracers: TracerState[];

	score: number;
	combo: number;
	comboTimer: number;
	maxCombo: number;
	tracersDestroyedThisGhostMode: number;

	entryTier: EntryTier;
	seed: number | null;

	// Per-level tracking
	hitThisLevel: boolean;
	allTracersDestroyedThisLevel: boolean;
	levelsCleared: number;
	perfectLevels: number;
	totalTracersDestroyed: number;
	totalDataCollected: number;
	levelStartTick: number;

	// Phase timers (ticks)
	phaseTimer: number;

	// EMP
	empFreezeRemaining: number;

	// UI
	isPaused: boolean;
	error: string | null;
}

export interface GhostMazeStore {
	readonly state: GhostMazeState;
	readonly renderEntities: RenderEntity[];
	readonly mazeText: string;
	readonly comboMultiplier: number;

	startGame(tier: EntryTier, seed?: number): void;
	cleanup(): void;
}

// ============================================================================
// STORE FACTORY
// ============================================================================

export function createGhostMazeStore(): GhostMazeStore {
	// ─────────────────────────────────────────────────────────────────────
	// STATE
	// ─────────────────────────────────────────────────────────────────────

	let state = $state<GhostMazeState>({
		phase: 'idle',
		currentLevel: 1,
		maze: null,
		dataRemaining: 0,
		dataTotal: 0,
		playerPos: { x: 0, y: 0 },
		playerDir: 'up',
		lives: INITIAL_LIVES,
		isInvincible: false,
		hasEmp: true,
		ghostModeActive: false,
		ghostModeRemaining: 0,
		tracers: [],
		score: 0,
		combo: 0,
		comboTimer: 0,
		maxCombo: 0,
		tracersDestroyedThisGhostMode: 0,
		entryTier: 'free',
		seed: null,
		hitThisLevel: false,
		allTracersDestroyedThisLevel: false,
		levelsCleared: 0,
		perfectLevels: 0,
		totalTracersDestroyed: 0,
		totalDataCollected: 0,
		levelStartTick: 0,
		phaseTimer: 0,
		empFreezeRemaining: 0,
		isPaused: false,
		error: null,
	});

	// Sub-systems
	const input = createInputHandler();
	let rng: (() => number) | null = null;
	let inputLog: InputRecord[] = [];
	let currentTick = 0;
	let extraLifeAwarded = false;

	// Game loop (fixed timestep inside frame loop)
	const gameLoop = createGameLoop({
		onTick: handleTick,
		onRender: () => {}, // Svelte reactivity handles rendering
	});

	const frameLoop = createFrameLoop((delta) => {
		gameLoop.update(delta);
	});

	// ─────────────────────────────────────────────────────────────────────
	// DERIVED
	// ─────────────────────────────────────────────────────────────────────

	const comboMultiplier = $derived(getComboMultiplier(state.combo));

	const renderEntities = $derived.by(() => {
		if (!state.maze) return [];
		const entities: RenderEntity[] = [];

		// Player
		if (state.phase === 'playing' || state.phase === 'ghost_mode' || state.phase === 'respawn') {
			entities.push({
				id: 'player',
				type: 'player',
				x: state.playerPos.x,
				y: state.playerPos.y,
				char: MAZE_CHARS.PLAYER,
			});
		}

		// Tracers
		for (const tracer of state.tracers) {
			if (tracer.mode === 'dead') continue;

			let type: RenderEntity['type'];
			let char: string;

			if (tracer.mode === 'frightened') {
				type = 'tracer-frightened';
				char = MAZE_CHARS.TRACER_FRIGHTENED;
			} else if (tracer.mode === 'frozen') {
				type = 'tracer-frozen';
				char = MAZE_CHARS.TRACER_FROZEN;
			} else {
				type = `tracer-${tracer.type}` as RenderEntity['type'];
				char = {
					patrol: MAZE_CHARS.TRACER_PATROL,
					hunter: MAZE_CHARS.TRACER_HUNTER,
					phantom: MAZE_CHARS.TRACER_PHANTOM,
					swarm: MAZE_CHARS.TRACER_SWARM,
				}[tracer.type];
			}

			entities.push({
				id: `tracer-${tracer.id}`,
				type,
				x: tracer.pos.x,
				y: tracer.pos.y,
				char,
			});
		}

		// Power nodes
		if (state.maze) {
			for (const pos of state.maze.powerNodePositions) {
				const cell = getCell(state.maze, pos.x, pos.y);
				if (cell?.content === 'power_node') {
					entities.push({
						id: `pn-${pos.x}-${pos.y}`,
						type: 'power-node',
						x: pos.x,
						y: pos.y,
						char: MAZE_CHARS.POWER_NODE,
					});
				}
			}
		}

		return entities;
	});

	const mazeText = $derived.by(() => {
		if (!state.maze) return '';
		return renderMazeToText(state.maze);
	});

	// ─────────────────────────────────────────────────────────────────────
	// GAME LIFECYCLE
	// ─────────────────────────────────────────────────────────────────────

	function startGame(tier: EntryTier, seed?: number): void {
		if (!browser) return;

		const gameSeed = seed ?? Math.floor(Math.random() * 2 ** 32);
		rng = createRng(gameSeed);
		inputLog = [];
		currentTick = 0;
		extraLifeAwarded = false;

		state = {
			...state,
			phase: 'level_intro',
			currentLevel: 1,
			lives: INITIAL_LIVES,
			score: 0,
			combo: 0,
			comboTimer: 0,
			maxCombo: 0,
			entryTier: tier,
			seed: gameSeed,
			hitThisLevel: false,
			allTracersDestroyedThisLevel: false,
			levelsCleared: 0,
			perfectLevels: 0,
			totalTracersDestroyed: 0,
			totalDataCollected: 0,
			isPaused: false,
			error: null,
			hasEmp: true,
			ghostModeActive: false,
			ghostModeRemaining: 0,
			tracersDestroyedThisGhostMode: 0,
			empFreezeRemaining: 0,
			isInvincible: false,
			phaseTimer: LEVEL_INTRO_TICKS,
		};

		setupLevel(1);

		input.reset();
		gameLoop.reset();
		frameLoop.start();

		// Set up keyboard listeners
		if (browser) {
			window.addEventListener('keydown', handleKeyDown);
			window.addEventListener('keyup', handleKeyUp);
		}
	}

	function setupLevel(level: number): void {
		const config = LEVELS[level - 1];
		if (!config || !rng) return;

		const tracerCount = config.tracers.reduce((sum, t) => sum + t.count, 0);

		const maze = generateMaze({
			width: config.gridWidth,
			height: config.gridHeight,
			seed: rng() * 2 ** 32,
			loopFactor: config.loopFactor,
			tracerCount,
			dataPackets: config.dataPackets,
		});

		const tracers = createTracers(config.tracers, maze);

		state = {
			...state,
			currentLevel: level,
			maze,
			dataRemaining: maze.totalDataPackets,
			dataTotal: maze.totalDataPackets,
			playerPos: { ...maze.playerSpawn },
			playerDir: 'up',
			tracers,
			hitThisLevel: false,
			allTracersDestroyedThisLevel: false,
			hasEmp: true,
			ghostModeActive: false,
			ghostModeRemaining: 0,
			tracersDestroyedThisGhostMode: 0,
			empFreezeRemaining: 0,
			isInvincible: false,
			levelStartTick: currentTick,
		};
	}

	function createTracers(
		configs: readonly { type: TracerType; count: number }[],
		maze: MazeGrid,
	): TracerState[] {
		const tracers: TracerState[] = [];
		let id = 0;
		let spawnIdx = 0;

		for (const cfg of configs) {
			for (let i = 0; i < cfg.count; i++) {
				const spawnPos = maze.tracerSpawns[spawnIdx % maze.tracerSpawns.length];
				spawnIdx++;

				const tracer: TracerState = {
					id: id++,
					type: cfg.type,
					pos: { ...spawnPos },
					dir: 'left',
					mode: 'normal',
					respawnTimer: 0,
					data: createTracerData(cfg.type, spawnPos, maze, id - 1, rng!),
				};
				tracers.push(tracer);
			}
		}

		return tracers;
	}

	function createTracerData(
		type: TracerType,
		spawnPos: Coord,
		maze: MazeGrid,
		id: number,
		rng: () => number,
	) {
		switch (type) {
			case 'patrol':
				return {
					type: 'patrol' as const,
					waypoints: generatePatrolWaypoints(maze, spawnPos, rng),
					waypointIndex: 0,
				};
			case 'hunter':
				return {
					type: 'hunter' as const,
					chasing: false,
					chaseTicks: 0,
					homeCorner: {
						x: spawnPos.x < maze.width / 2 ? 0 : maze.width - 1,
						y: spawnPos.y < maze.height / 2 ? 0 : maze.height - 1,
					},
					currentPath: [] as Coord[],
					pathRefreshTicks: 0,
				};
			case 'phantom':
				return {
					type: 'phantom' as const,
					teleportTimer: PHANTOM_TELEPORT_TICKS,
					teleportWarning: false,
				};
			case 'swarm':
				return {
					type: 'swarm' as const,
					partnerId: id % 2 === 0 ? id + 1 : id - 1,
					flockOffset: (['up', 'down', 'left', 'right'] as const)[
						Math.floor(rng() * 4)
					],
				};
		}
	}

	// ─────────────────────────────────────────────────────────────────────
	// INPUT
	// ─────────────────────────────────────────────────────────────────────

	function handleKeyDown(e: KeyboardEvent): void {
		// Prevent default for game keys
		if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', ' ', 'Escape'].includes(e.key)) {
			e.preventDefault();
		}

		const action = input.onKeyDown(e.key);
		if (action) {
			inputLog.push({ tick: currentTick, action });

			// Handle pause toggle
			if (action === 'pause') {
				togglePause();
			}
		}
	}

	function handleKeyUp(e: KeyboardEvent): void {
		input.onKeyUp(e.key);
	}

	function togglePause(): void {
		if (state.phase === 'playing' || state.phase === 'ghost_mode') {
			state = { ...state, phase: 'paused', isPaused: true };
			gameLoop.pause();
		} else if (state.phase === 'paused') {
			const resumePhase = state.ghostModeActive ? 'ghost_mode' : 'playing';
			state = { ...state, phase: resumePhase as GhostMazePhase, isPaused: false };
			gameLoop.resume();
		}
	}

	// ─────────────────────────────────────────────────────────────────────
	// GAME TICK (15 ticks/sec)
	// ─────────────────────────────────────────────────────────────────────

	function handleTick(tick: number): void {
		currentTick = tick;

		switch (state.phase) {
			case 'level_intro':
				tickLevelIntro();
				break;
			case 'playing':
			case 'ghost_mode':
				tickPlaying();
				break;
			case 'player_death':
				tickPlayerDeath();
				break;
			case 'respawn':
				tickRespawn();
				break;
			case 'level_clear':
				tickLevelClear();
				break;
			default:
				break;
		}
	}

	// ─────────────────────────────────────────────────────────────────────
	// PHASE: LEVEL INTRO
	// ─────────────────────────────────────────────────────────────────────

	function tickLevelIntro(): void {
		state.phaseTimer--;
		if (state.phaseTimer <= 0) {
			state = { ...state, phase: 'playing', phaseTimer: 0 };
		}
	}

	// ─────────────────────────────────────────────────────────────────────
	// PHASE: PLAYING / GHOST MODE
	// ─────────────────────────────────────────────────────────────────────

	function tickPlaying(): void {
		if (!state.maze) return;
		const maze = state.maze;
		const levelConfig = LEVELS[state.currentLevel - 1];

		// 1. Process input
		input.tick();

		// 2. Handle EMP
		if (input.consumeEmp() && state.hasEmp) {
			activateEmp();
		}

		// 3. Move player
		movePlayer(maze);

		// 4. Check data packet collection
		checkDataCollection(maze);

		// 5. Check power node collection
		checkPowerNodeCollection(maze);

		// 6. Update ghost mode timer
		if (state.ghostModeActive) {
			state.ghostModeRemaining--;
			if (state.ghostModeRemaining <= 0) {
				endGhostMode();
			}
		}

		// 7. Update EMP freeze timer
		if (state.empFreezeRemaining > 0) {
			state.empFreezeRemaining--;
			if (state.empFreezeRemaining <= 0) {
				unfreezeTracers();
			}
		}

		// 8. Move tracers
		updateTracers(maze, levelConfig.playerSpeed);

		// 9. Check collisions with tracers
		checkTracerCollisions();

		// 10. Update combo decay
		if (state.comboTimer > 0) {
			state.comboTimer--;
			if (state.comboTimer <= 0 && state.combo > 0) {
				state = { ...state, combo: 0, comboTimer: 0 };
			}
		}

		// 11. Check invincibility decay
		if (state.isInvincible) {
			// Invincibility is managed by respawn timer
		}

		// 12. Check level clear
		if (state.dataRemaining <= 0) {
			triggerLevelClear();
		}

		// 13. Check extra life
		if (!extraLifeAwarded && state.score >= EXTRA_LIFE_SCORE && state.lives < MAX_LIVES) {
			state.lives++;
			extraLifeAwarded = true;
		}
	}

	function movePlayer(maze: MazeGrid): void {
		// Try buffered direction first
		const buffered = input.state.buffered;
		if (buffered && canMove(maze, state.playerPos, buffered)) {
			const newPos = tryMove(maze, state.playerPos, buffered);
			if (newPos) {
				state.playerPos = newPos;
				state.playerDir = buffered;
				input.consumeBuffer();
				return;
			}
		}

		// Fall back to current held direction
		const current = input.state.current;
		if (current && canMove(maze, state.playerPos, current)) {
			const newPos = tryMove(maze, state.playerPos, current);
			if (newPos) {
				state.playerPos = newPos;
				state.playerDir = current;
			}
		}
	}

	function checkDataCollection(maze: MazeGrid): void {
		const idx = getCellIndex(state.playerPos.x, state.playerPos.y, maze.width);
		const cell = maze.cells[idx];

		if (cell.content === 'data') {
			// Collect
			maze.cells[idx] = { ...cell, content: 'empty' };
			state.dataRemaining--;
			state.totalDataCollected++;

			// Combo
			state.combo++;
			state.comboTimer = COMBO_DECAY_TICKS;
			if (state.combo > state.maxCombo) {
				state.maxCombo = state.combo;
			}

			// Score with combo multiplier
			const mult = getComboMultiplier(state.combo);
			state.score += SCORE_DATA_PACKET * mult;
		}
	}

	function checkPowerNodeCollection(maze: MazeGrid): void {
		const idx = getCellIndex(state.playerPos.x, state.playerPos.y, maze.width);
		const cell = maze.cells[idx];

		if (cell.content === 'power_node') {
			maze.cells[idx] = { ...cell, content: 'empty' };
			activateGhostMode();
		}
	}

	function activateGhostMode(): void {
		state = {
			...state,
			phase: 'ghost_mode',
			ghostModeActive: true,
			ghostModeRemaining: GHOST_MODE_TICKS,
			tracersDestroyedThisGhostMode: 0,
		};

		// Set all active tracers to frightened
		for (const tracer of state.tracers) {
			if (tracer.mode === 'normal') {
				tracer.mode = 'frightened';
				tracer.dir = OPPOSITE_DIRECTION[tracer.dir]; // Reverse direction
			}
		}
	}

	function endGhostMode(): void {
		state = {
			...state,
			phase: 'playing',
			ghostModeActive: false,
			ghostModeRemaining: 0,
		};

		for (const tracer of state.tracers) {
			if (tracer.mode === 'frightened') {
				tracer.mode = 'normal';
			}
		}
	}

	function activateEmp(): void {
		state.hasEmp = false;
		state.empFreezeRemaining = EMP_FREEZE_TICKS;

		for (const tracer of state.tracers) {
			if (tracer.mode === 'normal' || tracer.mode === 'frightened') {
				tracer.mode = 'frozen';
			}
		}
	}

	function unfreezeTracers(): void {
		for (const tracer of state.tracers) {
			if (tracer.mode === 'frozen') {
				tracer.mode = state.ghostModeActive ? 'frightened' : 'normal';
			}
		}
	}

	function updateTracers(maze: MazeGrid, playerSpeed: number): void {
		for (const tracer of state.tracers) {
			// Handle dead tracers (respawn timer)
			if (tracer.mode === 'dead') {
				tracer.respawnTimer--;
				if (tracer.respawnTimer <= 0) {
					// Respawn at original position
					const spawnIdx = tracer.id % maze.tracerSpawns.length;
					tracer.pos = { ...maze.tracerSpawns[spawnIdx] };
					tracer.mode = state.ghostModeActive ? 'frightened' : 'normal';
				}
				continue;
			}

			// Frozen tracers don't move
			if (tracer.mode === 'frozen') continue;

			// Speed check
			const isFrightened = tracer.mode === 'frightened';
			if (!shouldTracerMove(tracer.type, currentTick, playerSpeed, isFrightened)) continue;

			// Get movement direction based on AI type
			let dir: Direction | null = null;

			if (isFrightened) {
				dir = updateFrightened(tracer, maze, state.playerPos);
			} else {
				switch (tracer.type) {
					case 'patrol':
						dir = updatePatrol(tracer, maze, state.playerPos);
						break;
					case 'hunter':
						dir = updateHunter(tracer, maze, state.playerPos);
						break;
					case 'phantom': {
						if (!rng) break;
						const action: PhantomAction = updatePhantom(tracer, maze, state.playerPos, rng);
						if (action.type === 'teleport' && action.destination) {
							tracer.pos = { ...action.destination };
						} else if (action.direction) {
							dir = action.direction;
						}
						break;
					}
					case 'swarm':
						dir = updateSwarm(tracer, maze, state.playerPos);
						break;
				}
			}

			// Apply movement
			if (dir) {
				const newPos = tryMove(maze, tracer.pos, dir);
				if (newPos) {
					tracer.pos = newPos;
					tracer.dir = dir;
				}
			}
		}
	}

	function checkTracerCollisions(): void {
		if (state.isInvincible) return;

		for (const tracer of state.tracers) {
			if (tracer.mode === 'dead' || tracer.mode === 'frozen') continue;
			if (!overlaps(state.playerPos, tracer.pos)) continue;

			if (tracer.mode === 'frightened') {
				// Destroy tracer
				tracer.mode = 'dead';
				tracer.respawnTimer = TRACER_RESPAWN_TICKS;

				// Score (doubling cascade)
				const destroyScore =
					SCORE_TRACER_DESTROY_BASE * 2 ** state.tracersDestroyedThisGhostMode;
				state.score += destroyScore;
				state.tracersDestroyedThisGhostMode++;
				state.totalTracersDestroyed++;
			} else {
				// Player hit!
				triggerPlayerDeath();
				return;
			}
		}
	}

	// ─────────────────────────────────────────────────────────────────────
	// PHASE: PLAYER DEATH
	// ─────────────────────────────────────────────────────────────────────

	function triggerPlayerDeath(): void {
		state = {
			...state,
			phase: 'player_death',
			lives: state.lives - 1,
			hitThisLevel: true,
			phaseTimer: DEATH_ANIMATION_TICKS,
			combo: 0,
			comboTimer: 0,
			ghostModeActive: false,
			ghostModeRemaining: 0,
		};

		// Reset tracer modes
		for (const tracer of state.tracers) {
			if (tracer.mode === 'frightened') tracer.mode = 'normal';
		}
	}

	function tickPlayerDeath(): void {
		state.phaseTimer--;
		if (state.phaseTimer <= 0) {
			if (state.lives <= 0) {
				state = { ...state, phase: 'game_over' };
				endGame();
			} else {
				// Respawn
				state = {
					...state,
					phase: 'respawn',
					playerPos: state.maze ? { ...state.maze.playerSpawn } : state.playerPos,
					isInvincible: true,
					phaseTimer: RESPAWN_INVINCIBILITY_TICKS,
				};

				// Reset tracers to home positions
				if (state.maze) {
					for (const tracer of state.tracers) {
						if (tracer.mode !== 'dead') {
							const spawnIdx = tracer.id % state.maze.tracerSpawns.length;
							tracer.pos = { ...state.maze.tracerSpawns[spawnIdx] };
							tracer.mode = 'normal';
						}
					}
				}
			}
		}
	}

	// ─────────────────────────────────────────────────────────────────────
	// PHASE: RESPAWN
	// ─────────────────────────────────────────────────────────────────────

	function tickRespawn(): void {
		state.phaseTimer--;
		if (state.phaseTimer <= 0) {
			state = { ...state, phase: 'playing', isInvincible: false, phaseTimer: 0 };
		}
	}

	// ─────────────────────────────────────────────────────────────────────
	// PHASE: LEVEL CLEAR
	// ─────────────────────────────────────────────────────────────────────

	function triggerLevelClear(): void {
		// Calculate bonuses
		const levelNum = state.currentLevel;
		state.score += SCORE_LEVEL_CLEAR * levelNum;

		// Time bonus
		const ticksElapsed = currentTick - state.levelStartTick;
		const secondsRemaining = Math.max(0, 120 - ticksElapsed / TICK_RATE);
		state.score += Math.floor(secondsRemaining * SCORE_TIME_BONUS_PER_SECOND);

		// No-hit bonus
		if (!state.hitThisLevel) {
			state.score += SCORE_NO_HIT_BONUS;
		}

		// Perfect clear (all data + all tracers destroyed)
		const allTracersDestroyed = state.tracers.every(
			(t) => t.mode === 'dead' || t.respawnTimer > 0,
		);
		if (allTracersDestroyed) {
			state.score += SCORE_PERFECT_CLEAR * levelNum;
			state.perfectLevels++;
		}

		state.levelsCleared++;

		state = {
			...state,
			phase: 'level_clear',
			phaseTimer: LEVEL_CLEAR_TICKS,
		};
	}

	function tickLevelClear(): void {
		state.phaseTimer--;
		if (state.phaseTimer <= 0) {
			if (state.currentLevel >= TOTAL_LEVELS) {
				// Game complete!
				state.score += SCORE_FULL_RUN;
				if (state.perfectLevels === TOTAL_LEVELS) {
					state.score += SCORE_FULL_RUN_PERFECT;
				}
				state = { ...state, phase: 'game_over' };
				endGame();
			} else {
				// Next level
				const nextLevel = state.currentLevel + 1;
				state = { ...state, phase: 'level_intro', phaseTimer: LEVEL_INTRO_TICKS };
				setupLevel(nextLevel);
			}
		}
	}

	// ─────────────────────────────────────────────────────────────────────
	// GAME END
	// ─────────────────────────────────────────────────────────────────────

	function endGame(): void {
		frameLoop.stop();
		if (browser) {
			window.removeEventListener('keydown', handleKeyDown);
			window.removeEventListener('keyup', handleKeyUp);
		}
	}

	function cleanup(): void {
		frameLoop.stop();
		input.reset();
		if (browser) {
			window.removeEventListener('keydown', handleKeyDown);
			window.removeEventListener('keyup', handleKeyUp);
		}
	}

	// ─────────────────────────────────────────────────────────────────────
	// HELPERS
	// ─────────────────────────────────────────────────────────────────────

	function getComboMultiplier(combo: number): number {
		for (const tier of COMBO_MULTIPLIERS) {
			if (combo >= tier.minCombo) return tier.multiplier;
		}
		return 1;
	}

	// ─────────────────────────────────────────────────────────────────────
	// MAZE RENDERING (text)
	// ─────────────────────────────────────────────────────────────────────

	function renderMazeToText(maze: MazeGrid): string {
		const lines: string[] = [];

		for (let y = 0; y < maze.height; y++) {
			let line = '';
			for (let x = 0; x < maze.width; x++) {
				const cell = maze.cells[y * maze.width + x];

				if (cell.content === 'data') {
					line += MAZE_CHARS.DATA_PACKET;
				} else if (cell.content === 'power_node') {
					line += MAZE_CHARS.EMPTY; // Rendered as overlay
				} else {
					// Determine wall character based on which walls this cell has
					const hasAnyWall = cell.walls.up || cell.walls.down || cell.walls.left || cell.walls.right;
					const allWalls = cell.walls.up && cell.walls.down && cell.walls.left && cell.walls.right;

					if (allWalls) {
						line += MAZE_CHARS.CROSS;
					} else if (hasAnyWall && cell.walls.up && cell.walls.down && !cell.walls.left && !cell.walls.right) {
						line += MAZE_CHARS.WALL_V;
					} else if (hasAnyWall && !cell.walls.up && !cell.walls.down && cell.walls.left && cell.walls.right) {
						line += MAZE_CHARS.WALL_H;
					} else {
						line += MAZE_CHARS.EMPTY;
					}
				}
			}
			lines.push(line);
		}

		return lines.join('\n');
	}

	// ─────────────────────────────────────────────────────────────────────
	// RETURN
	// ─────────────────────────────────────────────────────────────────────

	return {
		get state() {
			return state;
		},
		get renderEntities() {
			return renderEntities;
		},
		get mazeText() {
			return mazeText;
		},
		get comboMultiplier() {
			return comboMultiplier;
		},
		startGame,
		cleanup,
	};
}
