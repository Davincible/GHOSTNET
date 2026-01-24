/**
 * GHOSTNET Home Page E2E Tests
 * =============================
 * Tests for the main command center interface.
 *
 * E2E tests run against a real built application (via `bun run preview`).
 * Use these for testing full user flows across multiple pages.
 */
import { test, expect } from '@playwright/test';

test.describe('GHOSTNET Home Page', () => {
	test.beforeEach(async ({ page }) => {
		await page.goto('/');
	});

	// ════════════════════════════════════════════════════════════════
	// PAGE LOAD & BASIC STRUCTURE
	// ════════════════════════════════════════════════════════════════

	test('has GHOSTNET title', async ({ page }) => {
		await expect(page).toHaveTitle(/GHOSTNET/);
	});

	test('displays header with logo', async ({ page }) => {
		// Header should contain GHOSTNET branding
		const header = page.locator('header');
		await expect(header).toBeVisible();
	});

	test('displays feed panel', async ({ page }) => {
		// Feed panel shows live events
		const feedPanel = page.locator('text=LIVE FEED').first();
		await expect(feedPanel).toBeVisible();
	});

	test('displays position panel', async ({ page }) => {
		// Position panel shows user's current position
		const positionPanel = page.locator('text=POSITION').first();
		await expect(positionPanel).toBeVisible();
	});

	test('displays quick actions panel', async ({ page }) => {
		// Quick actions provides primary game actions
		const actionsPanel = page.locator('text=QUICK ACTIONS').first();
		await expect(actionsPanel).toBeVisible();
	});

	// ════════════════════════════════════════════════════════════════
	// WALLET CONNECTION
	// ════════════════════════════════════════════════════════════════

	test('shows connect wallet button when not connected', async ({ page }) => {
		// Wallet button should be visible in header
		const walletButton = page.getByRole('button', { name: /connect|wallet/i });
		await expect(walletButton).toBeVisible();
	});

	// ════════════════════════════════════════════════════════════════
	// NAVIGATION
	// ════════════════════════════════════════════════════════════════

	test('navigation bar is visible', async ({ page }) => {
		// Bottom navigation should be present
		const nav = page.locator('nav');
		await expect(nav).toBeVisible();
	});

	// ════════════════════════════════════════════════════════════════
	// FEED EVENTS
	// ════════════════════════════════════════════════════════════════

	test('feed loads with events after connection', async ({ page }) => {
		// Feed should have some event items (wait for mock provider to generate events)
		// Using data-testid for stable selection
		const feedItems = page.getByTestId('feed-item');
		await expect(feedItems.first()).toBeVisible({ timeout: 5000 });
	});

	// ════════════════════════════════════════════════════════════════
	// MODALS
	// ════════════════════════════════════════════════════════════════

	test('settings modal opens from header', async ({ page }) => {
		// Find and click settings button using stable test ID
		const settingsButton = page.getByTestId('settings-button');
		await expect(settingsButton).toBeVisible();
		await settingsButton.click();

		// Modal should be visible - prefer role-based selector for accessibility
		const modal = page.getByRole('dialog');
		await expect(modal).toBeVisible();
	});

	// ════════════════════════════════════════════════════════════════
	// VISUAL EFFECTS
	// ════════════════════════════════════════════════════════════════

	test('scanlines overlay is present when enabled', async ({ page }) => {
		// GHOSTNET uses CRT-style scanlines effect
		// Using data-testid for stable selection
		const scanlines = page.getByTestId('scanlines-overlay');

		// Scanlines are enabled by default, so should be visible
		await expect(scanlines).toBeVisible();
	});

	// ════════════════════════════════════════════════════════════════
	// RESPONSIVE BEHAVIOR
	// ════════════════════════════════════════════════════════════════

	test('layout is responsive on mobile', async ({ page }) => {
		// Set mobile viewport
		await page.setViewportSize({ width: 375, height: 667 });
		await page.goto('/');

		// Content should still be visible
		const positionPanel = page.locator('text=POSITION').first();
		await expect(positionPanel).toBeVisible();

		// Navigation should still work
		const nav = page.locator('nav');
		await expect(nav).toBeVisible();
	});
});

test.describe('Navigation to other pages', () => {
	test('can navigate to typing game', async ({ page }) => {
		await page.goto('/typing');
		await expect(page).toHaveURL(/\/typing/);

		// Typing page should load
		const typingContent = page.locator('text=/trace|evasion|typing/i').first();
		await expect(typingContent).toBeVisible({ timeout: 5000 });
	});

	test('can navigate to leaderboard', async ({ page }) => {
		await page.goto('/leaderboard');
		await expect(page).toHaveURL(/\/leaderboard/);
	});
});
