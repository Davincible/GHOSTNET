<script lang="ts">
	import { onMount, onDestroy } from 'svelte';

	type Format = 'hh:mm:ss' | 'mm:ss' | 'auto';

	interface Props {
		/** Target timestamp (ms since epoch) */
		targetTime: number;
		/** Display format */
		format?: Format;
		/** Threshold in seconds for urgent styling */
		urgentThreshold?: number;
		/** Callback when countdown reaches zero */
		onComplete?: () => void;
		/** Show expired state or hide */
		showExpired?: boolean;
		/** Label prefix */
		label?: string;
	}

	let {
		targetTime,
		format = 'auto',
		urgentThreshold = 60,
		onComplete,
		showExpired = true,
		label
	}: Props = $props();

	let remainingMs = $state(0);
	let intervalId: ReturnType<typeof setInterval> | null = null;

	// Calculate remaining time
	function updateRemaining() {
		const now = Date.now();
		remainingMs = Math.max(0, targetTime - now);

		if (remainingMs === 0 && onComplete) {
			onComplete();
			if (intervalId) {
				clearInterval(intervalId);
				intervalId = null;
			}
		}
	}

	onMount(() => {
		updateRemaining();
		intervalId = setInterval(updateRemaining, 1000);
	});

	onDestroy(() => {
		if (intervalId) {
			clearInterval(intervalId);
		}
	});

	// Derived values
	let totalSeconds = $derived(Math.floor(remainingMs / 1000));
	let hours = $derived(Math.floor(totalSeconds / 3600));
	let minutes = $derived(Math.floor((totalSeconds % 3600) / 60));
	let seconds = $derived(totalSeconds % 60);

	let isExpired = $derived(remainingMs === 0);
	let isUrgent = $derived(totalSeconds > 0 && totalSeconds <= urgentThreshold);

	// Format the display
	let displayTime = $derived.by(() => {
		const pad = (n: number) => n.toString().padStart(2, '0');

		if (isExpired) {
			return '00:00';
		}

		switch (format) {
			case 'hh:mm:ss':
				return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
			case 'mm:ss':
				return `${pad(minutes + hours * 60)}:${pad(seconds)}`;
			case 'auto':
			default:
				if (hours > 0) {
					return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
				}
				return `${pad(minutes)}:${pad(seconds)}`;
		}
	});
</script>

{#if !isExpired || showExpired}
	<span
		class="countdown"
		class:countdown-urgent={isUrgent}
		class:countdown-expired={isExpired}
		role="timer"
		aria-label={label ? `${label}: ${displayTime}` : displayTime}
	>
		{#if label}
			<span class="countdown-label">{label}</span>
		{/if}
		<span class="countdown-time">{displayTime}</span>
	</span>
{/if}

<style>
	.countdown {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		font-family: var(--font-mono);
		font-variant-numeric: tabular-nums;
	}

	.countdown-label {
		color: var(--color-green-dim);
	}

	.countdown-time {
		color: var(--color-green-bright);
	}

	/* Urgent state - pulsing red/amber */
	.countdown-urgent .countdown-time {
		animation: urgent-pulse 1s ease-in-out infinite;
	}

	@keyframes urgent-pulse {
		0%, 100% {
			color: var(--color-red);
			text-shadow: 0 0 5px var(--color-red-glow);
		}
		50% {
			color: var(--color-amber);
			text-shadow: 0 0 15px var(--color-red-glow);
		}
	}

	/* Expired state */
	.countdown-expired .countdown-time {
		color: var(--color-red);
		animation: none;
	}
</style>
