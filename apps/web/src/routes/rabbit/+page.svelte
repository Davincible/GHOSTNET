<script lang="ts">
	import { Panel, Box } from '$lib/ui/terminal';
	import RabbitParticles from '$lib/ui/visualizations/RabbitParticles.svelte';
	import RabbitVoxel from '$lib/ui/visualizations/RabbitVoxel.svelte';
	import RabbitASCII from '$lib/ui/visualizations/RabbitASCII.svelte';
	import RabbitWireframe from '$lib/ui/visualizations/RabbitWireframe.svelte';

	let activeRabbit = $state<'particles' | 'voxel' | 'ascii' | 'wireframe' | 'all'>('all');
	let color = $state('#00e5cc');
	let bgColor = $state('#00e5cc');

	const rabbits = [
		{ id: 'particles', name: 'PARTICLE CLOUD', desc: 'Matrix dissolve/reform' },
		{ id: 'voxel', name: 'VOXEL', desc: '3D pixel art' },
		{ id: 'ascii', name: 'ASCII', desc: 'Terminal rain' },
		{ id: 'wireframe', name: 'WIREFRAME', desc: 'Tron vectors' },
	] as const;

	const colors = [
		{ value: '#00e5cc', name: 'Ghost Cyan' },
		{ value: '#00ff00', name: 'Matrix Green' },
		{ value: '#ff00ff', name: 'Neon Pink' },
		{ value: '#ffff00', name: 'Warning Yellow' },
		{ value: '#ff3366', name: 'Danger Red' },
		{ value: '#ffffff', name: 'Pure White' },
	];
</script>

<svelte:head>
	<title>Follow The White Rabbit | GHOSTNET</title>
</svelte:head>

<div class="rabbit-page">
	<header class="page-header">
		<h1 class="title">
			<span class="bracket">[</span>
			FOLLOW THE WHITE RABBIT
			<span class="bracket">]</span>
		</h1>
		<p class="subtitle">Choose your reality</p>
	</header>

	<div class="controls">
		<div class="view-toggle">
			<button
				class="toggle-btn"
				class:active={activeRabbit === 'all'}
				onclick={() => (activeRabbit = 'all')}
			>
				ALL
			</button>
			{#each rabbits as rabbit (rabbit.id)}
				<button
					class="toggle-btn"
					class:active={activeRabbit === rabbit.id}
					onclick={() => (activeRabbit = rabbit.id)}
				>
					{rabbit.name}
				</button>
			{/each}
		</div>

		<div class="color-picker">
			<span class="label">RABBIT:</span>
			{#each colors as c (c.value)}
				<button
					class="color-btn"
					class:active={color === c.value}
					style="--btn-color: {c.value}"
					onclick={() => (color = c.value)}
					title={c.name}
				></button>
			{/each}
		</div>

		<div class="color-picker">
			<span class="label">BACKGROUND:</span>
			{#each colors as c (c.value)}
				<button
					class="color-btn"
					class:active={bgColor === c.value}
					style="--btn-color: {c.value}"
					onclick={() => (bgColor = c.value)}
					title={c.name}
				></button>
			{/each}
		</div>
	</div>

	{#if activeRabbit === 'all'}
		<div class="grid">
			{#each rabbits as rabbit (rabbit.id)}
				<Panel title={rabbit.name} borderColor="cyan" glow>
					<div class="rabbit-container">
						{#if rabbit.id === 'particles'}
							<RabbitParticles width={350} height={350} {color} {bgColor} />
						{:else if rabbit.id === 'voxel'}
							<RabbitVoxel width={350} height={350} {color} {bgColor} />
						{:else if rabbit.id === 'ascii'}
							<RabbitASCII width={350} height={350} {color} {bgColor} />
						{:else if rabbit.id === 'wireframe'}
							<RabbitWireframe width={350} height={350} {color} {bgColor} />
						{/if}
					</div>
					<p class="rabbit-desc">{rabbit.desc}</p>
				</Panel>
			{/each}
		</div>
	{:else}
		<div class="single-view">
			<Panel title={rabbits.find((r) => r.id === activeRabbit)?.name ?? ''} borderColor="cyan" glow>
				<div class="rabbit-container large">
					{#if activeRabbit === 'particles'}
						<RabbitParticles width={600} height={500} {color} {bgColor} particleCount={3400} />
					{:else if activeRabbit === 'voxel'}
						<RabbitVoxel width={600} height={500} {color} {bgColor} />
					{:else if activeRabbit === 'ascii'}
						<RabbitASCII width={600} height={500} {color} {bgColor} />
					{:else if activeRabbit === 'wireframe'}
						<RabbitWireframe width={600} height={500} {color} {bgColor} />
					{/if}
				</div>
			</Panel>
		</div>
	{/if}

	<footer class="page-footer">
		<Box borderColor="dim">
			<div class="footer-content">
				<span class="code">$ wake_up_neo</span>
				<span class="message">The Matrix has you...</span>
				<span class="blink">_</span>
			</div>
		</Box>
	</footer>
</div>

<style>
	.rabbit-page {
		padding: var(--space-6);
		min-height: 100vh;
		display: flex;
		flex-direction: column;
		gap: var(--space-6);
	}

	.page-header {
		text-align: center;
		padding: var(--space-4) 0;
	}

	.title {
		font-family: var(--font-mono);
		font-size: var(--text-2xl);
		font-weight: 700;
		color: var(--color-text-primary);
		letter-spacing: 0.15em;
		margin: 0;
	}

	.bracket {
		color: var(--color-accent);
	}

	.subtitle {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		margin-top: var(--space-2);
		letter-spacing: 0.3em;
		text-transform: uppercase;
	}

	.controls {
		display: flex;
		justify-content: center;
		align-items: center;
		gap: var(--space-6);
		flex-wrap: wrap;
	}

	.view-toggle {
		display: flex;
		gap: var(--space-1);
		background: var(--color-surface-1);
		padding: var(--space-1);
		border-radius: var(--radius-md);
		border: 1px solid var(--color-border-subtle);
	}

	.toggle-btn {
		padding: var(--space-2) var(--space-3);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		background: transparent;
		border: none;
		color: var(--color-text-tertiary);
		cursor: pointer;
		border-radius: var(--radius-sm);
		transition: all 0.15s ease;
		letter-spacing: 0.05em;
	}

	.toggle-btn:hover {
		color: var(--color-text-secondary);
		background: var(--color-surface-2);
	}

	.toggle-btn.active {
		color: var(--color-accent);
		background: var(--color-surface-2);
		box-shadow: 0 0 10px var(--color-accent-muted);
	}

	.color-picker {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.label {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: 0.1em;
	}

	.color-btn {
		width: 24px;
		height: 24px;
		border-radius: 50%;
		border: 2px solid transparent;
		background: var(--btn-color);
		cursor: pointer;
		transition: all 0.15s ease;
		box-shadow: 0 0 5px color-mix(in srgb, var(--btn-color) 50%, transparent);
	}

	.color-btn:hover {
		transform: scale(1.15);
		box-shadow: 0 0 15px var(--btn-color);
	}

	.color-btn.active {
		border-color: var(--color-text-primary);
		transform: scale(1.1);
		box-shadow: 0 0 20px var(--btn-color);
	}

	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(380px, 1fr));
		gap: var(--space-4);
		flex: 1;
	}

	.single-view {
		display: flex;
		justify-content: center;
		flex: 1;
	}

	.rabbit-container {
		display: flex;
		justify-content: center;
		align-items: center;
		padding: var(--space-2);
		background: var(--color-void);
		border-radius: var(--radius-sm);
	}

	.rabbit-container.large {
		padding: var(--space-4);
	}

	.rabbit-desc {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		text-align: center;
		margin: var(--space-2) 0 0 0;
		letter-spacing: 0.1em;
	}

	.page-footer {
		margin-top: auto;
		padding-top: var(--space-4);
	}

	.footer-content {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-3);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
	}

	.code {
		color: var(--color-accent);
	}

	.message {
		color: var(--color-text-secondary);
	}

	.blink {
		color: var(--color-accent);
		animation: blink 1s step-end infinite;
	}

	@keyframes blink {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0;
		}
	}

	/* Responsive */
	@media (max-width: 768px) {
		.rabbit-page {
			padding: var(--space-4);
		}

		.title {
			font-size: var(--text-lg);
		}

		.controls {
			flex-direction: column;
			gap: var(--space-3);
		}

		.view-toggle {
			flex-wrap: wrap;
			justify-content: center;
		}

		.grid {
			grid-template-columns: 1fr;
		}
	}
</style>
