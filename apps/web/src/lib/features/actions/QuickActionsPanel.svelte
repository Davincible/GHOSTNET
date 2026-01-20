<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Button } from '$lib/ui/primitives';
	import { Stack } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';

	interface Props {
		/** Callback when jack in is clicked */
		onJackIn?: () => void;
		/** Callback when extract is clicked */
		onExtract?: () => void;
		/** Callback when trace evasion is clicked */
		onTraceEvasion?: () => void;
		/** Callback when hack run is clicked */
		onHackRun?: () => void;
		/** Callback when crew is clicked */
		onCrew?: () => void;
		/** Callback when dead pool is clicked */
		onDeadPool?: () => void;
	}

	let {
		onJackIn,
		onExtract,
		onTraceEvasion,
		onHackRun,
		onCrew,
		onDeadPool
	}: Props = $props();

	const provider = getProvider();

	// Determine button states
	let canJackIn = $derived(!!provider.currentUser);
	let canExtract = $derived(!!provider.position);
	let canPlayGames = $derived(!!provider.position);
</script>

<Box title="QUICK ACTIONS">
	<Stack gap={2}>
		<Button
			variant="secondary"
			hotkey="J"
			fullWidth
			disabled={!canJackIn}
			onclick={onJackIn}
		>
			{provider.position ? 'Jack In More' : 'Jack In'}
		</Button>

		<Button
			variant="danger"
			hotkey="E"
			fullWidth
			disabled={!canExtract}
			onclick={onExtract}
		>
			Extract All
		</Button>

		<div class="divider"></div>

		<Button
			variant="secondary"
			hotkey="T"
			fullWidth
			disabled={!canPlayGames}
			onclick={onTraceEvasion}
		>
			Trace Evasion
		</Button>

		<Button
			variant="secondary"
			hotkey="H"
			fullWidth
			disabled={!canPlayGames}
			onclick={onHackRun}
		>
			Hack Run
		</Button>

		<div class="divider"></div>

		<Button
			variant="ghost"
			hotkey="C"
			fullWidth
			disabled={!provider.currentUser}
			onclick={onCrew}
		>
			Crew
		</Button>

		<Button
			variant="ghost"
			hotkey="P"
			fullWidth
			disabled={!provider.currentUser}
			onclick={onDeadPool}
		>
			Dead Pool
		</Button>
	</Stack>
</Box>

<style>
	.divider {
		height: 1px;
		background: var(--color-border-subtle);
		margin: var(--space-1) 0;
	}
</style>
