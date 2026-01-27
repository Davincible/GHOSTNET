<script lang="ts">
	import { Header, Breadcrumb } from '$lib/features/header';
	import { NavigationBar } from '$lib/features/nav';
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

<div class="leaderboard-shell">
	<Header />
	<Breadcrumb path={[{ label: 'NETWORK', href: '/' }, { label: 'LEADERBOARD' }]} />

	<main class="leaderboard-content">
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

	<NavigationBar active="leaderboard" />
</div>

<style>
	.leaderboard-shell {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		padding-bottom: var(--space-16);
	}

	.leaderboard-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		padding: var(--space-4) var(--space-6);
		width: 100%;
		max-width: 1000px;
		margin: 0 auto;
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

	@media (max-width: 767px) {
		.leaderboard-content {
			padding: var(--space-2);
		}
	}
</style>
