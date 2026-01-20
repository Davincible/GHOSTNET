<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import * as THREE from 'three';

	type SecurityLevel = 'VAULT' | 'MAINFRAME' | 'SUBNET' | 'DARKNET' | 'BLACK_ICE';

	interface RadarNode {
		id: string;
		level: SecurityLevel;
		angle: number;
		isCurrentUser?: boolean;
		status: 'active' | 'traced' | 'survived';
	}

	interface Props {
		width?: number;
		height?: number;
		sweepDuration?: number;
		nodes?: RadarNode[];
		currentScanProgress?: number;
	}

	let {
		width = 400,
		height = 400,
		sweepDuration = 10,
		nodes = [],
		currentScanProgress = 0
	}: Props = $props();

	let container: HTMLDivElement;
	let animationId: number;
	let scene: THREE.Scene;
	let camera: THREE.OrthographicCamera;
	let renderer: THREE.WebGLRenderer;
	let sweepLine: THREE.Mesh;
	let sweepTrail: THREE.Mesh;
	let sweepAngle = 0;
	let radarNodes: Map<string, { mesh: THREE.Mesh; node: RadarNode }> = new Map();
	let gridLines: THREE.LineSegments;

	const COLORS = {
		background: 0x030305,
		grid: 0x1a1a24,
		ring: 0x252532,
		sweep: 0x00e5cc,
		sweepTrail: 0x007a6b,
		vault: 0x00e5cc,
		mainframe: 0x00e5ff,
		subnet: 0xffb000,
		darknet: 0xff6633,
		blackIce: 0xff3366,
		traced: 0xff3366,
		survived: 0x00ff88,
		currentUser: 0xffffff
	};

	const LEVEL_RADIUS: Record<SecurityLevel, number> = {
		VAULT: 0.2,
		MAINFRAME: 0.4,
		SUBNET: 0.6,
		DARKNET: 0.8,
		BLACK_ICE: 0.95
	};

	const LEVEL_COLOR: Record<SecurityLevel, number> = {
		VAULT: COLORS.vault,
		MAINFRAME: COLORS.mainframe,
		SUBNET: COLORS.subnet,
		DARKNET: COLORS.darknet,
		BLACK_ICE: COLORS.blackIce
	};

	onMount(() => {
		init();
		createScene();
		animate();
	});

	onDestroy(() => {
		if (animationId) cancelAnimationFrame(animationId);
		if (renderer) renderer.dispose();
		radarNodes.clear();
	});

	function init() {
		scene = new THREE.Scene();

		const aspect = width / height;
		camera = new THREE.OrthographicCamera(-aspect, aspect, 1, -1, 0.1, 100);
		camera.position.z = 5;

		renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
		renderer.setSize(width, height);
		renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
		container.appendChild(renderer.domElement);
	}

	function createScene() {
		createRadarBase();
		createConcentricRings();
		createGridLines();
		createSweepLine();
		createNodes();
	}

	function createRadarBase() {
		// Radar background circle
		const geometry = new THREE.CircleGeometry(1, 64);
		const material = new THREE.MeshBasicMaterial({
			color: COLORS.background,
			transparent: true,
			opacity: 0.8
		});
		const base = new THREE.Mesh(geometry, material);
		base.position.z = -0.1;
		scene.add(base);

		// Outer ring border
		const ringGeometry = new THREE.RingGeometry(0.98, 1.0, 64);
		const ringMaterial = new THREE.MeshBasicMaterial({
			color: COLORS.ring,
			transparent: true,
			opacity: 0.6
		});
		const ring = new THREE.Mesh(ringGeometry, ringMaterial);
		scene.add(ring);
	}

	function createConcentricRings() {
		const levels: SecurityLevel[] = ['VAULT', 'MAINFRAME', 'SUBNET', 'DARKNET', 'BLACK_ICE'];

		levels.forEach((level) => {
			const radius = LEVEL_RADIUS[level];
			const segments = 64;
			const points: THREE.Vector3[] = [];

			for (let i = 0; i <= segments; i++) {
				const theta = (i / segments) * Math.PI * 2;
				points.push(new THREE.Vector3(
					radius * Math.cos(theta),
					radius * Math.sin(theta),
					0
				));
			}

			const geometry = new THREE.BufferGeometry().setFromPoints(points);
			const material = new THREE.LineBasicMaterial({
				color: LEVEL_COLOR[level],
				transparent: true,
				opacity: 0.3
			});

			const ring = new THREE.Line(geometry, material);
			scene.add(ring);
		});
	}

	function createGridLines() {
		const positions: number[] = [];
		const numLines = 8;

		// Radial lines
		for (let i = 0; i < numLines; i++) {
			const angle = (i / numLines) * Math.PI * 2;
			positions.push(0, 0, 0);
			positions.push(Math.cos(angle), Math.sin(angle), 0);
		}

		const geometry = new THREE.BufferGeometry();
		geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));

		const material = new THREE.LineBasicMaterial({
			color: COLORS.grid,
			transparent: true,
			opacity: 0.3
		});

		gridLines = new THREE.LineSegments(geometry, material);
		scene.add(gridLines);
	}

	function createSweepLine() {
		// Sweep trail (fading cone)
		const trailGeometry = new THREE.CircleGeometry(1, 32, 0, Math.PI / 4);
		const trailMaterial = new THREE.MeshBasicMaterial({
			color: COLORS.sweepTrail,
			transparent: true,
			opacity: 0.15,
			side: THREE.DoubleSide
		});
		sweepTrail = new THREE.Mesh(trailGeometry, trailMaterial);
		sweepTrail.position.z = 0.01;
		scene.add(sweepTrail);

		// Main sweep line
		const lineGeometry = new THREE.BufferGeometry();
		const linePositions = new Float32Array([0, 0, 0, 1, 0, 0]);
		lineGeometry.setAttribute('position', new THREE.BufferAttribute(linePositions, 3));

		const lineMaterial = new THREE.LineBasicMaterial({
			color: COLORS.sweep,
			transparent: true,
			opacity: 0.9
		});

		sweepLine = new THREE.Line(lineGeometry, lineMaterial) as unknown as THREE.Mesh;
		sweepLine.position.z = 0.02;
		scene.add(sweepLine);

		// Sweep line glow
		const glowGeometry = new THREE.PlaneGeometry(1, 0.02);
		const glowMaterial = new THREE.MeshBasicMaterial({
			color: COLORS.sweep,
			transparent: true,
			opacity: 0.4
		});
		const glow = new THREE.Mesh(glowGeometry, glowMaterial);
		glow.position.x = 0.5;
		sweepLine.add(glow);
	}

	function createNodes() {
		// Generate demo nodes if none provided
		const demoNodes: RadarNode[] = nodes.length > 0 ? nodes : generateDemoNodes(40);

		demoNodes.forEach((node) => {
			createNode(node);
		});
	}

	function generateDemoNodes(count: number): RadarNode[] {
		const levels: SecurityLevel[] = ['VAULT', 'MAINFRAME', 'SUBNET', 'DARKNET', 'BLACK_ICE'];
		const result: RadarNode[] = [];

		for (let i = 0; i < count; i++) {
			result.push({
				id: `node-${i}`,
				level: levels[Math.floor(Math.random() * levels.length)],
				angle: Math.random() * Math.PI * 2,
				isCurrentUser: i === 0,
				status: 'active'
			});
		}

		return result;
	}

	function createNode(node: RadarNode) {
		const radius = LEVEL_RADIUS[node.level];
		const size = node.isCurrentUser ? 0.035 : 0.02;

		const geometry = new THREE.CircleGeometry(size, 16);
		const material = new THREE.MeshBasicMaterial({
			color: node.isCurrentUser ? COLORS.currentUser : LEVEL_COLOR[node.level],
			transparent: true,
			opacity: 0.9
		});

		const mesh = new THREE.Mesh(geometry, material);
		mesh.position.x = radius * Math.cos(node.angle);
		mesh.position.y = radius * Math.sin(node.angle);
		mesh.position.z = 0.03;

		scene.add(mesh);

		// Add glow ring for current user
		if (node.isCurrentUser) {
			const ringGeometry = new THREE.RingGeometry(size * 1.5, size * 2, 16);
			const ringMaterial = new THREE.MeshBasicMaterial({
				color: COLORS.sweep,
				transparent: true,
				opacity: 0.5
			});
			const ring = new THREE.Mesh(ringGeometry, ringMaterial);
			mesh.add(ring);

			// Pulsing animation will be handled in animate()
		}

		radarNodes.set(node.id, { mesh, node });
	}

	function checkSweepCollision(nodeAngle: number): boolean {
		// Normalize angles to 0-2PI
		const normalizedSweep = ((sweepAngle % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
		const normalizedNode = ((nodeAngle % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);

		// Check if sweep just passed over node (within last few degrees)
		const diff = normalizedSweep - normalizedNode;
		return diff > 0 && diff < 0.1;
	}

	function handleNodeScan(nodeData: { mesh: THREE.Mesh; node: RadarNode }) {
		const material = nodeData.mesh.material as THREE.MeshBasicMaterial;

		// Random outcome
		const traced = Math.random() > 0.85;

		if (traced) {
			// Traced! Flash red and fade out
			material.color.setHex(COLORS.traced);
			nodeData.node.status = 'traced';

			// Particle explosion effect
			createExplosion(nodeData.mesh.position.x, nodeData.mesh.position.y);

			// Fade out
			const fadeOut = () => {
				material.opacity -= 0.05;
				if (material.opacity > 0) {
					requestAnimationFrame(fadeOut);
				} else {
					scene.remove(nodeData.mesh);
					radarNodes.delete(nodeData.node.id);
				}
			};
			fadeOut();
		} else {
			// Survived! Flash green
			const originalColor = nodeData.node.isCurrentUser ? COLORS.currentUser : LEVEL_COLOR[nodeData.node.level];
			material.color.setHex(COLORS.survived);
			nodeData.node.status = 'survived';

			setTimeout(() => {
				material.color.setHex(originalColor);
				nodeData.node.status = 'active';
			}, 500);
		}
	}

	function createExplosion(x: number, y: number) {
		const particleCount = 12;
		const particles: THREE.Mesh[] = [];

		for (let i = 0; i < particleCount; i++) {
			const geometry = new THREE.CircleGeometry(0.01, 8);
			const material = new THREE.MeshBasicMaterial({
				color: COLORS.traced,
				transparent: true,
				opacity: 1
			});
			const particle = new THREE.Mesh(geometry, material);
			particle.position.set(x, y, 0.04);

			const angle = (i / particleCount) * Math.PI * 2;
			const speed = 0.02 + Math.random() * 0.02;

			(particle as any).velocity = {
				x: Math.cos(angle) * speed,
				y: Math.sin(angle) * speed
			};

			scene.add(particle);
			particles.push(particle);
		}

		// Animate particles
		const animateParticles = () => {
			let allDone = true;

			particles.forEach((p) => {
				const vel = (p as any).velocity;
				p.position.x += vel.x;
				p.position.y += vel.y;
				(p.material as THREE.MeshBasicMaterial).opacity -= 0.03;

				if ((p.material as THREE.MeshBasicMaterial).opacity > 0) {
					allDone = false;
				} else {
					scene.remove(p);
				}
			});

			if (!allDone) {
				requestAnimationFrame(animateParticles);
			}
		};

		animateParticles();
	}

	function animate() {
		animationId = requestAnimationFrame(animate);

		const time = Date.now() * 0.001;

		// Rotate sweep line
		const sweepSpeed = (Math.PI * 2) / sweepDuration;
		sweepAngle += sweepSpeed / 60; // 60fps

		if (sweepLine) {
			sweepLine.rotation.z = sweepAngle;
		}
		if (sweepTrail) {
			sweepTrail.rotation.z = sweepAngle - Math.PI / 4;
		}

		// Check for sweep collisions
		radarNodes.forEach((nodeData) => {
			if (nodeData.node.status === 'active' && checkSweepCollision(nodeData.node.angle)) {
				handleNodeScan(nodeData);
			}
		});

		// Pulse current user node
		radarNodes.forEach((nodeData) => {
			if (nodeData.node.isCurrentUser && nodeData.mesh.children.length > 0) {
				const ring = nodeData.mesh.children[0] as THREE.Mesh;
				const scale = 1 + Math.sin(time * 3) * 0.2;
				ring.scale.set(scale, scale, 1);
			}
		});

		// Subtle grid rotation
		if (gridLines) {
			gridLines.rotation.z = Math.sin(time * 0.1) * 0.02;
		}

		renderer.render(scene, camera);
	}

	$effect(() => {
		if (renderer && camera) {
			renderer.setSize(width, height);
			const aspect = width / height;
			camera.left = -aspect;
			camera.right = aspect;
			camera.updateProjectionMatrix();
		}
	});
</script>

<div class="radar-sweep" bind:this={container} style:width="{width}px" style:height="{height}px">
</div>

<style>
	.radar-sweep {
		position: relative;
		overflow: hidden;
	}

	.radar-sweep :global(canvas) {
		display: block;
	}
</style>
