<script lang="ts">
  import { onMount } from 'svelte';
  import * as THREE from 'three';

  interface Props {
    width?: number;
    height?: number;
    color?: string;
    pulseSpeed?: number;
  }

  let { 
    width = 400, 
    height = 400, 
    color = '#00e5cc',
    pulseSpeed = 1
  }: Props = $props();

  let container: HTMLDivElement;
  let animationId: number;

  // Generate rabbit outline points for line drawing
  function generateRabbitOutline(): THREE.Vector3[][] {
    const paths: THREE.Vector3[][] = [];
    
    // Helper to create smooth curve
    const createCurve = (points: [number, number, number][]): THREE.Vector3[] => {
      return points.map(p => new THREE.Vector3(p[0], p[1], p[2]));
    };

    // Body outline (side view, will be extruded)
    const bodyOutline = createCurve([
      [-0.3, -0.3, 0], [-0.4, -0.1, 0], [-0.45, 0.1, 0], [-0.4, 0.25, 0],
      [-0.3, 0.35, 0], [-0.15, 0.4, 0], [0, 0.42, 0], [0.15, 0.4, 0],
      [0.3, 0.35, 0], [0.4, 0.25, 0], [0.45, 0.1, 0], [0.4, -0.1, 0],
      [0.3, -0.3, 0], [0, -0.35, 0], [-0.3, -0.3, 0]
    ]);
    paths.push(bodyOutline);

    // Head outline
    const headOutline = createCurve([
      [-0.2, 0.35, 0.1], [-0.25, 0.45, 0.15], [-0.25, 0.55, 0.2],
      [-0.2, 0.65, 0.2], [-0.1, 0.7, 0.2], [0, 0.72, 0.2],
      [0.1, 0.7, 0.2], [0.2, 0.65, 0.2], [0.25, 0.55, 0.2],
      [0.25, 0.45, 0.15], [0.2, 0.35, 0.1], [0, 0.32, 0.08],
      [-0.2, 0.35, 0.1]
    ]);
    paths.push(headOutline);

    // Left ear
    const leftEar = createCurve([
      [-0.15, 0.65, 0.2], [-0.18, 0.75, 0.22], [-0.2, 0.9, 0.25],
      [-0.18, 1.05, 0.25], [-0.12, 1.15, 0.22], [-0.08, 1.1, 0.2],
      [-0.1, 0.95, 0.18], [-0.12, 0.8, 0.18], [-0.1, 0.68, 0.2]
    ]);
    paths.push(leftEar);

    // Right ear  
    const rightEar = createCurve([
      [0.15, 0.65, 0.2], [0.18, 0.75, 0.22], [0.2, 0.9, 0.25],
      [0.18, 1.05, 0.25], [0.12, 1.15, 0.22], [0.08, 1.1, 0.2],
      [0.1, 0.95, 0.18], [0.12, 0.8, 0.18], [0.1, 0.68, 0.2]
    ]);
    paths.push(rightEar);

    // Tail (fluffy puff)
    const tail = createCurve([
      [-0.35, -0.15, -0.15], [-0.4, -0.1, -0.2], [-0.45, -0.05, -0.18],
      [-0.42, 0, -0.12], [-0.38, -0.05, -0.08], [-0.35, -0.12, -0.1],
      [-0.35, -0.15, -0.15]
    ]);
    paths.push(tail);

    // Eye outlines (simple circles)
    const leftEye: THREE.Vector3[] = [];
    const rightEye: THREE.Vector3[] = [];
    for (let i = 0; i <= 16; i++) {
      const angle = (i / 16) * Math.PI * 2;
      const r = 0.04;
      leftEye.push(new THREE.Vector3(
        -0.08 + Math.cos(angle) * r,
        0.55 + Math.sin(angle) * r,
        0.25
      ));
      rightEye.push(new THREE.Vector3(
        0.08 + Math.cos(angle) * r,
        0.55 + Math.sin(angle) * r,
        0.25
      ));
    }
    paths.push(leftEye);
    paths.push(rightEye);

    // Nose (triangle)
    const nose = createCurve([
      [0, 0.48, 0.28], [-0.03, 0.44, 0.26], [0.03, 0.44, 0.26], [0, 0.48, 0.28]
    ]);
    paths.push(nose);

    // Whiskers
    const whiskerL1 = createCurve([[-0.05, 0.46, 0.26], [-0.25, 0.5, 0.2]]);
    const whiskerL2 = createCurve([[-0.05, 0.44, 0.26], [-0.28, 0.44, 0.2]]);
    const whiskerL3 = createCurve([[-0.05, 0.42, 0.26], [-0.25, 0.38, 0.2]]);
    const whiskerR1 = createCurve([[0.05, 0.46, 0.26], [0.25, 0.5, 0.2]]);
    const whiskerR2 = createCurve([[0.05, 0.44, 0.26], [0.28, 0.44, 0.2]]);
    const whiskerR3 = createCurve([[0.05, 0.42, 0.26], [0.25, 0.38, 0.2]]);
    paths.push(whiskerL1, whiskerL2, whiskerL3, whiskerR1, whiskerR2, whiskerR3);

    // Front legs
    const leftFrontLeg = createCurve([
      [-0.2, -0.25, 0.08], [-0.22, -0.4, 0.1], [-0.2, -0.5, 0.12],
      [-0.15, -0.52, 0.12], [-0.12, -0.48, 0.1]
    ]);
    const rightFrontLeg = createCurve([
      [0.2, -0.25, 0.08], [0.22, -0.4, 0.1], [0.2, -0.5, 0.12],
      [0.15, -0.52, 0.12], [0.12, -0.48, 0.1]
    ]);
    paths.push(leftFrontLeg, rightFrontLeg);

    // Back legs (bigger)
    const leftBackLeg = createCurve([
      [-0.25, -0.28, -0.08], [-0.35, -0.38, -0.1], [-0.38, -0.5, -0.08],
      [-0.32, -0.55, -0.05], [-0.25, -0.52, -0.02]
    ]);
    const rightBackLeg = createCurve([
      [0.25, -0.28, -0.08], [0.35, -0.38, -0.1], [0.38, -0.5, -0.08],
      [0.32, -0.55, -0.05], [0.25, -0.52, -0.02]
    ]);
    paths.push(leftBackLeg, rightBackLeg);

    // Grid lines on body for extra Tron feel
    for (let i = -0.2; i <= 0.2; i += 0.1) {
      const verticalLine = createCurve([
        [i, -0.3, 0], [i, 0.3, 0]
      ]);
      paths.push(verticalLine);
    }
    for (let i = -0.2; i <= 0.3; i += 0.1) {
      const horizontalLine = createCurve([
        [-0.35, i, 0], [0.35, i, 0]
      ]);
      paths.push(horizontalLine);
    }

    return paths;
  }

  onMount(() => {
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(50, width / height, 0.1, 100);
    camera.position.set(0, 0.3, 2);
    camera.lookAt(0, 0.2, 0);

    const renderer = new THREE.WebGLRenderer({ 
      antialias: true, 
      alpha: true 
    });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    container.appendChild(renderer.domElement);

    // Create line material with glow effect
    const lineMaterial = new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uColor: { value: new THREE.Color(color) },
        uPulseSpeed: { value: pulseSpeed }
      },
      vertexShader: `
        attribute float lineDistance;
        varying float vLineDistance;
        varying vec3 vPosition;
        
        void main() {
          vLineDistance = lineDistance;
          vPosition = position;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform float uTime;
        uniform vec3 uColor;
        uniform float uPulseSpeed;
        
        varying float vLineDistance;
        varying vec3 vPosition;
        
        void main() {
          // Traveling pulse effect
          float pulse = sin(vLineDistance * 10.0 - uTime * uPulseSpeed * 5.0) * 0.5 + 0.5;
          pulse = pow(pulse, 3.0);
          
          // Base glow
          float glow = 0.6 + pulse * 0.4;
          
          // Distance-based intensity variation
          float distFactor = 0.8 + 0.2 * sin(vPosition.y * 5.0 + uTime * 2.0);
          
          vec3 finalColor = uColor * glow * distFactor;
          
          // Add white hot spots
          float hotspot = step(0.95, pulse) * 0.5;
          finalColor += vec3(hotspot);
          
          gl_FragColor = vec4(finalColor, 0.9);
        }
      `,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending
    });

    // Create lines from paths
    const paths = generateRabbitOutline();
    const lineGroup = new THREE.Group();
    
    paths.forEach(pathPoints => {
      // Create geometry with line distances for animated pulse
      const geometry = new THREE.BufferGeometry();
      const positions: number[] = [];
      const lineDistances: number[] = [];
      let totalDistance = 0;
      
      for (let i = 0; i < pathPoints.length; i++) {
        positions.push(pathPoints[i].x, pathPoints[i].y, pathPoints[i].z);
        lineDistances.push(totalDistance);
        
        if (i < pathPoints.length - 1) {
          totalDistance += pathPoints[i].distanceTo(pathPoints[i + 1]);
        }
      }
      
      geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
      geometry.setAttribute('lineDistance', new THREE.Float32BufferAttribute(lineDistances, 1));
      
      const line = new THREE.Line(geometry, lineMaterial);
      lineGroup.add(line);
    });

    scene.add(lineGroup);

    // Add glow sphere behind rabbit
    const glowGeometry = new THREE.SphereGeometry(0.8, 32, 32);
    const glowMaterial = new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uColor: { value: new THREE.Color(color) }
      },
      vertexShader: `
        varying vec3 vNormal;
        varying vec3 vPosition;
        void main() {
          vNormal = normalize(normalMatrix * normal);
          vPosition = position;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform vec3 uColor;
        uniform float uTime;
        varying vec3 vNormal;
        varying vec3 vPosition;
        
        void main() {
          // Fresnel-like glow
          float intensity = pow(0.7 - dot(vNormal, vec3(0.0, 0.0, 1.0)), 2.0);
          intensity *= 0.15 + 0.05 * sin(uTime * 2.0);
          
          // Grid pattern
          float gridX = step(0.95, fract(vPosition.x * 10.0 + uTime * 0.5));
          float gridY = step(0.95, fract(vPosition.y * 10.0 + uTime * 0.5));
          float grid = max(gridX, gridY) * 0.3;
          
          gl_FragColor = vec4(uColor, intensity + grid * intensity);
        }
      `,
      transparent: true,
      side: THREE.BackSide,
      depthWrite: false,
      blending: THREE.AdditiveBlending
    });
    
    const glowMesh = new THREE.Mesh(glowGeometry, glowMaterial);
    glowMesh.position.y = 0.2;
    scene.add(glowMesh);

    // Add floor grid for Tron aesthetic
    const gridHelper = new THREE.GridHelper(3, 20, new THREE.Color(color).multiplyScalar(0.3), new THREE.Color(color).multiplyScalar(0.15));
    gridHelper.position.y = -0.6;
    scene.add(gridHelper);

    // Add scan ring
    const ringGeometry = new THREE.RingGeometry(0.5, 0.52, 64);
    const ringMaterial = new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uColor: { value: new THREE.Color(color) }
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
          float angle = atan(vUv.y - 0.5, vUv.x - 0.5);
          float sweep = mod(angle + uTime * 2.0, 6.28318) / 6.28318;
          float intensity = pow(1.0 - sweep, 3.0);
          gl_FragColor = vec4(uColor * intensity, intensity * 0.5);
        }
      `,
      transparent: true,
      side: THREE.DoubleSide,
      depthWrite: false,
      blending: THREE.AdditiveBlending
    });
    
    const ring = new THREE.Mesh(ringGeometry, ringMaterial);
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = -0.59;
    scene.add(ring);

    // Animation
    const clock = new THREE.Clock();
    
    function animate() {
      animationId = requestAnimationFrame(animate);
      
      const elapsed = clock.getElapsedTime();
      
      // Update uniforms
      lineMaterial.uniforms.uTime.value = elapsed;
      glowMaterial.uniforms.uTime.value = elapsed;
      ringMaterial.uniforms.uTime.value = elapsed;
      
      // Gentle rotation
      lineGroup.rotation.y = Math.sin(elapsed * 0.4) * 0.4;
      glowMesh.rotation.y = lineGroup.rotation.y;
      
      // Hover effect
      lineGroup.position.y = Math.sin(elapsed * 1.2) * 0.03;
      glowMesh.position.y = 0.2 + lineGroup.position.y;
      
      // Scale pulse
      const scale = 1 + Math.sin(elapsed * 2) * 0.02;
      lineGroup.scale.setScalar(scale);
      
      renderer.render(scene, camera);
    }
    
    animate();

    return () => {
      cancelAnimationFrame(animationId);
      renderer.dispose();
      lineMaterial.dispose();
      glowMaterial.dispose();
      glowGeometry.dispose();
      ringGeometry.dispose();
      ringMaterial.dispose();
      if (container && renderer.domElement) {
        container.removeChild(renderer.domElement);
      }
    };
  });
</script>

<div 
  bind:this={container} 
  class="rabbit-wireframe"
  style="width: {width}px; height: {height}px;"
></div>

<style>
  .rabbit-wireframe {
    position: relative;
    background: transparent;
    border-radius: 4px;
    overflow: hidden;
  }

  .rabbit-wireframe :global(canvas) {
    display: block;
  }
</style>
