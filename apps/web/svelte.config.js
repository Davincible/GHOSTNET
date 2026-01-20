import adapter from '@sveltejs/adapter-vercel';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	// Preprocess TypeScript and other languages
	preprocess: vitePreprocess(),

	kit: {
		// Vercel adapter for deployment
		// Bun runtime is configured project-wide via vercel.json (bunVersion: "1.x")
		// See https://vercel.com/docs/functions/runtimes/bun
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
