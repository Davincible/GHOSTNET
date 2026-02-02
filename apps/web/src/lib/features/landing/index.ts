/**
 * Landing Feature
 *
 * Progressive disclosure components for the homepage.
 * Different experiences based on user state:
 * - LandingHero: First visit (no wallet connected)
 * - JackInFlow: Wallet connected, no position (level + amount selection)
 * - Command Center: Has active position (existing layout)
 */

export { default as LandingHero } from './LandingHero.svelte';
export { default as JackInFlow } from './JackInFlow.svelte';
// Keeping RiskSelector for backwards compatibility, but JackInFlow is preferred
export { default as RiskSelector } from './RiskSelector.svelte';
