/**
 * Landing Feature
 *
 * Progressive disclosure components for the homepage.
 * Different experiences based on user state:
 * - LandingHero: First visit (no wallet connected)
 * - RiskSelector: Wallet connected, no position
 * - Command Center: Has active position (existing layout)
 */

export { default as LandingHero } from './LandingHero.svelte';
export { default as RiskSelector } from './RiskSelector.svelte';
