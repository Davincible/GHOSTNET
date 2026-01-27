/**
 * ZzFX - Zuper Zmall Zound Zynth v1.3.2
 * by Frank Force 2019
 * https://github.com/KilledByAPixel/ZzFX
 *
 * MIT License - Copyright (c) 2019 Frank Force
 *
 * Faithfully ported to TypeScript for GHOSTNET.
 * 20 parameters matching the original buildSamples signature.
 */

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

/**
 * ZzFX sound parameter tuple — 20 values matching the original API.
 *
 * Index  Name            Default   Description
 * ─────  ──────────────  ───────   ──────────────────────────
 *  0     volume          1         Overall volume scale
 *  1     randomness      0.05      Frequency randomness
 *  2     frequency       220       Base frequency (Hz)
 *  3     attack          0         Attack time (seconds)
 *  4     sustain         0         Sustain time (seconds)
 *  5     release         0.1       Release time (seconds)
 *  6     shape           0         Waveform (0=sin,1=tri,2=saw,3=tan,4=noise)
 *  7     shapeCurve      1         Shape curve exponent
 *  8     slide           0         Frequency slide
 *  9     deltaSlide      0         Slide acceleration
 * 10     pitchJump       0         Pitch jump amount
 * 11     pitchJumpTime   0         Time before pitch jump (seconds)
 * 12     repeatTime      0         Repeat time (seconds)
 * 13     noise           0         Noise amount
 * 14     modulation      0         Frequency modulation
 * 15     bitCrush        0         Bit crush amount
 * 16     delay           0         Delay time (seconds)
 * 17     sustainVolume   1         Volume during sustain
 * 18     decay           0         Decay time (seconds)
 * 19     tremolo         0         Tremolo amount
 */
export type ZzFXParams = [
	volume?: number,
	randomness?: number,
	frequency?: number,
	attack?: number,
	sustain?: number,
	release?: number,
	shape?: number,
	shapeCurve?: number,
	slide?: number,
	deltaSlide?: number,
	pitchJump?: number,
	pitchJumpTime?: number,
	repeatTime?: number,
	noise?: number,
	modulation?: number,
	bitCrush?: number,
	delay?: number,
	sustainVolume?: number,
	decay?: number,
	tremolo?: number,
];

// ════════════════════════════════════════════════════════════════
// AUDIO CONTEXT
// ════════════════════════════════════════════════════════════════

/** Master volume applied to all playback (matches original ZZFX.volume) */
const MASTER_VOLUME = 0.3;

/** Sample rate — matches the hardware context */
const SAMPLE_RATE = 44100;

let audioContext: AudioContext | null = null;

function getAudioContext(): AudioContext {
	if (!audioContext) {
		audioContext = new AudioContext();
	}
	return audioContext;
}

// ════════════════════════════════════════════════════════════════
// PLAYBACK
// ════════════════════════════════════════════════════════════════

/**
 * Generate and play a ZzFX sound.
 * Matches the original `zzfx(...parameters)` API.
 */
export function zzfx(...params: ZzFXParams): AudioBufferSourceNode | undefined {
	const ctx = getAudioContext();
	const samples = zzfxGenerate(...params);

	const buffer = ctx.createBuffer(1, samples.length, SAMPLE_RATE);
	buffer.getChannelData(0).set(samples);

	const source = ctx.createBufferSource();
	source.buffer = buffer;

	// Gain node for master volume (matches original ZZFX.playSamples)
	const gainNode = ctx.createGain();
	gainNode.gain.value = MASTER_VOLUME;
	gainNode.connect(ctx.destination);

	source.connect(gainNode);
	source.start();

	return source;
}

// ════════════════════════════════════════════════════════════════
// SAMPLE GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate ZzFX samples.
 * Faithful port of ZZFX.buildSamples from v1.3.2.
 *
 * 20 parameters — exactly matching the original signature and index order.
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
	tremolo = 0,
): Float32Array {
	// ── Init parameters ──
	const PI2 = Math.PI * 2;
	const abs = Math.abs;
	const sign = (v: number) => (v < 0 ? -1 : 1);

	const startSlide = (slide *= (500 * PI2) / SAMPLE_RATE / SAMPLE_RATE);
	let startFrequency = (frequency *=
		((1 + randomness * 2 * Math.random() - randomness) * PI2) / SAMPLE_RATE);

	let modOffset = 0;
	let repeat = 0;
	let crush = 0;
	let jump: number = 1;
	let length: number;
	const b: number[] = [];
	let t = 0;
	let i = 0;
	let s = 0;
	let f: number;

	// ── Scale by sample rate ──
	const minAttack = 9; // prevent pop if attack is 0
	attack = attack * SAMPLE_RATE || minAttack;
	decay *= SAMPLE_RATE;
	sustain *= SAMPLE_RATE;
	release *= SAMPLE_RATE;
	delay *= SAMPLE_RATE;
	deltaSlide *= (500 * PI2) / SAMPLE_RATE ** 3;
	modulation *= PI2 / SAMPLE_RATE;
	pitchJump *= PI2 / SAMPLE_RATE;
	pitchJumpTime *= SAMPLE_RATE;
	repeatTime = (repeatTime * SAMPLE_RATE) | 0;

	// ── Generate waveform ──
	for (
		length = (attack + decay + sustain + release + delay) | 0;
		i < length;
		b[i++] = s * volume
	) {
		if (!(++crush % ((bitCrush * 100) | 0))) {
			// ── Wave shape ──
			s = shape
				? shape > 1
					? shape > 2
						? shape > 3
							? shape > 4
								? // 5: square duty
									t / PI2 % 1 < shapeCurve / 2
									? 1
									: -1
								: // 4: noise
									Math.sin(t ** 3)
							: // 3: tan
								Math.max(Math.min(Math.tan(t), 1), -1)
						: // 2: saw
							1 - ((((2 * t) / PI2) % 2 + 2) % 2)
					: // 1: triangle
						1 - 4 * abs(Math.round(t / PI2) - t / PI2)
				: // 0: sin
					Math.sin(t);

			// ── Envelope ──
			s =
				(repeatTime ? 1 - tremolo + tremolo * Math.sin((PI2 * i) / repeatTime) : 1) *
				(shape > 4 ? s : sign(s) * abs(s) ** shapeCurve) *
				(i < attack
					? i / attack
					: i < attack + decay
						? 1 - ((i - attack) / decay) * (1 - sustainVolume)
						: i < attack + decay + sustain
							? sustainVolume
							: i < length - delay
								? ((length - i - delay) / release) * sustainVolume
								: 0);

			// ── Delay ──
			s = delay
				? s / 2 +
					(delay > i
						? 0
						: (i < length - delay ? 1 : (length - i) / delay) *
							((b[(i - delay) | 0] || 0) / 2 / volume))
				: s;
		}

		// ── Frequency / modulation ──
		f = (frequency += slide += deltaSlide) * Math.cos(modulation * modOffset++);

		// ── Noise ──
		t += f + f * noise * Math.sin(i ** 5);

		// ── Pitch jump ──
		if (jump && ++jump > pitchJumpTime) {
			frequency += pitchJump;
			// eslint-disable-next-line @typescript-eslint/no-unused-expressions
			startFrequency += pitchJump;
			jump = 0;
		}

		// ── Repeat ──
		if (repeatTime && !(++repeat % repeatTime)) {
			frequency = startFrequency;
			slide = startSlide;
			jump ||= 1;
		}
	}

	return new Float32Array(b);
}

// ════════════════════════════════════════════════════════════════
// AUDIO CONTEXT MANAGEMENT
// ════════════════════════════════════════════════════════════════

/**
 * Resume audio context (required after user gesture).
 */
export function resumeAudio(): void {
	const ctx = getAudioContext();
	if (ctx.state === 'suspended') {
		ctx.resume();
	}
}
