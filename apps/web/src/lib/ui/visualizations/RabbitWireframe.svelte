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

  // Create smooth curve from control points using Catmull-Rom interpolation
  function createSmoothCurve(controlPoints: [number, number, number][], segments: number = 32, closed: boolean = false): THREE.Vector3[] {
    const points = controlPoints.map(p => new THREE.Vector3(p[0], p[1], p[2]));
    const curve = new THREE.CatmullRomCurve3(points, closed, 'catmullrom', 0.5);
    return curve.getPoints(segments);
  }

  // Generate high-quality realistic rabbit wireframe
  function generateRabbitOutline(): THREE.Vector3[][] {
    const paths: THREE.Vector3[][] = [];
    const scale = 1.2; // Overall scale
    
    // Helper to scale points
    const s = (points: [number, number, number][]): [number, number, number][] => 
      points.map(([x, y, z]) => [x * scale, y * scale, z * scale]);

    // ============================================
    // BODY - Multiple contour lines for 3D effect
    // ============================================
    
    // Main body silhouette (side view) - elegant curved shape
    const bodyMain = createSmoothCurve(s([
      [-0.35, -0.15, 0],      // Lower back
      [-0.42, -0.05, 0],      // Back curve
      [-0.45, 0.08, 0],       // Upper back
      [-0.40, 0.18, 0],       // Shoulder
      [-0.28, 0.25, 0],       // Neck base
      [-0.15, 0.28, 0],       // Lower neck
      [0.05, 0.22, 0],        // Chest top
      [0.18, 0.12, 0],        // Chest
      [0.25, -0.02, 0],       // Lower chest
      [0.22, -0.15, 0],       // Belly
      [0.12, -0.22, 0],       // Under belly
      [-0.05, -0.24, 0],      // Belly bottom
      [-0.22, -0.20, 0],      // Back belly
      [-0.35, -0.15, 0],      // Connect back
    ]), 64, true);
    paths.push(bodyMain);

    // Body contour lines at different Z depths
    for (let zOffset of [-0.12, -0.06, 0.06, 0.12]) {
      const depthScale = 1 - Math.abs(zOffset) * 1.5;
      const bodyContour = createSmoothCurve(s([
        [-0.35 * depthScale, -0.15, zOffset],
        [-0.42 * depthScale, -0.05, zOffset],
        [-0.45 * depthScale, 0.08, zOffset],
        [-0.40 * depthScale, 0.18, zOffset],
        [-0.28 * depthScale, 0.25, zOffset * 0.8],
      ]), 24);
      paths.push(bodyContour);
    }

    // Horizontal body rings
    for (let y = -0.15; y <= 0.15; y += 0.1) {
      const ringWidth = 0.35 * Math.sqrt(1 - Math.pow(y / 0.25, 2));
      const ringDepth = 0.15 * Math.sqrt(1 - Math.pow(y / 0.25, 2));
      const ring: THREE.Vector3[] = [];
      for (let a = 0; a <= Math.PI * 2; a += Math.PI / 16) {
        ring.push(new THREE.Vector3(
          Math.cos(a) * ringWidth * scale - 0.1 * scale,
          y * scale,
          Math.sin(a) * ringDepth * scale
        ));
      }
      paths.push(ring);
    }

    // ============================================
    // HEAD - Detailed round head with cheeks
    // ============================================
    
    // Main head outline (front-facing, slightly turned)
    const headMain = createSmoothCurve(s([
      [-0.18, 0.30, 0.12],    // Left jaw
      [-0.22, 0.38, 0.14],    // Left cheek
      [-0.23, 0.48, 0.13],    // Left temple
      [-0.20, 0.58, 0.10],    // Left forehead
      [-0.12, 0.64, 0.08],    // Top left
      [0, 0.66, 0.06],        // Crown
      [0.12, 0.64, 0.08],     // Top right
      [0.20, 0.58, 0.10],     // Right forehead
      [0.23, 0.48, 0.13],     // Right temple
      [0.22, 0.38, 0.14],     // Right cheek
      [0.18, 0.30, 0.12],     // Right jaw
      [0.08, 0.26, 0.15],     // Right chin
      [0, 0.24, 0.16],        // Chin
      [-0.08, 0.26, 0.15],    // Left chin
      [-0.18, 0.30, 0.12],    // Back to start
    ]), 48, true);
    paths.push(headMain);

    // Head profile line (side silhouette)
    const headProfile = createSmoothCurve(s([
      [-0.10, 0.28, 0.08],
      [-0.20, 0.32, 0.02],
      [-0.24, 0.42, -0.02],
      [-0.22, 0.54, -0.04],
      [-0.16, 0.62, -0.02],
      [-0.08, 0.65, 0.02],
    ]), 24);
    paths.push(headProfile);

    // Snout/muzzle detail
    const snout = createSmoothCurve(s([
      [-0.08, 0.32, 0.18],
      [-0.10, 0.36, 0.22],
      [-0.06, 0.40, 0.24],
      [0, 0.42, 0.25],
      [0.06, 0.40, 0.24],
      [0.10, 0.36, 0.22],
      [0.08, 0.32, 0.18],
    ]), 24);
    paths.push(snout);

    // ============================================
    // EARS - Long, elegant rabbit ears
    // ============================================
    
    // Left ear - outer edge
    const leftEarOuter = createSmoothCurve(s([
      [-0.14, 0.60, 0.06],    // Base
      [-0.20, 0.72, 0.04],    // Lower outer
      [-0.24, 0.88, 0.02],    // Mid outer
      [-0.25, 1.05, 0.00],    // Upper outer
      [-0.22, 1.20, -0.02],   // Near tip outer
      [-0.16, 1.32, -0.03],   // Tip
      [-0.12, 1.28, -0.02],   // Tip inner
      [-0.10, 1.15, 0.00],    // Upper inner
      [-0.10, 0.98, 0.02],    // Mid inner
      [-0.10, 0.80, 0.04],    // Lower inner
      [-0.08, 0.62, 0.06],    // Base inner
    ]), 40);
    paths.push(leftEarOuter);

    // Left ear - inner detail lines
    const leftEarInner1 = createSmoothCurve(s([
      [-0.13, 0.68, 0.05],
      [-0.17, 0.85, 0.03],
      [-0.18, 1.02, 0.01],
      [-0.16, 1.18, -0.01],
      [-0.14, 1.26, -0.02],
    ]), 24);
    paths.push(leftEarInner1);

    const leftEarInner2 = createSmoothCurve(s([
      [-0.11, 0.70, 0.05],
      [-0.13, 0.88, 0.03],
      [-0.13, 1.05, 0.01],
      [-0.12, 1.18, -0.01],
    ]), 20);
    paths.push(leftEarInner2);

    // Right ear - outer edge (mirrored)
    const rightEarOuter = createSmoothCurve(s([
      [0.14, 0.60, 0.06],
      [0.20, 0.72, 0.04],
      [0.24, 0.88, 0.02],
      [0.25, 1.05, 0.00],
      [0.22, 1.20, -0.02],
      [0.16, 1.32, -0.03],
      [0.12, 1.28, -0.02],
      [0.10, 1.15, 0.00],
      [0.10, 0.98, 0.02],
      [0.10, 0.80, 0.04],
      [0.08, 0.62, 0.06],
    ]), 40);
    paths.push(rightEarOuter);

    // Right ear inner details
    const rightEarInner1 = createSmoothCurve(s([
      [0.13, 0.68, 0.05],
      [0.17, 0.85, 0.03],
      [0.18, 1.02, 0.01],
      [0.16, 1.18, -0.01],
      [0.14, 1.26, -0.02],
    ]), 24);
    paths.push(rightEarInner1);

    const rightEarInner2 = createSmoothCurve(s([
      [0.11, 0.70, 0.05],
      [0.13, 0.88, 0.03],
      [0.13, 1.05, 0.01],
      [0.12, 1.18, -0.01],
    ]), 20);
    paths.push(rightEarInner2);

    // ============================================
    // EYES - Almond shaped with detail
    // ============================================
    
    // Left eye
    const leftEye = createSmoothCurve(s([
      [-0.16, 0.48, 0.14],
      [-0.14, 0.52, 0.15],
      [-0.10, 0.54, 0.16],
      [-0.06, 0.52, 0.16],
      [-0.05, 0.48, 0.15],
      [-0.07, 0.45, 0.15],
      [-0.11, 0.44, 0.14],
      [-0.15, 0.46, 0.14],
      [-0.16, 0.48, 0.14],
    ]), 24, true);
    paths.push(leftEye);

    // Left eye inner (pupil area)
    const leftPupil: THREE.Vector3[] = [];
    for (let a = 0; a <= Math.PI * 2; a += Math.PI / 12) {
      leftPupil.push(new THREE.Vector3(
        (-0.105 + Math.cos(a) * 0.025) * scale,
        (0.49 + Math.sin(a) * 0.03) * scale,
        0.155 * scale
      ));
    }
    paths.push(leftPupil);

    // Right eye
    const rightEye = createSmoothCurve(s([
      [0.16, 0.48, 0.14],
      [0.14, 0.52, 0.15],
      [0.10, 0.54, 0.16],
      [0.06, 0.52, 0.16],
      [0.05, 0.48, 0.15],
      [0.07, 0.45, 0.15],
      [0.11, 0.44, 0.14],
      [0.15, 0.46, 0.14],
      [0.16, 0.48, 0.14],
    ]), 24, true);
    paths.push(rightEye);

    // Right pupil
    const rightPupil: THREE.Vector3[] = [];
    for (let a = 0; a <= Math.PI * 2; a += Math.PI / 12) {
      rightPupil.push(new THREE.Vector3(
        (0.105 + Math.cos(a) * 0.025) * scale,
        (0.49 + Math.sin(a) * 0.03) * scale,
        0.155 * scale
      ));
    }
    paths.push(rightPupil);

    // ============================================
    // NOSE - Small triangular nose
    // ============================================
    
    const nose = createSmoothCurve(s([
      [0, 0.38, 0.26],
      [-0.025, 0.36, 0.25],
      [-0.02, 0.34, 0.24],
      [0, 0.33, 0.24],
      [0.02, 0.34, 0.24],
      [0.025, 0.36, 0.25],
      [0, 0.38, 0.26],
    ]), 20, true);
    paths.push(nose);

    // Nose to mouth line
    const noseLine = createSmoothCurve(s([
      [0, 0.33, 0.24],
      [0, 0.30, 0.22],
      [0, 0.27, 0.20],
    ]), 12);
    paths.push(noseLine);

    // ============================================
    // WHISKERS - Elegant curves
    // ============================================
    
    // Left whiskers
    paths.push(createSmoothCurve(s([[-0.04, 0.35, 0.24], [-0.15, 0.38, 0.18], [-0.28, 0.42, 0.10]]), 16));
    paths.push(createSmoothCurve(s([[-0.04, 0.34, 0.24], [-0.16, 0.34, 0.18], [-0.30, 0.34, 0.08]]), 16));
    paths.push(createSmoothCurve(s([[-0.04, 0.33, 0.24], [-0.15, 0.30, 0.18], [-0.28, 0.26, 0.10]]), 16));
    
    // Right whiskers
    paths.push(createSmoothCurve(s([[0.04, 0.35, 0.24], [0.15, 0.38, 0.18], [0.28, 0.42, 0.10]]), 16));
    paths.push(createSmoothCurve(s([[0.04, 0.34, 0.24], [0.16, 0.34, 0.18], [0.30, 0.34, 0.08]]), 16));
    paths.push(createSmoothCurve(s([[0.04, 0.33, 0.24], [0.15, 0.30, 0.18], [0.28, 0.26, 0.10]]), 16));

    // ============================================
    // FRONT LEGS - Delicate, tucked position
    // ============================================
    
    // Left front leg
    const leftFrontLeg = createSmoothCurve(s([
      [0.08, 0.05, 0.10],      // Shoulder
      [0.06, -0.05, 0.14],     // Upper leg
      [0.04, -0.18, 0.16],     // Knee
      [0.05, -0.30, 0.15],     // Lower leg
      [0.04, -0.38, 0.14],     // Ankle
      [0.02, -0.42, 0.16],     // Paw back
      [0.08, -0.44, 0.18],     // Paw front
    ]), 28);
    paths.push(leftFrontLeg);

    // Right front leg
    const rightFrontLeg = createSmoothCurve(s([
      [0.12, 0.05, 0.06],
      [0.14, -0.05, 0.10],
      [0.15, -0.18, 0.12],
      [0.14, -0.30, 0.12],
      [0.13, -0.38, 0.11],
      [0.12, -0.42, 0.13],
      [0.18, -0.44, 0.14],
    ]), 28);
    paths.push(rightFrontLeg);

    // ============================================
    // BACK LEGS - Powerful haunches
    // ============================================
    
    // Left back leg (haunch)
    const leftBackHaunch = createSmoothCurve(s([
      [-0.25, 0.00, 0.08],     // Hip
      [-0.30, -0.08, 0.10],    // Upper haunch
      [-0.34, -0.18, 0.08],    // Haunch curve
      [-0.32, -0.28, 0.06],    // Knee
      [-0.28, -0.36, 0.08],    // Lower leg
      [-0.26, -0.42, 0.10],    // Ankle
    ]), 28);
    paths.push(leftBackHaunch);

    // Left back foot (large rabbit foot)
    const leftBackFoot = createSmoothCurve(s([
      [-0.26, -0.42, 0.10],
      [-0.32, -0.44, 0.08],
      [-0.40, -0.44, 0.06],
      [-0.45, -0.43, 0.04],
      [-0.42, -0.42, 0.06],
      [-0.34, -0.41, 0.08],
    ]), 20);
    paths.push(leftBackFoot);

    // Right back leg
    const rightBackHaunch = createSmoothCurve(s([
      [-0.25, 0.00, -0.08],
      [-0.30, -0.08, -0.10],
      [-0.34, -0.18, -0.08],
      [-0.32, -0.28, -0.06],
      [-0.28, -0.36, -0.08],
      [-0.26, -0.42, -0.10],
    ]), 28);
    paths.push(rightBackHaunch);

    // Right back foot
    const rightBackFoot = createSmoothCurve(s([
      [-0.26, -0.42, -0.10],
      [-0.32, -0.44, -0.08],
      [-0.40, -0.44, -0.06],
      [-0.45, -0.43, -0.04],
      [-0.42, -0.42, -0.06],
      [-0.34, -0.41, -0.08],
    ]), 20);
    paths.push(rightBackFoot);

    // ============================================
    // TAIL - Fluffy cotton ball
    // ============================================
    
    // Tail made of multiple overlapping curves
    for (let i = 0; i < 6; i++) {
      const angle = (i / 6) * Math.PI * 2;
      const tailCurve = createSmoothCurve(s([
        [-0.38, -0.08, -0.02],
        [-0.44 + Math.cos(angle) * 0.03, -0.06 + Math.sin(angle) * 0.04, -0.08 + Math.cos(angle + 1) * 0.03],
        [-0.48 + Math.cos(angle) * 0.02, -0.04 + Math.sin(angle) * 0.03, -0.10 + Math.sin(angle) * 0.02],
        [-0.46 + Math.cos(angle) * 0.02, -0.02 + Math.sin(angle) * 0.02, -0.08 + Math.cos(angle) * 0.02],
        [-0.40, 0.00, -0.04],
      ]), 16);
      paths.push(tailCurve);
    }

    // ============================================
    // STRUCTURAL LINES - Tron grid effect
    // ============================================
    
    // Spine line
    const spine = createSmoothCurve(s([
      [-0.44, 0.08, 0],
      [-0.40, 0.16, 0],
      [-0.30, 0.24, 0],
      [-0.18, 0.28, 0],
      [-0.05, 0.26, 0.04],
      [0, 0.32, 0.08],
      [0, 0.45, 0.12],
      [0, 0.58, 0.08],
      [0, 0.65, 0.06],
    ]), 40);
    paths.push(spine);

    // Neck to head connection lines
    const neckLine1 = createSmoothCurve(s([
      [-0.18, 0.28, 0.06],
      [-0.15, 0.32, 0.10],
      [-0.12, 0.38, 0.12],
    ]), 12);
    paths.push(neckLine1);

    const neckLine2 = createSmoothCurve(s([
      [0.05, 0.24, 0.08],
      [0.08, 0.28, 0.12],
      [0.10, 0.34, 0.14],
    ]), 12);
    paths.push(neckLine2);

    return paths;
  }

  onMount(() => {
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 100);
    camera.position.set(1.5, 0.8, 2.5);
    camera.lookAt(0, 0.35, 0);

    const renderer = new THREE.WebGLRenderer({ 
      antialias: true, 
      alpha: true 
    });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    container.appendChild(renderer.domElement);

    // Enhanced line material with better glow
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
          // Multiple traveling pulses for more life
          float pulse1 = sin(vLineDistance * 8.0 - uTime * uPulseSpeed * 4.0) * 0.5 + 0.5;
          float pulse2 = sin(vLineDistance * 12.0 + uTime * uPulseSpeed * 3.0) * 0.5 + 0.5;
          float pulse = max(pow(pulse1, 4.0), pow(pulse2, 6.0) * 0.5);
          
          // Height-based intensity (ears glow more)
          float heightGlow = smoothstep(0.3, 1.2, vPosition.y) * 0.3;
          
          // Base glow
          float glow = 0.5 + pulse * 0.5 + heightGlow;
          
          vec3 finalColor = uColor * glow;
          
          // Hot white highlights
          float hotspot = step(0.92, pulse1) * 0.6;
          finalColor += vec3(hotspot);
          
          gl_FragColor = vec4(finalColor, 0.95);
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

    // Center the rabbit
    lineGroup.position.y = -0.1;
    scene.add(lineGroup);

    // Atmospheric glow behind rabbit
    const glowGeometry = new THREE.SphereGeometry(1.0, 32, 32);
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
          float intensity = pow(0.65 - dot(vNormal, vec3(0.0, 0.0, 1.0)), 2.5);
          intensity *= 0.12 + 0.04 * sin(uTime * 1.5);
          gl_FragColor = vec4(uColor, intensity);
        }
      `,
      transparent: true,
      side: THREE.BackSide,
      depthWrite: false,
      blending: THREE.AdditiveBlending
    });
    
    const glowMesh = new THREE.Mesh(glowGeometry, glowMaterial);
    glowMesh.position.set(0, 0.3, 0);
    scene.add(glowMesh);

    // Floor grid
    const gridHelper = new THREE.GridHelper(4, 30, new THREE.Color(color).multiplyScalar(0.25), new THREE.Color(color).multiplyScalar(0.1));
    gridHelper.position.y = -0.65;
    scene.add(gridHelper);

    // Scan ring on floor
    const ringGeometry = new THREE.RingGeometry(0.6, 0.62, 64);
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
          float sweep = mod(angle + uTime * 1.5, 6.28318) / 6.28318;
          float intensity = pow(1.0 - sweep, 4.0);
          gl_FragColor = vec4(uColor * intensity, intensity * 0.6);
        }
      `,
      transparent: true,
      side: THREE.DoubleSide,
      depthWrite: false,
      blending: THREE.AdditiveBlending
    });
    
    const ring = new THREE.Mesh(ringGeometry, ringMaterial);
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = -0.64;
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
      
      // Smooth rotation
      lineGroup.rotation.y = Math.sin(elapsed * 0.3) * 0.5;
      glowMesh.rotation.y = lineGroup.rotation.y;
      
      // Gentle floating
      const floatY = Math.sin(elapsed * 0.8) * 0.02;
      lineGroup.position.y = -0.1 + floatY;
      glowMesh.position.y = 0.3 + floatY;
      
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
      lineGroup.traverse((obj) => {
        if (obj instanceof THREE.Line) {
          obj.geometry.dispose();
        }
      });
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
