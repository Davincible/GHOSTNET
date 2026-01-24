/**
 * Daily Operations Feature
 * ========================
 * Components for daily check-ins, streaks, missions, and contract interactions.
 */

// UI Components
export { default as DailyOpsPanel } from './DailyOpsPanel.svelte';
export { default as StreakProgress } from './StreakProgress.svelte';
export { default as StreakDisplay } from './StreakDisplay.svelte';
export { default as StreakCalendar } from './StreakCalendar.svelte';
export { default as MissionCard } from './MissionCard.svelte';
export { default as BadgeDisplay } from './BadgeDisplay.svelte';
export { default as ShieldPurchase } from './ShieldPurchase.svelte';

// Contract Provider
export { createDailyOpsProvider } from './contractProvider.svelte';
export type { DailyOpsState, DailyOpsProvider, NextMilestone } from './contractProvider.svelte';

// Mock Provider
export { createMockDailyOpsProvider } from './mockProvider.svelte';
export type { MockProviderOptions, MockDailyOpsProvider } from './mockProvider.svelte';

// Contract Functions
export * from './contracts';
