<script lang="ts">
	import { goto } from '$app/navigation';
	import { Header, Breadcrumb } from '$lib/features/header';
	import { NavigationBar } from '$lib/features/nav';
	import {
		CrewHeader,
		BonusesPanel,
		MembersPanel,
		ActivityFeed,
		NoCrewView,
		CreateCrewModal,
		CrewBrowserModal,
	} from '$lib/features/crew';
	import { ToastContainer, getToasts } from '$lib/ui/toast';
	import { Stack, Row } from '$lib/ui/layout';
	import { Panel } from '$lib/ui/terminal';
	import { Button } from '$lib/ui/primitives';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import {
		generateMockCrew,
		generateMockMembers,
		generateMockActivity,
		generateMockInvites,
	} from '$lib/core/providers/mock/generators/crew';
	import type { Crew, CrewMember, CrewActivity, CrewInvite } from '$lib/core/types';

	const provider = getProvider();
	const toast = getToasts();

	// Navigation state
	let activeNav = $state('crew');

	// Determine if user has a crew (mock: toggle this for testing)
	const USER_HAS_CREW = true;

	// Crew data (loaded from mock generators)
	let crew = $state<Crew | null>(
		USER_HAS_CREW ? generateMockCrew({ memberCount: 23, includeYou: true }) : null
	);
	let members = $state<CrewMember[]>(USER_HAS_CREW ? generateMockMembers(23, true) : []);
	let activity = $state<CrewActivity[]>(generateMockActivity(15));
	let pendingInvites = $state<CrewInvite[]>(!USER_HAS_CREW ? generateMockInvites(2) : []);

	// Modal state
	let showCreateModal = $state(false);
	let showBrowserModal = $state(false);

	// Handlers
	function handleNavigate(id: string) {
		activeNav = id;
		if (id === 'network') {
			goto('/');
		} else if (id === 'pool') {
			goto('/deadpool');
		}
	}

	function handleCreateCrew(data: {
		name: string;
		tag: string;
		description: string;
		isPublic: boolean;
	}) {
		toast.success(`Crew "${data.name}" [${data.tag}] created!`);
		// In production, this would call the contract/API
		showCreateModal = false;

		// Simulate crew creation
		crew = {
			id: crypto.randomUUID(),
			name: data.name,
			tag: data.tag,
			description: data.description,
			memberCount: 1,
			maxMembers: 50,
			rank: 999,
			totalStaked: provider.position?.stakedAmount ?? 0n,
			weeklyExtracted: 0n,
			bonuses: [],
			leader: provider.currentUser?.address ?? '0x0000000000000000000000000000000000000000',
			createdAt: Date.now(),
			isPublic: data.isPublic,
		};
		members = [
			{
				address: provider.currentUser?.address ?? '0x0000000000000000000000000000000000000000',
				level: provider.position?.level ?? null,
				stakedAmount: provider.position?.stakedAmount ?? 0n,
				ghostStreak: provider.position?.ghostStreak ?? 0,
				isOnline: true,
				isYou: true,
				role: 'leader',
				joinedAt: Date.now(),
				weeklyContribution: 0n,
			},
		];
		activity = [];
		pendingInvites = [];
	}

	function handleJoinRequest(targetCrew: Crew) {
		if (targetCrew.isPublic && targetCrew.memberCount < targetCrew.maxMembers) {
			toast.success(`Joined "${targetCrew.name}"!`);
			crew = targetCrew;
			members = generateMockMembers(targetCrew.memberCount, true);
			activity = generateMockActivity(10);
			pendingInvites = [];
		} else {
			toast.info(`Join request sent to "${targetCrew.name}"`);
		}
		showBrowserModal = false;
	}

	function handleAcceptInvite(invite: CrewInvite) {
		toast.success(`Joined "${invite.crewName}"!`);
		// Simulate joining the crew
		const newCrew = generateMockCrew({ memberCount: 20, includeYou: true });
		newCrew.name = invite.crewName;
		newCrew.tag = invite.crewTag;
		crew = newCrew;
		members = generateMockMembers(20, true);
		activity = generateMockActivity(10);
		pendingInvites = [];
	}

	function handleDeclineInvite(invite: CrewInvite) {
		pendingInvites = pendingInvites.filter((i) => i.id !== invite.id);
		toast.info(`Declined invite from "${invite.crewName}"`);
	}

	function handleInviteMember() {
		toast.info('Invite member feature coming soon...');
	}

	function handleLeaveCrew() {
		if (confirm('Are you sure you want to leave this crew?')) {
			toast.warning('You left the crew');
			crew = null;
			members = [];
			activity = [];
			pendingInvites = generateMockInvites(1);
		}
	}

	function handleCrewSettings() {
		toast.info('Crew settings coming soon...');
	}

	function handleViewAllMembers() {
		toast.info('Full member list coming soon...');
	}
</script>

<svelte:head>
	<title>GHOSTNET - Crew</title>
	<meta name="description" content="Crew management. Join forces with other operators." />
</svelte:head>

<div class="crew-page">
	<Header />
	<Breadcrumb path={[{ label: 'NETWORK', href: '/' }, { label: 'CREW' }]} />

	<main class="main-content">
		<Panel title="CREW" blur="content" attention="dimmed" comingSoon>
			{#if crew}
				<!-- User is in a crew -->
				<Stack gap={4}>
					<CrewHeader {crew} />

					<div class="content-grid">
						<!-- Left column: Bonuses + Members -->
						<div class="column">
							<BonusesPanel bonuses={crew.bonuses} />
							<MembersPanel {members} onViewAll={handleViewAllMembers} />
						</div>

						<!-- Right column: Activity -->
						<div class="column">
							<ActivityFeed {activity} />
						</div>
					</div>

					<!-- Action buttons -->
					<Row gap={3} justify="start" class="action-buttons">
						<Button variant="secondary" onclick={handleInviteMember}>INVITE MEMBER</Button>
						<Button variant="ghost" onclick={handleLeaveCrew}>LEAVE CREW</Button>
						<Button variant="ghost" onclick={handleCrewSettings}>SETTINGS</Button>
					</Row>
				</Stack>
			{:else}
				<!-- User is not in a crew -->
				<NoCrewView
					{pendingInvites}
					onCreateCrew={() => (showCreateModal = true)}
					onBrowseCrews={() => (showBrowserModal = true)}
					onAcceptInvite={handleAcceptInvite}
					onDeclineInvite={handleDeclineInvite}
				/>
			{/if}
		</Panel>

	</main>

	<NavigationBar active={activeNav} onNavigate={handleNavigate} />
</div>

<!-- Modals -->
<CreateCrewModal
	open={showCreateModal}
	onclose={() => (showCreateModal = false)}
	onCreate={handleCreateCrew}
/>

<CrewBrowserModal
	open={showBrowserModal}
	onclose={() => (showBrowserModal = false)}
	onJoinRequest={handleJoinRequest}
/>

<!-- Toast notifications -->
<ToastContainer />

<style>
	.crew-page {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		padding-bottom: var(--space-16); /* Room for fixed nav */
	}

	.main-content {
		flex: 1;
		padding: var(--space-4) var(--space-6);
		width: 100%;
		max-width: 1200px;
		margin: 0 auto;
	}

	.content-grid {
		display: grid;
		grid-template-columns: 1fr; /* Mobile first: single column */
		gap: var(--space-4);
	}

	.column {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		min-width: 0; /* Allow column to shrink below content size */
	}

	:global(.action-buttons) {
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-border-subtle);
	}

	/* Mobile spacing */
	@media (max-width: 767px) {
		.main-content {
			padding: var(--space-2);
		}

		.content-grid {
			gap: var(--space-2);
		}
	}

	/* Tablet: 60/40 split */
	@media (min-width: 768px) {
		.content-grid {
			grid-template-columns: 3fr 2fr;
		}
	}

	/* Desktop: wider left column for bonuses + members */
	@media (min-width: 1024px) {
		.content-grid {
			grid-template-columns: 2fr 1fr;
		}
	}
</style>
