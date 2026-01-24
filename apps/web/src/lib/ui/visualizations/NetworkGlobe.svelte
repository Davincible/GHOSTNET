<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import * as THREE from 'three';

	interface Props {
		/** Width of the canvas */
		width?: number;
		/** Height of the canvas */
		height?: number;
		/** Number of particles */
		particleCount?: number;
		/** Auto-rotate speed */
		rotationSpeed?: number;
		/** Enable interaction */
		interactive?: boolean;
	}

	let {
		width = 400,
		height = 400,
		particleCount = 120,
		rotationSpeed = 0.001,
		interactive = true,
	}: Props = $props();

	let container: HTMLDivElement;
	let animationId: number;
	let scene: THREE.Scene;
	let camera: THREE.PerspectiveCamera;
	let renderer: THREE.WebGLRenderer;
	let particles: THREE.Points;
	let connections: THREE.LineSegments;
	let outerRing: THREE.LineLoop;
	let innerSphere: THREE.LineSegments;
	let mouseX = 0;
	let mouseY = 0;

	// Colors from our design system
	const COLORS = {
		accent: 0x00e5cc,
		accentBright: 0x00fff2,
		accentDim: 0x007a6b,
		red: 0xff3366,
		amber: 0xffb000,
		background: 0x030305,
	};

	onMount(() => {
		init();
		animate();

		if (interactive) {
			container.addEventListener('mousemove', onMouseMove);
		}
	});

	onDestroy(() => {
		if (animationId) {
			cancelAnimationFrame(animationId);
		}
		if (renderer) {
			renderer.dispose();
		}
		if (interactive && container) {
			container.removeEventListener('mousemove', onMouseMove);
		}
	});

	function init() {
		// Scene
		scene = new THREE.Scene();

		// Camera
		camera = new THREE.PerspectiveCamera(60, width / height, 0.1, 1000);
		camera.position.z = 4;

		// Renderer
		renderer = new THREE.WebGLRenderer({
			antialias: true,
			alpha: true,
		});
		renderer.setSize(width, height);
		renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
		renderer.setClearColor(COLORS.background, 0);
		container.appendChild(renderer.domElement);

		// Create the visualization elements
		createParticles();
		createConnections();
		createOuterRing();
		createInnerSphere();
	}

	function createParticles() {
		const geometry = new THREE.BufferGeometry();
		const positions = new Float32Array(particleCount * 3);
		const colors = new Float32Array(particleCount * 3);
		const sizes = new Float32Array(particleCount);

		const color = new THREE.Color(COLORS.accent);
		const colorBright = new THREE.Color(COLORS.accentBright);
		const colorDim = new THREE.Color(COLORS.accentDim);

		for (let i = 0; i < particleCount; i++) {
			// Distribute on sphere surface with some variance
			const phi = Math.acos(-1 + (2 * i) / particleCount);
			const theta = Math.sqrt(particleCount * Math.PI) * phi;
			const radius = 1.5 + Math.random() * 0.3;

			positions[i * 3] = radius * Math.cos(theta) * Math.sin(phi);
			positions[i * 3 + 1] = radius * Math.sin(theta) * Math.sin(phi);
			positions[i * 3 + 2] = radius * Math.cos(phi);

			// Random color variation
			const colorChoice = Math.random();
			let c: THREE.Color;
			if (colorChoice > 0.9) {
				c = colorBright;
			} else if (colorChoice > 0.7) {
				c = color;
			} else {
				c = colorDim;
			}

			colors[i * 3] = c.r;
			colors[i * 3 + 1] = c.g;
			colors[i * 3 + 2] = c.b;

			sizes[i] = Math.random() * 3 + 1;
		}

		geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
		geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
		geometry.setAttribute('size', new THREE.BufferAttribute(sizes, 1));

		const material = new THREE.PointsMaterial({
			size: 0.04,
			vertexColors: true,
			transparent: true,
			opacity: 0.9,
			sizeAttenuation: true,
			blending: THREE.AdditiveBlending,
		});

		particles = new THREE.Points(geometry, material);
		scene.add(particles);
	}

	function createConnections() {
		const positions = particles.geometry.attributes.position.array as Float32Array;
		const connectionPositions: number[] = [];
		const connectionColors: number[] = [];
		const maxDistance = 0.8;

		const color = new THREE.Color(COLORS.accentDim);

		// Find nearby particles and create connections
		for (let i = 0; i < particleCount; i++) {
			const x1 = positions[i * 3];
			const y1 = positions[i * 3 + 1];
			const z1 = positions[i * 3 + 2];

			for (let j = i + 1; j < particleCount; j++) {
				const x2 = positions[j * 3];
				const y2 = positions[j * 3 + 1];
				const z2 = positions[j * 3 + 2];

				const distance = Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2 + (z2 - z1) ** 2);

				if (distance < maxDistance) {
					connectionPositions.push(x1, y1, z1, x2, y2, z2);
					// Fade based on distance
					const alpha = 1 - distance / maxDistance;
					connectionColors.push(
						color.r * alpha,
						color.g * alpha,
						color.b * alpha,
						color.r * alpha,
						color.g * alpha,
						color.b * alpha
					);
				}
			}
		}

		const geometry = new THREE.BufferGeometry();
		geometry.setAttribute('position', new THREE.Float32BufferAttribute(connectionPositions, 3));
		geometry.setAttribute('color', new THREE.Float32BufferAttribute(connectionColors, 3));

		const material = new THREE.LineBasicMaterial({
			vertexColors: true,
			transparent: true,
			opacity: 0.3,
			blending: THREE.AdditiveBlending,
		});

		connections = new THREE.LineSegments(geometry, material);
		scene.add(connections);
	}

	function createOuterRing() {
		// Orbital ring around the globe
		const geometry = new THREE.BufferGeometry();
		const segments = 128;
		const positions = new Float32Array((segments + 1) * 3);
		const radius = 2.2;

		for (let i = 0; i <= segments; i++) {
			const theta = (i / segments) * Math.PI * 2;
			positions[i * 3] = radius * Math.cos(theta);
			positions[i * 3 + 1] = 0;
			positions[i * 3 + 2] = radius * Math.sin(theta);
		}

		geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));

		const material = new THREE.LineBasicMaterial({
			color: COLORS.accentDim,
			transparent: true,
			opacity: 0.4,
		});

		outerRing = new THREE.LineLoop(geometry, material);
		outerRing.rotation.x = Math.PI / 6;
		scene.add(outerRing);

		// Second ring at different angle
		const ring2 = outerRing.clone();
		ring2.rotation.x = -Math.PI / 4;
		ring2.rotation.z = Math.PI / 3;
		scene.add(ring2);
	}

	function createInnerSphere() {
		// Wireframe icosahedron core
		const geometry = new THREE.IcosahedronGeometry(0.8, 1);
		const wireframe = new THREE.WireframeGeometry(geometry);

		const material = new THREE.LineBasicMaterial({
			color: COLORS.accent,
			transparent: true,
			opacity: 0.15,
		});

		innerSphere = new THREE.LineSegments(wireframe, material);
		scene.add(innerSphere);
	}

	function onMouseMove(event: MouseEvent) {
		const rect = container.getBoundingClientRect();
		mouseX = ((event.clientX - rect.left) / width) * 2 - 1;
		mouseY = -((event.clientY - rect.top) / height) * 2 + 1;
	}

	function animate() {
		animationId = requestAnimationFrame(animate);

		const time = Date.now() * 0.001;

		// Rotate everything slowly
		if (particles) {
			particles.rotation.y += rotationSpeed;
			particles.rotation.x = Math.sin(time * 0.2) * 0.1;
		}

		if (connections) {
			connections.rotation.y += rotationSpeed;
			connections.rotation.x = Math.sin(time * 0.2) * 0.1;
		}

		if (innerSphere) {
			innerSphere.rotation.y -= rotationSpeed * 0.5;
			innerSphere.rotation.x += rotationSpeed * 0.3;
		}

		if (outerRing) {
			outerRing.rotation.z += rotationSpeed * 0.5;
		}

		// Interactive mouse follow
		if (interactive) {
			camera.position.x += (mouseX * 0.5 - camera.position.x) * 0.05;
			camera.position.y += (mouseY * 0.3 - camera.position.y) * 0.05;
			camera.lookAt(scene.position);
		}

		// Pulse random particles occasionally
		if (particles && Math.random() > 0.98) {
			const colors = particles.geometry.attributes.color.array as Float32Array;
			const randomIndex = Math.floor(Math.random() * particleCount) * 3;

			// Random pulse color (mostly teal, sometimes red for "traced")
			if (Math.random() > 0.85) {
				// Red pulse - traced
				colors[randomIndex] = 1.0;
				colors[randomIndex + 1] = 0.2;
				colors[randomIndex + 2] = 0.4;
			} else {
				// Bright teal pulse
				colors[randomIndex] = 0;
				colors[randomIndex + 1] = 1.0;
				colors[randomIndex + 2] = 0.95;
			}
			particles.geometry.attributes.color.needsUpdate = true;

			// Fade back to normal
			setTimeout(() => {
				if (particles) {
					const c = new THREE.Color(COLORS.accentDim);
					colors[randomIndex] = c.r;
					colors[randomIndex + 1] = c.g;
					colors[randomIndex + 2] = c.b;
					particles.geometry.attributes.color.needsUpdate = true;
				}
			}, 300);
		}

		renderer.render(scene, camera);
	}

	// Handle resize
	$effect(() => {
		if (renderer && camera) {
			renderer.setSize(width, height);
			camera.aspect = width / height;
			camera.updateProjectionMatrix();
		}
	});
</script>

<div
	class="network-globe"
	bind:this={container}
	style:width="{width}px"
	style:height="{height}px"
></div>

<style>
	.network-globe {
		position: relative;
		overflow: hidden;
	}

	.network-globe :global(canvas) {
		display: block;
	}
</style>
