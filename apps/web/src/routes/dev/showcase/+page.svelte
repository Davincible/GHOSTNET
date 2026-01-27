<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { Panel, Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';

	const componentSections = [
		{
			name: 'PANELS',
			description:
				'Container component with lifecycle animations, attention states, and ambient effects.',
			href: '/dev/showcase/panels',
			status: 'ACTIVE',
			count: '6 attention states, 4 ambient effects, 2 enter animations, blur modifier',
		},
		{
			name: 'AUDIO',
			description:
				'ZzFX sound system — UI feedback, game events, alerts, and crash game sounds.',
			href: '/dev/showcase/audio',
			status: 'ACTIVE',
			count: '30 sounds, 5 categories',
		},
		{
			name: 'BUTTONS',
			description: 'Primary, secondary, danger, and ghost action triggers.',
			href: null,
			status: 'PLANNED',
			count: '4 variants, 3 sizes',
		},
		{
			name: 'BADGES',
			description: 'Status indicators and labels with glow and pulse options.',
			href: null,
			status: 'PLANNED',
			count: '6 variants',
		},
		{
			name: 'TERMINAL',
			description: 'Box, Shell, Scanlines, Flicker, ScreenFlash components.',
			href: null,
			status: 'PLANNED',
			count: '5 components',
		},
		{
			name: 'DATA DISPLAY',
			description: 'AddressDisplay, AmountDisplay, LevelBadge, PercentDisplay.',
			href: null,
			status: 'PLANNED',
			count: '4 components',
		},
		{
			name: 'LAYOUT',
			description: 'Stack, Row, and responsive layout primitives.',
			href: null,
			status: 'PLANNED',
			count: '2 components',
		},
	];

	function navigate(href: string) {
		goto(resolve(href as any));
	}
</script>

<Stack gap={4}>
	<div class="overview-intro">
		<Box title="SYSTEM STATUS">
			<div class="status-grid">
				<div class="status-item">
					<span class="status-label">DESIGN SYSTEM</span>
					<span class="status-value status-online">ONLINE</span>
				</div>
				<div class="status-item">
					<span class="status-label">COMPONENTS</span>
					<span class="status-value">{componentSections.length}</span>
				</div>
				<div class="status-item">
					<span class="status-label">ACTIVE SHOWCASES</span>
					<span class="status-value">{componentSections.filter((s) => s.href).length}</span>
				</div>
				<div class="status-item">
					<span class="status-label">AESTHETIC</span>
					<span class="status-value">TERMINAL // CYBERPUNK</span>
				</div>
			</div>
		</Box>
	</div>

	<div class="section-grid">
		{#each componentSections as section (section.name)}
			{@const isActive = section.href !== null}
			<button
				type="button"
				class="section-card"
				class:section-active={isActive}
				class:section-planned={!isActive}
				disabled={!isActive}
				onclick={() => section.href && navigate(section.href)}
			>
				<div class="section-header">
					<span class="section-name">{section.name}</span>
					<span class="section-status" class:active={isActive}>
						{section.status}
					</span>
				</div>
				<p class="section-description">{section.description}</p>
				<span class="section-count">{section.count}</span>
			</button>
		{/each}
	</div>
</Stack>

<style>
	/* ── Status Grid ── */

	.status-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: var(--space-3);
	}

	.status-item {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.status-label {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.status-value {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
	}

	.status-online {
		color: var(--color-accent);
	}

	/* ── Section Grid ── */

	.section-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space-3);
	}

	.section-card {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding: var(--space-4);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-default);
		text-align: left;
		cursor: pointer;
		font-family: var(--font-mono);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.section-card:disabled {
		cursor: default;
	}

	.section-active:hover {
		border-color: var(--color-accent-dim);
		background: var(--color-bg-tertiary);
	}

	.section-planned {
		opacity: 0.4;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.section-name {
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wider);
	}

	.section-status {
		font-size: 0.5625rem;
		padding: var(--space-0-5) var(--space-1-5);
		border: 1px solid var(--color-border-default);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.section-status.active {
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
		background: rgba(0, 229, 204, 0.08);
	}

	.section-description {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		line-height: var(--leading-relaxed);
		margin: 0;
	}

	.section-count {
		font-size: 0.5625rem;
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wide);
	}

	/* ── Responsive ── */

	@media (max-width: 640px) {
		.status-grid {
			grid-template-columns: 1fr;
		}

		.section-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
