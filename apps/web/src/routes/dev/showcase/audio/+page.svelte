<script lang="ts">
	import { Panel, Box } from '$lib/ui/terminal';
	import { Stack, Row } from '$lib/ui/layout';
	import { Button, Badge } from '$lib/ui/primitives';
	import { getAudioManager, type SoundName } from '$lib/core/audio';

	const audio = getAudioManager();

	// ── Sound categories ──

	const categories = [
		{
			name: 'UI',
			description: 'Interface interaction feedback — clicks, hovers, modals.',
			sounds: [
				{ name: 'click' as SoundName, label: 'CLICK', desc: 'Button press' },
				{ name: 'hover' as SoundName, label: 'HOVER', desc: 'Element hover' },
				{ name: 'open' as SoundName, label: 'OPEN', desc: 'Modal / panel open' },
				{ name: 'close' as SoundName, label: 'CLOSE', desc: 'Modal / panel close' },
				{ name: 'error' as SoundName, label: 'ERROR', desc: 'Validation failure' },
				{ name: 'success' as SoundName, label: 'SUCCESS', desc: 'Action confirmed' },
			],
		},
		{
			name: 'TYPING GAME',
			description: 'Trace Evasion mini-game — keystroke feedback, countdown, completion.',
			sounds: [
				{ name: 'keystroke' as SoundName, label: 'KEYSTROKE', desc: 'Correct key' },
				{ name: 'keystrokeError' as SoundName, label: 'KEYSTROKE ERROR', desc: 'Wrong key' },
				{ name: 'countdown' as SoundName, label: 'COUNTDOWN', desc: '3... 2... 1...' },
				{ name: 'countdownGo' as SoundName, label: 'COUNTDOWN GO', desc: 'GO!' },
				{ name: 'roundComplete' as SoundName, label: 'ROUND COMPLETE', desc: 'Round finished' },
				{ name: 'gameComplete' as SoundName, label: 'GAME COMPLETE', desc: 'All rounds done' },
			],
		},
		{
			name: 'FEED EVENTS',
			description: 'Live network events — jack-ins, extractions, traces, scans.',
			sounds: [
				{ name: 'jackIn' as SoundName, label: 'JACK IN', desc: 'Player staked' },
				{ name: 'extract' as SoundName, label: 'EXTRACT', desc: 'Player cashed out' },
				{ name: 'traced' as SoundName, label: 'TRACED', desc: 'Player killed' },
				{ name: 'survived' as SoundName, label: 'SURVIVED', desc: 'Player survived scan' },
				{ name: 'jackpot' as SoundName, label: 'JACKPOT', desc: 'Big payout event' },
				{ name: 'scanWarning' as SoundName, label: 'SCAN WARNING', desc: 'Scan approaching' },
				{ name: 'scanStart' as SoundName, label: 'SCAN START', desc: 'Scan executing' },
			],
		},
		{
			name: 'ALERTS',
			description: 'System-level notifications — escalating severity.',
			sounds: [
				{ name: 'alert' as SoundName, label: 'ALERT', desc: 'General notification' },
				{ name: 'warning' as SoundName, label: 'WARNING', desc: 'Elevated severity' },
				{ name: 'danger' as SoundName, label: 'DANGER', desc: 'Critical threat' },
			],
		},
		{
			name: 'HASH CRASH',
			description: 'Crash game — betting, launch, cash-out, explosion, win tiers.',
			sounds: [
				{ name: 'crashBettingStart' as SoundName, label: 'BETTING START', desc: 'Round opens' },
				{ name: 'crashBettingEnd' as SoundName, label: 'BETTING END', desc: 'Bets locked' },
				{ name: 'crashLaunch' as SoundName, label: 'LAUNCH', desc: 'Multiplier running' },
				{ name: 'crashCashOut' as SoundName, label: 'CASH OUT', desc: 'Player exits' },
				{
					name: 'crashCashOutOther' as SoundName,
					label: 'CASH OUT (OTHER)',
					desc: 'Another player exits',
				},
				{ name: 'crashExplosion' as SoundName, label: 'EXPLOSION', desc: 'Crash!' },
				{ name: 'crashWinSmall' as SoundName, label: 'WIN SMALL', desc: '< 2x' },
				{ name: 'crashWinMedium' as SoundName, label: 'WIN MEDIUM', desc: '2x - 5x' },
				{ name: 'crashWinBig' as SoundName, label: 'WIN BIG', desc: '5x - 20x' },
				{ name: 'crashWinMassive' as SoundName, label: 'WIN MASSIVE', desc: '20x+' },
				{ name: 'crashLoss' as SoundName, label: 'LOSS', desc: 'Didn\'t cash out' },
			],
		},
	];

	// ── Recently played tracking ──
	let lastPlayed = $state<string | null>(null);
	let playCount = $state(0);

	function play(name: SoundName, label: string) {
		audio.init();
		audio.play(name);
		lastPlayed = label;
		playCount++;
	}

	// ── Play All in category ──
	function playCategory(catSounds: { name: SoundName; label: string }[]) {
		let i = 0;
		function next() {
			if (i >= catSounds.length) return;
			play(catSounds[i].name, catSounds[i].label);
			i++;
			if (i < catSounds.length) {
				setTimeout(next, 400);
			}
		}
		next();
	}

	const totalSounds = categories.reduce((sum, c) => sum + c.sounds.length, 0);
</script>

<Stack gap={6}>
	<!-- ═══════════════════════════════════════════════════════════
	     STATUS
	     ═══════════════════════════════════════════════════════════ -->
	<Box title="AUDIO SYSTEM">
		<div class="status-grid">
			<div class="status-item">
				<span class="status-label">ENGINE</span>
				<span class="status-value status-online">ZzFX</span>
			</div>
			<div class="status-item">
				<span class="status-label">SOUNDS</span>
				<span class="status-value">{totalSounds}</span>
			</div>
			<div class="status-item">
				<span class="status-label">CATEGORIES</span>
				<span class="status-value">{categories.length}</span>
			</div>
			<div class="status-item">
				<span class="status-label">LAST PLAYED</span>
				<span class="status-value" class:status-online={lastPlayed}>
					{lastPlayed ?? 'NONE'}
				</span>
			</div>
			<div class="status-item">
				<span class="status-label">PLAYS THIS SESSION</span>
				<span class="status-value">{playCount}</span>
			</div>
			<div class="status-item">
				<span class="status-label">NOTE</span>
				<span class="status-value status-dim">Click any sound to preview</span>
			</div>
		</div>
	</Box>

	<!-- ═══════════════════════════════════════════════════════════
	     SOUND CATEGORIES
	     ═══════════════════════════════════════════════════════════ -->
	{#each categories as category (category.name)}
		<section class="showcase-section">
			<div class="section-header">
				<div class="section-header-row">
					<h2 class="section-title">{category.name}</h2>
					<Button
						size="sm"
						variant="ghost"
						onclick={() => playCategory(category.sounds)}
					>
						PLAY ALL
					</Button>
				</div>
				<p class="section-subtitle">{category.description}</p>
			</div>

			<div class="sound-grid">
				{#each category.sounds as sound (sound.name)}
					<button
						type="button"
						class="sound-card"
						class:sound-active={lastPlayed === sound.label}
						onclick={() => play(sound.name, sound.label)}
					>
						<div class="sound-header">
							<span class="sound-icon">&#9654;</span>
							<span class="sound-label">{sound.label}</span>
						</div>
						<span class="sound-desc">{sound.desc}</span>
						<span class="sound-id">{sound.name}</span>
					</button>
				{/each}
			</div>
		</section>
	{/each}
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

	.status-dim {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
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

	/* ── Sound Grid ── */

	.sound-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
		gap: var(--space-2);
	}

	.sound-card {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		padding: var(--space-3);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-default);
		text-align: left;
		cursor: pointer;
		font-family: var(--font-mono);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.sound-card:hover {
		border-color: var(--color-accent-dim);
		background: var(--color-bg-tertiary);
	}

	.sound-card:active {
		border-color: var(--color-accent);
		background: var(--color-accent-glow);
	}

	.sound-card.sound-active {
		border-color: var(--color-accent-dim);
	}

	.sound-header {
		display: flex;
		align-items: center;
		gap: var(--space-1-5);
	}

	.sound-icon {
		font-size: 0.5rem;
		color: var(--color-accent-dim);
		flex-shrink: 0;
		transition: color var(--duration-fast) var(--ease-default);
	}

	.sound-card:hover .sound-icon {
		color: var(--color-accent);
	}

	.sound-label {
		font-size: var(--text-xs);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wider);
	}

	.sound-desc {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		line-height: var(--leading-relaxed);
	}

	.sound-id {
		font-size: 0.5625rem;
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wide);
	}

	/* ── Responsive ── */

	@media (max-width: 640px) {
		.status-grid {
			grid-template-columns: repeat(2, 1fr);
		}

		.sound-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
