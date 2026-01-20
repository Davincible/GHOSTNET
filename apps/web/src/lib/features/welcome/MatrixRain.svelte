<script lang="ts">
	import { onMount } from 'svelte';

	interface Props {
		density?: number;      // Number of columns
		speed?: number;        // Fall speed multiplier
		opacity?: number;      // Overall opacity
		color?: string;        // Rain color (CSS color)
	}

	let { 
		density = 20, 
		speed = 1, 
		opacity = 0.15,
		color = 'var(--color-accent)'
	}: Props = $props();

	let canvas: HTMLCanvasElement;
	let animationId: number;

	const chars = 'ゴーストネット01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン$DATA';

	onMount(() => {
		const ctx = canvas.getContext('2d');
		if (!ctx) return;

		// Set canvas size
		const resize = () => {
			canvas.width = canvas.offsetWidth;
			canvas.height = canvas.offsetHeight;
		};
		resize();
		window.addEventListener('resize', resize);

		// Initialize drops
		const columns = Math.floor(canvas.width / (canvas.width / density));
		const drops: number[] = new Array(columns).fill(0).map(() => Math.random() * -100);
		const speeds: number[] = new Array(columns).fill(0).map(() => 0.5 + Math.random() * speed);

		// Get computed color
		const getColor = () => {
			const temp = document.createElement('div');
			temp.style.color = color;
			document.body.appendChild(temp);
			const computed = getComputedStyle(temp).color;
			document.body.removeChild(temp);
			return computed;
		};

		const rainColor = getColor();

		const draw = () => {
			// Fade effect
			ctx.fillStyle = `rgba(0, 0, 0, 0.05)`;
			ctx.fillRect(0, 0, canvas.width, canvas.height);

			// Draw characters
			ctx.font = '14px monospace';
			
			const columnWidth = canvas.width / columns;

			for (let i = 0; i < drops.length; i++) {
				const char = chars[Math.floor(Math.random() * chars.length)];
				const x = i * columnWidth;
				const y = drops[i] * 20;

				// Gradient opacity based on position
				const fadeIn = Math.min(1, drops[i] / 5);
				const fadeOut = Math.max(0, 1 - (drops[i] * 20 - canvas.height + 100) / 100);
				const charOpacity = opacity * fadeIn * fadeOut;

				ctx.fillStyle = rainColor.replace('rgb', 'rgba').replace(')', `, ${charOpacity})`);
				ctx.fillText(char, x, y);

				// Reset when off screen
				if (y > canvas.height && Math.random() > 0.975) {
					drops[i] = 0;
				}

				drops[i] += speeds[i];
			}

			animationId = requestAnimationFrame(draw);
		};

		draw();

		return () => {
			cancelAnimationFrame(animationId);
			window.removeEventListener('resize', resize);
		};
	});
</script>

<canvas bind:this={canvas} class="matrix-rain"></canvas>

<style>
	.matrix-rain {
		position: absolute;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		pointer-events: none;
		z-index: 0;
	}
</style>
