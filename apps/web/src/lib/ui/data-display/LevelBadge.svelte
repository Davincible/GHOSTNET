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
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wide);
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

	/* Glow effect */
	.level-glow.level-vault {
		text-shadow: 0 0 8px var(--color-level-vault);
	}

	.level-glow.level-mainframe {
		text-shadow: 0 0 8px var(--color-level-mainframe);
	}

	.level-glow.level-subnet {
		text-shadow: 0 0 8px var(--color-level-subnet);
	}

	.level-glow.level-darknet {
		text-shadow: 0 0 8px var(--color-level-darknet);
	}

	.level-glow.level-black-ice {
		text-shadow: 0 0 8px var(--color-level-black-ice);
		animation: danger-pulse 1.5s ease-in-out infinite;
	}

	@keyframes danger-pulse {
		0%, 100% {
			text-shadow: 0 0 8px var(--color-level-black-ice);
		}
		50% {
			text-shadow: 0 0 15px var(--color-level-black-ice), 0 0 25px var(--color-level-black-ice);
		}
	}
</style>
