<script lang="ts">
	import { Modal } from '$lib/ui/modal';
	import { Button, Badge } from '$lib/ui/primitives';
	import { Stack, Row } from '$lib/ui/layout';

	interface Props {
		/** Whether the modal is open */
		open: boolean;
		/** Callback when modal should close */
		onclose: () => void;
		/** Callback when crew is created */
		onCreate: (data: { name: string; tag: string; description: string; isPublic: boolean }) => void;
	}

	let { open, onclose, onCreate }: Props = $props();

	// Form state
	let name = $state('');
	let tag = $state('');
	let description = $state('');
	let isPublic = $state(true);
	let isSubmitting = $state(false);

	// Validation
	let nameError = $derived.by(() => {
		if (!name) return null;
		if (name.length < 3) return 'Name must be at least 3 characters';
		if (name.length > 24) return 'Name must be 24 characters or less';
		if (!/^[a-zA-Z0-9\s]+$/.test(name)) return 'Name can only contain letters, numbers, and spaces';
		return null;
	});

	let tagError = $derived.by(() => {
		if (!tag) return null;
		if (tag.length < 2 || tag.length > 4) return 'Tag must be 2-4 characters';
		if (!/^[A-Z0-9]+$/.test(tag.toUpperCase())) return 'Tag can only contain letters and numbers';
		return null;
	});

	let isValid = $derived(
		name.length >= 3 &&
			name.length <= 24 &&
			tag.length >= 2 &&
			tag.length <= 4 &&
			!nameError &&
			!tagError
	);

	// Reset state when modal opens
	$effect(() => {
		if (open) {
			name = '';
			tag = '';
			description = '';
			isPublic = true;
			isSubmitting = false;
		}
	});

	// Handlers
	async function handleSubmit() {
		if (!isValid || isSubmitting) return;

		isSubmitting = true;
		try {
			await onCreate({
				name: name.trim(),
				tag: tag.toUpperCase().trim(),
				description: description.trim(),
				isPublic,
			});
			onclose();
		} catch (error) {
			console.error('Failed to create crew:', error);
		} finally {
			isSubmitting = false;
		}
	}

	function handleTagInput(event: Event) {
		const input = event.target as HTMLInputElement;
		tag = input.value.toUpperCase();
	}
</script>

<Modal {open} title="CREATE CREW" maxWidth="md" {onclose}>
	<Stack gap={4}>
		<p class="modal-description">
			Form your crew. Lead operators through the network. Max 50 members.
		</p>

		<!-- Crew Name -->
		<div class="input-group">
			<label class="input-label" for="crew-name">CREW NAME</label>
			<input
				id="crew-name"
				type="text"
				class="input-field"
				class:error={nameError}
				bind:value={name}
				placeholder="Enter crew name..."
				maxlength={24}
			/>
			{#if nameError}
				<span class="input-error">{nameError}</span>
			{:else}
				<span class="input-hint">{name.length}/24 characters</span>
			{/if}
		</div>

		<!-- Crew Tag -->
		<div class="input-group">
			<label class="input-label" for="crew-tag">CREW TAG</label>
			<Row align="center" gap={2}>
				<span class="tag-bracket">[</span>
				<input
					id="crew-tag"
					type="text"
					class="input-field input-tag"
					class:error={tagError}
					value={tag}
					oninput={handleTagInput}
					placeholder="TAG"
					maxlength={4}
				/>
				<span class="tag-bracket">]</span>
			</Row>
			{#if tagError}
				<span class="input-error">{tagError}</span>
			{:else}
				<span class="input-hint">2-4 characters, displayed as [{tag || 'TAG'}]</span>
			{/if}
		</div>

		<!-- Description -->
		<div class="input-group">
			<label class="input-label" for="crew-description">DESCRIPTION (optional)</label>
			<textarea
				id="crew-description"
				class="input-field input-textarea"
				bind:value={description}
				placeholder="Enter crew mission statement..."
				rows={3}
				maxlength={140}
			></textarea>
			<span class="input-hint">{description.length}/140 characters</span>
		</div>

		<!-- Visibility Toggle -->
		<div class="input-group" role="group" aria-labelledby="visibility-label">
			<span id="visibility-label" class="input-label">VISIBILITY</span>
			<Row gap={3}>
				<button
					type="button"
					class="toggle-option"
					class:active={isPublic}
					onclick={() => (isPublic = true)}
				>
					<span class="toggle-indicator">{isPublic ? '[x]' : '[ ]'}</span>
					<span class="toggle-label">PUBLIC</span>
					<span class="toggle-desc">Anyone can join</span>
				</button>
				<button
					type="button"
					class="toggle-option"
					class:active={!isPublic}
					onclick={() => (isPublic = false)}
				>
					<span class="toggle-indicator">{!isPublic ? '[x]' : '[ ]'}</span>
					<span class="toggle-label">PRIVATE</span>
					<span class="toggle-desc">Invite only</span>
				</button>
			</Row>
		</div>

		<!-- Preview -->
		{#if name && tag}
			<div class="preview">
				<span class="preview-label">PREVIEW:</span>
				<span class="preview-name">{name.toUpperCase()}</span>
				<span class="preview-tag">[{tag.toUpperCase()}]</span>
			</div>
		{/if}

		<!-- Actions -->
		<Row justify="end" gap={2}>
			<Button variant="ghost" onclick={onclose}>Cancel</Button>
			<Button variant="primary" onclick={handleSubmit} disabled={!isValid} loading={isSubmitting}>
				CREATE CREW
			</Button>
		</Row>
	</Stack>
</Modal>

<style>
	.modal-description {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		line-height: var(--leading-relaxed);
	}

	.input-group {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.input-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-widest);
		text-transform: uppercase;
	}

	.input-field {
		background: var(--color-bg-primary);
		border: 1px solid var(--color-border-default);
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		padding: var(--space-2) var(--space-3);
		outline: none;
		transition: border-color var(--duration-fast) var(--ease-default);
	}

	.input-field:focus {
		border-color: var(--color-accent);
	}

	.input-field::placeholder {
		color: var(--color-text-tertiary);
	}

	.input-field.error {
		border-color: var(--color-red);
	}

	.input-tag {
		width: 6ch;
		text-align: center;
		text-transform: uppercase;
	}

	.input-textarea {
		resize: none;
		min-height: 80px;
	}

	.input-hint {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	.input-error {
		color: var(--color-red);
		font-size: var(--text-xs);
	}

	.tag-bracket {
		color: var(--color-accent);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
	}

	/* Toggle options */
	.toggle-option {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: var(--space-1);
		padding: var(--space-2) var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.toggle-option:hover {
		border-color: var(--color-accent-dim);
	}

	.toggle-option.active {
		border-color: var(--color-accent);
		background: rgba(var(--color-accent-rgb, 0, 229, 204), 0.05);
	}

	.toggle-indicator {
		color: var(--color-accent);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
	}

	.toggle-label {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
	}

	.toggle-desc {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	/* Preview */
	.preview {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
		border: 1px dashed var(--color-border-default);
	}

	.preview-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	.preview-name {
		color: var(--color-cyan);
		font-weight: var(--font-bold);
	}

	.preview-tag {
		color: var(--color-accent);
	}
</style>
