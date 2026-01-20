<script lang="ts">
  import { onMount } from 'svelte';
  import * as THREE from 'three';

  interface Props {
    width?: number;
    height?: number;
    voxelSize?: number;
    color?: string;
    glitchIntensity?: number;
  }

  let { 
    width = 400, 
    height = 400, 
    voxelSize = 0.08,
    color = '#00e5cc',
    glitchIntensity = 0.3
  }: Props = $props();

  let container: HTMLDivElement;
  let animationId: number;
  
  // Store references to rabbit materials for color updates
  let rabbitVoxelMaterial = $state<THREE.ShaderMaterial | null>(null);
  let rabbitWireframeMaterial = $state<THREE.ShaderMaterial | null>(null);
  
  // Update rabbit color when prop changes (only rabbit, not background glow)
  $effect(() => {
    if (color) {
      const newColor = new THREE.Color(color);
      if (rabbitVoxelMaterial) {
        rabbitVoxelMaterial.uniforms.uColor.value = newColor;
      }
      if (rabbitWireframeMaterial) {
        rabbitWireframeMaterial.uniforms.uColor.value = newColor;
      }
    }
  });

  // Define rabbit as 3D voxel grid (1 = filled, 0 = empty)
  // Grid is 16 wide (x) x 24 tall (y) x 12 deep (z)
  function generateVoxelData(): { x: number; y: number; z: number }[] {
    const voxels: { x: number; y: number; z: number }[] = [];
    
    // Helper to add voxel (centered coordinates)
    const add = (x: number, y: number, z: number) => {
      voxels.push({ x: x - 8, y: y - 12, z: z - 6 });
    };

    // Body (ellipsoid approximation) - layers 4-12 on Y axis
    for (let y = 4; y <= 11; y++) {
      const yNorm = (y - 7.5) / 3.5; // -1 to 1
      const radiusX = Math.sqrt(1 - yNorm * yNorm) * 4;
      const radiusZ = Math.sqrt(1 - yNorm * yNorm) * 3;
      
      for (let x = Math.floor(8 - radiusX); x <= Math.ceil(8 + radiusX); x++) {
        for (let z = Math.floor(6 - radiusZ); z <= Math.ceil(6 + radiusZ); z++) {
          const dx = (x - 8) / 4;
          const dz = (z - 6) / 3;
          if (dx * dx + dz * dz + yNorm * yNorm <= 1.1) {
            add(x, y, z);
          }
        }
      }
    }

    // Head (sphere) - layers 12-18
    for (let y = 12; y <= 17; y++) {
      const yNorm = (y - 14.5) / 2.5;
      const radius = Math.sqrt(Math.max(0, 1 - yNorm * yNorm)) * 2.5;
      
      for (let x = Math.floor(8 - radius); x <= Math.ceil(8 + radius); x++) {
        for (let z = Math.floor(7 - radius); z <= Math.ceil(7 + radius); z++) {
          const dx = (x - 8) / 2.5;
          const dz = (z - 7) / 2.5;
          if (dx * dx + dz * dz + yNorm * yNorm <= 1.1) {
            add(x, y, z);
          }
        }
      }
    }

    // Left ear
    for (let y = 17; y <= 23; y++) {
      const taper = 1 - (y - 17) / 7;
      const w = Math.max(1, Math.floor(taper * 2));
      for (let x = 5; x <= 5 + w; x++) {
        for (let z = 7; z <= 8; z++) {
          add(x, y, z);
        }
      }
    }

    // Right ear
    for (let y = 17; y <= 23; y++) {
      const taper = 1 - (y - 17) / 7;
      const w = Math.max(1, Math.floor(taper * 2));
      for (let x = 10 - w; x <= 10; x++) {
        for (let z = 7; z <= 8; z++) {
          add(x, y, z);
        }
      }
    }

    // Tail (small puff)
    for (let y = 5; y <= 7; y++) {
      for (let x = 7; x <= 9; x++) {
        for (let z = 2; z <= 3; z++) {
          add(x, y, z);
        }
      }
    }

    // Eyes (dark spots - we'll handle these differently in rendering)
    // Left eye at approximately (6, 15, 9)
    // Right eye at approximately (10, 15, 9)

    // Front paws
    for (let y = 2; y <= 4; y++) {
      add(6, y, 8);
      add(10, y, 8);
    }

    // Back paws (bigger)
    for (let y = 2; y <= 4; y++) {
      for (let x = 5; x <= 6; x++) {
        add(x, y, 4);
      }
      for (let x = 10; x <= 11; x++) {
        add(x, y, 4);
      }
    }

    return voxels;
  }

  onMount(() => {
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(50, width / height, 0.1, 100);
    camera.position.set(2, 1, 3);
    camera.lookAt(0, 0, 0);

    const renderer = new THREE.WebGLRenderer({ 
      antialias: true, 
      alpha: true 
    });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    container.appendChild(renderer.domElement);

    // Create instanced mesh for voxels
    const voxelData = generateVoxelData();
    const cubeGeometry = new THREE.BoxGeometry(voxelSize * 0.9, voxelSize * 0.9, voxelSize * 0.9);
    
    // Custom shader material for glowing voxels
    const voxelMaterial = new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uColor: { value: new THREE.Color(color) },
        uGlitchIntensity: { value: glitchIntensity }
      },
      vertexShader: `
        varying vec3 vNormal;
        varying vec3 vPosition;
        varying float vGlitch;
        
        uniform float uTime;
        uniform float uGlitchIntensity;
        
        void main() {
          vNormal = normalize(normalMatrix * normal);
          vPosition = position;
          
          // Random glitch offset per instance
          float glitchSeed = dot(instanceMatrix[3].xyz, vec3(12.9898, 78.233, 45.164));
          float glitchRand = fract(sin(glitchSeed) * 43758.5453);
          
          // Periodic glitch
          float glitchTime = floor(uTime * 8.0 + glitchRand * 10.0);
          float glitch = step(0.95 - uGlitchIntensity * 0.1, fract(sin(glitchTime * glitchRand) * 43758.5453));
          vGlitch = glitch;
          
          vec4 worldPos = instanceMatrix * vec4(position, 1.0);
          
          // Apply glitch displacement
          if (glitch > 0.5) {
            worldPos.x += (fract(sin(glitchTime * 1.1) * 43758.5453) - 0.5) * 0.2;
            worldPos.y += (fract(sin(glitchTime * 2.2) * 43758.5453) - 0.5) * 0.1;
          }
          
          gl_Position = projectionMatrix * viewMatrix * worldPos;
        }
      `,
      fragmentShader: `
        uniform vec3 uColor;
        uniform float uTime;
        
        varying vec3 vNormal;
        varying vec3 vPosition;
        varying float vGlitch;
        
        void main() {
          // Edge glow effect
          float edge = 1.0 - abs(dot(vNormal, vec3(0.0, 0.0, 1.0)));
          edge = pow(edge, 2.0);
          
          // Scan line effect
          float scanline = sin(vPosition.y * 50.0 + uTime * 5.0) * 0.5 + 0.5;
          scanline = 0.9 + scanline * 0.1;
          
          // Base color with edge highlight
          vec3 baseColor = uColor * (0.6 + edge * 0.4);
          
          // Glitch color shift
          vec3 glitchColor = vec3(uColor.g, uColor.b, uColor.r); // Color shift
          vec3 finalColor = mix(baseColor, glitchColor, vGlitch * 0.5);
          
          // Apply scanline
          finalColor *= scanline;
          
          // Brightness pulse
          float pulse = 0.9 + 0.1 * sin(uTime * 2.0);
          finalColor *= pulse;
          
          gl_FragColor = vec4(finalColor, 0.95);
        }
      `,
      transparent: true
    });

    const instancedMesh = new THREE.InstancedMesh(cubeGeometry, voxelMaterial, voxelData.length);
    
    // Set instance matrices
    const matrix = new THREE.Matrix4();
    const originalPositions: THREE.Vector3[] = [];
    
    voxelData.forEach((voxel, i) => {
      const pos = new THREE.Vector3(
        voxel.x * voxelSize,
        voxel.y * voxelSize,
        voxel.z * voxelSize
      );
      originalPositions.push(pos.clone());
      matrix.setPosition(pos);
      instancedMesh.setMatrixAt(i, matrix);
    });
    
    instancedMesh.instanceMatrix.needsUpdate = true;
    scene.add(instancedMesh);
    
    // Store reference for reactive color updates
    rabbitVoxelMaterial = voxelMaterial;

    // Add wireframe outline for extra retro feel (also part of rabbit)
    const wireframeMaterial = new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uColor: { value: new THREE.Color(color) }
      },
      vertexShader: `
        void main() {
          vec4 worldPos = instanceMatrix * vec4(position, 1.0);
          gl_Position = projectionMatrix * viewMatrix * worldPos;
        }
      `,
      fragmentShader: `
        uniform vec3 uColor;
        uniform float uTime;
        
        void main() {
          float pulse = 0.3 + 0.2 * sin(uTime * 3.0);
          gl_FragColor = vec4(uColor * pulse, 0.5);
        }
      `,
      transparent: true,
      wireframe: true
    });
    
    const wireframeGeometry = new THREE.BoxGeometry(voxelSize, voxelSize, voxelSize);
    const wireframeMesh = new THREE.InstancedMesh(wireframeGeometry, wireframeMaterial, voxelData.length);
    
    voxelData.forEach((voxel, i) => {
      matrix.setPosition(
        voxel.x * voxelSize,
        voxel.y * voxelSize,
        voxel.z * voxelSize
      );
      wireframeMesh.setMatrixAt(i, matrix);
    });
    wireframeMesh.instanceMatrix.needsUpdate = true;
    scene.add(wireframeMesh);
    
    // Store reference for reactive color updates
    rabbitWireframeMaterial = wireframeMaterial;

    // Add ambient glow (fixed color - doesn't change)
    const fixedAccentColor = '#00e5cc';
    const glowGeometry = new THREE.SphereGeometry(1.2, 32, 32);
    const glowMaterial = new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uColor: { value: new THREE.Color(fixedAccentColor) }
      },
      vertexShader: `
        varying vec3 vNormal;
        void main() {
          vNormal = normalize(normalMatrix * normal);
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform vec3 uColor;
        uniform float uTime;
        varying vec3 vNormal;
        
        void main() {
          float intensity = pow(0.6 - dot(vNormal, vec3(0.0, 0.0, 1.0)), 3.0);
          intensity *= 0.15 + 0.05 * sin(uTime * 2.0);
          gl_FragColor = vec4(uColor, intensity);
        }
      `,
      transparent: true,
      side: THREE.BackSide,
      depthWrite: false,
      blending: THREE.AdditiveBlending
    });
    
    const glowMesh = new THREE.Mesh(glowGeometry, glowMaterial);
    scene.add(glowMesh);

    // Group for rotation
    const group = new THREE.Group();
    group.add(instancedMesh);
    group.add(wireframeMesh);
    group.add(glowMesh);
    scene.add(group);
    scene.remove(instancedMesh);
    scene.remove(wireframeMesh);
    scene.remove(glowMesh);

    // Animation
    const clock = new THREE.Clock();
    
    function animate() {
      animationId = requestAnimationFrame(animate);
      
      const elapsed = clock.getElapsedTime();
      
      // Update shader uniforms
      voxelMaterial.uniforms.uTime.value = elapsed;
      wireframeMaterial.uniforms.uTime.value = elapsed;
      glowMaterial.uniforms.uTime.value = elapsed;
      
      // Gentle rotation
      group.rotation.y = Math.sin(elapsed * 0.5) * 0.5;
      group.rotation.x = Math.sin(elapsed * 0.3) * 0.1;
      
      // Hover/bob effect
      group.position.y = Math.sin(elapsed * 1.5) * 0.05;
      
      renderer.render(scene, camera);
    }
    
    animate();

    return () => {
      cancelAnimationFrame(animationId);
      renderer.dispose();
      cubeGeometry.dispose();
      voxelMaterial.dispose();
      wireframeGeometry.dispose();
      wireframeMaterial.dispose();
      glowGeometry.dispose();
      glowMaterial.dispose();
      if (container && renderer.domElement) {
        container.removeChild(renderer.domElement);
      }
    };
  });
</script>

<div 
  bind:this={container} 
  class="rabbit-voxel"
  style="width: {width}px; height: {height}px;"
></div>

<style>
  .rabbit-voxel {
    position: relative;
    background: transparent;
    border-radius: 4px;
    overflow: hidden;
  }

  .rabbit-voxel :global(canvas) {
    display: block;
  }
</style>
