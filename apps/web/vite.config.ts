import { sveltekit } from '@sveltejs/kit/vite';
import { playwright } from '@vitest/browser-playwright';
import { defineConfig } from 'vitest/config';

export default defineConfig({
	plugins: [sveltekit()],
	test: {
		projects: [
			// Client-side component tests (Browser Mode - recommended for Svelte 5)
			{
				extends: true,
				test: {
					name: 'client',
					browser: {
						enabled: true,
						provider: playwright(),
						instances: [{ browser: 'chromium' }],
					},
					// IMPORTANT: .svelte in filename enables runes compilation
					include: ['src/**/*.svelte.{test,spec}.{js,ts}'],
					setupFiles: ['./src/vitest-setup-client.ts'],
				},
			},

			// Server-side tests (Node environment)
			{
				extends: true,
				test: {
					name: 'server',
					environment: 'node',
					include: ['src/**/*.server.{test,spec}.{js,ts}'],
				},
			},

			// SSR tests (Node environment for server-side rendering)
			{
				extends: true,
				test: {
					name: 'ssr',
					environment: 'node',
					include: ['src/**/*.ssr.{test,spec}.{js,ts}'],
				},
			},
		],
	},
});
