<script lang="ts">
	import type { RenderEntity, MazeGrid } from '../types';

	interface Props {
		/** ASCII text of the maze (walls + data packets) */
		mazeText: string;
		/** Entities to overlay on the maze */
		entities: RenderEntity[];
		/** Current maze grid (for dimensions) */
		maze: MazeGrid | null;
		/** Whether player is in ghost mode */
		ghostMode?: boolean;
		/** Whether ghost mode is about to expire (last 2s) */
		ghostModeWarning?: boolean;
		/** Whether player is invincible (blinking) */
		invincible?: boolean;
		/** Whether player is dead (flash red) */
		dead?: boolean;
		/** Whether EMP was just deployed (screen flash) */
		empFlash?: boolean;
	}

	let {
		mazeText,
		entities,
		maze,
		ghostMode = false,
		ghostModeWarning = false,
		invincible = false,
		dead = false,
		empFlash = false,
	}: Props = $props();

	// Text grid dimensions: (logical * 2 + 1)
	let cols = $derived(maze ? maze.width * 2 + 1 : 21);
	let rows = $derived(maze ? maze.height * 2 + 1 : 15);

	// Responsive font sizing: scale so the maze fills available width.
	// Monospace ch-to-fontSize ratio is ~0.6 (IBM Plex Mono).
	const CH_RATIO = 0.602;
	let containerWidth = $state(0);
	let fontSize = $derived.by(() => {
		if (containerWidth <= 0 || cols <= 0) return 14;
		const ideal = containerWidth / (cols * CH_RATIO);
		// Clamp between 8px (tiny screens) and 20px (large monitors)
		return Math.min(20, Math.max(8, Math.floor(ideal)));
	});
</script>

<div
	class="maze-container"
	class:emp-flash={empFlash}
	style="--cols: {cols}; --rows: {rows}; font-size: {fontSize}px"
	bind:clientWidth={containerWidth}
>
	<!-- Static maze (walls + data packets) -->
	<pre class="maze-grid">{mazeText}</pre>

	<!-- Entity overlays -->
	{#each entities as entity (entity.id)}
		<span
			class="entity entity-{entity.type}"
			class:ghost-player={entity.type === 'player' && ghostMode}
			class:invincible-player={entity.type === 'player' && invincible}
			class:dead-player={entity.type === 'player' && dead}
			class:frightened-warning={entity.type === 'tracer-frightened' && ghostModeWarning}
			style="left: {entity.x}ch; top: calc({entity.y} * var(--line-h));"
		>
			{entity.char}
		</span>
	{/each}
</div>

<style>
	.maze-container {
		position: relative;
		font-family: var(--font-mono);
		/* font-size set dynamically via inline style for responsive scaling */
		--line-h: 1.2em;
		line-height: var(--line-h);
		color: var(--color-accent-dim);
		overflow: hidden;
		user-select: none;
		width: 100%;
	}

	.maze-grid {
		margin: 0;
		white-space: pre;
		pointer-events: none;
	}

	.entity {
		position: absolute;
		z-index: 10;
		pointer-events: none;
		font-weight: bold;
		/* Tracers glide smoothly between positions */
		transition: left 120ms ease-out, top 120ms ease-out;
		will-change: left, top;
	}

	/* Player — instant snap, no transition (crisp input feel) */
	.entity-player {
		color: var(--color-accent-bright);
		text-shadow: 0 0 8px var(--color-accent-glow);
		transition: none;
	}

	.ghost-player {
		color: var(--color-cyan);
		text-shadow: 0 0 12px var(--color-cyan-glow), 0 0 24px var(--color-cyan-glow);
		animation: ghost-pulse 0.5s ease-in-out infinite alternate;
	}

	.invincible-player {
		animation: blink 0.15s step-end infinite;
	}

	.dead-player {
		color: var(--color-red);
		text-shadow: 0 0 8px var(--color-red-glow);
		animation: death-flash 0.1s step-end 3;
	}

	/* Tracers */
	.entity-tracer-patrol {
		color: var(--color-red);
	}

	.entity-tracer-hunter {
		color: #ff00ff;
		text-shadow: 0 0 4px rgba(255, 0, 255, 0.4);
	}

	.entity-tracer-phantom {
		color: var(--color-cyan);
		text-shadow: 0 0 4px var(--color-cyan-glow);
	}

	.entity-tracer-swarm {
		color: var(--color-amber);
	}

	.entity-tracer-frightened {
		color: var(--color-accent-dim);
		animation: blink 0.3s step-end infinite;
	}

	.frightened-warning {
		animation: blink 0.1s step-end infinite !important;
		color: var(--color-red) !important;
	}

	.entity-tracer-frozen {
		color: var(--color-cyan);
		opacity: 0.8;
	}

	/* Power nodes */
	.entity-power-node {
		color: #ffd700;
		text-shadow: 0 0 6px rgba(255, 215, 0, 0.5);
		animation: power-pulse 1.5s ease-in-out infinite;
	}

	/* Animations */
	/* EMP screen flash */
	.emp-flash {
		animation: emp-burst 0.3s ease-out;
	}

	@keyframes emp-burst {
		0% { filter: brightness(3) saturate(0); }
		30% { filter: brightness(2) saturate(0.3); }
		100% { filter: brightness(1) saturate(1); }
	}

	@keyframes ghost-pulse {
		from {
			text-shadow: 0 0 8px var(--color-cyan-glow);
		}
		to {
			text-shadow: 0 0 16px var(--color-cyan-glow), 0 0 32px var(--color-cyan-glow);
		}
	}

	@keyframes blink {
		0%, 49% {
			opacity: 1;
		}
		50%, 100% {
			opacity: 0;
		}
	}

	@keyframes death-flash {
		0%, 49% {
			opacity: 1;
		}
		50%, 100% {
			opacity: 0;
		}
	}

	@keyframes power-pulse {
		0%, 100% {
			text-shadow: 0 0 4px rgba(255, 215, 0, 0.3);
		}
		50% {
			text-shadow: 0 0 10px rgba(255, 215, 0, 0.7);
		}
	}
</style>
