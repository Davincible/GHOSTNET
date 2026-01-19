/**
 * Counter store demonstrating Svelte 5 runes in a .svelte.ts file.
 *
 * This pattern allows runes ($state, $derived, $effect) to work outside of
 * .svelte component files. The `.svelte.ts` extension tells the compiler
 * to process runes in this file.
 */
export function createCounter(initial = 0) {
	let count = $state(initial);

	return {
		get count() {
			return count;
		},
		get doubled() {
			return count * 2;
		},
		increment() {
			count++;
		},
		decrement() {
			count--;
		},
		reset() {
			count = initial;
		},
	};
}

export type Counter = ReturnType<typeof createCounter>;
