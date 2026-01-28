<script lang="ts">
	interface Props {
		onResume: () => void;
		onQuit: () => void;
	}

	let { onResume, onQuit }: Props = $props();
</script>

<div class="pause-overlay">
	<div class="pause-content">
		<h2 class="pause-title">P A U S E D</h2>
		<div class="pause-actions">
			<button class="pause-btn" onclick={onResume}>[ESC] RESUME</button>
			<button class="pause-btn quit" onclick={onQuit}>[Q] QUIT</button>
		</div>
		<div class="controls-hint">
			<div>[WASD / Arrows] Move</div>
			<div>[SPACE / E] EMP</div>
			<div>[ESC] Pause</div>
		</div>
	</div>
</div>

<style>
	.pause-overlay {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(0, 0, 0, 0.85);
		z-index: 100;
		font-family: var(--font-mono);
	}

	.pause-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-6);
	}

	.pause-title {
		font-size: var(--text-2xl);
		font-weight: bold;
		letter-spacing: var(--tracking-widest);
		color: var(--color-accent);
		text-shadow: 0 0 8px var(--color-accent-glow);
		margin: 0;
	}

	.pause-actions {
		display: flex;
		gap: var(--space-4);
	}

	.pause-btn {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		padding: var(--space-2) var(--space-4);
		border: 1px solid var(--color-accent-dim);
		background: transparent;
		color: var(--color-accent);
		cursor: pointer;
		letter-spacing: var(--tracking-wider);
	}

	.pause-btn:hover {
		border-color: var(--color-accent);
		background: var(--color-accent-glow);
	}

	.pause-btn.quit {
		border-color: var(--color-red-dim);
		color: var(--color-red);
	}

	.pause-btn.quit:hover {
		border-color: var(--color-red);
		background: var(--color-red-glow);
	}

	.controls-hint {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		color: var(--color-text-secondary);
		font-size: var(--text-xs);
		text-align: center;
		opacity: 0.6;
	}
</style>
