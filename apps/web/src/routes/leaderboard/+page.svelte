<script lang="ts">
	import { goto } from '$app/navigation';
	import { Shell } from '$lib/ui/terminal';
	import {
		LeaderboardHeader,
		CategoryTabs,
		TimeframeTabs,
		LeaderboardTable,
		CrewLeaderboard,
		YourRankCard,
	} from '$lib/features/leaderboard';
	import {
		generateLeaderboardData,
		generateUserRankings,
		generateCrewLeaderboard,
	} from '$lib/core/providers/mock/generators/leaderboard';
	import type { LeaderboardCategory, LeaderboardTimeframe } from '$lib/core/types/leaderboard';

	// Selected category and timeframe state
	let category = $state<LeaderboardCategory>('ghost_streak');
	let timeframe = $state<LeaderboardTimeframe>('all_time');

	// Generate mock data based on selections
	let data = $derived(generateLeaderboardData(category, timeframe, 50));
	let userRankings = $state(generateUserRankings());
	let crewData = $state(generateCrewLeaderboard(20));

	// Whether to show crew leaderboard (special case)
	let showCrews = $derived(category === 'crews');

	// Handle category change
	function handleCategoryChange(newCategory: LeaderboardCategory): void {
		category = newCategory;
	}

	// Handle timeframe change
	function handleTimeframeChange(newTimeframe: LeaderboardTimeframe): void {
		timeframe = newTimeframe;
	}
</script>

<svelte:head>
	<title>Leaderboard | GHOSTNET</title>
</svelte:head>

<Shell>
	<div class="leaderboard-page">
		<!-- Header -->
		<header class="page-header">
			<button class="back-button" onclick={() => goto('/')} aria-label="Return to network">
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="19" y1="12" x2="5" y2="12"></line>
					<polyline points="12 19 5 12 12 5"></polyline>
				</svg>
				<span>NETWORK</span>
			</button>
			<h1 class="page-title">RANKINGS</h1>
			<div class="spacer"></div>
		</header>

		<!-- Main Content -->
		<main class="page-content">
			<!-- Leaderboard Header with User Rankings Summary -->
			<section class="section-header">
				<LeaderboardHeader {userRankings} />
			</section>

			<!-- Category & Timeframe Tabs -->
			<section class="section-tabs">
				<div class="tabs-row">
					<CategoryTabs selected={category} onchange={handleCategoryChange} />
				</div>
				{#if !showCrews}
					<div class="tabs-row timeframe-row">
						<TimeframeTabs selected={timeframe} onchange={handleTimeframeChange} />
					</div>
				{/if}
			</section>

			<!-- Leaderboard Table or Crew Leaderboard -->
			<section class="section-table">
				{#if showCrews}
					<CrewLeaderboard entries={crewData} />
				{:else}
					<LeaderboardTable {data} />
				{/if}
			</section>

			<!-- Your Rank Card (context-specific) -->
			{#if !showCrews}
				<section class="section-your-rank">
					<YourRankCard {data} positionChange={Math.floor(Math.random() * 20) - 5} />
				</section>
			{/if}
		</main>
	</div>
</Shell>

<style>
	.leaderboard-page {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		padding: var(--space-4);
		max-width: 1000px;
		margin: 0 auto;
	}

	.page-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: var(--space-6);
		padding-bottom: var(--space-3);
		border-bottom: 1px solid var(--color-bg-tertiary);
	}

	.back-button {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2) var(--space-3);
		background: transparent;
		border: 1px solid var(--color-green-dim);
		color: var(--color-green-mid);
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		letter-spacing: var(--tracking-wide);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.back-button:hover {
		background: var(--color-bg-secondary);
		border-color: var(--color-green-mid);
		color: var(--color-green-bright);
	}

	.back-button svg {
		width: 16px;
		height: 16px;
	}

	.page-title {
		color: var(--color-green-bright);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.spacer {
		width: 100px;
	}

	.page-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.section-header {
		margin-bottom: var(--space-2);
	}

	.section-tabs {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.tabs-row {
		display: flex;
		flex-wrap: wrap;
	}

	.timeframe-row {
		margin-top: var(--space-1);
	}

	.section-table {
		flex: 1;
	}

	.section-your-rank {
		margin-top: var(--space-2);
	}

	@media (max-width: 640px) {
		.leaderboard-page {
			padding: var(--space-3);
		}

		.page-header {
			margin-bottom: var(--space-4);
		}

		.back-button {
			padding: var(--space-1) var(--space-2);
			font-size: var(--text-xs);
		}

		.page-title {
			font-size: var(--text-base);
		}

		.spacer {
			width: 80px;
		}
	}
</style>
