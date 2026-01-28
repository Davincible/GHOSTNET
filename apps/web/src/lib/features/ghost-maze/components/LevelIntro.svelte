<script lang="ts">
	import { LEVELS, computeTracers, computeDataPackets } from '../constants';
	import type { TracerType } from '../types';

	interface Props {
		level: number;
	}

	let { level }: Props = $props();

	let config = $derived(LEVELS[level - 1]);
	let theme = $derived(config?.theme ?? 'UNKNOWN');
	let tracerConfigs = $derived(config ? computeTracers(config) : []);
	let tracerCount = $derived(tracerConfigs.reduce((s, t) => s + t.count, 0));
	let dataPackets = $derived(config ? computeDataPackets(config) : 0);

	// Find new tracer type introduced this level
	let newTracer = $derived.by(() => {
		if (level <= 1) return null;
		const prevTypes = new Set<TracerType>(
			LEVELS.slice(0, level - 1).flatMap((l) => {
				const configs = computeTracers(l);
				return configs.map((t) => t.type);
			}),
		);
		const currentTypes = tracerConfigs.map((t) => t.type);
		const newType = currentTypes.find((t) => !prevTypes.has(t));
		if (!newType) return null;
		const labels: Record<string, string> = {
			hunter: 'HUNTER TRACER (pathfinds to you!)',
			phantom: 'PHANTOM TRACER (teleports!)',
			swarm: 'SWARM TRACERS (fast pairs!)',
		};
		return labels[newType] ?? newType.toUpperCase();
	});

	let levelText = $derived(`L E V E L   ${level}`);
	let themeText = $derived(
		theme.split('').join(' '),
	);
</script>

<div class="level-intro">
	<div class="intro-content">
		<div class="divider">{'░'.repeat(24)}</div>
		<h2 class="level-number">{levelText}</h2>
		<h3 class="level-theme">{themeText}</h3>
		<div class="divider">{'░'.repeat(24)}</div>

		<div class="level-stats">
			<span>TRACERS: {tracerCount}</span>
			<span>DATA PACKETS: {dataPackets}</span>
		</div>

		{#if newTracer}
			<div class="new-element">
				NEW: {newTracer}
			</div>
		{/if}
	</div>
</div>

<style>
	.level-intro {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 400px;
		font-family: var(--font-mono);
		text-align: center;
		animation: fade-in 0.3s ease-out;
	}

	.intro-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-3);
	}

	.divider {
		color: var(--color-accent-dim);
		letter-spacing: 2px;
	}

	.level-number {
		font-size: var(--text-2xl);
		font-weight: bold;
		letter-spacing: var(--tracking-widest);
		color: var(--color-accent-bright);
		text-shadow: 0 0 8px var(--color-accent-glow);
		margin: 0;
	}

	.level-theme {
		font-size: var(--text-xl);
		font-weight: bold;
		letter-spacing: var(--tracking-widest);
		color: var(--color-accent);
		margin: 0;
	}

	.level-stats {
		display: flex;
		gap: var(--space-6);
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
	}

	.new-element {
		color: var(--color-amber);
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-wider);
		padding: var(--space-1) var(--space-3);
		border: 1px solid var(--color-amber-dim);
	}

	@keyframes fade-in {
		from { opacity: 0; transform: translateY(8px); }
		to { opacity: 1; transform: translateY(0); }
	}
</style>
