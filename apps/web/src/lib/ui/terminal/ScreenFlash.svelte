<script lang="ts">
	type FlashType = 'death' | 'jackpot' | 'warning' | 'success' | 'custom';

	interface Props {
		/** Current flash type (null = no flash) */
		type?: FlashType | null;
		/** Custom color for 'custom' type */
		color?: string;
		/** Flash duration in ms */
		duration?: number;
		/** Callback when flash completes */
		onComplete?: () => void;
	}

	let { type = null, color = 'rgba(255, 0, 0, 0.4)', duration = 500, onComplete }: Props = $props();

	let visible = $state(false);

	// Watch for type changes to trigger flash
	$effect(() => {
		if (type) {
			visible = true;
			const timer = setTimeout(() => {
				visible = false;
				onComplete?.();
			}, duration);
			return () => clearTimeout(timer);
		}
	});

	// Get color based on type
	let flashColor = $derived.by(() => {
		switch (type) {
			case 'death':
				return 'var(--color-red-glow)';
			case 'jackpot':
				return 'var(--color-gold-glow)';
			case 'warning':
				return 'var(--color-amber-glow)';
			case 'success':
				return 'var(--color-green-glow)';
			case 'custom':
				return color;
			default:
				return 'transparent';
		}
	});
</script>

{#if visible && type}
	<div
		class="screen-flash"
		class:flash-death={type === 'death'}
		class:flash-jackpot={type === 'jackpot'}
		class:flash-warning={type === 'warning'}
		class:flash-success={type === 'success'}
		style:--flash-color={flashColor}
		style:--flash-duration="{duration}ms"
		aria-hidden="true"
	></div>
{/if}

<style>
	.screen-flash {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		pointer-events: none;
		z-index: var(--z-flash);
		background-color: var(--flash-color);
		animation: flash var(--flash-duration) ease-out forwards;
	}

	@keyframes flash {
		0% {
			opacity: 0;
		}
		15% {
			opacity: 1;
		}
		30% {
			opacity: 0.3;
		}
		45% {
			opacity: 0.8;
		}
		60% {
			opacity: 0.2;
		}
		100% {
			opacity: 0;
		}
	}

	/* Death flash with shake */
	.flash-death {
		animation:
			flash var(--flash-duration) ease-out forwards,
			shake calc(var(--flash-duration) * 0.6) ease-out;
	}

	@keyframes shake {
		0%,
		100% {
			transform: translateX(0);
		}
		10% {
			transform: translateX(-3px);
		}
		20% {
			transform: translateX(3px);
		}
		30% {
			transform: translateX(-3px);
		}
		40% {
			transform: translateX(3px);
		}
		50% {
			transform: translateX(-2px);
		}
		60% {
			transform: translateX(2px);
		}
		70% {
			transform: translateX(-1px);
		}
		80% {
			transform: translateX(1px);
		}
	}

	/* Jackpot flash with glow pulse */
	.flash-jackpot {
		box-shadow: inset 0 0 100px 50px var(--color-gold-glow);
	}

	/* Respect reduced motion preference */
	@media (prefers-reduced-motion: reduce) {
		.screen-flash {
			animation: flash-simple var(--flash-duration) ease-out forwards;
		}

		@keyframes flash-simple {
			0% {
				opacity: 0;
			}
			20% {
				opacity: 0.5;
			}
			100% {
				opacity: 0;
			}
		}
	}
</style>
