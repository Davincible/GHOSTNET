<script lang="ts">
	import type { Snippet } from 'svelte';
	import { Box } from '$lib/ui/terminal';

	interface Props {
		/** Whether the modal is open */
		open: boolean;
		/** Modal title */
		title?: string;
		/** Max width of modal content */
		maxWidth?: 'sm' | 'md' | 'lg';
		/** Close on backdrop click */
		closeOnBackdrop?: boolean;
		/** Close on Escape key */
		closeOnEscape?: boolean;
		/** Callback when modal should close */
		onclose?: () => void;
		/** Modal content */
		children: Snippet;
		/** Optional footer content */
		footer?: Snippet;
	}

	let {
		open = false,
		title,
		maxWidth = 'md',
		closeOnBackdrop = true,
		closeOnEscape = true,
		onclose,
		children,
		footer
	}: Props = $props();

	let dialogEl = $state<HTMLDialogElement | null>(null);

	// Sync open state with dialog
	$effect(() => {
		if (!dialogEl) return;

		if (open && !dialogEl.open) {
			dialogEl.showModal();
		} else if (!open && dialogEl.open) {
			dialogEl.close();
		}
	});

	// Handle backdrop click
	function handleClick(event: MouseEvent) {
		if (!closeOnBackdrop || !dialogEl) return;

		// Check if click was on the backdrop (the dialog element itself)
		const rect = dialogEl.getBoundingClientRect();
		const isInDialog =
			rect.top <= event.clientY &&
			event.clientY <= rect.top + rect.height &&
			rect.left <= event.clientX &&
			event.clientX <= rect.left + rect.width;

		// If click is outside the dialog content, close
		if (event.target === dialogEl && !isInDialog) {
			onclose?.();
		}
	}

	// Handle native close event (Escape key)
	function handleClose() {
		if (closeOnEscape) {
			onclose?.();
		}
	}

	// Handle cancel event (before close)
	function handleCancel(event: Event) {
		if (!closeOnEscape) {
			event.preventDefault();
		}
	}
</script>

<dialog
	bind:this={dialogEl}
	class="modal"
	class:modal-sm={maxWidth === 'sm'}
	class:modal-md={maxWidth === 'md'}
	class:modal-lg={maxWidth === 'lg'}
	onclick={handleClick}
	onclose={handleClose}
	oncancel={handleCancel}
>
	<div class="modal-container">
		<Box title={title} variant="double" borderColor="bright" glow padding={0}>
			<div class="modal-content">
				{@render children()}
			</div>

			{#if footer}
				<div class="modal-footer">
					{@render footer()}
				</div>
			{/if}
		</Box>
	</div>
</dialog>

<style>
	.modal {
		position: fixed;
		padding: 0;
		border: none;
		background: transparent;
		max-height: 90vh;
		max-width: 90vw;
		overflow: visible;
	}

	.modal::backdrop {
		background: rgba(3, 3, 5, 0.92);
		backdrop-filter: blur(8px);
	}

	.modal-sm {
		width: 320px;
	}

	.modal-md {
		width: 480px;
	}

	.modal-lg {
		width: 640px;
	}

	.modal-container {
		background: var(--color-bg-secondary);
		animation: modal-enter 0.2s ease-out;
		box-shadow: var(--shadow-elevated);
	}

	.modal-content {
		padding: var(--space-4);
		max-height: 60vh;
		overflow-y: auto;
	}

	.modal-footer {
		padding: var(--space-3) var(--space-4);
		border-top: 1px solid var(--color-border-subtle);
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}

	@keyframes modal-enter {
		from {
			opacity: 0;
			transform: scale(0.98) translateY(-8px);
		}
		to {
			opacity: 1;
			transform: scale(1) translateY(0);
		}
	}

	/* Focus trap styling */
	.modal:focus {
		outline: none;
	}
</style>
