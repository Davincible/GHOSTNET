/**
 * Component tests for Counter using Vitest Browser Mode.
 *
 * This demonstrates the recommended approach for testing Svelte 5 components:
 * - Browser Mode (real browser via Playwright)
 * - vitest-browser-svelte for rendering
 * - page.getByRole() locators that auto-retry
 *
 * See: docs/guides/SvelteBestPractices/26-TestingSetup.md
 */
import { describe, it, expect } from 'vitest';
import { render } from 'vitest-browser-svelte';
import { page } from 'vitest/browser';
import Counter from './Counter.svelte';

describe('Counter Component', () => {
	describe('Rendering', () => {
		it('renders with default count of 0', async () => {
			render(Counter);

			await expect.element(page.getByTestId('count')).toHaveTextContent('0');
			await expect.element(page.getByTestId('doubled')).toHaveTextContent('0');
		});

		it('renders with custom initial count', async () => {
			render(Counter, { initialCount: 5 });

			await expect.element(page.getByTestId('count')).toHaveTextContent('5');
			await expect.element(page.getByTestId('doubled')).toHaveTextContent('10');
		});

		it('displays all buttons', async () => {
			render(Counter);

			await expect.element(page.getByRole('button', { name: 'Increment' })).toBeVisible();
			await expect.element(page.getByRole('button', { name: 'Decrement' })).toBeVisible();
			await expect.element(page.getByRole('button', { name: 'Reset' })).toBeVisible();
		});
	});

	describe('User Interactions', () => {
		it('increments count when + button is clicked', async () => {
			render(Counter);

			const incrementButton = page.getByRole('button', { name: 'Increment' });
			await incrementButton.click();

			await expect.element(page.getByTestId('count')).toHaveTextContent('1');
			await expect.element(page.getByTestId('doubled')).toHaveTextContent('2');
		});

		it('decrements count when - button is clicked', async () => {
			render(Counter, { initialCount: 5 });

			const decrementButton = page.getByRole('button', { name: 'Decrement' });
			await decrementButton.click();

			await expect.element(page.getByTestId('count')).toHaveTextContent('4');
		});

		it('resets to initial value', async () => {
			render(Counter, { initialCount: 10 });

			// Change the count
			const incrementButton = page.getByRole('button', { name: 'Increment' });
			await incrementButton.click();
			await incrementButton.click();
			await expect.element(page.getByTestId('count')).toHaveTextContent('12');

			// Reset
			const resetButton = page.getByRole('button', { name: 'Reset' });
			await resetButton.click();
			await expect.element(page.getByTestId('count')).toHaveTextContent('10');
		});

		it('handles multiple clicks', async () => {
			render(Counter);

			const incrementButton = page.getByRole('button', { name: 'Increment' });

			await incrementButton.click();
			await incrementButton.click();
			await incrementButton.click();

			await expect.element(page.getByTestId('count')).toHaveTextContent('3');
			await expect.element(page.getByTestId('doubled')).toHaveTextContent('6');
		});
	});

	describe('Edge Cases', () => {
		it('allows negative counts', async () => {
			render(Counter);

			const decrementButton = page.getByRole('button', { name: 'Decrement' });
			await decrementButton.click();

			await expect.element(page.getByTestId('count')).toHaveTextContent('-1');
			await expect.element(page.getByTestId('doubled')).toHaveTextContent('-2');
		});
	});
});
