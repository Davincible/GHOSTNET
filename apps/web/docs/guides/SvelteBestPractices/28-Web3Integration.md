# Web3 + SvelteKit Integration Guide

This guide covers connecting your SvelteKit frontend to Solidity smart contracts using **viem** and **wagmi**.

## Overview

| Library | Purpose |
|---------|---------|
| **viem** | Low-level contract interactions, transaction building |
| **wagmi** | Wallet connections, React hooks (adaptable to Svelte) |
| **@wagmi/core** | Framework-agnostic wagmi core |

## Quick Start

### 1. Install Dependencies

```bash
cd apps/web
bun add viem @wagmi/core @wagmi/connectors
```

### 2. Export Contract ABIs

After building contracts:

```bash
just contracts-build
just export-abis
```

ABIs are exported to `apps/web/src/lib/contracts/abis/`.

### 3. Configure Wagmi

Create `apps/web/src/lib/web3/config.ts`:

```typescript
import { createConfig, http } from '@wagmi/core';
import { mainnet, sepolia, foundry } from '@wagmi/core/chains';
import { injected, walletConnect } from '@wagmi/connectors';

// Use local Anvil for development
const localAnvil = {
  ...foundry,
  id: 31337,
  rpcUrls: {
    default: { http: ['http://localhost:8545'] },
  },
};

export const config = createConfig({
  chains: [localAnvil, sepolia, mainnet],
  connectors: [
    injected(),
    walletConnect({
      projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID,
    }),
  ],
  transports: {
    [localAnvil.id]: http(),
    [sepolia.id]: http(),
    [mainnet.id]: http(),
  },
});

// Contract addresses per chain
export const CONTRACT_ADDRESSES = {
  [localAnvil.id]: {
    MyContract: '0x5FbDB2315678afecb367f032d93F642f64180aa3' as const,
  },
  [sepolia.id]: {
    MyContract: '0x...' as const,
  },
  [mainnet.id]: {
    MyContract: '0x...' as const,
  },
} as const;
```

---

## Svelte 5 Wallet Store

Create a runes-based wallet store in `apps/web/src/lib/stores/wallet.svelte.ts`:

```typescript
import { 
  connect, 
  disconnect, 
  getAccount, 
  watchAccount,
  type GetAccountReturnType 
} from '@wagmi/core';
import { injected } from '@wagmi/connectors';
import { config } from '$lib/web3/config';

export function createWalletStore() {
  let account = $state<GetAccountReturnType>(getAccount(config));
  let isConnecting = $state(false);
  let error = $state<Error | null>(null);

  // Watch for account changes
  $effect(() => {
    const unwatch = watchAccount(config, {
      onChange: (newAccount) => {
        account = newAccount;
      },
    });

    return () => unwatch();
  });

  async function connectWallet() {
    isConnecting = true;
    error = null;
    try {
      await connect(config, { connector: injected() });
    } catch (e) {
      error = e instanceof Error ? e : new Error('Failed to connect');
    } finally {
      isConnecting = false;
    }
  }

  async function disconnectWallet() {
    await disconnect(config);
  }

  return {
    // State (readonly getters)
    get address() { return account.address; },
    get isConnected() { return account.isConnected; },
    get isConnecting() { return isConnecting; },
    get chain() { return account.chain; },
    get error() { return error; },
    
    // Actions
    connect: connectWallet,
    disconnect: disconnectWallet,
  };
}

// Singleton instance
export const wallet = createWalletStore();
```

### Usage in Components

```svelte
<script lang="ts">
  import { wallet } from '$lib/stores/wallet.svelte';
</script>

{#if wallet.isConnected}
  <p>Connected: {wallet.address}</p>
  <p>Chain: {wallet.chain?.name}</p>
  <button onclick={wallet.disconnect}>Disconnect</button>
{:else}
  <button onclick={wallet.connect} disabled={wallet.isConnecting}>
    {wallet.isConnecting ? 'Connecting...' : 'Connect Wallet'}
  </button>
{/if}

{#if wallet.error}
  <p class="error">{wallet.error.message}</p>
{/if}
```

---

## Contract Interactions

### Reading Contract State

Create a contract store in `apps/web/src/lib/stores/contract.svelte.ts`:

```typescript
import { readContract, watchContractEvent } from '@wagmi/core';
import { config, CONTRACT_ADDRESSES } from '$lib/web3/config';
import MyContractAbi from '$lib/contracts/abis/MyContract.json';
import { wallet } from './wallet.svelte';

export function createContractStore() {
  let balance = $state<bigint>(0n);
  let isLoading = $state(false);
  let error = $state<Error | null>(null);

  // Derive contract address from current chain
  let contractAddress = $derived(
    wallet.chain 
      ? CONTRACT_ADDRESSES[wallet.chain.id]?.MyContract 
      : undefined
  );

  async function fetchBalance(userAddress: `0x${string}`) {
    if (!contractAddress) return;
    
    isLoading = true;
    error = null;
    try {
      balance = await readContract(config, {
        address: contractAddress,
        abi: MyContractAbi,
        functionName: 'balances',
        args: [userAddress],
      });
    } catch (e) {
      error = e instanceof Error ? e : new Error('Failed to fetch balance');
    } finally {
      isLoading = false;
    }
  }

  // Auto-fetch when wallet connects
  $effect(() => {
    if (wallet.isConnected && wallet.address) {
      fetchBalance(wallet.address);
    }
  });

  return {
    get balance() { return balance; },
    get isLoading() { return isLoading; },
    get error() { return error; },
    get contractAddress() { return contractAddress; },
    fetchBalance,
  };
}
```

### Writing to Contracts

```typescript
import { writeContract, waitForTransactionReceipt } from '@wagmi/core';
import { parseEther } from 'viem';

export function createDepositAction() {
  let isPending = $state(false);
  let txHash = $state<`0x${string}` | null>(null);
  let error = $state<Error | null>(null);

  async function deposit(amount: string) {
    if (!contractAddress) throw new Error('Contract not available');
    
    isPending = true;
    error = null;
    txHash = null;

    try {
      const hash = await writeContract(config, {
        address: contractAddress,
        abi: MyContractAbi,
        functionName: 'deposit',
        value: parseEther(amount),
      });
      
      txHash = hash;

      // Wait for confirmation
      await waitForTransactionReceipt(config, { hash });
      
    } catch (e) {
      error = e instanceof Error ? e : new Error('Transaction failed');
    } finally {
      isPending = false;
    }
  }

  return {
    get isPending() { return isPending; },
    get txHash() { return txHash; },
    get error() { return error; },
    deposit,
  };
}
```

### Usage Example

```svelte
<script lang="ts">
  import { wallet } from '$lib/stores/wallet.svelte';
  import { createContractStore } from '$lib/stores/contract.svelte';
  import { createDepositAction } from '$lib/stores/deposit.svelte';
  import { formatEther } from 'viem';

  const contract = createContractStore();
  const depositAction = createDepositAction();
  
  let amount = $state('0.1');
</script>

<div>
  <h2>Your Balance</h2>
  {#if contract.isLoading}
    <p>Loading...</p>
  {:else}
    <p>{formatEther(contract.balance)} ETH</p>
  {/if}

  <h2>Deposit</h2>
  <input type="text" bind:value={amount} placeholder="Amount in ETH" />
  <button 
    onclick={() => depositAction.deposit(amount)}
    disabled={depositAction.isPending || !wallet.isConnected}
  >
    {depositAction.isPending ? 'Depositing...' : 'Deposit'}
  </button>

  {#if depositAction.txHash}
    <p>TX: {depositAction.txHash}</p>
  {/if}

  {#if depositAction.error}
    <p class="error">{depositAction.error.message}</p>
  {/if}
</div>
```

---

## Event Listening

Watch for contract events:

```typescript
import { watchContractEvent } from '@wagmi/core';

$effect(() => {
  if (!contractAddress) return;
  
  const unwatch = watchContractEvent(config, {
    address: contractAddress,
    abi: MyContractAbi,
    eventName: 'Deposited',
    onLogs: (logs) => {
      for (const log of logs) {
        console.log('Deposit:', log.args.user, log.args.amount);
        // Update local state
      }
    },
  });

  return () => unwatch();
});
```

---

## TypeScript Type Generation

For type-safe contract interactions, use wagmi CLI:

### 1. Install wagmi CLI

```bash
cd apps/web
bun add -D @wagmi/cli
```

### 2. Create wagmi.config.ts

```typescript
import { defineConfig } from '@wagmi/cli';
import { foundry } from '@wagmi/cli/plugins';

export default defineConfig({
  out: 'src/lib/contracts/generated.ts',
  plugins: [
    foundry({
      project: '../../packages/contracts',
      include: ['MyContract.sol/**'],
    }),
  ],
});
```

### 3. Generate Types

```bash
bunx wagmi generate
```

Or use the justfile command:

```bash
just generate-types
```

### 4. Use Generated Types

```typescript
import { myContractAbi, myContractAddress } from '$lib/contracts/generated';

const balance = await readContract(config, {
  address: myContractAddress[31337], // Type-safe chain ID
  abi: myContractAbi,               // Type-safe ABI
  functionName: 'balances',         // Autocomplete!
  args: [userAddress],              // Type-checked args
});
```

---

## Local Development Workflow

### 1. Start Anvil

```bash
just contracts-anvil
```

This starts a local Ethereum node at `http://localhost:8545`.

### 2. Deploy Contracts

```bash
just contracts-deploy-local
```

Note the deployed contract addresses.

### 3. Update Config

Update `CONTRACT_ADDRESSES` in your config with deployed addresses.

### 4. Start Web App

```bash
just web-dev
```

### 5. Connect MetaMask

1. Add network: `http://localhost:8545`, Chain ID: `31337`
2. Import test account: Use Anvil's default private key
   ```
   0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
   ```

---

## Environment Variables

Create `apps/web/.env`:

```bash
# WalletConnect (get from cloud.walletconnect.com)
VITE_WALLETCONNECT_PROJECT_ID=your_project_id

# RPC URLs (optional - for production)
VITE_MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
VITE_SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
```

---

## SSR Considerations

Wagmi/viem use browser APIs. For SSR safety:

### 1. Lazy Initialize in Browser

```typescript
// lib/web3/client.ts
import { browser } from '$app/environment';

let config: ReturnType<typeof createConfig> | null = null;

export function getConfig() {
  if (!browser) return null;
  if (!config) {
    config = createConfig({ /* ... */ });
  }
  return config;
}
```

### 2. Guard Component Access

```svelte
<script lang="ts">
  import { browser } from '$app/environment';
  import { wallet } from '$lib/stores/wallet.svelte';
</script>

{#if browser}
  <WalletButton />
{:else}
  <button disabled>Connect Wallet</button>
{/if}
```

### 3. Use Client-Side Only Components

```svelte
<!-- +page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  
  let Web3Panel: typeof import('$components/Web3Panel.svelte').default;
  
  onMount(async () => {
    Web3Panel = (await import('$components/Web3Panel.svelte')).default;
  });
</script>

{#if Web3Panel}
  <Web3Panel />
{/if}
```

---

## Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| `ChainMismatchError` | Wrong network | Prompt user to switch chains |
| `ConnectorNotFoundError` | No wallet | Show "Install MetaMask" message |
| `UserRejectedRequestError` | User denied | Show retry option |
| `ContractFunctionExecutionError` | Reverted | Parse revert reason, show to user |

```typescript
import { 
  ChainMismatchError,
  UserRejectedRequestError,
  ContractFunctionExecutionError 
} from 'viem';

try {
  await writeContract(/* ... */);
} catch (e) {
  if (e instanceof UserRejectedRequestError) {
    error = 'Transaction cancelled';
  } else if (e instanceof ChainMismatchError) {
    error = 'Please switch to the correct network';
  } else if (e instanceof ContractFunctionExecutionError) {
    error = e.shortMessage || 'Transaction reverted';
  } else {
    error = 'Unknown error';
  }
}
```

---

## Resources

- [viem Documentation](https://viem.sh)
- [wagmi Documentation](https://wagmi.sh)
- [Foundry Book](https://book.getfoundry.sh)
- [EIP-712 Typed Data](https://eips.ethereum.org/EIPS/eip-712)
