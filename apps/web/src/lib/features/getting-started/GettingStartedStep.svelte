<script lang="ts">
	import type { Snippet } from 'svelte';

	type StepStatus = 'current' | 'future' | 'complete';

	interface Props {
		/** Step number displayed (e.g. "01") */
		number: string;
		/** Step label (e.g. "CONNECT WALLET") */
		label: string;
		/** Visual state of the step */
		status?: StepStatus;
		/** Step description content */
		children: Snippet;
		/** Optional CTA rendered below description (only for current step) */
		action?: Snippet;
	}

	let { number, label, status = 'future', children, action }: Props = $props();

	const ICONS: Record<StepStatus, string> = {
		current: '\u25B6',
		future: '\u25CB',
		complete: '\u2713',
	};

	let icon = $derived(ICONS[status]);
</script>

<li class="step step-{status}">
	<span class="step-number">{number}</span>
	<span class="step-icon">{icon}</span>
	<div class="step-content">
		<span class="step-label">{label}</span>
		<div class="step-description">
			{@render children()}
		</div>
		{#if action && status === 'current'}
			<div class="step-action">
				{@render action()}
			</div>
		{/if}
	</div>
</li>

<style>
	.step {
		display: grid;
		grid-template-columns: auto auto 1fr;
		gap: var(--space-2);
		align-items: start;
		list-style: none;
	}

	.step-number {
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		min-width: 2ch;
		text-align: right;
	}

	.step-icon {
		font-size: var(--text-sm);
		min-width: 1.5ch;
	}

	.step-content {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.step-label {
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wide);
	}

	.step-description {
		font-size: var(--text-xs);
		line-height: var(--leading-relaxed);
	}

	.step-action {
		margin-top: var(--space-1);
	}

	/* ── Current step: bright, accented ── */
	.step-current .step-number {
		color: var(--color-accent);
	}

	.step-current .step-icon {
		color: var(--color-accent);
	}

	.step-current .step-label {
		color: var(--color-text-primary);
	}

	.step-current .step-description {
		color: var(--color-text-secondary);
	}

	/* ── Future step: dimmed ── */
	.step-future .step-number {
		color: var(--color-text-muted);
	}

	.step-future .step-icon {
		color: var(--color-text-muted);
	}

	.step-future .step-label {
		color: var(--color-text-tertiary);
	}

	.step-future .step-description {
		color: var(--color-text-muted);
	}

	/* ── Complete step: green check ── */
	.step-complete .step-number {
		color: var(--color-profit);
	}

	.step-complete .step-icon {
		color: var(--color-profit);
	}

	.step-complete .step-label {
		color: var(--color-text-primary);
	}

	.step-complete .step-description {
		color: var(--color-text-secondary);
	}
</style>
