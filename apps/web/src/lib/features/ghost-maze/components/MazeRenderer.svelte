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
		/** Whether player is invincible (blinking) */
		invincible?: boolean;
		/** Whether player is dead (flash red) */
		dead?: boolean;
	}

	let {
		mazeText,
		entities,
		maze,
		ghostMode = false,
		invincible = false,
		dead = false,
	}: Props = $props();

	let cols = $derived(maze?.width ?? 21);
	let rows = $derived(maze?.height ?? 15);
</script>

<div
	class="maze-container"
	style="--cols: {cols}; --rows: {rows}"
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
		font-size: 14px;
		--line-h: 1.2em;
		line-height: var(--line-h);
		color: var(--color-accent-dim);
		overflow: hidden;
		user-select: none;
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
	}

	/* Player */
	.entity-player {
		color: var(--color-accent-bright);
		text-shadow: 0 0 8px var(--color-accent-glow);
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
