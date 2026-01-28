<!--
  PresalePage.svelte
  ==================
  Main compositor for the /presale route — "INTERCEPT".
  Manages boot sequence, then renders sections based on presale.pageState.
-->
<script lang="ts">
	import { browser } from '$app/environment';
	import { presale } from './presale.store.svelte';
	import { getContractAddress } from '$lib/web3/abis';
	import { wallet } from '$lib/web3/wallet.svelte';
	import { BOOT_SEEN_KEY } from './types';
	import Scanlines from '$lib/ui/terminal/Scanlines.svelte';

	// Sections
	import BootSequence from './BootSequence.svelte';
	import HeroSection from './HeroSection.svelte';
	import PricingSection from './PricingSection.svelte';
	import ContributionForm from './ContributionForm.svelte';
	import PresaleFeed from './PresaleFeed.svelte';
	import PositionSection from './PositionSection.svelte';
	import ConfirmationOverlay from './ConfirmationOverlay.svelte';
	import TokenomicsSection from './TokenomicsSection.svelte';
	import TrustAnchors from './TrustAnchors.svelte';
	import RefundSection from './RefundSection.svelte';
	import ClaimSection from './ClaimSection.svelte';

	// ─────────────────────────────────────────────────────────────
	// Boot Sequence
	// ─────────────────────────────────────────────────────────────

	let bootSeen = $state(browser ? !!localStorage.getItem(BOOT_SEEN_KEY) : true);
	let showBoot = $derived(!bootSeen);

	function handleBootComplete() {
		bootSeen = true;
	}

	// ─────────────────────────────────────────────────────────────
	// Contribution Confirmation
	// ─────────────────────────────────────────────────────────────

	let showConfirmation = $state(false);

	function handleContributed() {
		showConfirmation = true;
	}

	function handleConfirmDismiss() {
		showConfirmation = false;
	}

	// ─────────────────────────────────────────────────────────────
	// Contract Address (for TrustAnchors)
	// ─────────────────────────────────────────────────────────────

	let presaleAddress = $derived(
		wallet.chainId ? getContractAddress(wallet.chainId, 'ghostPresale') : null,
	);

	// ─────────────────────────────────────────────────────────────
	// Initialize Store
	// ─────────────────────────────────────────────────────────────

	$effect(() => {
		return presale.init();
	});
</script>

<!-- CRT scanlines overlay -->
<Scanlines opacity={0.02} />

{#if showBoot}
	<!-- Boot sequence (first visit only) -->
	<BootSequence oncomplete={handleBootComplete} />
{:else}
	<div class="presale-page">
		{#if presale.loading}
			<div class="presale-loading">
				<span class="blink">█</span> ESTABLISHING CONNECTION...
			</div>
		{:else if presale.error}
			<div class="presale-error">
				<span class="error-prefix">[ERR]</span> {presale.error}
				<button class="retry-btn" onclick={() => presale.refresh()}>RETRY</button>
			</div>
		{:else}
			<!-- ════ HERO ════ -->
			<HeroSection pageState={presale.pageState} />

			<!-- ════ PRICING + PROGRESS (all states except REFUNDING) ════ -->
			{#if presale.pageState !== 'REFUNDING'}
				<section class="section-gap">
					<PricingSection
						pricingMode={presale.pricingMode}
						progress={presale.progress}
						curveConfig={presale.curveConfig}
					/>
				</section>
			{/if}

			<!-- ════ STATE-SPECIFIC SECTIONS ════ -->
			{#if presale.pageState === 'LIVE'}
				<!-- Contribution Form -->
				<section class="section-gap">
					{#if showConfirmation && wallet.address}
						<ConfirmationOverlay
							allocation={presale.userPosition.allocation}
							address={wallet.address}
							ondismiss={handleConfirmDismiss}
						/>
					{:else}
						<ContributionForm
							config={presale.config}
							progress={presale.progress}
							pricingMode={presale.pricingMode}
							userContribution={presale.userPosition.contributed}
							userAllocation={presale.userPosition.allocation}
							oncontributed={handleContributed}
						/>
					{/if}
				</section>

				<!-- Live Feed -->
				<section class="section-gap">
					<PresaleFeed />
				</section>

				<!-- User Position (if contributed) -->
				{#if presale.hasContributed}
					<section class="section-gap">
						<PositionSection
							allocation={presale.userPosition.allocation}
							contributed={presale.userPosition.contributed}
							contributorCount={presale.progress.contributorCount}
						/>
					</section>
				{/if}

			{:else if presale.pageState === 'SOLD_OUT' || presale.pageState === 'ENDED'}
				<!-- Position (if contributed) -->
				{#if presale.hasContributed}
					<section class="section-gap">
						<PositionSection
							allocation={presale.userPosition.allocation}
							contributed={presale.userPosition.contributed}
							contributorCount={presale.progress.contributorCount}
						/>
					</section>
				{/if}

			{:else if presale.pageState === 'REFUNDING'}
				<section class="section-gap">
					<RefundSection contributed={presale.userPosition.contributed} />
				</section>

			{:else if presale.pageState === 'CLAIM_ACTIVE'}
				<section class="section-gap">
					<ClaimSection
						allocation={presale.userPosition.allocation}
						claimable={presale.userPosition.claimable}
						hasClaimed={presale.userPosition.hasClaimed}
					/>
				</section>

			{:else if presale.pageState === 'CLAIMED'}
				<section class="section-gap">
					<ClaimSection
						allocation={presale.userPosition.allocation}
						claimable={0n}
						hasClaimed={true}
					/>
				</section>
			{/if}

			<!-- ════ TOKENOMICS (always visible) ════ -->
			<section class="section-gap">
				<TokenomicsSection />
			</section>

			<!-- ════ TRUST ANCHORS (always visible) ════ -->
			<section class="section-gap">
				<TrustAnchors
					{presaleAddress}
					pricingMode={presale.pricingMode}
					totalPresaleSupply={presale.progress.totalSupply}
				/>
			</section>
		{/if}
	</div>
{/if}

<style>
	.presale-page {
		min-height: 100vh;
		background: var(--color-bg-void, #0a0a0a);
		color: var(--color-text-primary, #00e5cc);
		font-family: var(--font-mono, 'IBM Plex Mono', monospace);
		padding: var(--space-8, 2rem) var(--space-4, 1rem);
		max-width: 960px;
		margin: 0 auto;
	}

	.presale-loading,
	.presale-error {
		text-align: center;
		padding: var(--space-8, 2rem) 0;
		font-size: var(--text-base, 1rem);
	}

	.presale-error {
		color: var(--color-red, #ff3333);
	}

	.error-prefix {
		color: var(--color-red, #ff3333);
		font-weight: bold;
	}

	.retry-btn {
		display: inline-block;
		margin-top: var(--space-4, 1rem);
		padding: var(--space-2, 0.5rem) var(--space-6, 1.5rem);
		background: transparent;
		border: 1px solid var(--color-red, #ff3333);
		color: var(--color-red, #ff3333);
		font-family: inherit;
		cursor: pointer;
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider, 0.1em);
	}

	.retry-btn:hover {
		background: var(--color-red, #ff3333);
		color: var(--color-bg-void, #0a0a0a);
	}

	.blink {
		animation: blink 1s step-end infinite;
	}

	@keyframes blink {
		50% {
			opacity: 0;
		}
	}

	.section-gap {
		margin-bottom: var(--space-6, 1.5rem);
	}
</style>
