<script lang="ts">
	// GHOSTNET Design System Test Page
	// Phase 1 & 2: Component Showcase

	import { Button, ProgressBar, AnimatedNumber, Countdown, Badge, Spinner } from '$lib/ui/primitives';
	import { AddressDisplay, AmountDisplay, PercentDisplay, LevelBadge } from '$lib/ui/data-display';
	import { Stack, Row } from '$lib/ui/layout';
	import { Box, Panel } from '$lib/ui/terminal';

	// Test state
	let progressValue = $state(75);
	let animatedValue = $state(1234);
	let isLoading = $state(false);

	// Countdown target (2 minutes from now)
	let countdownTarget = $state(Date.now() + 2 * 60 * 1000);

	// Test data
	const testAddress = '0x7a3f9c2d8b1e4a5f6c7d8e9f0a1b2c3d4e5f6789' as const;
	const testAmount = 500000000000000000000n; // 500 tokens
	const testGain = 47000000000000000000n; // +47 tokens

	function handleClick() {
		isLoading = true;
		setTimeout(() => {
			isLoading = false;
			animatedValue += Math.floor(Math.random() * 500);
		}, 1000);
	}

	function updateProgress() {
		progressValue = Math.floor(Math.random() * 100);
	}

	function resetCountdown() {
		countdownTarget = Date.now() + 2 * 60 * 1000;
	}
</script>

<svelte:head>
	<title>GHOSTNET v1.0.7 - Design System</title>
	<meta name="description" content="Jack In. Don't Get Traced." />
</svelte:head>

<main class="terminal">
	<!-- Header -->
	<header class="header">
		<h1 class="logo glow-green">GHOSTNET <span class="text-green-dim">v1.0.7</span></h1>
		<div class="status">
			<span class="text-green-mid text-sm">NETWORK:</span>
			<Badge variant="success" glow>ONLINE</Badge>
		</div>
	</header>

	<!-- Design System Test -->
	<div class="content">
		<Stack gap={6}>
			<h2 class="text-xl glow-green">Phase 1: Component Library</h2>

			<!-- Buttons -->
			<section class="test-section">
				<h3 class="section-title">Buttons</h3>
				<Stack gap={4}>
					<Row gap={4} wrap>
						<Button variant="primary" onclick={handleClick} loading={isLoading}>
							Primary
						</Button>
						<Button variant="secondary">Secondary</Button>
						<Button variant="danger">Danger</Button>
						<Button variant="ghost">Ghost</Button>
					</Row>
					<Row gap={4} wrap>
						<Button size="sm">Small</Button>
						<Button size="md">Medium</Button>
						<Button size="lg">Large</Button>
					</Row>
					<Row gap={4} wrap>
						<Button hotkey="J">Jack In</Button>
						<Button hotkey="E" variant="danger">Extract</Button>
						<Button hotkey="T" variant="secondary">Trace Evasion</Button>
					</Row>
					<Row gap={4}>
						<Button disabled>Disabled</Button>
						<Button loading={true}>Loading</Button>
					</Row>
				</Stack>
			</section>

			<!-- Progress Bars -->
			<section class="test-section">
				<h3 class="section-title">Progress Bars</h3>
				<Stack gap={3}>
					<ProgressBar value={progressValue} showPercent label="TVL CAPACITY" />
					<ProgressBar value={89} variant="success" showPercent label="OPERATORS" />
					<ProgressBar value={45} variant="warning" showPercent label="SCAN TIME" />
					<ProgressBar value={92} variant="danger" showPercent animated label="DEATH RATE" />
					<ProgressBar value={60} variant="cyan" showPercent label="XP PROGRESS" />
					<Button size="sm" variant="ghost" onclick={updateProgress}>Randomize</Button>
				</Stack>
			</section>

			<!-- Animated Numbers -->
			<section class="test-section">
				<h3 class="section-title">Animated Numbers</h3>
				<Stack gap={3}>
					<Row gap={6}>
						<Stack gap={1}>
							<span class="text-green-dim text-xs">BASIC</span>
							<span class="text-2xl">
								<AnimatedNumber value={animatedValue} />
							</span>
						</Stack>
						<Stack gap={1}>
							<span class="text-green-dim text-xs">CURRENCY</span>
							<span class="text-2xl">
								<AnimatedNumber value={animatedValue} format="currency" prefix="$" decimals={2} />
							</span>
						</Stack>
						<Stack gap={1}>
							<span class="text-green-dim text-xs">COMPACT</span>
							<span class="text-2xl">
								<AnimatedNumber value={animatedValue * 1000} format="compact" decimals={1} />
							</span>
						</Stack>
					</Row>
					<Row gap={6}>
						<Stack gap={1}>
							<span class="text-green-dim text-xs">PROFIT</span>
							<span class="text-xl">
								<AnimatedNumber value={347} showSign colorize prefix="$" />
							</span>
						</Stack>
						<Stack gap={1}>
							<span class="text-green-dim text-xs">LOSS</span>
							<span class="text-xl">
								<AnimatedNumber value={-128} showSign colorize prefix="$" />
							</span>
						</Stack>
					</Row>
				</Stack>
			</section>

			<!-- Countdown -->
			<section class="test-section">
				<h3 class="section-title">Countdown Timers</h3>
				<Stack gap={3}>
					<Row gap={6}>
						<Stack gap={1}>
							<span class="text-green-dim text-xs">NEXT SCAN</span>
							<span class="text-xl">
								<Countdown targetTime={countdownTarget} />
							</span>
						</Stack>
						<Stack gap={1}>
							<span class="text-green-dim text-xs">URGENT (30s)</span>
							<span class="text-xl">
								<Countdown targetTime={Date.now() + 25000} urgentThreshold={30} />
							</span>
						</Stack>
						<Stack gap={1}>
							<span class="text-green-dim text-xs">WITH LABEL</span>
							<span class="text-lg">
								<Countdown targetTime={countdownTarget} label="SYSTEM RESET" />
							</span>
						</Stack>
					</Row>
					<Button size="sm" variant="ghost" onclick={resetCountdown}>Reset Countdown</Button>
				</Stack>
			</section>

			<!-- Badges -->
			<section class="test-section">
				<h3 class="section-title">Badges</h3>
				<Row gap={4} wrap>
					<Badge>Default</Badge>
					<Badge variant="success">Success</Badge>
					<Badge variant="warning">Warning</Badge>
					<Badge variant="danger">Danger</Badge>
					<Badge variant="info">Info</Badge>
					<Badge variant="hotkey">[J]</Badge>
					<Badge variant="success" glow>Glow</Badge>
					<Badge variant="warning" pulse>Pulse</Badge>
				</Row>
			</section>

			<!-- Spinners -->
			<section class="test-section">
				<h3 class="section-title">Spinners</h3>
				<Row gap={6} align="center">
					<Stack gap={1} align="center">
						<Spinner size="sm" />
						<span class="text-xs text-green-dim">Small</span>
					</Stack>
					<Stack gap={1} align="center">
						<Spinner size="md" />
						<span class="text-xs text-green-dim">Medium</span>
					</Stack>
					<Stack gap={1} align="center">
						<Spinner size="lg" />
						<span class="text-xs text-green-dim">Large</span>
					</Stack>
					<Stack gap={1} align="center">
						<Spinner variant="dots" />
						<span class="text-xs text-green-dim">Dots</span>
					</Stack>
					<Stack gap={1} align="center">
						<Spinner variant="bar" />
						<span class="text-xs text-green-dim">Bar</span>
					</Stack>
				</Row>
			</section>

			<!-- Data Display -->
			<section class="test-section">
				<h3 class="section-title">Data Display</h3>
				<Stack gap={4}>
					<!-- Address -->
					<Row gap={4} align="baseline">
						<span class="text-green-dim text-sm" style="min-width: 100px;">Address:</span>
						<AddressDisplay address={testAddress} />
					</Row>

					<!-- Amounts -->
					<Row gap={4} align="baseline">
						<span class="text-green-dim text-sm" style="min-width: 100px;">Amount:</span>
						<AmountDisplay amount={testAmount} />
						<span class="text-green-dim">|</span>
						<AmountDisplay amount={testAmount} format="full" />
						<span class="text-green-dim">|</span>
						<AmountDisplay amount={testAmount} symbol="$DATA" useDataSymbol={false} />
					</Row>

					<!-- Gains/Losses -->
					<Row gap={4} align="baseline">
						<span class="text-green-dim text-sm" style="min-width: 100px;">Gain/Loss:</span>
						<AmountDisplay amount={testGain} showSign colorize />
						<span class="text-green-dim">|</span>
						<AmountDisplay amount={-testGain} showSign colorize />
					</Row>

					<!-- Percentages -->
					<Row gap={4} align="baseline">
						<span class="text-green-dim text-sm" style="min-width: 100px;">Percent:</span>
						<PercentDisplay value={32} trend="down" colorMode="inverted" />
						<span class="text-green-dim">|</span>
						<PercentDisplay value={15.5} decimals={1} trend="up" />
						<span class="text-green-dim">|</span>
						<PercentDisplay value={95} trend="up" colorMode="default" urgentAbove={90} />
					</Row>
				</Stack>
			</section>

			<!-- Level Badges -->
			<section class="test-section">
				<h3 class="section-title">Security Clearances</h3>
				<Row gap={4} wrap>
					<LevelBadge level="VAULT" />
					<LevelBadge level="MAINFRAME" />
					<LevelBadge level="SUBNET" />
					<LevelBadge level="DARKNET" />
					<LevelBadge level="BLACK_ICE" />
				</Row>
				<Row gap={4} wrap class="mt-4">
					<LevelBadge level="VAULT" glow compact />
					<LevelBadge level="MAINFRAME" glow compact />
					<LevelBadge level="SUBNET" glow compact />
					<LevelBadge level="DARKNET" glow compact />
					<LevelBadge level="BLACK_ICE" glow compact />
				</Row>
			</section>

			<!-- Layout Demo -->
			<section class="test-section">
				<h3 class="section-title">Layout Components</h3>
				<Stack gap={4}>
					<div>
						<span class="text-green-dim text-xs">Stack (vertical, gap=2)</span>
						<Stack gap={2}>
							<div class="demo-box">Item 1</div>
							<div class="demo-box">Item 2</div>
							<div class="demo-box">Item 3</div>
						</Stack>
					</div>
					<div>
						<span class="text-green-dim text-xs">Row (horizontal, justify=between)</span>
						<Row gap={2} justify="between">
							<div class="demo-box">Left</div>
							<div class="demo-box">Center</div>
							<div class="demo-box">Right</div>
						</Row>
					</div>
				</Stack>
			</section>

			<!-- Terminal Box Components -->
			<section class="test-section">
				<h3 class="section-title">Terminal Boxes</h3>
				<Stack gap={4}>
					<Row gap={4} wrap>
						<div style="flex: 1; min-width: 250px;">
							<Box title="Single Border" variant="single">
								<p class="text-sm">Default single-line ASCII border style.</p>
							</Box>
						</div>
						<div style="flex: 1; min-width: 250px;">
							<Box title="Double Border" variant="double" borderColor="cyan">
								<p class="text-sm">Double-line border with cyan color.</p>
							</Box>
						</div>
					</Row>
					<Row gap={4} wrap>
						<div style="flex: 1; min-width: 250px;">
							<Box title="Glowing" variant="single" borderColor="bright" glow>
								<p class="text-sm">Glowing border effect for emphasis.</p>
							</Box>
						</div>
						<div style="flex: 1; min-width: 250px;">
							<Box title="Danger" variant="single" borderColor="red">
								<p class="text-sm text-red">Red border for warnings/errors.</p>
							</Box>
						</div>
					</Row>
				</Stack>
			</section>

			<!-- Panel with Scroll -->
			<section class="test-section">
				<h3 class="section-title">Scrollable Panel</h3>
				<Panel title="LIVE FEED" scrollable maxHeight="150px">
					<Stack gap={2}>
						<p class="text-sm">> 0x7a3f jacked in [DARKNET] 500Đ</p>
						<p class="text-sm text-red">> 0x9c2d ████ TRACED ████ -Loss 120Đ</p>
						<p class="text-sm text-profit">> 0x3b1a extracted 847Đ [+312 gain]</p>
						<p class="text-sm text-amber">> TRACE SCAN [DARKNET] in 00:45</p>
						<p class="text-sm">> 0x8f2e jacked in [BLACK ICE] 50Đ</p>
						<p class="text-sm text-red">> 0x1d4c ████ TRACED ████ -Loss 200Đ</p>
						<p class="text-sm">> 0x5e7b survived [SUBNET] streak: 12</p>
						<p class="text-sm text-amber">> SYSTEM RESET in 04:32:17</p>
						<p class="text-sm text-cyan">> 0x2a9f crew [PHANTOMS] +10% boost</p>
						<p class="text-sm">> 0x6c3d perfect hack run [3x mult]</p>
					</Stack>
				</Panel>
			</section>
		</Stack>
	</div>

	<!-- Footer -->
	<footer class="footer">
		<p class="text-sm text-green-dim">
			Phase 1 & 2 Complete - Design System & Terminal Shell Ready
		</p>
	</footer>
</main>

<style>
	.terminal {
		padding: var(--space-4);
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-bottom: var(--space-4);
		border-bottom: 1px solid var(--color-green-dim);
		margin-bottom: var(--space-6);
	}

	.logo {
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.status {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.content {
		max-width: 900px;
		margin: 0 auto;
	}

	.test-section {
		padding: var(--space-4);
		border: 1px solid var(--color-bg-tertiary);
	}

	.section-title {
		font-size: var(--text-lg);
		color: var(--color-cyan);
		margin-bottom: var(--space-4);
		padding-bottom: var(--space-2);
		border-bottom: 1px solid var(--color-bg-tertiary);
	}

	.demo-box {
		padding: var(--space-2) var(--space-4);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-green-dim);
		color: var(--color-green-mid);
		font-size: var(--text-sm);
	}

	.footer {
		margin-top: var(--space-8);
		padding-top: var(--space-4);
		border-top: 1px solid var(--color-bg-tertiary);
		text-align: center;
	}

	/* Utility classes used in this page */
	:global(.mt-4) {
		margin-top: var(--space-4);
	}
</style>
