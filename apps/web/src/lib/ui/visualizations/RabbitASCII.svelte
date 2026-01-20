<script lang="ts">
  import { onMount } from 'svelte';

  interface Props {
    width?: number;
    height?: number;
    color?: string;
    bgColor?: string;
    rainSpeed?: number;
    showRain?: boolean;
  }

  let { 
    width = 400, 
    height = 400, 
    color = '#00e5cc',
    bgColor = '#1a0a2e',
    rainSpeed = 1,
    showRain = true
  }: Props = $props();

  let canvas: HTMLCanvasElement;
  let animationId: number;
  
  // Parse hex color to RGB - reactive
  function hexToRgb(hex: string) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? {
      r: parseInt(result[1], 16),
      g: parseInt(result[2], 16),
      b: parseInt(result[3], 16)
    } : { r: 0, g: 229, b: 204 };
  }
  
  // Reactive RGB objects that animation loop can reference
  let rgb = $state(hexToRgb(color));
  let bgRgb = $state(hexToRgb(bgColor));
  
  // Update RGB when color props change
  $effect(() => {
    rgb = hexToRgb(color);
    bgRgb = hexToRgb(bgColor);
  });

  // ASCII art frames for the rabbit (multiple frames for animation)
  const rabbitFrames = [
    // Frame 1 - Neutral
    `
       (\\(\\
       ( -.-)
       o_(")(")
    `,
    // Frame 2 - Ear twitch
    `
       (\\(\\
       ( -.-)
       o_(")(")
    `,
    // Frame 3 - Alert
    `
       (\\ /)
       ( . .)
       c(")(")
    `
  ];

  // More detailed ASCII rabbit for the main display
  const detailedRabbit = `
         ,\\
         \\\\\\,_
          \\  ,\\
     __,.-" =__)
   ."        )
,_/   ,    \\/\\_
\\_|    )_-\\ \\_-\`
   \`-----\` \`--\`
  `;

  // Alternative cute rabbit
  const cuteRabbit = `
   (\\__/)
   (='.'=)
   (")_(")
  `;

  // Larger detailed rabbit
  const largeRabbit = `
          /|      __
         / |   ,-~ /
        Y :|  //  /
        | jj /( .^
        >-"~"-v"
       /       Y
      jo  o    |
     ( ~T~     j
      >._-' _./
     /   "~"  |
    Y     _,  |
   /| ;-"~ _  l
  / l/ ,-"~    \\
  \\//\\/      .- \\
   Y        /    Y
   l       I     !
   ]\\      _\\    /"\\
  (" ~----( ~   Y.  )
  `;

  // Matrix-style large rabbit with more detail
  const matrixRabbit = `
                     /\\
                    /  \\
       (\\__/)     /    \\
       (o'.'o)   /  /\\  \\
      =(")_(")= /  /__\\  \\
        |   |  /  /    \\  \\
       _|   |_/  /      \\  \\
      (___,___) /        \\  \\
         | |   /__________\\  \\
         | |  |   FOLLOW   |  |
         | |  |    THE     |  |
         |_|  |   WHITE    |  |
        /   \\ |   RABBIT   |  |
       |     ||____________|__|
  `;

  // Simple but iconic rabbit silhouette
  const iconicRabbit = `
      (\\(\\           (\\(\\
      ( -.-) _______ (-.-)
     o_(")(")(     )(")_(")o
              \\   /
               | |
    ___________| |___________
   |    FOLLOW THE WHITE    |
   |         RABBIT         |
   |________________________|
  `;

  // Main display rabbit - clean and recognizable
  const mainRabbit = `

             /\\     /\\
            {  \`---'  }
            {  O   O  }
            ~~>  V  <~~
             \\  \\|/  /
              \`-----'____
              /     \\    \\_
             {       }\\  )_\\_   _
             |  \\_/  |/ /  \\_\\_/ )
              \\__/  /(_/     \\__/
                (__/

`;

  onMount(() => {
    const ctx = canvas.getContext('2d')!;
    const dpr = window.devicePixelRatio || 1;
    
    // Set canvas size with device pixel ratio
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    ctx.scale(dpr, dpr);

    // Matrix rain columns
    const fontSize = 14;
    const columns = Math.floor(width / fontSize);
    const drops: number[] = new Array(columns).fill(0).map(() => Math.random() * -100);
    const chars = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789ABCDEF';

    // Rabbit display state
    let rabbitAlpha = 0;
    let targetRabbitAlpha = 1;
    let glitchOffset = 0;
    let scanlineY = 0;

    function animate() {
      animationId = requestAnimationFrame(animate);

      // Semi-transparent black for trail effect
      ctx.fillStyle = 'rgba(3, 3, 5, 0.1)';
      ctx.fillRect(0, 0, width, height);

      // Draw Matrix rain
      if (showRain) {
        ctx.font = `${fontSize}px monospace`;
        
        for (let i = 0; i < columns; i++) {
          // Random character
          const char = chars[Math.floor(Math.random() * chars.length)];
          
          // Calculate position
          const x = i * fontSize;
          const y = drops[i] * fontSize;
          
          // Gradient from bright to dim
          const brightness = Math.random();
          if (brightness > 0.95) {
            // Bright leading character
            ctx.fillStyle = `rgba(255, 255, 255, 0.9)`;
          } else {
            // Normal rain character
            const alpha = 0.3 + brightness * 0.4;
            ctx.fillStyle = `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${alpha})`;
          }
          
          ctx.fillText(char, x, y);
          
          // Reset drop when it goes off screen
          if (y > height && Math.random() > 0.975) {
            drops[i] = 0;
          }
          drops[i] += rainSpeed * (0.5 + Math.random() * 0.5);
        }
      }

      // Draw ASCII rabbit in center
      ctx.save();
      
      // Glitch effect
      const time = Date.now() * 0.001;
      if (Math.random() > 0.97) {
        glitchOffset = (Math.random() - 0.5) * 10;
      } else {
        glitchOffset *= 0.9;
      }
      
      // Smooth alpha transition
      rabbitAlpha += (targetRabbitAlpha - rabbitAlpha) * 0.05;
      
      // Scanline position
      scanlineY = (scanlineY + 2) % height;

      // Draw rabbit
      ctx.font = '12px "Courier New", monospace';
      ctx.textAlign = 'center';
      
      const lines = mainRabbit.split('\n');
      const lineHeight = 14;
      const startY = (height - lines.length * lineHeight) / 2;
      
      lines.forEach((line, i) => {
        const y = startY + i * lineHeight;
        
        // Glitch effect on random lines
        let xOffset = glitchOffset;
        if (Math.random() > 0.98) {
          xOffset += (Math.random() - 0.5) * 20;
        }
        
        // Color with glow effect
        const distFromCenter = Math.abs(i - lines.length / 2) / (lines.length / 2);
        const intensity = 1 - distFromCenter * 0.3;
        
        // Draw glow layer
        ctx.fillStyle = `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${0.3 * rabbitAlpha * intensity})`;
        ctx.fillText(line, width / 2 + xOffset + 1, y + 1);
        ctx.fillText(line, width / 2 + xOffset - 1, y - 1);
        
        // Draw main text
        ctx.fillStyle = `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${rabbitAlpha * intensity})`;
        ctx.fillText(line, width / 2 + xOffset, y);
        
        // Bright leading edge on some characters
        if (Math.random() > 0.95) {
          ctx.fillStyle = `rgba(255, 255, 255, ${0.8 * rabbitAlpha})`;
          const charIndex = Math.floor(Math.random() * line.length);
          const char = line[charIndex];
          if (char && char !== ' ') {
            const charWidth = ctx.measureText(line.substring(0, charIndex)).width;
            const lineWidth = ctx.measureText(line).width;
            ctx.fillText(char, width / 2 + xOffset - lineWidth / 2 + charWidth, y);
          }
        }
      });

      // Draw scanline effect
      ctx.fillStyle = `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.03)`;
      ctx.fillRect(0, scanlineY, width, 2);
      
      // Draw "FOLLOW THE WHITE RABBIT" text
      ctx.font = 'bold 10px "Courier New", monospace';
      ctx.textAlign = 'center';
      
      const message = 'FOLLOW THE WHITE RABBIT';
      const messageY = height - 40;
      
      // Typing effect
      const visibleChars = Math.floor((time * 3) % (message.length + 10));
      const displayMessage = message.substring(0, Math.min(visibleChars, message.length));
      
      // Glow
      ctx.fillStyle = `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.4)`;
      ctx.fillText(displayMessage, width / 2 + 1, messageY + 1);
      ctx.fillText(displayMessage, width / 2 - 1, messageY - 1);
      
      // Main text
      ctx.fillStyle = `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.9)`;
      ctx.fillText(displayMessage, width / 2, messageY);
      
      // Cursor blink
      if (visibleChars <= message.length && Math.floor(time * 2) % 2 === 0) {
        const cursorX = width / 2 + ctx.measureText(displayMessage).width / 2 + 3;
        ctx.fillRect(cursorX, messageY - 8, 6, 10);
      }

      ctx.restore();

      // CRT effect - subtle vignette
      const gradient = ctx.createRadialGradient(
        width / 2, height / 2, 0,
        width / 2, height / 2, width * 0.7
      );
      gradient.addColorStop(0, 'rgba(0, 0, 0, 0)');
      gradient.addColorStop(1, 'rgba(0, 0, 0, 0.4)');
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, width, height);

      // Horizontal scan lines (CRT effect)
      ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
      for (let y = 0; y < height; y += 3) {
        ctx.fillRect(0, y, width, 1);
      }
    }

    animate();

    return () => {
      cancelAnimationFrame(animationId);
    };
  });
</script>

<div class="rabbit-ascii" style="width: {width}px; height: {height}px;">
  <canvas bind:this={canvas}></canvas>
</div>

<style>
  .rabbit-ascii {
    position: relative;
    background: #030305;
    border-radius: 4px;
    overflow: hidden;
  }

  .rabbit-ascii canvas {
    display: block;
    image-rendering: pixelated;
  }
</style>
