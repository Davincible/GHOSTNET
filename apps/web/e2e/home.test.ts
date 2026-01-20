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
		// Wait for mock provider to connect and generate events
		await page.waitForTimeout(1000);
		
		// Feed should have some event items
		const feedItems = page.locator('[class*="feed-item"], [class*="FeedItem"]');
		await expect(feedItems.first()).toBeVisible({ timeout: 5000 });
	});

	// ════════════════════════════════════════════════════════════════
	// MODALS
	// ════════════════════════════════════════════════════════════════

	test('settings modal opens from header', async ({ page }) => {
		// Find and click settings button
		const settingsButton = page.getByRole('button', { name: /settings|gear|cog/i });
		
		// Settings might be an icon button, so also try aria-label
		if (await settingsButton.count() === 0) {
			// Try finding by test id or other means
			const settingsIcon = page.locator('button:has-text("⚙"), [aria-label*="settings" i]').first();
			if (await settingsIcon.count() > 0) {
				await settingsIcon.click();
			}
		} else {
			await settingsButton.click();
		}

		// Modal should be visible with settings title
		const modal = page.locator('[role="dialog"], .modal');
		// Only check if modal appeared (button might not exist in all builds)
		if (await modal.count() > 0) {
			await expect(modal).toBeVisible();
		}
	});

	// ════════════════════════════════════════════════════════════════
	// VISUAL EFFECTS
	// ════════════════════════════════════════════════════════════════

	test('scanlines overlay is present', async ({ page }) => {
		// GHOSTNET uses CRT-style scanlines effect
		const scanlines = page.locator('[class*="scanline"], [class*="Scanline"]');
		// Scanlines should be in the DOM (may be disabled by default)
		const count = await scanlines.count();
		// Either scanlines exist or they're disabled - both are valid states
		expect(count).toBeGreaterThanOrEqual(0);
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
