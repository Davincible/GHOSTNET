<script lang="ts">
  import { onMount } from 'svelte';
  import * as THREE from 'three';

  interface Props {
    width?: number;
    height?: number;
    particleCount?: number;
    color?: string;
    bgColor?: string;
    autoDissolve?: boolean;
  }

  let { 
    width = 400, 
    height = 400, 
    particleCount = 2000,
    color = '#00e5cc',
    bgColor = '#00e5cc',
    autoDissolve = true
  }: Props = $props();

  let container: HTMLDivElement;
  let animationId: number;
  
  // Store references to materials for color updates
  let rabbitMaterial = $state<THREE.ShaderMaterial | null>(null);
  let bgGlowMaterial = $state<THREE.ShaderMaterial | null>(null);
  
  // Update rabbit color when prop changes
  $effect(() => {
    if (rabbitMaterial && color) {
      rabbitMaterial.uniforms.uColor.value = new THREE.Color(color);
    }
  });
  
  // Update background color when prop changes
  $effect(() => {
    if (bgGlowMaterial && bgColor) {
      bgGlowMaterial.uniforms.uColor.value = new THREE.Color(bgColor);
    }
  });

  // Generate rabbit shape points procedurally
  function generateRabbitPoints(count: number): Float32Array {
    const positions = new Float32Array(count * 3);
    let i = 0;

    // Helper to add point with some noise (tighter spread for better definition)
    const addPoint = (x: number, y: number, z: number, spread: number = 0.025) => {
      if (i >= count * 3) return;
      positions[i++] = x + (Math.random() - 0.5) * spread;
      positions[i++] = y + (Math.random() - 0.5) * spread;
      positions[i++] = z + (Math.random() - 0.5) * spread;
    };

    // Helper to check if point is inside ellipsoid
    const inEllipsoid = (x: number, y: number, z: number, cx: number, cy: number, cz: number, rx: number, ry: number, rz: number) => {
      return ((x - cx) ** 2 / rx ** 2 + (y - cy) ** 2 / ry ** 2 + (z - cz) ** 2 / rz ** 2) <= 1;
    };

    // Body - main ellipsoid
    const bodyPoints = Math.floor(count * 0.35);
    for (let j = 0; j < bodyPoints; j++) {
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.acos(2 * Math.random() - 1);
      const r = Math.cbrt(Math.random()); // Cubic root for uniform volume distribution
      const x = r * 0.6 * Math.sin(phi) * Math.cos(theta);
      const y = r * 0.45 * Math.sin(phi) * Math.sin(theta) - 0.2;
      const z = r * 0.5 * Math.cos(phi);
      addPoint(x, y, z, 0.018);
    }

    // Head - sphere
    const headPoints = Math.floor(count * 0.25);
    for (let j = 0; j < headPoints; j++) {
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.acos(2 * Math.random() - 1);
      const r = Math.cbrt(Math.random()) * 0.35;
      const x = r * Math.sin(phi) * Math.cos(theta);
      const y = r * Math.sin(phi) * Math.sin(theta) + 0.45;
      const z = r * Math.cos(phi) + 0.15;
      addPoint(x, y, z, 0.012);
    }

    // Left ear
    const earPoints = Math.floor(count * 0.12);
    for (let j = 0; j < earPoints; j++) {
      const t = Math.random();
      const earLength = 0.55;
      const earWidth = 0.08 * (1 - t * 0.6); // Taper toward tip
      const angle = Math.random() * Math.PI * 2;
      const x = -0.15 + Math.cos(angle) * earWidth * 0.5;
      const y = 0.7 + t * earLength;
      const z = 0.15 + Math.sin(angle) * earWidth + t * 0.1;
      addPoint(x, y, z, 0.012);
    }

    // Right ear
    for (let j = 0; j < earPoints; j++) {
      const t = Math.random();
      const earLength = 0.55;
      const earWidth = 0.08 * (1 - t * 0.6);
      const angle = Math.random() * Math.PI * 2;
      const x = 0.15 + Math.cos(angle) * earWidth * 0.5;
      const y = 0.7 + t * earLength;
      const z = 0.15 + Math.sin(angle) * earWidth + t * 0.1;
      addPoint(x, y, z, 0.012);
    }

    // Tail - small fluffy ball
    const tailPoints = Math.floor(count * 0.08);
    for (let j = 0; j < tailPoints; j++) {
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.acos(2 * Math.random() - 1);
      const r = Math.cbrt(Math.random()) * 0.12;
      const x = r * Math.sin(phi) * Math.cos(theta);
      const y = r * Math.sin(phi) * Math.sin(theta) - 0.55;
      const z = r * Math.cos(phi) - 0.35;
      addPoint(x, y, z, 0.025);
    }

    // Front legs (subtle)
    const legPoints = Math.floor(count * 0.04);
    for (let j = 0; j < legPoints; j++) {
      const t = Math.random();
      const x = -0.2 + (Math.random() - 0.5) * 0.08;
      const y = -0.3 - t * 0.3;
      const z = 0.25 + (Math.random() - 0.5) * 0.08;
      addPoint(x, y, z, 0.012);
    }
    for (let j = 0; j < legPoints; j++) {
      const t = Math.random();
      const x = 0.2 + (Math.random() - 0.5) * 0.08;
      const y = -0.3 - t * 0.3;
      const z = 0.25 + (Math.random() - 0.5) * 0.08;
      addPoint(x, y, z, 0.012);
    }

    return positions;
  }

  onMount(() => {
    // Scene setup
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(50, width / height, 0.1, 100);
    camera.position.set(0, 0.2, 2.5);
    camera.lookAt(0, 0.1, 0);

    const renderer = new THREE.WebGLRenderer({ 
      antialias: true, 
      alpha: true 
    });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    container.appendChild(renderer.domElement);

    // Create particle system
    const geometry = new THREE.BufferGeometry();
    const positions = generateRabbitPoints(particleCount);
    const originalPositions = new Float32Array(positions);
    const velocities = new Float32Array(particleCount * 3);
    const phases = new Float32Array(particleCount); // For individual particle animation

    // Initialize velocities and phases
    for (let i = 0; i < particleCount; i++) {
      velocities[i * 3] = (Math.random() - 0.5) * 0.02;
      velocities[i * 3 + 1] = (Math.random() - 0.5) * 0.02;
      velocities[i * 3 + 2] = (Math.random() - 0.5) * 0.02;
      phases[i] = Math.random() * Math.PI * 2;
    }

    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));

    // Custom shader material for glowing particles
    const material = new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uColor: { value: new THREE.Color(color) },
        uDissolve: { value: 0 },
        uPixelRatio: { value: renderer.getPixelRatio() }
      },
      vertexShader: `
        uniform float uTime;
        uniform float uDissolve;
        uniform float uPixelRatio;
        
        attribute float phase;
        
        varying float vAlpha;
        varying float vDistance;
        
        void main() {
          vec3 pos = position;
          
          // Breathing/floating effect (subtle for better definition)
          float breath = sin(uTime * 2.0 + phase) * 0.008;
          pos += normalize(pos) * breath;
          
          // Dissolve effect - particles drift away
          if (uDissolve > 0.0) {
            vec3 drift = normalize(pos + vec3(
              sin(phase * 10.0),
              cos(phase * 7.0),
              sin(phase * 13.0)
            )) * uDissolve * 2.0;
            pos += drift;
          }
          
          vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);
          gl_Position = projectionMatrix * mvPosition;
          
          // Size attenuation (larger particles for better definition)
          float size = 4.5 * uPixelRatio;
          gl_PointSize = size * (1.0 / -mvPosition.z);
          
          // Alpha based on dissolve and distance
          vAlpha = 1.0 - uDissolve * 0.8;
          vDistance = length(pos);
        }
      `,
      fragmentShader: `
        uniform vec3 uColor;
        uniform float uTime;
        
        varying float vAlpha;
        varying float vDistance;
        
        void main() {
          // Circular point with soft edge
          vec2 center = gl_PointCoord - 0.5;
          float dist = length(center);
          if (dist > 0.5) discard;
          
          // Glow effect (sharper edge for better definition)
          float glow = 1.0 - dist * 2.0;
          glow = pow(glow, 1.2);
          
          // Flicker (reduced for more solid appearance)
          float flicker = 0.9 + 0.1 * sin(uTime * 10.0 + vDistance * 20.0);
          
          // Edge fade - particles fade out as they drift further from center
          // Start fading at distance 1.0, fully transparent by 2.5
          float edgeFade = 1.0 - smoothstep(1.0, 2.5, vDistance);
          
          vec3 finalColor = uColor * glow * flicker;
          float alpha = glow * vAlpha * flicker * edgeFade;
          
          gl_FragColor = vec4(finalColor, alpha);
        }
      `,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending
    });

    // Add phase attribute
    geometry.setAttribute('phase', new THREE.BufferAttribute(phases, 1));

    const particles = new THREE.Points(geometry, material);
    scene.add(particles);
    
    // Store reference for reactive color updates
    rabbitMaterial = material;

    // Add subtle glow plane behind rabbit (background color - reactive)
    const glowGeometry = new THREE.PlaneGeometry(2, 2);
    const glowMaterial = new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uColor: { value: new THREE.Color(bgColor) }
      },
      vertexShader: `
        varying vec2 vUv;
        void main() {
          vUv = uv;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform float uTime;
        uniform vec3 uColor;
        varying vec2 vUv;
        
        void main() {
          vec2 center = vUv - 0.5;
          float dist = length(center);
          
          // Radial gradient glow
          float glow = 1.0 - smoothstep(0.0, 0.5, dist);
          glow = pow(glow, 3.0) * 0.15;
          
          // Pulse
          glow *= 0.8 + 0.2 * sin(uTime * 1.5);
          
          gl_FragColor = vec4(uColor * glow, glow);
        }
      `,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending
    });
    const glowPlane = new THREE.Mesh(glowGeometry, glowMaterial);
    glowPlane.position.z = -0.5;
    scene.add(glowPlane);
    
    // Store reference for reactive background color updates
    bgGlowMaterial = glowMaterial;

    // Animation state
    let dissolveDirection = 1;
    let dissolveValue = 0;
    let lastDissolveTime = 0;
    const dissolveCycleDuration = 8000; // ms for full cycle

    // Animation loop
    const clock = new THREE.Clock();
    
    function animate() {
      animationId = requestAnimationFrame(animate);
      
      const elapsed = clock.getElapsedTime();
      
      // Update uniforms
      material.uniforms.uTime.value = elapsed;
      glowMaterial.uniforms.uTime.value = elapsed;
      
      // Auto dissolve cycle
      if (autoDissolve) {
        const cycleTime = (elapsed * 1000) % dissolveCycleDuration;
        const cycleProgress = cycleTime / dissolveCycleDuration;
        
        // Animation flow: dissolved → slow reform → brief peak → dissolve out
        if (cycleProgress < 0.20) {
          // Dissolved/floating phase
          dissolveValue = 1;
        } else if (cycleProgress < 0.55) {
          // Slowly reforming (35% of cycle = 2.8s)
          const reformProgress = (cycleProgress - 0.20) / 0.35;
          // Ease-out for satisfying coalesce
          dissolveValue = 1 - Math.pow(reformProgress, 0.7);
        } else if (cycleProgress < 0.70) {
          // Brief solid/peak phase (15% of cycle = 1.2s)
          dissolveValue = 0;
        } else {
          // Dissolving back out (30% of cycle = 2.4s)
          const dissolveProgress = (cycleProgress - 0.70) / 0.30;
          // Ease-in for gentle start
          dissolveValue = Math.pow(dissolveProgress, 1.5);
        }
        
        material.uniforms.uDissolve.value = dissolveValue;
      }
      
      // Gentle rotation
      particles.rotation.y = Math.sin(elapsed * 0.3) * 0.3;
      glowPlane.rotation.y = particles.rotation.y;
      
      renderer.render(scene, camera);
    }
    
    animate();

    // Cleanup
    return () => {
      cancelAnimationFrame(animationId);
      renderer.dispose();
      geometry.dispose();
      material.dispose();
      glowMaterial.dispose();
      glowGeometry.dispose();
      if (container && renderer.domElement) {
        container.removeChild(renderer.domElement);
      }
    };
  });
</script>

<div 
  bind:this={container} 
  class="rabbit-particles"
  style="width: {width}px; height: {height}px;"
></div>

<style>
  .rabbit-particles {
    position: relative;
    background: transparent;
    border-radius: 4px;
    overflow: hidden;
  }

  .rabbit-particles :global(canvas) {
    display: block;
  }
</style>
