/**
 * Presale Feature Module
 * =======================
 * GHOSTNET presale — "INTERCEPT"
 */

// Types
export type {
	PresaleConfig,
	PresaleProgress,
	CurveConfig,
	TrancheConfig,
	ContributionPreview,
	PresalePageState,
	ContributedEvent,
	TrancheCompletedEvent,
	UserPresalePosition,
} from './types';

export {
	PricingMode,
	PresaleState,
	WHALE_THRESHOLD_ETH,
	POLL_INTERVAL_MS,
	BOOT_SEEN_KEY,
} from './types';

// Page compositor
export { default as PresalePage } from './PresalePage.svelte';

// Individual sections (for custom layouts or testing)
export { default as BootSequence } from './BootSequence.svelte';
export { default as HeroSection } from './HeroSection.svelte';
export { default as PricingSection } from './PricingSection.svelte';
export { default as TrancheProgress } from './TrancheProgress.svelte';
export { default as BondingCurveChart } from './BondingCurveChart.svelte';
export { default as ContributionForm } from './ContributionForm.svelte';
export { default as PresaleFeed } from './PresaleFeed.svelte';
export { default as PositionSection } from './PositionSection.svelte';
export { default as ConfirmationOverlay } from './ConfirmationOverlay.svelte';
export { default as TokenomicsSection } from './TokenomicsSection.svelte';
export { default as TrustAnchors } from './TrustAnchors.svelte';
export { default as RefundSection } from './RefundSection.svelte';
export { default as ClaimSection } from './ClaimSection.svelte';

// Contract helpers
export {
	contribute,
	refund,
	claimTokens,
	previewContribution,
} from './presale-contracts';
