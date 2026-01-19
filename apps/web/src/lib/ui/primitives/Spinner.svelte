<script lang="ts">
	type Size = 'sm' | 'md' | 'lg';
	type Variant = 'default' | 'dots' | 'bar';

	interface Props {
		size?: Size;
		variant?: Variant;
		/** Accessible label */
		label?: string;
	}

	let {
		size = 'md',
		variant = 'default',
		label = 'Loading...'
	}: Props = $props();
</script>

<span
	class="spinner spinner-{size} spinner-{variant}"
	role="status"
	aria-label={label}
>
	{#if variant === 'dots'}
		<span class="dot">.</span><span class="dot">.</span><span class="dot">.</span>
	{:else if variant === 'bar'}
		<span class="bar"></span>
	{:else}
		<span class="char"></span>
	{/if}
</span>

<style>
	.spinner {
		display: inline-flex;
		align-items: center;
		font-family: var(--font-mono);
		color: var(--color-green-bright);
	}

	/* Sizes */
	.spinner-sm {
		font-size: var(--text-xs);
	}

	.spinner-md {
		font-size: var(--text-base);
	}

	.spinner-lg {
		font-size: var(--text-xl);
	}

	/* Default variant: rotating ASCII characters */
	.spinner-default .char::before {
		content: '|';
		display: inline-block;
		animation: spin-chars 0.4s steps(4, end) infinite;
	}

	@keyframes spin-chars {
		0% { content: '|'; }
		25% { content: '/'; }
		50% { content: '-'; }
		75% { content: '\\'; }
	}

	/* Dots variant: three dots loading */
	.spinner-dots {
		gap: 0;
	}

	.spinner-dots .dot {
		animation: dot-pulse 1.4s ease-in-out infinite;
	}

	.spinner-dots .dot:nth-child(1) {
		animation-delay: 0s;
	}

	.spinner-dots .dot:nth-child(2) {
		animation-delay: 0.2s;
	}

	.spinner-dots .dot:nth-child(3) {
		animation-delay: 0.4s;
	}

	@keyframes dot-pulse {
		0%, 80%, 100% {
			opacity: 0.3;
		}
		40% {
			opacity: 1;
		}
	}

	/* Bar variant: filling/unfilling bar */
	.spinner-bar .bar {
		display: inline-block;
		width: 8ch;
		overflow: hidden;
	}

	.spinner-bar .bar::before {
		content: '████████';
		display: block;
		animation: bar-fill 1s ease-in-out infinite;
	}

	@keyframes bar-fill {
		0% {
			clip-path: inset(0 100% 0 0);
		}
		50% {
			clip-path: inset(0 0 0 0);
		}
		100% {
			clip-path: inset(0 0 0 100%);
		}
	}
</style>
