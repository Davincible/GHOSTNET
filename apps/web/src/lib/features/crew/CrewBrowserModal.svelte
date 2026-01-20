<script lang="ts">
	import type { Crew } from '$lib/core/types';
	import { Modal } from '$lib/ui/modal';
	import { Button, Badge, ProgressBar } from '$lib/ui/primitives';
	import { Stack, Row } from '$lib/ui/layout';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { generateCrewRankings } from '$lib/core/providers/mock/generators/crew';

	interface Props {
		/** Whether the modal is open */
		open: boolean;
		/** Callback when modal should close */
		onclose: () => void;
		/** Callback when user requests to join a crew */
		onJoinRequest: (crew: Crew) => void;
	}

	let { open, onclose, onJoinRequest }: Props = $props();

	// Mock data - in production this would come from an API
	let rankings = $state(generateCrewRankings(20));
	let searchQuery = $state('');
	let sortBy = $state<'rank' | 'members' | 'tvl'>('rank');

	// Filtered and sorted crews
	let filteredCrews = $derived.by(() => {
		let crews = rankings.map((r) => r.crew);

		// Filter by search
		if (searchQuery) {
			const query = searchQuery.toLowerCase();
			crews = crews.filter(
				(c) =>
					c.name.toLowerCase().includes(query) ||
					c.tag.toLowerCase().includes(query) ||
					c.description.toLowerCase().includes(query)
			);
		}

		// Sort
		switch (sortBy) {
			case 'members':
				crews = [...crews].sort((a, b) => b.memberCount - a.memberCount);
				break;
			case 'tvl':
				crews = [...crews].sort((a, b) => Number(b.totalStaked - a.totalStaked));
				break;
			case 'rank':
			default:
				crews = [...crews].sort((a, b) => a.rank - b.rank);
		}

		return crews;
	});

	// Reset state when modal opens
	$effect(() => {
		if (open) {
			searchQuery = '';
			sortBy = 'rank';
			rankings = generateCrewRankings(20);
		}
	});

	// Handlers
	function handleJoin(crew: Crew) {
		onJoinRequest(crew);
	}
</script>

<Modal {open} title="BROWSE CREWS" maxWidth="lg" {onclose}>
	<Stack gap={3}>
		<!-- Search and Sort -->
		<Row gap={3} align="end">
			<div class="search-group">
				<label class="search-label" for="crew-search">SEARCH</label>
				<input
					id="crew-search"
					type="text"
					class="search-input"
					bind:value={searchQuery}
					placeholder="Search crews..."
				/>
			</div>
			<div class="sort-group" role="group" aria-labelledby="sort-label">
				<span id="sort-label" class="sort-label">SORT BY</span>
				<Row gap={1}>
					<button
						class="sort-btn"
						class:active={sortBy === 'rank'}
						onclick={() => (sortBy = 'rank')}
					>
						RANK
					</button>
					<button
						class="sort-btn"
						class:active={sortBy === 'members'}
						onclick={() => (sortBy = 'members')}
					>
						MEMBERS
					</button>
					<button
						class="sort-btn"
						class:active={sortBy === 'tvl'}
						onclick={() => (sortBy = 'tvl')}
					>
						TVL
					</button>
				</Row>
			</div>
		</Row>

		<!-- Results count -->
		<p class="results-count">{filteredCrews.length} crews found</p>

		<!-- Crew List -->
		<div class="crews-list">
			{#each filteredCrews as crew (crew.id)}
				<div class="crew-card">
					<div class="crew-header-row">
						<div class="crew-identity">
							<span class="crew-rank">#{crew.rank}</span>
							<span class="crew-name">{crew.name}</span>
							<span class="crew-tag">[{crew.tag}]</span>
							{#if !crew.isPublic}
								<Badge variant="default" compact>PRIVATE</Badge>
							{/if}
						</div>
					</div>

					<p class="crew-description">"{crew.description}"</p>

					<div class="crew-stats">
						<div class="stat">
							<span class="stat-label">MEMBERS</span>
							<span class="stat-value">{crew.memberCount}/{crew.maxMembers}</span>
							<ProgressBar
								value={(crew.memberCount / crew.maxMembers) * 100}
								width={8}
								variant="cyan"
							/>
						</div>
						<div class="stat">
							<span class="stat-label">TVL</span>
							<span class="stat-value"><AmountDisplay amount={crew.totalStaked} format="compact" /></span>
						</div>
						<div class="stat">
							<span class="stat-label">BONUSES</span>
							<span class="stat-value">
								{crew.bonuses.filter((b) => b.active).length}/{crew.bonuses.length} active
							</span>
						</div>
					</div>

					<div class="crew-actions">
						{#if crew.isPublic}
							{#if crew.memberCount < crew.maxMembers}
								<Button variant="primary" size="sm" onclick={() => handleJoin(crew)}>
									JOIN
								</Button>
							{:else}
								<Badge variant="warning">FULL</Badge>
							{/if}
						{:else}
							<Button variant="secondary" size="sm" onclick={() => handleJoin(crew)}>
								REQUEST
							</Button>
						{/if}
					</div>
				</div>
			{/each}

			{#if filteredCrews.length === 0}
				<p class="no-results">No crews match your search</p>
			{/if}
		</div>
	</Stack>
</Modal>

<style>
	/* Search and Sort */
	.search-group {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.search-label,
	.sort-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-widest);
	}

	.search-input {
		background: var(--color-bg-primary);
		border: 1px solid var(--color-border-default);
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		padding: var(--space-2) var(--space-3);
		outline: none;
		width: 100%;
	}

	.search-input:focus {
		border-color: var(--color-accent);
	}

	.search-input::placeholder {
		color: var(--color-text-tertiary);
	}

	.sort-group {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.sort-btn {
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		padding: var(--space-1) var(--space-2);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.sort-btn:hover {
		color: var(--color-text-primary);
		border-color: var(--color-border-default);
	}

	.sort-btn.active {
		background: var(--color-accent);
		border-color: var(--color-accent);
		color: var(--color-bg-void);
	}

	.results-count {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	/* Crews List */
	.crews-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		max-height: 400px;
		overflow-y: auto;
		padding-right: var(--space-2);
	}

	.crew-card {
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		transition: border-color var(--duration-fast) var(--ease-default);
	}

	.crew-card:hover {
		border-color: var(--color-border-default);
	}

	.crew-header-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: var(--space-1);
	}

	.crew-identity {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		flex-wrap: wrap;
	}

	.crew-rank {
		color: var(--color-amber);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		min-width: 3ch;
	}

	.crew-name {
		color: var(--color-cyan);
		font-weight: var(--font-bold);
	}

	.crew-tag {
		color: var(--color-accent);
		font-size: var(--text-sm);
	}

	.crew-description {
		color: var(--color-text-secondary);
		font-size: var(--text-xs);
		font-style: italic;
		margin-bottom: var(--space-2);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.crew-stats {
		display: flex;
		gap: var(--space-4);
		margin-bottom: var(--space-2);
		flex-wrap: wrap;
	}

	.stat {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.stat-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	.stat-value {
		color: var(--color-text-primary);
		font-size: var(--text-xs);
		font-family: var(--font-mono);
	}

	.crew-actions {
		display: flex;
		justify-content: flex-end;
	}

	.no-results {
		color: var(--color-text-tertiary);
		text-align: center;
		padding: var(--space-4);
	}

	/* Scrollbar styling */
	.crews-list::-webkit-scrollbar {
		width: 4px;
	}

	.crews-list::-webkit-scrollbar-track {
		background: var(--color-bg-tertiary);
	}

	.crews-list::-webkit-scrollbar-thumb {
		background: var(--color-border-strong);
	}

	.crews-list::-webkit-scrollbar-thumb:hover {
		background: var(--color-accent-dim);
	}

	@media (max-width: 480px) {
		.crew-stats {
			flex-direction: column;
			gap: var(--space-1);
		}
	}
</style>
