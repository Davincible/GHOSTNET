<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import * as THREE from 'three';

	type SecurityLevel = 'VAULT' | 'MAINFRAME' | 'SUBNET' | 'DARKNET' | 'BLACK_ICE';

	interface Operator {
		id: string;
		level: SecurityLevel;
		stakedAmount: number;
		isCurrentUser?: boolean;
	}

	interface Props {
		width?: number;
		height?: number;
		operators?: Operator[];
		currentUserLevel?: SecurityLevel;
		onScanPulse?: () => void;
	}

	let {
		width = 400,
		height = 350,
		operators = [],
		currentUserLevel = 'VAULT',
		onScanPulse
	}: Props = $props();

	let container: HTMLDivElement;
	let animationId: number;
	let scene: THREE.Scene;
	let camera: THREE.PerspectiveCamera;
	let renderer: THREE.WebGLRenderer;
	let core: THREE.Mesh;
	let orbitRings: THREE.Line[] = [];
	let satellites: Map<string, { mesh: THREE.Mesh; level: SecurityLevel; angle: number; speed: number }> = new Map();
	let scanPulse: THREE.Mesh | null = null;
	let scanPulseScale = 0;
	let isScanning = false;
	let particles: THREE.Points;

	// Colors from design system
	const COLORS = {
		core: 0x00e5cc,
		corePulse: 0x00fff2,
		vault: 0x00e5cc,
		mainframe: 0x00e5ff,
		subnet: 0xffb000,
		darknet: 0xff6633,
		blackIce: 0xff3366,
		ring: 0x252532,
		particle: 0x007a6b,
		traced: 0xff3366
	};

	const LEVEL_CONFIG: Record<SecurityLevel, { radius: number; speed: number; color: number; tilt: number }> = {
		VAULT: { radius: 1.0, speed: 0.3, color: COLORS.vault, tilt: 0 },
		MAINFRAME: { radius: 1.4, speed: 0.4, color: COLORS.mainframe, tilt: 0.1 },
		SUBNET: { radius: 1.8, speed: 0.55, color: COLORS.subnet, tilt: 0.15 },
		DARKNET: { radius: 2.2, speed: 0.75, color: COLORS.darknet, tilt: 0.2 },
		BLACK_ICE: { radius: 2.6, speed: 1.0, color: COLORS.blackIce, tilt: 0.25 }
	};

	onMount(() => {
		init();
		createScene();
		animate();
	});

	onDestroy(() => {
		if (animationId) cancelAnimationFrame(animationId);
		if (renderer) renderer.dispose();
		satellites.clear();
	});

	function init() {
		scene = new THREE.Scene();

		camera = new THREE.PerspectiveCamera(50, width / height, 0.1, 1000);
		camera.position.set(0, 3, 5);
		camera.lookAt(0, 0, 0);

		renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
		renderer.setSize(width, height);
		renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
		container.appendChild(renderer.domElement);
	}

	function createScene() {
		createCore();
		createOrbitRings();
		createBackgroundParticles();
		createSatellites();
	}

	function createCore() {
		// Inner glowing core
		const coreGeometry = new THREE.IcosahedronGeometry(0.4, 2);
		const coreMaterial = new THREE.MeshBasicMaterial({
			color: COLORS.core,
			transparent: true,
			opacity: 0.8,
			wireframe: true
		});
		core = new THREE.Mesh(coreGeometry, coreMaterial);
		scene.add(core);

		// Core glow sphere
		const glowGeometry = new THREE.SphereGeometry(0.5, 16, 16);
		const glowMaterial = new THREE.MeshBasicMaterial({
			color: COLORS.core,
			transparent: true,
			opacity: 0.15
		});
		const glow = new THREE.Mesh(glowGeometry, glowMaterial);
		scene.add(glow);

		// Inner solid core
		const innerGeometry = new THREE.IcosahedronGeometry(0.25, 1);
		const innerMaterial = new THREE.MeshBasicMaterial({
			color: COLORS.corePulse,
			transparent: true,
			opacity: 0.6
		});
		const inner = new THREE.Mesh(innerGeometry, innerMaterial);
		scene.add(inner);
	}

	function createOrbitRings() {
		const levels: SecurityLevel[] = ['VAULT', 'MAINFRAME', 'SUBNET', 'DARKNET', 'BLACK_ICE'];

		levels.forEach((level) => {
			const config = LEVEL_CONFIG[level];
			const segments = 64;
			const points: THREE.Vector3[] = [];

			for (let i = 0; i <= segments; i++) {
				const theta = (i / segments) * Math.PI * 2;
				points.push(new THREE.Vector3(
					config.radius * Math.cos(theta),
					0,
					config.radius * Math.sin(theta)
				));
			}

			const geometry = new THREE.BufferGeometry().setFromPoints(points);
			const material = new THREE.LineBasicMaterial({
				color: COLORS.ring,
				transparent: true,
				opacity: 0.4
			});

			const ring = new THREE.Line(geometry, material);
			ring.rotation.x = config.tilt;
			orbitRings.push(ring);
			scene.add(ring);

			// Add level label ring glow
			const glowMaterial = new THREE.LineBasicMaterial({
				color: config.color,
				transparent: true,
				opacity: 0.1
			});
			const glowRing = new THREE.Line(geometry.clone(), glowMaterial);
			glowRing.rotation.x = config.tilt;
			scene.add(glowRing);
		});
	}

	function createBackgroundParticles() {
		const particleCount = 200;
		const positions = new Float32Array(particleCount * 3);
		const colors = new Float32Array(particleCount * 3);

		const color = new THREE.Color(COLORS.particle);

		for (let i = 0; i < particleCount; i++) {
			// Random positions in a sphere
			const radius = 3 + Math.random() * 2;
			const theta = Math.random() * Math.PI * 2;
			const phi = Math.acos(2 * Math.random() - 1);

			positions[i * 3] = radius * Math.sin(phi) * Math.cos(theta);
			positions[i * 3 + 1] = radius * Math.sin(phi) * Math.sin(theta);
			positions[i * 3 + 2] = radius * Math.cos(phi);

			const alpha = 0.3 + Math.random() * 0.5;
			colors[i * 3] = color.r * alpha;
			colors[i * 3 + 1] = color.g * alpha;
			colors[i * 3 + 2] = color.b * alpha;
		}

		const geometry = new THREE.BufferGeometry();
		geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
		geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));

		const material = new THREE.PointsMaterial({
			size: 0.02,
			vertexColors: true,
			transparent: true,
			opacity: 0.6,
			blending: THREE.AdditiveBlending
		});

		particles = new THREE.Points(geometry, material);
		scene.add(particles);
	}

	function createSatellites() {
		// Create demo satellites if none provided
		const demoOperators: Operator[] = operators.length > 0 ? operators : generateDemoOperators(30);

		demoOperators.forEach((op, index) => {
			createSatellite(op, index);
		});
	}

	function generateDemoOperators(count: number): Operator[] {
		const levels: SecurityLevel[] = ['VAULT', 'MAINFRAME', 'SUBNET', 'DARKNET', 'BLACK_ICE'];
		const ops: Operator[] = [];

		for (let i = 0; i < count; i++) {
			ops.push({
				id: `op-${i}`,
				level: levels[Math.floor(Math.random() * levels.length)],
				stakedAmount: Math.random() * 10000,
				isCurrentUser: i === 0
			});
		}

		return ops;
	}

	function createSatellite(operator: Operator, index: number) {
		const config = LEVEL_CONFIG[operator.level];
		
		// Satellite size based on staked amount
		const size = 0.03 + (operator.stakedAmount / 10000) * 0.04;
		
		const geometry = operator.isCurrentUser
			? new THREE.OctahedronGeometry(size * 1.5, 0)
			: new THREE.SphereGeometry(size, 8, 8);

		const material = new THREE.MeshBasicMaterial({
			color: operator.isCurrentUser ? 0xffffff : config.color,
			transparent: true,
			opacity: operator.isCurrentUser ? 1 : 0.8
		});

		const satellite = new THREE.Mesh(geometry, material);
		
		// Starting angle distributed around the orbit
		const angle = (index / 30) * Math.PI * 2 + Math.random() * 0.5;
		
		// Position on orbit
		satellite.position.x = config.radius * Math.cos(angle);
		satellite.position.z = config.radius * Math.sin(angle);
		satellite.position.y = config.tilt * config.radius * Math.sin(angle);

		scene.add(satellite);

		// Add glow for current user
		if (operator.isCurrentUser) {
			const glowGeometry = new THREE.SphereGeometry(size * 2.5, 16, 16);
			const glowMaterial = new THREE.MeshBasicMaterial({
				color: COLORS.core,
				transparent: true,
				opacity: 0.3
			});
			const glow = new THREE.Mesh(glowGeometry, glowMaterial);
			satellite.add(glow);
		}

		satellites.set(operator.id, {
			mesh: satellite,
			level: operator.level,
			angle,
			speed: config.speed * (0.8 + Math.random() * 0.4)
		});
	}

	export function triggerScanPulse() {
		if (isScanning) return;
		isScanning = true;
		scanPulseScale = 0;

		// Create expanding pulse ring
		const geometry = new THREE.RingGeometry(0.1, 0.15, 32);
		const material = new THREE.MeshBasicMaterial({
			color: COLORS.core,
			transparent: true,
			opacity: 0.8,
			side: THREE.DoubleSide
		});

		scanPulse = new THREE.Mesh(geometry, material);
		scanPulse.rotation.x = -Math.PI / 2;
		scene.add(scanPulse);

		onScanPulse?.();
	}

	function updateScanPulse() {
		if (!scanPulse || !isScanning) return;

		scanPulseScale += 0.03;
		const maxScale = 30;

		if (scanPulseScale >= maxScale) {
			scene.remove(scanPulse);
			scanPulse = null;
			isScanning = false;

			// Randomly "trace" some satellites
			satellites.forEach((sat, id) => {
				if (Math.random() > 0.92) {
					traceSatellite(id);
				}
			});
			return;
		}

		scanPulse.scale.set(scanPulseScale, scanPulseScale, 1);
		(scanPulse.material as THREE.MeshBasicMaterial).opacity = 0.8 * (1 - scanPulseScale / maxScale);

		// Check for satellites caught in pulse
		const pulseRadius = scanPulseScale * 0.15;
		satellites.forEach((sat) => {
			const dist = Math.sqrt(sat.mesh.position.x ** 2 + sat.mesh.position.z ** 2);
			if (Math.abs(dist - pulseRadius) < 0.2) {
				// Flash the satellite
				const mat = sat.mesh.material as THREE.MeshBasicMaterial;
				mat.opacity = 1;
				setTimeout(() => { mat.opacity = 0.8; }, 100);
			}
		});
	}

	function traceSatellite(id: string) {
		const sat = satellites.get(id);
		if (!sat) return;

		const material = sat.mesh.material as THREE.MeshBasicMaterial;
		material.color.setHex(COLORS.traced);

		// Animate falling into core
		const fallAnimation = () => {
			sat.mesh.position.y -= 0.05;
			sat.mesh.position.x *= 0.95;
			sat.mesh.position.z *= 0.95;
			material.opacity *= 0.95;

			if (material.opacity > 0.1) {
				requestAnimationFrame(fallAnimation);
			} else {
				scene.remove(sat.mesh);
				satellites.delete(id);
			}
		};

		fallAnimation();
	}

	function animate() {
		animationId = requestAnimationFrame(animate);

		const time = Date.now() * 0.001;

		// Rotate core
		if (core) {
			core.rotation.y += 0.005;
			core.rotation.x = Math.sin(time * 0.5) * 0.1;
		}

		// Rotate background particles slowly
		if (particles) {
			particles.rotation.y += 0.0002;
		}

		// Update satellite positions
		satellites.forEach((sat) => {
			const config = LEVEL_CONFIG[sat.level];
			sat.angle += sat.speed * 0.01;

			sat.mesh.position.x = config.radius * Math.cos(sat.angle);
			sat.mesh.position.z = config.radius * Math.sin(sat.angle);
			sat.mesh.position.y = config.tilt * config.radius * Math.sin(sat.angle);

			// Slight bobbing
			sat.mesh.position.y += Math.sin(time * 2 + sat.angle) * 0.02;
		});

		// Update scan pulse
		updateScanPulse();

		// Random scan trigger for demo
		if (Math.random() > 0.998 && !isScanning) {
			triggerScanPulse();
		}

		renderer.render(scene, camera);
	}

	$effect(() => {
		if (renderer && camera) {
			renderer.setSize(width, height);
			camera.aspect = width / height;
			camera.updateProjectionMatrix();
		}
	});
</script>

<div class="orbital-tracker" bind:this={container} style:width="{width}px" style:height="{height}px">
</div>

<style>
	.orbital-tracker {
		position: relative;
		overflow: hidden;
	}

	.orbital-tracker :global(canvas) {
		display: block;
	}
</style>
