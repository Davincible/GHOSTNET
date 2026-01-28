<script lang="ts">
	import Box from '$lib/ui/terminal/Box.svelte';

	interface ContributedEvent {
		contributor: `0x${string}`;
		ethAmount: bigint;
		allocation: bigint;
		totalContributed: bigint;
		totalSold: bigint;
		timestamp: number;
		txHash: `0x${string}`;
	}

	interface Props {
		feedEvents?: ContributedEvent[];
		maxItems?: number;
	}

	const WHALE_THRESHOLD_ETH = 1_000_000_000_000_000_000n; // 1 ETH in wei

	let { feedEvents = [], maxItems = 20 }: Props = $props();

	let items = $derived(feedEvents.slice(0, maxItems));
	let empty = $derived(items.length === 0);

	function shortAddr(addr: `0x${string}`): string {
		return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
	}

	function formatEth(wei: bigint): string {
		return (Number(wei) / 1e18).toFixed(2);
	}

	function formatTokens(amount: bigint): string {
		const num = Number(amount) / 1e18;
		if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1)}M`;
		if (num >= 1_000) return `${Math.round(num).toLocaleString()}`;
		return num.toFixed(0);
	}

	function timeAgo(timestamp: number): string {
		const seconds = Math.floor(Date.now() / 1000) - timestamp;
		if (seconds < 10) return 'just now';
		if (seconds < 60) return `${seconds}s ago`;
		if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
		if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
		return `${Math.floor(seconds / 86400)}d ago`;
	}

	function isWhale(ethAmount: bigint): boolean {
		return ethAmount >= WHALE_THRESHOLD_ETH;
	}
</script>

<Box title="LIVE FEED" variant="single" borderColor="default" borderFill>
	<div class="feed">
		{#if empty}
			<div class="empty">
				<span class="empty-text">AWAITING FIRST SIGNAL</span><span class="cursor">█</span>
			</div>
		{:else}
			{#each items as event (event.txHash)}
				<div class="item">
					<span class="prompt">&gt;</span>
					<span class="addr">{shortAddr(event.contributor)}</span>
					<span class="dim">acquired</span>
					<span class="amount">{formatTokens(event.allocation)} $DATA</span>
					<span class="eth">({formatEth(event.ethAmount)} ETH)</span>
					{#if isWhale(event.ethAmount)}
						<span class="whale">🐋</span>
					{/if}
					<span class="time">{timeAgo(event.timestamp)}</span>
				</div>
			{/each}
		{/if}
	</div>
</Box>

<style>
	.feed {
		max-height: 320px;
		overflow-y: auto;
		scrollbar-width: none;
		display: flex;
		flex-direction: column;
		gap: var(--space-1, 4px);
		padding: var(--space-2, 8px) 0;
	}

	.feed::-webkit-scrollbar {
		display: none;
	}

	.empty {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-6, 24px) 0;
		font-family: var(--font-mono, monospace);
		font-size: var(--text-sm, 0.875rem);
		color: var(--color-text-tertiary, #555);
		letter-spacing: var(--tracking-wider, 0.05em);
	}

	.empty-text {
		margin-right: 2px;
	}

	.cursor {
		animation: blink 1s step-end infinite;
		color: var(--color-accent, #00e5cc);
	}

	@keyframes blink {
		50% {
			opacity: 0;
		}
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
			transform: translateY(-4px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.item {
		display: flex;
		align-items: baseline;
		gap: var(--space-1, 4px);
		font-family: var(--font-mono, monospace);
		font-size: var(--text-xs, 0.75rem);
		line-height: 1.6;
		white-space: nowrap;
		overflow: hidden;
		animation: fadeIn 0.3s ease-out;
		padding: 0 var(--space-1, 4px);
	}

	.prompt {
		color: var(--color-text-tertiary, #555);
		flex-shrink: 0;
	}

	.addr {
		color: var(--color-cyan, #00bcd4);
		flex-shrink: 0;
	}

	.dim {
		color: var(--color-text-tertiary, #555);
		flex-shrink: 0;
	}

	.amount {
		color: var(--color-accent, #00e5cc);
		font-weight: 600;
		flex-shrink: 0;
	}

	.eth {
		color: var(--color-text-secondary, #888);
		flex-shrink: 0;
	}

	.whale {
		flex-shrink: 0;
	}

	.time {
		color: var(--color-text-tertiary, #555);
		margin-left: auto;
		flex-shrink: 0;
	}
</style>
