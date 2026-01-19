import adapter from '@sveltejs/adapter-auto';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	// Preprocess TypeScript and other languages
	preprocess: vitePreprocess(),

	kit: {
		// adapter-auto automatically selects the right adapter for your deployment target
		// See https://svelte.dev/docs/kit/adapters for available adapters
		adapter: adapter(),

		// Alias configuration for cleaner imports
		alias: {
			$components: 'src/lib/components',
			$stores: 'src/lib/stores',
			$utils: 'src/lib/utils',
		},
	},
};

export default config;
