<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';
	import { SimplifiedHero, QuickPitch, BigSteps, RiskLevelCards } from '$lib/features/experiments';
	import { GettingStartedPanel } from '$lib/features/getting-started';

	// State for risk level selection
	let selectedLevel = $state<'vault' | 'mainframe' | 'subnet' | 'darknet' | 'blackice'>('subnet');

	// Mock handlers
	function handleJackIn() {
		alert('Jack In clicked!');
	}

	function handleWatchFeed() {
		alert('Watch Feed clicked!');
	}

	function handleConnectWallet() {
		alert('Connect Wallet clicked!');
	}

	function handleLevelSelect(level: 'vault' | 'mainframe' | 'subnet' | 'darknet' | 'blackice') {
		selectedLevel = level;
	}
</script>

<svelte:head>
	<title>Experiments Showcase | GHOSTNET Dev</title>
</svelte:head>

<Stack gap={6}>
	<!-- Intro -->
	<Box title="UX EXPERIMENTS">
		<div class="intro">
			<p class="intro-description">
				Testing different approaches to simplify the homepage experience. Goal: Communicate value
				proposition in 5 seconds without overwhelming new users.
			</p>
			<p class="intro-note">
				Each component shown two ways: RAW (on black background) vs IN PANEL (inside Box component).
			</p>
			<div class="intro-stats">
				<span class="stat">
					<span class="stat-label">EXPERIMENTS</span>
					<span class="stat-value">4</span>
				</span>
				<span class="stat">
					<span class="stat-label">FOCUS</span>
					<span class="stat-value">CONVERSION</span>
				</span>
				<span class="stat">
					<span class="stat-label">TARGET</span>
					<span class="stat-value">5 SEC COMPREHENSION</span>
				</span>
			</div>
		</div>
	</Box>

	<!-- Current Implementation (for comparison) -->
	<section class="experiment-section">
		<header class="section-header">
			<h2 class="section-title">CURRENT: GettingStartedPanel</h2>
			<p class="section-description">
				The current implementation. Already uses Box component internally.
			</p>
		</header>
		<div class="comparison-grid">
			<div class="comparison-column">
				<span class="comparison-label">CURRENT IMPLEMENTATION</span>
				<div class="preview-area">
					<div class="component-wrapper" style="max-width: 400px;">
						<GettingStartedPanel onConnectWallet={handleConnectWallet} />
					</div>
				</div>
			</div>
		</div>
	</section>

	<!-- Experiment 1: SimplifiedHero -->
	<section class="experiment-section">
		<header class="section-header">
			<h2 class="section-title">EXPERIMENT 1: SimplifiedHero</h2>
			<p class="section-description">Larger typography. 3-step horizontal flow. Single CTA.</p>
		</header>
		<div class="comparison-grid">
			<div class="comparison-column">
				<span class="comparison-label">RAW (no panel)</span>
				<div class="preview-area">
					<div class="component-wrapper">
						<SimplifiedHero
							onJackIn={handleJackIn}
							onWatchFeed={handleWatchFeed}
							showDecorations={false}
						/>
					</div>
				</div>
			</div>
			<div class="comparison-column">
				<span class="comparison-label">IN PANEL (Box component)</span>
				<div class="preview-area">
					<div class="component-wrapper">
						<Box title="NETWORK INITIALIZATION" borderColor="cyan">
							<SimplifiedHero
								onJackIn={handleJackIn}
								onWatchFeed={handleWatchFeed}
								showDecorations={false}
							/>
						</Box>
					</div>
				</div>
			</div>
		</div>
	</section>

	<!-- Experiment 2: QuickPitch -->
	<section class="experiment-section">
		<header class="section-header">
			<h2 class="section-title">EXPERIMENT 2: QuickPitch</h2>
			<p class="section-description">Ultra-minimal. Just the pitch + CTA. Maximum clarity.</p>
		</header>
		<div class="comparison-grid">
			<div class="comparison-column">
				<span class="comparison-label">RAW (no panel)</span>
				<div class="preview-area">
					<div class="component-wrapper" style="max-width: 550px;">
						<QuickPitch onJackIn={handleJackIn} playersOnline={1847} tvl="$4.8M" />
					</div>
				</div>
			</div>
			<div class="comparison-column">
				<span class="comparison-label">IN PANEL (Box component)</span>
				<div class="preview-area">
					<div class="component-wrapper" style="max-width: 550px;">
						<Box title="GHOSTNET" borderColor="cyan">
							<QuickPitch onJackIn={handleJackIn} playersOnline={1847} tvl="$4.8M" />
						</Box>
					</div>
				</div>
			</div>
		</div>
	</section>

	<!-- Experiment 3: BigSteps -->
	<section class="experiment-section">
		<header class="section-header">
			<h2 class="section-title">EXPERIMENT 3: BigSteps</h2>
			<p class="section-description">The 4-step flow with larger, more readable typography.</p>
		</header>
		<div class="comparison-grid">
			<div class="comparison-column">
				<span class="comparison-label">RAW (no panel)</span>
				<div class="preview-area">
					<div class="component-wrapper" style="max-width: 420px;">
						<BigSteps onConnectWallet={handleConnectWallet} variant="default" />
					</div>
				</div>
			</div>
			<div class="comparison-column">
				<span class="comparison-label">IN PANEL (Box component)</span>
				<div class="preview-area">
					<div class="component-wrapper" style="max-width: 420px;">
						<Box title="GETTING STARTED">
							<BigSteps onConnectWallet={handleConnectWallet} variant="default" showCta={true} />
						</Box>
					</div>
				</div>
			</div>
		</div>

		<!-- Additional variants -->
		<div class="variants-section">
			<span class="variants-title">ADDITIONAL VARIANTS (all in panels)</span>
			<div class="comparison-grid">
				<div class="comparison-column">
					<span class="comparison-label">COMPACT</span>
					<div class="preview-area preview-area-small">
						<div class="component-wrapper" style="max-width: 380px;">
							<Box title="GETTING STARTED">
								<BigSteps onConnectWallet={handleConnectWallet} variant="compact" />
							</Box>
						</div>
					</div>
				</div>
				<div class="comparison-column">
					<span class="comparison-label">NO CTA</span>
					<div class="preview-area preview-area-small">
						<div class="component-wrapper" style="max-width: 380px;">
							<Box title="HOW IT WORKS">
								<BigSteps showCta={false} variant="default" />
							</Box>
						</div>
					</div>
				</div>
			</div>
		</div>
	</section>

	<!-- Experiment 4: RiskLevelCards -->
	<section class="experiment-section">
		<header class="section-header">
			<h2 class="section-title">EXPERIMENT 4: RiskLevelCards</h2>
			<p class="section-description">
				Visual risk level selector. Replaces dense table with clickable cards.
			</p>
		</header>
		<div class="comparison-grid">
			<div class="comparison-column">
				<span class="comparison-label">RAW (no panel)</span>
				<div class="preview-area">
					<div class="component-wrapper" style="max-width: 420px;">
						<RiskLevelCards bind:selected={selectedLevel} onSelect={handleLevelSelect} />
					</div>
				</div>
				<span class="variant-note">Selected: {selectedLevel}</span>
			</div>
			<div class="comparison-column">
				<span class="comparison-label">IN PANEL (Box component)</span>
				<div class="preview-area">
					<div class="component-wrapper" style="max-width: 420px;">
						<Box title="SELECT RISK LEVEL">
							<RiskLevelCards bind:selected={selectedLevel} onSelect={handleLevelSelect} />
						</Box>
					</div>
				</div>
			</div>
		</div>

		<!-- Compact variant -->
		<div class="variants-section">
			<span class="variants-title">COMPACT VARIANT</span>
			<div class="comparison-grid">
				<div class="comparison-column">
					<span class="comparison-label">RAW COMPACT</span>
					<div class="preview-area preview-area-small">
						<div class="component-wrapper" style="max-width: 350px;">
							<RiskLevelCards compact />
						</div>
					</div>
				</div>
				<div class="comparison-column">
					<span class="comparison-label">IN PANEL COMPACT</span>
					<div class="preview-area preview-area-small">
						<div class="component-wrapper" style="max-width: 350px;">
							<Box title="RISK LEVELS">
								<RiskLevelCards compact />
							</Box>
						</div>
					</div>
				</div>
			</div>
		</div>
	</section>

	<!-- Comparison Notes -->
	<Box title="COMPARISON NOTES">
		<div class="notes">
			<div class="note">
				<span class="note-title">RAW vs IN PANEL</span>
				<p class="note-content">
					Raw components have their own borders/backgrounds. In Panel adds the terminal Box wrapper.
					Consider: Do you want double borders? Or should raw components drop their own styling when
					inside a Panel?
				</p>
			</div>
			<div class="note">
				<span class="note-title">SimplifiedHero</span>
				<p class="note-content">
					Best for hero area replacement. The Panel version adds terminal authenticity but may feel
					heavy. Raw version is cleaner but less "GHOSTNET".
				</p>
			</div>
			<div class="note">
				<span class="note-title">QuickPitch</span>
				<p class="note-content">
					Most minimal. Works well both ways. Panel version grounds it in the terminal aesthetic.
				</p>
			</div>
			<div class="note">
				<span class="note-title">BigSteps</span>
				<p class="note-content">
					Good replacement for GettingStartedPanel. Panel version maintains consistency with
					existing UI. Compact variant good for tighter spaces.
				</p>
			</div>
			<div class="note">
				<span class="note-title">RiskLevelCards</span>
				<p class="note-content">
					Visual risk selection. Panel version with "SELECT RISK LEVEL" title provides clear
					context. Consider using in Jack In modal.
				</p>
			</div>
		</div>
	</Box>
</Stack>

<style>
	/* ═══════════════════════════════════════════════════════════════
	   INTRO
	   ═══════════════════════════════════════════════════════════════ */

	.intro {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.intro-description {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		line-height: var(--leading-relaxed);
		margin: 0;
	}

	.intro-note {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-amber);
		margin: 0;
		padding: var(--space-2);
		background: rgba(255, 176, 0, 0.05);
		border: 1px solid rgba(255, 176, 0, 0.2);
	}

	.intro-stats {
		display: flex;
		gap: var(--space-6);
		flex-wrap: wrap;
	}

	.stat {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.stat-label {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wider);
	}

	.stat-value {
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		color: var(--color-accent);
		font-weight: var(--font-bold);
	}

	/* ═══════════════════════════════════════════════════════════════
	   EXPERIMENT SECTION
	   ═══════════════════════════════════════════════════════════════ */

	.experiment-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.section-header {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding: var(--space-4);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-default);
	}

	.section-title {
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-accent);
		letter-spacing: var(--tracking-wider);
		margin: 0;
	}

	.section-description {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		margin: 0;
	}

	/* ═══════════════════════════════════════════════════════════════
	   COMPARISON GRID - Side by side RAW vs PANEL
	   ═══════════════════════════════════════════════════════════════ */

	.comparison-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: var(--space-4);
	}

	.comparison-grid-3 {
		grid-template-columns: repeat(3, 1fr);
	}

	.comparison-column {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.comparison-label {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wider);
		padding: var(--space-2) var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		text-align: center;
	}

	/* ═══════════════════════════════════════════════════════════════
	   PREVIEW AREA - True black background
	   ═══════════════════════════════════════════════════════════════ */

	.preview-area {
		background: var(--color-bg-void);
		padding: var(--space-6);
		border: 1px dashed var(--color-border-subtle);
		min-height: 200px;
		display: flex;
		align-items: flex-start;
		justify-content: center;
	}

	.preview-area-small {
		padding: var(--space-4);
		min-height: 150px;
	}

	/* ═══════════════════════════════════════════════════════════════
	   COMPONENT WRAPPER
	   ═══════════════════════════════════════════════════════════════ */

	.component-wrapper {
		width: 100%;
	}

	/* ═══════════════════════════════════════════════════════════════
	   VARIANTS SECTION
	   ═══════════════════════════════════════════════════════════════ */

	.variants-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		margin-top: var(--space-4);
		padding-top: var(--space-4);
		border-top: 1px solid var(--color-border-subtle);
	}

	.variants-title {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.variant-note {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-accent);
		padding: var(--space-1) var(--space-2);
		background: rgba(0, 229, 204, 0.1);
		border: 1px solid var(--color-accent-dim);
		align-self: flex-start;
	}

	/* ═══════════════════════════════════════════════════════════════
	   NOTES
	   ═══════════════════════════════════════════════════════════════ */

	.notes {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.note {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.note-title {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
	}

	.note-content {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		line-height: var(--leading-relaxed);
		margin: 0;
	}

	/* ═══════════════════════════════════════════════════════════════
	   RESPONSIVE
	   ═══════════════════════════════════════════════════════════════ */

	@media (max-width: 1024px) {
		.comparison-grid {
			grid-template-columns: 1fr;
		}

		.comparison-grid-3 {
			grid-template-columns: 1fr;
		}
	}

	@media (max-width: 768px) {
		.intro-stats {
			flex-direction: column;
			gap: var(--space-3);
		}

		.preview-area {
			padding: var(--space-4);
		}
	}
</style>
