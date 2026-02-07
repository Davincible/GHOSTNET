# MegaETH Testnet Legacy Chain ID Conflict

**Date:** 2026-02-04
**Category:** Web3 / Wallet Integration

## Problem

Users who previously added MegaETH Testnet to MetaMask had chain ID **6342** configured.
MegaETH later changed their testnet chain ID to **6343**, but the RPC URL remained the same
(`https://carrot.megaeth.com/rpc`).

When our app tried to switch to chain 6343, MetaMask threw:

```
Could not add network that points to same RPC endpoint as existing network
for chain 0x18c6 ('Mega Testnet')
```

MetaMask has no `wallet_removeEthereumChain` or `wallet_updateEthereumChain` API, so
there's no programmatic way to remove the old network. Telling users to manually delete
it from Settings > Networks is terrible UX.

## Solution

Two-part fix:

### 1. Accept both chain IDs as valid

Since both 6342 and 6343 point to the same RPC endpoint and same network, we treat
both as acceptable:

```typescript
// chains.ts
export function isAcceptableChain(chainId: number): boolean {
  if (chainId === defaultChain.id) return true; // 6343
  if (defaultChain.id === megaethTestnet.id && chainId === 6342) return true; // legacy
  return false;
}
```

This prevents the "Wrong network" warning from showing for users on the old chain ID.

### 2. Fallback in switchToCorrectChain

When the "same RPC endpoint" error occurs, we catch it and try switching to the old
chain ID (6342) instead via raw `wallet_switchEthereumChain`:

```typescript
if (errMsg.includes('Could not add network that points to same RPC endpoint')) {
  const provider = await connector?.getProvider();
  await provider.request({
    method: 'wallet_switchEthereumChain',
    params: [{ chainId: '0x18c6' }], // 6342
  });
}
```

## Key Insight

When a chain provider changes their chain ID but keeps the same RPC, you can't force
users to update. Accept the legacy chain ID gracefully and fall back to it automatically.
This is a common issue with testnets.

## Files Changed

- `apps/web/src/lib/web3/chains.ts` — `isAcceptableChain()`, legacy constant
- `apps/web/src/lib/web3/wallet.svelte.ts` — Updated chain comparison, fallback logic
- `apps/web/src/lib/features/header/WalletButton.svelte` — Uses `isWrongChain`
