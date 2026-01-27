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

The DailyOpsPanel is the worst offender. It speaks the language of a returning operator to someone who doesn't know what an operator *is*. It assumes familiarity when there is none.

The left column's WelcomePanel carousel handles the *pitch* — why GHOSTNET exists, how the game works, the risk levels, the trust model. It's cinematic and aspirational. What's missing is the *operational counterpart*: not "here's why this world is cool" but "here's what to do to enter it."

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

---

## 3. Design Intent

### What It Should Feel Like

Booting into a new system for the first time. You SSH into a box and the first thing it prints is a briefing — not a tutorial, not a walkthrough, not a marketing carousel. A single, scannable document that tells you everything you need to know to start operating.

Like a `README`. Like a `--help` output. Like the message-of-the-day that greets you when you log into a server.

The WelcomePanel is the *trailer*. This panel is the *field manual*.

### Design Principles

1. **Scannable, not scrollable.** The entire briefing should be visible without scrolling on desktop. If it doesn't fit in one screen, it's too long.

2. **Operational, not aspirational.** No "imagine a world where..." — just "here's what you do." The WelcomePanel handles the story. This handles the steps.

3. **Stateful, not static.** The panel knows where the user is in their journey and highlights the current step. Connect Wallet has a button. Jack In has a button. Completed steps check off.

4. **Terminal-native.** Box component, monospace, terminal aesthetic. But the *content* is human-readable plain language — clarity dressed in terminal clothing.

5. **Self-destructing.** Once the user has connected their wallet and jacked in, this panel's job is done. DailyOpsPanel takes its place. The user has graduated from "getting started" to "operating."

---

## 4. Behavior Specification

### When It Appears

The GettingStartedPanel replaces `DailyOpsPanel` in the right column of the home page when `provider.currentUser` is `null` (wallet not connected).

```
if (!provider.currentUser) → show GettingStartedPanel
if (provider.currentUser)  → show DailyOpsPanel
```

The swap happens reactively — the moment they connect their wallet, the panel transitions from Getting Started to Daily Ops. No page reload. No navigation.

### Why Wallet Connection Is the Trigger (Not Position)

Once they've connected their wallet, they've taken the first action. They're engaged. At that point:
- PositionPanel shows "NOT JACKED IN" with a "Jack In" button and their balance
- QuickActionsPanel's "Jack In" button is now enabled
- DailyOpsPanel gives them something to *do* immediately (check in, start a streak)

The system already guides them from "connected" to "jacked in" through multiple affordances. The Getting Started panel's job is to get them from "anonymous visitor" to "connected wallet." Everything after that is handled by existing components.

### What It Shows

The panel has two sections: **Active Steps** (dynamic, stateful) and **Quick Reference** (static, informational).

---

## 5. Content Design

### The Full Briefing

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
║  VAULT      0% death    Safe haven               ║
║  MAINFRAME  2% death    Every 24h                ║
║  SUBNET    15% death    Every 8h                 ║
║  DARKNET   40% death    Every 2h                 ║
║  BLACK ICE 90% death    Every 30min              ║
║                                                  ║
║  Higher risk = higher yield.                     ║
║  Dead capital flows UP to safer levels.          ║
║                                                  ║
║  ─────────────────────────────────────────────── ║
║  ⚠ High risk. You can lose everything.           ║
║    Only stake what you can afford to lose.       ║
╚══════════════════════════════════════════════════╝
```

### Section-by-Section Breakdown

#### The One-Liner (Header)

```
Stake $DATA. Earn yield. Survive the trace scans. When others die, you profit.
```

This is the game in one sentence. Not a tagline — an operational description. It tells you:
- What you do (stake $DATA)
- What you get (yield)
- What threatens you (trace scans)
- Where yield comes from (other people dying)

Every word carries weight. No filler.

#### The Steps (Active Section)

Four steps. Not six — we collapsed the original six concepts into the four actions a user actually takes:

| Step | Label | Description | Why This Step |
|------|-------|-------------|---------------|
| 01 | CONNECT WALLET | Link your wallet to access the network. | The literal first action. Has a CTA button. |
| 02 | JACK IN | Choose a risk level. Stake $DATA. Yield starts accumulating immediately. | The core action. Tells them it's immediate. |
| 03 | SURVIVE | Periodic trace scans roll for death. Play mini-games to reduce your odds. | The risk. Introduces scans and the skill layer in one line. |
| 04 | EXTRACT | Cash out anytime. Principal + earned yield. Or stay in and keep earning. | The exit. Tells them they're not locked in, and teases the greed. |

**Why four, not more:**
- "Earn yield" is implicit in Jack In ("Yield starts accumulating immediately")
- "When others die, you profit" is in the header one-liner — it's the cascade concept, but we don't name it here. Naming it would add jargon to a panel meant to remove jargon.
- Mini-games are mentioned in step 3 but not given their own step — they're a feature of surviving, not a separate action.

#### Step States

Each step has a visual state based on user progress:

| State | Icon | Visual Treatment | When |
|-------|------|------------------|------|
| **Current** | `►` | Bright text, accent-colored step number, CTA button visible | This is what to do next |
| **Future** | `○` | Dimmed text, muted step number | Haven't reached this yet |
| **Complete** | `✓` | Green check, text at normal brightness | Already done |

Since this panel only shows when wallet is disconnected, the states in practice are:

- Step 01: Always **current** (with Connect Wallet button)
- Steps 02-04: Always **future** (dimmed)

Once wallet connects, the panel disappears entirely. We never need to show step 01 as complete within this panel — that transition is handled by the panel swap to DailyOps.

**Why not show steps completing within the panel?**

We considered keeping the panel visible after wallet connection (showing step 01 as ✓, step 02 as current with a Jack In button). But this creates a worse experience:
- PositionPanel already shows "NOT JACKED IN" with a Jack In button and the user's balance
- QuickActionsPanel already has an enabled Jack In button
- Having a *third* Jack In button in the Getting Started panel would be redundant
- DailyOpsPanel gives them an immediate engagement hook (daily check-in) that's more valuable than a checklist

The cleanest UX: Getting Started → connect wallet → panel disappears → DailyOps appears → existing components guide them to Jack In.

#### The Risk Levels Table (Reference Section)

```
VAULT      0% death    Safe haven
MAINFRAME  2% death    Every 24h
SUBNET    15% death    Every 8h
DARKNET   40% death    Every 2h
BLACK ICE 90% death    Every 30min
```

Three columns: Name, Death Rate, Scan Frequency. That's all they need.

**What we deliberately omit:**
- APY numbers — they're theoretical and change constantly. Including them invites scrutiny of numbers we can't guarantee.
- Min stake amounts — important but secondary. They'll see this in the Jack In modal.
- Level descriptions — "The whale zone," "Degen territory," etc. The WelcomePanel covers this. Here, just the facts.

Below the table, two lines of context:
- "Higher risk = higher yield." — The fundamental trade-off.
- "Dead capital flows UP to safer levels." — The cascade in one sentence. This is the key insight that makes the game theory click: whales earn from degen deaths.

#### The Warning

```
⚠ High risk. You can lose everything.
  Only stake what you can afford to lose.
```

Always present. Not hidden, not dismissable. Two lines. Terminal amber color. This is a game where people can lose real money. The warning is part of the design, not an afterthought.

---

## 6. Visual Design

### Component Structure

```svelte
<Box title="GETTING STARTED">
  <!-- One-liner -->
  <p class="briefing-intro">
    Stake $DATA. Earn yield. Survive the trace scans.
    When others die, you profit.
  </p>

  <!-- Section divider -->
  <div class="section-divider">
    <span class="divider-label">WHAT TO DO</span>
  </div>

  <!-- Steps -->
  <div class="steps">
    <Step number="01" status="current" label="CONNECT WALLET">
      Link your wallet to access the network.
      <Button>CONNECT WALLET</Button>
    </Step>
    <Step number="02" status="future" label="JACK IN">
      Choose a risk level. Stake $DATA.
      Yield starts accumulating immediately.
    </Step>
    <Step number="03" status="future" label="SURVIVE">
      Periodic trace scans roll for death.
      Play mini-games to reduce your odds.
    </Step>
    <Step number="04" status="future" label="EXTRACT">
      Cash out anytime. Principal + earned yield.
      Or stay in and keep earning.
    </Step>
  </div>

  <!-- Section divider -->
  <div class="section-divider">
    <span class="divider-label">RISK LEVELS</span>
  </div>

  <!-- Risk table -->
  <div class="risk-table">
    <!-- 5 rows, color-coded by level -->
  </div>

  <p class="risk-context">
    Higher risk = higher yield.
    Dead capital flows UP to safer levels.
  </p>

  <!-- Warning -->
  <div class="warning">
    ⚠ High risk. You can lose everything.
    Only stake what you can afford to lose.
  </div>
</Box>
```

### Color Treatment

| Element | Color | Token |
|---------|-------|-------|
| Panel title | Cyan | `--color-accent` |
| One-liner text | Primary (bright green) | `--color-text-primary` |
| Section divider label | Tertiary (dim) | `--color-text-tertiary` |
| Current step number | Accent (cyan) | `--color-accent` |
| Current step label | Primary | `--color-text-primary` |
| Current step description | Secondary | `--color-text-secondary` |
| Future step number | Muted | `--color-text-muted` |
| Future step label | Tertiary | `--color-text-tertiary` |
| Future step description | Muted | `--color-text-muted` |
| Connect Wallet button | Primary variant | Standard `Button` primary |
| VAULT row | Profit green | `--color-profit` |
| MAINFRAME row | Cyan | `--color-cyan` |
| SUBNET row | Amber | `--color-amber` |
| DARKNET row | Orange | `#ff6600` (matches existing level colors) |
| BLACK ICE row | Red | `--color-red` |
| Risk context text | Secondary | `--color-text-secondary` |
| Warning text | Amber | `--color-amber` |
| Warning icon | Amber | `--color-amber` |

### Typography

All monospace (IBM Plex Mono), consistent with the terminal aesthetic.

| Element | Size | Weight |
|---------|------|--------|
| One-liner | `--text-sm` | Normal |
| Section divider label | `--text-xs` | Normal, `letter-spacing: wider` |
| Step number | `--text-sm` | Bold |
| Step label | `--text-sm` | Bold |
| Step description | `--text-xs` | Normal |
| Risk table entries | `--text-xs` | Normal (name bold) |
| Risk context | `--text-xs` | Normal |
| Warning | `--text-xs` | Normal |

### Spacing

The panel should feel compact but breathable. Terminal output is dense but organized.

- Steps: `gap: var(--space-3)` between steps
- Sections: `gap: var(--space-4)` between major sections
- Risk table rows: `gap: 2px` (tight, like a real terminal table)
- Internal padding: Standard Box padding (`padding: 3`)

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

This creates the `─── WHAT TO DO ───` look from the wireframe.

---

## 7. Interaction Design

### Connect Wallet Button

The button in step 01 triggers the wallet connection modal (same as the header wallet button). It uses the existing `WalletModal` component.

```svelte
<Button variant="primary" onclick={onConnectWallet} fullWidth>
  CONNECT WALLET
</Button>
```

The `onConnectWallet` callback is passed as a prop from the page. This keeps the panel decoupled from wallet logic.

### Hover Behavior

- Future steps: slight brightness increase on hover to indicate they're readable, but no click action
- Risk table rows: no hover effects (it's reference material, not interactive)
- Connect Wallet button: standard Button hover behavior

### Keyboard

No custom keyboard shortcuts on this panel. The Connect Wallet button is focusable and activatable via Enter/Space. That's sufficient.

### Mobile Behavior

On mobile (`max-width: 767px`), the right column appears first (above the feed). This means the Getting Started panel will be one of the first things a mobile user sees — which is correct.

The risk table may need to adapt:

```css
/* Mobile: stack level info vertically if needed */
@media (max-width: 400px) {
  .risk-row {
    /* Reduce padding, allow wrapping */
  }
}
```

But the three-column layout (name, death%, frequency) should fit on most mobile screens since the data is compact.

---

## 8. File Structure

```
apps/web/src/lib/features/getting-started/
├── GettingStartedPanel.svelte     ← Main panel component
├── GettingStartedStep.svelte      ← Individual step component
├── RiskLevelsTable.svelte         ← Risk level reference table
└── index.ts                       ← Barrel export
```

### Why Separate Components

- **GettingStartedStep** — Encapsulates the step state logic (current/future/complete icons, dimming). Reusable if we ever need steps elsewhere. Keeps the main panel template clean.
- **RiskLevelsTable** — The risk levels data and rendering. Could be reused on the help page or in tooltips. Separates data from layout.

### Barrel Export

```typescript
// apps/web/src/lib/features/getting-started/index.ts
export { default as GettingStartedPanel } from './GettingStartedPanel.svelte';
```

---

## 9. Integration into Home Page

### Current State (`+page.svelte`)

```svelte
<!-- Right Column (lines 269-294) -->
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
<!-- Right Column -->
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

1. Import `GettingStartedPanel` from `$lib/features/getting-started`
2. Add `handleConnectWallet` function that opens the wallet modal (same logic as header button)
3. Wrap DailyOpsPanel/GettingStartedPanel in `{#if provider.currentUser}` conditional

**What doesn't change:**
- PositionPanel (already handles disconnected state)
- ModifiersPanel (already handles empty state)
- NetworkVitalsPanel, QuickActionsPanel, FAQPanel (unchanged)
- Left column (WelcomePanel, FeedPanel, etc.)
- All modal logic, keyboard shortcuts, daily ops state management

---

## 10. Props Interface

```typescript
interface Props {
  /** Callback when Connect Wallet button is clicked */
  onConnectWallet?: () => void;
}
```

That's it. One prop. The panel manages its own content and layout. It doesn't need external data — the steps and risk levels are static content. The only dynamic behavior is the button callback.

**Why no step state props?**

The panel only appears when the wallet is disconnected. In that state, step 01 is always current and steps 02-04 are always future. There's no variation to express through props. If we later want to show the panel in other states (e.g., connected but not jacked in), we can add a `currentStep` prop without breaking existing usage.

---

## 11. Relationship to Other Components

### WelcomePanel (Left Column)

| Concern | WelcomePanel | GettingStartedPanel |
|---------|-------------|---------------------|
| Purpose | Pitch the game | Guide the user |
| Style | Cinematic carousel | Static briefing |
| Content | Why GHOSTNET exists | What to do next |
| Tone | Aspirational | Operational |
| Duration | 7 slides × 7 seconds | One screen, read once |
| Lifecycle | Always visible (desktop) | Disappears on wallet connect |

They're complementary. WelcomePanel says "this world is worth entering." GettingStartedPanel says "here's how to enter it."

### FAQPanel (Right Column, Below)

FAQPanel handles the "I have questions" moment that comes *after* the user understands the basics. It covers 18 detailed topics. The Getting Started panel doesn't try to explain everything — it gives just enough for the user to take action, knowing the FAQ is below if they want depth.

### PositionPanel (Right Column, Above)

PositionPanel shows "DISCONNECTED" with "Connect wallet to view your status." It's a status display, not a guide. The Getting Started panel is the guide that explains *why* they should connect and *what happens after*.

---

## 12. Content Tone

The tone is **briefing, not tutorial**. The difference:

**Tutorial tone (wrong for this):**
> "Welcome to GHOSTNET! Let's get you started. First, you'll need to connect your wallet. Click the button below to connect..."

**Briefing tone (what we want):**
> "Link your wallet to access the network."

No "let's." No "you'll need to." No exclamation marks. Short declarative sentences. The system is telling you what's what. Not cheerful, not cold — just clear.

The one-liner is the most carefully worded piece:

> "Stake $DATA. Earn yield. Survive the trace scans. When others die, you profit."

Four short sentences. Four game concepts. Action, reward, threat, mechanism. It reads like a system prompt, not a marketing headline.

---

## 13. Edge Cases

| Scenario | Behavior |
|----------|----------|
| User connects wallet while reading | Panel disappears, DailyOpsPanel appears. Svelte reactive swap — no flash. |
| User disconnects wallet after connecting | GettingStartedPanel reappears. Steps reset to initial state. |
| User has wallet but no $DATA balance | Not this panel's concern. Jack In modal handles insufficient balance. |
| Mobile viewport (< 768px) | Right column renders first (above feed). Getting Started is visible immediately. |
| Very narrow viewport (< 360px) | Risk table may need font-size reduction. Test and adjust. |
| Screen reader | Steps are an ordered list (`<ol>`). Button is labeled. Warning has `role="alert"`. |
| `prefers-reduced-motion` | No animations in this panel (it's static content). No impact. |
| Settings: effects disabled | No impact (panel has no effects). |

---

## 14. What This Is NOT

- **Not a tutorial.** No step-by-step walkthrough with tooltips and arrows. Users are crypto-native. They know how to use a dApp.
- **Not a marketing page.** The WelcomePanel handles the pitch. This is operational.
- **Not comprehensive.** It doesn't explain the cascade formula, the burn engines, crew mechanics, or hack runs. Those are discoverable through play and the FAQ.
- **Not persistent.** It appears once (per session, while disconnected) and disappears. It doesn't follow the user around.
- **Not blocking.** The user can ignore it entirely and connect via the header button. The panel is helpful, not required.

---

## 15. Implementation Notes

### Component Dependencies

- `Box` from `$lib/ui/terminal` — container
- `Button` from `$lib/ui/primitives` — Connect Wallet CTA
- `Stack` from `$lib/ui/layout` — vertical spacing

No new dependencies. All existing design system components.

### Data

All content is hardcoded. No API calls, no provider data, no reactive state beyond what Svelte gives us for free. The risk levels could be imported from `LEVEL_CONFIG` in `$lib/core/types` for consistency, but the display format is different enough (we show scan frequency, not death rate as a decimal) that hardcoding may be cleaner.

**Decision:** Import level names from `LEVEL_CONFIG` to stay in sync. Hardcode the display strings ("0% death", "Every 24h") since they're human-readable summaries, not raw data.

### Testing

```
GettingStartedPanel.svelte.test.ts
├── renders panel with title "GETTING STARTED"
├── renders one-liner briefing text
├── renders 4 steps with correct labels
├── step 01 shows as current (► icon, bright text)
├── steps 02-04 show as future (○ icon, dimmed text)
├── renders Connect Wallet button
├── calls onConnectWallet when button clicked
├── renders risk levels table with 5 levels
├── renders warning text
├── is accessible (ordered list, button label, warning role)
```

### Performance

No performance concerns. The panel renders static content with one reactive button. No timers, no intervals, no subscriptions, no animations.

---

## 16. Success Criteria

The panel is successful if:

1. A crypto-native user who has never seen GHOSTNET can read it in under 30 seconds and understand what the game is and what to do next.
2. The Connect Wallet button is the single most obvious action on the panel.
3. After connecting, the transition to DailyOpsPanel feels natural — not jarring, not confusing.
4. The panel fits on one screen (no scrolling) on desktop at 1024px+ width.
5. On mobile, the panel is the first substantive content the user sees (right column renders first).
6. The risk levels table gives enough information to make an informed choice about which level to pick — without overwhelming.

---

## 17. Future Considerations

- **Expanded onboarding flow:** If we later want a multi-step onboarding (connect → get $DATA → jack in → first scan), we could evolve this panel to persist through those steps. The `currentStep` prop would enable this without restructuring.
- **Returning user detection:** If a user has previously jacked in (detectable via localStorage or on-chain history), we could skip this panel entirely even before wallet connection. Not needed for MVP.
- **Localization:** All strings are hardcoded English. If we ever localize, these would move to a strings file. Not a concern now.
- **A/B testing:** The one-liner and step descriptions are testable. Different wordings could affect conversion from "visitor" to "connected wallet." Track wallet connections as the conversion event.
