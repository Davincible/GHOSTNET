<script lang="ts">
	import type { CrewInvite } from '$lib/core/types';
	import { Box } from '$lib/ui/terminal';
	import { Button, Badge } from '$lib/ui/primitives';
	import { Stack, Row } from '$lib/ui/layout';

	interface Props {
		/** Pending crew invites */
		pendingInvites: CrewInvite[];
		/** Callback when "Create Crew" is clicked */
		onCreateCrew: () => void;
		/** Callback when "Browse Crews" is clicked */
		onBrowseCrews: () => void;
		/** Callback when an invite is accepted */
		onAcceptInvite: (invite: CrewInvite) => void;
		/** Callback when an invite is declined */
		onDeclineInvite: (invite: CrewInvite) => void;
	}

	let {
		pendingInvites,
		onCreateCrew,
		onBrowseCrews,
		onAcceptInvite,
		onDeclineInvite,
	}: Props = $props();

	// Format inviter display
	function formatInviter(invite: CrewInvite): string {
		if (invite.inviterName) return invite.inviterName;
		return `${invite.inviterAddress.slice(0, 6)}...`;
	}
</script>

<Box title="CREW STATUS" variant="single" padding={4}>
	<Stack gap={4} align="center">
		<div class="status-badge">
			<Badge variant="warning">NO CREW</Badge>
		</div>

		<p class="status-message">YOU'RE NOT IN A CREW</p>
		<p class="status-description">
			Crews provide shared bonuses, death rate reductions, and social features. Join a crew to
			maximize your survival odds.
		</p>

		<Row gap={3} justify="center">
			<Button variant="primary" onclick={onCreateCrew}>CREATE CREW</Button>
			<Button variant="secondary" onclick={onBrowseCrews}>BROWSE CREWS</Button>
		</Row>

		{#if pendingInvites.length > 0}
			<div class="invites-section">
				<h3 class="invites-header">
					PENDING INVITES
					<span class="invites-count">({pendingInvites.length})</span>
				</h3>

				<div class="invites-list">
					{#each pendingInvites as invite (invite.id)}
						<div class="invite-item">
							<div class="invite-info">
								<span class="invite-crew">
									{invite.crewName}
									<span class="invite-tag">[{invite.crewTag}]</span>
								</span>
								<span class="invite-from">invited by {formatInviter(invite)}</span>
							</div>
							<Row gap={2}>
								<button
									class="invite-btn invite-accept"
									onclick={() => onAcceptInvite(invite)}
									aria-label="Accept invite from {invite.crewName}"
								>
									[ACCEPT]
								</button>
								<button
									class="invite-btn invite-decline"
									onclick={() => onDeclineInvite(invite)}
									aria-label="Decline invite from {invite.crewName}"
								>
									[DECLINE]
								</button>
							</Row>
						</div>
					{/each}
				</div>
			</div>
		{/if}
	</Stack>
</Box>

<style>
	.status-badge {
		padding: var(--space-2) 0;
	}

	.status-message {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wider);
		text-align: center;
	}

	.status-description {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		text-align: center;
		line-height: var(--leading-relaxed);
		max-width: 400px;
	}

	.invites-section {
		width: 100%;
		margin-top: var(--space-4);
		padding-top: var(--space-4);
		border-top: 1px solid var(--color-border-subtle);
	}

	.invites-header {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-widest);
		margin: 0 0 var(--space-3) 0;
	}

	.invites-count {
		color: var(--color-amber);
	}

	.invites-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.invite-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
	}

	.invite-info {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.invite-crew {
		color: var(--color-cyan);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
	}

	.invite-tag {
		color: var(--color-accent);
		margin-left: var(--space-1);
	}

	.invite-from {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	.invite-btn {
		background: none;
		border: none;
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		cursor: pointer;
		padding: var(--space-1);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.invite-accept {
		color: var(--color-profit);
	}

	.invite-accept:hover {
		text-shadow: 0 0 4px var(--color-profit);
	}

	.invite-decline {
		color: var(--color-text-tertiary);
	}

	.invite-decline:hover {
		color: var(--color-red);
	}

	@media (max-width: 480px) {
		.invite-item {
			flex-direction: column;
			align-items: flex-start;
			gap: var(--space-2);
		}
	}
</style>
