<script lang="ts">
	import type { FeedEvent } from '$lib/core/types';
	import { LevelBadge, AmountDisplay } from '$lib/ui/data-display';

	interface Props {
		/** The feed event to display */
		event: FeedEvent;
		/** Current user's address for highlighting */
		currentUserAddress?: `0x${string}` | null;
		/** Whether this is a new event (for animation) */
		isNew?: boolean;
	}

	let { event, currentUserAddress = null, isNew = false }: Props = $props();

	// Format address for display
	function formatAddress(address: `0x${string}`): string {
		return `${address.slice(0, 6)}...${address.slice(-4)}`;
	}

	// Check if this event involves the current user
	let isCurrentUser = $derived.by(() => {
		if (!currentUserAddress) return false;
		const data = event.data;
		if ('address' in data) {
			return data.address.toLowerCase() === currentUserAddress.toLowerCase();
		}
		if ('jackpotWinner' in data) {
			return data.jackpotWinner.toLowerCase() === currentUserAddress.toLowerCase();
		}
		return false;
	});

	// Get display properties based on event type
	let display = $derived.by(() => {
		const data = event.data;

		switch (data.type) {
			case 'JACK_IN':
				return {
					prefix: '>',
					text: `${formatAddress(data.address)} jacked in`,
					level: data.level,
					amount: data.amount,
					color: 'text-green',
					icon: null
				};

			case 'EXTRACT':
				return {
					prefix: '>',
					text: `${formatAddress(data.address)} extracted`,
					level: null,
					amount: data.amount,
					gain: data.gain,
					color: 'text-profit',
					icon: null
				};

			case 'TRACED':
				return {
					prefix: '>',
					text: `${formatAddress(data.address)}`,
					traced: true,
					level: data.level,
					amount: data.amountLost,
					color: 'text-red',
					icon: null
				};

			case 'SURVIVED':
				return {
					prefix: '>',
					text: `${formatAddress(data.address)} survived`,
					level: data.level,
					streak: data.streak,
					color: 'text-green-mid',
					icon: null
				};

			case 'TRACE_SCAN_WARNING':
				return {
					prefix: '>',
					text: 'TRACE SCAN',
					level: data.level,
					warning: true,
					seconds: data.secondsUntil,
					color: 'text-amber',
					icon: null
				};

			case 'TRACE_SCAN_START':
				return {
					prefix: '>',
					text: 'SCANNING',
					level: data.level,
					scanning: true,
					color: 'text-amber',
					icon: null
				};

			case 'TRACE_SCAN_COMPLETE':
				return {
					prefix: '>',
					text: 'SCAN COMPLETE',
					level: data.level,
					survivors: data.survivors,
					traced: data.traced,
					color: 'text-cyan',
					icon: null
				};

			case 'CASCADE':
				return {
					prefix: '>',
					text: 'CASCADE',
					level: data.sourceLevel,
					burned: data.burned,
					distributed: data.distributed,
					color: 'text-amber',
					icon: null
				};

			case 'WHALE_ALERT':
				return {
					prefix: '>',
					text: `WHALE: ${formatAddress(data.address)}`,
					level: data.level,
					amount: data.amount,
					color: 'text-gold',
					icon: null
				};

			case 'SYSTEM_RESET_WARNING':
				return {
					prefix: '>',
					text: 'SYSTEM RESET',
					seconds: data.secondsUntil,
					critical: true,
					color: 'text-red',
					icon: null
				};

			case 'SYSTEM_RESET':
				return {
					prefix: '>',
					text: 'SYSTEM RESET EXECUTED',
					penalty: data.penaltyPercent,
					winner: data.jackpotWinner,
					color: 'text-red',
					icon: null
				};

			case 'CREW_EVENT':
				return {
					prefix: '>',
					text: `[${data.crewName}] ${data.message}`,
					color: 'text-cyan',
					icon: null
				};

			case 'MINIGAME_RESULT':
				return {
					prefix: '>',
					text: `${formatAddress(data.address)} ${data.game}: ${data.result}`,
					color: 'text-cyan',
					icon: null
				};

			case 'JACKPOT':
				return {
					prefix: '>',
					text: `JACKPOT: ${formatAddress(data.address)}`,
					level: data.level,
					amount: data.amount,
					jackpot: true,
					color: 'text-gold',
					icon: null
				};

			default:
				return {
					prefix: '>',
					text: 'Unknown event',
					color: 'text-green-dim',
					icon: null
				};
		}
	});
</script>

<div
	class="feed-item {display.color}"
	class:feed-item-new={isNew}
	class:feed-item-current-user={isCurrentUser}
	class:feed-item-traced={'traced' in display && display.traced}
	class:feed-item-jackpot={'jackpot' in display && display.jackpot}
	class:feed-item-warning={'warning' in display && display.warning}
	class:feed-item-critical={'critical' in display && display.critical}
	data-testid="feed-item"
>
	<span class="feed-prefix">{display.prefix}</span>

	{#if 'traced' in display && display.traced}
		<span class="feed-text">{display.text}</span>
		<span class="feed-traced-badge">TRACED</span>
		{#if 'level' in display && display.level}
			<LevelBadge level={display.level} compact />
		{/if}
		{#if 'amount' in display && display.amount}
			<span class="feed-loss">-<AmountDisplay amount={display.amount} format="compact" /></span>
		{/if}
	{:else if 'warning' in display && display.warning}
		<span class="feed-warning-icon" aria-hidden="true">!</span>
		<span class="feed-text">{display.text}</span>
		{#if 'level' in display && display.level}
			<LevelBadge level={display.level} compact />
		{/if}
		{#if 'seconds' in display}
			<span class="feed-countdown">in {display.seconds}s</span>
		{/if}
		<span class="feed-warning-icon" aria-hidden="true">!</span>
	{:else if 'scanning' in display && display.scanning}
		<span class="feed-scanning" aria-hidden="true"></span>
		<span class="feed-text">{display.text}</span>
		{#if 'level' in display && display.level}
			<LevelBadge level={display.level} compact />
		{/if}
		<span class="feed-scanning" aria-hidden="true"></span>
	{:else if 'critical' in display && display.critical}
		<span class="feed-critical-icon" aria-hidden="true">!!</span>
		<span class="feed-text">{display.text}</span>
		{#if 'seconds' in display}
			<span class="feed-countdown">in {display.seconds}s</span>
		{/if}
		<span class="feed-critical-note">NEEDS DEPOSITS</span>
	{:else if 'jackpot' in display && display.jackpot}
		<span class="feed-jackpot-icon" aria-hidden="true"></span>
		<span class="feed-text">{display.text}</span>
		{#if 'level' in display && display.level}
			<LevelBadge level={display.level} compact />
		{/if}
		{#if 'amount' in display && display.amount}
			<span class="feed-gain">+<AmountDisplay amount={display.amount} format="compact" /></span>
		{/if}
		<span class="feed-jackpot-icon" aria-hidden="true"></span>
	{:else if 'survivors' in display}
		<span class="feed-text">{display.text}</span>
		{#if 'level' in display && display.level}
			<LevelBadge level={display.level} compact />
		{/if}
		<span class="feed-stats">{display.survivors} survived, {display.traced} traced</span>
	{:else}
		<span class="feed-text">{display.text}</span>
		{#if 'level' in display && display.level}
			<LevelBadge level={display.level} compact />
		{/if}
		{#if 'amount' in display && display.amount}
			<AmountDisplay amount={display.amount} format="compact" />
		{/if}
		{#if 'gain' in display && display.gain}
			<span class="feed-gain">[+<AmountDisplay amount={display.gain} format="compact" /> gain]</span>
		{/if}
		{#if 'streak' in display && display.streak}
			<span class="feed-streak">streak: {display.streak}</span>
		{/if}
	{/if}
</div>

<style>
	.feed-item {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-1);
		padding: var(--space-1) 0;
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		border-bottom: 1px solid var(--color-border-subtle);
		transition: background-color var(--duration-fast) var(--ease-default);
	}

	.feed-item:last-child {
		border-bottom: none;
	}

	.feed-item-new {
		animation: feed-item-enter 0.3s ease-out;
	}

	.feed-item-current-user {
		background-color: var(--color-accent-glow);
	}

	.feed-item-traced {
		animation: feed-item-flash-red 0.5s ease-out;
	}

	.feed-item-jackpot {
		animation: feed-item-flash-gold 0.5s ease-out;
	}

	.feed-item-warning {
		animation: feed-item-pulse 1s ease-in-out infinite;
	}

	.feed-item-critical {
		animation: feed-item-pulse-fast 0.5s ease-in-out infinite;
	}

	.feed-prefix {
		color: var(--color-text-muted);
		user-select: none;
	}

	.feed-text {
		color: inherit;
	}

	/* Color classes */
	:global(.text-green) {
		color: var(--color-accent);
	}

	:global(.text-green-mid) {
		color: var(--color-accent-mid);
	}

	:global(.text-green-dim) {
		color: var(--color-text-tertiary);
	}

	:global(.text-profit) {
		color: var(--color-profit);
	}

	:global(.text-red) {
		color: var(--color-red);
	}

	:global(.text-amber) {
		color: var(--color-amber);
	}

	:global(.text-cyan) {
		color: var(--color-cyan);
	}

	:global(.text-gold) {
		color: var(--color-gold);
	}

	.feed-traced-badge {
		padding: 0 var(--space-1);
		background: var(--color-red);
		color: var(--color-bg-void);
		font-weight: var(--font-bold);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.feed-warning-icon,
	.feed-critical-icon {
		color: inherit;
		font-weight: var(--font-bold);
	}

	.feed-jackpot-icon::before {
		content: '';
	}

	.feed-scanning::before {
		content: '';
		display: inline-block;
		width: 4ch;
		background: linear-gradient(90deg, var(--color-amber), transparent);
		animation: scan-bar 0.5s linear infinite;
	}

	.feed-countdown {
		color: var(--color-amber);
	}

	.feed-critical-note {
		color: var(--color-red);
		font-size: var(--text-xs);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
	}

	.feed-gain {
		color: var(--color-profit);
	}

	.feed-loss {
		color: var(--color-loss);
	}

	.feed-streak {
		color: var(--color-amber);
	}

	.feed-stats {
		color: var(--color-text-secondary);
		font-size: var(--text-xs);
	}

	/* Animations */
	@keyframes feed-item-enter {
		from {
			opacity: 0;
			transform: translateY(-4px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	@keyframes feed-item-flash-red {
		0%,
		100% {
			background-color: transparent;
		}
		20%,
		60% {
			background-color: var(--color-red-glow);
		}
	}

	@keyframes feed-item-flash-gold {
		0%,
		100% {
			background-color: transparent;
		}
		20%,
		60% {
			background-color: var(--color-gold-glow);
		}
	}

	@keyframes feed-item-pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.6;
		}
	}

	@keyframes feed-item-pulse-fast {
		0%,
		100% {
			opacity: 1;
			background-color: transparent;
		}
		50% {
			opacity: 0.7;
			background-color: var(--color-red-glow);
		}
	}

	@keyframes scan-bar {
		from {
			background-position: -100% 0;
		}
		to {
			background-position: 200% 0;
		}
	}
</style>
