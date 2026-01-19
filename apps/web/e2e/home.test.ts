/**
 * End-to-end tests for the home page.
 *
 * E2E tests run against a real built application (via `bun run preview`).
 * Use these for testing full user flows across multiple pages.
 *
 * For component-level testing, prefer Vitest Browser Mode tests.
 */
import { test, expect } from '@playwright/test';

test.describe('Home Page', () => {
	test('has expected title', async ({ page }) => {
		await page.goto('/');
		await expect(page).toHaveTitle(/SvelteKit/);
	});

	test('displays welcome heading', async ({ page }) => {
		await page.goto('/');
		await expect(page.getByRole('heading', { level: 1 })).toContainText('Welcome to SvelteKit');
	});

	test('counter increments on click', async ({ page }) => {
		await page.goto('/');

		// Initial state
		await expect(page.getByTestId('count')).toHaveText('0');

		// Click increment
		await page.getByRole('button', { name: 'Increment' }).click();

		// Verify update
		await expect(page.getByTestId('count')).toHaveText('1');
		await expect(page.getByTestId('doubled')).toHaveText('2');
	});
});
