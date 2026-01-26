import eslint from '@eslint/js';
import prettier from 'eslint-config-prettier';
import svelte from 'eslint-plugin-svelte';
import globals from 'globals';
import ts from 'typescript-eslint';

// MVP lint config: intentionally ignores non-MVP feature trees.
// This is a shipping gate, not a "repo is perfect" gate.
export default ts.config(
	eslint.configs.recommended,
	...ts.configs.recommended,
	...svelte.configs['flat/recommended'],
	prettier,
	...svelte.configs['flat/prettier'],
	{
		languageOptions: {
			globals: {
				...globals.browser,
				...globals.node,
			},
		},
	},
	{
		files: ['**/*.svelte', '**/*.svelte.ts', '**/*.svelte.js'],
		languageOptions: {
			parserOptions: {
				parser: ts.parser,
			},
		},
	},
	{
		files: ['src/lib/core/audio/manager.svelte.ts', 'src/lib/features/hash-crash/audio.ts'],
		rules: {
			'no-sparse-arrays': 'off',
		},
	},
	{
		files: ['src/lib/features/welcome/WelcomePanel.svelte'],
		rules: {
			// Uses `Array(totalSlides) as _, i` pattern.
			'@typescript-eslint/no-unused-vars': 'off',
		},
	},
	{
		ignores: [
			'build/',
			'.svelte-kit/',
			'dist/',
			'node_modules/',
			'.vercel/',
			'.netlify/',
			'playwright-report/',
			'test-results/',
			'coverage/',

			// Non-MVP routes/features
			'src/routes/arcade/**',
			'src/routes/games/**',
			'src/routes/crew/**',
			'src/routes/market/**',
			'src/routes/leaderboard/**',
			'src/routes/help/**',

			'src/lib/features/arcade/**',
			'src/lib/features/daily/**',
			'src/lib/features/crew/**',
			'src/lib/features/deadpool/**',
			'src/lib/features/hackrun/**',
			'src/lib/features/hash-crash/**',
			'src/lib/features/leaderboard/**',
			'src/lib/features/market/**',

			// Non-MVP heavy visuals
			'src/lib/ui/visualizations/**',

			// Non-MVP mock generators (daily/leaderboard/market)
			'src/lib/core/providers/mock/generators/daily.ts',
			'src/lib/core/providers/mock/generators/leaderboard.ts',
			'src/lib/core/providers/mock/generators/market.ts',

			// Web3 layer still evolving
			'src/lib/web3/**',
		],
	}
);
