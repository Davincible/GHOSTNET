import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
	// Directory containing E2E tests
	testDir: './e2e',

	// Output directory for test artifacts
	outputDir: './test-results',

	// Run tests in parallel
	fullyParallel: true,

	// Fail the build on CI if test.only is left in
	forbidOnly: !!process.env.CI,

	// Retry on CI only
	retries: process.env.CI ? 2 : 0,

	// Opt out of parallel tests on CI
	workers: process.env.CI ? 1 : undefined,

	// Reporter configuration
	reporter: [['html', { outputFolder: 'playwright-report' }], ['list']],

	// Shared settings for all projects
	use: {
		// Base URL for navigation
		baseURL: 'http://localhost:4173',

		// Collect trace when retrying the failed test
		trace: 'on-first-retry',

		// Take screenshot on failure
		screenshot: 'only-on-failure',
	},

	// Configure projects for different browsers
	projects: [
		{
			name: 'chromium',
			use: { ...devices['Desktop Chrome'] },
		},
		// Uncomment for additional browser coverage
		// {
		// 	name: 'firefox',
		// 	use: { ...devices['Desktop Firefox'] },
		// },
		// {
		// 	name: 'webkit',
		// 	use: { ...devices['Desktop Safari'] },
		// },
	],

	// Run the dev server before starting tests
	webServer: {
		command: 'bun run build && bun run preview',
		port: 4173,
		reuseExistingServer: !process.env.CI,
	},
});
