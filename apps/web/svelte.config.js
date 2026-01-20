import adapter from '@sveltejs/adapter-vercel';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	// Preprocess TypeScript and other languages
	preprocess: vitePreprocess(),

	kit: {
		// Vercel adapter for deployment
		// Runtime: Bun is configured via vercel.json (bunVersion: "1.x")
		// We specify nodejs22.x here as fallback for adapter validation during local builds
		// The actual deployment uses Bun per vercel.json config
		adapter: adapter({
			runtime: 'nodejs22.x'
		}),

		// Alias configuration for cleaner imports
		alias: {
			$components: 'src/lib/components',
			$stores: 'src/lib/stores',
			$utils: 'src/lib/utils',
		},
	},
};

export default config;
