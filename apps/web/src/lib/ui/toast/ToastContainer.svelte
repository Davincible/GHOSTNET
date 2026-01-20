<script lang="ts">
	import { getToasts } from './store.svelte';

	const toasts = getToasts();
</script>

{#if toasts.list.length > 0}
	<div class="toast-container" role="region" aria-label="Notifications">
		{#each toasts.list as toast (toast.id)}
			<div
				class="toast toast-{toast.type}"
				role="alert"
			>
				<span class="toast-icon">
					{#if toast.type === 'success'}
						<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="20 6 9 17 4 12"></polyline>
						</svg>
					{:else if toast.type === 'error'}
						<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"></circle>
							<line x1="15" y1="9" x2="9" y2="15"></line>
							<line x1="9" y1="9" x2="15" y2="15"></line>
						</svg>
					{:else if toast.type === 'warning'}
						<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path>
							<line x1="12" y1="9" x2="12" y2="13"></line>
							<line x1="12" y1="17" x2="12.01" y2="17"></line>
						</svg>
					{:else}
						<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"></circle>
							<line x1="12" y1="16" x2="12" y2="12"></line>
							<line x1="12" y1="8" x2="12.01" y2="8"></line>
						</svg>
					{/if}
				</span>
				<span class="toast-message">{toast.message}</span>
				<button
					class="toast-close"
					onclick={() => toasts.remove(toast.id)}
					aria-label="Dismiss"
				>
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"></line>
						<line x1="6" y1="6" x2="18" y2="18"></line>
					</svg>
				</button>
			</div>
		{/each}
	</div>
{/if}

<style>
	.toast-container {
		position: fixed;
		top: var(--space-4);
		right: var(--space-4);
		z-index: var(--z-toast, 50);
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		max-width: 400px;
		pointer-events: none;
	}

	.toast {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-3);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-default);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		animation: toast-in 0.2s ease-out;
		pointer-events: auto;
	}

	.toast-info {
		border-color: var(--color-cyan);
	}

	.toast-success {
		border-color: var(--color-profit);
	}

	.toast-warning {
		border-color: var(--color-amber);
	}

	.toast-error {
		border-color: var(--color-red);
	}

	.toast-icon {
		flex-shrink: 0;
		width: 18px;
		height: 18px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.toast-icon svg {
		width: 100%;
		height: 100%;
	}

	.toast-info .toast-icon {
		color: var(--color-cyan);
	}

	.toast-success .toast-icon {
		color: var(--color-profit);
	}

	.toast-warning .toast-icon {
		color: var(--color-amber);
	}

	.toast-error .toast-icon {
		color: var(--color-red);
	}

	.toast-message {
		flex: 1;
		color: var(--color-text-primary);
	}

	.toast-close {
		flex-shrink: 0;
		width: 20px;
		height: 20px;
		background: none;
		border: none;
		color: var(--color-text-tertiary);
		cursor: pointer;
		padding: 0;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.toast-close:hover {
		color: var(--color-text-primary);
	}

	.toast-close svg {
		width: 14px;
		height: 14px;
	}

	@keyframes toast-in {
		from {
			opacity: 0;
			transform: translateX(100%);
		}
		to {
			opacity: 1;
			transform: translateX(0);
		}
	}

	@media (max-width: 480px) {
		.toast-container {
			top: auto;
			bottom: var(--space-4);
			left: var(--space-4);
			right: var(--space-4);
			max-width: none;
		}
	}
</style>
