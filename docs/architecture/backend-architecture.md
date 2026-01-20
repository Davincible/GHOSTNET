# GHOSTNET Backend Architecture

**Version:** 1.0  
**Status:** Planning  
**Last Updated:** 2026-01-20

---

## Table of Contents

1. [Overview](#1-overview)
2. [System Architecture](#2-system-architecture)
3. [Indexer Service](#3-indexer-service)
4. [WebSocket Gateway](#4-websocket-gateway)
5. [API Server](#5-api-server)
6. [Data Model](#6-data-model)
7. [Mini-Game Integration](#7-mini-game-integration)
8. [Infrastructure](#8-infrastructure)
9. [Security](#9-security)
10. [Monitoring](#10-monitoring)

---

## 1. Overview

### Purpose

The GHOSTNET backend provides:

1. **Event Indexing** - Listen to contract events, store in database, broadcast via WebSocket
2. **WebSocket Gateway** - Real-time event streaming to connected clients
3. **API Server** - RESTful endpoints for crews, profiles, leaderboards, mini-game validation
4. **Mini-Game Backend** - Validate gameplay, sign boost approvals (EIP-712)

### Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Runtime | Node.js 20+ / Bun | Fast, TypeScript native |
| Framework | Fastify | High performance, WebSocket support |
| Database | PostgreSQL 15+ | Relational, JSONB for flexibility |
| Cache | Redis | Pub/sub for events, session cache |
| Blockchain | viem | Type-safe, tree-shakeable |
| WebSocket | ws / uWebSockets.js | Native, performant |

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            BACKEND ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                            ┌──────────────────┐                             │
│                            │   MegaETH RPC    │                             │
│                            │   (Contract      │                             │
│                            │    Events)       │                             │
│                            └────────┬─────────┘                             │
│                                     │                                        │
│                                     ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         INDEXER SERVICE                               │   │
│  │  ────────────────────────────────────────────────────────────────────│   │
│  │  • Listens to contract events (JackedIn, Extracted, DeathsProcessed) │   │
│  │  • Parses and validates event data                                   │   │
│  │  • Writes to PostgreSQL                                              │   │
│  │  • Publishes to Redis pub/sub                                        │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                     │                                        │
│                    ┌────────────────┼────────────────┐                      │
│                    │                │                │                      │
│                    ▼                ▼                ▼                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │    PostgreSQL    │  │      Redis       │  │   Elasticsearch  │          │
│  │    ──────────    │  │    ─────────     │  │   (Optional)     │          │
│  │  • Events        │  │  • Pub/Sub       │  │  • Full-text     │          │
│  │  • Positions     │  │  • Sessions      │  │    search        │          │
│  │  • Users         │  │  • Rate limits   │  │  • Analytics     │          │
│  │  • Crews         │  │  • Cache         │  │                  │          │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                    │                │                                        │
│                    └────────┬───────┘                                       │
│                             │                                                │
│  ┌──────────────────────────┴───────────────────────────────────────────┐   │
│  │                       WEBSOCKET GATEWAY                               │   │
│  │  ────────────────────────────────────────────────────────────────────│   │
│  │  • Subscribes to Redis pub/sub                                       │   │
│  │  • Maintains client connections (authenticated)                      │   │
│  │  • Broadcasts events to subscribers                                  │   │
│  │  • Handles reconnection / gap detection                              │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                             │                                                │
│                             ▼                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                          API SERVER                                   │   │
│  │  ────────────────────────────────────────────────────────────────────│   │
│  │  • Auth (wallet signature verification)                              │   │
│  │  • User profiles                                                     │   │
│  │  • Crew management                                                   │   │
│  │  • Leaderboards                                                      │   │
│  │  • Mini-game result validation                                       │   │
│  │  • Boost signature generation (EIP-712)                              │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                             │                                                │
│                             ▼                                                │
│                    ┌──────────────────┐                                     │
│                    │     Clients      │                                     │
│                    │  (SvelteKit App) │                                     │
│                    └──────────────────┘                                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Indexer Service

### Purpose

Transform blockchain events into queryable data and real-time broadcasts.

### Events Indexed

| Contract Event | Action |
|----------------|--------|
| `JackedIn(user, amount, level, totalAmount)` | Create/update position, broadcast |
| `Extracted(user, principal, rewards)` | Close position, broadcast |
| `DeathsProcessed(level, count, totalCapital)` | Mark positions dead, broadcast |
| `CascadeDistributed(level, ...)` | Update stats, broadcast |
| `SystemResetTriggered(...)` | Mark penalties, broadcast |
| `PositionPenalized(user, level, penalty, newAmount)` | Update position, broadcast |
| `BoostApplied(user, boostType, ...)` | Add boost record |

### Implementation

```typescript
// services/indexer/index.ts

import { createPublicClient, http, parseAbiItem } from 'viem';
import { megaeth } from './chains';
import { GhostCoreAbi } from './abis';
import { db } from './db';
import { redis } from './redis';

const client = createPublicClient({
  chain: megaeth,
  transport: http(process.env.MEGAETH_RPC_URL),
});

// Watch for all relevant events
async function startIndexer() {
  const unwatch = client.watchContractEvent({
    address: GHOST_CORE_ADDRESS,
    abi: GhostCoreAbi,
    onLogs: async (logs) => {
      for (const log of logs) {
        await processEvent(log);
      }
    },
  });
  
  console.log('[Indexer] Started watching events');
}

async function processEvent(log: Log) {
  const { eventName, args, blockNumber, transactionHash } = log;
  
  // Begin transaction
  await db.transaction(async (tx) => {
    // 1. Store raw event
    await tx.insert(events).values({
      type: eventName,
      blockNumber,
      txHash: transactionHash,
      data: args,
      indexedAt: new Date(),
    });
    
    // 2. Update domain tables
    switch (eventName) {
      case 'JackedIn':
        await handleJackIn(tx, args);
        break;
      case 'Extracted':
        await handleExtract(tx, args);
        break;
      case 'DeathsProcessed':
        await handleDeaths(tx, args);
        break;
      // ... other events
    }
    
    // 3. Publish to Redis for real-time
    await redis.publish('ghostnet:events', JSON.stringify({
      type: eventName,
      data: args,
      timestamp: Date.now(),
      sequenceId: await getNextSequenceId(),
    }));
  });
}
```

### Latency Budget

| Stage | Target |
|-------|--------|
| Block confirmation → Indexer receives | < 100ms |
| Indexer processes → DB write | < 50ms |
| Redis publish → Gateway receives | < 10ms |
| Gateway → Client receives | < 50ms |
| **Total** | **< 300ms** |

---

## 4. WebSocket Gateway

### Protocol

```
Connection:     wss://api.ghostnet.io/ws
Authentication: JWT token in first message
Heartbeat:      30-second ping/pong
```

### Message Types

#### Server → Client

```typescript
// Feed event (most common)
{
  type: 'FEED_EVENT',
  event: {
    type: 'JACK_IN',
    address: '0x...',
    level: 'DARKNET',
    amount: '500000000000000000000',
    timestamp: 1705790400000
  },
  sequenceId: 12345
}

// Position update (for current user)
{
  type: 'POSITION_UPDATE',
  position: { ... }
}

// Scan warning
{
  type: 'SCAN_WARNING',
  level: 'BLACK_ICE',
  secondsUntil: 60
}

// Connection state
{
  type: 'CONNECTION_STATE',
  status: 'connected' | 'reconnecting' | 'error'
}

// Replay (after reconnect)
{
  type: 'REPLAY',
  events: [...],  // Array of missed events
  fromSequenceId: 12300,
  toSequenceId: 12345
}
```

#### Client → Server

```typescript
// Authentication (first message)
{
  type: 'AUTH',
  token: 'jwt...'
}

// Reconnection (request missed events)
{
  type: 'RECONNECT',
  lastSequenceId: 12300
}

// Ping (keepalive)
{
  type: 'PING'
}
```

### Reconnection Flow

```
┌────────────────────────────────────────────────────────────────────┐
│                     RECONNECTION SEQUENCE                           │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Client                              Server                         │
│  ──────                              ──────                         │
│     │                                   │                           │
│     │──── Connect ─────────────────────>│                           │
│     │                                   │                           │
│     │──── AUTH { token }───────────────>│                           │
│     │                                   │                           │
│     │<─── CONNECTION_STATE: connected ──│                           │
│     │                                   │                           │
│     │──── RECONNECT { lastSeqId: 12300}─>│                          │
│     │                                   │                           │
│     │          [If gap < 1000 events]   │                           │
│     │<─── REPLAY { events: [...] }──────│                           │
│     │                                   │                           │
│     │          [If gap >= 1000 events]  │                           │
│     │<─── FULL_SYNC { snapshot: {...} }─│                           │
│     │                                   │                           │
│     │<─── FEED_EVENT (live) ────────────│                           │
│     │<─── FEED_EVENT (live) ────────────│                           │
│     │                                   │                           │
└────────────────────────────────────────────────────────────────────┘
```

### Implementation

```typescript
// services/gateway/index.ts

import { WebSocketServer } from 'ws';
import { redis } from './redis';
import { verifyJwt } from './auth';

const wss = new WebSocketServer({ port: 8080 });

// Track connections by user
const connections = new Map<string, Set<WebSocket>>();

// Subscribe to Redis for events
const subscriber = redis.duplicate();
await subscriber.subscribe('ghostnet:events');

subscriber.on('message', (channel, message) => {
  const event = JSON.parse(message);
  broadcast(event);
});

function broadcast(event: ServerEvent) {
  for (const [userId, sockets] of connections) {
    for (const socket of sockets) {
      if (socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify({
          type: 'FEED_EVENT',
          event,
          sequenceId: event.sequenceId,
        }));
      }
    }
  }
}

wss.on('connection', (socket) => {
  let userId: string | null = null;
  let authenticated = false;
  
  socket.on('message', async (data) => {
    const message = JSON.parse(data.toString());
    
    switch (message.type) {
      case 'AUTH':
        const payload = await verifyJwt(message.token);
        if (payload) {
          userId = payload.sub;
          authenticated = true;
          addConnection(userId, socket);
          socket.send(JSON.stringify({ type: 'CONNECTION_STATE', status: 'connected' }));
        }
        break;
        
      case 'RECONNECT':
        if (!authenticated) return;
        const missedEvents = await getMissedEvents(message.lastSequenceId);
        if (missedEvents.length < 1000) {
          socket.send(JSON.stringify({ type: 'REPLAY', events: missedEvents }));
        } else {
          const snapshot = await getFullSnapshot(userId);
          socket.send(JSON.stringify({ type: 'FULL_SYNC', snapshot }));
        }
        break;
        
      case 'PING':
        socket.send(JSON.stringify({ type: 'PONG' }));
        break;
    }
  });
  
  socket.on('close', () => {
    if (userId) {
      removeConnection(userId, socket);
    }
  });
});
```

---

## 5. API Server

### Endpoints

#### Authentication

```
POST /auth/verify
  Body: { message, signature }
  Response: { token, expiresAt }
  
  Verifies wallet signature, issues JWT (24h expiry)
```

#### Users

```
GET /users/:address
  Response: { address, ensName, totalExtracted, ghostStreakBest, createdAt }

GET /users/:address/history
  Query: ?limit=50&offset=0
  Response: { positions: [...], total }
```

#### Crews

```
GET /crews
  Query: ?search=&sort=rank&limit=20
  Response: { crews: [...], total }

GET /crews/:id
  Response: { id, name, members: [...], stats: {...}, bonuses: [...] }

POST /crews
  Auth: Required
  Body: { name }
  Response: { id, name }

POST /crews/:id/join
  Auth: Required
  Response: { success }

POST /crews/:id/leave
  Auth: Required
  Response: { success }
```

#### Leaderboard

```
GET /leaderboard
  Query: ?type=extracted|streak|pnl&period=daily|weekly|all&limit=100
  Response: { entries: [{ rank, address, value }] }
```

#### Mini-Games

```
POST /minigame/typing/result
  Auth: Required
  Body: { 
    accuracy: 0.94, 
    wpm: 76, 
    command: "ssh -L 8080...",
    timestamp: 1705790400000,
    duration: 24300  // ms
  }
  Response: { 
    valid: true,
    boost: {
      type: 0,
      valueBps: 1500,
      expiry: 1705794000,
      nonce: "0x...",
      signature: "0x..."  // EIP-712 signature
    }
  }
```

### Mini-Game Anti-Cheat

```typescript
// services/api/minigame/typing.ts

interface TypingResult {
  accuracy: number;
  wpm: number;
  command: string;
  timestamp: number;
  duration: number;
}

async function validateTypingResult(
  result: TypingResult, 
  userId: string
): Promise<boolean> {
  // 1. Check timestamp is recent (within 5 minutes)
  if (Date.now() - result.timestamp > 5 * 60 * 1000) {
    return false;
  }
  
  // 2. Check for replay (same timestamp used before)
  const exists = await db.query.typingResults.findFirst({
    where: and(
      eq(typingResults.userId, userId),
      eq(typingResults.timestamp, result.timestamp)
    )
  });
  if (exists) return false;
  
  // 3. Sanity check WPM (human limit ~200, typical 40-80)
  if (result.wpm > 200 || result.wpm < 10) {
    return false;
  }
  
  // 4. Verify duration is plausible for WPM/accuracy
  const expectedDuration = calculateExpectedDuration(result.command, result.wpm);
  if (Math.abs(result.duration - expectedDuration) > 5000) {
    return false;
  }
  
  // 5. Rate limit (max 10 games per hour)
  const recentCount = await countRecentGames(userId, 60 * 60 * 1000);
  if (recentCount >= 10) {
    return false;
  }
  
  return true;
}
```

---

## 6. Data Model

### PostgreSQL Schema

```sql
-- Users (indexed by wallet address)
CREATE TABLE users (
  address VARCHAR(42) PRIMARY KEY,
  ens_name VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW(),
  total_extracted NUMERIC(78, 0) DEFAULT 0,
  ghost_streak_best INTEGER DEFAULT 0
);

-- Positions (current and historical)
CREATE TABLE positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_address VARCHAR(42) REFERENCES users(address),
  level SMALLINT NOT NULL,
  amount NUMERIC(78, 0) NOT NULL,
  entry_at TIMESTAMP NOT NULL,
  exit_at TIMESTAMP,
  exit_type VARCHAR(20), -- 'extracted', 'traced', 'reset_penalty'
  rewards_earned NUMERIC(78, 0),
  ghost_streak INTEGER DEFAULT 0,
  alive BOOLEAN DEFAULT TRUE,
  tx_hash_in VARCHAR(66),
  tx_hash_out VARCHAR(66),
  
  INDEX idx_positions_user (user_address),
  INDEX idx_positions_alive (alive, level)
);

-- Events (raw blockchain events)
CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  type VARCHAR(50) NOT NULL,
  block_number BIGINT NOT NULL,
  tx_hash VARCHAR(66) NOT NULL,
  data JSONB NOT NULL,
  indexed_at TIMESTAMP DEFAULT NOW(),
  
  INDEX idx_events_type (type),
  INDEX idx_events_block (block_number)
);

-- Crews
CREATE TABLE crews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  created_by VARCHAR(42) REFERENCES users(address)
);

CREATE TABLE crew_members (
  crew_id UUID REFERENCES crews(id),
  user_address VARCHAR(42) REFERENCES users(address),
  joined_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (crew_id, user_address)
);

-- Typing results (for anti-cheat and history)
CREATE TABLE typing_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_address VARCHAR(42) REFERENCES users(address),
  accuracy REAL NOT NULL,
  wpm INTEGER NOT NULL,
  command TEXT NOT NULL,
  duration INTEGER NOT NULL,
  timestamp BIGINT NOT NULL,
  boost_signed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE (user_address, timestamp)
);

-- Event sequence (for reconnection)
CREATE TABLE event_sequence (
  id BIGSERIAL PRIMARY KEY,
  event_id BIGINT REFERENCES events(id),
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Redis Keys

```
# Pub/Sub channel for real-time events
ghostnet:events

# Connection tracking
ws:connections:{userId}  → Set of connection IDs

# Sequence tracking
event:last_sequence_id   → Latest sequence ID (atomic increment)

# Rate limiting
ratelimit:{userId}:{endpoint} → Counter with TTL

# Cache
cache:leaderboard:{type}:{period} → JSON with TTL
cache:crew:{id} → JSON with TTL
```

---

## 7. Mini-Game Integration

### Flow

```
┌────────────────────────────────────────────────────────────────────┐
│                    MINI-GAME BOOST FLOW                             │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. User completes typing game in browser                          │
│                                                                     │
│  2. Frontend sends result to API:                                  │
│     POST /minigame/typing/result                                   │
│     { accuracy: 0.94, wpm: 76, command: "...", timestamp: ... }   │
│                                                                     │
│  3. Server validates (anti-cheat):                                 │
│     - Timestamp recent                                              │
│     - Not replayed                                                  │
│     - WPM plausible                                                 │
│     - Rate limit OK                                                 │
│                                                                     │
│  4. Server calculates reward tier:                                 │
│     - 94% accuracy → -15% death rate (1500 bps)                    │
│                                                                     │
│  5. Server signs EIP-712 boost:                                    │
│     signTypedData({                                                 │
│       domain: { name: 'GHOSTNET', chainId: 6343, ... },            │
│       types: { Boost: [...] },                                      │
│       message: { user, boostType, valueBps, expiry, nonce }        │
│     })                                                              │
│                                                                     │
│  6. Response includes signature:                                   │
│     { boost: { ..., signature: "0x..." } }                         │
│                                                                     │
│  7. Frontend calls contract:                                       │
│     GhostCore.applyBoost(boostType, valueBps, expiry, nonce, sig) │
│                                                                     │
│  8. Contract verifies EIP-712 signature, applies boost             │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

### EIP-712 Signing

```typescript
// services/api/signing.ts

import { privateKeyToAccount } from 'viem/accounts';
import { signTypedData } from 'viem/accounts';

const boostSigner = privateKeyToAccount(process.env.BOOST_SIGNER_PRIVATE_KEY as `0x${string}`);

const domain = {
  name: 'GHOSTNET',
  version: '1',
  chainId: 6343, // MegaETH testnet
  verifyingContract: GHOST_CORE_ADDRESS,
};

const types = {
  Boost: [
    { name: 'user', type: 'address' },
    { name: 'boostType', type: 'uint8' },
    { name: 'valueBps', type: 'uint16' },
    { name: 'expiry', type: 'uint64' },
    { name: 'nonce', type: 'bytes32' },
  ],
};

export async function signBoost(params: {
  user: `0x${string}`;
  boostType: number;
  valueBps: number;
  expiry: number;
  nonce: `0x${string}`;
}): Promise<`0x${string}`> {
  return signTypedData({
    privateKey: boostSigner.privateKey,
    domain,
    types,
    primaryType: 'Boost',
    message: params,
  });
}
```

---

## 8. Infrastructure

### Deployment

```yaml
# docker-compose.yml (development)
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ghostnet
      POSTGRES_PASSWORD: dev
    ports:
      - "5432:5432"
  
  redis:
    image: redis:7
    ports:
      - "6379:6379"
  
  indexer:
    build: ./services/indexer
    environment:
      DATABASE_URL: postgres://postgres:dev@postgres/ghostnet
      REDIS_URL: redis://redis:6379
      MEGAETH_RPC_URL: https://carrot.megaeth.com/rpc
    depends_on:
      - postgres
      - redis
  
  gateway:
    build: ./services/gateway
    ports:
      - "8080:8080"
    environment:
      REDIS_URL: redis://redis:6379
    depends_on:
      - redis
  
  api:
    build: ./services/api
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://postgres:dev@postgres/ghostnet
      REDIS_URL: redis://redis:6379
      BOOST_SIGNER_PRIVATE_KEY: ${BOOST_SIGNER_PRIVATE_KEY}
    depends_on:
      - postgres
      - redis
```

### Production

- **Kubernetes** with horizontal pod autoscaling
- **Region:** Closest to MegaETH sequencer (for latency)
- **WebSocket:** Sticky sessions via load balancer
- **Database:** Managed PostgreSQL (e.g., Supabase, Neon, RDS)
- **Redis:** Managed Redis (e.g., Upstash, ElastiCache)

---

## 9. Security

### Authentication

- JWT tokens from wallet signature verification
- 24-hour expiry, refresh via new signature
- Tokens stored in httpOnly cookies (not localStorage)

### Rate Limiting

| Endpoint | Limit |
|----------|-------|
| Unauthenticated | 100 req/min/IP |
| Authenticated | 1000 req/min/user |
| Mini-game submit | 10/hour/user |
| WebSocket connect | 5 connections/user |

### Secrets Management

- Boost signer private key in secure vault (e.g., AWS Secrets Manager)
- Never logged, never in error messages
- Rotation strategy documented

### Input Validation

- All inputs validated with Zod schemas
- SQL queries parameterized (via ORM)
- No user input in raw queries

---

## 10. Monitoring

### Metrics

| Metric | Alert Threshold |
|--------|-----------------|
| Indexer lag (blocks behind) | > 10 blocks |
| WebSocket connections | > 10,000 |
| API p99 latency | > 500ms |
| Error rate | > 1% |
| Database connections | > 80% pool |

### Logging

```typescript
// Structured logging
logger.info('Event indexed', {
  eventType: 'JackedIn',
  blockNumber: 12345,
  user: '0x...',
  processingTime: 45,
});
```

### Alerts

- PagerDuty/Opsgenie for critical alerts
- Slack for warnings
- Daily digest of key metrics

---

## Next Steps

1. [ ] Set up development environment (Docker Compose)
2. [ ] Implement indexer service
3. [ ] Implement WebSocket gateway
4. [ ] Implement API server
5. [ ] Integration testing with frontend
6. [ ] Load testing for WebSocket scalability
7. [ ] Production deployment

---

*This document should be updated as implementation progresses and decisions are made.*
