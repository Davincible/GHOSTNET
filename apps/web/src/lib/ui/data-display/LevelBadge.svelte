<script lang="ts">
	type Level = 'VAULT' | 'MAINFRAME' | 'SUBNET' | 'DARKNET' | 'BLACK_ICE';

	interface Props {
		/** Security clearance level */
		level: Level;
		/** Show glow effect */
		glow?: boolean;
		/** Compact display (just the name, no brackets) */
		compact?: boolean;
	}

	let {
		level,
		glow = false,
		compact = false
	}: Props = $props();

	// Display text
	let displayText = $derived(compact ? level : `[${level}]`);
</script>

<span
	class="level-badge level-{level.toLowerCase().replace('_', '-')}"
	class:level-glow={glow}
>
	{displayText}
</span>

<style>
	.level-badge {
		display: inline-block;
		font-family: var(--font-mono);
		font-size: inherit;
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		white-space: nowrap;
	}

	/* Level-specific colors */
	.level-vault {
		color: var(--color-level-vault);
	}

	.level-mainframe {
		color: var(--color-level-mainframe);
	}

	.level-subnet {
		color: var(--color-level-subnet);
	}

	.level-darknet {
		color: var(--color-level-darknet);
	}

	.level-black-ice {
		color: var(--color-level-black-ice);
	}

	/* Glow effect - more subtle */
	.level-glow.level-vault {
		text-shadow: 0 0 4px rgba(0, 229, 204, 0.4);
	}

	.level-glow.level-mainframe {
		text-shadow: 0 0 4px rgba(0, 229, 255, 0.4);
	}

	.level-glow.level-subnet {
		text-shadow: 0 0 4px rgba(255, 176, 0, 0.4);
	}

	.level-glow.level-darknet {
		text-shadow: 0 0 4px rgba(255, 102, 51, 0.4);
	}

	.level-glow.level-black-ice {
		text-shadow: 0 0 4px rgba(255, 51, 102, 0.5);
		animation: danger-pulse 2s ease-in-out infinite;
	}

	@keyframes danger-pulse {
		0%, 100% {
			text-shadow: 0 0 4px rgba(255, 51, 102, 0.5);
		}
		50% {
			text-shadow: 0 0 8px rgba(255, 51, 102, 0.6), 0 0 16px rgba(255, 51, 102, 0.3);
		}
	}
</style>
