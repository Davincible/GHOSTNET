<script lang="ts">
	import { Panel, Box } from '$lib/ui/terminal';
	import type {
		PanelAttention,
		PanelAmbientEffect,
		PanelEnterAnimation,
		PanelBorderColor,
		PanelVariant,
	} from '$lib/ui/terminal';
	import { Stack, Row } from '$lib/ui/layout';
	import { Button, Badge } from '$lib/ui/primitives';

	// ── Interactive attention demo state ──
	let activeAttention = $state<PanelAttention | null>(null);
	let activeAmbient = $state<PanelAmbientEffect | null>(null);
	let activeEnter = $state<PanelEnterAnimation>('none');
	let activeBorderColor = $state<PanelBorderColor>('default');
	let activeVariant = $state<PanelVariant>('single');
	let activeGlow = $state(false);
	let activeBlur = $state(false);

	// Key to force re-mount for enter animations
	let enterKey = $state(0);

	function triggerAttention(state: PanelAttention) {
		// Clear then set to allow re-triggering same state
		activeAttention = null;
		requestAnimationFrame(() => {
			activeAttention = state;
		});
	}

	function clearAttention() {
		activeAttention = null;
	}

	function toggleAmbient(effect: PanelAmbientEffect) {
		activeAmbient = activeAmbient === effect ? null : effect;
	}

	function replayEnter(animation: PanelEnterAnimation) {
		activeEnter = 'none';
		enterKey++;
		requestAnimationFrame(() => {
			activeEnter = animation;
		});
	}

	// ── Transient attention states for grid demo ──
	let gridAttentionStates = $state<Record<string, PanelAttention | null>>({
		highlight: null,
		alert: null,
		success: null,
		critical: null,
	});

	function fireGridAttention(state: PanelAttention) {
		gridAttentionStates[state] = null;
		requestAnimationFrame(() => {
			gridAttentionStates = { ...gridAttentionStates, [state]: state };
		});
	}

	function clearGridAttention(state: string) {
		gridAttentionStates = { ...gridAttentionStates, [state]: null };
	}
</script>

<Stack gap={6}>
	<!-- ═══════════════════════════════════════════════════════════
	     SECTION: Interactive Playground
	     ═══════════════════════════════════════════════════════════ -->
	<section class="showcase-section">
		<div class="section-header">
			<h2 class="section-title">INTERACTIVE PLAYGROUND</h2>
			<p class="section-subtitle">Configure a live panel instance with all available props</p>
		</div>

		<div class="playground-layout">
			<!-- Live Preview -->
			<div class="playground-preview">
				{#key enterKey}
					<Panel
						title="LIVE PREVIEW"
						variant={activeVariant}
						borderColor={activeBorderColor}
						glow={activeGlow}
						blur={activeBlur}
						attention={activeAttention}
						onAttentionEnd={clearAttention}
						ambientEffect={activeAmbient}
						enterAnimation={activeEnter}
					>
						<div class="preview-content">
							<p class="preview-text">
								SYSTEM ONLINE // MONITORING ACTIVE
							</p>
							<div class="preview-stats">
								<div class="stat">
									<span class="stat-label">OPERATORS</span>
									<span class="stat-value">1,247</span>
								</div>
								<div class="stat">
									<span class="stat-label">TVL</span>
									<span class="stat-value">$847,231</span>
								</div>
								<div class="stat">
									<span class="stat-label">SURVIVAL</span>
									<span class="stat-value">87.3%</span>
								</div>
							</div>
						</div>
					</Panel>
				{/key}
			</div>

			<!-- Controls -->
			<div class="playground-controls">
				<Box title="CONTROLS" padding={2}>
					<Stack gap={3}>
						<!-- Variant -->
						<div class="control-group">
							<span class="control-label">VARIANT</span>
							<Row gap={1} wrap>
								{#each ['single', 'double', 'rounded'] as v (v)}
									<Button
										size="sm"
										variant={activeVariant === v ? 'primary' : 'ghost'}
										onclick={() => (activeVariant = v as PanelVariant)}
									>
										{v.toUpperCase()}
									</Button>
								{/each}
							</Row>
						</div>

						<!-- Border Color -->
						<div class="control-group">
							<span class="control-label">BORDER COLOR</span>
							<Row gap={1} wrap>
								{#each ['default', 'bright', 'dim', 'cyan', 'amber', 'red'] as c (c)}
									<Button
										size="sm"
										variant={activeBorderColor === c ? 'primary' : 'ghost'}
										onclick={() => (activeBorderColor = c as PanelBorderColor)}
									>
										{c.toUpperCase()}
									</Button>
								{/each}
							</Row>
						</div>

						<!-- Glow -->
						<div class="control-group">
							<span class="control-label">GLOW</span>
							<Row gap={1}>
								<Button
									size="sm"
									variant={activeGlow ? 'primary' : 'ghost'}
									onclick={() => (activeGlow = !activeGlow)}
								>
									{activeGlow ? 'ON' : 'OFF'}
								</Button>
							</Row>
						</div>

						<!-- Blur -->
						<div class="control-group">
							<span class="control-label">BLUR</span>
							<Row gap={1}>
								<Button
									size="sm"
									variant={activeBlur ? 'primary' : 'ghost'}
									onclick={() => (activeBlur = !activeBlur)}
								>
									{activeBlur ? 'ON' : 'OFF'}
								</Button>
							</Row>
						</div>

						<!-- Transient Attention -->
						<div class="control-group">
							<span class="control-label">ATTENTION (TRANSIENT)</span>
							<Row gap={1} wrap>
								{#each ['highlight', 'alert', 'success', 'critical'] as a (a)}
									<Button
										size="sm"
										variant="ghost"
										onclick={() => triggerAttention(a as PanelAttention)}
									>
										{a.toUpperCase()}
									</Button>
								{/each}
							</Row>
						</div>

						<!-- Persistent Attention -->
						<div class="control-group">
							<span class="control-label">ATTENTION (PERSISTENT)</span>
							<Row gap={1} wrap>
								{#each ['blackout', 'dimmed', 'focused'] as a (a)}
									<Button
										size="sm"
										variant={activeAttention === a ? 'primary' : 'ghost'}
										onclick={() => {
											activeAttention = activeAttention === a ? null : (a as PanelAttention);
										}}
									>
										{a.toUpperCase()}
									</Button>
								{/each}
								{#if activeAttention === 'blackout' || activeAttention === 'dimmed' || activeAttention === 'focused'}
									<Button size="sm" variant="danger" onclick={clearAttention}>
										CLEAR
									</Button>
								{/if}
							</Row>
						</div>

						<!-- Ambient -->
						<div class="control-group">
							<span class="control-label">AMBIENT EFFECT</span>
							<Row gap={1} wrap>
								{#each ['pulse', 'heartbeat', 'static', 'scan'] as e (e)}
									<Button
										size="sm"
										variant={activeAmbient === e ? 'primary' : 'ghost'}
										onclick={() => toggleAmbient(e as PanelAmbientEffect)}
									>
										{e.toUpperCase()}
									</Button>
								{/each}
							</Row>
						</div>

						<!-- Enter Animation -->
						<div class="control-group">
							<span class="control-label">ENTER ANIMATION</span>
							<Row gap={1} wrap>
								{#each ['boot', 'glitch'] as a (a)}
									<Button
										size="sm"
										variant="ghost"
										onclick={() => replayEnter(a as PanelEnterAnimation)}
									>
										PLAY {a.toUpperCase()}
									</Button>
								{/each}
							</Row>
						</div>
					</Stack>
				</Box>
			</div>
		</div>
	</section>

	<!-- ═══════════════════════════════════════════════════════════
	     SECTION: Attention States Gallery
	     ═══════════════════════════════════════════════════════════ -->
	<section class="showcase-section">
		<div class="section-header">
			<h2 class="section-title">ATTENTION STATES</h2>
			<p class="section-subtitle">Transient states auto-resolve after animation. Persistent states remain until cleared.</p>
		</div>

		<!-- Transient -->
		<div class="subsection">
			<h3 class="subsection-title">
				TRANSIENT
				<Badge variant="info" compact>AUTO-RESOLVE</Badge>
			</h3>
			<div class="demo-grid demo-grid-2">
				{#each [
					{ state: 'highlight', desc: 'Border brightens, subtle brightness pulse', color: 'bright' },
					{ state: 'alert', desc: 'Red border + glow, brightness pulse, red overlay', color: 'red' },
					{ state: 'success', desc: 'Cyan border + glow, brief brightness pulse', color: 'cyan' },
					{ state: 'critical', desc: 'Red border, rapid pulse + panel shake', color: 'red' },
				] as item (item.state)}
					<div class="demo-card">
						<Panel
							title={item.state.toUpperCase()}
							attention={gridAttentionStates[item.state]}
							onAttentionEnd={() => clearGridAttention(item.state)}
						>
							<div class="demo-content">
								<p class="demo-desc">{item.desc}</p>
								<Button
									size="sm"
									variant="ghost"
									onclick={() => fireGridAttention(item.state as PanelAttention)}
								>
									TRIGGER {item.state.toUpperCase()}
								</Button>
							</div>
						</Panel>
					</div>
				{/each}
			</div>
		</div>

		<!-- Persistent -->
		<div class="subsection">
			<h3 class="subsection-title">
				PERSISTENT
				<Badge variant="warning" compact>MANUAL CLEAR</Badge>
			</h3>
			<div class="demo-grid demo-grid-3">
				<div class="demo-card">
					<Panel title="BLACKOUT" attention="blackout">
						<div class="demo-content">
							<p class="demo-desc">Darkened + desaturated. Dead, offline, disconnected.</p>
						</div>
					</Panel>
				</div>
				<div class="demo-card">
					<Panel title="DIMMED" attention="dimmed">
						<div class="demo-content">
							<p class="demo-desc">Opacity 0.5, desaturated. Secondary importance.</p>
						</div>
					</Panel>
				</div>
				<div class="demo-card">
					<Panel title="FOCUSED" attention="focused">
						<div class="demo-content">
							<p class="demo-desc">Slight brightness + scale. Active panel.</p>
						</div>
					</Panel>
				</div>
			</div>
		</div>
	</section>

	<!-- ═══════════════════════════════════════════════════════════
	     SECTION: Ambient Effects
	     ═══════════════════════════════════════════════════════════ -->
	<section class="showcase-section">
		<div class="section-header">
			<h2 class="section-title">AMBIENT EFFECTS</h2>
			<p class="section-subtitle">Persistent visual behaviors that indicate system state. Infinite animations.</p>
		</div>

		<div class="demo-grid demo-grid-2">
			<div class="demo-card">
				<Panel title="PULSE" ambientEffect="pulse">
					<div class="demo-content">
						<p class="demo-desc">Slow brightness breathing, 4s cycle. Panel is alive, active data.</p>
					</div>
				</Panel>
			</div>
			<div class="demo-card">
				<Panel title="HEARTBEAT" ambientEffect="heartbeat">
					<div class="demo-content">
						<p class="demo-desc">Brief brightness spikes at intervals, 2s cycle. Connected and healthy.</p>
					</div>
				</Panel>
			</div>
			<div class="demo-card">
				<Panel title="STATIC" ambientEffect="static">
					<div class="demo-content">
						<p class="demo-desc">Faint TV noise pattern overlay. Degraded connection, stale data.</p>
					</div>
				</Panel>
			</div>
			<div class="demo-card">
				<Panel title="SCAN" ambientEffect="scan">
					<div class="demo-content">
						<p class="demo-desc">Horizontal line sweeps down, 3s cycle. Monitoring mode.</p>
					</div>
				</Panel>
			</div>
		</div>
	</section>

	<!-- ═══════════════════════════════════════════════════════════
	     SECTION: Enter Animations
	     ═══════════════════════════════════════════════════════════ -->
	<section class="showcase-section">
		<div class="section-header">
			<h2 class="section-title">ENTER ANIMATIONS</h2>
			<p class="section-subtitle">How panels appear in the viewport. Plays once on mount.</p>
		</div>

		<div class="demo-grid demo-grid-2">
			{#each [
				{ animation: 'boot', desc: 'CRT power-on: panel expands from horizontal line via clip-path, content fades in.' },
				{ animation: 'glitch', desc: 'Brief clip-path displacement + hue-rotate, then resolves to normal.' },
			] as item (item.animation)}
				{@const key = `enter-${item.animation}-${enterKey}`}
				<div class="demo-card">
					{#key key}
						<Panel
							title={item.animation.toUpperCase()}
							enterAnimation={item.animation as PanelEnterAnimation}
						>
							<div class="demo-content">
								<p class="demo-desc">{item.desc}</p>
								<Button
									size="sm"
									variant="ghost"
									onclick={() => replayEnter(item.animation as PanelEnterAnimation)}
								>
									REPLAY
								</Button>
							</div>
						</Panel>
					{/key}
				</div>
			{/each}
		</div>
	</section>

	<!-- ═══════════════════════════════════════════════════════════
	     SECTION: Border Variants
	     ═══════════════════════════════════════════════════════════ -->
	<section class="showcase-section">
		<div class="section-header">
			<h2 class="section-title">BORDER VARIANTS</h2>
			<p class="section-subtitle">Box drawing styles and color options from the existing Panel API.</p>
		</div>

		<!-- Variants -->
		<div class="subsection">
			<h3 class="subsection-title">DRAW STYLE</h3>
			<div class="demo-grid demo-grid-3">
				{#each ['single', 'double', 'rounded'] as v (v)}
					<div class="demo-card">
						<Panel title={v.toUpperCase()} variant={v as PanelVariant}>
							<p class="demo-desc">{v} line box-drawing characters</p>
						</Panel>
					</div>
				{/each}
			</div>
		</div>

		<!-- Colors -->
		<div class="subsection">
			<h3 class="subsection-title">BORDER COLORS</h3>
			<div class="demo-grid demo-grid-3">
				{#each ['default', 'bright', 'dim', 'cyan', 'amber', 'red'] as c (c)}
					<div class="demo-card">
						<Panel title={c.toUpperCase()} borderColor={c as PanelBorderColor}>
							<p class="demo-desc">borderColor="{c}"</p>
						</Panel>
					</div>
				{/each}
			</div>
		</div>

		<!-- Glow -->
		<div class="subsection">
			<h3 class="subsection-title">GLOW EFFECT</h3>
			<div class="demo-grid demo-grid-2">
				<div class="demo-card">
					<Panel title="NO GLOW" borderColor="cyan">
						<p class="demo-desc">glow=false (default)</p>
					</Panel>
				</div>
				<div class="demo-card">
					<Panel title="WITH GLOW" borderColor="cyan" glow>
						<p class="demo-desc">glow=true &mdash; text-shadow on border characters</p>
					</Panel>
				</div>
			</div>
		</div>
	</section>

	<!-- ═══════════════════════════════════════════════════════════
	     SECTION: Blur
	     ═══════════════════════════════════════════════════════════ -->
	<section class="showcase-section">
		<div class="section-header">
			<h2 class="section-title">BLUR</h2>
			<p class="section-subtitle">Standalone boolean prop. Uses backdrop-filter so it composes freely with any attention state or ambient effect.</p>
		</div>

		<div class="demo-grid demo-grid-2">
			<div class="demo-card">
				<Panel title="BLUR ONLY" blur>
					<div class="demo-content">
						<p class="demo-desc">blur=true alone. Content visible but frosted. Disables text selection.</p>
					</div>
				</Panel>
			</div>
			<div class="demo-card">
				<Panel title="DIMMED + BLUR" attention="dimmed" blur>
					<div class="demo-content">
						<p class="demo-desc">Coming soon / unavailable. Dimmed + blurred = clearly inaccessible.</p>
					</div>
				</Panel>
			</div>
			<div class="demo-card">
				<Panel title="BLACKOUT + BLUR" attention="blackout" blur>
					<div class="demo-content">
						<p class="demo-desc">Locked out. Darkened + blurred = hard to read, but shape still visible.</p>
					</div>
				</Panel>
			</div>
			<div class="demo-card">
				<Panel title="NORMAL (NO BLUR)" >
					<div class="demo-content">
						<p class="demo-desc">blur=false (default). Clear, crisp content.</p>
					</div>
				</Panel>
			</div>
		</div>
	</section>

	<!-- ═══════════════════════════════════════════════════════════
	     SECTION: Composition
	     ═══════════════════════════════════════════════════════════ -->
	<section class="showcase-section">
		<div class="section-header">
			<h2 class="section-title">COMPOSITION</h2>
			<p class="section-subtitle">Effects compose orthogonally. A panel can simultaneously have an ambient effect, attention state, blur, and border style.</p>
		</div>

		<div class="demo-grid demo-grid-2">
			<div class="demo-card">
				<Panel
					title="LIVE + PULSE"
					borderColor="cyan"
					glow
					ambientEffect="pulse"
				>
					<div class="demo-content">
						<p class="demo-desc">Cyan border with glow + pulse ambient. A healthy, active panel.</p>
					</div>
				</Panel>
			</div>
			<div class="demo-card">
				<Panel
					title="DEGRADED + STATIC"
					borderColor="amber"
					ambientEffect="static"
				>
					<div class="demo-content">
						<p class="demo-desc">Amber border + static overlay. Connection issues.</p>
					</div>
				</Panel>
			</div>
			<div class="demo-card">
				<Panel
					title="MONITORING + SCAN"
					variant="double"
					borderColor="bright"
					ambientEffect="scan"
				>
					<div class="demo-content">
						<p class="demo-desc">Double border + scan sweep. Active surveillance.</p>
					</div>
				</Panel>
			</div>
			<div class="demo-card">
				<Panel
					title="VITAL + HEARTBEAT"
					borderColor="bright"
					glow
					ambientEffect="heartbeat"
				>
					<div class="demo-content">
						<p class="demo-desc">Bright border with glow + heartbeat. Core system vital.</p>
					</div>
				</Panel>
			</div>
		</div>
	</section>

	<!-- ═══════════════════════════════════════════════════════════
	     SECTION: Scrollable
	     ═══════════════════════════════════════════════════════════ -->
	<section class="showcase-section">
		<div class="section-header">
			<h2 class="section-title">SCROLLABLE PANELS</h2>
			<p class="section-subtitle">Content overflow handling with scroll indicators.</p>
		</div>

		<div class="demo-grid demo-grid-2">
			<div class="demo-card">
				<Panel title="SCROLLABLE" scrollable maxHeight="200px">
					{#each Array(20) as _, i (i)}
						<div class="log-line">
							<span class="log-time">[{String(i).padStart(2, '0')}:00:00]</span>
							<span class="log-msg">System event #{i + 1} logged</span>
						</div>
					{/each}
				</Panel>
			</div>
			<div class="demo-card">
				<Panel title="NON-SCROLLABLE (DEFAULT)">
					<div class="demo-content">
						<p class="demo-desc">Content renders at natural height. No overflow handling.</p>
					</div>
				</Panel>
			</div>
		</div>
	</section>
</Stack>

<style>
	/* ── Section Structure ── */

	.showcase-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.section-header {
		border-bottom: 1px solid var(--color-border-subtle);
		padding-bottom: var(--space-3);
	}

	.section-title {
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-accent);
		letter-spacing: var(--tracking-widest);
		margin: 0 0 var(--space-1);
	}

	.section-subtitle {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wide);
		margin: 0;
		line-height: var(--leading-relaxed);
	}

	.subsection {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.subsection-title {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		color: var(--color-text-secondary);
		letter-spacing: var(--tracking-wider);
		margin: 0;
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	/* ── Demo Grid ── */

	.demo-grid {
		display: grid;
		gap: var(--space-3);
	}

	.demo-grid-2 {
		grid-template-columns: repeat(2, 1fr);
	}

	.demo-grid-3 {
		grid-template-columns: repeat(3, 1fr);
	}

	.demo-card {
		min-width: 0;
	}

	.demo-content {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.demo-desc {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		line-height: var(--leading-relaxed);
		margin: 0;
	}

	/* ── Playground ── */

	.playground-layout {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: var(--space-4);
		align-items: start;
	}

	.playground-preview {
		position: sticky;
		top: var(--space-4);
	}

	.preview-content {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.preview-text {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-accent-dim);
		letter-spacing: var(--tracking-wider);
		margin: 0;
	}

	.preview-stats {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-2);
	}

	.stat {
		display: flex;
		flex-direction: column;
		gap: var(--space-0-5);
	}

	.stat-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.stat-value {
		font-size: var(--text-base);
		color: var(--color-text-primary);
		font-weight: var(--font-medium);
	}

	.playground-controls {
		max-height: 80vh;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: var(--color-border-strong) var(--color-bg-tertiary);
	}

	.control-group {
		display: flex;
		flex-direction: column;
		gap: var(--space-1-5);
	}

	.control-label {
		font-family: var(--font-mono);
		font-size: 0.5625rem;
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-widest);
	}

	/* ── Log Lines (scrollable demo) ── */

	.log-line {
		display: flex;
		gap: var(--space-2);
		padding: var(--space-0-5) 0;
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.log-time {
		color: var(--color-text-muted);
		flex-shrink: 0;
	}

	.log-msg {
		color: var(--color-text-tertiary);
	}

	/* ── Responsive ── */

	@media (max-width: 900px) {
		.playground-layout {
			grid-template-columns: 1fr;
		}

		.playground-preview {
			position: static;
		}

		.demo-grid-2 {
			grid-template-columns: 1fr;
		}

		.demo-grid-3 {
			grid-template-columns: 1fr;
		}
	}

	@media (min-width: 901px) and (max-width: 1200px) {
		.demo-grid-3 {
			grid-template-columns: repeat(2, 1fr);
		}
	}
</style>
