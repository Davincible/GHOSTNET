<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Countdown } from '$lib/ui/primitives';
	import { Stack, Row } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';

	const provider = getProvider();

	// Get modifier source icon
	function getSourceIcon(source: string): string {
		switch (source) {
			case 'typing':
				return '';
			case 'hackrun':
				return '';
			case 'crew':
				return '';
			case 'daily':
				return '';
			case 'network':
				return '';
			case 'consumable':
				return '';
			default:
				return '';
		}
	}

	// Get modifier color class
	function getModifierClass(type: string, value: number): string {
		if (type === 'death_rate') {
			return value < 0 ? 'modifier-good' : 'modifier-bad';
		}
		if (type === 'yield_multiplier') {
			return value > 1 ? 'modifier-good' : 'modifier-bad';
		}
		return '';
	}
</script>

{#if provider.modifiers.length > 0}
	<Box title="ACTIVE MODIFIERS">
		<Stack gap={2}>
			{#each provider.modifiers as modifier (modifier.id)}
				<div class="modifier-item {getModifierClass(modifier.type, modifier.value)}">
					<Row justify="between" align="center">
						<div class="modifier-info">
							<span class="modifier-icon" aria-hidden="true">{getSourceIcon(modifier.source)}</span>
							<span class="modifier-label">{modifier.label}</span>
						</div>
						<div class="modifier-meta">
							{#if modifier.expiresAt}
								<Countdown targetTime={modifier.expiresAt} format="mm:ss" />
							{:else}
								<span class="modifier-permanent">PERM</span>
							{/if}
						</div>
					</Row>
				</div>
			{/each}
		</Stack>
	</Box>
{/if}

<style>
	.modifier-item {
		padding: var(--space-2);
		border: 1px solid var(--color-border-subtle);
		background: var(--color-bg-tertiary);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.modifier-item:hover {
		border-color: var(--color-border-default);
	}

	.modifier-good {
		border-left: 2px solid var(--color-profit);
	}

	.modifier-bad {
		border-left: 2px solid var(--color-loss);
	}

	.modifier-info {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.modifier-icon {
		font-size: var(--text-base);
	}

	.modifier-label {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
	}

	.modifier-meta {
		font-size: var(--text-xs);
	}

	.modifier-permanent {
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}
</style>
