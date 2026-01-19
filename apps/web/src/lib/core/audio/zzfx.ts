/**
 * ZzFX - Zuper Zmall Zound Zynth
 * by Frank Force 2019
 * https://github.com/KilledByAPixel/ZzFX
 *
 * Minified and typed for GHOSTNET
 */

// ZzFX sound parameters type
export type ZzFXParams = [
	volume?: number,          // 0: volume
	randomness?: number,      // 1: randomness
	frequency?: number,       // 2: frequency
	attack?: number,          // 3: attack
	sustain?: number,         // 4: sustain
	release?: number,         // 5: release
	shape?: number,           // 6: shape
	shapeCurve?: number,      // 7: shapeCurve
	slide?: number,           // 8: slide
	deltaSlide?: number,      // 9: deltaSlide
	pitchJump?: number,       // 10: pitchJump
	pitchJumpTime?: number,   // 11: pitchJumpTime
	repeatTime?: number,      // 12: repeatTime
	noise?: number,           // 13: noise
	modulation?: number,      // 14: modulation
	bitCrush?: number,        // 15: bitCrush
	delay?: number,           // 16: delay
	sustainVolume?: number,   // 17: sustainVolume
	decay?: number,           // 18: decay
	tremolo?: number          // 19: tremolo
];

let audioContext: AudioContext | null = null;

function getAudioContext(): AudioContext {
	if (!audioContext) {
		audioContext = new AudioContext();
	}
	return audioContext;
}

/**
 * Generate and play a ZzFX sound
 */
export function zzfx(...params: ZzFXParams): AudioBufferSourceNode | undefined {
	const ctx = getAudioContext();
	const samples = zzfxGenerate(...params);
	
	const buffer = ctx.createBuffer(1, samples.length, ctx.sampleRate);
	buffer.getChannelData(0).set(samples);
	
	const source = ctx.createBufferSource();
	source.buffer = buffer;
	source.connect(ctx.destination);
	source.start();
	
	return source;
}

/**
 * Generate ZzFX samples
 */
export function zzfxGenerate(
	volume = 1,
	randomness = 0.05,
	frequency = 220,
	attack = 0,
	sustain = 0,
	release = 0.1,
	shape = 0,
	shapeCurve = 1,
	slide = 0,
	deltaSlide = 0,
	pitchJump = 0,
	pitchJumpTime = 0,
	repeatTime = 0,
	noise = 0,
	modulation = 0,
	bitCrush = 0,
	delay = 0,
	sustainVolume = 1,
	decay = 0,
	tremolo = 0
): Float32Array {
	const ctx = getAudioContext();
	const sampleRate = ctx.sampleRate;
	
	const PI2 = Math.PI * 2;
	const sign = (v: number) => (v > 0 ? 1 : -1);
	let startSlide = (slide *= (500 * PI2) / sampleRate / sampleRate);
	let startFrequency = (frequency *= ((1 + randomness * 2 * Math.random() - randomness) * PI2) / sampleRate);
	
	let b = [];
	let t = 0,
		tm = 0,
		f = 0,
		length = 0,
		c = 0;
		
	attack = 99 + attack * sampleRate;
	decay *= sampleRate;
	sustain *= sampleRate;
	release *= sampleRate;
	delay *= sampleRate;
	deltaSlide *= (500 * PI2) / sampleRate ** 3;
	length = attack + decay + sustain + release + delay | 0;
	
	pitchJump *= PI2 / sampleRate;
	pitchJumpTime *= sampleRate;
	repeatTime = repeatTime * sampleRate | 0;
	
	const modPhase = sign(modulation) * PI2 / 4;
	modulation *= PI2 / sampleRate;
	
	for (let i = 0, j = 0; i < length; b[i++] = c) {
		if (!(++j % ((bitCrush * 100) | 0))) {
			c = shape
				? shape > 1
					? shape > 2
						? shape > 3
							? Math.sin((t % PI2) ** 3)
							: Math.max(Math.min(Math.tan(t), 1), -1)
						: 1 - (((((2 * t) / PI2) % 2) + 2) % 2)
					: 1 - 4 * Math.abs(Math.round(t / PI2) - t / PI2)
				: Math.sin(t);
				
			c =
				(repeatTime
					? 1 - tremolo + tremolo * Math.sin((PI2 * i) / repeatTime)
					: 1) *
				sign(c) *
				Math.abs(c) ** shapeCurve *
				(i < attack
					? i / attack
					: i < attack + decay
					? 1 - ((i - attack) / decay) * (1 - sustainVolume)
					: i < attack + decay + sustain
					? sustainVolume
					: i < length - delay
					? ((length - i - delay) / release) * sustainVolume
					: 0);
					
			c = delay
				? c / 2 + (delay > i ? 0 : ((b[(i - delay) | 0] || 0) / 2))
				: c;
		}
		
		f =
			(frequency += slide += deltaSlide) *
			Math.cos(modulation * tm++ + modPhase);
			
		t += f - f * noise * (1 - (((Math.sin(i) + 1) * 1e9) % 2));
		
		if (pitchJumpTime && !(++j % pitchJumpTime)) {
			frequency += pitchJump;
			startFrequency += pitchJump;
		}
		
		if (repeatTime && !(++j % repeatTime)) {
			frequency = startFrequency;
			slide = startSlide;
		}
	}
	
	return new Float32Array(b);
}

/**
 * Resume audio context (required after user gesture)
 */
export function resumeAudio(): void {
	const ctx = getAudioContext();
	if (ctx.state === 'suspended') {
		ctx.resume();
	}
}
