<script lang="ts">
	import { Modal } from '$lib/ui/modal';
	import { Button } from '$lib/ui/primitives';
	import { Stack, Row } from '$lib/ui/layout';
	import { getSettings } from '$lib/core/settings';

	interface Props {
		/** Whether the modal is open */
		open: boolean;
		/** Callback when modal should close */
		onclose: () => void;
	}

	let { open, onclose }: Props = $props();

	const settings = getSettings();

	// Local state for slider (to avoid rapid localStorage writes)
	let volumeValue = $state(settings.audioVolume * 100);

	// Sync volume on change
	function handleVolumeChange(event: Event) {
		const input = event.target as HTMLInputElement;
		volumeValue = Number(input.value);
		settings.audioVolume = volumeValue / 100;
	}

	// Reset when modal opens
	$effect(() => {
		if (open) {
			volumeValue = settings.audioVolume * 100;
		}
	});

	function handleReset() {
		settings.reset();
		volumeValue = settings.audioVolume * 100;
	}
</script>

<Modal {open} title="SETTINGS" maxWidth="sm" {onclose}>
	<Stack gap={4}>
		<!-- Audio Section -->
		<div class="settings-section">
			<h3 class="section-title">AUDIO</h3>
			
			<div class="setting-row">
				<label class="setting-label" for="audio-enabled">
					Sound Effects
				</label>
				<label class="toggle">
					<input
						id="audio-enabled"
						type="checkbox"
						bind:checked={settings.audioEnabled}
					/>
					<span class="toggle-slider"></span>
				</label>
			</div>

			<div class="setting-row" class:disabled={!settings.audioEnabled}>
				<label class="setting-label" for="audio-volume">
					Volume
				</label>
				<div class="volume-control">
					<input
						id="audio-volume"
						type="range"
						min="0"
						max="100"
						value={volumeValue}
						oninput={handleVolumeChange}
						disabled={!settings.audioEnabled}
					/>
					<span class="volume-value">{Math.round(volumeValue)}%</span>
				</div>
			</div>
		</div>

		<!-- Visual Section -->
		<div class="settings-section">
			<h3 class="section-title">VISUAL EFFECTS</h3>
			
			<div class="setting-row">
				<label class="setting-label" for="effects-enabled">
					Screen Flashes
					<span class="setting-hint">Flash on deaths, survivals, etc.</span>
				</label>
				<label class="toggle">
					<input
						id="effects-enabled"
						type="checkbox"
						bind:checked={settings.effectsEnabled}
					/>
					<span class="toggle-slider"></span>
				</label>
			</div>

			<div class="setting-row">
				<label class="setting-label" for="scanlines-enabled">
					Scanlines Overlay
					<span class="setting-hint">CRT monitor effect</span>
				</label>
				<label class="toggle">
					<input
						id="scanlines-enabled"
						type="checkbox"
						bind:checked={settings.scanlinesEnabled}
					/>
					<span class="toggle-slider"></span>
				</label>
			</div>

			<div class="setting-row">
				<label class="setting-label" for="flicker-enabled">
					Screen Flicker
					<span class="setting-hint">Subtle CRT flicker (may affect motion-sensitive users)</span>
				</label>
				<label class="toggle">
					<input
						id="flicker-enabled"
						type="checkbox"
						bind:checked={settings.flickerEnabled}
					/>
					<span class="toggle-slider"></span>
				</label>
			</div>
		</div>

		<!-- Actions -->
		<div class="settings-actions">
			<Button variant="ghost" size="sm" onclick={handleReset}>
				Reset to Defaults
			</Button>
		</div>

		<Row justify="end">
			<Button variant="primary" onclick={onclose}>
				Done
			</Button>
		</Row>
	</Stack>
</Modal>

<style>
	.settings-section {
		border-bottom: 1px solid var(--color-bg-tertiary);
		padding-bottom: var(--space-3);
	}

	.settings-section:last-of-type {
		border-bottom: none;
	}

	.section-title {
		color: var(--color-green-mid);
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		margin-bottom: var(--space-3);
	}

	.setting-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-2) 0;
		transition: opacity var(--duration-fast) var(--ease-default);
	}

	.setting-row.disabled {
		opacity: 0.5;
	}

	.setting-label {
		color: var(--color-green-bright);
		font-size: var(--text-sm);
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.setting-hint {
		color: var(--color-green-dim);
		font-size: var(--text-xs);
	}

	/* Toggle Switch */
	.toggle {
		position: relative;
		display: inline-block;
		width: 48px;
		height: 24px;
		cursor: pointer;
	}

	.toggle input {
		opacity: 0;
		width: 0;
		height: 0;
	}

	.toggle-slider {
		position: absolute;
		inset: 0;
		background-color: var(--color-bg-tertiary);
		border: 1px solid var(--color-green-dim);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.toggle-slider::before {
		position: absolute;
		content: '';
		height: 18px;
		width: 18px;
		left: 2px;
		bottom: 2px;
		background-color: var(--color-green-dim);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.toggle input:checked + .toggle-slider {
		background-color: var(--color-green-glow);
		border-color: var(--color-green-bright);
	}

	.toggle input:checked + .toggle-slider::before {
		transform: translateX(24px);
		background-color: var(--color-green-bright);
	}

	.toggle input:focus-visible + .toggle-slider {
		outline: 2px solid var(--color-cyan);
		outline-offset: 2px;
	}

	/* Volume Control */
	.volume-control {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.volume-control input[type='range'] {
		width: 100px;
		height: 4px;
		appearance: none;
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-green-dim);
		cursor: pointer;
	}

	.volume-control input[type='range']::-webkit-slider-thumb {
		appearance: none;
		width: 12px;
		height: 12px;
		background: var(--color-green-bright);
		border: none;
		cursor: pointer;
	}

	.volume-control input[type='range']::-moz-range-thumb {
		width: 12px;
		height: 12px;
		background: var(--color-green-bright);
		border: none;
		cursor: pointer;
	}

	.volume-control input[type='range']:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.volume-value {
		color: var(--color-green-mid);
		font-size: var(--text-xs);
		width: 36px;
		text-align: right;
		font-variant-numeric: tabular-nums;
	}

	.settings-actions {
		display: flex;
		justify-content: center;
	}
</style>
