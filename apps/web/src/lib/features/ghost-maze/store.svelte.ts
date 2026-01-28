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
	CellContent,
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
	ScatterChasePhase,
	BonusItem,
	ScorePopup,
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
	findPath,
	getPathDirection,
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
	computeTracers,
	computeDataPackets,
	SCATTER_CHASE_CONFIGS,
	ESCALATION_THRESHOLDS,
	PROXIMITY_ALERT_RANGE,
	NEAR_MISS_RANGE,
	BONUS_SPAWN_CHECK_INTERVAL,
	BONUS_SPAWN_CHANCE,
	BONUS_LIFETIME_TICKS,
	BONUS_TYPES,
	BONUS_WEIGHTS,
} from './constants';
import type { BonusType } from './constants';
import { createFrameLoop } from '$lib/features/arcade/engine';
import type { GhostMazeAudio } from './audio';

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

	// Scatter/Chase cycle
	scatterChasePhase: ScatterChasePhase;
	scatterChaseTimer: number;

	// Escalation (Cruise Elroy)
	escalationSpeedBoost: number;

	// Bonus items
	bonusItem: BonusItem | null;
	bonusSpawnTimer: number;
	speedBoostRemaining: number;

	// Proximity detection
	nearestTracerDistance: number;
	nearMissThisTick: boolean;

	// Score popups
	scorePopups: ScorePopup[];

	// UI
	isPaused: boolean;
	error: string | null;
}

export interface GhostMazeStore {
	readonly state: GhostMazeState;
	readonly renderEntities: RenderEntity[];
	readonly mazeText: string;
	readonly comboMultiplier: number;
	readonly scorePopups: ScorePopup[];
	readonly nearestTracerDistance: number;
	readonly nearMissThisTick: boolean;
	readonly dangerZone: boolean;
	readonly scatterChasePhase: ScatterChasePhase;

	startGame(tier: EntryTier, seed?: number): void;
	togglePause(): void;
	cleanup(): void;
}

// ============================================================================
// STORE FACTORY
// ============================================================================

export interface GhostMazeStoreOptions {
	audio?: GhostMazeAudio;
}

export function createGhostMazeStore(options: GhostMazeStoreOptions = {}): GhostMazeStore {
	const audio = options.audio ?? null;
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
		scatterChasePhase: 'scatter',
		scatterChaseTimer: 0,
		escalationSpeedBoost: 0,
		bonusItem: null,
		bonusSpawnTimer: BONUS_SPAWN_CHECK_INTERVAL,
		speedBoostRemaining: 0,
		nearestTracerDistance: Infinity,
		nearMissThisTick: false,
		scorePopups: [],
		isPaused: false,
		error: null,
	});

	// Sub-systems
	const input = createInputHandler();
	let rng: (() => number) | null = null;
	let inputLog: InputRecord[] = [];
	let currentTick = 0;
	let extraLifeAwarded = false;
	let playerMoveAccumulator = 0;

	// Score popup ID counter
	let popupIdCounter = 0;
	const POPUP_LIFETIME = Math.round(0.8 * TICK_RATE);

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

	const dangerZone = $derived(state.dataTotal > 0 && state.dataRemaining / state.dataTotal <= 0.15);

	const renderEntities = $derived.by(() => {
		if (!state.maze) return [];
		const entities: RenderEntity[] = [];

		// Helper: convert logical cell coord to text grid coord
		const toText = (c: Coord) => ({ x: c.x * 2 + 1, y: c.y * 2 + 1 });

		// Player
		if (state.phase === 'playing' || state.phase === 'ghost_mode' || state.phase === 'respawn') {
			const tp = toText(state.playerPos);
			entities.push({
				id: 'player',
				type: 'player',
				x: tp.x,
				y: tp.y,
				char: MAZE_CHARS.PLAYER,
			});
		}

		// Tracers
		for (const tracer of state.tracers) {
			if (tracer.mode === 'dead') continue;

			let type: RenderEntity['type'];
			let char: string;

			if (tracer.mode === 'returning') {
				type = 'tracer-returning';
				char = MAZE_CHARS.TRACER_RETURNING;
			} else if (tracer.mode === 'frightened') {
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

			const tt = toText(tracer.pos);
			entities.push({
				id: `tracer-${tracer.id}`,
				type,
				x: tt.x,
				y: tt.y,
				char,
			});
		}

		// Power nodes
		if (state.maze) {
			for (const pos of state.maze.powerNodePositions) {
				const cell = getCell(state.maze, pos.x, pos.y);
				if (cell?.content === 'power_node') {
					const tp = toText(pos);
					entities.push({
						id: `pn-${pos.x}-${pos.y}`,
						type: 'power-node',
						x: tp.x,
						y: tp.y,
						char: MAZE_CHARS.POWER_NODE,
					});
				}
			}
		}

		// Bonus item
		if (state.bonusItem) {
			const bp = toText(state.bonusItem.pos);
			const bonusDef = BONUS_TYPES[state.bonusItem.type];
			entities.push({
				id: 'bonus-item',
				type: 'bonus-item',
				x: bp.x,
				y: bp.y,
				char: bonusDef.char,
			});
		}

		return entities;
	});

	// Cache the wall template: only recompute when maze identity changes (new level).
	// Cell content (data packets collected) is stamped in separately.
	let cachedMazeId: MazeGrid | null = null;
	let cachedWallTemplate: string[] = [];
	let cachedCellPositions: { lineIdx: number; charIdx: number; cx: number; cy: number }[] = [];

	function ensureWallCache(maze: MazeGrid): void {
		if (cachedMazeId === maze) return;
		cachedMazeId = maze;

		const tw = maze.width * 2 + 1;
		const th = maze.height * 2 + 1;
		const { cells, width, height } = maze;

		function hasHWall(tx: number, ty: number): boolean {
			const cx = (tx - 1) / 2;
			if (ty === 0) return cells[cx].walls.up;
			if (ty === th - 1) return cells[(height - 1) * width + cx].walls.down;
			const cyAbove = ty / 2 - 1;
			return cells[cyAbove * width + cx].walls.down;
		}

		function hasVWall(tx: number, ty: number): boolean {
			const cy = (ty - 1) / 2;
			if (tx === 0) return cells[cy * width].walls.left;
			if (tx === tw - 1) return cells[cy * width + (width - 1)].walls.right;
			const cxLeft = tx / 2 - 1;
			return cells[cy * width + cxLeft].walls.right;
		}

		function cornerCharFn(tx: number, ty: number): string {
			const up = ty > 0 && hasVWall(tx, ty - 1);
			const down = ty < th - 1 && hasVWall(tx, ty + 1);
			const left = tx > 0 && hasHWall(tx - 1, ty);
			const right = tx < tw - 1 && hasHWall(tx + 1, ty);
			const n = (up ? 1 : 0) + (down ? 1 : 0) + (left ? 1 : 0) + (right ? 1 : 0);

			if (n === 0) return MAZE_CHARS.EMPTY;
			if (n === 1) {
				if (up || down) return MAZE_CHARS.WALL_V;
				return MAZE_CHARS.WALL_H;
			}
			if (n === 2) {
				if (up && down) return MAZE_CHARS.WALL_V;
				if (left && right) return MAZE_CHARS.WALL_H;
				if (down && right) return MAZE_CHARS.CORNER_TL;
				if (down && left) return MAZE_CHARS.CORNER_TR;
				if (up && right) return MAZE_CHARS.CORNER_BL;
				if (up && left) return MAZE_CHARS.CORNER_BR;
			}
			if (n === 3) {
				if (!up) return MAZE_CHARS.TEE_T;
				if (!down) return MAZE_CHARS.TEE_B;
				if (!left) return MAZE_CHARS.TEE_L;
				if (!right) return MAZE_CHARS.TEE_R;
			}
			return MAZE_CHARS.CROSS;
		}

		cachedCellPositions = [];
		const lines: string[] = [];

		for (let ty = 0; ty < th; ty++) {
			let line = '';
			for (let tx = 0; tx < tw; tx++) {
				const isEvenY = ty % 2 === 0;
				const isEvenX = tx % 2 === 0;

				if (isEvenY && isEvenX) {
					line += cornerCharFn(tx, ty);
				} else if (isEvenY && !isEvenX) {
					line += hasHWall(tx, ty) ? MAZE_CHARS.WALL_H : MAZE_CHARS.EMPTY;
				} else if (!isEvenY && isEvenX) {
					line += hasVWall(tx, ty) ? MAZE_CHARS.WALL_V : MAZE_CHARS.EMPTY;
				} else {
					// Cell center — use placeholder; will be stamped per-frame
					const cx = (tx - 1) / 2;
					const cy = (ty - 1) / 2;
					cachedCellPositions.push({ lineIdx: ty, charIdx: tx, cx, cy });
					line += MAZE_CHARS.EMPTY; // placeholder
				}
			}
			lines.push(line);
		}

		cachedWallTemplate = lines;
	}

	const mazeText = $derived.by(() => {
		if (!state.maze) return '';
		const maze = state.maze;

		ensureWallCache(maze);

		// Stamp cell content onto a copy of the wall template
		const lines = [...cachedWallTemplate];
		for (const { lineIdx, charIdx, cx, cy } of cachedCellPositions) {
			const cell = maze.cells[cy * maze.width + cx];
			const ch = cell.content === 'data' ? MAZE_CHARS.DATA_PACKET : MAZE_CHARS.EMPTY;
			if (ch !== MAZE_CHARS.EMPTY) {
				// Replace single char in the line
				const line = lines[lineIdx];
				lines[lineIdx] = line.substring(0, charIdx) + ch + line.substring(charIdx + 1);
			}
		}

		return lines.join('\n');
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
		playerMoveAccumulator = 0;
		popupIdCounter = 0;

		state.phase = 'level_intro';
		state.currentLevel = 1;
		state.lives = INITIAL_LIVES;
		state.score = 0;
		state.combo = 0;
		state.comboTimer = 0;
		state.maxCombo = 0;
		state.entryTier = tier;
		state.seed = gameSeed;
		state.hitThisLevel = false;
		state.allTracersDestroyedThisLevel = false;
		state.levelsCleared = 0;
		state.perfectLevels = 0;
		state.totalTracersDestroyed = 0;
		state.totalDataCollected = 0;
		state.isPaused = false;
		state.error = null;
		state.hasEmp = true;
		state.ghostModeActive = false;
		state.ghostModeRemaining = 0;
		state.tracersDestroyedThisGhostMode = 0;
		state.empFreezeRemaining = 0;
		state.isInvincible = false;
		state.phaseTimer = LEVEL_INTRO_TICKS;
		state.scatterChasePhase = 'scatter';
		state.scatterChaseTimer = 0;
		state.escalationSpeedBoost = 0;
		state.bonusItem = null;
		state.bonusSpawnTimer = BONUS_SPAWN_CHECK_INTERVAL;
		state.speedBoostRemaining = 0;
		state.nearestTracerDistance = Infinity;
		state.nearMissThisTick = false;
		state.scorePopups = [];

		setupLevel(1);

		input.reset();
		gameLoop.reset();
		frameLoop.start();

		// Set up keyboard listeners (remove first to prevent leaks on re-start)
		if (browser) {
			window.removeEventListener('keydown', handleKeyDown);
			window.removeEventListener('keyup', handleKeyUp);
			window.addEventListener('keydown', handleKeyDown);
			window.addEventListener('keyup', handleKeyUp);
		}
	}

	function setupLevel(level: number): void {
		const config = LEVELS[level - 1];
		if (!config || !rng) return;

		const tracerConfigs = computeTracers(config);
		const tracerCount = tracerConfigs.reduce((sum, t) => sum + t.count, 0);
		const dataPackets = computeDataPackets(config);

		const maze = generateMaze({
			width: config.gridWidth,
			height: config.gridHeight,
			seed: rng() * 2 ** 32,
			loopFactor: config.loopFactor,
			tracerCount,
			dataPackets,
			powerNodes: config.powerNodes,
		});

		const tracers = createTracers(tracerConfigs, maze);

		state.currentLevel = level;
		state.maze = maze;
		state.dataRemaining = maze.totalDataPackets;
		state.dataTotal = maze.totalDataPackets;
		state.playerPos = { ...maze.playerSpawn };
		state.playerDir = 'up';
		state.tracers = tracers;
		state.hitThisLevel = false;
		state.allTracersDestroyedThisLevel = false;
		state.hasEmp = true;
		state.ghostModeActive = false;
		state.ghostModeRemaining = 0;
		state.tracersDestroyedThisGhostMode = 0;
		state.empFreezeRemaining = 0;
		state.isInvincible = false;
		state.levelStartTick = currentTick;

		// Scatter/chase cycle
		const scConfig = SCATTER_CHASE_CONFIGS[level - 1];
		state.scatterChasePhase = 'scatter';
		state.scatterChaseTimer = scConfig.scatterTicks;

		// Escalation
		state.escalationSpeedBoost = 0;

		// Bonus items
		state.bonusItem = null;
		state.bonusSpawnTimer = BONUS_SPAWN_CHECK_INTERVAL;
		state.speedBoostRemaining = 0;

		// Score popups
		state.scorePopups = [];
	}

	function createTracers(
		configs: readonly { type: TracerType; count: number }[],
		maze: MazeGrid,
	): TracerState[] {
		const tracers: TracerState[] = [];
		let id = 0;
		let spawnIdx = 0;
		// Track swarm IDs so we can pair them correctly
		let swarmIndexInGroup = 0;
		let swarmBaseId = -1;

		for (const cfg of configs) {
			if (cfg.type === 'swarm') {
				swarmIndexInGroup = 0;
				swarmBaseId = id;
			}

			for (let i = 0; i < cfg.count; i++) {
				const spawnPos = maze.tracerSpawns[spawnIdx % maze.tracerSpawns.length];
				spawnIdx++;

				const currentId = id++;

				const tracer: TracerState = {
					id: currentId,
					type: cfg.type,
					pos: { ...spawnPos },
					dir: 'left',
					mode: 'normal',
					respawnTimer: 0,
					data: createTracerData(cfg.type, spawnPos, maze, currentId, rng!,
						cfg.type === 'swarm' ? { swarmBaseId, swarmIndexInGroup } : undefined),
				};
				tracers.push(tracer);

				if (cfg.type === 'swarm') {
					swarmIndexInGroup++;
				}
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
		swarmInfo?: { swarmBaseId: number; swarmIndexInGroup: number },
	) {
		switch (type) {
			case 'patrol':
				return {
					type: 'patrol' as const,
					waypoints: generatePatrolWaypoints(maze, spawnPos, rng),
					waypointIndex: 0,
					currentPath: [] as Coord[],
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
			case 'swarm': {
				// Pair swarm tracers: 0↔1, 2↔3, etc. within the swarm group
				const si = swarmInfo!;
				const pairOffset = si.swarmIndexInGroup % 2 === 0 ? 1 : -1;
				const partnerId = si.swarmBaseId + si.swarmIndexInGroup + pairOffset;
				return {
					type: 'swarm' as const,
					partnerId,
					flockOffset: (['up', 'down', 'left', 'right'] as const)[
						Math.floor(rng() * 4)
					],
				};
			}
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
			state.phase = 'paused';
			state.isPaused = true;
			gameLoop.pause();
		} else if (state.phase === 'paused') {
			state.phase = state.ghostModeActive ? 'ghost_mode' : 'playing';
			state.isPaused = false;
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
			state.phase = 'playing';
			state.phaseTimer = 0;
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
			// Warning beep when about to expire
			if (state.ghostModeRemaining === GHOST_MODE_WARNING_TICKS) {
				audio?.ghostModeWarning();
			}
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

		// 8. Escalation — recompute speed boost based on data remaining
		{
			const dataFraction = state.dataTotal > 0 ? state.dataRemaining / state.dataTotal : 1;
			let boost = 0;
			for (const threshold of ESCALATION_THRESHOLDS) {
				if (dataFraction <= threshold.dataFraction) {
					boost = threshold.speedBoost;
				}
			}
			if (boost > state.escalationSpeedBoost) {
				state.escalationSpeedBoost = boost;
				if (boost >= 0.20) audio?.dangerZone();
			}
		}

		// 9. Scatter/chase cycle — the heartbeat
		// Ghost mode overrides: skip timer while ghost mode active
		if (!state.ghostModeActive) {
			state.scatterChaseTimer--;
			if (state.scatterChaseTimer <= 0) {
				const scConfig = SCATTER_CHASE_CONFIGS[state.currentLevel - 1];
				if (state.scatterChasePhase === 'scatter') {
					state.scatterChasePhase = 'chase';
					state.scatterChaseTimer = scConfig.chaseTicks;
					audio?.chaseStart();
				} else {
					state.scatterChasePhase = 'scatter';
					state.scatterChaseTimer = scConfig.scatterTicks;
					audio?.scatterStart();
				}
			}
		}

		// 10. Move tracers
		const isScatter = state.scatterChasePhase === 'scatter' && !state.ghostModeActive;
		updateTracers(maze, levelConfig.playerSpeed, isScatter, state.escalationSpeedBoost);

		// 11. Check collisions with tracers
		checkTracerCollisions();

		// 12. Proximity detection & near-miss
		{
			let nearest = Infinity;
			let nearMiss = false;
			for (const t of state.tracers) {
				if (t.mode === 'dead' || t.mode === 'returning' || t.mode === 'frozen') continue;
				const d = Math.abs(state.playerPos.x - t.pos.x) + Math.abs(state.playerPos.y - t.pos.y);
				if (d < nearest) nearest = d;
				if (d <= NEAR_MISS_RANGE && t.mode !== 'frightened') nearMiss = true;
			}
			state.nearestTracerDistance = nearest;

			if (nearMiss && !state.isInvincible && !state.ghostModeActive) {
				state.nearMissThisTick = true;
				audio?.nearMiss();
			} else {
				state.nearMissThisTick = false;
			}

			// Proximity heartbeat
			if (nearest <= PROXIMITY_ALERT_RANGE && !state.ghostModeActive && !state.isInvincible) {
				// Play every 8 ticks (~2x/sec) to avoid spam
				if (currentTick % 8 === 0) {
					audio?.proximityWarning(nearest);
				}
			}
		}

		// 13. Bonus item lifecycle
		if (state.bonusItem) {
			state.bonusItem.lifetime--;
			if (state.bonusItem.lifetime <= 0) {
				state.bonusItem = null;
			}
		}

		// 14. Check bonus collection
		if (state.bonusItem && overlaps(state.playerPos, state.bonusItem.pos)) {
			collectBonus(state.bonusItem);
			state.bonusItem = null;
		}

		// 15. Bonus spawn timer
		state.bonusSpawnTimer--;
		if (state.bonusSpawnTimer <= 0 && !state.bonusItem) {
			state.bonusSpawnTimer = BONUS_SPAWN_CHECK_INTERVAL;
			if (rng!() < BONUS_SPAWN_CHANCE) {
				spawnBonusItem(maze);
			}
		}

		// 16. Speed boost decay
		if (state.speedBoostRemaining > 0) {
			state.speedBoostRemaining--;
		}

		// 17. Update combo decay
		if (state.comboTimer > 0) {
			state.comboTimer--;
			if (state.comboTimer <= 0 && state.combo > 0) {
				if (state.combo > 5) audio?.comboBreak();
				state.combo = 0;
				state.comboTimer = 0;
			}
		}

		// 18. Score popup decay
		for (let i = state.scorePopups.length - 1; i >= 0; i--) {
			state.scorePopups[i].ticksLeft--;
			if (state.scorePopups[i].ticksLeft <= 0) {
				state.scorePopups.splice(i, 1);
			}
		}

		// 19. Check invincibility decay
		if (state.isInvincible) {
			// Invincibility is managed by respawn timer
		}

		// 20. Check level clear
		if (state.dataRemaining <= 0) {
			triggerLevelClear();
		}

		// 21. Check extra life
		if (!extraLifeAwarded && state.score >= EXTRA_LIFE_SCORE && state.lives < MAX_LIVES) {
			state.lives++;
			extraLifeAwarded = true;
		}
	}

	/** Base player move rate: cells per tick. At 15 tps, 0.5 = 7.5 cells/sec. */
	const BASE_PLAYER_RATE = 0.5;

	function movePlayer(maze: MazeGrid): void {
		// Fractional accumulator: accumulate speed each tick, move when >= 1
		const levelConfig = LEVELS[state.currentLevel - 1];
		let rate = BASE_PLAYER_RATE * (levelConfig?.playerSpeed ?? 1.0);

		// Speed boost from bonus item
		rate *= state.speedBoostRemaining > 0 ? 1.5 : 1.0;

		playerMoveAccumulator += rate;
		if (playerMoveAccumulator < 1) return;
		playerMoveAccumulator -= 1;

		// Move from buffer only. The input tick() re-fills the buffer from
		// held keys each tick, so holding a direction = continuous movement.
		// A tap sets the buffer once; after it's consumed, no re-fill since
		// current is null (key released). This gives exactly one move per tap.
		const buffered = input.state.buffered;
		if (buffered && canMove(maze, state.playerPos, buffered)) {
			const newPos = tryMove(maze, state.playerPos, buffered);
			if (newPos) {
				state.playerPos = newPos;
				state.playerDir = buffered;
				input.consumeBuffer();
				audio?.moveTick();
			}
		}
	}

	function checkDataCollection(maze: MazeGrid): void {
		const idx = getCellIndex(state.playerPos.x, state.playerPos.y, maze.width);
		const cell = maze.cells[idx];

		if (cell.content === 'data') {
			// Collect
		(cell as { content: CellContent }).content = 'empty';
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
		const points = SCORE_DATA_PACKET * mult;
		state.score += points;

		// Score popup
		addScorePopup(`+${points}`, state.playerPos);

		// Audio
		audio?.dataCollect(state.combo);
		if (state.combo === 5 || state.combo === 10 || state.combo === 20 || state.combo === 50) {
			audio?.comboMilestone();
		}
		}
	}

	function checkPowerNodeCollection(maze: MazeGrid): void {
		const idx = getCellIndex(state.playerPos.x, state.playerPos.y, maze.width);
		const cell = maze.cells[idx];

		if (cell.content === 'power_node') {
			(cell as { content: CellContent }).content = 'empty';
			audio?.powerNodeGrab();
			activateGhostMode();
		}
	}

	function activateGhostMode(): void {
		const levelConfig = LEVELS[state.currentLevel - 1];
		state.phase = 'ghost_mode';
		state.ghostModeActive = true;
		state.ghostModeRemaining = Math.round(levelConfig.ghostModeDuration * TICK_RATE);
		state.tracersDestroyedThisGhostMode = 0;
		audio?.ghostModeStart();

		// Set all active tracers to frightened
		for (const tracer of state.tracers) {
			if (tracer.mode === 'normal') {
				tracer.mode = 'frightened';
				tracer.dir = OPPOSITE_DIRECTION[tracer.dir]; // Reverse direction
			}
		}
	}

	function endGhostMode(): void {
		state.phase = 'playing';
		state.ghostModeActive = false;
		state.ghostModeRemaining = 0;
		audio?.ghostModeEnd();

		// Reset scatter/chase to scatter when ghost mode ends
		const scConfig = SCATTER_CHASE_CONFIGS[state.currentLevel - 1];
		state.scatterChasePhase = 'scatter';
		state.scatterChaseTimer = scConfig.scatterTicks;

		for (const tracer of state.tracers) {
			if (tracer.mode === 'frightened') {
				tracer.mode = 'normal';
			}
		}
	}

	function activateEmp(): void {
		state.hasEmp = false;
		state.empFreezeRemaining = EMP_FREEZE_TICKS;
		audio?.empDeploy();

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

	/**
	 * Random direction for a tracer, avoiding reversal.
	 * Used for phantom scatter mode and other random walk behaviors.
	 */
	function randomTracerDirection(maze: MazeGrid, pos: Coord, currentDir: Direction): Direction | null {
		const opposite = OPPOSITE_DIRECTION[currentDir];
		const dirs = getValidDirections(maze, pos).filter(d => d !== opposite);
		if (dirs.length > 0) return dirs[Math.floor((rng?.() ?? Math.random()) * dirs.length)];
		return canMove(maze, pos, opposite) ? opposite : null;
	}

	function updateTracers(maze: MazeGrid, playerSpeed: number, isScatter: boolean, escalationBoost: number): void {
		for (const tracer of state.tracers) {
			// Handle returning tracers (eyes going home)
			if (tracer.mode === 'returning') {
				const spawnPos = maze.tracerSpawns[tracer.id % maze.tracerSpawns.length];
				if (overlaps(tracer.pos, spawnPos)) {
					tracer.mode = state.ghostModeActive ? 'frightened' : 'normal';
					continue;
				}
				// Move toward spawn using A* at double speed (always moves)
				const path = findPath(maze, tracer.pos, spawnPos);
				if (path && path.length > 1) {
					const dir = getPathDirection([tracer.pos, ...path.slice(1)]);
					if (dir) {
						const newPos = tryMove(maze, tracer.pos, dir);
						if (newPos) {
							tracer.pos = newPos;
							tracer.dir = dir;
						}
					}
				}
				continue;
			}

			// Handle dead tracers (respawn timer — legacy fallback)
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

			// Speed check (with escalation boost)
			const isFrightened = tracer.mode === 'frightened';
			if (!shouldTracerMove(tracer.type, currentTick, playerSpeed * (1 + escalationBoost), isFrightened)) continue;

			// Get movement direction based on AI type
			let dir: Direction | null = null;

			if (isFrightened) {
				dir = updateFrightened(tracer, maze, state.playerPos);
			} else {
				switch (tracer.type) {
					case 'patrol':
						dir = updatePatrol(tracer, maze, state.playerPos, rng!);
						break;
					case 'hunter':
						dir = updateHunter(tracer, maze, state.playerPos, isScatter);
						break;
					case 'phantom': {
						if (!rng) break;
						if (isScatter) {
							// In scatter: pure random walk
							dir = randomTracerDirection(maze, tracer.pos, tracer.dir);
							break;
						}
						const action: PhantomAction = updatePhantom(tracer, maze, state.playerPos, rng);
						if (action.type === 'teleport' && action.destination) {
							tracer.pos = { ...action.destination };
							audio?.phantomTeleport();
						} else if (action.direction) {
							dir = action.direction;
						}
						break;
					}
					case 'swarm':
						dir = updateSwarm(tracer, maze, state.playerPos, state.tracers, isScatter);
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
			if (tracer.mode === 'dead' || tracer.mode === 'frozen' || tracer.mode === 'returning') continue;
			if (!overlaps(state.playerPos, tracer.pos)) continue;

			if (tracer.mode === 'frightened') {
				// Destroy tracer — switch to returning mode (eyes going home)
				tracer.mode = 'returning';

				// Score (doubling cascade)
				const destroyScore =
					SCORE_TRACER_DESTROY_BASE * 2 ** state.tracersDestroyedThisGhostMode;
				state.score += destroyScore;
				state.tracersDestroyedThisGhostMode++;
				state.totalTracersDestroyed++;
				audio?.tracerDestroyed();

				// Score popup
				addScorePopup(`+${destroyScore}`, tracer.pos, 'tracer');
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
		audio?.playerHit();
		state.phase = 'player_death';
		state.lives = state.lives - 1;
		state.hitThisLevel = true;
		state.phaseTimer = DEATH_ANIMATION_TICKS;
		state.combo = 0;
		state.comboTimer = 0;
		playerMoveAccumulator = 0;
		state.ghostModeActive = false;
		state.ghostModeRemaining = 0;

		// Reset tracer modes
		for (const tracer of state.tracers) {
			if (tracer.mode === 'frightened') tracer.mode = 'normal';
		}
	}

	function tickPlayerDeath(): void {
		state.phaseTimer--;
		if (state.phaseTimer <= 0) {
			if (state.lives <= 0) {
				state.phase = 'game_over';
				endGame();
			} else {
				// Respawn
				audio?.respawn();
				state.phase = 'respawn';
				if (state.maze) {
					state.playerPos = { ...state.maze.playerSpawn };
				}
				state.isInvincible = true;
				playerMoveAccumulator = 0;
				state.phaseTimer = RESPAWN_INVINCIBILITY_TICKS;

				// Reset tracers to home positions
				if (state.maze) {
					for (const tracer of state.tracers) {
						if (tracer.mode !== 'dead' && tracer.mode !== 'returning') {
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
			state.phase = 'playing';
			state.isInvincible = false;
			state.phaseTimer = 0;
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
			(t) => t.mode === 'dead' || t.mode === 'returning' || t.respawnTimer > 0,
		);
		if (allTracersDestroyed) {
			state.score += SCORE_PERFECT_CLEAR * levelNum;
			state.perfectLevels++;
		}

		state.levelsCleared++;

		state.phase = 'level_clear';
		state.phaseTimer = LEVEL_CLEAR_TICKS;
		audio?.levelClear();
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
				state.phase = 'game_over';
				endGame();
			} else {
				// Next level
				const nextLevel = state.currentLevel + 1;
				state.phase = 'level_intro';
				state.phaseTimer = LEVEL_INTRO_TICKS;
				setupLevel(nextLevel);
			}
		}
	}

	// ─────────────────────────────────────────────────────────────────────
	// GAME END
	// ─────────────────────────────────────────────────────────────────────

	function endGame(): void {
		audio?.gameOver();
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

	function addScorePopup(text: string, pos: Coord, variant: ScorePopup['variant'] = 'default'): void {
		const tp = { x: pos.x * 2 + 1, y: pos.y * 2 + 1 };
		state.scorePopups.push({
			id: popupIdCounter++,
			text,
			x: tp.x,
			y: tp.y,
			ticksLeft: POPUP_LIFETIME,
			variant,
		});
	}

	function spawnBonusItem(maze: MazeGrid): void {
		// Pick a random empty cell that's not too close to the player
		const emptyCells: Coord[] = [];
		for (let y = 0; y < maze.height; y++) {
			for (let x = 0; x < maze.width; x++) {
				const cell = maze.cells[y * maze.width + x];
				if (cell.content === 'empty') {
					const dist = Math.abs(x - state.playerPos.x) + Math.abs(y - state.playerPos.y);
					if (dist >= 5) {
						emptyCells.push({ x, y });
					}
				}
			}
		}

		if (emptyCells.length === 0) return;

		const pos = emptyCells[Math.floor(rng!() * emptyCells.length)];

		// Select type from weighted pool
		const totalWeight = BONUS_WEIGHTS.reduce((sum, bw) => sum + bw.weight, 0);
		let roll = rng!() * totalWeight;
		let selectedType: BonusType = 'SCORE_BURST';
		for (const bw of BONUS_WEIGHTS) {
			roll -= bw.weight;
			if (roll <= 0) {
				selectedType = bw.type;
				break;
			}
		}

		state.bonusItem = {
			type: selectedType,
			pos,
			lifetime: BONUS_LIFETIME_TICKS,
		};

		audio?.bonusAppear();
	}

	function collectBonus(item: BonusItem): void {
		const def = BONUS_TYPES[item.type];

		// Apply points
		if (def.points > 0) {
			state.score += def.points;
		}

		// Apply type-specific effects
		switch (item.type) {
			case 'EXTRA_LIFE':
				if (state.lives < MAX_LIVES) {
					state.lives++;
				}
				break;
			case 'SPEED_BOOST':
				state.speedBoostRemaining = BONUS_TYPES.SPEED_BOOST.durationTicks;
				break;
			case 'SCORE_BURST':
				// Points already added above
				break;
		}

		audio?.bonusCollect();

		// Score popup
		addScorePopup(def.label, item.pos, 'bonus');
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
		get scorePopups() {
			return state.scorePopups;
		},
		get nearestTracerDistance() {
			return state.nearestTracerDistance;
		},
		get nearMissThisTick() {
			return state.nearMissThisTick;
		},
		get dangerZone() {
			return dangerZone;
		},
		get scatterChasePhase() {
			return state.scatterChasePhase;
		},
		startGame,
		togglePause,
		cleanup,
	};
}
