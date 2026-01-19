<script lang="ts">
	interface Props {
		initialCount?: number;
	}

	let { initialCount = 0 }: Props = $props();

	let count = $state(initialCount);
	let doubled = $derived(count * 2);

	function increment() {
		count++;
	}

	function decrement() {
		count--;
	}

	function reset() {
		count = initialCount;
	}
</script>

<div class="counter">
	<p>Count: <span data-testid="count">{count}</span></p>
	<p>Doubled: <span data-testid="doubled">{doubled}</span></p>

	<div class="buttons">
		<button onclick={decrement} aria-label="Decrement">-</button>
		<button onclick={reset} aria-label="Reset">Reset</button>
		<button onclick={increment} aria-label="Increment">+</button>
	</div>
</div>

<style>
	.counter {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 1rem;
		border: 1px solid #ddd;
		border-radius: 8px;
		margin-top: 1rem;
	}

	.buttons {
		display: flex;
		gap: 0.5rem;
	}

	button {
		padding: 0.5rem 1rem;
		font-size: 1rem;
		border: none;
		border-radius: 4px;
		background: #ff3e00;
		color: white;
		cursor: pointer;
	}

	button:hover {
		background: #d63600;
	}
</style>
