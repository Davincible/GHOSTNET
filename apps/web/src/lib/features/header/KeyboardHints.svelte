<script lang="ts">
	interface Shortcut {
		key: string;
		modifier?: 'SHIFT';
		label: string;
		category: 'action' | 'game' | 'social';
	}

	const shortcuts: Shortcut[] = [
		{ key: 'J', modifier: 'SHIFT', label: 'Jack In', category: 'action' },
		{ key: 'E', modifier: 'SHIFT', label: 'Extract', category: 'action' },
		{ key: 'T', modifier: 'SHIFT', label: 'Trace Evasion', category: 'game' },
		{ key: 'H', modifier: 'SHIFT', label: 'Hack Run', category: 'game' },
		{ key: 'D', modifier: 'SHIFT', label: 'Duels', category: 'game' },
		{ key: 'C', modifier: 'SHIFT', label: 'Crew', category: 'social' },
		{ key: 'P', modifier: 'SHIFT', label: 'Dead Pool', category: 'social' },
	];

	// Group shortcuts by category for visual separation
	const actionShortcuts = shortcuts.filter((s) => s.category === 'action');
	const gameShortcuts = shortcuts.filter((s) => s.category === 'game');
	const socialShortcuts = shortcuts.filter((s) => s.category === 'social');
</script>

<div class="keyboard-hints" role="region" aria-label="Keyboard shortcuts">
	<span class="hints-label">HOTKEYS:</span>

	<div class="hints-group">
		{#each actionShortcuts as shortcut (shortcut.key)}
			<span class="hint">
				<span class="hint-keys">
					{#if shortcut.modifier}
						<kbd class="hint-key hint-modifier">{shortcut.modifier}</kbd>
						<span class="hint-plus">+</span>
					{/if}
					<kbd class="hint-key">{shortcut.key}</kbd>
				</span>
				<span class="hint-label">{shortcut.label}</span>
			</span>
		{/each}
	</div>

	<span class="hints-divider">|</span>

	<div class="hints-group">
		{#each gameShortcuts as shortcut (shortcut.key)}
			<span class="hint">
				<span class="hint-keys">
					{#if shortcut.modifier}
						<kbd class="hint-key hint-modifier">{shortcut.modifier}</kbd>
						<span class="hint-plus">+</span>
					{/if}
					<kbd class="hint-key">{shortcut.key}</kbd>
				</span>
				<span class="hint-label">{shortcut.label}</span>
			</span>
		{/each}
	</div>

	<span class="hints-divider">|</span>

	<div class="hints-group">
		{#each socialShortcuts as shortcut (shortcut.key)}
			<span class="hint">
				<span class="hint-keys">
					{#if shortcut.modifier}
						<kbd class="hint-key hint-modifier">{shortcut.modifier}</kbd>
						<span class="hint-plus">+</span>
					{/if}
					<kbd class="hint-key">{shortcut.key}</kbd>
				</span>
				<span class="hint-label">{shortcut.label}</span>
			</span>
		{/each}
	</div>
</div>

<style>
	.keyboard-hints {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-1-5) var(--space-4);
		background: var(--color-bg-tertiary);
		border-bottom: 1px solid var(--color-border-subtle);
		font-family: var(--font-mono);
		font-size: var(--text-2xs);
		overflow-x: auto;
		white-space: nowrap;
	}

	.hints-label {
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
		flex-shrink: 0;
	}

	.hints-group {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}

	.hints-divider {
		color: var(--color-border-default);
		flex-shrink: 0;
	}

	.hint {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.hint-keys {
		display: inline-flex;
		align-items: center;
		gap: 0.15em;
	}

	.hint-key {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-width: 1.5em;
		padding: 0.1em 0.4em;
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-default);
		color: var(--color-accent);
		font-family: var(--font-mono);
		font-size: var(--text-2xs);
		font-weight: var(--font-medium);
		line-height: 1;
	}

	.hint-modifier {
		color: var(--color-text-tertiary);
		font-size: 0.5rem;
		padding: 0.1em 0.25em;
		min-width: auto;
	}

	.hint-plus {
		color: var(--color-text-muted);
		font-size: 0.5rem;
	}

	.hint-label {
		color: var(--color-text-tertiary);
	}

	/* Hide on mobile - not useful without keyboard */
	@media (max-width: 768px) {
		.keyboard-hints {
			display: none;
		}
	}

	/* Compact on smaller screens */
	@media (max-width: 1024px) and (min-width: 769px) {
		.hints-label {
			display: none;
		}

		.keyboard-hints {
			justify-content: center;
		}
	}
</style>
