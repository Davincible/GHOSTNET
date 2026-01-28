# Getting Started Panel — Design Plan

> **Status:** Design Complete — Ready for Implementation  
> **Component:** `apps/web/src/lib/features/getting-started/GettingStartedPanel.svelte`  
> **Replaces:** `DailyOpsPanel` in right column when wallet is not connected  
> **Date:** 2026-01-27

---

## 1. The Problem

A new visitor lands on GHOSTNET. They're crypto-native — they have a wallet, ETH on MegaETH, they know how chains work. But they've never seen *this game*.

Right now the right column shows them:

1. **PositionPanel** — says "DISCONNECTED" (useful, tells them to connect)
2. **ModifiersPanel** — empty (noise)
3. **DailyOpsPanel** — shows streaks, missions, "CLAIM DAILY REWARD" (nonsensical — they haven't even connected)
4. **NetworkVitalsPanel** — stats they can't contextualize yet
5. **QuickActionsPanel** — all buttons disabled
6. **FAQPanel** — walls of text they won't read yet

The DailyOpsPanel is the worst offender. It speaks the language of a returning operator to someone who doesn't know what an operator *is*. It assumes familiarity when there is none. Streaks? Missions? "CLAIM DAILY REWARD"? These words mean nothing to someone who hasn't connected a wallet, hasn't jacked in, hasn't survived a single scan. The panel is speaking to an operator who doesn't exist yet.

Meanwhile, the left column's WelcomePanel carousel handles the *pitch* — why GHOSTNET exists, how the game works, the risk levels, the trust model. Seven slides. Cinematic. Animated. It's doing its job. But it's a trailer, not instructions.

What's missing is the *operational counterpart*: not "here's why this world is cool" but "here's what to do to enter it."

---

## 2. Target User

**Crypto-native, GHOSTNET-naive.**

They know:
- How to use a wallet (MetaMask, Rabby, etc.)
- What MegaETH is (or at least that it's an L2)
- How tokens, staking, and DeFi work conceptually
- How to get ETH and swap for tokens

They don't know:
- What GHOSTNET is beyond what they've seen in the last 30 seconds
- What "Jack In" means, what "Trace Scan" means, what "The Cascade" means
- What they're supposed to *do* right now
- Whether this is safe, how much they could lose, what the risks are

**The gap we're closing:** They're intrigued by the terminal aesthetic and the feed scrolling by. They need to go from "this looks cool" to "I understand what this is and I know what to do next" in under 60 seconds of reading.

### The Mental Model They Need to Build

There are six concepts that, once understood, make the entire game click:

1. **You stake $DATA into a risk level** — that's your position
2. **You earn yield while you're in** — passive, automatic
3. **Periodic scans can kill you** — lose your stake
4. **When others die, their stake flows to you** — that's your yield source
5. **Mini-games reduce your death rate** — skill gives you an edge
6. **You extract whenever you want** — take your gains and leave

That's it. Six concepts. If they understand those, they understand the game. Everything else — the cascade formula, the burn engines, crew mechanics, hack run node types — is discoverable through play. The Getting Started panel exists to plant these six seeds.

---

## 3. Design Intent

### What It Should Feel Like

Booting into a new system for the first time. You SSH into a box and the first thing it prints is a briefing — not a tutorial, not a walkthrough, not a marketing carousel. A single, scannable document that tells you everything you need to know to start operating.

Like a `README`. Like a `--help` output. Like the message-of-the-day that greets you when you log into a server.

```
GHOSTNET ACCESS PROTOCOL
════════════════════════

WELCOME, OPERATOR.

Before you jack in, here's what you need to know.

───────────────────────────────────────────────

01 ► CONNECT WALLET
    Link your wallet to access the network.
    [ CONNECT WALLET ]

02 ► CHOOSE YOUR LEVEL
    5 risk tiers. Higher risk = higher yield = more death.
    THE VAULT (0%) → BLACK ICE (90%)

03 ► JACK IN
    Stake $DATA at your chosen level. You're now live.
    Yield starts accumulating immediately.

04 ► SURVIVE THE SCANS
    Periodic trace scans roll for death. If traced,
    you lose your stake. If you ghost, you profit.

05 ► PLAY FOR AN EDGE
    Mini-games reduce your death rate up to -35%.
    Passive works. Active works better.

06 ► EXTRACT
    Cash out anytime. Principal + earned yield.
    Or stay in and keep earning.

───────────────────────────────────────────────
⚠ THIS IS HIGH RISK. You can lose everything.
  Only jack in what you can afford to lose.
```

That's the vibe. A single-screen briefing. No slides. No carousel. No animation choreography. Just *clarity*.

The WelcomePanel is the *trailer*. This panel is the *field manual*.

### Design Principles

1. **Scannable, not scrollable.** The entire briefing should be visible without scrolling on desktop. If it doesn't fit in one screen, it's too long.

2. **Operational, not aspirational.** No "imagine a world where..." — just "here's what you do." The WelcomePanel handles the story. This handles the steps.

3. **Terminal-native.** Box component, monospace, terminal aesthetic. But the *content* is human-readable plain language — clarity dressed in terminal clothing.

4. **Self-destructing.** Once the user has connected their wallet, this panel's job is done. DailyOpsPanel takes its place. The user has graduated from "getting started" to "operating."

---

## 4. Three Design Directions

We explored three approaches. Each has merits. The final recommendation is a hybrid.

### Direction A: The Static Briefing

A clean, scrollable terminal-style document. All steps visible at once. No interactive state. A Connect Wallet button embedded at the top, but the rest is pure text.

```
╔══════════════════════════════════════════════════╗
║              GETTING STARTED                     ║
╠══════════════════════════════════════════════════╣
║                                                  ║
║  Stake $DATA. Earn yield. Survive the trace      ║
║  scans. When others die, you profit.             ║
║                                                  ║
║  ─── HOW IT WORKS ──────────────────────────── ║
║                                                  ║
║  01  CONNECT WALLET                              ║
║      Link your wallet to access the network.     ║
║                                                  ║
║  02  JACK IN                                     ║
║      Choose a risk level. Stake $DATA.           ║
║      Yield starts accumulating immediately.      ║
║                                                  ║
║  03  SURVIVE                                     ║
║      Periodic trace scans roll for death.        ║
║      Play mini-games to reduce your odds.        ║
║                                                  ║
║  04  EXTRACT                                     ║
║      Cash out anytime. Principal + earned yield.  ║
║      Or stay in and keep earning.                ║
║                                                  ║
║  ─── RISK LEVELS ────────────────────────────── ║
║                                                  ║
║  ▌ VAULT      0% death    Safe haven            ║
║  ▌ MAINFRAME  2% death    Every 24h             ║
║  ▌ SUBNET    15% death    Every 8h              ║
║  ▌ DARKNET   40% death    Every 2h              ║
║  ▌ BLACK ICE 90% death    Every 30min           ║
║                                                  ║
║  Higher risk = higher yield.                     ║
║  Dead capital flows UP to safer levels.          ║
║                                                  ║
║  ─── THE KEY INSIGHT ────────────────────────── ║
║                                                  ║
║  When someone gets traced, their stake doesn't   ║
║  vanish. 60% flows to survivors. 30% is burned   ║
║  forever. You earn yield from other people dying. ║
║                                                  ║
║  ─────────────────────────────────────────────── ║
║                                                  ║
║  [ CONNECT WALLET ]                              ║
║                                                  ║
║  ⚠ High risk. You can lose everything.           ║
║    Only stake what you can afford to lose.       ║
╚══════════════════════════════════════════════════╝
```

**What's good about this:**
- Dead simple. Scannable. No interaction complexity.
- Feels like a `man` page or a `--help` output. Terminal-native.
- All information visible at once — no hidden steps, no progressive disclosure.
- The user reads top to bottom, understands the whole game, hits the button.
- Zero state management. Zero reactive logic. Pure content.

**What's weaker:**
- Feels passive. It's a wall of text in a game that's supposed to feel *alive*.
- Doesn't reward progress. Doesn't create a sense of "I'm moving forward."
- Could be ignored as "just documentation" in a sea of panels.
- The CTA button is at the bottom, below the fold on some screens. The user has to read everything before they see what to *do*.

**Best for:** Users who want to understand before they act. The careful reader.

---

### Direction B: The Interactive Checklist

Steps that check off as the user progresses. Step 1: Connect Wallet (with embedded button). Once connected, the panel disappears entirely and DailyOpsPanel takes over.

The key insight: **steps 3 and 4 (Survive, Extract) aren't onboarding steps — they're gameplay concepts**. You don't "complete" surviving. You don't "check off" extracting. So the interactive part is short: just the steps the user actually *takes* before the panel vanishes.

```
╔══════════════════════════════════════════════════╗
║              GETTING STARTED                     ║
╠══════════════════════════════════════════════════╣
║                                                  ║
║  Stake $DATA. Earn yield. Survive the trace      ║
║  scans. When others die, you profit.             ║
║                                                  ║
║  ─── WHAT TO DO ─────────────────────────────── ║
║                                                  ║
║  01 ► CONNECT WALLET                             ║
║      Link your wallet to access the network.     ║
║      [ CONNECT WALLET ]                          ║
║                                                  ║
║  02 ○ JACK IN                                    ║
║      Choose a risk level. Stake $DATA.           ║
║      Yield starts accumulating immediately.      ║
║                                                  ║
║  03 ○ SURVIVE                                    ║
║      Periodic trace scans roll for death.        ║
║      Play mini-games to reduce your odds.        ║
║                                                  ║
║  04 ○ EXTRACT                                    ║
║      Cash out anytime. Principal + earned yield.  ║
║      Or stay in and keep earning.                ║
║                                                  ║
║  ─── RISK LEVELS ────────────────────────────── ║
║                                                  ║
║  ▌ VAULT      0% death    Safe haven            ║
║  ▌ MAINFRAME  2% death    Every 24h             ║
║  ▌ SUBNET    15% death    Every 8h              ║
║  ▌ DARKNET   40% death    Every 2h              ║
║  ▌ BLACK ICE 90% death    Every 30min           ║
║                                                  ║
║  Higher risk = higher yield.                     ║
║  Dead capital flows UP to safer levels.          ║
║                                                  ║
║  ─────────────────────────────────────────────── ║
║  ⚠ High risk. You can lose everything.           ║
║    Only stake what you can afford to lose.       ║
╚══════════════════════════════════════════════════╝
```

The step icons communicate state at a glance:

| State | Icon | Visual | When |
|-------|------|--------|------|
| **Current** | `►` | Bright text, accent step number, CTA button | What to do now |
| **Future** | `○` | Dimmed text, muted step number | Not yet |
| **Complete** | `✓` | Green check, normal brightness | Done |

Since this panel only shows when wallet is disconnected, the states in practice are always:
- Step 01: **current** (with Connect Wallet button)
- Steps 02–04: **future** (dimmed)

Once wallet connects, the panel disappears entirely. We never show step 01 as complete *within this panel* — that transition is handled by the panel swap to DailyOps.

**What's good about this:**
- Feels alive. The visual hierarchy (bright current step, dimmed future steps) creates a sense of "I'm here, and there's more ahead."
- The CTA button is right next to the current step, not buried at the bottom. The action is always clear.
- The dimmed future steps create curiosity — "what happens after I connect?"
- Natural transition: connect → panel disappears → DailyOps appears → they're in the system.

**What's weaker:**
- The "interactive" part is thin — there's only one state change (panel appears → panel disappears). The steps never actually transition from future to current to complete within the panel's lifecycle.
- Steps 03 and 04 aren't really "steps" — they're gameplay concepts. Labeling them as future steps implies they're actions to take in sequence, which isn't quite right.

**Best for:** Users who act first and learn second. The clicker.

---

### Direction C: The Two-Part Briefing

A compact panel that splits into two distinct zones: a **dynamic action zone** (what to do right now) and a **static reference zone** (what you need to know). The action zone is prominent — a single, focused CTA based on the user's state. The reference zone is a compact quick-reference card.

```
╔══════════════════════════════════════════════════╗
║              GETTING STARTED                     ║
╠══════════════════════════════════════════════════╣
║                                                  ║
║  Stake $DATA. Earn yield. Survive the trace      ║
║  scans. When others die, you profit.             ║
║                                                  ║
║  ─── STEP 1: CONNECT YOUR WALLET ───────────── ║
║                                                  ║
║  Link your wallet to access the network.         ║
║  Once connected, choose a risk level and         ║
║  jack in to start earning.                       ║
║                                                  ║
║  [ CONNECT WALLET ]                              ║
║                                                  ║
║  ─── RISK LEVELS ────────────────────────────── ║
║                                                  ║
║  ▌ VAULT      0% death    Safe haven            ║
║  ▌ MAINFRAME  2% death    Every 24h             ║
║  ▌ SUBNET    15% death    Every 8h              ║
║  ▌ DARKNET   40% death    Every 2h              ║
║  ▌ BLACK ICE 90% death    Every 30min           ║
║                                                  ║
║  Higher risk = higher yield.                     ║
║  Dead capital flows UP to safer levels.          ║
║                                                  ║
║  ─────────────────────────────────────────────── ║
║  ⚠ High risk. You can lose everything.           ║
║    Only stake what you can afford to lose.       ║
╚══════════════════════════════════════════════════╝
```

**What's good about this:**
- Most compact option. The one-liner pitch + the immediate action + the reference table in one tight panel.
- Doesn't pretend to be a tutorial or a checklist. Respects that the user is crypto-native and just needs the key info fast.
- The action zone could evolve for different states (if we ever keep the panel visible post-connect, it swaps to "STEP 2: JACK IN").

**What's weaker:**
- Doesn't teach the full game loop. "Survive" and "Extract" aren't mentioned as explicit concepts — just implied by the one-liner and the risk table.
- Less educational than A or B. A user who *only* reads this panel might connect and then not understand what trace scans are.
- Could feel too minimal — like a login prompt rather than a briefing.

**Best for:** Users who already get the gist from the WelcomePanel and just need a quick "OK, what do I click?"

---

## 5. The Recommendation: A/B Hybrid

**Direction B's structure with Direction A's depth.**

The static briefing (A) has the right *content* — it teaches the full game loop, it has the key insight about the cascade, it reads like a system document. The interactive checklist (B) has the right *feel* — the step states create visual hierarchy, the CTA is embedded where you need it, the dimmed future steps create forward momentum.

The hybrid takes B's visual language (► current, ○ future, step numbers, embedded CTA) and fills it with A's content richness (the cascade insight, the risk table context, enough detail that you actually understand the game).

Direction C is too thin for someone who hasn't read the WelcomePanel carefully. We can't assume they watched all 7 slides. This panel may be the *only* thing they read before deciding whether to connect.

### What The Hybrid Looks Like

```
╔══════════════════════════════════════════════════╗
║              GETTING STARTED                     ║
╠══════════════════════════════════════════════════╣
║                                                  ║
║  Stake $DATA. Earn yield. Survive the trace      ║
║  scans. When others die, you profit.             ║
║                                                  ║
║  ─── WHAT TO DO ─────────────────────────────── ║
║                                                  ║
║  01 ► CONNECT WALLET                             ║
║      Link your wallet to access the network.     ║
║      [ CONNECT WALLET ]                          ║
║                                                  ║
║  02 ○ JACK IN                                    ║
║      Choose a risk level. Stake $DATA.           ║
║      Yield starts accumulating immediately.      ║
║                                                  ║
║  03 ○ SURVIVE                                    ║
║      Periodic trace scans roll for death.        ║
║      Play mini-games to reduce your odds.        ║
║                                                  ║
║  04 ○ EXTRACT                                    ║
║      Cash out anytime. Principal + earned yield.  ║
║      Or stay in and keep earning.                ║
║                                                  ║
║  ─── RISK LEVELS ────────────────────────────── ║
║                                                  ║
║  ▌ VAULT      0% death    Safe haven            ║
║  ▌ MAINFRAME  2% death    Every 24h             ║
║  ▌ SUBNET    15% death    Every 8h              ║
║  ▌ DARKNET   40% death    Every 2h              ║
║  ▌ BLACK ICE 90% death    Every 30min           ║
║                                                  ║
║  Higher risk = higher yield.                     ║
║  Dead capital flows UP to safer levels.          ║
║                                                  ║
║  ─── THE KEY INSIGHT ────────────────────────── ║
║                                                  ║
║  When someone gets traced, their stake doesn't   ║
║  vanish. 60% flows to survivors. 30% is burned   ║
║  forever. You earn yield from other people dying. ║
║                                                  ║
║  ─────────────────────────────────────────────── ║
║  ⚠ High risk. You can lose everything.           ║
║    Only stake what you can afford to lose.       ║
╚══════════════════════════════════════════════════╝
```

This is the version we build.

### Why This Hybrid Works

1. **The steps (from B)** give the user a sense of sequence and progress. Step 01 is bright and has a button. Steps 02–04 are dimmed but readable. The visual hierarchy says "do this first, then these things happen."

2. **The risk table (shared across all directions)** is the reference material that helps them make their first real decision: which level to pick. It's compact (5 rows, 3 columns) and color-coded. They'll see this information again in the Jack In modal, but having it here primes the decision.

3. **The key insight section (from A)** is the piece that makes the economics click. Without it, the user knows "there are scans that can kill you" but doesn't understand *why* — where yield comes from, why deaths aren't just loss but redistribution. Three sentences. The cascade in plain English. This is the "aha" moment.

4. **The warning (shared)** is non-negotiable. Real money. Real risk. Always visible.

---

## 6. Content Design — Deep Dive

### The One-Liner

```
Stake $DATA. Earn yield. Survive the trace scans. When others die, you profit.
```

This is the game in one sentence. Not a tagline — an operational description. It tells you:
- What you do (stake $DATA)
- What you get (yield)
- What threatens you (trace scans)
- Where yield comes from (other people dying)

Four short sentences. Four game concepts. Action, reward, threat, mechanism. It reads like a system prompt, not a marketing headline.

Every word was chosen:
- "Stake" not "deposit" — they know staking.
- "$DATA" not "tokens" — introduces the token name immediately.
- "Earn yield" not "make money" — DeFi language they understand.
- "Survive" not "avoid" — implies danger, not inconvenience.
- "trace scans" — introduces the term without explaining it. The steps below will elaborate.
- "When others die, you profit" — the hook. The thing that makes them lean forward.

### The Steps

Four steps, not six. We collapsed the original six mental-model concepts into four *actions*:

| Step | Label | Description | What It Teaches |
|------|-------|-------------|-----------------|
| 01 | CONNECT WALLET | Link your wallet to access the network. | The literal first action. Tells them what the button does. |
| 02 | JACK IN | Choose a risk level. Stake $DATA. Yield starts accumulating immediately. | Three concepts in three sentences: levels exist, staking is the entry, yield is instant. |
| 03 | SURVIVE | Periodic trace scans roll for death. Play mini-games to reduce your odds. | Two concepts: scans happen automatically, skill layer exists. |
| 04 | EXTRACT | Cash out anytime. Principal + earned yield. Or stay in and keep earning. | You're not locked in. You get back what you put in plus what you earned. Teases the greed: "or stay for more." |

**Why four, not six:**
- "Earn yield" is collapsed into Jack In ("Yield starts accumulating immediately"). It's not a separate action — it's a consequence of jacking in.
- "When others die, you profit" is in the header one-liner and expanded in the "Key Insight" section. It's not a step — it's a mechanism. Putting it as a step would be like listing "gravity works" as a step in "how to throw a ball."
- Mini-games are mentioned in step 03 but not given their own step. They're a feature of surviving, not a separate action. Giving them their own step would imply they're required (they're not).

**Why not more detail per step?**

Each step description is 1–2 lines. We could expand them — explain what risk levels are, what trace scans do in detail, what mini-games exist. But that's the FAQ's job, and the WelcomePanel's job. This panel is a *briefing*. Briefings are dense by design. If you want depth, scroll down to the FAQ.

### The Risk Levels Table

```
▌ VAULT      0% death    Safe haven
▌ MAINFRAME  2% death    Every 24h
▌ SUBNET    15% death    Every 8h
▌ DARKNET   40% death    Every 2h
▌ BLACK ICE 90% death    Every 30min
```

Three columns: Name, Death Rate, Scan Frequency. Each row has a color-coded left border (`▌`) matching the level's color from the existing design system (green, cyan, amber, orange, red).

**What we deliberately omit:**
- **APY numbers** — they're theoretical and change constantly. Including "20,000% APY" invites scrutiny of numbers we can't guarantee. The WelcomePanel shows them for aspirational effect; this panel is operational truth.
- **Min stake amounts** — important but secondary. They'll see this in the Jack In modal when they actually go to stake. Showing it here adds another column that doesn't help the "should I connect my wallet?" decision.
- **Level descriptions** — "The whale zone," "Degen territory," etc. The WelcomePanel covers this with flair. Here, just the facts.
- **Network modifier** — "More TVL = lower death rate" is a nuance for later. Not relevant to the first-time visitor deciding whether to connect.

Below the table, two lines of context:

```
Higher risk = higher yield.
Dead capital flows UP to safer levels.
```

The first line is the fundamental trade-off. The second is the cascade in one sentence — the key economic insight that makes GHOSTNET different from "just another staking protocol." It tells you that VAULT holders earn from BLACK ICE deaths. That's the "aha."

### The Key Insight Section

```
When someone gets traced, their stake doesn't vanish.
60% flows to survivors. 30% is burned forever.
You earn yield from other people dying.
```

This is the section that separates Direction A/Hybrid from Direction C. Without it, the user understands the *mechanics* (stake, scan, extract) but not the *economics* (why there's yield, where it comes from, why it's not a ponzi).

Three sentences:
1. **"Their stake doesn't vanish"** — counterintuitive. Most people assume death = total loss for everyone. This corrects that.
2. **"60% flows to survivors. 30% is burned forever."** — The cascade ratio, stripped to essentials. We omit the 10% protocol fee because it's not relevant to the user's understanding.
3. **"You earn yield from other people dying."** — The hook restated as a mechanism. Now they understand *why* the one-liner says "When others die, you profit."

### The Warning

```
⚠ High risk. You can lose everything.
  Only stake what you can afford to lose.
```

Always present. Not hidden, not dismissable. Not in a collapsible section. Not in small print. Two lines. Terminal amber color. This is a game where people can lose real money. The warning is part of the design, not an afterthought.

We say "you can lose everything" not "you may lose some funds." Because in BLACK ICE, you *can* lose everything. Honesty builds the trust that makes people actually play.

---

## 7. Content Tone

The tone is **briefing, not tutorial**. The difference:

**Tutorial tone (wrong for this):**
> "Welcome to GHOSTNET! Let's get you started. First, you'll need to connect your wallet. Click the button below to connect. Don't worry, it's easy!"

**Marketing tone (also wrong):**
> "Enter the most thrilling real-time survival experience on MegaETH. Your journey to massive yields begins with a single click."

**Briefing tone (what we want):**
> "Link your wallet to access the network."

No "let's." No "you'll need to." No exclamation marks. No superlatives. Short declarative sentences. The system is telling you what's what. Not cheerful, not cold — just clear.

This tone matches the terminal aesthetic. Terminals don't welcome you warmly. They print the facts and wait for your input.

---

## 8. Behavior Specification

### When It Appears

The GettingStartedPanel replaces `DailyOpsPanel` in the right column of the home page when `provider.currentUser` is `null` (wallet not connected).

```
if (!provider.currentUser) → show GettingStartedPanel
if (provider.currentUser)  → show DailyOpsPanel
```

The swap happens reactively — the moment they connect their wallet, the panel transitions from Getting Started to Daily Ops. No page reload. No navigation.

### Why Wallet Connection Is the Trigger (Not Position)

We considered keeping the panel visible until the user actually jacks in (has a position). But wallet connection is the better trigger:

**Once they've connected their wallet, they've taken the first action. They're engaged.** At that point:
- PositionPanel switches from "DISCONNECTED" to "NOT JACKED IN" with a "Jack In" button and their $DATA balance
- QuickActionsPanel's "Jack In" button is now enabled
- DailyOpsPanel gives them an immediate engagement hook (daily check-in, start a streak)

The system already has multiple affordances guiding them from "connected" to "jacked in." The Getting Started panel's job is to bridge the gap from "anonymous visitor" to "connected wallet." Everything after that is handled by existing components working together.

**If we kept the panel visible post-connect, we'd have three places telling the user to Jack In:** the Getting Started panel, the PositionPanel, and the QuickActionsPanel. That's redundant. Worse, the DailyOpsPanel wouldn't appear until they jack in, which means they miss the daily check-in engagement loop. DailyOps should start the moment they connect, not the moment they stake.

### Why Not Show Steps Completing Within the Panel?

We considered an alternative where the panel persists through the full onboarding:

```
State: Wallet not connected
  01 ► CONNECT WALLET    [CONNECT WALLET]
  02 ○ JACK IN
  03 ○ SURVIVE
  04 ○ EXTRACT

State: Wallet connected, no position
  01 ✓ CONNECT WALLET
  02 ► JACK IN           [JACK IN]
  03 ○ SURVIVE
  04 ○ EXTRACT

State: Jacked in → panel disappears, DailyOps takes over
```

This looks satisfying on paper but creates problems:
- **Redundant CTAs.** Connected-but-not-jacked-in state would have a Jack In button in the Getting Started panel *and* in PositionPanel *and* in QuickActionsPanel.
- **Delayed DailyOps.** The daily check-in streak — our best engagement hook — wouldn't appear until they've jacked in. That's a missed opportunity. A connected user who isn't ready to stake yet should still be able to start a streak.
- **Steps 03–04 are not completable.** "SURVIVE" and "EXTRACT" never get checkmarks. They're ongoing gameplay, not onboarding gates. Having them as future steps forever feels broken.
- **Complexity.** More states to test, more transitions to choreograph, more props to manage.

The cleanest UX: Getting Started → connect wallet → panel disappears → DailyOps appears → existing components guide them to Jack In.

---

## 9. Visual Design

### Overall Structure

```svelte
<Box title="GETTING STARTED">
  <Stack gap={4}>
    <!-- One-liner -->
    <p class="briefing-intro">...</p>

    <!-- Section: WHAT TO DO -->
    <section>
      <SectionDivider label="WHAT TO DO" />
      <ol class="steps">
        <GettingStartedStep number="01" status="current" label="CONNECT WALLET">
          Link your wallet to access the network.
          <Button variant="primary" onclick={onConnectWallet} fullWidth>
            CONNECT WALLET
          </Button>
        </GettingStartedStep>
        <GettingStartedStep number="02" status="future" label="JACK IN">
          Choose a risk level. Stake $DATA.
          Yield starts accumulating immediately.
        </GettingStartedStep>
        <GettingStartedStep number="03" status="future" label="SURVIVE">
          Periodic trace scans roll for death.
          Play mini-games to reduce your odds.
        </GettingStartedStep>
        <GettingStartedStep number="04" status="future" label="EXTRACT">
          Cash out anytime. Principal + earned yield.
          Or stay in and keep earning.
        </GettingStartedStep>
      </ol>
    </section>

    <!-- Section: RISK LEVELS -->
    <section>
      <SectionDivider label="RISK LEVELS" />
      <RiskLevelsTable />
      <p class="risk-context">
        Higher risk = higher yield.<br />
        Dead capital flows UP to safer levels.
      </p>
    </section>

    <!-- Section: THE KEY INSIGHT -->
    <section>
      <SectionDivider label="THE KEY INSIGHT" />
      <p class="key-insight">
        When someone gets traced, their stake doesn't vanish.
        60% flows to survivors. 30% is burned forever.
        You earn yield from other people dying.
      </p>
    </section>

    <!-- Warning -->
    <div class="warning" role="alert">
      <span class="warning-icon">⚠</span>
      <p>
        High risk. You can lose everything.<br />
        Only stake what you can afford to lose.
      </p>
    </div>
  </Stack>
</Box>
```

### Color Treatment

| Element | Color | Token |
|---------|-------|-------|
| Panel title | Cyan | `--color-accent` |
| One-liner text | Primary (bright green) | `--color-text-primary` |
| Section divider label | Tertiary (dim) | `--color-text-tertiary` |
| Section divider lines | Subtle border | `--color-border-subtle` |
| Current step number (`01`) | Accent (cyan) | `--color-accent` |
| Current step icon (`►`) | Accent (cyan) | `--color-accent` |
| Current step label | Primary | `--color-text-primary` |
| Current step description | Secondary | `--color-text-secondary` |
| Future step number | Muted | `--color-text-muted` |
| Future step icon (`○`) | Muted | `--color-text-muted` |
| Future step label | Tertiary | `--color-text-tertiary` |
| Future step description | Muted | `--color-text-muted` |
| Connect Wallet button | Primary variant | Accent bg, void text |
| VAULT row indicator | Profit green | `--color-profit` |
| MAINFRAME row indicator | Cyan | `--color-cyan` |
| SUBNET row indicator | Amber | `--color-amber` |
| DARKNET row indicator | Orange | `#ff6600` |
| BLACK ICE row indicator | Red | `--color-red` |
| Level name text | Primary | `--color-text-primary` (bold) |
| Death rate text | Matches level color | Per-level color |
| Frequency text | Secondary | `--color-text-secondary` |
| Risk context text | Secondary | `--color-text-secondary` |
| Key insight text | Primary | `--color-text-primary` |
| "60% flows" / "30% burned" | Accent / Amber | `--color-accent` / `--color-amber` |
| Warning text | Amber | `--color-amber` |
| Warning icon | Amber | `--color-amber` |
| Warning background | Subtle amber | `rgba(255, 170, 0, 0.05)` |
| Warning border | Amber dim | `rgba(255, 170, 0, 0.2)` |

### Typography

All monospace (IBM Plex Mono), consistent with the terminal aesthetic.

| Element | Size | Weight | Spacing |
|---------|------|--------|---------|
| One-liner | `--text-sm` | Normal | Default |
| Section divider label | `--text-xs` | Normal | `letter-spacing: wider` |
| Step number | `--text-sm` | Bold | Default |
| Step icon (► / ○) | `--text-sm` | Normal | Default |
| Step label | `--text-sm` | Bold | `letter-spacing: wide` |
| Step description | `--text-xs` | Normal | Default |
| Risk table level name | `--text-xs` | Bold | Default |
| Risk table data | `--text-xs` | Normal | Default |
| Risk context | `--text-xs` | Normal | Default |
| Key insight | `--text-xs` | Normal | Default |
| Warning | `--text-xs` | Normal | Default |

### Spacing

The panel should feel compact but breathable. Terminal output is dense but organized by whitespace.

| Between | Gap |
|---------|-----|
| Major sections (steps, risk table, key insight, warning) | `var(--space-4)` |
| Steps within the steps section | `var(--space-3)` |
| Step label and step description | `var(--space-1)` |
| Step description and CTA button | `var(--space-2)` |
| Risk table rows | `2px` (tight, like terminal output) |
| Risk table and context text | `var(--space-2)` |
| Internal padding (Box) | `padding: 3` (standard) |

### Section Dividers

Styled like terminal section headers:

```css
.section-divider {
  display: flex;
  align-items: center;
  gap: var(--space-2);
}

.section-divider::before,
.section-divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--color-border-subtle);
}

.divider-label {
  font-size: var(--text-xs);
  color: var(--color-text-tertiary);
  letter-spacing: var(--tracking-wider);
  white-space: nowrap;
}
```

This creates the `─── WHAT TO DO ───` look.

### Step Layout

Each step is a horizontal layout with the number/icon on the left and content on the right:

```css
.step {
  display: grid;
  grid-template-columns: auto auto 1fr;
  gap: var(--space-2);
  align-items: start;
}

.step-number {
  font-weight: var(--font-bold);
  min-width: 2ch;
  text-align: right;
}

.step-icon {
  min-width: 1.5ch;
}

.step-content {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}
```

The grid ensures numbers and icons align vertically across all steps.

### Risk Table Layout

Each row is a grid with a color indicator, name, death rate, and frequency:

```css
.risk-row {
  display: grid;
  grid-template-columns: 4px 1fr auto auto;
  gap: var(--space-2);
  padding: var(--space-1) var(--space-2);
  align-items: center;
}

.risk-indicator {
  width: 4px;
  height: 100%;
  border-radius: 1px;
}

.risk-name {
  font-weight: var(--font-bold);
  text-align: left;
}

.risk-death {
  text-align: center;
  min-width: 8ch;
}

.risk-frequency {
  text-align: right;
  min-width: 9ch;
}
```

This matches the existing risk level rendering in the WelcomePanel (slide 3) but in a more compact, tabular format.

### Warning Box

```css
.warning {
  display: flex;
  align-items: flex-start;
  gap: var(--space-2);
  padding: var(--space-2);
  background: rgba(255, 170, 0, 0.05);
  border: 1px solid rgba(255, 170, 0, 0.2);
  color: var(--color-amber);
  font-size: var(--text-xs);
}

.warning-icon {
  flex-shrink: 0;
}
```

Subtle amber background. Not screaming, but visible. Reads as a system warning, not a marketing disclaimer.

---

## 10. Interaction Design

### Connect Wallet Button

The button in step 01 triggers the wallet connection flow. It uses the same mechanism as the header WalletButton — opens the WalletModal.

```svelte
<Button variant="primary" onclick={onConnectWallet} fullWidth>
  CONNECT WALLET
</Button>
```

The `onConnectWallet` callback is passed as a prop from the page. This keeps the panel decoupled from wallet logic.

The button is `fullWidth` within the step content area (not the entire panel width). It's prominent but not obnoxious.

### Hover Behavior

- **Current step:** No special hover (the CTA button handles interaction)
- **Future steps:** Slight brightness increase on hover to indicate they're readable, but no click action. No cursor change.
- **Risk table rows:** No hover effects. It's reference material, not interactive.
- **Connect Wallet button:** Standard Button hover behavior (glow, slight lift)

### Keyboard

No custom keyboard shortcuts on this panel. The header keyboard hints already show `SHIFT+J` for Jack In, etc. The Connect Wallet button is focusable and activatable via Enter/Space. That's sufficient.

### Panel Transition

When the user connects their wallet, the swap from GettingStartedPanel to DailyOpsPanel should feel smooth. Svelte's `{#if}` will handle the DOM swap. No explicit transition animation needed — the content change is instantaneous and intentional. The user just clicked "Connect Wallet" and is expecting the UI to respond.

If we later add Panel enter/exit animations (from the panel-enhancement plan), a `boot` enter on the DailyOpsPanel could make the swap feel like "new system coming online."

### Mobile Behavior

On mobile (`max-width: 767px`), the right column appears first (above the feed). This means the Getting Started panel will be one of the first things a mobile user sees — which is correct. They see:

1. PositionPanel ("DISCONNECTED")
2. ModifiersPanel (empty, very small)
3. **GettingStartedPanel** ← this is what they need
4. (scroll) QuickActionsPanel, FAQPanel, etc.

The risk table should fit on mobile screens since the data is compact. At very narrow viewports (< 360px), the frequency column text may need to shrink:

```css
@media (max-width: 400px) {
  .risk-row {
    grid-template-columns: 4px 1fr auto;
    /* Drop frequency column, show only name + death rate */
  }

  .risk-frequency {
    display: none;
  }
}
```

At extremely narrow widths, we sacrifice scan frequency (the least critical column) to keep the layout clean. The user will see frequency info in the Jack In modal.

---

## 11. File Structure

```
apps/web/src/lib/features/getting-started/
├── GettingStartedPanel.svelte     ← Main panel component
├── GettingStartedStep.svelte      ← Individual step component
├── RiskLevelsTable.svelte         ← Risk level reference table
└── index.ts                       ← Barrel export
```

### Why Separate Components

- **GettingStartedStep** — Encapsulates the step state logic (current/future/complete icons, dimming, conditional CTA slot). Keeps the main panel template clean. The step component accepts a `status` prop and a `children` snippet, and handles all visual treatment internally.
- **RiskLevelsTable** — The risk levels data and rendering. Self-contained. Could be reused on the help page, in the Jack In modal, or in tooltips. Separates data from layout.

### Barrel Export

```typescript
// apps/web/src/lib/features/getting-started/index.ts
export { default as GettingStartedPanel } from './GettingStartedPanel.svelte';
```

Only the panel is exported. The sub-components are internal implementation details.

---

## 12. Integration into Home Page

### Current State (`+page.svelte`, lines 269–294)

```svelte
<div class="column column-right">
  <PositionPanel />
  <ModifiersPanel />
  <DailyOpsPanel
    progress={dailyState.progress}
    missions={dailyState.missions}
    onCheckIn={handleDailyCheckIn}
    onClaimMission={handleClaimMission}
    {checkingIn}
  />
  <div class="hide-mobile">
    <NetworkVitalsPanel />
  </div>
  <QuickActionsPanel ... />
  <FAQPanel />
</div>
```

### Target State

```svelte
<div class="column column-right">
  <PositionPanel />
  <ModifiersPanel />

  <!-- Getting Started replaces Daily Ops when not connected -->
  {#if provider.currentUser}
    <DailyOpsPanel
      progress={dailyState.progress}
      missions={dailyState.missions}
      onCheckIn={handleDailyCheckIn}
      onClaimMission={handleClaimMission}
      {checkingIn}
    />
  {:else}
    <GettingStartedPanel onConnectWallet={handleConnectWallet} />
  {/if}

  <div class="hide-mobile">
    <NetworkVitalsPanel />
  </div>
  <QuickActionsPanel ... />
  <FAQPanel />
</div>
```

### Changes to `+page.svelte`

1. Add import: `import { GettingStartedPanel } from '$lib/features/getting-started';`
2. Add handler: `function handleConnectWallet() { /* open wallet modal — same as header button */ }`
3. Wrap DailyOpsPanel/GettingStartedPanel in `{#if provider.currentUser}` conditional

**What doesn't change:**
- PositionPanel (already handles disconnected state with its own messaging)
- ModifiersPanel (already handles empty state gracefully)
- NetworkVitalsPanel, QuickActionsPanel, FAQPanel (unchanged)
- Left column (WelcomePanel, FeedPanel, GameNavigationCard, NetworkVisualization)
- All modal logic, keyboard shortcuts, daily ops state management
- No styling changes to the grid or column layout

---

## 13. Props Interface

```typescript
interface Props {
  /** Callback when Connect Wallet button is clicked */
  onConnectWallet?: () => void;
}
```

One prop. The panel manages its own content and layout. It doesn't need external data — the steps and risk levels are static content. The only dynamic behavior is the button callback.

**Why no step state props?**

The panel only appears when the wallet is disconnected. In that state, step 01 is always current and steps 02–04 are always future. There's no variation to express through props.

**Future-proofing:** If we later want to show the panel in other states (e.g., connected but not jacked in, per the "persistent checklist" alternative we rejected), we can add a `currentStep` prop without breaking existing usage. The `GettingStartedStep` component already accepts a `status` prop, so the internal machinery is ready.

---

## 14. Relationship to Other Components

### WelcomePanel (Left Column)

| Concern | WelcomePanel | GettingStartedPanel |
|---------|-------------|---------------------|
| **Purpose** | Pitch the game | Guide the user |
| **Style** | Cinematic carousel with animations | Static terminal briefing |
| **Content** | Why GHOSTNET exists, the hook, the twist, the trust | What to do, what the risks are, how it works |
| **Tone** | Aspirational — "JACK IN. DON'T GET TRACED." | Operational — "Link your wallet to access the network." |
| **Duration** | 7 slides × 7 seconds, loops forever | One screen, read once |
| **Interaction** | Auto-advancing slides, manual nav | One button (Connect Wallet) |
| **Lifecycle** | Always visible on desktop | Disappears on wallet connect |
| **Overlap** | Risk levels (slide 3), mini-games (slide 4) | Risk levels table, mini-games mentioned in step 03 |

They're complementary. WelcomePanel says "this world is worth entering." GettingStartedPanel says "here's how to enter it."

The overlap on risk levels is intentional and good. A user might see the risk levels in the carousel, think "interesting," then scroll to the Getting Started panel and see them again in a compact table they can actually study. Repetition of the most important information is a feature, not a bug.

### FAQPanel (Right Column, Below)

The FAQ handles the "I have questions" moment that comes *after* understanding the basics. It covers 18 detailed topics — cascade formula, burn mechanics, crew bonuses, culling, etc. The Getting Started panel doesn't try to explain everything. It gives just enough to take action, knowing the FAQ is below for depth.

**Important:** The FAQ is below the Getting Started panel in the right column. A user who finishes reading Getting Started and wants more detail can scroll down to the FAQ without navigating anywhere. The information architecture flows: briefing → action → deep reference.

### PositionPanel (Right Column, Above)

PositionPanel shows "DISCONNECTED" with "Connect wallet to view your status." It's a status display, not a guide. These two panels have different jobs:
- PositionPanel says "you're not connected" (status)
- GettingStartedPanel says "here's why you should connect and what happens when you do" (guide)

They're both in the right column, PositionPanel above, GettingStartedPanel below. The visual flow is: "You're disconnected" → "Here's what to do about it."

---

## 15. Decisions and Alternatives

### Decision: Four Steps, Not Six

**Alternative considered:** Six steps matching the six mental-model concepts (Connect, Choose Level, Jack In, Earn Yield, Survive Scans, Extract).

**Why rejected:** "Choose Level" and "Earn Yield" aren't separate actions. Level choice is part of jacking in. Yield earning happens automatically. Having six steps makes the game sound more complex than it is. Four steps = four verbs (connect, stake, survive, extract).

### Decision: One CTA Button, Not Multiple

**Alternative considered:** A "Learn More" button linking to the help page, or an "Explore Levels" button opening a modal.

**Why rejected:** One action per panel. The user should do exactly one thing: connect their wallet. Multiple buttons create decision paralysis. "What should I click first?" is the wrong question. There is only Connect Wallet.

### Decision: Box Title "GETTING STARTED", Not "ACCESS PROTOCOL"

**Alternative considered:** In-world naming like "NETWORK ACCESS PROTOCOL" or "OPERATOR BRIEFING" or "SYSTEM INITIALIZATION."

**Why rejected:** These are cooler but less clear. A first-time visitor needs to instantly know "this panel helps me get started." The terminal aesthetic comes from the Box component styling, the monospace text, the section dividers. The title should be functional, not thematic. "GETTING STARTED" is universal.

**Trade-off acknowledged:** Less immersive. But clarity beats immersion for an onboarding component. The rest of the page is immersive. This one panel is allowed to be plain.

### Decision: Include "The Key Insight" Section

**Alternative considered:** Omit it (Direction C approach). The one-liner mentions "when others die, you profit" — isn't that enough?

**Why included:** The one-liner *states* the mechanism. The Key Insight section *explains* it. "60% flows to survivors. 30% is burned forever." — this is the moment where the economics click. Without it, users connect, jack in, see yield accumulating, but don't understand *why*. Understanding why is what turns a casual experiment into a committed position.

### Decision: Static Risk Table, Not Interactive Level Selector

**Alternative considered:** A clickable risk table where you can select a level before connecting, so the Jack In modal pre-fills your choice.

**Why rejected:** Over-engineering for an onboarding panel. The user can't jack in until they connect. Pre-selecting a level before connecting creates state that needs to be preserved across the wallet connection flow. The Jack In modal already has a level selector with more detail. Keep it simple.

---

## 16. Edge Cases

| Scenario | Behavior |
|----------|----------|
| User connects wallet while reading | Panel disappears, DailyOpsPanel appears. Svelte reactive swap — no flash, no animation (unless Panel enter effects are enabled). |
| User disconnects wallet after connecting | GettingStartedPanel reappears. All steps reset to initial state (01 current, 02–04 future). |
| User has wallet but no $DATA balance | Not this panel's concern. The panel's job is to get them to connect. Jack In modal handles insufficient balance with a clear message. |
| User has wallet but wrong network | Not this panel's concern. Wallet connection flow handles network switching. |
| Mobile viewport (< 768px) | Right column renders first (above feed). Getting Started is visible immediately — correct positioning. |
| Very narrow viewport (< 360px) | Risk table drops the frequency column to fit. Name + death rate is sufficient at this width. |
| Screen reader | Steps are rendered as an ordered list (`<ol>`). Button has accessible label. Warning has `role="alert"`. Section dividers use `<hr>` with `aria-label`. |
| `prefers-reduced-motion` | No impact — this panel has no animations. Pure static content with one button. |
| Settings: effects disabled | No impact — panel has no effects to disable. |
| User refreshes page while connected | DailyOpsPanel shows (wallet stays connected). Getting Started panel doesn't flash. |
| SSR rendering | All content is static. No hydration issues. Button callback attaches on mount. |

---

## 17. What This Is NOT

- **Not a tutorial.** No step-by-step walkthrough with tooltips, arrows, or a "next" button. Users are crypto-native. They know how to use a dApp. They don't need hand-holding — they need information.
- **Not a marketing page.** The WelcomePanel handles the pitch. This is operational. No superlatives, no hype, no promises.
- **Not comprehensive.** It doesn't explain the cascade formula, the burn engines, crew mechanics, hack run node types, PvP duels, the system reset timer, or the culling mechanism. Those are discoverable through play and the FAQ.
- **Not persistent.** It appears while disconnected and disappears on wallet connect. It doesn't follow the user around or nag them.
- **Not blocking.** The user can ignore it entirely and connect via the header WalletButton. The panel is helpful, not required. It's information, not a gate.
- **Not animated.** In a game full of CRT scanlines, matrix rain, glitch effects, and flickering terminals, this panel is deliberately still. It's a document. Documents don't flicker.

---

## 18. Implementation Notes

### Component Dependencies

- `Box` from `$lib/ui/terminal` — container
- `Button` from `$lib/ui/primitives` — Connect Wallet CTA
- `Stack` from `$lib/ui/layout` — vertical spacing

No new dependencies. All existing design system components. No new imports to the design system.

### Data

All content is hardcoded. No API calls, no provider data, no reactive state beyond what Svelte gives us for free.

The risk levels could be imported from `LEVEL_CONFIG` in `$lib/core/types` for consistency. The display format is different (we show scan frequency as "Every 24h", not a millisecond interval), so the connection is:

```typescript
import { LEVEL_CONFIG } from '$lib/core/types';

// Use LEVEL_CONFIG for level names and ordering
// Hardcode display strings since they're human-readable summaries
const RISK_LEVELS = [
  { level: 1, name: 'VAULT',     death: '0% death',  freq: 'Safe haven' },
  { level: 2, name: 'MAINFRAME', death: '2% death',  freq: 'Every 24h' },
  { level: 3, name: 'SUBNET',    death: '15% death', freq: 'Every 8h' },
  { level: 4, name: 'DARKNET',   death: '40% death', freq: 'Every 2h' },
  { level: 5, name: 'BLACK ICE', death: '90% death', freq: 'Every 30min' },
];
```

### Testing

```
GettingStartedPanel.svelte.test.ts
├── renders panel with title "GETTING STARTED"
├── renders one-liner briefing text
├── renders 4 steps with correct labels (CONNECT WALLET, JACK IN, SURVIVE, EXTRACT)
├── step 01 shows current state (► icon, accent-colored number)
├── steps 02-04 show future state (○ icon, dimmed text)
├── renders Connect Wallet button in step 01
├── calls onConnectWallet when button clicked
├── renders risk levels table with all 5 levels
├── each risk level has colored indicator
├── renders "The Key Insight" section with cascade explanation
├── renders warning with ⚠ icon and amber styling
├── warning has role="alert" for accessibility
├── steps render as ordered list (<ol>) for screen readers
├── no console errors or warnings on mount

GettingStartedStep.svelte.test.ts
├── renders current state with ► icon and bright styling
├── renders future state with ○ icon and dimmed styling
├── renders complete state with ✓ icon and green styling
├── renders children content (description text)
├── renders CTA slot when provided (button)

RiskLevelsTable.svelte.test.ts
├── renders 5 level rows
├── each row has name, death rate, frequency
├── each row has color-coded indicator matching level
├── renders context text below table
```

### Performance

No performance concerns. The panel renders static content with one reactive button. No timers, no intervals, no subscriptions, no animations, no WebSocket connections, no derived state.

---

## 19. Success Criteria

The panel is successful if:

1. **Comprehension.** A crypto-native user who has never seen GHOSTNET can read this panel in under 60 seconds and accurately explain to someone else what the game is and how to start.
2. **Action clarity.** The Connect Wallet button is the single most obvious action on the panel. No user should wonder "what do I click?"
3. **Transition.** After connecting, the swap to DailyOpsPanel feels natural — not jarring, not confusing. The user doesn't think "where did that panel go?"
4. **Fit.** The panel fits on one screen (no scrolling needed) on desktop at 1024px+ width in the right column.
5. **Mobile first.** On mobile, the panel is the first substantive content the user sees (right column renders first). It's readable and the button is tappable without scrolling.
6. **Informed decision.** The risk levels table gives enough information that when the user later opens the Jack In modal, they already know which level they're interested in.
7. **Economics click.** The "Key Insight" section causes at least some users to go "oh — so yield comes from other people dying?" That understanding is the gateway to engagement.

---

## 20. Future Considerations

- **Expanded onboarding flow:** If we later want a multi-step onboarding (connect → get $DATA → jack in → first scan), we could evolve this panel to persist through those steps. The `GettingStartedStep` component already supports `status: 'complete'` for this purpose. Adding a `currentStep` prop to the panel would enable it without restructuring.
- **Returning user detection:** If a user has previously jacked in (detectable via localStorage or on-chain history), we could skip this panel entirely even before wallet connection. Show them a "Welcome Back" panel instead, or just DailyOps with a "Connect to Resume" message. Not needed for MVP.
- **Non-crypto-native flow:** This plan assumes crypto-native users. If we later need to onboard users who don't have wallets or MegaETH ETH, the panel would need additional prerequisite steps (install wallet, bridge ETH, get $DATA). These would be separate steps at the top, pushing the current steps down. The architecture supports this — just add more `GettingStartedStep` entries.
- **Localization:** All strings are hardcoded English. If we ever localize, these would move to a strings file. Not a concern now.
- **A/B testing:** The one-liner and step descriptions are testable. Different wordings could affect conversion from "visitor" to "connected wallet." Track wallet connection rate as the conversion event. The "Key Insight" section is the most testable — does including the cascade explanation increase or decrease conversion?
- **Analytics.** Track: (1) how long users spend on the page before connecting, (2) whether they scroll to the FAQ before connecting, (3) whether they click Connect Wallet from this panel vs. the header button. This data tells us whether the panel is doing its job.
