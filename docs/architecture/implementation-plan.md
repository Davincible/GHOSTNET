# GHOSTNET Frontend Implementation Plan

**Version:** 1.0  
**Status:** Active  
**Created:** 2026-01-19  
**Approach:** Dummy Data First → Real Providers Later

---

## Table of Contents

1. [Overview](#1-overview)
2. [Data Interfaces](#2-data-interfaces)
3. [Mock Data Provider](#3-mock-data-provider)
4. [Implementation Phases](#4-implementation-phases)
5. [Phase 0: Project Setup](#5-phase-0-project-setup)
6. [Phase 1: Design System](#6-phase-1-design-system)
7. [Phase 2: Terminal Shell](#7-phase-2-terminal-shell)
8. [Phase 3: Core Infrastructure](#8-phase-3-core-infrastructure)
9. [Phase 4: Command Center](#9-phase-4-command-center)
10. [Phase 5: Typing Game](#10-phase-5-typing-game)
11. [Phase 6: Integration & Polish](#11-phase-6-integration--polish)
12. [Acceptance Criteria](#12-acceptance-criteria)

---

## 1. Overview

### Strategy: Interface-First Development

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEVELOPMENT APPROACH                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   STEP 1: Define Interfaces                                      │
│   ─────────────────────────                                      │
│   • TypeScript types for all data shapes                         │
│   • Clear contracts between layers                               │
│                                                                  │
│   STEP 2: Build Mock Provider                                    │
│   ──────────────────────────                                     │
│   • Generates realistic fake data                                │
│   • Simulates WebSocket events                                   │
│   • Controllable for testing scenarios                           │
│                                                                  │
│   STEP 3: Build UI Against Mocks                                 │
│   ─────────────────────────────                                  │
│   • All components work with mock data                           │
│   • Full UX testable without blockchain                          │
│   • Fast iteration cycles                                        │
│                                                                  │
│   STEP 4: Swap Providers (Later)                                 │
│   ─────────────────────────────                                  │
│   • Replace mock with real Web3 provider                         │
│   • Replace mock WebSocket with real server                      │
│   • No UI changes needed                                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Benefits

1. **Parallel Development** - UI work doesn't block on contracts/backend
2. **Fast Iteration** - No network delays, instant feedback
3. **Testable** - Can simulate edge cases (deaths, jackpots, etc.)
4. **Clear Contracts** - Interfaces defined before implementation
5. **Demo Ready** - Can show working UI before blockchain integration

---

## 2. Data Interfaces

### 2.1 Core Types

```typescript
// lib/core/types/index.ts

// ════════════════════════════════════════════════════════════════
// ENUMS & CONSTANTS
// ════════════════════════════════════════════════════════════════

export type Level = 'VAULT' | 'MAINFRAME' | 'SUBNET' | 'DARKNET' | 'BLACK_ICE';

export const LEVELS: Level[] = ['VAULT', 'MAINFRAME', 'SUBNET', 'DARKNET', 'BLACK_ICE'];

export type ConnectionStatus = 'disconnected' | 'connecting' | 'connected' | 'reconnecting';

// ════════════════════════════════════════════════════════════════
// USER & POSITION
// ════════════════════════════════════════════════════════════════

export interface User {
  address: `0x${string}`;
  ensName?: string;
  tokenBalance: bigint;
  ethBalance: bigint;
}

export interface Position {
  id: string;
  address: `0x${string}`;
  level: Level;
  stakedAmount: bigint;
  entryTimestamp: number;
  earnedYield: bigint;
  ghostStreak: number;
  nextScanTimestamp: number;
}

export interface Modifier {
  id: string;
  source: 'typing' | 'hackrun' | 'crew' | 'daily' | 'network' | 'consumable';
  type: 'death_rate' | 'yield_multiplier';
  value: number;           // -0.15 = -15% death rate, 1.5 = 1.5x yield
  expiresAt: number | null;
  label: string;
}

// ════════════════════════════════════════════════════════════════
// NETWORK STATE
// ════════════════════════════════════════════════════════════════

export interface NetworkState {
  tvl: bigint;
  tvlCapacity: bigint;
  operatorsOnline: number;
  operatorsAth: number;
  systemResetTimestamp: number;
  traceScanTimestamps: Record<Level, number>;
  burnRatePerHour: bigint;
  hourlyStats: {
    jackedIn: bigint;
    extracted: bigint;
    traced: bigint;
  };
}

export interface LevelStats {
  level: Level;
  operatorCount: number;
  totalStaked: bigint;
  baseDeathRate: number;
  effectiveDeathRate: number;
  nextScanTimestamp: number;
}

// ════════════════════════════════════════════════════════════════
// FEED EVENTS
// ════════════════════════════════════════════════════════════════

export type FeedEventType = 
  | 'JACK_IN'
  | 'EXTRACT'
  | 'TRACED'
  | 'SURVIVED'
  | 'TRACE_SCAN_WARNING'
  | 'TRACE_SCAN_START'
  | 'TRACE_SCAN_COMPLETE'
  | 'CASCADE'
  | 'WHALE_ALERT'
  | 'SYSTEM_RESET_WARNING'
  | 'SYSTEM_RESET'
  | 'CREW_EVENT'
  | 'MINIGAME_RESULT'
  | 'JACKPOT';

export interface FeedEvent {
  id: string;
  type: FeedEventType;
  timestamp: number;
  data: FeedEventData;
}

export type FeedEventData = 
  | { type: 'JACK_IN'; address: `0x${string}`; level: Level; amount: bigint }
  | { type: 'EXTRACT'; address: `0x${string}`; amount: bigint; gain: bigint }
  | { type: 'TRACED'; address: `0x${string}`; level: Level; amountLost: bigint }
  | { type: 'SURVIVED'; address: `0x${string}`; level: Level; streak: number }
  | { type: 'TRACE_SCAN_WARNING'; level: Level; secondsUntil: number }
  | { type: 'TRACE_SCAN_START'; level: Level }
  | { type: 'TRACE_SCAN_COMPLETE'; level: Level; survivors: number; traced: number }
  | { type: 'CASCADE'; sourceLevel: Level; burned: bigint; distributed: bigint }
  | { type: 'WHALE_ALERT'; address: `0x${string}`; level: Level; amount: bigint }
  | { type: 'SYSTEM_RESET_WARNING'; secondsUntil: number }
  | { type: 'SYSTEM_RESET'; penaltyPercent: number; jackpotWinner: `0x${string}` }
  | { type: 'CREW_EVENT'; crewName: string; eventType: string; message: string }
  | { type: 'MINIGAME_RESULT'; address: `0x${string}`; game: string; result: string }
  | { type: 'JACKPOT'; address: `0x${string}`; level: Level; amount: bigint };

// ════════════════════════════════════════════════════════════════
// TYPING GAME
// ════════════════════════════════════════════════════════════════

export interface TypingChallenge {
  command: string;
  difficulty: 'easy' | 'medium' | 'hard';
  timeLimit: number;
}

export interface TypingResult {
  accuracy: number;
  wpm: number;
  timeElapsed: number;
  reward: {
    type: 'death_rate_reduction';
    value: number;
    label: string;
  } | null;
}

// ════════════════════════════════════════════════════════════════
// CREW
// ════════════════════════════════════════════════════════════════

export interface Crew {
  id: string;
  name: string;
  memberCount: number;
  maxMembers: number;
  rank: number;
  totalStaked: bigint;
  weeklyExtracted: bigint;
  bonuses: CrewBonus[];
  members: CrewMember[];
}

export interface CrewMember {
  address: `0x${string}`;
  level: Level;
  stakedAmount: bigint;
  ghostStreak: number;
  isOnline: boolean;
  isYou: boolean;
}

export interface CrewBonus {
  name: string;
  condition: string;
  effect: string;
  active: boolean;
}

// ════════════════════════════════════════════════════════════════
// DEAD POOL
// ════════════════════════════════════════════════════════════════

export interface DeadPoolRound {
  id: string;
  roundNumber: number;
  type: 'death_count' | 'whale_watch' | 'survival_streak' | 'system_reset';
  targetLevel: Level;
  question: string;
  line: number;
  endsAt: number;
  pools: {
    under: bigint;
    over: bigint;
  };
  userBet: {
    side: 'under' | 'over';
    amount: bigint;
  } | null;
}
```

### 2.2 Provider Interface

```typescript
// lib/core/providers/types.ts

import type { 
  User, Position, Modifier, NetworkState, FeedEvent, 
  Level, Crew, DeadPoolRound, TypingChallenge 
} from '../types';

// ════════════════════════════════════════════════════════════════
// DATA PROVIDER INTERFACE
// ════════════════════════════════════════════════════════════════

export interface DataProvider {
  // Connection
  connect(): Promise<void>;
  disconnect(): void;
  readonly connectionStatus: ConnectionStatus;

  // User
  readonly currentUser: User | null;
  connectWallet(): Promise<void>;
  disconnectWallet(): void;

  // Position
  readonly position: Position | null;
  readonly modifiers: Modifier[];
  jackIn(level: Level, amount: bigint): Promise<string>;  // returns tx hash
  extract(): Promise<string>;

  // Network
  readonly networkState: NetworkState;
  getLevelStats(level: Level): LevelStats;

  // Feed
  readonly feedEvents: FeedEvent[];
  subscribeFeed(callback: (event: FeedEvent) => void): () => void;

  // Typing
  getTypingChallenge(): TypingChallenge;
  submitTypingResult(result: TypingResult): Promise<void>;

  // Crew (optional for MVP)
  readonly crew: Crew | null;

  // Dead Pool (optional for MVP)
  readonly activeRounds: DeadPoolRound[];
  placeBet(roundId: string, side: 'under' | 'over', amount: bigint): Promise<string>;
}

// ════════════════════════════════════════════════════════════════
// PROVIDER CONTEXT KEY
// ════════════════════════════════════════════════════════════════

export const DATA_PROVIDER_KEY = Symbol('dataProvider');
```

---

## 3. Mock Data Provider

### 3.1 Mock Provider Implementation

```typescript
// lib/core/providers/mock/provider.svelte.ts

import type { DataProvider, ConnectionStatus } from '../types';
import type { 
  User, Position, Modifier, NetworkState, FeedEvent, 
  Level, LevelStats, Crew, DeadPoolRound, TypingChallenge, TypingResult 
} from '../../types';
import { generateMockFeedEvents } from './generators/feed';
import { generateMockPosition } from './generators/position';
import { generateMockNetworkState } from './generators/network';
import { TYPING_COMMANDS } from './data/commands';

export function createMockProvider(): DataProvider {
  // ══════════════════════════════════════════════════════════════
  // STATE
  // ══════════════════════════════════════════════════════════════
  
  let connectionStatus = $state<ConnectionStatus>('disconnected');
  let currentUser = $state<User | null>(null);
  let position = $state<Position | null>(null);
  let modifiers = $state<Modifier[]>([]);
  let networkState = $state<NetworkState>(generateMockNetworkState());
  let feedEvents = $state<FeedEvent[]>([]);
  let crew = $state<Crew | null>(null);
  let activeRounds = $state<DeadPoolRound[]>([]);

  // Feed subscribers
  const feedSubscribers = new Set<(event: FeedEvent) => void>();
  
  // Simulation intervals
  let feedInterval: ReturnType<typeof setInterval> | null = null;
  let networkInterval: ReturnType<typeof setInterval> | null = null;

  // ══════════════════════════════════════════════════════════════
  // CONNECTION
  // ══════════════════════════════════════════════════════════════

  async function connect(): Promise<void> {
    connectionStatus = 'connecting';
    
    // Simulate connection delay
    await sleep(500);
    
    connectionStatus = 'connected';
    
    // Start simulations
    startFeedSimulation();
    startNetworkSimulation();
  }

  function disconnect(): void {
    connectionStatus = 'disconnected';
    stopSimulations();
  }

  // ══════════════════════════════════════════════════════════════
  // WALLET
  // ══════════════════════════════════════════════════════════════

  async function connectWallet(): Promise<void> {
    await sleep(300);
    
    currentUser = {
      address: '0x7a3f9c2d8b1e4a5f6c7d8e9f0a1b2c3d4e5f6789',
      tokenBalance: 10000n * 10n ** 18n,  // 10,000 $DATA
      ethBalance: 5n * 10n ** 18n,         // 5 ETH
    };

    // Generate a position for the user
    position = generateMockPosition(currentUser.address);
    
    // Add some modifiers
    modifiers = [
      {
        id: '1',
        source: 'typing',
        type: 'death_rate',
        value: -0.15,
        expiresAt: Date.now() + 3600000,
        label: 'Trace Evasion -15%',
      },
      {
        id: '2', 
        source: 'crew',
        type: 'yield_multiplier',
        value: 1.1,
        expiresAt: null,
        label: 'Crew Bonus +10%',
      },
    ];
  }

  function disconnectWallet(): void {
    currentUser = null;
    position = null;
    modifiers = [];
  }

  // ══════════════════════════════════════════════════════════════
  // POSITION ACTIONS
  // ══════════════════════════════════════════════════════════════

  async function jackIn(level: Level, amount: bigint): Promise<string> {
    if (!currentUser) throw new Error('Wallet not connected');
    
    await sleep(1000); // Simulate tx
    
    const txHash = `0x${Math.random().toString(16).slice(2)}`;
    
    position = {
      id: crypto.randomUUID(),
      address: currentUser.address,
      level,
      stakedAmount: amount,
      entryTimestamp: Date.now(),
      earnedYield: 0n,
      ghostStreak: 0,
      nextScanTimestamp: Date.now() + getScanInterval(level),
    };

    // Add to feed
    emitFeedEvent({
      type: 'JACK_IN',
      address: currentUser.address,
      level,
      amount,
    });

    return txHash;
  }

  async function extract(): Promise<string> {
    if (!currentUser || !position) throw new Error('No position');
    
    await sleep(1000);
    
    const txHash = `0x${Math.random().toString(16).slice(2)}`;
    const gain = position.earnedYield;
    const amount = position.stakedAmount + gain;

    emitFeedEvent({
      type: 'EXTRACT',
      address: currentUser.address,
      amount,
      gain,
    });

    position = null;
    
    return txHash;
  }

  // ══════════════════════════════════════════════════════════════
  // NETWORK
  // ══════════════════════════════════════════════════════════════

  function getLevelStats(level: Level): LevelStats {
    const config = LEVEL_CONFIG[level];
    return {
      level,
      operatorCount: Math.floor(Math.random() * 500) + 50,
      totalStaked: BigInt(Math.floor(Math.random() * 100000)) * 10n ** 18n,
      baseDeathRate: config.baseDeathRate,
      effectiveDeathRate: config.baseDeathRate * 0.92, // Network modifier
      nextScanTimestamp: networkState.traceScanTimestamps[level],
    };
  }

  // ══════════════════════════════════════════════════════════════
  // FEED
  // ══════════════════════════════════════════════════════════════

  function subscribeFeed(callback: (event: FeedEvent) => void): () => void {
    feedSubscribers.add(callback);
    return () => feedSubscribers.delete(callback);
  }

  function emitFeedEvent(data: FeedEventData): void {
    const event: FeedEvent = {
      id: crypto.randomUUID(),
      type: data.type,
      timestamp: Date.now(),
      data,
    };
    
    feedEvents = [event, ...feedEvents].slice(0, 100);
    feedSubscribers.forEach(cb => cb(event));
  }

  // ══════════════════════════════════════════════════════════════
  // TYPING
  // ══════════════════════════════════════════════════════════════

  function getTypingChallenge(): TypingChallenge {
    const command = TYPING_COMMANDS[Math.floor(Math.random() * TYPING_COMMANDS.length)];
    return {
      command,
      difficulty: command.length < 40 ? 'easy' : command.length < 70 ? 'medium' : 'hard',
      timeLimit: 60,
    };
  }

  async function submitTypingResult(result: TypingResult): Promise<void> {
    if (!position) return;
    
    if (result.reward) {
      modifiers = [
        ...modifiers.filter(m => m.source !== 'typing'),
        {
          id: crypto.randomUUID(),
          source: 'typing',
          type: 'death_rate',
          value: result.reward.value,
          expiresAt: position.nextScanTimestamp,
          label: result.reward.label,
        },
      ];
    }
  }

  // ══════════════════════════════════════════════════════════════
  // SIMULATIONS
  // ══════════════════════════════════════════════════════════════

  function startFeedSimulation(): void {
    // Generate initial feed events
    feedEvents = generateMockFeedEvents(20);
    
    // Generate new events periodically
    feedInterval = setInterval(() => {
      const newEvents = generateMockFeedEvents(1);
      newEvents.forEach(event => {
        feedEvents = [event, ...feedEvents].slice(0, 100);
        feedSubscribers.forEach(cb => cb(event));
      });
    }, 2000 + Math.random() * 3000); // 2-5 seconds
  }

  function startNetworkSimulation(): void {
    networkInterval = setInterval(() => {
      // Update network state
      networkState = {
        ...networkState,
        operatorsOnline: networkState.operatorsOnline + Math.floor(Math.random() * 10) - 5,
        tvl: networkState.tvl + BigInt(Math.floor(Math.random() * 10000 - 5000)) * 10n ** 18n,
      };

      // Update position yield if exists
      if (position) {
        position = {
          ...position,
          earnedYield: position.earnedYield + BigInt(Math.floor(Math.random() * 100)) * 10n ** 15n,
        };
      }
    }, 1000);
  }

  function stopSimulations(): void {
    if (feedInterval) clearInterval(feedInterval);
    if (networkInterval) clearInterval(networkInterval);
    feedInterval = null;
    networkInterval = null;
  }

  // ══════════════════════════════════════════════════════════════
  // RETURN INTERFACE
  // ══════════════════════════════════════════════════════════════

  return {
    // Connection
    connect,
    disconnect,
    get connectionStatus() { return connectionStatus; },

    // User
    get currentUser() { return currentUser; },
    connectWallet,
    disconnectWallet,

    // Position
    get position() { return position; },
    get modifiers() { return modifiers; },
    jackIn,
    extract,

    // Network
    get networkState() { return networkState; },
    getLevelStats,

    // Feed
    get feedEvents() { return feedEvents; },
    subscribeFeed,

    // Typing
    getTypingChallenge,
    submitTypingResult,

    // Optional
    get crew() { return crew; },
    get activeRounds() { return activeRounds; },
    placeBet: async () => { throw new Error('Not implemented'); },
  };
}

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function getScanInterval(level: Level): number {
  const hours = {
    VAULT: Infinity,
    MAINFRAME: 24,
    SUBNET: 8,
    DARKNET: 2,
    BLACK_ICE: 0.5,
  };
  return hours[level] * 60 * 60 * 1000;
}

const LEVEL_CONFIG = {
  VAULT: { baseDeathRate: 0 },
  MAINFRAME: { baseDeathRate: 0.02 },
  SUBNET: { baseDeathRate: 0.15 },
  DARKNET: { baseDeathRate: 0.40 },
  BLACK_ICE: { baseDeathRate: 0.90 },
};
```

### 3.2 Mock Data Generators

```typescript
// lib/core/providers/mock/generators/feed.ts

import type { FeedEvent, FeedEventData, Level } from '../../../types';

const LEVELS: Level[] = ['VAULT', 'MAINFRAME', 'SUBNET', 'DARKNET', 'BLACK_ICE'];

export function generateMockFeedEvents(count: number): FeedEvent[] {
  const events: FeedEvent[] = [];
  
  for (let i = 0; i < count; i++) {
    events.push(generateRandomFeedEvent());
  }
  
  return events.sort((a, b) => b.timestamp - a.timestamp);
}

function generateRandomFeedEvent(): FeedEvent {
  const type = pickRandom([
    'JACK_IN', 'JACK_IN', 'JACK_IN',  // More common
    'EXTRACT', 'EXTRACT',
    'TRACED',
    'SURVIVED', 'SURVIVED',
    'TRACE_SCAN_WARNING',
  ]);

  return {
    id: crypto.randomUUID(),
    type,
    timestamp: Date.now() - Math.random() * 60000, // Last minute
    data: generateEventData(type),
  };
}

function generateEventData(type: string): FeedEventData {
  const address = generateRandomAddress();
  const level = pickRandom(LEVELS);
  const amount = BigInt(Math.floor(Math.random() * 1000 + 10)) * 10n ** 18n;

  switch (type) {
    case 'JACK_IN':
      return { type: 'JACK_IN', address, level, amount };
    
    case 'EXTRACT':
      const gain = BigInt(Math.floor(Math.random() * 500)) * 10n ** 18n;
      return { type: 'EXTRACT', address, amount, gain };
    
    case 'TRACED':
      return { type: 'TRACED', address, level, amountLost: amount };
    
    case 'SURVIVED':
      return { type: 'SURVIVED', address, level, streak: Math.floor(Math.random() * 20) + 1 };
    
    case 'TRACE_SCAN_WARNING':
      return { type: 'TRACE_SCAN_WARNING', level, secondsUntil: Math.floor(Math.random() * 60) + 10 };
    
    default:
      return { type: 'JACK_IN', address, level, amount };
  }
}

function generateRandomAddress(): `0x${string}` {
  const chars = '0123456789abcdef';
  let addr = '0x';
  for (let i = 0; i < 40; i++) {
    addr += chars[Math.floor(Math.random() * chars.length)];
  }
  return addr as `0x${string}`;
}

function pickRandom<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}
```

```typescript
// lib/core/providers/mock/generators/network.ts

import type { NetworkState, Level } from '../../../types';

export function generateMockNetworkState(): NetworkState {
  const now = Date.now();
  
  return {
    tvl: BigInt(4847291) * 10n ** 18n,
    tvlCapacity: BigInt(5500000) * 10n ** 18n,
    operatorsOnline: 1247,
    operatorsAth: 2150,
    systemResetTimestamp: now + 4 * 60 * 60 * 1000 + 32 * 60 * 1000, // 4:32 from now
    traceScanTimestamps: {
      VAULT: now + 24 * 60 * 60 * 1000,
      MAINFRAME: now + 18 * 60 * 60 * 1000,
      SUBNET: now + 5 * 60 * 60 * 1000,
      DARKNET: now + 1 * 60 * 60 * 1000 + 23 * 60 * 1000, // 1:23 from now
      BLACK_ICE: now + 15 * 60 * 1000, // 15 min from now
    },
    burnRatePerHour: 847n * 10n ** 18n,
    hourlyStats: {
      jackedIn: BigInt(127400) * 10n ** 18n,
      extracted: BigInt(89200) * 10n ** 18n,
      traced: BigInt(34100) * 10n ** 18n,
    },
  };
}
```

```typescript
// lib/core/providers/mock/generators/position.ts

import type { Position, Level } from '../../../types';

export function generateMockPosition(address: `0x${string}`): Position {
  const level: Level = 'DARKNET';
  const now = Date.now();
  
  return {
    id: crypto.randomUUID(),
    address,
    level,
    stakedAmount: 500n * 10n ** 18n,
    entryTimestamp: now - 2 * 60 * 60 * 1000, // 2 hours ago
    earnedYield: 47n * 10n ** 18n,
    ghostStreak: 7,
    nextScanTimestamp: now + 1 * 60 * 60 * 1000 + 23 * 60 * 1000, // 1:23 from now
  };
}
```

```typescript
// lib/core/providers/mock/data/commands.ts

export const TYPING_COMMANDS = [
  // Network commands
  'ssh -L 8080:localhost:443 ghost@proxy.darknet.io',
  'nmap -sS -sV -p- --script vuln target.subnet',
  'curl -X POST -H "Auth: Bearer token" https://api.ghost/extract',
  'nc -lvnp 4444 -e /bin/bash',
  'tcpdump -i eth0 -w capture.pcap host 192.168.1.1',

  // Encryption
  'openssl enc -aes-256-cbc -salt -in data.bin -out cipher.enc',
  'gpg --encrypt --recipient ghost@net --armor payload.dat',
  'hashcat -m 1000 -a 0 ntlm.hash wordlist.txt',

  // Exploitation
  'msfconsole -q -x "use exploit/multi/handler; set PAYLOAD"',
  'sqlmap -u "target.io/id=1" --dump --batch --level=5',
  'nikto -h https://target.io -ssl -output scan.txt',

  // System commands
  'sudo iptables -A INPUT -s 0.0.0.0/0 -j DROP',
  'find / -perm -4000 -type f 2>/dev/null',
  'cat /etc/passwd | grep -v nologin',

  // Data extraction
  'rsync -avz --progress /vault/data ghost@exit:/extracted/',
  'tar -czvf payload.tar.gz ./loot && scp payload.tar.gz ghost:/out',
  'base64 -d encoded.txt | gunzip > decoded.bin',

  // Short ones (easy)
  'whoami && id && pwd',
  'ls -la /home/ghost',
  'cat /etc/passwd | grep root',
  'ping -c 4 ghostnet.io',
];
```

---

## 4. Implementation Phases

### Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    IMPLEMENTATION PHASES                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PHASE 0: Project Setup                    [✓] ██████████ 100%  │
│  ────────────────────────────────────────────────────────────   │
│  • Folder structure                                              │
│  • Dependencies                                                  │
│  • CSS tokens                                                    │
│                                                                  │
│  PHASE 1: Design System                    [✓] ██████████ 100%  │
│  ────────────────────────────────────────────────────────────   │
│  • Primitive components                                          │
│  • Typography                                                    │
│  • Layout utilities                                              │
│                                                                  │
│  PHASE 2: Terminal Shell                   [✓] ██████████ 100%  │
│  ────────────────────────────────────────────────────────────   │
│  • Shell wrapper                                                 │
│  • Scanlines, flicker                                            │
│  • Box component                                                 │
│                                                                  │
│  PHASE 3: Core Infrastructure              [✓] ██████████ 100%  │
│  ────────────────────────────────────────────────────────────   │
│  • Type definitions                                              │
│  • Mock provider                                                 │
│  • Event bus                                                     │
│  • Store setup                                                   │
│                                                                  │
│  PHASE 4: Command Center                   [  ] ░░░░░░░░░░  0%  │
│  ────────────────────────────────────────────────────────────   │
│  • Feed panel                                                    │
│  • Position panel                                                │
│  • Network vitals                                                │
│  • Quick actions                                                 │
│                                                                  │
│  PHASE 5: Typing Game                      [  ] ░░░░░░░░░░  0%  │
│  ────────────────────────────────────────────────────────────   │
│  • All states (idle, countdown, active, complete)                │
│  • Keyboard input                                                │
│  • Results & rewards                                             │
│                                                                  │
│  PHASE 6: Integration & Polish             [  ] ░░░░░░░░░░  0%  │
│  ────────────────────────────────────────────────────────────   │
│  • Audio system                                                  │
│  • Visual effects                                                │
│  • Navigation                                                    │
│  • Responsive                                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Phase 0: Project Setup

### Checklist

```
PHASE 0: PROJECT SETUP ✓ COMPLETE (2026-01-19)
══════════════════════════════════════════════════════════════════

✓ 0.1 Folder Structure
  ✓ Create lib/core/types/
  ✓ Create lib/core/providers/
  ✓ Create lib/core/providers/mock/
  ✓ Create lib/core/providers/mock/generators/
  ✓ Create lib/core/providers/mock/data/
  ✓ Create lib/core/stores/
  ✓ Create lib/core/events/
  ✓ Create lib/ui/primitives/
  ✓ Create lib/ui/terminal/
  ✓ Create lib/ui/data-display/
  ✓ Create lib/ui/layout/
  ✓ Create lib/features/feed/
  ✓ Create lib/features/position/
  ✓ Create lib/features/network/
  ✓ Create lib/features/typing/
  ✓ Create lib/audio/

✓ 0.2 CSS Setup
  ✓ Create lib/ui/styles/tokens.css (design tokens)
  ✓ Create lib/ui/styles/reset.css (CSS reset)
  ✓ Create lib/ui/styles/utilities.css (utility classes)
  ✓ Create lib/ui/styles/animations.css (keyframes)
  ✓ Import styles in app.css

✓ 0.3 Dependencies
  ✓ Verify IBM Plex Mono font is available
  ✓ Install zzfx (for audio)

✓ 0.4 TypeScript Config
  ✓ Verify path aliases work ($lib/*)

ACCEPTANCE CRITERIA: ✓ ALL MET
────────────────────
✓ All folders exist
✓ CSS tokens load without errors
✓ Font renders correctly
✓ Dev server starts successfully
```

### Files to Create

```
apps/web/src/
├── app.css                    # Global styles import
├── lib/
│   ├── core/
│   │   ├── types/
│   │   │   └── index.ts       # All type definitions
│   │   ├── providers/
│   │   │   ├── types.ts       # Provider interface
│   │   │   └── mock/
│   │   │       ├── provider.svelte.ts
│   │   │       ├── generators/
│   │   │       │   ├── feed.ts
│   │   │       │   ├── network.ts
│   │   │       │   └── position.ts
│   │   │       └── data/
│   │   │           └── commands.ts
│   │   ├── stores/
│   │   │   └── index.svelte.ts
│   │   └── events/
│   │       └── bus.svelte.ts
│   │
│   └── ui/
│       └── styles/
│           ├── tokens.css
│           ├── reset.css
│           ├── utilities.css
│           └── animations.css
```

---

## 6. Phase 1: Design System

### Checklist

```
PHASE 1: DESIGN SYSTEM ✓ COMPLETE (2026-01-19)
══════════════════════════════════════════════════════════════════

✓ 1.1 Design Tokens (tokens.css) - Created in Phase 0
  ✓ Color variables (all from master design)
  ✓ Typography variables
  ✓ Spacing scale
  ✓ Border/radius variables
  ✓ Animation timing variables

✓ 1.2 Primitive Components
  ✓ Button.svelte
    ✓ Props: variant, size, hotkey, disabled, loading
    ✓ Styles: terminal aesthetic
  
  ✓ ProgressBar.svelte
    ✓ Props: value, variant, showPercent, animated
    ✓ ASCII style (████░░░░)
  
  ✓ AnimatedNumber.svelte
    ✓ Props: value, format, duration
    ✓ Tweened animation
  
  ✓ Countdown.svelte
    ✓ Props: targetTime, format, urgent, onComplete
    ✓ Auto-updating display
    ✓ Urgent styling when < threshold
  
  ✓ Badge.svelte
    ✓ Props: variant (level, status, hotkey)
    ✓ Glow and pulse animations
  
  ✓ Spinner.svelte
    ✓ Props: size, variant
    ✓ ASCII spinner animation (|/-\, dots, bar)

✓ 1.3 Data Display Components
  ✓ AddressDisplay.svelte
    ✓ Props: address, truncate, copyable
    ✓ Copy to clipboard functionality
  
  ✓ AmountDisplay.svelte
    ✓ Props: amount (bigint), symbol, decimals
    ✓ Proper formatting with Đ symbol
  
  ✓ PercentDisplay.svelte
    ✓ Props: value, trend (up/down/stable)
    ✓ Color coding
    ✓ Trend arrows
  
  ✓ LevelBadge.svelte
    ✓ Props: level, glow, compact
    ✓ Color per level

✓ 1.4 Layout Components
  ✓ Stack.svelte (vertical spacing)
  ✓ Row.svelte (horizontal layout)

ACCEPTANCE CRITERIA: ✓ ALL MET
────────────────────
✓ All components render correctly
✓ All variants work
✓ Components follow terminal aesthetic
✓ svelte-check passes with 0 errors
✓ Test page demonstrates all components
```

### Component Specifications

```typescript
// Button variants
type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'ghost';
type ButtonSize = 'sm' | 'md' | 'lg';

// ProgressBar variants
type ProgressVariant = 'default' | 'danger' | 'warning' | 'success';

// Badge variants
type BadgeVariant = 'level' | 'status' | 'hotkey' | 'modifier';
```

---

## 7. Phase 2: Terminal Shell

### Checklist

```
PHASE 2: TERMINAL SHELL
══════════════════════════════════════════════════════════════════

✓ 2.1 Shell Component
  ✓ Shell.svelte
    ✓ Full viewport wrapper
    ✓ Background color
    ✓ Font family applied
    ✓ Children slot

✓ 2.2 CRT Effects
  ✓ Scanlines.svelte
    ✓ Horizontal line overlay
    ✓ CSS only (no JS)
    ✓ Configurable opacity
  
  ✓ Flicker.svelte
    ✓ Props: enabled, intensity (subtle/normal/intense)
    ✓ Multiple flicker intensities
    ✓ Respects prefers-reduced-motion
  
  ✓ ScreenFlash.svelte
    ✓ Full screen color overlay
    ✓ Props: type (death/jackpot/warning/success/custom)
    ✓ Shake animation for death
    ✓ onComplete callback

✓ 2.3 Box Component
  ✓ Box.svelte
    ✓ Props: title, variant (single/double/rounded)
    ✓ Props: borderColor, glow, padding
    ✓ ASCII border characters
  
  ✓ Panel.svelte
    ✓ Props: title, scrollable, maxHeight
    ✓ Uses Box internally
    ✓ Scroll indicator
    ✓ Optional footer snippet

- 2.4 Typography (DEFERRED - using utility classes instead)
  - Heading.svelte - using .text-* utilities
  - Text.svelte - using .text-* utilities

✓ 2.5 Layout Integration
  ✓ Update +layout.svelte to use Shell
  ✓ Scanlines + Flicker + ScreenFlash integrated
  ✓ Test page demonstrates Box/Panel

ACCEPTANCE CRITERIA: ✓ ALL MET (2026-01-19)
────────────────────
✓ Terminal aesthetic matches design
✓ Scanlines visible but subtle
✓ Flicker is subtle, not distracting
✓ Box borders render correctly
✓ svelte-check passes with 0 errors
```

### Shell Structure

```svelte
<!-- +layout.svelte -->
<script>
  import Shell from '$lib/ui/terminal/Shell.svelte';
  import Scanlines from '$lib/ui/terminal/Scanlines.svelte';
  import Flicker from '$lib/ui/terminal/Flicker.svelte';
  import ScreenFlash from '$lib/ui/terminal/ScreenFlash.svelte';
</script>

<Shell>
  <Scanlines />
  <Flicker>
    <slot />
  </Flicker>
  <ScreenFlash />
</Shell>
```

---

## 8. Phase 3: Core Infrastructure

### Checklist

```
PHASE 3: CORE INFRASTRUCTURE ✓ COMPLETE (2026-01-19)
══════════════════════════════════════════════════════════════════

✓ 3.1 Type Definitions
  ✓ lib/core/types/index.ts
    ✓ Level type with LEVEL_CONFIG
    ✓ User interface
    ✓ Position interface
    ✓ Modifier interface
    ✓ NetworkState interface
    ✓ FeedEvent types (14 event types)
    ✓ TypingChallenge/TypingResult interfaces
    ✓ Crew and DeadPoolRound interfaces

✓ 3.2 Provider Interface
  ✓ lib/core/providers/types.ts
    ✓ DataProvider interface (full contract)
    ✓ ConnectionStatus type
    ✓ DATA_PROVIDER_KEY for context

✓ 3.3 Mock Provider
  ✓ lib/core/providers/mock/provider.svelte.ts
    ✓ Implements full DataProvider interface
    ✓ Reactive state with $state
    ✓ Connection/wallet simulation
    ✓ Position/network state
    ✓ Feed event generation with intervals
    ✓ Typing challenge support
  
  ✓ lib/core/providers/mock/generators/feed.ts
    ✓ 10 event types with weighted distribution
    ✓ Random address generation
    ✓ Realistic amounts
  
  ✓ lib/core/providers/mock/generators/network.ts
    ✓ Initial network state
    ✓ Periodic updates
  
  ✓ lib/core/providers/mock/generators/position.ts
    ✓ Mock position generation
    ✓ Yield accumulation
  
  ✓ lib/core/providers/mock/data/commands.ts
    ✓ 40 hacker-themed typing commands
    ✓ Difficulty categorization

✓ 3.4 Store Setup
  ✓ lib/core/stores/index.svelte.ts
    ✓ initializeProvider() function
    ✓ getProvider() context helper

✓ 3.5 Integration
  ✓ +layout.svelte uses provider
    ✓ Auto-connect on mount
    ✓ Feed subscription for screen flashes
  ✓ Test page shows live data
    ✓ Live feed with real-time updates
    ✓ Network vitals with animated values
    ✓ Wallet connect/disconnect
    ✓ Position display with countdown

ACCEPTANCE CRITERIA: ✓ ALL MET
────────────────────
✓ Mock provider implements full interface
✓ Feed events generate every 2-5 seconds
✓ Network state updates every second
✓ Position yield accumulates
✓ Wallet connect/disconnect works
✓ Test page shows all live mock data
✓ Screen flashes on TRACED/JACKPOT events
```

### Provider Usage Pattern

```svelte
<!-- routes/+layout.svelte -->
<script lang="ts">
  import { setContext, onMount, onDestroy } from 'svelte';
  import { createMockProvider } from '$lib/core/providers/mock/provider.svelte';
  import { DATA_PROVIDER_KEY } from '$lib/core/providers/types';
  import Shell from '$lib/ui/terminal/Shell.svelte';

  const provider = createMockProvider();
  setContext(DATA_PROVIDER_KEY, provider);

  onMount(() => {
    provider.connect();
  });

  onDestroy(() => {
    provider.disconnect();
  });
</script>

<Shell>
  <slot />
</Shell>
```

---

## 9. Phase 4: Command Center

### Checklist

```
PHASE 4: COMMAND CENTER
══════════════════════════════════════════════════════════════════

□ 4.1 Page Layout
  □ routes/+page.svelte
    □ Two-column grid layout
    □ Header section
    □ Navigation bar
    □ Responsive breakpoints

□ 4.2 Header Component
  □ lib/features/header/Header.svelte
    □ Logo text ("GHOSTNET v1.0.7")
    □ Animated status bar (glitch line)
    □ Network status indicator
    □ Wallet connect button
  
  □ lib/features/header/WalletButton.svelte
    □ Connect state
    □ Connected state (show address)
    □ Click to connect/disconnect

□ 4.3 Feed Panel
  □ lib/features/feed/FeedPanel.svelte
    □ Box with "LIVE FEED" title
    □ Streaming indicator
    □ Feed list container
    □ Scroll hint footer
  
  □ lib/features/feed/FeedItem.svelte
    □ Props: event (FeedEvent)
    □ Format text based on event type
    □ Color coding per type
    □ Emoji indicators
    □ Current user highlighting
    □ Entry animation
  
  □ lib/features/feed/store.svelte.ts
    □ Subscribe to provider feed
    □ Maintain visible items list
    □ Priority sorting

□ 4.4 Position Panel
  □ lib/features/position/PositionPanel.svelte
    □ Box with user address
    □ Status display (JACKED IN / NOT JACKED IN)
    □ Level badge
    □ Staked amount
    □ Death rate with trend
    □ Yield APY (animated)
    □ Next scan countdown
    □ Extracted total
    □ Ghost streak with fire emoji
    □ Empty state when no position
  
  □ lib/features/position/ModifiersPanel.svelte
    □ Box with "ACTIVE MODIFIERS" title
    □ List of active modifiers
    □ Checkmark icons
    □ Expiration time where applicable

□ 4.5 Network Vitals Panel
  □ lib/features/network/NetworkVitalsPanel.svelte
    □ TVL with progress bar
    □ Operators online with progress bar
    □ System reset timer (critical styling)
    □ Hourly flow stats (tree style)
    □ Burn rate display

□ 4.6 Quick Actions Panel
  □ lib/features/actions/QuickActionsPanel.svelte
    □ Box with "QUICK ACTIONS" title
    □ Action buttons with hotkeys
  
  □ lib/features/actions/ActionButton.svelte
    □ Hotkey badge
    □ Action label
    □ Keyboard shortcut handling

□ 4.7 Navigation Bar
  □ lib/features/nav/NavigationBar.svelte
    □ Horizontal button row
    □ Active state
    □ Route links

□ 4.8 Integration
  □ Connect all panels to mock provider
  □ Verify live updates
  □ Test keyboard shortcuts
  □ Verify responsive layout

ACCEPTANCE CRITERIA:
────────────────────
✓ Layout matches design mockup
✓ Feed updates in real-time
✓ Position reflects mock data
✓ Network vitals update periodically
✓ Countdown timers work
✓ Keyboard shortcuts function
✓ Current user events highlighted
✓ All panels have proper terminal styling
```

### Layout Structure

```svelte
<!-- routes/+page.svelte -->
<script lang="ts">
  import Header from '$lib/features/header/Header.svelte';
  import FeedPanel from '$lib/features/feed/FeedPanel.svelte';
  import NetworkVitalsPanel from '$lib/features/network/NetworkVitalsPanel.svelte';
  import PositionPanel from '$lib/features/position/PositionPanel.svelte';
  import ModifiersPanel from '$lib/features/position/ModifiersPanel.svelte';
  import QuickActionsPanel from '$lib/features/actions/QuickActionsPanel.svelte';
  import NavigationBar from '$lib/features/nav/NavigationBar.svelte';
</script>

<div class="command-center">
  <Header />
  
  <main class="main-content">
    <div class="left-column">
      <FeedPanel />
      <NetworkVitalsPanel />
    </div>
    
    <div class="right-column">
      <PositionPanel />
      <ModifiersPanel />
      <QuickActionsPanel />
    </div>
  </main>
  
  <NavigationBar />
</div>
```

---

## 10. Phase 5: Typing Game

### Checklist

```
PHASE 5: TYPING GAME
══════════════════════════════════════════════════════════════════

□ 5.1 Page Setup
  □ routes/typing/+page.svelte
    □ Full-page typing game container
    □ State-based rendering

□ 5.2 Typing Store
  □ lib/features/typing/store.svelte.ts
    □ State machine (idle → countdown → active → complete)
    □ Challenge state
    □ Progress tracking
    □ Timer management
    □ Result calculation

□ 5.3 Idle View
  □ lib/features/typing/IdleView.svelte
    □ Current position summary
    □ Current protection status
    □ Reward tiers table
    □ Speed bonus info
    □ Start button

□ 5.4 Countdown View
  □ lib/features/typing/CountdownView.svelte
    □ "PREPARE FOR EVASION SEQUENCE"
    □ Large countdown number (3, 2, 1)
    □ Countdown animation
    □ Sound effect trigger

□ 5.5 Active View
  □ lib/features/typing/ActiveView.svelte
    □ Command prompt styling
    □ Target text display
    □ Typed text with cursor
    □ Progress bar
    □ Stats row (WPM, Accuracy, Time)
    □ Projected reward
  
  □ lib/features/typing/TypingInput.svelte
    □ Invisible input for keyboard capture
    □ Handle correct/incorrect keystrokes
    □ Emit events for audio triggers
    □ Handle backspace (optional)

□ 5.6 Complete View
  □ lib/features/typing/CompleteView.svelte
    □ Success checkmark animation
    □ Results summary
    □ Reward earned (if any)
    □ Before/after death rate comparison
    □ Action buttons (Practice Again, Return)

□ 5.7 Keyboard Handling
  □ Capture keystrokes globally during active state
  □ Prevent default browser behavior
  □ Handle special keys appropriately

□ 5.8 Integration
  □ Connect to provider for challenge data
  □ Submit results to provider
  □ Update modifiers in position store
  □ Navigation to/from main page

ACCEPTANCE CRITERIA:
────────────────────
✓ All 4 states render correctly
✓ Typing input captures all keys
✓ WPM calculates correctly
✓ Accuracy tracks errors
✓ Timer counts down
✓ Results show correct reward tier
✓ Modifier applies after completion
✓ Can navigate back to main screen
```

### State Machine

```typescript
// State transitions
type TypingState = 
  | { status: 'idle' }
  | { status: 'countdown'; secondsLeft: number }
  | { status: 'active'; challenge: Challenge; progress: Progress }
  | { status: 'complete'; result: Result };

// Transitions:
// idle → countdown (on START)
// countdown → active (when countdown reaches 0)
// active → complete (when finished or timeout)
// complete → idle (on RESET)
```

---

## 11. Phase 6: Integration & Polish

### Checklist

```
PHASE 6: INTEGRATION & POLISH
══════════════════════════════════════════════════════════════════

□ 6.1 Audio System
  □ lib/audio/manager.svelte.ts
    □ ZzFX integration
    □ Sound definitions
    □ Volume control
    □ Enable/disable toggle
    □ Persist preferences
  
  □ Connect audio to events:
    □ Feed events (traced, survived, etc.)
    □ Typing keystrokes
    □ Countdown ticks
    □ UI interactions

□ 6.2 Visual Effects Integration
  □ lib/core/effects/manager.svelte.ts
    □ Screen flash on deaths
    □ Screen flash on survivals
    □ Feed item highlighting
  
  □ Connect effects to events:
    □ TRACED → red flash
    □ SURVIVED → green flash
    □ JACKPOT → gold flash + shake

□ 6.3 Navigation
  □ Full navigation between pages
  □ Active state indicators
  □ Keyboard navigation (hotkeys)
  □ Back button handling

□ 6.4 Modals
  □ JackInModal.svelte
    □ Level selection
    □ Amount input
    □ Confirmation
  
  □ ExtractModal.svelte
    □ Amount preview
    □ Confirmation
  
  □ SettingsModal.svelte
    □ Audio toggle
    □ Volume slider
    □ Effects toggle

□ 6.5 Responsive Design
  □ Mobile layout (< 768px)
    □ Single column
    □ Collapsible panels
    □ Bottom navigation
  
  □ Tablet layout (768-1024px)
    □ Two columns
    □ Adjusted spacing
  
  □ Desktop layout (> 1024px)
    □ Full layout as designed

□ 6.6 Error Handling
  □ Connection error states
  □ Transaction error handling
  □ Graceful degradation

□ 6.7 Loading States
  □ Initial load spinner
  □ Button loading states
  □ Skeleton components for data

□ 6.8 Final Polish
  □ Verify all animations smooth
  □ Check all colors correct
  □ Verify all text readable
  □ Test all interactions
  □ Performance check

ACCEPTANCE CRITERIA:
────────────────────
✓ Audio plays correctly on events
✓ Screen flashes work
✓ All navigation functional
✓ Modals open/close properly
✓ Responsive on all breakpoints
✓ No console errors
✓ Performance is smooth
✓ All dummy data displays correctly
```

---

## 12. Acceptance Criteria

### Per-Phase Sign-Off

Each phase must meet these criteria before moving to the next:

```
PHASE COMPLETION CHECKLIST
══════════════════════════════════════════════════════════════════

□ All checklist items completed
□ No TypeScript errors
□ No console errors
□ Visual matches design
□ Components tested
□ Code reviewed
□ Documentation updated
```

### Final MVP Acceptance

```
MVP ACCEPTANCE CRITERIA
══════════════════════════════════════════════════════════════════

FUNCTIONALITY:
□ Can view live feed (mock data)
□ Can see position status
□ Can see network vitals
□ Can play typing game
□ Can see modifiers after typing
□ Navigation works

VISUAL:
□ Terminal aesthetic correct
□ All colors match design
□ Scanlines visible
□ Box borders render correctly
□ Animations smooth

AUDIO:
□ Sounds play on correct events
□ Volume controllable
□ Can mute

RESPONSIVE:
□ Works on mobile
□ Works on tablet  
□ Works on desktop

PERFORMANCE:
□ No jank during feed updates
□ Typing input responsive
□ Animations at 60fps

CODE QUALITY:
□ TypeScript strict mode
□ No any types
□ Components properly typed
□ Tests pass
```

---

## Quick Reference: File Creation Order

```
IMPLEMENTATION ORDER
══════════════════════════════════════════════════════════════════

PHASE 0:
  1. lib/ui/styles/tokens.css
  2. lib/ui/styles/reset.css
  3. lib/ui/styles/utilities.css
  4. lib/ui/styles/animations.css
  5. app.css (imports)

PHASE 1:
  6. lib/ui/primitives/Button.svelte
  7. lib/ui/primitives/ProgressBar.svelte
  8. lib/ui/primitives/AnimatedNumber.svelte
  9. lib/ui/primitives/Countdown.svelte
  10. lib/ui/primitives/Badge.svelte
  11. lib/ui/primitives/Spinner.svelte
  12. lib/ui/data-display/AddressDisplay.svelte
  13. lib/ui/data-display/AmountDisplay.svelte
  14. lib/ui/data-display/LevelBadge.svelte
  15. lib/ui/layout/Stack.svelte

PHASE 2:
  16. lib/ui/terminal/Shell.svelte
  17. lib/ui/terminal/Scanlines.svelte
  18. lib/ui/terminal/Flicker.svelte
  19. lib/ui/terminal/ScreenFlash.svelte
  20. lib/ui/terminal/Box.svelte
  21. Update routes/+layout.svelte

PHASE 3:
  22. lib/core/types/index.ts
  23. lib/core/providers/types.ts
  24. lib/core/providers/mock/data/commands.ts
  25. lib/core/providers/mock/generators/feed.ts
  26. lib/core/providers/mock/generators/network.ts
  27. lib/core/providers/mock/generators/position.ts
  28. lib/core/providers/mock/provider.svelte.ts
  29. lib/core/stores/index.svelte.ts

PHASE 4:
  30. lib/features/header/Header.svelte
  31. lib/features/header/WalletButton.svelte
  32. lib/features/feed/store.svelte.ts
  33. lib/features/feed/FeedItem.svelte
  34. lib/features/feed/FeedPanel.svelte
  35. lib/features/network/NetworkVitalsPanel.svelte
  36. lib/features/position/PositionPanel.svelte
  37. lib/features/position/ModifiersPanel.svelte
  38. lib/features/actions/QuickActionsPanel.svelte
  39. lib/features/nav/NavigationBar.svelte
  40. Update routes/+page.svelte

PHASE 5:
  41. lib/features/typing/store.svelte.ts
  42. lib/features/typing/IdleView.svelte
  43. lib/features/typing/CountdownView.svelte
  44. lib/features/typing/TypingInput.svelte
  45. lib/features/typing/ActiveView.svelte
  46. lib/features/typing/CompleteView.svelte
  47. lib/features/typing/TypingGame.svelte
  48. routes/typing/+page.svelte

PHASE 6:
  49. lib/audio/sounds.ts
  50. lib/audio/manager.svelte.ts
  51. lib/core/effects/manager.svelte.ts
  52. lib/features/modals/JackInModal.svelte
  53. lib/features/modals/ExtractModal.svelte
  54. lib/features/modals/SettingsModal.svelte
  55. Final polish and testing
```

---

## Notes

### Provider Swapping (Future)

When ready to integrate real data:

```typescript
// lib/core/providers/web3/provider.svelte.ts
// Implement same DataProvider interface with real Web3 calls

// In +layout.svelte, swap provider:
// import { createMockProvider } from '$lib/core/providers/mock/provider.svelte';
import { createWeb3Provider } from '$lib/core/providers/web3/provider.svelte';

const provider = createWeb3Provider(); // Instead of createMockProvider()
```

### Testing Scenarios

Mock provider can be extended to simulate:
- **Death scenario:** Force position to null
- **Jackpot scenario:** Emit JACKPOT event
- **System reset:** Trigger reset event
- **Connection loss:** Set status to disconnected

---

*End of Implementation Plan*
