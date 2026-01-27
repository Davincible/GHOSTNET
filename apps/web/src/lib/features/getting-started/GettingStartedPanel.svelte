<script lang="ts">
	/**
	 * Getting Started Panel — the field manual for first-time visitors.
	 *
	 * Replaces DailyOpsPanel in the right column when the wallet is not
	 * connected. A static terminal-style briefing that teaches the game
	 * loop in four steps, shows the risk spectrum, and explains the
	 * cascade economics — enough to take action, not so much that it
	 * overwhelms.
	 *
	 * Disappears the moment the user connects their wallet.
	 * DailyOpsPanel takes its place. The user has graduated
	 * from "getting started" to "operating."
	 */

	import { Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';
	import { Button } from '$lib/ui/primitives';
	import GettingStartedStep from './GettingStartedStep.svelte';
	import RiskLevelsTable from './RiskLevelsTable.svelte';

	interface Props {
		/** Callback when Connect Wallet button is clicked */
		onConnectWallet?: () => void;
	}

	let { onConnectWallet }: Props = $props();
</script>

<Box title="GETTING STARTED">
	<Stack gap={4}>
		<!-- One-liner: the game in one sentence -->
		<p class="briefing-intro">
			Stake $DATA. Earn yield. Survive the trace scans. When others die, you profit.
		</p>

		<!-- Section: WHAT TO DO -->
		<section>
			<div class="section-divider">
				<span class="divider-label">WHAT TO DO</span>
			</div>

			<ol class="steps">
				<GettingStartedStep number="01" label="CONNECT WALLET" status="current">
					{#snippet children()}
						Link your wallet to access the network.
					{/snippet}
					{#snippet action()}
						<Button variant="primary" onclick={onConnectWallet} fullWidth>CONNECT WALLET</Button>
					{/snippet}
				</GettingStartedStep>

				<GettingStartedStep number="02" label="JACK IN" status="future">
					{#snippet children()}
						Choose a risk level. Stake $DATA. Yield starts accumulating immediately.
					{/snippet}
				</GettingStartedStep>

				<GettingStartedStep number="03" label="SURVIVE" status="future">
					{#snippet children()}
						Periodic trace scans roll for death. Play mini-games to reduce your odds.
					{/snippet}
				</GettingStartedStep>

				<GettingStartedStep number="04" label="EXTRACT" status="future">
					{#snippet children()}
						Cash out anytime. Principal + earned yield. Or stay in and keep earning.
					{/snippet}
				</GettingStartedStep>
			</ol>
		</section>

		<!-- Section: RISK LEVELS -->
		<section>
			<div class="section-divider">
				<span class="divider-label">RISK LEVELS</span>
			</div>

			<RiskLevelsTable />
		</section>

		<!-- Section: THE KEY INSIGHT -->
		<section>
			<div class="section-divider">
				<span class="divider-label">THE KEY INSIGHT</span>
			</div>

			<p class="key-insight">
				When someone gets traced, their stake doesn't vanish.
				<span class="highlight-accent">60% flows to survivors.</span>
				<span class="highlight-amber">30% is burned forever.</span>
				You earn yield from other people dying.
			</p>
		</section>

		<!-- Warning -->
		<div class="warning" role="alert">
			<span class="warning-icon" aria-hidden="true">&#x26A0;</span>
			<p class="warning-text">
				High risk. You can lose everything.<br />
				Only stake what you can afford to lose.
			</p>
		</div>
	</Stack>
</Box>

<style>
	/* ── Briefing intro ── */
	.briefing-intro {
		font-size: var(--text-sm);
		color: var(--color-text-primary);
		line-height: var(--leading-relaxed);
	}

	/* ── Section dividers: ─── LABEL ─── ── */
	.section-divider {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin-bottom: var(--space-3);
	}

	.section-divider::before,
	.section-divider::after {
		content: '';
		flex: 1;
		height: 1px;
		background: var(--color-border-subtle);
	}

	.divider-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
		white-space: nowrap;
	}

	/* ── Steps list ── */
	.steps {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		list-style: none;
		margin: 0;
		padding: 0;
	}

	/* ── Key insight ── */
	.key-insight {
		font-size: var(--text-xs);
		color: var(--color-text-primary);
		line-height: var(--leading-relaxed);
	}

	.highlight-accent {
		color: var(--color-accent);
	}

	.highlight-amber {
		color: var(--color-amber);
	}

	/* ── Warning box ── */
	.warning {
		display: flex;
		align-items: flex-start;
		gap: var(--space-2);
		padding: var(--space-2);
		background: rgba(255, 176, 0, 0.05);
		border: 1px solid rgba(255, 176, 0, 0.2);
	}

	.warning-icon {
		flex-shrink: 0;
		color: var(--color-amber);
		font-size: var(--text-sm);
	}

	.warning-text {
		font-size: var(--text-xs);
		color: var(--color-amber);
		line-height: var(--leading-relaxed);
	}
</style>
