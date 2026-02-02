<script lang="ts">
	import { onMount } from 'svelte';

	interface Props {
		density?: number; // Number of columns
		speed?: number; // Fall speed multiplier
		opacity?: number; // Overall opacity
		color?: string; // Rain color (CSS color)
	}

	let { density = 20, speed = 1, opacity = 0.15, color = 'var(--color-accent)' }: Props = $props();

	let canvas: HTMLCanvasElement;
	let animationId: number;

	const chars =
		'ゴーストネット01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン$DATA';

	onMount(() => {
		const ctx = canvas.getContext('2d');
		if (!ctx) return;

		const fontSize = 14;
		const lineHeight = fontSize * 1.4;
		let width = 0;
		let height = 0;
		let drops: number[] = [];
		let speeds: number[] = [];

		const getColor = () => {
			const temp = document.createElement('div');
			temp.style.color = color;
			document.body.appendChild(temp);
			const computed = getComputedStyle(temp).color;
			document.body.removeChild(temp);
			return computed;
		};

		const rainColor = getColor();

		const resize = () => {
			width = canvas.offsetWidth;
			height = canvas.offsetHeight;
			canvas.width = width;
			canvas.height = height;
			ctx.font = `${fontSize}px monospace`;

			const columnCount = Math.max(1, Math.floor(density));
			drops = new Array(columnCount).fill(0).map(() => Math.random() * -100);
			speeds = new Array(columnCount).fill(0).map(() => 0.5 + Math.random() * speed);
		};

		resize();
		window.addEventListener('resize', resize);

		const draw = () => {
			ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
			ctx.fillRect(0, 0, width, height);

			const columnWidth = width / drops.length;
			ctx.fillStyle = rainColor;

			for (let i = 0; i < drops.length; i++) {
				const char = chars[Math.floor(Math.random() * chars.length)];
				const x = i * columnWidth;
				const y = drops[i] * lineHeight;

				ctx.globalAlpha = opacity;
				ctx.fillText(char, x, y);

				if (y > height && Math.random() > 0.975) {
					drops[i] = Math.random() * -20;
				}

				drops[i] += speeds[i];
			}

			ctx.globalAlpha = 1;
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
