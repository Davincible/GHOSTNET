<script lang="ts">
	import Modal from '$lib/ui/modal/Modal.svelte';
	import IntroVideo from './IntroVideo.svelte';

	interface Props {
		open: boolean;
		onclose?: () => void;
	}

	let { open = false, onclose }: Props = $props();
</script>

<Modal {open} title="/// TRANSMISSION ///" maxWidth="xl" {onclose}>
	<div class="intro-modal-body">
		<IntroVideo active={open} />
	</div>
</Modal>

<style>
	.intro-modal-body {
		/* Remove Modal's default padding — let the video fill edge-to-edge */
		margin: calc(-1 * var(--space-4, 1rem));
	}
</style>
