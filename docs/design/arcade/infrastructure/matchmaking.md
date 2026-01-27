# Matchmaking System

## Infrastructure Document

**Service:** `arcade-coordinator`  
**Version:** 1.0  
**Status:** Planning  
**Target:** Phase 3A (Week 2)  

---

## Overview

The Matchmaking System is the real-time infrastructure backbone for GHOSTNET Arcade's multiplayer games. It handles player queues, match creation, ready checks, game coordination, and spectator management across three game modes:

| Mode | Game | Players | Match Type |
|------|------|---------|------------|
| 1v1 | CODE DUEL | 2 | Stake-matched |
| Team | PROXY WAR | 3-8 per crew | Crew-based |
| FFA | BOUNTY HUNT | 8-64 | Free-for-all |

### Design Requirements

```
MATCHMAKING REQUIREMENTS
════════════════════════════════════════════════════════════════════

1. LATENCY
   └── Queue operations: <50ms
   └── Match notifications: <100ms
   └── Ready check propagation: <100ms

2. SCALE
   └── Target: 1000+ concurrent matches
   └── 10,000+ WebSocket connections
   └── 50,000+ queue operations/minute

3. FAIRNESS
   └── Stake-based matching (similar wagers)
   └── Optional ELO matching (competitive modes)
   └── Anti-sniping (randomized delays)

4. RELIABILITY
   └── Graceful disconnect handling
   └── State recovery on reconnect
   └── No orphaned matches

════════════════════════════════════════════════════════════════════
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GHOSTNET ARCADE                                 │
│                          MATCHMAKING ARCHITECTURE                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                                FRONTEND                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         SvelteKit App                                │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │    │
│  │  │  QueueStore     │  │  MatchStore     │  │  SpectatorStore │     │    │
│  │  │  (.svelte.ts)   │  │  (.svelte.ts)   │  │  (.svelte.ts)   │     │    │
│  │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘     │    │
│  │           │                    │                    │              │    │
│  │           └────────────────────┼────────────────────┘              │    │
│  │                                │                                   │    │
│  │                    ┌───────────┴───────────┐                       │    │
│  │                    │   WebSocketClient     │                       │    │
│  │                    │   (reconnect, auth)   │                       │    │
│  │                    └───────────┬───────────┘                       │    │
│  └────────────────────────────────┼─────────────────────────────────────┘    │
└───────────────────────────────────┼─────────────────────────────────────────┘
                                    │
                              WebSocket
                              (wss://)
                                    │
┌───────────────────────────────────┼─────────────────────────────────────────┐
│                                   ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      ARCADE COORDINATOR                              │    │
│  │                        (Rust Service)                                │    │
│  │  ┌─────────────────────────────────────────────────────────────┐   │    │
│  │  │                   WebSocket Gateway                          │   │    │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │   │    │
│  │  │  │  Auth       │  │  Routing    │  │  Heartbeat  │         │   │    │
│  │  │  │  Handler    │  │  Handler    │  │  Manager    │         │   │    │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘         │   │    │
│  │  └─────────────────────────┬───────────────────────────────────┘   │    │
│  │                            │                                        │    │
│  │  ┌─────────────────────────┼───────────────────────────────────┐   │    │
│  │  │                         ▼                                    │   │    │
│  │  │  ┌─────────────────────────────────────────────────────┐   │   │    │
│  │  │  │               MATCHMAKING ENGINE                     │   │   │    │
│  │  │  │                                                      │   │   │    │
│  │  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │   │    │
│  │  │  │  │ Queue       │  │ Matcher     │  │ Ready Check │ │   │   │    │
│  │  │  │  │ Manager     │  │ Algorithm   │  │ Coordinator │ │   │   │    │
│  │  │  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘ │   │   │    │
│  │  │  │         │                │                │        │   │   │    │
│  │  │  │         └────────────────┼────────────────┘        │   │   │    │
│  │  │  │                          ▼                         │   │   │    │
│  │  │  │  ┌─────────────────────────────────────────────┐  │   │   │    │
│  │  │  │  │            Match Lifecycle                  │  │   │   │    │
│  │  │  │  │  QUEUED → MATCHED → READY → ACTIVE → DONE  │  │   │   │    │
│  │  │  │  └─────────────────────────────────────────────┘  │   │   │    │
│  │  │  └──────────────────────────────────────────────────┘   │   │    │
│  │  │                                                          │   │    │
│  │  │  ┌─────────────────────────────────────────────────────┐│   │    │
│  │  │  │               SPECTATOR ENGINE                      ││   │    │
│  │  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ ││   │    │
│  │  │  │  │ Watch List  │  │ Broadcast   │  │ Bet Pool    │ ││   │    │
│  │  │  │  │ Manager     │  │ Relay       │  │ Aggregator  │ ││   │    │
│  │  │  │  └─────────────┘  └─────────────┘  └─────────────┘ ││   │    │
│  │  │  └─────────────────────────────────────────────────────┘│   │    │
│  │  └──────────────────────────────────────────────────────────┘   │    │
│  │                            │                                     │    │
│  │                            ▼                                     │    │
│  │  ┌─────────────────────────────────────────────────────────┐    │    │
│  │  │                    STATE LAYER                           │    │    │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │    │    │
│  │  │  │ Redis       │  │ PostgreSQL  │  │ Apache      │     │    │    │
│  │  │  │ (hot state) │  │ (durable)   │  │ Iggy        │     │    │    │
│  │  │  │             │  │             │  │ (streaming) │     │    │    │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘     │    │    │
│  │  └─────────────────────────────────────────────────────────┘    │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│                                    │                                      │
│                                    ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                         MEGAETH                                      │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │ │
│  │  │  DuelEscrow.sol │  │  BountyPool.sol │  │ SpectatorBets   │     │ │
│  │  │  (wager lock)   │  │  (FFA pools)    │  │ (side betting)  │     │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘     │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Queue System

### Queue Types

The matchmaking system supports three distinct queue configurations:

#### 1. Duel Queue (1v1)

For CODE DUEL and similar head-to-head matches.

```
DUEL QUEUE STRUCTURE
════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│                        STAKE TIER: GOLD                          │
│                      (300 $DATA wager)                           │
├─────────────────────────────────────────────────────────────────┤
│  QUEUE (sorted by wait time)                                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  0x7a3f │ ELO: 1247 │ Wait: 45s │ Range: ±100          │    │
│  │  0x9c2d │ ELO: 1189 │ Wait: 32s │ Range: ±100          │    │
│  │  0x3b1a │ ELO: 1456 │ Wait: 12s │ Range: ±100          │    │
│  │  0x8f2e │ ELO: 1102 │ Wait: 8s  │ Range: ±100          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  MATCHING RULES:                                                 │
│  1. Same stake tier (exact match)                                │
│  2. ELO within range (expands over time)                        │
│  3. Oldest player matched first                                  │
└─────────────────────────────────────────────────────────────────┘

STAKE TIERS:
├── BRONZE: 50 $DATA
├── SILVER: 150 $DATA
├── GOLD: 300 $DATA
└── DIAMOND: 500 $DATA

ELO RANGE EXPANSION:
├── 0-15s:  ±100 ELO
├── 15-30s: ±200 ELO
├── 30-60s: ±300 ELO
└── 60s+:   Any opponent
```

#### 2. Team Queue (Crew vs Crew)

For PROXY WAR territory battles.

```
TEAM QUEUE STRUCTURE
════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│                      PROXY WAR QUEUE                             │
│                    (Territory: BETA-3)                           │
├─────────────────────────────────────────────────────────────────┤
│  ATTACKING CREWS                   DEFENDING CREWS               │
│  ┌─────────────────────────┐      ┌─────────────────────────┐   │
│  │ SHADOW_COLLECTIVE       │      │ VOID_RUNNERS            │   │
│  │ Members: 5 online       │  vs  │ Members: 4 online       │   │
│  │ Stake: 600 $DATA        │      │ Stake: 600 $DATA        │   │
│  │ Avg Rating: 1,340       │      │ Avg Rating: 1,280       │   │
│  └─────────────────────────┘      └─────────────────────────┘   │
│                                                                  │
│  BATTLE TYPE: SIEGE                                              │
│  STARTS IN: 04:32                                                │
│  REQUIRED: Defender auto-matched (territory owner)               │
└─────────────────────────────────────────────────────────────────┘
```

#### 3. FFA Queue (Free-for-All)

For BOUNTY HUNT and similar multi-player modes.

```
FFA QUEUE STRUCTURE
════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│                      BOUNTY HUNT LOBBY                           │
│                       Round #847                                 │
├─────────────────────────────────────────────────────────────────┤
│  REGISTRATION PHASE                                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Players: 47 / 64                                        │    │
│  │  Min Required: 8                                         │    │
│  │  Prize Pool: 8,450 $DATA                                 │    │
│  │  Time Remaining: 00:34                                   │    │
│  │                                                          │    │
│  │  ████████████████████████████████████████░░░░░░░░ 73%    │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  STATE MACHINE:                                                  │
│  REGISTRATION → ASSIGNING → ACTIVE → ENDED                      │
│       60s         ~5s        6min     payout                    │
└─────────────────────────────────────────────────────────────────┘
```

### Stake-Based Matching

Players are matched with opponents who have wagered similar amounts:

```rust
/// Stake tier configuration for matchmaking
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum StakeTier {
    Bronze,   // 50 $DATA
    Silver,   // 150 $DATA
    Gold,     // 300 $DATA
    Diamond,  // 500 $DATA
}

impl StakeTier {
    pub const fn wager_amount(&self) -> u64 {
        match self {
            Self::Bronze => 50,
            Self::Silver => 150,
            Self::Gold => 300,
            Self::Diamond => 500,
        }
    }

    pub fn from_wager(wager: u64) -> Option<Self> {
        match wager {
            50 => Some(Self::Bronze),
            150 => Some(Self::Silver),
            300 => Some(Self::Gold),
            500 => Some(Self::Diamond),
            _ => None,
        }
    }
}
```

### ELO/Skill-Based Matching

Optional competitive mode uses ELO ratings:

```rust
/// ELO rating calculation for competitive matchmaking
pub struct EloSystem {
    k_factor: f64,
}

impl EloSystem {
    pub const DEFAULT_K_FACTOR: f64 = 32.0;
    pub const DEFAULT_RATING: i32 = 1200;

    pub fn new(k_factor: f64) -> Self {
        Self { k_factor }
    }

    /// Calculate expected win probability
    pub fn expected_score(&self, player_rating: i32, opponent_rating: i32) -> f64 {
        1.0 / (1.0 + 10_f64.powf((opponent_rating - player_rating) as f64 / 400.0))
    }

    /// Calculate new ratings after a match
    pub fn calculate_new_ratings(
        &self,
        winner_rating: i32,
        loser_rating: i32,
    ) -> (i32, i32) {
        let expected_winner = self.expected_score(winner_rating, loser_rating);
        let expected_loser = 1.0 - expected_winner;

        let new_winner = winner_rating + (self.k_factor * (1.0 - expected_winner)) as i32;
        let new_loser = loser_rating + (self.k_factor * (0.0 - expected_loser)) as i32;

        (new_winner, new_loser)
    }
}

/// Matchmaking range that expands over time
pub struct MatchmakingRange {
    base_range: i32,
    expansion_rate: i32,
    max_range: i32,
}

impl MatchmakingRange {
    pub fn calculate_range(&self, wait_time_secs: u64) -> i32 {
        let expansion = (wait_time_secs / 15) as i32 * self.expansion_rate;
        (self.base_range + expansion).min(self.max_range)
    }
}

impl Default for MatchmakingRange {
    fn default() -> Self {
        Self {
            base_range: 100,
            expansion_rate: 100,
            max_range: 500,
        }
    }
}
```

### Queue Timeout Handling

```rust
/// Queue timeout configuration
pub struct QueueTimeoutConfig {
    /// Maximum time a player can wait in queue
    pub max_wait_time: Duration,
    /// Time before warning player about long wait
    pub warning_threshold: Duration,
    /// Time to respond to match found
    pub ready_check_timeout: Duration,
}

impl Default for QueueTimeoutConfig {
    fn default() -> Self {
        Self {
            max_wait_time: Duration::from_secs(300),      // 5 minutes
            warning_threshold: Duration::from_secs(120),  // 2 minutes
            ready_check_timeout: Duration::from_secs(15), // 15 seconds
        }
    }
}

/// Handle queue timeout events
pub async fn handle_queue_timeout(
    queue_manager: &QueueManager,
    player_id: &PlayerId,
    timeout_type: TimeoutType,
) -> Result<(), MatchmakingError> {
    match timeout_type {
        TimeoutType::MaxWaitExceeded => {
            // Remove from queue, notify player
            queue_manager.remove_player(player_id).await?;
            queue_manager.notify_player(player_id, QueueEvent::Timeout {
                reason: "No opponents found. Try a different stake tier.".into(),
            }).await?;
        }
        TimeoutType::ReadyCheckFailed => {
            // Player didn't accept match in time
            queue_manager.remove_player(player_id).await?;
            // Re-queue their opponent
            if let Some(opponent) = queue_manager.get_pending_opponent(player_id).await? {
                queue_manager.requeue_player(&opponent).await?;
            }
        }
    }
    Ok(())
}
```

---

## Match Lifecycle

```
MATCH LIFECYCLE STATE MACHINE
════════════════════════════════════════════════════════════════════

                          ┌─────────────┐
                          │   QUEUED    │
                          │  (waiting)  │
                          └──────┬──────┘
                                 │
                    match found  │  timeout
                         ┌───────┴───────┐
                         ▼               ▼
                  ┌─────────────┐  ┌─────────────┐
                  │   MATCHED   │  │  CANCELLED  │
                  │ (pending)   │  │  (timeout)  │
                  └──────┬──────┘  └─────────────┘
                         │
          both ready     │  decline/timeout
               ┌─────────┴─────────┐
               ▼                   ▼
        ┌─────────────┐     ┌─────────────┐
        │    READY    │     │  CANCELLED  │
        │ (countdown) │     │ (declined)  │
        └──────┬──────┘     └─────────────┘
               │
     countdown │
      complete │
               ▼
        ┌─────────────┐
        │   ACTIVE    │
        │  (playing)  │
        └──────┬──────┘
               │
     game ends │
               │
               ▼
        ┌─────────────┐
        │  RESOLVED   │
        │  (results)  │
        └──────┬──────┘
               │
    submitted  │
               ▼
        ┌─────────────┐
        │   SETTLED   │
        │  (payouts)  │
        └─────────────┘

════════════════════════════════════════════════════════════════════
```

### Phase Details

#### 1. Queue Entry

```rust
/// Player enters matchmaking queue
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QueueEntry {
    pub player_id: PlayerId,
    pub game_type: GameType,
    pub stake_tier: StakeTier,
    pub rating: i32,
    pub entered_at: DateTime<Utc>,
    pub preferences: QueuePreferences,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QueuePreferences {
    /// Accept any opponent after timeout
    pub expand_search: bool,
    /// Minimum opponent rating (optional)
    pub min_opponent_rating: Option<i32>,
    /// Maximum opponent rating (optional)
    pub max_opponent_rating: Option<i32>,
}

impl QueueManager {
    pub async fn enter_queue(&self, entry: QueueEntry) -> Result<QueueTicket, MatchmakingError> {
        // Validate player isn't already in queue or match
        if self.is_player_active(&entry.player_id).await? {
            return Err(MatchmakingError::AlreadyInQueue);
        }

        // Verify stake is locked on-chain
        self.verify_stake_locked(&entry.player_id, entry.stake_tier).await?;

        // Add to appropriate queue
        let queue_key = (entry.game_type, entry.stake_tier);
        let ticket = QueueTicket::new(&entry);
        
        self.queues
            .entry(queue_key)
            .or_default()
            .push(entry.clone());

        // Notify player
        self.notify_player(&entry.player_id, QueueEvent::Entered {
            position: self.get_queue_position(&entry.player_id).await?,
            estimated_wait: self.estimate_wait_time(&entry).await?,
        }).await?;

        // Trigger matching attempt
        self.try_match(queue_key).await?;

        Ok(ticket)
    }
}
```

#### 2. Match Found

```rust
/// A match has been created between players
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Match {
    pub match_id: MatchId,
    pub game_type: GameType,
    pub players: Vec<MatchPlayer>,
    pub stake_tier: StakeTier,
    pub state: MatchState,
    pub created_at: DateTime<Utc>,
    pub code_sequence: Option<String>, // For typing games
    pub spectator_count: u32,
    pub spectator_bets: SpectatorBets,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatchPlayer {
    pub player_id: PlayerId,
    pub address: Address,
    pub rating: i32,
    pub ready: bool,
    pub connected: bool,
}

impl MatchManager {
    pub async fn create_match(
        &self,
        player1: QueueEntry,
        player2: QueueEntry,
    ) -> Result<Match, MatchmakingError> {
        let match_id = MatchId::generate();
        
        let match_data = Match {
            match_id: match_id.clone(),
            game_type: player1.game_type,
            players: vec![
                MatchPlayer::from_entry(&player1),
                MatchPlayer::from_entry(&player2),
            ],
            stake_tier: player1.stake_tier,
            state: MatchState::Matched,
            created_at: Utc::now(),
            code_sequence: None,
            spectator_count: 0,
            spectator_bets: SpectatorBets::default(),
        };

        // Store match
        self.matches.insert(match_id.clone(), match_data.clone());

        // Notify both players
        for player in &match_data.players {
            self.notify_player(&player.player_id, MatchEvent::MatchFound {
                match_id: match_id.clone(),
                opponent: self.get_opponent_info(&match_data, &player.player_id),
                accept_deadline: Utc::now() + chrono::Duration::seconds(15),
            }).await?;
        }

        // Start ready check timer
        self.start_ready_check_timer(&match_id).await;

        Ok(match_data)
    }
}
```

#### 3. Ready Check

```rust
/// Player accepts or declines match
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ReadyResponse {
    Accept,
    Decline,
}

impl MatchManager {
    pub async fn handle_ready_response(
        &self,
        match_id: &MatchId,
        player_id: &PlayerId,
        response: ReadyResponse,
    ) -> Result<(), MatchmakingError> {
        let mut match_data = self.get_match_mut(match_id).await?;

        match response {
            ReadyResponse::Accept => {
                // Mark player as ready
                let player = match_data.players
                    .iter_mut()
                    .find(|p| &p.player_id == player_id)
                    .ok_or(MatchmakingError::PlayerNotInMatch)?;
                
                player.ready = true;

                // Check if all players ready
                if match_data.players.iter().all(|p| p.ready) {
                    self.transition_to_countdown(match_id).await?;
                }
            }
            ReadyResponse::Decline => {
                // Cancel match, requeue other player
                self.cancel_match(match_id, CancelReason::Declined {
                    by: player_id.clone(),
                }).await?;
            }
        }

        Ok(())
    }

    async fn transition_to_countdown(&self, match_id: &MatchId) -> Result<(), MatchmakingError> {
        let mut match_data = self.get_match_mut(match_id).await?;
        match_data.state = MatchState::Ready;

        // Generate code sequence for typing games
        if matches!(match_data.game_type, GameType::CodeDuel) {
            match_data.code_sequence = Some(
                self.code_generator.generate(match_data.stake_tier).await?
            );
        }

        // Notify all players of countdown
        let countdown_start = Utc::now();
        let game_start = countdown_start + chrono::Duration::seconds(5);

        self.broadcast_to_match(match_id, MatchEvent::Countdown {
            starts_at: countdown_start,
            game_starts_at: game_start,
            code_sequence: match_data.code_sequence.clone(),
        }).await?;

        // Close spectator betting
        self.close_betting(match_id).await?;

        // Schedule game start
        self.schedule_game_start(match_id, game_start).await;

        Ok(())
    }
}
```

#### 4. Game Start

```rust
impl MatchManager {
    pub async fn start_game(&self, match_id: &MatchId) -> Result<(), MatchmakingError> {
        let mut match_data = self.get_match_mut(match_id).await?;
        
        // Verify all players still connected
        for player in &match_data.players {
            if !player.connected {
                return self.handle_disconnect_at_start(match_id, &player.player_id).await;
            }
        }

        match_data.state = MatchState::Active;
        let start_time = Utc::now();

        // Notify players game is starting
        self.broadcast_to_match(match_id, MatchEvent::GameStarted {
            started_at: start_time,
            duration: self.get_game_duration(&match_data.game_type),
        }).await?;

        // Start game timer
        self.start_game_timer(match_id, start_time).await;

        // Publish to event stream for indexing
        self.publish_event(ArcadeEvent::GameStarted {
            match_id: match_id.clone(),
            game_type: match_data.game_type,
            players: match_data.players.iter().map(|p| p.address).collect(),
            stake_tier: match_data.stake_tier,
        }).await?;

        Ok(())
    }
}
```

#### 5. Game End

```rust
/// Game result submitted by players or determined by timeout
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameResult {
    pub match_id: MatchId,
    pub winner: Option<PlayerId>, // None for tie
    pub player_stats: Vec<PlayerStats>,
    pub duration_ms: u64,
    pub end_reason: EndReason,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlayerStats {
    pub player_id: PlayerId,
    pub progress: f32,      // 0.0 - 1.0
    pub wpm: Option<u32>,   // For typing games
    pub accuracy: Option<f32>,
    pub score: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EndReason {
    Completed,        // Normal completion
    Timeout,          // Time limit reached
    Forfeit(PlayerId), // Player disconnected/quit
}

impl MatchManager {
    pub async fn end_game(&self, result: GameResult) -> Result<(), MatchmakingError> {
        let mut match_data = self.get_match_mut(&result.match_id).await?;
        match_data.state = MatchState::Resolved;

        // Broadcast results to players and spectators
        self.broadcast_to_match(&result.match_id, MatchEvent::GameEnded {
            result: result.clone(),
        }).await?;

        // Calculate payouts
        let payouts = self.calculate_payouts(&match_data, &result).await?;

        // Submit result to chain
        self.submit_result_to_chain(&result, &payouts).await?;

        Ok(())
    }
}
```

#### 6. Result Submission

```rust
/// Submit match result to smart contract
impl ChainSubmitter {
    pub async fn submit_result(
        &self,
        match_id: &MatchId,
        result: &GameResult,
        payouts: &Payouts,
    ) -> Result<TxHash, ChainError> {
        // Build transaction based on game type
        let tx = match result.end_reason {
            EndReason::Completed | EndReason::Timeout => {
                self.build_resolve_tx(match_id, &result.winner, payouts).await?
            }
            EndReason::Forfeit(ref forfeiter) => {
                self.build_forfeit_tx(match_id, forfeiter).await?
            }
        };

        // Submit and wait for confirmation
        let tx_hash = self.submit_tx(tx).await?;
        
        // Wait for confirmation (MegaETH is fast)
        self.wait_for_confirmation(&tx_hash, 1).await?;

        // Update match state to settled
        self.match_manager.update_state(match_id, MatchState::Settled).await?;

        Ok(tx_hash)
    }
}
```

---

## Real-time Communication

### WebSocket Protocol Design

All messages use JSON encoding with a consistent envelope:

```rust
/// WebSocket message envelope
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WsMessage {
    /// Message type for routing
    #[serde(rename = "type")]
    pub msg_type: String,
    /// Unique message ID for acknowledgment
    pub id: String,
    /// Timestamp
    pub ts: i64,
    /// Payload (varies by type)
    pub data: serde_json::Value,
}
```

### Message Types and Formats

#### Client → Server Messages

```json
// Authentication
{
  "type": "auth",
  "id": "msg_001",
  "ts": 1706025600000,
  "data": {
    "token": "jwt_token_here",
    "address": "0x7a3f..."
  }
}

// Enter Queue
{
  "type": "queue.enter",
  "id": "msg_002",
  "ts": 1706025600100,
  "data": {
    "game_type": "code_duel",
    "stake_tier": "gold",
    "preferences": {
      "expand_search": true,
      "min_opponent_rating": null,
      "max_opponent_rating": null
    }
  }
}

// Leave Queue
{
  "type": "queue.leave",
  "id": "msg_003",
  "ts": 1706025600200,
  "data": {}
}

// Ready Response
{
  "type": "match.ready",
  "id": "msg_004",
  "ts": 1706025600300,
  "data": {
    "match_id": "match_abc123",
    "response": "accept"
  }
}

// Game Progress Update
{
  "type": "game.progress",
  "id": "msg_005",
  "ts": 1706025600400,
  "data": {
    "match_id": "match_abc123",
    "progress": 0.45,
    "wpm": 87,
    "accuracy": 0.96,
    "current_position": 42
  }
}

// Join as Spectator
{
  "type": "spectate.join",
  "id": "msg_006",
  "ts": 1706025600500,
  "data": {
    "match_id": "match_abc123"
  }
}

// Place Spectator Bet
{
  "type": "spectate.bet",
  "id": "msg_007",
  "ts": 1706025600600,
  "data": {
    "match_id": "match_abc123",
    "on_player": "0x7a3f...",
    "amount": "100000000000000000000"
  }
}

// Heartbeat (Pong)
{
  "type": "pong",
  "id": "msg_008",
  "ts": 1706025600700,
  "data": {}
}
```

#### Server → Client Messages

```json
// Authentication Success
{
  "type": "auth.success",
  "id": "msg_001",
  "ts": 1706025600050,
  "data": {
    "player_id": "player_xyz",
    "rating": 1247,
    "session_expires": 1706112000000
  }
}

// Queue Update
{
  "type": "queue.update",
  "id": "server_001",
  "ts": 1706025600150,
  "data": {
    "status": "searching",
    "position": 3,
    "estimated_wait_secs": 25,
    "players_in_tier": 12
  }
}

// Match Found
{
  "type": "match.found",
  "id": "server_002",
  "ts": 1706025600250,
  "data": {
    "match_id": "match_abc123",
    "opponent": {
      "address": "0x9c2d...",
      "rating": 1189,
      "wins": 18,
      "avg_wpm": 76
    },
    "wager": "300000000000000000000",
    "accept_deadline": 1706025615000
  }
}

// Countdown
{
  "type": "match.countdown",
  "id": "server_003",
  "ts": 1706025600350,
  "data": {
    "match_id": "match_abc123",
    "seconds_remaining": 5,
    "code_sequence": "nmap -sS -sV -p- --script vuln 192.168.1.0/24",
    "game_starts_at": 1706025605000
  }
}

// Game Started
{
  "type": "game.started",
  "id": "server_004",
  "ts": 1706025605000,
  "data": {
    "match_id": "match_abc123",
    "duration_secs": 60
  }
}

// Opponent Progress
{
  "type": "game.opponent_progress",
  "id": "server_005",
  "ts": 1706025620000,
  "data": {
    "match_id": "match_abc123",
    "progress": 0.62,
    "wpm": 72,
    "accuracy": 0.94
  }
}

// Game Result
{
  "type": "game.result",
  "id": "server_006",
  "ts": 1706025640000,
  "data": {
    "match_id": "match_abc123",
    "winner": "0x7a3f...",
    "your_stats": {
      "progress": 1.0,
      "wpm": 92,
      "accuracy": 0.98,
      "time_ms": 18300
    },
    "opponent_stats": {
      "progress": 0.89,
      "wpm": 74,
      "accuracy": 0.96,
      "time_ms": 22700
    },
    "prize": "270000000000000000000",
    "rating_change": 18,
    "tx_hash": "0xabc123..."
  }
}

// Spectator Update
{
  "type": "spectate.update",
  "id": "server_007",
  "ts": 1706025625000,
  "data": {
    "match_id": "match_abc123",
    "player1_progress": 0.78,
    "player2_progress": 0.62,
    "spectator_count": 47,
    "bet_odds": {
      "player1": 1.425,
      "player2": 2.85
    }
  }
}

// Heartbeat (Ping)
{
  "type": "ping",
  "id": "server_ping_001",
  "ts": 1706025600000,
  "data": {}
}

// Error
{
  "type": "error",
  "id": "msg_002",
  "ts": 1706025600100,
  "data": {
    "code": "ALREADY_IN_QUEUE",
    "message": "You are already in a matchmaking queue"
  }
}
```

### Reconnection Handling

```rust
/// Connection state management
pub struct ConnectionManager {
    connections: DashMap<PlayerId, Connection>,
    reconnect_window: Duration,
}

impl ConnectionManager {
    pub async fn handle_disconnect(&self, player_id: &PlayerId) -> Result<(), ConnectionError> {
        let conn = self.connections.get(player_id)
            .ok_or(ConnectionError::NotFound)?;
        
        // Mark as disconnected, don't remove immediately
        conn.state = ConnectionState::Disconnected {
            at: Utc::now(),
            grace_period_ends: Utc::now() + self.reconnect_window,
        };

        // Check if player is in active match
        if let Some(match_id) = self.get_active_match(player_id).await? {
            // Notify opponent of potential disconnect
            self.notify_match_participants(&match_id, MatchEvent::PlayerDisconnected {
                player_id: player_id.clone(),
                grace_period_secs: self.reconnect_window.as_secs(),
            }).await?;

            // Start forfeit timer
            self.start_forfeit_timer(player_id, &match_id).await;
        }

        Ok(())
    }

    pub async fn handle_reconnect(
        &self,
        player_id: &PlayerId,
        new_conn: WebSocket,
    ) -> Result<ReconnectResult, ConnectionError> {
        let conn = self.connections.get_mut(player_id)
            .ok_or(ConnectionError::NotFound)?;

        match &conn.state {
            ConnectionState::Disconnected { grace_period_ends, .. } => {
                if Utc::now() < *grace_period_ends {
                    // Successful reconnect within grace period
                    conn.socket = new_conn;
                    conn.state = ConnectionState::Connected;

                    // Cancel forfeit timer if in match
                    if let Some(match_id) = self.get_active_match(player_id).await? {
                        self.cancel_forfeit_timer(player_id).await;
                        self.notify_match_participants(&match_id, MatchEvent::PlayerReconnected {
                            player_id: player_id.clone(),
                        }).await?;

                        // Send current game state
                        let state = self.get_match_state(&match_id).await?;
                        return Ok(ReconnectResult::ResumedMatch { state });
                    }

                    Ok(ReconnectResult::Reconnected)
                } else {
                    // Grace period expired
                    Err(ConnectionError::GracePeriodExpired)
                }
            }
            ConnectionState::Connected => {
                // Already connected, replace socket
                conn.socket = new_conn;
                Ok(ReconnectResult::Reconnected)
            }
        }
    }
}
```

### Heartbeat/Keepalive

```rust
/// Heartbeat configuration and handling
pub struct HeartbeatManager {
    ping_interval: Duration,
    pong_timeout: Duration,
}

impl HeartbeatManager {
    pub fn new() -> Self {
        Self {
            ping_interval: Duration::from_secs(15),
            pong_timeout: Duration::from_secs(5),
        }
    }

    pub async fn start_heartbeat_loop(&self, conn: &mut Connection) {
        let mut interval = tokio::time::interval(self.ping_interval);
        
        loop {
            interval.tick().await;

            // Send ping
            let ping_id = format!("ping_{}", Utc::now().timestamp_millis());
            conn.pending_pong = Some(ping_id.clone());
            conn.last_ping_at = Some(Utc::now());

            if let Err(e) = conn.send(WsMessage::ping(&ping_id)).await {
                tracing::warn!("Failed to send ping: {}", e);
                break;
            }

            // Wait for pong with timeout
            let pong_result = tokio::time::timeout(
                self.pong_timeout,
                self.wait_for_pong(conn, &ping_id),
            ).await;

            match pong_result {
                Ok(Ok(())) => {
                    conn.last_pong_at = Some(Utc::now());
                    conn.pending_pong = None;
                }
                Ok(Err(e)) => {
                    tracing::warn!("Pong error: {}", e);
                    break;
                }
                Err(_) => {
                    // Timeout - connection dead
                    tracing::info!("Connection {} timed out (no pong)", conn.player_id);
                    break;
                }
            }
        }

        // Connection lost, trigger disconnect handling
        self.connection_manager.handle_disconnect(&conn.player_id).await.ok();
    }
}
```

---

## Spectator System

### Watching Live Games

```rust
/// Spectator management for live game viewing
pub struct SpectatorManager {
    /// Match ID -> Set of spectator connections
    watchers: DashMap<MatchId, HashSet<ConnectionId>>,
    /// Broadcast delay for anti-cheat
    broadcast_delay: Duration,
}

impl SpectatorManager {
    pub fn new() -> Self {
        Self {
            watchers: DashMap::new(),
            broadcast_delay: Duration::from_millis(500), // 500ms delay
        }
    }

    pub async fn join_as_spectator(
        &self,
        match_id: &MatchId,
        conn_id: &ConnectionId,
    ) -> Result<SpectatorSession, SpectatorError> {
        let match_data = self.match_manager.get_match(match_id).await?;

        // Verify match is spectatable
        if !matches!(match_data.state, MatchState::Ready | MatchState::Active) {
            return Err(SpectatorError::MatchNotSpectatable);
        }

        // Add to watchers
        self.watchers
            .entry(match_id.clone())
            .or_default()
            .insert(conn_id.clone());

        // Update spectator count
        self.match_manager.increment_spectator_count(match_id).await?;

        // Return initial state
        Ok(SpectatorSession {
            match_id: match_id.clone(),
            match_state: match_data.state,
            players: match_data.players.iter().map(|p| SpectatorPlayerView {
                address: p.address,
                rating: p.rating,
                progress: 0.0,
            }).collect(),
            bet_pool: match_data.spectator_bets.clone(),
            can_bet: matches!(match_data.state, MatchState::Ready),
        })
    }

    pub async fn leave_spectator(
        &self,
        match_id: &MatchId,
        conn_id: &ConnectionId,
    ) -> Result<(), SpectatorError> {
        if let Some(mut watchers) = self.watchers.get_mut(match_id) {
            watchers.remove(conn_id);
        }
        self.match_manager.decrement_spectator_count(match_id).await?;
        Ok(())
    }

    /// Broadcast game state to all spectators with delay
    pub async fn broadcast_to_spectators(
        &self,
        match_id: &MatchId,
        event: SpectatorEvent,
    ) -> Result<(), SpectatorError> {
        // Apply anti-cheat delay
        tokio::time::sleep(self.broadcast_delay).await;

        if let Some(watchers) = self.watchers.get(match_id) {
            let message = WsMessage::spectator_update(match_id, &event);
            
            for conn_id in watchers.iter() {
                if let Some(conn) = self.connection_manager.get_connection(conn_id) {
                    conn.send(message.clone()).await.ok();
                }
            }
        }

        Ok(())
    }
}
```

### Spectator Betting Integration

```rust
/// Spectator betting pool management
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SpectatorBets {
    pub player1_pool: U256,
    pub player2_pool: U256,
    pub total_pool: U256,
    pub bets: Vec<SpectatorBet>,
    pub betting_closed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpectatorBet {
    pub bettor: Address,
    pub amount: U256,
    pub on_player1: bool,
    pub placed_at: DateTime<Utc>,
}

impl SpectatorBets {
    pub const RAKE_BPS: u64 = 500; // 5%
    pub const MIN_BET: u64 = 10;   // 10 $DATA
    pub const MAX_BET: u64 = 500;  // 500 $DATA

    pub fn calculate_odds(&self) -> (f64, f64) {
        if self.total_pool.is_zero() {
            return (2.0, 2.0);
        }

        let rake = self.total_pool * U256::from(Self::RAKE_BPS) / U256::from(10000);
        let pool_after_rake = self.total_pool - rake;

        let p1_odds = if self.player1_pool.is_zero() {
            2.0
        } else {
            (pool_after_rake.as_u64() as f64) / (self.player1_pool.as_u64() as f64)
        };

        let p2_odds = if self.player2_pool.is_zero() {
            2.0
        } else {
            (pool_after_rake.as_u64() as f64) / (self.player2_pool.as_u64() as f64)
        };

        (p1_odds, p2_odds)
    }
}

impl SpectatorManager {
    pub async fn place_bet(
        &self,
        match_id: &MatchId,
        bettor: &Address,
        amount: U256,
        on_player1: bool,
    ) -> Result<SpectatorBetReceipt, BettingError> {
        let mut match_data = self.match_manager.get_match_mut(match_id).await?;

        // Validate betting is open
        if match_data.spectator_bets.betting_closed {
            return Err(BettingError::BettingClosed);
        }

        // Validate amount
        let amount_data = amount / U256::from(10).pow(U256::from(18));
        if amount_data < U256::from(SpectatorBets::MIN_BET) {
            return Err(BettingError::BetTooSmall);
        }
        if amount_data > U256::from(SpectatorBets::MAX_BET) {
            return Err(BettingError::BetTooLarge);
        }

        // Record bet
        let bet = SpectatorBet {
            bettor: *bettor,
            amount,
            on_player1,
            placed_at: Utc::now(),
        };

        if on_player1 {
            match_data.spectator_bets.player1_pool += amount;
        } else {
            match_data.spectator_bets.player2_pool += amount;
        }
        match_data.spectator_bets.total_pool += amount;
        match_data.spectator_bets.bets.push(bet);

        // Submit to chain (escrow)
        let tx_hash = self.chain_client
            .place_spectator_bet(match_id, bettor, amount, on_player1)
            .await?;

        // Broadcast updated odds
        let (p1_odds, p2_odds) = match_data.spectator_bets.calculate_odds();
        self.broadcast_to_spectators(match_id, SpectatorEvent::OddsUpdated {
            player1_odds: p1_odds,
            player2_odds: p2_odds,
            total_pool: match_data.spectator_bets.total_pool,
        }).await?;

        Ok(SpectatorBetReceipt {
            match_id: match_id.clone(),
            amount,
            on_player1,
            current_odds: if on_player1 { p1_odds } else { p2_odds },
            tx_hash,
        })
    }
}
```

### Delayed Broadcast (Anti-Cheat)

```rust
/// Anti-cheat measures for spectator broadcasts
pub struct AntiCheatBroadcaster {
    /// Base delay for all spectator broadcasts
    base_delay: Duration,
    /// Additional random jitter to prevent timing attacks
    jitter_range: Range<u64>,
}

impl AntiCheatBroadcaster {
    pub fn new() -> Self {
        Self {
            base_delay: Duration::from_millis(500),
            jitter_range: 0..200,
        }
    }

    pub async fn broadcast_with_delay(
        &self,
        spectator_manager: &SpectatorManager,
        match_id: &MatchId,
        event: SpectatorEvent,
    ) {
        // Apply base delay plus random jitter
        let jitter = rand::thread_rng().gen_range(self.jitter_range.clone());
        let total_delay = self.base_delay + Duration::from_millis(jitter);
        
        tokio::time::sleep(total_delay).await;

        // Broadcast to spectators
        spectator_manager.broadcast_to_spectators(match_id, event).await.ok();
    }

    /// Sanitize player progress for spectators (hide exact input)
    pub fn sanitize_progress(progress: &PlayerProgress) -> SpectatorProgress {
        SpectatorProgress {
            // Round progress to 1% increments
            progress: (progress.progress * 100.0).round() / 100.0,
            // Round WPM to nearest 5
            wpm: (progress.wpm / 5) * 5,
            // Hide exact position
            accuracy: (progress.accuracy * 100.0).round() / 100.0,
        }
    }
}
```

---

## Rust Service Implementation

### Service Architecture

```
services/arcade-coordinator/
├── Cargo.toml
├── rust-toolchain.toml
├── src/
│   ├── main.rs                 # Entry point
│   ├── lib.rs                  # Library root
│   ├── config/
│   │   ├── mod.rs
│   │   └── settings.rs         # Configuration
│   ├── api/
│   │   ├── mod.rs
│   │   ├── http.rs             # REST endpoints
│   │   └── ws.rs               # WebSocket handler
│   ├── matchmaking/
│   │   ├── mod.rs
│   │   ├── queue.rs            # Queue management
│   │   ├── matcher.rs          # Matching algorithm
│   │   ├── elo.rs              # Rating system
│   │   └── ready_check.rs      # Ready check handling
│   ├── match_manager/
│   │   ├── mod.rs
│   │   ├── lifecycle.rs        # Match state machine
│   │   ├── result.rs           # Result processing
│   │   └── chain.rs            # On-chain submission
│   ├── spectator/
│   │   ├── mod.rs
│   │   ├── manager.rs          # Spectator sessions
│   │   ├── betting.rs          # Bet handling
│   │   └── broadcast.rs        # Delayed broadcasts
│   ├── connection/
│   │   ├── mod.rs
│   │   ├── manager.rs          # Connection tracking
│   │   ├── heartbeat.rs        # Keepalive
│   │   └── reconnect.rs        # Reconnection logic
│   ├── state/
│   │   ├── mod.rs
│   │   ├── redis.rs            # Hot state (queues, matches)
│   │   └── postgres.rs         # Durable state (history)
│   ├── types/
│   │   ├── mod.rs
│   │   ├── messages.rs         # WS message types
│   │   ├── match_types.rs      # Match/queue types
│   │   └── errors.rs           # Error types
│   └── utils/
│       ├── mod.rs
│       └── code_generator.rs   # Code sequence generation
└── tests/
    ├── integration/
    │   ├── matchmaking_test.rs
    │   └── spectator_test.rs
    └── common/
        └── fixtures.rs
```

### Core Service Implementation

```rust
// src/main.rs

use arcade_coordinator::{
    api::{HttpServer, WebSocketServer},
    config::Settings,
    connection::ConnectionManager,
    matchmaking::MatchmakingEngine,
    match_manager::MatchManager,
    spectator::SpectatorManager,
    state::{PostgresStore, RedisState},
};
use std::sync::Arc;
use tokio::signal;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .with(tracing_subscriber::fmt::layer())
        .init();

    tracing::info!("Starting GHOSTNET Arcade Coordinator");

    // Load configuration
    let settings = Settings::load()?;

    // Initialize state stores
    let redis = RedisState::connect(&settings.redis_url).await?;
    let postgres = PostgresStore::connect(&settings.database_url).await?;

    // Initialize managers
    let connection_manager = Arc::new(ConnectionManager::new(
        settings.connection.clone(),
    ));
    
    let match_manager = Arc::new(MatchManager::new(
        redis.clone(),
        postgres.clone(),
        settings.chain.clone(),
    ));
    
    let matchmaking_engine = Arc::new(MatchmakingEngine::new(
        redis.clone(),
        match_manager.clone(),
        connection_manager.clone(),
        settings.matchmaking.clone(),
    ));
    
    let spectator_manager = Arc::new(SpectatorManager::new(
        match_manager.clone(),
        connection_manager.clone(),
        settings.spectator.clone(),
    ));

    // Start background tasks
    let matchmaking_handle = tokio::spawn({
        let engine = matchmaking_engine.clone();
        async move { engine.run_matching_loop().await }
    });

    // Start HTTP API server
    let http_server = HttpServer::new(
        match_manager.clone(),
        matchmaking_engine.clone(),
        settings.http.clone(),
    );
    let http_handle = tokio::spawn(async move {
        http_server.run().await
    });

    // Start WebSocket server
    let ws_server = WebSocketServer::new(
        connection_manager.clone(),
        matchmaking_engine.clone(),
        match_manager.clone(),
        spectator_manager.clone(),
        settings.websocket.clone(),
    );
    let ws_handle = tokio::spawn(async move {
        ws_server.run().await
    });

    tracing::info!(
        "Arcade Coordinator running on http://{}:{} and ws://{}:{}",
        settings.http.host,
        settings.http.port,
        settings.websocket.host,
        settings.websocket.port,
    );

    // Wait for shutdown signal
    shutdown_signal().await;

    tracing::info!("Shutting down...");
    
    // Graceful shutdown
    matchmaking_handle.abort();
    http_handle.abort();
    ws_handle.abort();

    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        () = ctrl_c => {},
        () = terminate => {},
    }
}
```

### State Management

```rust
// src/state/redis.rs

use deadpool_redis::{Config, Pool, Runtime};
use redis::AsyncCommands;
use serde::{de::DeserializeOwned, Serialize};
use std::time::Duration;

pub struct RedisState {
    pool: Pool,
}

impl RedisState {
    pub async fn connect(url: &str) -> Result<Self, redis::RedisError> {
        let cfg = Config::from_url(url);
        let pool = cfg.create_pool(Some(Runtime::Tokio1))?;
        
        // Verify connection
        let mut conn = pool.get().await.map_err(|e| {
            redis::RedisError::from((redis::ErrorKind::IoError, "Pool error", e.to_string()))
        })?;
        redis::cmd("PING").query_async::<_, ()>(&mut *conn).await?;
        
        Ok(Self { pool })
    }

    // Queue operations
    pub async fn add_to_queue<T: Serialize>(
        &self,
        queue_key: &str,
        entry: &T,
        score: f64,
    ) -> Result<(), redis::RedisError> {
        let mut conn = self.pool.get().await.unwrap();
        let data = serde_json::to_string(entry).unwrap();
        conn.zadd(queue_key, data, score).await
    }

    pub async fn remove_from_queue(
        &self,
        queue_key: &str,
        member: &str,
    ) -> Result<bool, redis::RedisError> {
        let mut conn = self.pool.get().await.unwrap();
        let removed: i64 = conn.zrem(queue_key, member).await?;
        Ok(removed > 0)
    }

    pub async fn get_queue_range<T: DeserializeOwned>(
        &self,
        queue_key: &str,
        start: isize,
        end: isize,
    ) -> Result<Vec<T>, redis::RedisError> {
        let mut conn = self.pool.get().await.unwrap();
        let items: Vec<String> = conn.zrange(queue_key, start, end).await?;
        Ok(items
            .into_iter()
            .filter_map(|s| serde_json::from_str(&s).ok())
            .collect())
    }

    // Match state operations
    pub async fn set_match<T: Serialize>(
        &self,
        match_id: &str,
        data: &T,
        ttl: Duration,
    ) -> Result<(), redis::RedisError> {
        let mut conn = self.pool.get().await.unwrap();
        let json = serde_json::to_string(data).unwrap();
        conn.set_ex(format!("match:{match_id}"), json, ttl.as_secs()).await
    }

    pub async fn get_match<T: DeserializeOwned>(
        &self,
        match_id: &str,
    ) -> Result<Option<T>, redis::RedisError> {
        let mut conn = self.pool.get().await.unwrap();
        let data: Option<String> = conn.get(format!("match:{match_id}")).await?;
        Ok(data.and_then(|s| serde_json::from_str(&s).ok()))
    }

    pub async fn delete_match(&self, match_id: &str) -> Result<(), redis::RedisError> {
        let mut conn = self.pool.get().await.unwrap();
        conn.del(format!("match:{match_id}")).await
    }

    // Pub/sub for real-time events
    pub async fn publish(
        &self,
        channel: &str,
        message: &str,
    ) -> Result<(), redis::RedisError> {
        let mut conn = self.pool.get().await.unwrap();
        conn.publish(channel, message).await
    }
}
```

### Connection Pooling

```rust
// src/connection/pool.rs

use dashmap::DashMap;
use std::sync::Arc;
use tokio::sync::mpsc;
use uuid::Uuid;

/// Connection pool for WebSocket connections
pub struct ConnectionPool {
    connections: DashMap<ConnectionId, Connection>,
    player_to_conn: DashMap<PlayerId, ConnectionId>,
    max_connections: usize,
}

#[derive(Debug, Clone, Hash, PartialEq, Eq)]
pub struct ConnectionId(pub Uuid);

impl ConnectionId {
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }
}

pub struct Connection {
    pub id: ConnectionId,
    pub player_id: Option<PlayerId>,
    pub sender: mpsc::Sender<WsMessage>,
    pub state: ConnectionState,
    pub created_at: DateTime<Utc>,
    pub last_activity: DateTime<Utc>,
}

impl ConnectionPool {
    pub fn new(max_connections: usize) -> Self {
        Self {
            connections: DashMap::new(),
            player_to_conn: DashMap::new(),
            max_connections,
        }
    }

    pub fn add_connection(
        &self,
        sender: mpsc::Sender<WsMessage>,
    ) -> Result<ConnectionId, ConnectionError> {
        if self.connections.len() >= self.max_connections {
            return Err(ConnectionError::PoolFull);
        }

        let conn_id = ConnectionId::new();
        let conn = Connection {
            id: conn_id.clone(),
            player_id: None,
            sender,
            state: ConnectionState::Connected,
            created_at: Utc::now(),
            last_activity: Utc::now(),
        };

        self.connections.insert(conn_id.clone(), conn);
        Ok(conn_id)
    }

    pub fn associate_player(
        &self,
        conn_id: &ConnectionId,
        player_id: &PlayerId,
    ) -> Result<(), ConnectionError> {
        let mut conn = self.connections
            .get_mut(conn_id)
            .ok_or(ConnectionError::NotFound)?;

        conn.player_id = Some(player_id.clone());
        self.player_to_conn.insert(player_id.clone(), conn_id.clone());
        
        Ok(())
    }

    pub fn get_by_player(&self, player_id: &PlayerId) -> Option<Arc<Connection>> {
        self.player_to_conn
            .get(player_id)
            .and_then(|conn_id| self.connections.get(&conn_id))
            .map(|c| Arc::new(c.value().clone()))
    }

    pub async fn send_to_player(
        &self,
        player_id: &PlayerId,
        message: WsMessage,
    ) -> Result<(), ConnectionError> {
        let conn_id = self.player_to_conn
            .get(player_id)
            .ok_or(ConnectionError::NotFound)?;

        let conn = self.connections
            .get(&conn_id)
            .ok_or(ConnectionError::NotFound)?;

        conn.sender
            .send(message)
            .await
            .map_err(|_| ConnectionError::SendFailed)
    }

    pub fn remove_connection(&self, conn_id: &ConnectionId) {
        if let Some((_, conn)) = self.connections.remove(conn_id) {
            if let Some(player_id) = conn.player_id {
                self.player_to_conn.remove(&player_id);
            }
        }
    }
}
```

---

## Frontend Integration

### Svelte 5 Stores for Queue State

```typescript
// src/lib/features/arcade/matchmaking/queue.svelte.ts

import { browser } from '$app/environment';
import type {
  GameType,
  StakeTier,
  QueueStatus,
  MatchFoundData,
  QueuePreferences,
} from '$lib/features/arcade/types';

export interface QueueState {
  status: 'idle' | 'searching' | 'match_found' | 'ready' | 'countdown';
  gameType: GameType | null;
  stakeTier: StakeTier | null;
  position: number | null;
  estimatedWaitSecs: number | null;
  matchData: MatchFoundData | null;
  countdownSecs: number | null;
  error: string | null;
}

export function createQueueStore() {
  // State
  let status = $state<QueueState['status']>('idle');
  let gameType = $state<GameType | null>(null);
  let stakeTier = $state<StakeTier | null>(null);
  let position = $state<number | null>(null);
  let estimatedWaitSecs = $state<number | null>(null);
  let matchData = $state<MatchFoundData | null>(null);
  let countdownSecs = $state<number | null>(null);
  let error = $state<string | null>(null);
  let enteredAt = $state<number | null>(null);

  // Derived
  let isSearching = $derived(status === 'searching');
  let hasMatch = $derived(status === 'match_found' || status === 'ready');
  let waitTimeSecs = $derived(
    enteredAt ? Math.floor((Date.now() - enteredAt) / 1000) : 0
  );
  let canAccept = $derived(status === 'match_found' && matchData !== null);

  // WebSocket connection reference
  let wsClient: WebSocketClient | null = null;

  // Actions
  async function enterQueue(
    game: GameType,
    stake: StakeTier,
    preferences: QueuePreferences = { expandSearch: true }
  ): Promise<void> {
    if (!browser) return;

    try {
      error = null;
      gameType = game;
      stakeTier = stake;
      status = 'searching';
      enteredAt = Date.now();

      wsClient = getWebSocketClient();
      
      await wsClient.send({
        type: 'queue.enter',
        data: {
          game_type: game,
          stake_tier: stake,
          preferences: {
            expand_search: preferences.expandSearch,
            min_opponent_rating: preferences.minOpponentRating ?? null,
            max_opponent_rating: preferences.maxOpponentRating ?? null,
          },
        },
      });
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to enter queue';
      status = 'idle';
      throw e;
    }
  }

  async function leaveQueue(): Promise<void> {
    if (!browser || status !== 'searching') return;

    try {
      await wsClient?.send({
        type: 'queue.leave',
        data: {},
      });
      reset();
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to leave queue';
    }
  }

  async function acceptMatch(): Promise<void> {
    if (!browser || !matchData) return;

    try {
      await wsClient?.send({
        type: 'match.ready',
        data: {
          match_id: matchData.matchId,
          response: 'accept',
        },
      });
      status = 'ready';
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to accept match';
    }
  }

  async function declineMatch(): Promise<void> {
    if (!browser || !matchData) return;

    try {
      await wsClient?.send({
        type: 'match.ready',
        data: {
          match_id: matchData.matchId,
          response: 'decline',
        },
      });
      reset();
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to decline match';
    }
  }

  function reset(): void {
    status = 'idle';
    gameType = null;
    stakeTier = null;
    position = null;
    estimatedWaitSecs = null;
    matchData = null;
    countdownSecs = null;
    error = null;
    enteredAt = null;
  }

  // Message handlers
  function handleQueueUpdate(data: {
    status: string;
    position: number;
    estimated_wait_secs: number;
    players_in_tier: number;
  }): void {
    position = data.position;
    estimatedWaitSecs = data.estimated_wait_secs;
  }

  function handleMatchFound(data: MatchFoundData): void {
    status = 'match_found';
    matchData = data;
    
    // Play sound effect
    playSound('matchFound');
  }

  function handleCountdown(data: {
    seconds_remaining: number;
    code_sequence: string;
    game_starts_at: number;
  }): void {
    status = 'countdown';
    countdownSecs = data.seconds_remaining;
    
    // Update countdown timer
    const interval = setInterval(() => {
      if (countdownSecs !== null && countdownSecs > 0) {
        countdownSecs--;
      } else {
        clearInterval(interval);
      }
    }, 1000);
  }

  function handleError(data: { code: string; message: string }): void {
    error = data.message;
    if (data.code === 'ALREADY_IN_QUEUE' || data.code === 'QUEUE_FULL') {
      status = 'idle';
    }
  }

  // Subscribe to WebSocket messages
  function subscribeToMessages(): () => void {
    if (!browser) return () => {};

    wsClient = getWebSocketClient();
    
    const unsubscribe = wsClient.subscribe((message) => {
      switch (message.type) {
        case 'queue.update':
          handleQueueUpdate(message.data);
          break;
        case 'match.found':
          handleMatchFound(message.data);
          break;
        case 'match.countdown':
          handleCountdown(message.data);
          break;
        case 'error':
          handleError(message.data);
          break;
      }
    });

    return unsubscribe;
  }

  return {
    // State (getters)
    get status() { return status; },
    get gameType() { return gameType; },
    get stakeTier() { return stakeTier; },
    get position() { return position; },
    get estimatedWaitSecs() { return estimatedWaitSecs; },
    get matchData() { return matchData; },
    get countdownSecs() { return countdownSecs; },
    get error() { return error; },
    
    // Derived
    get isSearching() { return isSearching; },
    get hasMatch() { return hasMatch; },
    get waitTimeSecs() { return waitTimeSecs; },
    get canAccept() { return canAccept; },
    
    // Actions
    enterQueue,
    leaveQueue,
    acceptMatch,
    declineMatch,
    reset,
    subscribeToMessages,
  };
}

// Singleton instance
let queueStore: ReturnType<typeof createQueueStore> | null = null;

export function getQueueStore(): ReturnType<typeof createQueueStore> {
  if (!queueStore) {
    queueStore = createQueueStore();
  }
  return queueStore;
}
```

### Match Store

```typescript
// src/lib/features/arcade/matchmaking/match.svelte.ts

import { browser } from '$app/environment';
import type {
  MatchId,
  MatchState,
  PlayerStats,
  OpponentProgress,
  GameResult,
} from '$lib/features/arcade/types';

export interface ActiveMatch {
  matchId: MatchId;
  gameType: GameType;
  state: MatchState;
  codeSequence: string | null;
  startedAt: number | null;
  duration: number;
  myProgress: PlayerProgress;
  opponentProgress: OpponentProgress | null;
}

export interface PlayerProgress {
  progress: number;
  wpm: number;
  accuracy: number;
  currentPosition: number;
}

export function createMatchStore() {
  // State
  let activeMatch = $state<ActiveMatch | null>(null);
  let result = $state<GameResult | null>(null);
  let timeRemainingSecs = $state<number | null>(null);
  let isSubmitting = $state(false);

  // Derived
  let isActive = $derived(activeMatch?.state === 'active');
  let isComplete = $derived(result !== null);
  let myProgress = $derived(activeMatch?.myProgress.progress ?? 0);
  let opponentProgress = $derived(activeMatch?.opponentProgress?.progress ?? 0);
  let isWinning = $derived(myProgress > opponentProgress);

  // Timer interval
  let timerInterval: ReturnType<typeof setInterval> | null = null;

  // Actions
  function startMatch(data: {
    match_id: string;
    game_type: GameType;
    code_sequence: string;
    duration_secs: number;
  }): void {
    activeMatch = {
      matchId: data.match_id,
      gameType: data.game_type,
      state: 'active',
      codeSequence: data.code_sequence,
      startedAt: Date.now(),
      duration: data.duration_secs,
      myProgress: {
        progress: 0,
        wpm: 0,
        accuracy: 1,
        currentPosition: 0,
      },
      opponentProgress: null,
    };

    timeRemainingSecs = data.duration_secs;
    startTimer();
  }

  function updateMyProgress(progress: PlayerProgress): void {
    if (!activeMatch) return;
    activeMatch.myProgress = progress;

    // Send progress to server
    sendProgressUpdate(progress);
  }

  function handleOpponentProgress(data: OpponentProgress): void {
    if (!activeMatch) return;
    activeMatch.opponentProgress = data;
  }

  function handleGameResult(data: GameResult): void {
    stopTimer();
    result = data;
    
    if (activeMatch) {
      activeMatch.state = 'resolved';
    }

    // Play appropriate sound
    if (data.winner === getMyAddress()) {
      playSound('victory');
    } else {
      playSound('defeat');
    }
  }

  function startTimer(): void {
    if (timerInterval) clearInterval(timerInterval);
    
    timerInterval = setInterval(() => {
      if (timeRemainingSecs !== null && timeRemainingSecs > 0) {
        timeRemainingSecs--;
      } else if (timeRemainingSecs === 0) {
        stopTimer();
        // Time ran out - wait for server result
      }
    }, 1000);
  }

  function stopTimer(): void {
    if (timerInterval) {
      clearInterval(timerInterval);
      timerInterval = null;
    }
  }

  async function sendProgressUpdate(progress: PlayerProgress): Promise<void> {
    if (!browser || !activeMatch) return;

    const wsClient = getWebSocketClient();
    await wsClient.send({
      type: 'game.progress',
      data: {
        match_id: activeMatch.matchId,
        progress: progress.progress,
        wpm: progress.wpm,
        accuracy: progress.accuracy,
        current_position: progress.currentPosition,
      },
    });
  }

  function reset(): void {
    stopTimer();
    activeMatch = null;
    result = null;
    timeRemainingSecs = null;
    isSubmitting = false;
  }

  // Subscribe to WebSocket messages
  function subscribeToMessages(): () => void {
    if (!browser) return () => {};

    const wsClient = getWebSocketClient();
    
    return wsClient.subscribe((message) => {
      switch (message.type) {
        case 'game.started':
          startMatch(message.data);
          break;
        case 'game.opponent_progress':
          handleOpponentProgress(message.data);
          break;
        case 'game.result':
          handleGameResult(message.data);
          break;
      }
    });
  }

  return {
    // State
    get activeMatch() { return activeMatch; },
    get result() { return result; },
    get timeRemainingSecs() { return timeRemainingSecs; },
    get isSubmitting() { return isSubmitting; },
    
    // Derived
    get isActive() { return isActive; },
    get isComplete() { return isComplete; },
    get myProgress() { return myProgress; },
    get opponentProgress() { return opponentProgress; },
    get isWinning() { return isWinning; },
    
    // Actions
    updateMyProgress,
    reset,
    subscribeToMessages,
  };
}
```

### UI Components

#### Queue Status Component

```svelte
<!-- src/lib/features/arcade/matchmaking/QueueStatus.svelte -->
<script lang="ts">
  import { getQueueStore } from './queue.svelte';
  import { formatTime } from '$lib/core/utils';
  import { Button } from '$lib/ui/primitives';
  import { Box } from '$lib/ui/terminal';

  const queue = getQueueStore();

  // Subscribe to messages on mount
  $effect(() => {
    const unsubscribe = queue.subscribeToMessages();
    return unsubscribe;
  });
</script>

{#if queue.isSearching}
  <Box title="MATCHMAKING" variant="terminal">
    <div class="queue-status">
      <div class="search-animation">
        <span class="searching-text">SEARCHING FOR OPPONENT</span>
        <span class="dots">...</span>
      </div>

      <div class="stats">
        <div class="stat">
          <span class="label">TIER</span>
          <span class="value">{queue.stakeTier?.toUpperCase()}</span>
        </div>
        <div class="stat">
          <span class="label">WAIT TIME</span>
          <span class="value">{formatTime(queue.waitTimeSecs)}</span>
        </div>
        {#if queue.position}
          <div class="stat">
            <span class="label">QUEUE POSITION</span>
            <span class="value">#{queue.position}</span>
          </div>
        {/if}
        {#if queue.estimatedWaitSecs}
          <div class="stat">
            <span class="label">EST. WAIT</span>
            <span class="value">~{queue.estimatedWaitSecs}s</span>
          </div>
        {/if}
      </div>

      <Button variant="danger" onclick={() => queue.leaveQueue()}>
        CANCEL SEARCH
      </Button>
    </div>
  </Box>
{/if}

{#if queue.error}
  <div class="error-toast">
    {queue.error}
  </div>
{/if}

<style>
  .queue-status {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-4);
  }

  .search-animation {
    text-align: center;
    font-family: var(--font-mono);
    color: var(--color-phosphor);
  }

  .searching-text {
    animation: flicker 2s infinite;
  }

  .dots {
    animation: blink 1s infinite steps(4);
  }

  .stats {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: var(--space-2);
  }

  .stat {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .label {
    font-size: var(--text-xs);
    color: var(--color-muted);
    text-transform: uppercase;
  }

  .value {
    font-family: var(--font-mono);
    color: var(--color-phosphor);
  }

  .error-toast {
    position: fixed;
    bottom: var(--space-4);
    left: 50%;
    transform: translateX(-50%);
    background: var(--color-danger);
    color: var(--color-bg);
    padding: var(--space-2) var(--space-4);
    font-family: var(--font-mono);
  }

  @keyframes flicker {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.8; }
  }

  @keyframes blink {
    0% { content: ''; }
    25% { content: '.'; }
    50% { content: '..'; }
    75% { content: '...'; }
  }
</style>
```

#### Match Found Modal

```svelte
<!-- src/lib/features/arcade/matchmaking/MatchFoundModal.svelte -->
<script lang="ts">
  import { getQueueStore } from './queue.svelte';
  import { formatAddress, formatAmount } from '$lib/core/utils';
  import { Button } from '$lib/ui/primitives';
  import { Modal, Box } from '$lib/ui/terminal';

  const queue = getQueueStore();

  let acceptDeadline = $derived(
    queue.matchData?.acceptDeadline 
      ? Math.max(0, Math.floor((queue.matchData.acceptDeadline - Date.now()) / 1000))
      : 0
  );

  // Countdown timer
  $effect(() => {
    if (queue.status !== 'match_found') return;
    
    const interval = setInterval(() => {
      // Force reactivity update
      queue.matchData;
    }, 1000);

    return () => clearInterval(interval);
  });
</script>

<Modal 
  open={queue.status === 'match_found'} 
  onclose={() => queue.declineMatch()}
>
  <Box title="MATCH FOUND" variant="highlight">
    {#if queue.matchData}
      <div class="match-found">
        <div class="versus">
          <div class="player you">
            <span class="label">YOU</span>
            <span class="address">{formatAddress(getMyAddress())}</span>
            <span class="rating">Rating: {getMyRating()}</span>
          </div>

          <span class="vs">VS</span>

          <div class="player opponent">
            <span class="label">OPPONENT</span>
            <span class="address">{formatAddress(queue.matchData.opponent.address)}</span>
            <span class="rating">Rating: {queue.matchData.opponent.rating}</span>
            <span class="stats">
              W: {queue.matchData.opponent.wins} | 
              Avg WPM: {queue.matchData.opponent.avgWpm}
            </span>
          </div>
        </div>

        <div class="wager-info">
          <div class="row">
            <span>WAGER</span>
            <span>{formatAmount(queue.matchData.wager)} $DATA each</span>
          </div>
          <div class="row">
            <span>PRIZE</span>
            <span>{formatAmount(BigInt(queue.matchData.wager) * 9n / 10n * 2n)} $DATA (winner)</span>
          </div>
          <div class="row burn">
            <span>BURN</span>
            <span>{formatAmount(BigInt(queue.matchData.wager) * 1n / 10n * 2n)} $DATA (10%)</span>
          </div>
        </div>

        <div class="countdown">
          Match expires in: <span class="time">{acceptDeadline}</span>
        </div>

        <div class="actions">
          <Button variant="primary" onclick={() => queue.acceptMatch()}>
            ACCEPT MATCH
          </Button>
          <Button variant="ghost" onclick={() => queue.declineMatch()}>
            DECLINE
          </Button>
        </div>
      </div>
    {/if}
  </Box>
</Modal>

<style>
  .match-found {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-4);
  }

  .versus {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);
  }

  .player {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    text-align: center;
  }

  .player.you {
    text-align: left;
  }

  .player.opponent {
    text-align: right;
  }

  .label {
    font-size: var(--text-xs);
    color: var(--color-muted);
  }

  .address {
    font-family: var(--font-mono);
    color: var(--color-phosphor);
  }

  .rating {
    font-size: var(--text-sm);
  }

  .stats {
    font-size: var(--text-xs);
    color: var(--color-muted);
  }

  .vs {
    font-size: var(--text-xl);
    font-weight: bold;
    color: var(--color-phosphor);
  }

  .wager-info {
    border: 1px solid var(--color-border);
    padding: var(--space-3);
  }

  .row {
    display: flex;
    justify-content: space-between;
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    padding: var(--space-1) 0;
  }

  .row.burn {
    color: var(--color-danger);
  }

  .countdown {
    text-align: center;
    color: var(--color-warning);
    font-family: var(--font-mono);
  }

  .countdown .time {
    font-weight: bold;
    font-size: var(--text-lg);
  }

  .actions {
    display: flex;
    gap: var(--space-2);
    justify-content: center;
  }
</style>
```

---

## Edge Cases and Error Handling

### Disconnect Handling

```rust
/// Handle various disconnect scenarios
pub enum DisconnectScenario {
    /// Player disconnects while in queue
    InQueue { player_id: PlayerId },
    /// Player disconnects during ready check
    DuringReadyCheck { match_id: MatchId, player_id: PlayerId },
    /// Player disconnects during active game
    DuringGame { match_id: MatchId, player_id: PlayerId },
    /// Player disconnects as spectator
    AsSpectator { match_id: MatchId, conn_id: ConnectionId },
}

impl MatchmakingEngine {
    pub async fn handle_disconnect(&self, scenario: DisconnectScenario) -> Result<(), Error> {
        match scenario {
            DisconnectScenario::InQueue { player_id } => {
                // Simply remove from queue
                self.queue_manager.remove_player(&player_id).await?;
                tracing::info!("Removed disconnected player {} from queue", player_id);
            }

            DisconnectScenario::DuringReadyCheck { match_id, player_id } => {
                // Cancel match, requeue opponent
                let match_data = self.match_manager.get_match(&match_id).await?;
                let opponent = match_data.get_opponent(&player_id);
                
                self.match_manager.cancel_match(&match_id, CancelReason::Disconnect).await?;
                
                if let Some(opp) = opponent {
                    self.queue_manager.requeue_player(&opp.player_id).await?;
                    self.notify_player(&opp.player_id, MatchEvent::OpponentDisconnected {
                        requeued: true,
                    }).await?;
                }
            }

            DisconnectScenario::DuringGame { match_id, player_id } => {
                // Start grace period, then forfeit if not reconnected
                self.start_grace_period(&match_id, &player_id).await?;
                
                // Notify opponent
                let match_data = self.match_manager.get_match(&match_id).await?;
                if let Some(opp) = match_data.get_opponent(&player_id) {
                    self.notify_player(&opp.player_id, MatchEvent::OpponentDisconnected {
                        grace_period_secs: 30,
                    }).await?;
                }
            }

            DisconnectScenario::AsSpectator { match_id, conn_id } => {
                // Just remove from spectator list
                self.spectator_manager.leave_spectator(&match_id, &conn_id).await?;
            }
        }
        
        Ok(())
    }
}
```

### Abandon Handling

```rust
/// Handle intentional match abandonment
pub async fn handle_abandon(
    &self,
    match_id: &MatchId,
    player_id: &PlayerId,
) -> Result<(), MatchmakingError> {
    let match_data = self.get_match(match_id).await?;
    
    match match_data.state {
        MatchState::Matched | MatchState::Ready => {
            // Before game starts - cancel match, no penalty
            self.cancel_match(match_id, CancelReason::Abandoned { by: player_id.clone() }).await?;
            
            // Requeue opponent
            if let Some(opp) = match_data.get_opponent(player_id) {
                self.queue_manager.requeue_player(&opp.player_id).await?;
            }
        }
        MatchState::Active => {
            // During game - forfeit
            let opponent = match_data.get_opponent(player_id)
                .ok_or(MatchmakingError::InvalidState)?;
            
            let result = GameResult {
                match_id: match_id.clone(),
                winner: Some(opponent.player_id.clone()),
                player_stats: vec![],
                duration_ms: 0,
                end_reason: EndReason::Forfeit(player_id.clone()),
            };
            
            self.end_game(result).await?;
        }
        _ => {
            return Err(MatchmakingError::InvalidState);
        }
    }
    
    Ok(())
}
```

### Timeout Handling

```rust
/// Timeout configurations and handlers
pub struct TimeoutConfig {
    pub queue_max_wait: Duration,
    pub ready_check: Duration,
    pub game_duration: Duration,
    pub disconnect_grace: Duration,
}

impl Default for TimeoutConfig {
    fn default() -> Self {
        Self {
            queue_max_wait: Duration::from_secs(300),    // 5 min
            ready_check: Duration::from_secs(15),        // 15 sec
            game_duration: Duration::from_secs(60),      // 1 min
            disconnect_grace: Duration::from_secs(30),   // 30 sec
        }
    }
}

/// Background task for timeout processing
pub async fn run_timeout_processor(
    match_manager: Arc<MatchManager>,
    config: TimeoutConfig,
) {
    let mut interval = tokio::time::interval(Duration::from_secs(1));
    
    loop {
        interval.tick().await;
        
        // Check for ready check timeouts
        let pending_matches = match_manager.get_matches_in_state(MatchState::Matched).await;
        for match_data in pending_matches {
            let elapsed = Utc::now() - match_data.created_at;
            if elapsed > chrono::Duration::from_std(config.ready_check).unwrap() {
                // Find non-ready players
                for player in &match_data.players {
                    if !player.ready {
                        match_manager.handle_ready_timeout(&match_data.match_id, &player.player_id).await.ok();
                    }
                }
            }
        }
        
        // Check for game duration timeouts
        let active_matches = match_manager.get_matches_in_state(MatchState::Active).await;
        for match_data in active_matches {
            if let Some(started_at) = match_data.started_at {
                let elapsed = Utc::now() - started_at;
                if elapsed > chrono::Duration::from_std(config.game_duration).unwrap() {
                    match_manager.handle_game_timeout(&match_data.match_id).await.ok();
                }
            }
        }
        
        // Check for disconnect grace period expirations
        let disconnected = match_manager.get_disconnected_players().await;
        for (match_id, player_id, disconnected_at) in disconnected {
            let elapsed = Utc::now() - disconnected_at;
            if elapsed > chrono::Duration::from_std(config.disconnect_grace).unwrap() {
                match_manager.handle_forfeit(&match_id, &player_id).await.ok();
            }
        }
    }
}
```

---

## Scaling Considerations

### Horizontal Scaling Architecture

```
HORIZONTAL SCALING FOR 1000+ CONCURRENT MATCHES
════════════════════════════════════════════════════════════════════

                        ┌─────────────────────┐
                        │   Load Balancer     │
                        │   (sticky sessions) │
                        └──────────┬──────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    ▼                    ▼
    ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
    │ Coordinator #1   │ │ Coordinator #2   │ │ Coordinator #N   │
    │ (WS + HTTP)      │ │ (WS + HTTP)      │ │ (WS + HTTP)      │
    └────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘
             │                    │                    │
             └────────────────────┼────────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
                    ▼             ▼             ▼
           ┌──────────────┐ ┌──────────┐ ┌────────────┐
           │ Redis        │ │ Postgres │ │ Apache     │
           │ Cluster      │ │ (primary)│ │ Iggy       │
           │ (6 nodes)    │ │          │ │            │
           └──────────────┘ └──────────┘ └────────────┘

════════════════════════════════════════════════════════════════════

SCALING STRATEGIES:

1. STATELESS COORDINATORS
   - All state in Redis/Postgres
   - Any coordinator can handle any request
   - Sticky sessions for WebSocket affinity

2. REDIS CLUSTER FOR HOT STATE
   - Queues: Sorted sets with player entries
   - Matches: Hash maps with match state
   - Pub/Sub: Cross-coordinator messaging

3. POSTGRES FOR DURABILITY
   - Match history
   - Player statistics
   - Settlement records

4. PARTITIONING STRATEGY
   - Queue partitioning by stake tier
   - Match partitioning by game type
   - Connection partitioning by consistent hash

CAPACITY ESTIMATES (per coordinator):
├── WebSocket connections: 3,000
├── Concurrent matches: 500
├── Queue operations/sec: 200
└── Message throughput: 10,000/sec

TOTAL CAPACITY (3 coordinators):
├── WebSocket connections: 9,000
├── Concurrent matches: 1,500
├── Queue operations/sec: 600
└── Message throughput: 30,000/sec
```

### Performance Optimizations

```rust
/// Configuration for high-throughput operation
pub struct PerformanceConfig {
    /// Batch size for queue processing
    pub queue_batch_size: usize,
    /// Interval between matching attempts
    pub matching_interval: Duration,
    /// Progress update rate limiting
    pub progress_rate_limit: Duration,
    /// Spectator broadcast batching
    pub spectator_batch_interval: Duration,
}

impl Default for PerformanceConfig {
    fn default() -> Self {
        Self {
            queue_batch_size: 100,
            matching_interval: Duration::from_millis(100),
            progress_rate_limit: Duration::from_millis(50),
            spectator_batch_interval: Duration::from_millis(200),
        }
    }
}

/// Rate limiter for progress updates
pub struct ProgressRateLimiter {
    last_update: DashMap<(MatchId, PlayerId), Instant>,
    min_interval: Duration,
}

impl ProgressRateLimiter {
    pub fn should_send(&self, match_id: &MatchId, player_id: &PlayerId) -> bool {
        let key = (match_id.clone(), player_id.clone());
        
        if let Some(last) = self.last_update.get(&key) {
            if last.elapsed() < self.min_interval {
                return false;
            }
        }
        
        self.last_update.insert(key, Instant::now());
        true
    }
}

/// Batched spectator broadcaster
pub struct BatchedBroadcaster {
    pending: DashMap<MatchId, Vec<SpectatorEvent>>,
    batch_interval: Duration,
}

impl BatchedBroadcaster {
    pub async fn queue_broadcast(&self, match_id: &MatchId, event: SpectatorEvent) {
        self.pending
            .entry(match_id.clone())
            .or_default()
            .push(event);
    }

    pub async fn flush(&self, spectator_manager: &SpectatorManager) {
        let matches: Vec<_> = self.pending
            .iter()
            .map(|entry| (entry.key().clone(), entry.value().clone()))
            .collect();

        for (match_id, events) in matches {
            if let Some((_, events)) = self.pending.remove(&match_id) {
                // Send combined update
                if let Some(latest) = events.last() {
                    spectator_manager.broadcast_to_spectators(&match_id, latest.clone()).await.ok();
                }
            }
        }
    }
}
```

---

## Monitoring and Observability

```rust
/// Metrics for matchmaking system
pub struct MatchmakingMetrics {
    // Queue metrics
    pub queue_size: IntGauge,
    pub queue_wait_time: Histogram,
    pub matches_created: IntCounter,
    pub matches_cancelled: IntCounter,

    // Match metrics  
    pub active_matches: IntGauge,
    pub match_duration: Histogram,
    pub games_completed: IntCounter,
    pub games_forfeited: IntCounter,

    // Connection metrics
    pub active_connections: IntGauge,
    pub disconnections: IntCounter,
    pub reconnections: IntCounter,

    // Performance metrics
    pub matching_latency: Histogram,
    pub ws_message_latency: Histogram,
}

impl MatchmakingMetrics {
    pub fn register(registry: &Registry) -> Self {
        Self {
            queue_size: IntGauge::new("matchmaking_queue_size", "Players in queue")
                .expect("metric"),
            queue_wait_time: Histogram::with_opts(
                HistogramOpts::new("matchmaking_queue_wait_seconds", "Queue wait time")
                    .buckets(vec![1.0, 5.0, 15.0, 30.0, 60.0, 120.0, 300.0]),
            ).expect("metric"),
            matches_created: IntCounter::new("matchmaking_matches_created", "Matches created")
                .expect("metric"),
            // ... register all metrics
        }
    }
}
```

---

## Testing Strategy

### Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_elo_calculation() {
        let elo = EloSystem::new(32.0);
        
        // Equal ratings
        let (new_winner, new_loser) = elo.calculate_new_ratings(1200, 1200);
        assert_eq!(new_winner, 1216);
        assert_eq!(new_loser, 1184);
        
        // Upset (lower beats higher)
        let (new_winner, new_loser) = elo.calculate_new_ratings(1100, 1300);
        assert!(new_winner > 1100 + 16); // More than expected gain
        assert!(new_loser < 1300 - 16);  // More than expected loss
    }

    #[test]
    fn test_stake_tier_matching() {
        let bronze_entry = QueueEntry {
            stake_tier: StakeTier::Bronze,
            ..Default::default()
        };
        let gold_entry = QueueEntry {
            stake_tier: StakeTier::Gold,
            ..Default::default()
        };
        
        // Should not match different tiers
        assert!(!can_match(&bronze_entry, &gold_entry));
    }

    #[test]
    fn test_spectator_odds_calculation() {
        let mut bets = SpectatorBets::default();
        
        bets.player1_pool = U256::from(800);
        bets.player2_pool = U256::from(400);
        bets.total_pool = U256::from(1200);
        
        let (p1_odds, p2_odds) = bets.calculate_odds();
        
        // After 5% rake: pool = 1140
        // P1 odds: 1140 / 800 = 1.425
        // P2 odds: 1140 / 400 = 2.85
        assert!((p1_odds - 1.425).abs() < 0.01);
        assert!((p2_odds - 2.85).abs() < 0.01);
    }
}
```

### Integration Tests

```rust
#[tokio::test]
async fn test_full_match_lifecycle() {
    let harness = TestHarness::setup().await;
    
    // Create two players
    let player1 = harness.create_player("0x7a3f").await;
    let player2 = harness.create_player("0x9c2d").await;
    
    // Both enter queue
    harness.enter_queue(&player1, StakeTier::Gold).await;
    harness.enter_queue(&player2, StakeTier::Gold).await;
    
    // Wait for match
    let match_id = harness.wait_for_match(&player1, Duration::from_secs(5)).await?;
    
    // Both accept
    harness.accept_match(&player1, &match_id).await;
    harness.accept_match(&player2, &match_id).await;
    
    // Wait for game start
    harness.wait_for_game_start(&match_id).await?;
    
    // Simulate gameplay
    harness.send_progress(&player1, &match_id, 1.0).await; // Player 1 completes
    
    // Wait for result
    let result = harness.wait_for_result(&match_id, Duration::from_secs(5)).await?;
    
    assert_eq!(result.winner, Some(player1.id));
    assert_eq!(result.end_reason, EndReason::Completed);
}

#[tokio::test]
async fn test_disconnect_and_reconnect() {
    let harness = TestHarness::setup().await;
    
    let player1 = harness.create_player("0x7a3f").await;
    let player2 = harness.create_player("0x9c2d").await;
    
    // Start match
    let match_id = harness.setup_active_match(&player1, &player2).await;
    
    // Player 1 disconnects
    harness.disconnect(&player1).await;
    
    // Verify opponent notified
    let event = harness.receive_event(&player2).await;
    assert!(matches!(event, MatchEvent::OpponentDisconnected { .. }));
    
    // Player 1 reconnects within grace period
    harness.reconnect(&player1).await;
    
    // Verify opponent notified of reconnection
    let event = harness.receive_event(&player2).await;
    assert!(matches!(event, MatchEvent::OpponentReconnected { .. }));
    
    // Match should continue
    let match_state = harness.get_match_state(&match_id).await;
    assert_eq!(match_state, MatchState::Active);
}
```

---

## Related Documents

- [Game Engine Architecture](./game-engine.md)
- [Smart Contract Specs](./contracts.md)
- [Randomness & Fairness](./randomness.md)
- [CODE DUEL Design](../games/02-code-duel.md)
- [BOUNTY HUNT Design](../games/06-bounty-hunt.md)
- [PROXY WAR Design](../games/07-proxy-war.md)
