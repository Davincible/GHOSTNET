# Web3 Integration Audit

**Date**: 2026-01-21
**Reviewer**: Akira (Automated)
**Scope**: Web3/blockchain integration security and correctness

---

## Executive Summary

| Severity | Count | Description |
|----------|-------|-------------|
| **CRITICAL** | 1 | Financial safety issue in display formatting |
| **HIGH** | 4 | Error handling gaps, missing UX states |
| **MODERATE** | 5 | Gas estimation, chain verification improvements |
| **LOW** | 3 | Code organization, type safety enhancements |

**Overall Assessment**: The Web3 integration is **architecturally sound** with excellent use of `parseUnits`/`formatUnits` for token amounts and proper `simulateContract` before writes. However, there are gaps in error handling completeness, transaction state feedback, and gas-related error handling that should be addressed before production.

---

## CRITICAL: Financial Safety Issues

### 1. Token Amount Handling

**Status**: MOSTLY SAFE with one concern

**Files checked**:
- [x] `src/lib/web3/contracts.ts` - **SAFE**
- [x] `src/lib/features/modals/JackInModal.svelte` - **SAFE** (with concern)
- [x] `src/lib/features/modals/ExtractModal.svelte` - **SAFE**

#### Correct Patterns Found

**contracts.ts (lines 92-104)** - Excellent use of viem utilities:
```typescript
// CORRECT: String-based decimal parsing
export function formatData(amount: bigint, decimals = 2): string {
  return Number(formatUnits(amount, 18)).toLocaleString(undefined, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals
  });
}

export function parseData(amount: string): bigint {
  return parseUnits(amount, 18);
}
```

**JackInModal.svelte (lines 41-48)** - Correct parsing:
```typescript
let parsedAmount = $derived.by(() => {
  const trimmed = amountInput.trim();
  if (!trimmed || isNaN(Number(trimmed)) || Number(trimmed) <= 0) return 0n;
  try {
    return parseUnits(trimmed, 18);  // CORRECT
  } catch {
    return 0n;
  }
});
```

#### Concern: Display Formatting Precision Loss

**JackInModal.svelte (lines 37-39)**:
```typescript
let minStakeFormatted = $derived(Number(levelConfig.minStake / 10n ** 18n));
let userBalance = $derived(provider.currentUser?.tokenBalance ?? 0n);
let userBalanceFormatted = $derived(Number(userBalance / 10n ** 18n));
```

**Issue**: Integer division `/ 10n ** 18n` before converting to Number loses the fractional part.

**Example**:
- User has `1500000000000000000n` (1.5 tokens)
- `1500000000000000000n / 10n ** 18n` = `1n` (integer division!)
- User sees "1" instead of "1.5"

**Impact**: MODERATE - Display only, doesn't affect actual transaction amounts, but could mislead users about their balance.

**Fix**:
```typescript
import { formatUnits } from 'viem';

let minStakeFormatted = $derived(Number(formatUnits(levelConfig.minStake, 18)));
let userBalanceFormatted = $derived(Number(formatUnits(userBalance, 18)));
```

### 2. No Float-to-BigInt Conversion Found

**Status**: SAFE

Grep for dangerous patterns returned no results:
- No `parseFloat` with token amounts
- No `Number()` multiplication by `1e18`
- No `Math.floor` before `BigInt()`

This is excellent - the codebase properly uses `parseUnits` for all user input to bigint conversion.

---

## HIGH: Error Handling Assessment

### Contract Write Error Handling

| Function | File | Has Try/Catch | User Feedback | Specific Errors | Simulation |
|----------|------|:-------------:|:-------------:|:---------------:|:----------:|
| `jackIn` | contracts.ts:311 | Partial | Toast | Generic | Yes |
| `extract` | contracts.ts:340 | Partial | Toast | Generic | Yes |
| `claimRewards` | contracts.ts:359 | No | None | None | Yes |
| `upgradeLevel` | contracts.ts:378 | No | None | None | Yes |
| `increaseStake` | contracts.ts:398 | No | None | None | Yes |
| `approveData` | contracts.ts:180 | No | None | None | Yes |
| `placeBet` | contracts.ts:479 | No | None | None | Yes |
| `claimWinnings` | contracts.ts:522 | No | None | None | Yes |

**Critical Finding**: The contract interaction functions in `contracts.ts` do NOT have internal error handling. They throw errors that must be caught by callers.

**JackInModal.svelte (lines 97-121)** - Good error handling:
```typescript
try {
  await provider.jackIn(selectedLevel, parsedAmount);
  toast.success('Successfully jacked in');
  onclose();
} catch (err) {
  console.error('Jack In failed:', err);
  if (err instanceof UserRejectedRequestError) {
    toast.error('Transaction cancelled');
  } else if (err instanceof ContractFunctionExecutionError) {
    toast.error(err.shortMessage || 'Transaction reverted');
  } else if (err instanceof Error) {
    toast.error(err.message);
  } else {
    toast.error('Jack In failed. Please try again.');
  }
}
```

**ExtractModal.svelte (lines 54-78)** - Similar good pattern.

### Missing Error Types

**contracts.ts:18-21** imports:
```typescript
import {
  UserRejectedRequestError,
  ContractFunctionExecutionError
} from 'viem';
```

**Missing imports** that should be handled:
```typescript
import {
  InsufficientFundsError,      // User can't afford gas
  TransactionExecutionError,   // Transaction failed on-chain
  ContractFunctionRevertError, // Contract reverted with reason
  EstimateGasExecutionError,   // Gas estimation failed
} from 'viem';
```

### Silent Failure Points

**contracts.ts** - All write functions will throw on failure but callers may not handle all cases:

1. **Line 322-323** - Approval before jackIn:
   ```typescript
   if (allowance < amount) {
     await approveData(amount);  // No error handling wrapper!
   }
   ```
   If approval fails, error is thrown but not caught with specific context.

2. **parseContractError (lines 63-83)** - Good error parsing but missing:
   - `InsufficientFundsError` - "Not enough ETH for gas"
   - Network disconnection errors
   - Timeout errors

**Recommendation**: Add to `parseContractError`:
```typescript
export function parseContractError(err: unknown): string {
  if (err instanceof UserRejectedRequestError) {
    return 'Transaction cancelled by user';
  }
  if (err instanceof InsufficientFundsError) {
    return 'Insufficient ETH for gas fees';
  }
  if (err instanceof ContractFunctionExecutionError) {
    const reason = err.shortMessage || err.message;
    // ... existing custom error parsing
  }
  if (err instanceof Error) {
    if (err.message.includes('network') || err.message.includes('disconnected')) {
      return 'Network connection lost. Please check your connection.';
    }
    if (err.message.includes('timeout')) {
      return 'Request timed out. Please try again.';
    }
    return err.message;
  }
  return 'Transaction failed';
}
```

---

## MODERATE: Transaction UX

### Pending States

| Flow | Shows Pending | Shows Hash | Shows Confirm | Shows Error |
|------|:-------------:|:----------:|:-------------:|:-----------:|
| Jack In | Yes (button) | No | No | Yes (toast) |
| Extract | Yes (button) | No | No | Yes (toast) |
| Approve | No | No | No | No |

**JackInModal.svelte (lines 33, 98-99, 119, 308-310)**:
```typescript
let isSubmitting = $state(false);
// ...
isSubmitting = true;
// ...
isSubmitting = false;
// ...
<Button ... loading={isSubmitting}>JACK IN</Button>
```

This shows a loading spinner but **does not show**:
1. Transaction hash for tracking
2. "Confirming..." state after submission
3. Block explorer link

### Missing Transaction Hash Display

**contracts.ts** returns the hash but it's not shown to users:

```typescript
// contracts.ts line 332-334
const hash = await writeContract(config, request);
await waitForTransactionReceipt(config, { hash });
return hash;
```

The hash is returned but the UI components don't display it.

**Recommendation**: Add transaction status to modals:
```svelte
{#if txHash}
  <div class="tx-status">
    <span>TX: {txHash.slice(0, 10)}...</span>
    <a href={`${chain.blockExplorers.default.url}/tx/${txHash}`} target="_blank">
      View on Explorer
    </a>
  </div>
{/if}
```

### Approval Flow UX Gap

When `jackIn` needs approval first, users see:
1. Click "JACK IN"
2. Wallet popup for approval (unexpected!)
3. Another wallet popup for jackIn
4. Success

Users should be informed:
```
Step 1/2: Approve $DATA spending
Step 2/2: Jack In to SUBNET
```

---

## Chain/Network Safety

### Address Management

**Pattern Used**: Chain-ID keyed object with null checks

**abis.ts (lines 36-67)**:
```typescript
export const CONTRACT_ADDRESSES = {
  6343: { // MegaETH Testnet
    dataToken: '' as `0x${string}`,  // Empty - not deployed
    ghostCore: '' as `0x${string}`,
    // ...
  },
  4326: { // MegaETH Mainnet
    // ...
  },
  31337: { // Localhost
    // ...
  }
} as const;
```

**Null Handling (lines 81-97)**: GOOD
```typescript
export function getContractAddress(chainId: number, contract: ContractName): `0x${string}` | null {
  const addresses = CONTRACT_ADDRESSES[chainId as ChainId];
  if (!addresses) return null;
  const addr = addresses[contract];
  if (!addr || addr.length < 3) {
    // Warns in dev, returns null
    return null;
  }
  return addr;
}
```

**contracts.ts (lines 109-117)** - Proper null handling:
```typescript
function requireAddress(contract: 'ghostCore' | 'dataToken' | 'deadPool'): `0x${string}` {
  const chainId = wallet.chainId;
  if (!chainId) throw new Error('Not connected to a chain');

  const address = getContractAddress(chainId, contract);
  if (!address) throw new Error(`${contract} not deployed on chain ${chainId}`);

  return address;
}
```

### Multi-Chain Support

| Chain | ID | Addresses Defined | RPC Configured |
|-------|---:|:-----------------:|:--------------:|
| MegaETH Testnet | 6343 | Yes (empty) | Yes |
| MegaETH Mainnet | 4326 | Yes (empty) | Yes |
| Localhost | 31337 | Yes (empty) | Yes |

**Issue**: All addresses are empty strings. This is expected for pre-deployment but must be updated before launch.

**chains.ts (lines 13-33, 39-59)** - Good chain definitions with:
- Correct chain IDs
- RPC URLs
- Block explorer URLs
- Native currency config

### Chain Mismatch Handling

**wallet.svelte.ts (line 106)**:
```typescript
const isCorrectChain = $derived(chainId === defaultChain.id);
```

**wallet.svelte.ts (lines 318-339)** - `switchToCorrectChain`:
```typescript
async function switchToCorrectChain() {
  // ... guards
  try {
    error = null;
    await switchChain(config, { chainId: defaultChain.id });
  } catch (err) {
    error = parseWalletError(err);
    console.error('[Wallet] Chain switch error:', err);
  }
}
```

**Gap**: The UI doesn't prominently warn users when on wrong chain. Recommend adding a persistent banner.

---

## Wallet Connection

### Connection Flow Assessment

| Capability | Status | Implementation |
|------------|:------:|----------------|
| Initial connection | Yes | `wallet.connect()` |
| Reconnection on reload | Partial | `watchAccount` watches but no explicit reconnect |
| Account change detection | Yes | `watchAccount` callback |
| Chain change detection | Yes | `watchChainId` callback |
| Disconnection handling | Yes | `disconnectWallet()` |
| Error handling | Yes | `parseWalletError()` |

**wallet.svelte.ts (lines 172-184)** - Watchers:
```typescript
const unwatchAccount = watchAccount(config, {
  onChange: handleAccountChange
});

const unwatchChainId = watchChainId(config, {
  onChange: handleChainChange
});

// Check if already connected
const account = getAccount(config);
handleAccountChange(account);
```

**Good**: Checks existing connection on init.

### WalletModal.svelte Assessment

**Lines 66-95** - Connection handling:
```typescript
async function connectWallet(walletId: string) {
  isConnecting = walletId;
  error = null;

  try {
    if (walletId === 'walletconnect') {
      onclose();  // Close modal first for QR visibility
      await wallet.connectWalletConnect();
    } else {
      const target = walletId === 'metamask' ? 'metaMask' 
        : walletId === 'coinbase' ? 'coinbaseWallet' 
        : undefined;
      
      await wallet.connect(target);
      
      if (wallet.isConnected) {
        onclose();
      } else if (wallet.error) {
        error = wallet.error;
      }
    }
  } catch (err) {
    error = err instanceof Error ? err.message : 'Failed to connect';
  } finally {
    isConnecting = null;
  }
}
```

**Good practices**:
- Clears error before connecting
- Handles WalletConnect QR modal visibility
- Maps wallet IDs to specific targets
- Shows connection state per wallet option

---

## Approval Flow (ERC20)

**Status**: IMPLEMENTED

**contracts.ts (lines 316-323)**:
```typescript
// Check and set allowance if needed
const address = wallet.address;
if (!address) throw new Error('Wallet not connected');

const allowance = await getDataAllowance(address);
if (allowance < amount) {
  await approveData(amount);
}
```

**Also in increaseStake (lines 403-410)** and **placeBet (lines 486-505)**.

### Approval Pattern Assessment

| Check | Status | Notes |
|-------|:------:|-------|
| Allowance checked | Yes | `getDataAllowance(address)` |
| Approval requested if needed | Yes | `approveData(amount)` |
| Correct spender address | Yes | GhostCore/DeadPool addresses |
| Simulation before approval | Yes | `simulateContract` used |
| Wait for confirmation | Yes | `waitForTransactionReceipt` |

**Improvement Needed**: The approval is done silently. Users should be informed this is happening.

---

## Gas Estimation

**Status**: PARTIALLY HANDLED

### Gas Limit Handling

The code uses `simulateContract` which implicitly estimates gas:
```typescript
const { request } = await simulateContract(config, {
  address: ghostCoreAddress,
  abi: ghostCoreAbi,
  functionName: 'jackIn',
  args: [level, amount]
});
```

Wagmi/viem will estimate gas automatically. No explicit `gasLimit` overrides found.

### Missing Gas-Related Error Handling

**Not handled**:
1. `EstimateGasExecutionError` - When gas estimation fails
2. `InsufficientFundsError` - Not enough ETH for gas
3. Gas price spikes making transactions too expensive

**Recommendation**: Add to `parseContractError`:
```typescript
if (err.message?.includes('gas') || err.message?.includes('insufficient funds')) {
  return 'Transaction would fail or you don\'t have enough ETH for gas';
}
```

---

## Security Checklist

| Check | Status | Notes |
|-------|:------:|-------|
| No float-to-BigInt for amounts | PASS | Uses `parseUnits` consistently |
| All writes have error handling | PARTIAL | UI catches, library functions throw |
| User sees all transaction states | PARTIAL | Missing hash display, multi-step flow |
| Chain-specific addresses | PASS | Proper chain ID keying |
| Null address checks | PASS | `requireAddress` throws if missing |
| Approval before transfer | PASS | Implemented in all transfer functions |
| No hardcoded private keys | PASS | None found |
| RPC URLs not exposing keys | PASS | Uses public RPC URLs |
| simulateContract before write | PASS | All write functions simulate first |
| SSR safety | PASS | All browser APIs guarded |

---

## Recommendations

### Critical (Fix Before Launch)

1. **Fix Display Formatting Precision Loss**
   
   **File**: `JackInModal.svelte` lines 37-39
   ```typescript
   // BEFORE
   let minStakeFormatted = $derived(Number(levelConfig.minStake / 10n ** 18n));
   
   // AFTER
   let minStakeFormatted = $derived(Number(formatUnits(levelConfig.minStake, 18)));
   ```

2. **Populate Contract Addresses**
   
   **File**: `abis.ts` lines 36-67
   
   All contract addresses are empty strings. These must be populated with deployed addresses before launch.

### High Priority

3. **Add Missing Error Types to parseContractError**
   
   **File**: `contracts.ts` lines 63-83
   ```typescript
   import { InsufficientFundsError } from 'viem';
   
   export function parseContractError(err: unknown): string {
     if (err instanceof InsufficientFundsError) {
       return 'Not enough ETH to pay for gas';
     }
     // ... rest of existing code
   }
   ```

4. **Add Transaction Hash Display**
   
   **Files**: `JackInModal.svelte`, `ExtractModal.svelte`
   
   Show the transaction hash and link to block explorer during/after transaction.

5. **Add Multi-Step Approval UX**
   
   When `jackIn` or `increaseStake` needs approval, show:
   - "Step 1/2: Approve $DATA spending"
   - "Step 2/2: Confirm Jack In"

6. **Add Wrong Chain Warning Banner**
   
   When `wallet.isCorrectChain` is false, show a prominent banner with switch button.

### Improvements

7. **Add Confirmation Waiting State**
   
   After `writeContract` but before `waitForTransactionReceipt`:
   ```typescript
   txState = 'confirming';  // Show "Confirming..." in UI
   await waitForTransactionReceipt(config, { hash });
   txState = 'confirmed';
   ```

8. **Add Retry Button on Error**
   
   When transaction fails, show error message with a "Try Again" button.

9. **Consider Permit2 for Better UX**
   
   Instead of approve + transfer, use [Permit2](https://docs.uniswap.org/contracts/permit2/overview) for single-transaction approval.

---

## Code Examples for Fixes

### Fix 1: Display Formatting

**Current code** (`JackInModal.svelte`):
```typescript
let minStakeFormatted = $derived(Number(levelConfig.minStake / 10n ** 18n));
let userBalanceFormatted = $derived(Number(userBalance / 10n ** 18n));
```

**Fixed code**:
```typescript
import { formatUnits } from 'viem';

let minStakeFormatted = $derived(
  Number(formatUnits(levelConfig.minStake, 18))
);
let userBalanceFormatted = $derived(
  Number(formatUnits(userBalance, 18))
);
```

### Fix 2: Enhanced Error Parsing

**Current code** (`contracts.ts`):
```typescript
export function parseContractError(err: unknown): string {
  if (err instanceof UserRejectedRequestError) {
    return 'Transaction cancelled by user';
  }
  // ...
}
```

**Fixed code**:
```typescript
import {
  UserRejectedRequestError,
  ContractFunctionExecutionError,
  InsufficientFundsError,
  EstimateGasExecutionError
} from 'viem';

export function parseContractError(err: unknown): string {
  if (err instanceof UserRejectedRequestError) {
    return 'Transaction cancelled by user';
  }
  if (err instanceof InsufficientFundsError) {
    return 'Insufficient ETH for gas fees. Please add ETH to your wallet.';
  }
  if (err instanceof EstimateGasExecutionError) {
    return 'Transaction would fail. Please check your inputs.';
  }
  if (err instanceof ContractFunctionExecutionError) {
    const reason = err.shortMessage || err.message;
    if (reason.includes('InsufficientBalance')) return 'Insufficient token balance';
    if (reason.includes('InsufficientAllowance')) return 'Token approval required';
    if (reason.includes('NoActivePosition')) return 'No active position found';
    if (reason.includes('PositionLocked')) return 'Position is locked during scan period';
    if (reason.includes('BelowMinimum')) return 'Amount below minimum stake';
    if (reason.includes('ExceedsCapacity')) return 'Level capacity exceeded';
    return reason;
  }
  if (err instanceof Error) {
    if (err.message.includes('network') || err.message.includes('disconnect')) {
      return 'Network connection lost. Please check your connection.';
    }
    return err.message;
  }
  return 'Transaction failed';
}
```

### Fix 3: Transaction State Component

**New component** (`TransactionStatus.svelte`):
```svelte
<script lang="ts">
  import { wallet } from '$lib/web3';
  
  interface Props {
    state: 'idle' | 'pending' | 'confirming' | 'confirmed' | 'failed';
    hash?: `0x${string}`;
    error?: string;
  }
  
  let { state, hash, error }: Props = $props();
  
  let explorerUrl = $derived(
    hash && wallet.chainId 
      ? `https://megaeth-testnet-v2.blockscout.com/tx/${hash}`
      : null
  );
</script>

{#if state === 'pending'}
  <div class="tx-status pending">
    <span class="spinner"></span>
    <span>Waiting for wallet confirmation...</span>
  </div>
{:else if state === 'confirming' && hash}
  <div class="tx-status confirming">
    <span class="spinner"></span>
    <span>Confirming transaction...</span>
    <a href={explorerUrl} target="_blank" rel="noopener">
      {hash.slice(0, 10)}...{hash.slice(-8)}
    </a>
  </div>
{:else if state === 'confirmed'}
  <div class="tx-status confirmed">
    <span>Transaction confirmed!</span>
    {#if explorerUrl}
      <a href={explorerUrl} target="_blank" rel="noopener">View on Explorer</a>
    {/if}
  </div>
{:else if state === 'failed'}
  <div class="tx-status failed">
    <span>{error || 'Transaction failed'}</span>
  </div>
{/if}
```

---

## Files Reviewed

| File | Lines | Assessment |
|------|------:|------------|
| `src/lib/web3/contracts.ts` | 538 | Core logic, mostly good |
| `src/lib/web3/wallet.svelte.ts` | 430 | Excellent SSR handling |
| `src/lib/web3/abis.ts` | 98 | Good, needs addresses |
| `src/lib/web3/config.ts` | 87 | Good SSR safety |
| `src/lib/web3/chains.ts` | 95 | Complete |
| `src/lib/web3/index.ts` | 59 | Good exports |
| `src/lib/features/modals/JackInModal.svelte` | 522 | Display bug found |
| `src/lib/features/modals/ExtractModal.svelte` | 229 | Good |
| `src/lib/features/modals/WalletModal.svelte` | 248 | Good |
| `src/lib/contracts/generated.ts` | 1935+ | Auto-generated, complete |

---

## Conclusion

The GHOSTNET Web3 integration demonstrates solid foundational practices:

1. **Correct token amount handling** using `parseUnits`/`formatUnits`
2. **Proper simulation** before all write operations
3. **Good SSR safety** with browser guards throughout
4. **Clean separation** between wallet state and contract interactions
5. **Comprehensive error parsing** with user-friendly messages

The critical issues are:
1. Display formatting precision loss (fixable in minutes)
2. Missing contract addresses (expected pre-deployment)

The high-priority issues around transaction UX and error handling completeness should be addressed before production to ensure users always know what's happening with their transactions.

**Recommendation**: Address Critical and High priority items before mainnet launch. The codebase shows good security awareness and should be safe for testnet use immediately.
