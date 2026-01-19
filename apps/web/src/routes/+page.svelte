<script lang="ts">
	import Counter from '$components/Counter.svelte';
</script>

<svelte:head>
	<title>SvelteKit Template</title>
	<meta name="description" content="A SvelteKit template with Svelte 5 runes" />
</svelte:head>

<main>
	<h1>Welcome to SvelteKit</h1>
	<p>
		Visit <a href="https://svelte.dev/docs/kit">svelte.dev/docs/kit</a> to learn more about SvelteKit.
	</p>

	<Counter />
</main>

<style>
	main {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 2rem;
		max-width: 800px;
		margin: 0 auto;
	}

	h1 {
		color: #ff3e00;
	}

	a {
		color: #ff3e00;
	}
</style>
