<script lang="ts">
	/**
	 * Scrolling terminal log for atmospheric messages.
	 * Displays hacking-themed status updates during gameplay.
	 */

	import type { TerminalMessage } from '../../../messages';

	interface Props {
		/** Messages to display */
		messages: TerminalMessage[];
		/** Maximum number of visible lines */
		maxLines?: number;
		/** Height of the log area */
		height?: string;
	}

	let { messages, maxLines = 6, height = '120px' }: Props = $props();

	// Get visible messages (most recent)
	let visibleMessages = $derived(messages.slice(-maxLines));

	// Color class based on message type
	function getColorClass(type: TerminalMessage['type']): string {
		switch (type) {
			case 'success':
				return 'msg-success';
			case 'warning':
				return 'msg-warning';
			case 'danger':
				return 'msg-danger';
			case 'system':
				return 'msg-system';
			default:
				return 'msg-info';
		}
	}
</script>

<div class="terminal-log" style:height style:--max-lines={maxLines}>
	<div class="log-content">
		{#each visibleMessages as message, i (i)}
			<div
				class="log-line {getColorClass(message.type)}"
				class:new={i === visibleMessages.length - 1}
			>
				{message.text}
			</div>
		{/each}
	</div>
	<div class="log-fade"></div>
</div>

<style>
	.terminal-log {
		position: relative;
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		background: var(--color-bg-void);
		border: var(--border-width) solid var(--color-border-subtle);
		overflow: hidden;
	}

	.log-content {
		padding: var(--space-2);
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.log-line {
		opacity: 0.7;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		animation: fade-in 0.3s ease-out;
	}

	.log-line.new {
		opacity: 1;
	}

	/* Message colors */
	.msg-info {
		color: var(--color-text-secondary);
	}

	.msg-success {
		color: var(--color-accent);
	}

	.msg-warning {
		color: var(--color-amber);
	}

	.msg-danger {
		color: var(--color-red);
		font-weight: var(--font-medium);
	}

	.msg-system {
		color: var(--color-cyan);
	}

	/* Fade at top to indicate more content */
	.log-fade {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: var(--space-4);
		background: linear-gradient(to bottom, var(--color-bg-void), transparent);
		pointer-events: none;
	}

	@keyframes fade-in {
		from {
			opacity: 0;
			transform: translateY(5px);
		}
		to {
			opacity: 0.7;
			transform: translateY(0);
		}
	}
</style>
