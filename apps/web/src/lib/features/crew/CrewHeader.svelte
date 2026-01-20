<script lang="ts">
	import type { Crew } from '$lib/core/types';
	import { Box } from '$lib/ui/terminal';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Row } from '$lib/ui/layout';

	interface Props {
		/** Crew data */
		crew: Crew;
	}

	let { crew }: Props = $props();
</script>

<Box variant="double" borderColor="cyan" padding={3}>
	<div class="crew-header">
		<!-- Top row: Name, Tag, Rank -->
		<Row justify="between" align="center">
			<div class="crew-identity">
				<span class="crew-label">CREW:</span>
				<span class="crew-name">{crew.name.toUpperCase()}</span>
				<span class="crew-tag">[{crew.tag}]</span>
			</div>
			<div class="crew-rank">
				<span class="rank-label">RANK:</span>
				<span class="rank-value">#{crew.rank}</span>
			</div>
		</Row>

		<!-- Description -->
		<p class="crew-description">"{crew.description}"</p>

		<!-- Divider -->
		<div class="divider" aria-hidden="true"></div>

		<!-- Stats row -->
		<Row justify="between" align="center" class="stats-row">
			<div class="stat">
				<span class="stat-label">MEMBERS:</span>
				<span class="stat-value">{crew.memberCount}/{crew.maxMembers}</span>
			</div>
			<div class="stat">
				<span class="stat-label">TVL:</span>
				<span class="stat-value"><AmountDisplay amount={crew.totalStaked} format="full" /></span>
			</div>
			<div class="stat">
				<span class="stat-label">WEEKLY:</span>
				<span class="stat-value profit">
					+<AmountDisplay amount={crew.weeklyExtracted} format="compact" />
				</span>
			</div>
		</Row>
	</div>
</Box>

<style>
	.crew-header {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.crew-identity {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.crew-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-wider);
	}

	.crew-name {
		color: var(--color-cyan);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.crew-tag {
		color: var(--color-accent);
		font-size: var(--text-base);
		font-weight: var(--font-medium);
	}

	.crew-rank {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.rank-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.rank-value {
		color: var(--color-amber);
		font-size: var(--text-base);
		font-weight: var(--font-bold);
	}

	.crew-description {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		font-style: italic;
		padding-left: var(--space-2);
	}

	.divider {
		height: 1px;
		background: var(--color-border-subtle);
		margin: var(--space-1) 0;
	}

	:global(.stats-row) {
		flex-wrap: wrap;
		gap: var(--space-3);
	}

	.stat {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.stat-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.stat-value {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
	}

	.stat-value.profit {
		color: var(--color-profit);
	}

	/* Mobile responsiveness */
	@media (max-width: 480px) {
		.crew-identity {
			flex-wrap: wrap;
		}

		.crew-name {
			font-size: var(--text-base);
		}

		:global(.stats-row) {
			flex-direction: column;
			align-items: flex-start;
			gap: var(--space-1);
		}
	}
</style>
