# ZzFX Parameter Offset Bug

**Date**: 2026-01-27  
**Severity**: Critical — all 30 sound effects were broken  
**Component**: `apps/web/src/lib/core/audio/zzfx.ts`

## Problem

Every sound in the audio system produced incorrect output (clicks, silence, or noise instead of the intended sound).

## Root Cause

The `zzfxGenerate` function had **21 parameters** instead of the original ZzFX's **20 parameters**. An extra `_volume` parameter was inserted before `volume`:

```typescript
// BROKEN — 21 params, off-by-one for every value after index 0
export function zzfxGenerate(
  _volume = 1,              // position 0 — EXTRA
  volume = _volume,         // position 1 — consumes randomness slot
  randomness = 0.05,        // position 2 — consumes frequency slot
  frequency = 220,          // position 3 — consumes attack slot
  // ... everything shifted by one
)
```

When `zzfx(...[0.3, , 800, , 0.01, ...])` was called:
- `0.3` (volume) → `_volume` ✓
- `undefined` (randomness) → `volume` — consumed the slot
- `800` (intended frequency) → `randomness` — 800x randomness!
- Every subsequent parameter was in the wrong position.

## Additional Bugs Found

1. **Volume not applied to samples**: Original ZzFX: `b[i++] = s * volume`. Broken version: `b[i++] = c` — no volume scaling.
2. **Shared counter `j`**: Bit crush, pitch jump, and repeat shared one counter. Original uses three separate counters (`crush`, `jump`, `repeat`).
3. **Noise formula wrong**: Original: `Math.sin(i**5)`. Broken: `Math.sin(i)` wrapped in different math.
4. **Pitch jump logic broken**: Original uses a timer variable. Broken used modulo on shared counter.
5. **Attack always inflated**: `attack = 99 + attack * sampleRate` instead of `attack * sampleRate || 9`.
6. **Delay release envelope missing**: Original scales delayed samples by a release factor.

## Fix

Rewrote `zzfx.ts` as a faithful port of the original ZzFX v1.3.2 `buildSamples` function from https://github.com/KilledByAPixel/ZzFX, with proper TypeScript types. All 20 parameters map correctly to the `ZzFXParams` tuple indices.

## Lesson

When porting minified third-party code, verify the function signature against the original source. A single extra parameter silently corrupts every subsequent argument via positional mapping. The eslint-disable comment on `volume` was a red flag that should have been caught — it indicated a parameter that existed only to be suppressed.
