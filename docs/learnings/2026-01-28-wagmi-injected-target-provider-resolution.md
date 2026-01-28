# Wagmi Injected Connector: Target String vs Provider Function

**Date**: 2026-01-28
**Category**: Web3 / Wallet Connection
**Severity**: Breaking — causes `ProviderNotFoundError` at runtime

## Problem

Passing arbitrary string targets to wagmi's `injected({ target: 'rabby' })` throws `ProviderNotFoundError` because wagmi's internal `targetMap` only contains 3 entries: `metaMask`, `coinbaseWallet`, and `phantom`.

For unknown strings, wagmi auto-generates a provider check using `is${Target}` (e.g. `'rabby'` becomes `isRabby`), which searches `window.ethereum[flag]`. This fails when:

1. The wallet uses a different flag name than the auto-generated one
2. The wallet injects on a different window property (e.g. `window.okxwallet`, `window.xfi.ethereum`, `window.$onekey.ethereum`)
3. Multiple providers exist (EIP-5749) and the flag check doesn't traverse the `providers` array

## Root Cause

`@wagmi/core/connectors/injected.js` lines 17-24:
```js
if (typeof target === 'string')
  return {
    ...(targetMap[target] ?? {
      id: target,
      name: `${target[0].toUpperCase()}${target.slice(1)}`,
      provider: `is${target[0].toUpperCase()}${target.slice(1)}`,
    }),
  };
```

The fallback `provider` is just a string like `"isRabby"`, which `findProvider()` uses to check `window.ethereum.isRabby` — but doesn't handle the multi-provider array or alternative window locations.

## Solution

Pass a **target object** with an explicit `provider` function instead of a string:

```typescript
// WRONG - only works for metaMask, coinbaseWallet, phantom
injected({ target: 'rabby' })

// RIGHT - explicit provider resolution
injected({
  target: {
    id: 'rabby',
    name: 'Rabby',
    provider(window) {
      const eth = window.ethereum;
      if (eth?.providers) {
        return eth.providers.find(p => p.isRabby);
      }
      return eth?.isRabby ? eth : undefined;
    }
  }
})
```

For wallets on non-standard window properties:
```typescript
// OKX injects on window.okxwallet
provider: (win) => win.okxwallet ?? findProvider('isOkxWallet')(win)

// XDEFI injects on window.xfi.ethereum
provider: (win) => win.xfi?.ethereum ?? findProvider('isXDEFI')(win)
```

## Additional Fix

Before attempting connection, detect if the wallet is actually installed by checking the EIP-1193 flag. Show "not detected" UI state instead of letting wagmi throw a cryptic error.

## Key Takeaway

Only 3 wagmi `injected()` string targets work out of the box. All other wallets require a target object with a `provider` function that handles multi-provider arrays and non-standard injection points.
