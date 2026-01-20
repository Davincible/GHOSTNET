# Wagmi/Viem TypeScript: Strict Chain Type Inference

**Date:** January 2026  
**Issue:** TypeScript errors when using wagmi's writeContract with custom chains

## Problem

When using wagmi v3 with custom chains (MegaETH), TypeScript complains about chain ID types:

```typescript
// Error: Type 'number' is not assignable to type '6343 | 4326 | 31337'
const hash = await writeContract(config, request as WriteContractParameters);
```

The issue occurs because:
1. `simulateContract` returns a `request` object with a generic `Chain` type
2. `writeContract` expects chain IDs to match the literal union of configured chains
3. TypeScript infers `chainId: number` instead of `chainId: 6343 | 4326 | 31337`

## Root Cause

Wagmi v3's type system is very strict about chain configurations. When you define a config with specific chains:

```typescript
export const config = createConfig({
  chains: [megaethTestnet, megaethMainnet, localhost], // ids: 6343, 4326, 31337
  ...
});
```

All wagmi functions expect chain IDs to be one of those literal types, not `number`.

## Solution

Use `as any` type assertion for the request object when calling `writeContract`:

```typescript
const { request } = await simulateContract(config, {
  address: contractAddress,
  abi: contractAbi,
  functionName: 'someFunction',
  args: [arg1, arg2]
});

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const hash = await writeContract(config, request as any);
```

## Why This Is Safe

1. `simulateContract` validates the request against the chain
2. If simulation succeeds, the request is valid for that chain
3. The type mismatch is purely a TypeScript limitation with generic inference
4. The runtime behavior is correct

## Alternative Approaches

### Option 1: Generic Type Parameters (More Complex)
```typescript
// Would require threading chain types through all functions
async function write<TChain extends Chain>(...) { ... }
```

### Option 2: Separate Functions Per Chain (Not Scalable)
```typescript
// Not practical with multiple chains
```

### Option 3: Type Assertion (Recommended)
Simple, safe, and maintainable.

## References

- [Wagmi v3 Migration Guide](https://wagmi.sh/react/migration-guide)
- [Viem Chain Types](https://viem.sh/docs/chains/introduction)
