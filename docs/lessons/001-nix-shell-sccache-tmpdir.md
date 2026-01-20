# Lesson: sccache Temp Directory in Nix Shell

**Date**: 2026-01-21  
**Category**: Build Infrastructure  
**Severity**: Build Blocker

## Problem

When running Rust builds inside a Nix shell with sccache enabled, builds would fail intermittently with:

```
sccache: encountered fatal error
sccache: error: Failed to create temp dir
sccache: caused by: No such file or directory (os error 2) 
  at path "/private/tmp/nix-shell-XXXXX-XXXXXXX/sccacheXXXXXX"
```

## Root Cause

Nix shells create ephemeral temp directories under `/private/tmp/nix-shell-*` that are:
1. Unique per shell session
2. Cleaned up when the shell exits or in some edge cases during long-running operations

sccache uses the system `TMPDIR` (which Nix sets to the ephemeral directory) for its temporary compilation artifacts. If the temp directory disappears mid-compilation (due to shell state changes or cleanup), sccache fails.

## Solution

Set `SCCACHE_TMPDIR` to a stable directory that persists across shell sessions:

```nix
# shell.nix
shellHook = ''
  # === Rust/sccache Setup ===
  export SCCACHE_CACHE_SIZE="10G"
  export SCCACHE_DIR="$HOME/.cache/sccache"
  # Use stable temp directory (not the ephemeral nix-shell temp)
  export SCCACHE_TMPDIR="$HOME/.cache/sccache/tmp"
  mkdir -p "$SCCACHE_TMPDIR"
  export RUSTC_WRAPPER="${pkgs.sccache}/bin/sccache"
'';
```

## Additional Fix

Also found a Nix string interpolation bug in the welcome message:

```nix
# WRONG - Nix tries to interpolate ${SCCACHE_CACHE_SIZE} as a Nix variable
echo "  sccache: enabled (${SCCACHE_CACHE_SIZE} cache)"

# CORRECT - Escape the $ for bash interpolation
echo "  sccache: enabled (''${SCCACHE_CACHE_SIZE} cache)"
```

In Nix strings, `''$` escapes to a literal `$` in the output.

## Files Changed

- `shell.nix` - Added `SCCACHE_TMPDIR` and fixed string interpolation

## Verification

```bash
# Enter nix shell and verify sccache works
nix-shell --run "cargo check"

# Or verify sccache can create temp files
nix-shell --run "sccache --show-stats"
```

## References

- [sccache Configuration](https://github.com/mozilla/sccache#configuration)
- [Nix String Interpolation](https://nixos.org/manual/nix/stable/language/values.html#type-string)
