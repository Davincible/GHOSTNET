<script lang="ts">
	import { Panel, Box } from '$lib/ui/terminal';
	import { Stack, Row } from '$lib/ui/layout';
	import { Button, Badge } from '$lib/ui/primitives';
	import { MatrixRain, MatrixRainLegacy } from '$lib/features/welcome';

	// ═══════════════════════════════════════════════════════════════════════════
	// CORE PARAMETERS (with legacy prop names for comparison)
	// ═══════════════════════════════════════════════════════════════════════════

	// Legacy props (passed to both implementations)
	let columns = $state(20);
	let baseSpeed = $state(2);
	let trailOpacity = $state(0.7);

	// New refactored-only props
	let mode = $state<'smooth' | 'grid'>('grid');
	let gridStep = $state(1);
	let trailLength = $state(20);
	let trailLengthVariance = $state(0.5);
	let generationMultiplier = $state(1);
	let fadeRate = $state(0.05);
	let brightHead = $state(true);
	let glow = $state(true);
	let glowRadius = $state(10);
	let headOpacity = $state(1.0);
	let headColor = $state('#ffffff');
	let color = $state('#00ff41');
	let mutationRate = $state(1.0);
	let headMutationRate = $state(1.0);
	let targetFps = $state(60);

	// ═══════════════════════════════════════════════════════════════════════════
	// PRESETS
	// ═══════════════════════════════════════════════════════════════════════════

	type PresetName = 'subtle' | 'classic' | 'intense' | 'retro' | 'neon' | 'stealth';

	interface PresetConfig {
		mode: 'smooth' | 'grid';
		gridStep: number;
		columns: number;
		baseSpeed: number;
		trailOpacity: number;
		trailLength: number;
		trailLengthVariance: number;
		generationMultiplier: number;
		fadeRate: number;
		brightHead: boolean;
		glow: boolean;
		glowRadius: number;
		headOpacity: number;
		headColor: string;
		color: string;
		mutationRate: number;
		headMutationRate: number;
	}

	const presets: Record<PresetName, PresetConfig> = {
		subtle: {
			mode: 'smooth',
			gridStep: 0.5,
			columns: 15,
			baseSpeed: 1.5,
			trailOpacity: 0.4,
			trailLength: 16,
			trailLengthVariance: 0.3,
			generationMultiplier: 1,
			fadeRate: 0.05,
			brightHead: false,
			glow: false,
			glowRadius: 6,
			headOpacity: 0.8,
			headColor: '#88ffcc',
			color: '#00e5cc',
			mutationRate: 0.02,
			headMutationRate: 0.08,
		},
		classic: {
			mode: 'smooth',
			gridStep: 0.5,
			columns: 25,
			baseSpeed: 2,
			trailOpacity: 0.7,
			trailLength: 20,
			trailLengthVariance: 0.5,
			generationMultiplier: 1,
			fadeRate: 0.05,
			brightHead: true,
			glow: true,
			glowRadius: 10,
			headOpacity: 1.0,
			headColor: '#ffffff',
			color: '#00ff41',
			mutationRate: 0.03,
			headMutationRate: 0.12,
		},
		intense: {
			mode: 'smooth',
			gridStep: 0.5,
			columns: 35,
			baseSpeed: 3,
			trailOpacity: 0.85,
			trailLength: 28,
			trailLengthVariance: 0.7,
			generationMultiplier: 1,
			fadeRate: 0.04,
			brightHead: true,
			glow: true,
			glowRadius: 14,
			headOpacity: 1.0,
			headColor: '#ffffff',
			color: '#00ff41',
			mutationRate: 0.05,
			headMutationRate: 0.18,
		},
		retro: {
			mode: 'grid',
			gridStep: 1,
			columns: 20,
			baseSpeed: 3,
			trailOpacity: 0.8,
			trailLength: 16,
			trailLengthVariance: 0.5,
			generationMultiplier: 1.2,
			fadeRate: 0.06,
			brightHead: true,
			glow: false,
			glowRadius: 6,
			headOpacity: 1.0,
			headColor: '#00ff00',
			color: '#00aa00',
			mutationRate: 1.0,
			headMutationRate: 1.0,
		},
		neon: {
			mode: 'smooth',
			gridStep: 0.5,
			columns: 20,
			baseSpeed: 2.5,
			trailOpacity: 0.9,
			trailLength: 24,
			trailLengthVariance: 0.6,
			generationMultiplier: 1,
			fadeRate: 0.04,
			brightHead: true,
			glow: true,
			glowRadius: 18,
			headOpacity: 1.0,
			headColor: '#ff00ff',
			color: '#00ffff',
			mutationRate: 0.04,
			headMutationRate: 0.15,
		},
		stealth: {
			mode: 'smooth',
			gridStep: 0.5,
			columns: 12,
			baseSpeed: 1,
			trailOpacity: 0.25,
			trailLength: 12,
			trailLengthVariance: 0.2,
			generationMultiplier: 0.9,
			fadeRate: 0.06,
			brightHead: false,
			glow: false,
			glowRadius: 4,
			headOpacity: 0.5,
			headColor: '#66aa88',
			color: '#335544',
			mutationRate: 0.01,
			headMutationRate: 0.04,
		},
	};

	let activePreset = $state<PresetName | null>(null);

	function applyPreset(name: PresetName) {
		const p = presets[name];
		mode = p.mode;
		gridStep = p.gridStep;
		columns = p.columns;
		baseSpeed = p.baseSpeed;
		trailOpacity = p.trailOpacity;
		trailLength = p.trailLength;
		trailLengthVariance = p.trailLengthVariance;
		generationMultiplier = p.generationMultiplier;
		fadeRate = p.fadeRate;
		brightHead = p.brightHead;
		glow = p.glow;
		glowRadius = p.glowRadius;
		headOpacity = p.headOpacity;
		headColor = p.headColor;
		color = p.color;
		mutationRate = p.mutationRate;
		headMutationRate = p.headMutationRate;
		activePreset = name;
	}

	// Clear preset when manually adjusting
	function clearPreset() {
		activePreset = null;
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// COMPARISON KEYS
	// ═══════════════════════════════════════════════════════════════════════════

	let legacyKey = $state(0);
	let refactorKey = $state(0);

	function restartLegacy() {
		legacyKey++;
	}

	function restartRefactor() {
		refactorKey++;
	}

	function restartBoth() {
		legacyKey++;
		refactorKey++;
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// COPY SETTINGS
	// ═══════════════════════════════════════════════════════════════════════════

	let copied = $state(false);

	async function copySettings() {
		const code = `<MatrixRain
  mode="${mode}"
  gridStep={${gridStep}}
  columns={${columns}}
  baseSpeed={${baseSpeed}}
  trailOpacity={${trailOpacity}}
  trailLength={${trailLength}}
  generationMultiplier={${generationMultiplier}}
  fadeRate={${fadeRate}}
  brightHead={${brightHead}}
  glow={${glow}}
  glowRadius={${glowRadius}}
  headOpacity={${headOpacity}}
  headColor="${headColor}"
  color="${color}"
  mutationRate={${mutationRate}}
  headMutationRate={${headMutationRate}}
  targetFps={${targetFps}}
/>`;
		await navigator.clipboard.writeText(code);
		copied = true;
		setTimeout(() => {
			copied = false;
		}, 2000);
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// ADVANCED PANEL STATE
	// ═══════════════════════════════════════════════════════════════════════════

	let showAdvanced = $state(false);
</script>

<svelte:head>
	<title>Effects Showcase | GHOSTNET Dev</title>
</svelte:head>

<Stack gap={6}>
	<!-- ═══════════════════════════════════════════════════════════
	     STATUS
	     ═══════════════════════════════════════════════════════════ -->
	<Box title="MATRIX RAIN // REFACTORED">
		<div class="status-grid">
			<div class="status-item">
				<span class="status-label">MODE</span>
				<span class="status-value" class:status-grid-mode={mode === 'grid'}>
					{mode.toUpperCase()}
				</span>
			</div>
			<div class="status-item">
				<span class="status-label">COLUMNS</span>
				<span class="status-value">{columns}</span>
			</div>
			<div class="status-item">
				<span class="status-label">SPEED</span>
				<span class="status-value">{baseSpeed.toFixed(1)} px/f</span>
			</div>
			<div class="status-item">
				<span class="status-label">TRAIL</span>
				<span class="status-value">{trailLength} glyphs</span>
			</div>
			<div class="status-item">
				<span class="status-label">GLOW</span>
				<span class="status-value" class:status-online={glow}>{glow ? 'ON' : 'OFF'}</span>
			</div>
			<div class="status-item">
				<span class="status-label">PRESET</span>
				<span class="status-value" class:status-online={activePreset}>
					{activePreset?.toUpperCase() ?? 'CUSTOM'}
				</span>
			</div>
		</div>
	</Box>

	<!-- ═══════════════════════════════════════════════════════════
	     PRESETS
	     ═══════════════════════════════════════════════════════════ -->
	<section class="showcase-section">
		<div class="section-header">
			<div class="section-header-row">
				<h2 class="section-title">PRESETS</h2>
				<Row gap={1}>
					<Button size="sm" variant={copied ? 'primary' : 'ghost'} onclick={copySettings}>
						{copied ? 'COPIED!' : 'COPY CODE'}
					</Button>
					<Button size="sm" variant="ghost" onclick={restartBoth}>RESTART</Button>
				</Row>
			</div>
			<p class="section-subtitle">Quick configuration presets for common use cases.</p>
		</div>

		<Row gap={2} wrap>
			{#each Object.keys(presets) as preset (preset)}
				<Button
					size="sm"
					variant={activePreset === preset ? 'primary' : 'ghost'}
					onclick={() => applyPreset(preset as PresetName)}
				>
					{preset.toUpperCase()}
				</Button>
			{/each}
		</Row>
	</section>

	<!-- ═══════════════════════════════════════════════════════════
	     PARAMETERS
	     ═══════════════════════════════════════════════════════════ -->
	<section class="showcase-section">
		<div class="section-header">
			<h2 class="section-title">PARAMETERS</h2>
			<p class="section-subtitle">Configure the Matrix Rain effect in real-time.</p>
		</div>

		<div class="controls-layout">
			<!-- Core Controls -->
			<div class="sliders-grid">
				<!-- Mode Toggle -->
				<div class="control-group">
					<div class="control-header">
						<span class="control-label">MODE</span>
						<span class="control-value">{mode.toUpperCase()}</span>
					</div>
					<Row gap={1}>
						<Button
							size="sm"
							variant={mode === 'smooth' ? 'primary' : 'ghost'}
							onclick={() => {
								mode = 'smooth';
								clearPreset();
							}}
						>
							SMOOTH
						</Button>
						<Button
							size="sm"
							variant={mode === 'grid' ? 'primary' : 'ghost'}
							onclick={() => {
								mode = 'grid';
								clearPreset();
							}}
						>
							GRID
						</Button>
					</Row>
					<span class="control-hint">Smooth pixels vs cell-based stepping</span>
				</div>

				<!-- Grid Step (only enabled in grid mode) -->
				<div class="control-group">
					<div class="control-header">
						<span class="control-label">GRID STEP</span>
						<span class="control-value">{gridStep.toFixed(2)}</span>
					</div>
					<input
						type="range"
						class="slider"
						min="0.25"
						max="1"
						step="0.25"
						bind:value={gridStep}
						oninput={clearPreset}
						disabled={mode !== 'grid'}
					/>
					<span class="control-hint">Step size as fraction of cell height</span>
				</div>

				<div class="control-group">
					<div class="control-header">
						<span class="control-label">COLUMNS</span>
						<span class="control-value">{columns}</span>
					</div>
					<input
						type="range"
						class="slider"
						min="8"
						max="50"
						step="1"
						bind:value={columns}
						oninput={clearPreset}
					/>
					<span class="control-hint">Number of rain columns</span>
				</div>

				<div class="control-group">
					<div class="control-header">
						<span class="control-label">SPEED</span>
						<span class="control-value">{baseSpeed.toFixed(1)}</span>
					</div>
					<input
						type="range"
						class="slider"
						min="0.5"
						max="20"
						step="0.5"
						bind:value={baseSpeed}
						oninput={clearPreset}
					/>
					<span class="control-hint">Fall speed in pixels per frame</span>
				</div>

				<div class="control-group">
					<div class="control-header">
						<span class="control-label">TRAIL LENGTH</span>
						<span class="control-value">{trailLength}</span>
					</div>
					<input
						type="range"
						class="slider"
						min="4"
						max="80"
						step="1"
						bind:value={trailLength}
						oninput={clearPreset}
					/>
					<span class="control-hint">Base glyphs per trail</span>
				</div>

				<div class="control-group">
					<div class="control-header">
						<span class="control-label">LENGTH VARIANCE</span>
						<span class="control-value">{(trailLengthVariance * 100).toFixed(0)}%</span>
					</div>
					<input
						type="range"
						class="slider"
						min="0"
						max="1"
						step="0.05"
						bind:value={trailLengthVariance}
						oninput={clearPreset}
					/>
					<span class="control-hint">0% = uniform, 100% = 50%-150% range</span>
				</div>

				<div class="control-group">
					<div class="control-header">
						<span class="control-label">GEN MULTIPLIER</span>
						<span class="control-value">{generationMultiplier.toFixed(1)}x</span>
					</div>
					<input
						type="range"
						class="slider"
						min="0.01"
						max="3"
						step="0.01"
						bind:value={generationMultiplier}
						oninput={clearPreset}
					/>
					<span class="control-hint"
						>Stream density multiplier (higher = more concurrent streams)</span
					>
				</div>

				<div class="control-group">
					<div class="control-header">
						<span class="control-label">TRAIL OPACITY</span>
						<span class="control-value">{(trailOpacity * 100).toFixed(0)}%</span>
					</div>
					<input
						type="range"
						class="slider"
						min="0.1"
						max="1"
						step="0.05"
						bind:value={trailOpacity}
						oninput={clearPreset}
					/>
					<span class="control-hint">Visibility of trail characters</span>
				</div>

				<!-- Color Settings Group -->
				<div class="control-group color-group">
					<span class="control-label">COLORS</span>
					<div class="color-settings">
						<div class="color-setting">
							<span class="color-setting-label">TRAIL</span>
							<input type="color" class="color-picker" bind:value={color} oninput={clearPreset} />
						</div>
						<div class="color-setting">
							<span class="color-setting-label">HEAD</span>
							<Row gap={1}>
								<input
									type="color"
									class="color-picker"
									bind:value={headColor}
									oninput={clearPreset}
									disabled={!brightHead}
								/>
								<Button
									size="sm"
									variant={brightHead ? 'primary' : 'ghost'}
									onclick={() => {
										brightHead = !brightHead;
										clearPreset();
									}}
								>
									{brightHead ? 'ON' : 'OFF'}
								</Button>
							</Row>
						</div>
					</div>
					<span class="control-hint">Trail color and optional bright head</span>
				</div>
			</div>

			<!-- Advanced Toggle -->
			<button type="button" class="advanced-toggle" onclick={() => (showAdvanced = !showAdvanced)}>
				<span class="advanced-toggle-icon">{showAdvanced ? '▼' : '▶'}</span>
				<span class="advanced-toggle-label">ADVANCED</span>
			</button>

			<!-- Advanced Controls (collapsible) -->
			{#if showAdvanced}
				<div class="sliders-grid">
					<div class="control-group">
						<div class="control-header">
							<span class="control-label">GLOW</span>
							<span class="control-value">{glow ? 'ON' : 'OFF'}</span>
						</div>
						<Row gap={1}>
							<Button
								size="sm"
								variant={glow ? 'primary' : 'ghost'}
								onclick={() => {
									glow = true;
									clearPreset();
								}}
							>
								ON
							</Button>
							<Button
								size="sm"
								variant={!glow ? 'primary' : 'ghost'}
								onclick={() => {
									glow = false;
									clearPreset();
								}}
							>
								OFF
							</Button>
						</Row>
						<span class="control-hint">Head character bloom effect</span>
					</div>

					<div class="control-group">
						<div class="control-header">
							<span class="control-label">GLOW RADIUS</span>
							<span class="control-value">{glowRadius}px</span>
						</div>
						<input
							type="range"
							class="slider"
							min="4"
							max="24"
							step="1"
							bind:value={glowRadius}
							oninput={clearPreset}
							disabled={!glow}
						/>
						<span class="control-hint">Bloom blur radius</span>
					</div>

					<div class="control-group">
						<div class="control-header">
							<span class="control-label">HEAD OPACITY</span>
							<span class="control-value">{(headOpacity * 100).toFixed(0)}%</span>
						</div>
						<input
							type="range"
							class="slider"
							min="0.3"
							max="1"
							step="0.05"
							bind:value={headOpacity}
							oninput={clearPreset}
						/>
						<span class="control-hint">Brightness of leading character</span>
					</div>

					<div class="control-group">
						<div class="control-header">
							<span class="control-label">FADE RATE</span>
							<span class="control-value">{fadeRate.toFixed(2)}</span>
						</div>
						<input
							type="range"
							class="slider"
							min="0.01"
							max="0.15"
							step="0.01"
							bind:value={fadeRate}
							oninput={clearPreset}
						/>
						<span class="control-hint"
							>{mode === 'grid' ? 'Not used (position gradient)' : 'Alpha decay per frame'}</span
						>
					</div>

					<div class="control-group">
						<div class="control-header">
							<span class="control-label">MUTATION RATE</span>
							<span class="control-value">{(mutationRate * 100).toFixed(0)}%</span>
						</div>
						<input
							type="range"
							class="slider"
							min="0"
							max="1"
							step="0.05"
							bind:value={mutationRate}
							oninput={clearPreset}
						/>
						<span class="control-hint"
							>{mode === 'grid' ? 'Trail change % per step' : 'Trail change % per frame'}</span
						>
					</div>

					<div class="control-group">
						<div class="control-header">
							<span class="control-label">HEAD MUTATION</span>
							<span class="control-value">{(headMutationRate * 100).toFixed(0)}%</span>
						</div>
						<input
							type="range"
							class="slider"
							min="0"
							max="1"
							step="0.05"
							bind:value={headMutationRate}
							oninput={clearPreset}
						/>
						<span class="control-hint"
							>{mode === 'grid' ? 'Head change % per step' : 'Head change % per frame'}</span
						>
					</div>

					<div class="control-group">
						<div class="control-header">
							<span class="control-label">TARGET FPS</span>
							<span class="control-value">{targetFps}</span>
						</div>
						<input
							type="range"
							class="slider"
							min="15"
							max="60"
							step="5"
							bind:value={targetFps}
							oninput={clearPreset}
						/>
						<span class="control-hint">Frame rate limit (perf tuning)</span>
					</div>
				</div>
			{/if}
		</div>
	</section>

	<!-- ═══════════════════════════════════════════════════════════
	     IMPLEMENTATION COMPARISON
	     ═══════════════════════════════════════════════════════════ -->
	<section class="showcase-section">
		<div class="section-header">
			<h2 class="section-title">IMPLEMENTATION COMPARISON</h2>
			<p class="section-subtitle">
				Legacy uses overlay-fade hack. Refactored uses proper trail simulation with head glow.
			</p>
		</div>

		<div class="comparison-grid">
			<!-- Legacy -->
			<div class="demo-card">
				<Panel title="LEGACY" borderColor="amber">
					<div class="demo-content">
						<div class="panel-header-row">
							<Badge variant="warning" compact>DEPRECATED</Badge>
							<Button size="sm" variant="ghost" onclick={restartLegacy}>RESTART</Button>
						</div>
						<div class="demo-preview">
							{#key legacyKey}
								<MatrixRainLegacy
									density={columns}
									speed={baseSpeed / 2}
									opacity={trailOpacity / 2.5}
								/>
							{/key}
						</div>
						<p class="demo-desc">
							Overlay-fade technique. Single character per column, no trail simulation. Does not
							support glow, head brightness, or advanced configuration.
						</p>
					</div>
				</Panel>
			</div>

			<!-- Refactored -->
			<div class="demo-card">
				<Panel title="REFACTORED" borderColor="cyan" glow>
					<div class="demo-content">
						<div class="panel-header-row">
							<Badge variant="success" compact>CURRENT</Badge>
							<Button size="sm" variant="ghost" onclick={restartRefactor}>RESTART</Button>
						</div>
						<div class="demo-preview">
							{#key refactorKey}
								<MatrixRain
									{mode}
									{gridStep}
									{columns}
									{baseSpeed}
									{trailOpacity}
									{trailLength}
									{trailLengthVariance}
									{generationMultiplier}
									{fadeRate}
									{brightHead}
									{glow}
									{glowRadius}
									{headOpacity}
									{headColor}
									{color}
									{mutationRate}
									{headMutationRate}
									{targetFps}
								/>
							{/key}
						</div>
						<p class="demo-desc">
							Trail-based simulation with ring buffer optimization. Bright head glyph with
							configurable glow, separate mutation rates, frame limiting, and visibility pause.
						</p>
					</div>
				</Panel>
			</div>
		</div>
	</section>

	<!-- ═══════════════════════════════════════════════════════════
	     NOTES
	     ═══════════════════════════════════════════════════════════ -->
	<Box title="IMPLEMENTATION NOTES">
		<div class="notes">
			<div class="note">
				<span class="note-title">New Features (Refactored)</span>
				<p class="note-content">
					<strong>Head Glow:</strong> The leading character uses canvas <code>shadowBlur</code> for
					authentic CRT bloom. <strong>Bright Head:</strong> Head glyph is rendered at full opacity
					with configurable color. <strong>Separate Mutation Rates:</strong> Head and trail
					characters mutate at different frequencies. <strong>Movement Modes:</strong> SMOOTH mode uses
					fluid pixel movement with random per-frame mutations. GRID mode uses cell-based stepping with
					synchronized mutations—all characters change together on each step for authentic terminal feel.
				</p>
			</div>
			<div class="note">
				<span class="note-title">Performance Optimizations</span>
				<p class="note-content">
					<strong>Ring Buffer:</strong> Trails use fixed-size arrays with head/count pointers
					instead of array mutations. <strong>Frame Limiting:</strong> Configurable FPS cap (default
					30fps).
					<strong>Visibility Pause:</strong> Animation pauses when tab is hidden.
					<strong>HiDPI:</strong> Uses devicePixelRatio for crisp retina rendering.
				</p>
			</div>
			<div class="note">
				<span class="note-title">Backward Compatibility</span>
				<p class="note-content">
					Legacy props (<code>density</code>, <code>speed</code>, <code>opacity</code>) are still
					supported and automatically mapped to the new prop names. Existing usage will continue to
					work without changes.
				</p>
			</div>
			<div class="note">
				<span class="note-title">Recommended Presets</span>
				<p class="note-content">
					<strong>SUBTLE:</strong> Background ambiance, minimal distraction.
					<strong>CLASSIC:</strong> Balanced Matrix look for most use cases.
					<strong>RETRO:</strong> Grid mode with full-cell stepping for terminal authenticity.
					<strong>STEALTH:</strong> Ultra-dim for text-heavy pages.
					<strong>NEON:</strong> Cyberpunk aesthetic with color variation.
				</p>
			</div>
		</div>
	</Box>
</Stack>

<style>
	/* ── Status Grid ── */

	.status-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-3);
	}

	.status-item {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.status-label {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.status-value {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
	}

	.status-online {
		color: var(--color-accent);
	}

	.status-grid-mode {
		color: var(--color-amber);
	}

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

	.section-header-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: var(--space-1);
	}

	.section-title {
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-accent);
		letter-spacing: var(--tracking-widest);
		margin: 0;
	}

	.section-subtitle {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wide);
		margin: 0;
		line-height: var(--leading-relaxed);
	}

	/* ── Controls ── */

	.controls-layout {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		padding: var(--space-4);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-default);
	}

	.sliders-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-4);
	}

	.control-group {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.control-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.control-label {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-widest);
	}

	.control-value {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-accent);
		font-weight: var(--font-medium);
	}

	.control-hint {
		font-family: var(--font-mono);
		font-size: 0.5625rem;
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wide);
	}

	/* ── Advanced Toggle ── */

	.advanced-toggle {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-1) 0;
		background: none;
		border: none;
		cursor: pointer;
		width: fit-content;
		text-align: left;
	}

	.advanced-toggle:hover .advanced-toggle-label {
		color: var(--color-text-secondary);
	}

	.advanced-toggle:hover .advanced-toggle-icon {
		color: var(--color-accent);
	}

	.advanced-toggle-icon {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-accent-dim);
		transition: color var(--duration-fast) var(--ease-default);
	}

	.advanced-toggle-label {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-widest);
		transition: color var(--duration-fast) var(--ease-default);
	}

	/* ── Slider Styling ── */

	.slider {
		-webkit-appearance: none;
		appearance: none;
		width: 100%;
		height: 4px;
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-default);
		outline: none;
		cursor: pointer;
	}

	.slider:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.slider::-webkit-slider-thumb {
		-webkit-appearance: none;
		appearance: none;
		width: 12px;
		height: 12px;
		background: var(--color-accent);
		border: none;
		cursor: pointer;
	}

	.slider::-moz-range-thumb {
		width: 12px;
		height: 12px;
		background: var(--color-accent);
		border: none;
		cursor: pointer;
	}

	.slider:hover:not(:disabled)::-webkit-slider-thumb {
		background: var(--color-accent-bright);
	}

	.slider:hover:not(:disabled)::-moz-range-thumb {
		background: var(--color-accent-bright);
	}

	/* ── Color Settings ── */

	.color-group {
		grid-column: span 2;
	}

	.color-settings {
		display: flex;
		gap: var(--space-6);
	}

	.color-setting {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.color-setting-label {
		font-family: var(--font-mono);
		font-size: 0.5625rem;
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wider);
		min-width: 3ch;
	}

	.color-picker {
		-webkit-appearance: none;
		appearance: none;
		width: 28px;
		height: 20px;
		border: 1px solid var(--color-border-default);
		background: none;
		cursor: pointer;
		padding: 0;
	}

	.color-picker:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.color-picker::-webkit-color-swatch-wrapper {
		padding: 0;
	}

	.color-picker::-webkit-color-swatch {
		border: none;
	}

	/* ── Comparison Grid ── */

	.comparison-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: var(--space-4);
	}

	.demo-card {
		min-width: 0;
	}

	.demo-content {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.panel-header-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.demo-preview {
		position: relative;
		height: 320px;
		background: var(--color-bg-void);
		border: 1px solid var(--color-border-subtle);
		overflow: hidden;
	}

	.demo-desc {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		line-height: var(--leading-relaxed);
		margin: 0;
	}

	/* ── Notes ── */

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
		letter-spacing: var(--tracking-wide);
	}

	.note-content {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		line-height: var(--leading-relaxed);
		margin: 0;
	}

	.note-content code {
		color: var(--color-accent);
		background: var(--color-bg-tertiary);
		padding: 0 var(--space-1);
	}

	.note-content strong {
		color: var(--color-text-secondary);
	}

	/* ── Responsive ── */

	@media (max-width: 900px) {
		.status-grid {
			grid-template-columns: repeat(2, 1fr);
		}

		.sliders-grid {
			grid-template-columns: repeat(2, 1fr);
		}

		.comparison-grid {
			grid-template-columns: 1fr;
		}
	}

	@media (max-width: 640px) {
		.status-grid {
			grid-template-columns: 1fr 1fr;
		}

		.sliders-grid {
			grid-template-columns: 1fr;
		}

		.color-group {
			grid-column: span 1;
		}

		.color-settings {
			flex-direction: column;
			gap: var(--space-2);
		}

		.demo-preview {
			height: 250px;
		}
	}
</style>
