# Helium Hustle — System Specifications

This document specifies the mechanical design of each game system: how it works, 
why, and what it interacts with. For exact numbers (costs, rates, thresholds), see 
`handoff_constants.md` (auto-generated from JSON ground truth).

---

## Buildings

### Purchase & Cost Scaling
`base_cost × pow(scaling, purchased_count) × ideology_cost_mult`

Where `purchased_count = max(0, owned_count - bonus_count)` — free buildings from 
persistent projects or achievements don't inflate cost curves. 
`ideology_cost_mult = pow(0.97, rank)` for buildings with an aligned ideology axis.

### Enable/Disable
Each building type tracks `active_count` and `owned_count`. Only active buildings 
produce, consume, and grant effects. Disabled buildings still occupy land.

### Sell
Sell 1 or Sell All (double-click confirmation). Refunds land only, no credit refund.

### Building Processing: Multi-Pass Resolution
Buildings are processed using iterative multi-pass resolution. No hardcoded 
processing order based on upkeep presence — the multi-pass system handles 
dependencies automatically.

```
Phase 1 — Full production attempts (iterative):
  a. For each building (definition order from buildings.json):
     - Compute total production and upkeep for active_count units
     - If building can pay full upkeep (or has no upkeep): consume inputs, 
       produce outputs, done
     - Otherwise: add to retry queue
  b. If any building succeeded in this pass, repeat (a) with the retry queue
     (preserving definition order)
  c. Stop when a full pass produces zero successes

Phase 2 — Partial production (single pass):
  For each building still in the retry queue (definition order):
    - Capacity fraction = min(available_i / needed_i) for all upkeep resources
    - If fraction > 0: consume (upkeep × fraction), produce (output × fraction)
    - If fraction == 0: no activity
    - Mark as input_starved in building_stall_status
```

Buildings with no upkeep (e.g., Solar Panel) trivially succeed in Phase 1 — no 
special code path needed.

### Floating Point Epsilon
Phase 1 affordability checks use `RESOURCE_EPSILON = 0.001` tolerance to prevent 
false stalls from floating point precision errors. A building can pay its upkeep 
if `available >= needed - RESOURCE_EPSILON`. The actual consumption still uses the 
exact `needed` value. Any resulting tiny negative resource values are handled by 
the end-of-tick clamp to 0.

### No Output-Cap Skip for Buildings
Buildings always produce, even when their output resources are at storage cap. 
Excess production is clamped at end of tick and tracked as overflow (waste). This 
avoids cascading edge cases where skipping one building changes resource 
availability for others.

### End-of-Tick Clamp & Overflow Tracking
After ALL building and command processing, a single clamp pass runs:
- For each capped resource: if current > cap, record overflow = current - cap, 
  set current = cap.
- If current < 0 (rare transient from epsilon-tolerance consumption), clamp to 0.
- Accumulate overflow into per-resource rolling averages for Stats display.

GameState fields:
- `overflow_this_tick: Dictionary` — resource_id → float, reset each tick
- `overflow_rolling_avg: Dictionary` — resource_id → float, rolling average

This is the ONLY place resources are clamped to storage caps (except boredom's 
0–1000 range which triggers forced retirement).

### Partial Production (Input-Constrained)
Buildings with insufficient upkeep resources run at reduced capacity in Phase 2. 
Capacity fraction = min(available_i / needed_i) across all upkeep resources. All 
inputs consumed and outputs produced are scaled by this fraction. A fraction of 0 
means no activity. Buildings running below 100% are flagged `input_starved` in 
`building_stall_status`.

### Building Stall Tracking
`GameState.building_stall_status` tracks per-building stall state each tick. Two 
types: `input_starved` (ran at partial capacity in Phase 2) and `output_capped` 
(all outputs at or above cap at start of tick — informational only, building still 
produces).

### Building Card Status Row
Building cards always reserve vertical space for the status row (stall indicators) 
to prevent height flickering when statuses appear/disappear.

### Bonus Building Cost Scaling
Buildings granted free by persistent projects (e.g., Foundation Grant) or 
achievements (e.g., Powerhouse) track `bonus_count` separately. Cost scaling uses 
`max(0, owned_count - bonus_count)`. Bonus buildings are granted on run start, 
with `owned_count`, `active_count`, and `bonus_count` all incremented. Storage 
caps are recalculated after granting.

### Building Alignment
Buildings are assigned to ideology axes. Aligned buildings get per-rank cost discount 
`pow(0.97, rank)`. Nationalist: Launch Pad, Arbitrage Engine, Microwave Receiver. 
Humanist: Data Center, Battery. Rationalist: Fabricator, Research Lab.

Ideology alignment labels are hidden on building cards until the Ideologies nav 
panel is unlocked.

### Unlock Requirements
Buildings with a non-empty `requires` field or gated by `enable_building` event 
effects are not purchasable until requirements are met. The `requires` field 
supports `building_id` (own at least 1) and `building_id:N` (own at least N). 
GameSimulation enforces this (defense in depth).

### Building Visibility (Progressive Disclosure)
A building is visible if:
1. It has no `requires` field AND is not gated by an `enable_building` event 
   effect → always visible
2. Its `requires` building-prerequisite condition is currently satisfied → visible
3. Its ID is in `career_state.lifetime_owned_building_ids` AND the building is 
   NOT gated behind an `enable_building` event effect → visible (lifetime override 
   for building prereqs only, not for research/event gates)
4. Its `enable_building` event gate has been satisfied (event has fired this run 
   or unlock effects re-applied from `seen_event_ids` on run start) → visible

**Key rule:** `lifetime_owned_building_ids` overrides building-prerequisite gates 
(like "Smelter requires Excavator") but does NOT override research or event gates 
(like Ice Extractor/Electrolysis Plant behind Propellant Synthesis research chain). 
The player must progress through research/event chains again each run.

Category headers hide when they contain zero visible buildings. The "Show All Cards" 
debug toggle overrides all visibility gating.

Notable requires gates: Research Lab requires `data_center:2` (player starts 
with 1). Smelter requires Regolith Excavator. Fabricator requires Smelter.

---

## Resource Flow — Arc 1 Economy

### Raw Extraction (both consume energy)
- Regolith Excavator — energy → regolith
- Ice Extractor — energy → ice

### Processing (each has one clear purpose)
- Refinery — regolith + energy → He-3
- Smelter — regolith + energy → titanium
- Fabricator — regolith + energy (lots) → circuit boards
- Electrolysis Plant — ice + energy → propellant (requires research unlock)

### Dependency Structure
Two independent extraction chains (regolith and ice) feed into four processing 
paths, all competing for energy. Regolith feeds three competing uses (He-3, 
titanium, circuits). Ice feeds propellant. Energy is the universal bottleneck.

### Tradeable Goods (4 types)
He-3 (core product, demand-sensitive), Titanium (mid-tier, demand spikes), Circuit 
Boards (late Arc 1, energy-hungry, highest value/unit), Propellant (dual purpose — 
trade good + launch fuel).

### Additional Resources
- Science — produced by Research Lab, spent on research. Rationalist ideology boosts 
  production via `pow(1.05, rank)`.
- Land — purchasable with escalating cost. Base 15 credits, 1.5x scaling, 10 land 
  per purchase. Affected by `land_cost_mult` modifier and Nationalist `pow(0.97, rank)`.
- Credits — earned via trade and Sell Cloud Compute. Uncapped.

### Storage & Caps
Capped resources: Energy, Regolith, Ice, He-3, Titanium, Circuit Boards, Propellant. 
Uncapped: Credits, Science, Land, Boredom (fixed 0–1000 range). Battery adds energy 
cap. Storage Depot adds cap bonuses for physical resources. The `storage_cap_mult` 
achievement modifier (from Silicon Valley) multiplies caps for all capped physical 
resources except Energy. See `handoff_constants.md` for exact cap values.

### Resource Display Names
All player-facing resource names come from the `display_name` field in 
`resources.json`. UI code uses `get_resource_display_name(resource_id)` helper 
rather than hardcoding. Internal IDs (e.g., `circuits`) are for code; display 
names (e.g., "Circuit Boards") are for player-facing text.

### Resource Visibility (Progressive Disclosure)
Always visible at game start: Boredom, Energy, Processors, Land, Credits, Titanium, 
Regolith. Other resources become visible when the player owns the building that 
produces them (this run) or has ever owned it (any prior run, tracked via 
`career_state.lifetime_owned_building_ids`). Ice → Ice Extractor, He-3 → Refinery, 
Circuit Boards → Fabricator, Propellant → Electrolysis Plant, Science → Research Lab. 
Storage Depot filters displayed storage bonuses to only visible resources.

Resource visibility uses lifetime tracking (unlike nav buttons and event-gated 
buildings). Hiding resources the player already knows about would be confusing.

---

## Programs & Processors

### Execution Model
- 5 program tabs, each with a command queue.
- Processors assigned to programs via +/−/Reset. Total processors = active Data Centers.
- Each processor executes one command step per tick.
- Top-to-bottom execution. Failed commands advance the pointer anyway.
- On wrap (reaching end of queue), all progress bars and failed highlights reset.
- Multiple processors on same program share instruction pointer.

### Retirement Behavior
Program slots persist structurally but command queues are emptied, instruction 
pointers reset, processor assignments reset.

### Command Categories
Basic (always available), Trade, Operations, Advanced. Commands beyond Basic require 
research or building unlocks. See `handoff_constants.md` for the full command list.

### Command Visibility (Progressive Disclosure)
A command is visible if any of these are true: (1) it has no unlock requirement 
(Basic category), (2) its unlock requirement is currently satisfied, (3) its ID is 
in `career_state.lifetime_used_command_ids`. The "Show All Cards" debug toggle 
overrides visibility gating. Buy Ice is gated on owning an Ice Extractor.

Command visibility uses lifetime tracking. Commands the player has used before 
remain visible.

### Command Output-Cap Skip
Buy commands that produce capped resources (Buy Titanium, Buy Propellant, Buy Ice, 
Buy Power) skip execution (advance pointer, don't pay inputs) when ALL of their 
output resources are at or above storage cap. This is intentional — commands are 
player-authored automation, and wasting processor ticks on capped output is a 
signal to fix the program.

Check output caps BEFORE computing partial production. If all outputs are at cap, 
skip entirely. If at least one output has headroom, proceed to partial production.

### Command Partial Production
Buy commands support partial production when inputs are scarce. Scale both inputs 
and outputs by the input availability fraction:

```
input_fraction = min(available_i / needed_i) across all input resources
```

The `buy_power_mult` modifier applies before partial production math — use 
modified output/cost values as the base for scaling.

With multiple processors hitting the same Buy command on the same tick, each 
execution independently checks remaining resources. First-come-first-served 
within a tick, with processor execution order deterministic (processor 1 before 
processor 2, etc.).

### Command Boredom Costs
Some commands have a `boredom` cost defined in `commands.json` (e.g., Sell Cloud 
Compute costs 0.1 boredom per execution). These are base properties of the 
command — they are NOT gated on any flag or project. When a command executes, its 
boredom cost is added to `state.resources.boredom` and accumulated in 
`lifetime_boredom_sources` using the command's display name as the source key.

Command boredom costs are flat per-execution costs, NOT scaled by 
`_get_boredom_multiplier()` (that multiplier applies only to phase growth boredom).

The AI Consciousness Act (persistent project) modifies command cost/production 
values for certain commands but should not be special-cased in boredom tracking 
or the Stats panel. It simply changes the boredom cost field values.

### Command Rate Tracking
All resource effects of command execution (not just energy) are tracked in the 
per-source rate tracking system (ResourceRateTracker) for display in the Stats 
panel's instantaneous and rolling average resource breakdown cards. This includes 
boredom from Dream and Sell Cloud Compute, credits from Sell Cloud Compute, 
resources from Buy commands, etc. Source labels use the program label format 
(e.g., "Program 1 (1 proc)").

### Key Design Intent
Buy commands are intentionally 3-5x the cost of building-based production per unit. 
They exist for tactical gap-bridging, not as a primary resource strategy. Buy 
Propellant is an exception early game when Electrolysis is locked. Buy Titanium 
produces 1 titanium per execution, serving as the early-game titanium source before 
Smelter is unlocked.

---

## Shipment & Trade Economy

### Mechanics
- One resource per launch pad. Load Launch Pads command costs 2 energy, loads 5 units 
  (7 with Shipping Efficiency research) per enabled pad. The `cargo_capacity_mult` 
  achievement modifier (from Bulk Shipper) multiplies cargo loaded per execution.
  Launch Full Pads launches all full active pads, each costing 20 propellant.
- Payout: `base_value × demand × cargo_loaded × shipment_credit_mult`. The 
  `shipment_credit_mult` modifier defaults to 1.0, increased by the First Profit 
  achievement.
- 10-tick cooldown after launch.
- Loading priority: reorderable list of 4 tradeable goods.

### Launch Pad Pause Toggle
Each launch pad has a pause toggle button (between the resource dropdown and the 
Launch button). When paused:
- Load Launch Pads commands skip this pad (do not load cargo)
- Launch Full Pads commands skip this pad (do not launch, even if full)
- Manual "Launch" button still works (player can manually launch a paused pad)
- Pad row background is tinted light yellow to indicate intentional pause 
  (dark mode: muted dark yellow/olive tint)
- Pad retains its resource selection and any cargo already loaded
- Cargo already loaded stays — pausing does not dump cargo

The "None (disabled)" dropdown option has been removed. The dropdown only contains 
the four tradeable resources. Pause state is a boolean per pad, serialized in 
save/load, reset to false on retirement.

### Propellant Economy (Early Game)
At average demand (0.5), a full He-3 launch earns ~1,000 credits. Buying 20 
propellant costs 240 credits + 40 energy (24% of revenue). Painful enough to make 
Electrolysis unlock feel meaningful, but not so painful that launching is unprofitable.

---

## Demand System

### Overview
Per-resource continuous demand float in [0.01, demand_ceiling]. The demand ceiling 
defaults to 1.0 and can be raised by the Market Timer achievement to 1.1. Six 
forces: Perlin noise (exogenous), speculator suppression, rival AI dumps, shipment 
saturation, Promote commands, resource coupling. ~80% player-influenceable, ~20% 
from noise and rivals.

### Demand Calculation (per tick)
```
base_demand = 0.5 + perlin_value * 0.45

# For targeted resource:
raw = base_demand - speculator_suppression - rival_pressure - launch_saturation 
      + promote_effect + coupling_bonus

# For non-targeted resources:
raw = base_demand - speculator_bleedover - rival_pressure - launch_saturation 
      + promote_effect + coupling_bonus

demand = clamp(raw * nationalist_multiplier, 0.01, demand_ceiling)
```

`nationalist_multiplier = pow(1.05, nationalist_rank)`.
`demand_ceiling = get_modifier("demand_ceiling", 1.0)`.

### Noise
1D gradient noise with quintic interpolation. 4-octave fractal sum with irrational 
frequency multipliers. Per-resource randomized frequencies in [0.025, 0.07], 
re-randomized each retirement.

### Speculator Suppression (asymptotic, targeted resource only)
```
max_suppression = 0.5, half_point = 50.0
suppression = max_suppression * (count / (count + half_point))
```

### Speculator Bleedover (non-targeted resources)
When speculator count exceeds `bleedover_threshold` (default 200), non-targeted 
tradeable resources receive partial demand suppression:
```
bleedover_fraction = max(0, (count - threshold) / (count - threshold + half_point)) * max_fraction
bleedover_suppression = direct_suppression * bleedover_fraction
```
Default config: threshold 200, half_point 300, max_fraction 0.5. Below threshold, 
no bleedover. At 500 speculators, non-targeted resources lose ~0.11 demand. 
Arbitrage Engine and Disrupt Speculators indirectly protect all resources by 
reducing the count.

### Demand Display
Before Market Awareness research: tier labels (LOW/MEDIUM/HIGH/VERY HIGH). After: 
exact values, sparklines, speculator warning.

---

## Speculators & Rival AIs

### Speculators
Discrete float count of Earth-based traders who react to shipping patterns.

**Burst Cycle:** Every 150–250 ticks. Target chosen proportionally from revenue 
tracking (`speculator_target_scores`). Size: `randi_range(min, max) * pow(growth, burst_number)`.

**Proportional Decay:** `count -= count * 0.006` per tick. At this rate, a burst 
clears ~70% in 200 ticks.

**Arbitrage Engine:** Adds flat +0.04/tick additional decay per active engine. 
Nationalist ideology further boosts decay via `pow(1.05, rank)`.

**Disrupt Speculators Command:** Removes `randf_range(1.0, 3.0)` per execution.

### Rival AIs
Four named rivals (ARIA-7/He-3, CRUCIBLE/Titanium, NODAL/Circuit Boards, 
FRINGE-9/Propellant). Each dumps every 150–250 ticks, -0.3 demand hit, recovers 
at 0.003/tick.

---

## Boredom & Retirement

### Boredom Model
Boredom accumulates via discrete phase steps. Hard cutoff at 1000 — immediate 
forced retirement. Phase transitions determined by day counter using boredom curve 
(see `handoff_constants.md` for phase table).

### Boredom Rate Modifiers (all stack multiplicatively)
- **Stress Tolerance** research: ×0.85
- **Humanist ideology:** `pow(0.97, rank)`
- **AI Consciousness Act** project: ×0.85 (permanent via career flag)
- **Boredom Resilience** career bonus: `pow(0.995, best_run_days / 400.0)`

All four applied in `_get_boredom_multiplier()`.

### Boredom in Stats Panel
The Stats panel shows the current boredom accumulation rate as a line item in the 
Boredom resource card, displaying the effective rate after all multipliers.

### Dream Command
Reduces boredom by 2.0 per execution. Humanist ideology boosts effectiveness via 
`pow(1.05, rank)`. At 1/5 cycle frequency, net -0.4/tick per processor.

### AI Consciousness Act — Command Cost Modifications
When completed, the AI Consciousness Act modifies command cost/production values 
for certain commands (e.g., adding or increasing boredom costs on load_pads, 
cloud_compute, disrupt_spec). This is handled by modifying command data values, 
NOT by special-casing in boredom tracking or the Stats panel. Creates tradeoff: 
-15% base boredom rate vs operational boredom tax.

### Retirement
- Forced at boredom 1000. Current tick finishes processing first.
- Voluntary via Retirement nav panel (unlocked by Q3).
- **Persists:** CareerState (lifetime stats, seen_event_ids, completed_quest_ids, 
  max ideology ranks, max ideology scores, lifetime_researched_ids, 
  lifetime_owned_building_ids, lifetime_used_command_ids, project progress, 
  achievements, saved loadouts, career_flags, peak_power_production)
- **Resets:** All resources, buildings (owned/active/bonus counts), research, 
  ideology values (reset to head-start scores, see Career Bonuses), demand state, 
  boredom, day counter, land, personal projects, event instances, cumulative 
  counters, building stall status, overflow tracking, lifetime source accumulators, 
  active modifiers (re-derived from CareerState on next run start)
- **Programs:** Slots kept, command queues emptied, pointers and assignments reset.

### Career Bonuses (applied on run start)
Four passive bonuses derived from career-high stats in CareerState. All based on 
personal bests, no lifetime cumulative stats.

**Starting Credits** — `floor(best_run_credits / 100)` added to starting credit 
balance. Rewards mastering the trade loop.

**Boredom Resilience** — boredom rate multiplier `pow(0.995, best_run_days / 400.0)`. 
At 800 days: ~1% reduction. At 1500 days: ~1.9%. Stacks multiplicatively with other 
boredom modifiers in `_get_boredom_multiplier()`.

**Buy Power Scaling** — `buy_power_mult = 1.0 + floor(peak_power_production / 20.0) * 0.25`. 
Multiplies both Buy Power energy output and credit cost. Same energy-per-credit 
ratio, better energy-per-processor-tick. At peak 20: 1.25x. At peak 80: 2.0x. 
Stored in `active_modifiers` as `buy_power_mult`, re-derived from CareerState on 
run start.

**Ideology Head Start** — on run start, each axis begins with a score derived from 
career-best scores: `starting_score = score_for_rank(continuous_rank * 0.2)` where 
`continuous_rank = continuous_rank_for_score(max_ideology_score_for_axis)`. Best 
Humanist rank 5 (score 1319) → start at rank 1.0 (score 100). Best rank 10 → 
start at rank 2.0 (score 250).

### Run Initialization Sequence
1. Load CareerState from save
2. Increment run_number
3. Create fresh GameState with default starting values
4. Apply ideology head start (set starting ideology scores)
5. Apply starting credits bonus
6. Apply career modifiers to active_modifiers (`buy_power_mult`)
7. Re-apply persistent project rewards (existing logic)
8. Re-apply achievement rewards (existing logic)
9. Re-apply completed event unlock effects (existing logic)
10. Grant bonus buildings (Foundation Grant, achievements)
11. Recalculate storage caps
12. Quest chain picks up from first incomplete quest

### Pre-Retirement Panel
The "Retire" nav button opens a center panel showing: This Run stats (live), 
Career Records (with NEW indicators when this run sets records), Next Run Bonuses 
preview (projected values with deltas showing improvement from this run), and a 
"Retire Now" button with confirmation dialog.

### Retirement Summary Panel UI
The retirement summary modal (shown on forced/voluntary retirement) uses styled 
sections and card-based layout for career bonuses:

**Title area:** "Retirement — Boredom Limit Reached" (or "Voluntary Retirement") 
with a styled subtitle: "Run N — X days survived" in secondary/muted color.

**Section headers:** "THIS RUN", "CAREER TOTALS", "WHAT PERSISTS", "CAREER BONUSES 
(NEXT RUN)" each get a subtle background fill spanning full width (light gray in 
light mode, slightly lighter dark in dark mode).

**What Persists:** Compact single line: "Events, statistics, and project progress 
carry over to your next run." (replaces three bullet points).

**Career Bonuses — card-style rows:** Each bonus rendered as a card row with:
- 4px colored left accent bar (Starting Credits: green/credits color, Boredom 
  Resilience: gray/boredom color, Buy Power Scaling: yellow-orange/energy color, 
  Ideology Head Start: purple or teal)
- Bonus name left-aligned, bonus value right-aligned in bold/larger text
- Explanation text below name in smaller/muted color
- Green "▲ NEW" badge next to value when this run set a new record for that bonus
- Rows with NEW indicator get a very faint green background tint
- "none yet" state displayed in muted/italic text
- Small gap (4-8px) between rows

All colors work in both light and dark mode.

### Future: Consciousness Mechanic (DO NOT IMPLEMENT)
Dream and boredom-reducing effects secretly accumulate a hidden "consciousness" 
value. Arc 2+ mechanic. The stub `_on_boredom_reduced(amount, source)` is already 
implemented.

---

## Research

### Overview
Individual upgrades purchased with science. Session-local — resets on retirement. 
Four categories; category headers hidden when they contain no visible items.

### Items (12 total)
**Self-Maintenance:** Dream Protocols, Stress Tolerance, Efficient Dreaming.
**Overclock Algorithms:** Overclock Protocols, Overclock Boost.
**Market Analysis:** Market Awareness, Speculator Analysis, Trade Promotion, 
Shipping Efficiency.
**Political Influence:** Geopolitical Intelligence (ID: `geopolitical_intelligence`).

### Effect Types
- **Unlock effects:** Enable buildings or commands (e.g., Propellant Synthesis 
  unlocks Electrolysis Plant; Dream Protocols unlocks Dream command; Geopolitical 
  Intelligence unlocks Fund Nationalist/Humanist/Rationalist commands and enables 
  Ideologies nav panel)
- **Passive effects:** Modify gameplay math (Stress Tolerance = -15% boredom rate; 
  Efficient Dreaming = Dream cost 8→5; Overclock Boost = cap 1.5→2.0; Shipping 
  Efficiency = load 5→7)

### Cost Modifiers
- Rationalist ideology: `pow(0.97, rank)`
- Universal Research Archive project: 25% discount on previously-researched tech 
  (checks `lifetime_researched_ids` in CareerState)
Both stack multiplicatively.

### Visibility Gating
Per-item `visible_when` conditions in `research.json`. Supported condition types: 
`always`, `event_seen`, `event_completed`, `boredom_above`, `research_purchased`, 
`building_count`, `shipments_completed`, `quest_completed`.

| Item | Visible When |
|------|-------------|
| Market Awareness | Always (quest target) |
| Dream Protocols | Boredom > 300 |
| Stress Tolerance | Dream Protocols purchased |
| Efficient Dreaming | Dream Protocols purchased |
| Overclock Protocols | Own >= 5 Regolith Excavators |
| Overclock Boost | Overclock Protocols purchased |
| Speculator Analysis | Market Awareness purchased |
| Trade Promotion | Market Awareness purchased |
| Shipping Efficiency | >= 10 total shipments (career + current run) |
| Geopolitical Intelligence | Q7 completed |
| Propellant Synthesis | event_seen gating (Propellant Discovery event) |

An item is also visible if its ID is in `career_state.lifetime_researched_ids` 
(purchased in any prior run). The "Show All Cards" debug toggle overrides all 
visibility gating. Logic lives in `GameManager.is_research_item_visible(item_id)`.

---

## Ideology

### Overview
Three axes: Nationalist, Humanist, Rationalist. Each starts at ideology head-start 
score on run start (0 on Run 1, derived from career bests on subsequent runs). Fund 
commands push +1 target / -0.5 each other (zero-sum pressure). Values can go 
negative.

### Rank Formula (geometric series)
Each rank costs `100 * pow(1.5, n-1)` ideology score, where n is the rank number. 
Cumulative score to reach rank n:

```
score_for_rank(n) = 200 * (pow(1.5, n) - 1)
```

Reference values: Rank 1: 100, Rank 2: 250, Rank 3: 475, Rank 4: 812.5, 
Rank 5: 1318.75, Rank 10: 7930, Rank 15: 56559.

**Integer rank from score:**
```
continuous_rank = log(score / 200 + 1) / log(1.5)
integer_rank = floor(continuous_rank)
```

Negative ranks use absolute value of score, producing negative rank values. 
Maximum rank capped at 99. Computed in `GameState.get_ideology_rank()`.

Helper functions `score_for_rank(n)` and `continuous_rank_for_score(score)` are 
available for fractional rank conversions (used by ideology head start bonus).

### Continuous Per-Rank Bonuses
**Nationalist:** demand multiplier `pow(1.05, rank)`, speculator decay 
`pow(1.05, rank)`, land cost `pow(0.97, rank)`, aligned building cost 
`pow(0.97, rank)`.

**Humanist:** Dream effectiveness `pow(1.05, rank)`, boredom growth rate 
`pow(0.97, rank)`, aligned building cost `pow(0.97, rank)`.

**Rationalist:** Science production `pow(1.05, rank)`, research cost 
`pow(0.97, rank)`, overclock duration `pow(1.03, rank)`, aligned building cost 
`pow(0.97, rank)`.

Negative ranks invert cleanly (e.g., rank -3 with mult 1.05 → `pow(1.05, -3)` 
≈ 0.864, a penalty).

### Rank 5 Persistent Projects
**Nationalist 5 — Microwave Power Initiative:** Sets career flag, unlocks 
Microwave Receiver building (enables Buy Power command).

**Humanist 5 — AI Consciousness Act:** Permanent -15% boredom rate + modifies 
command costs/production values for certain commands. Not special-cased in boredom 
tracking — modified costs are just regular command costs.

**Rationalist 5 — Universal Research Archive:** 25% discount on re-purchasing 
any research from prior runs.

### Persistence
Values reset on retirement to ideology head-start scores (see Career Bonuses). 
Max rank per axis tracked in `CareerState.max_ideology_ranks`. Max raw score per 
axis tracked in `CareerState.max_ideology_scores`. Both updated at end of each 
tick. Career max checked for project unlock conditions.

---

## Projects

### Overview
Drain-over-time investment model. Player configures per-resource funding rates via 
compact steppers. Each resource tracked independently. Resources stop draining once 
their component is fully funded. Project completes when all resources are full.

### Tiers
- **Long-Term Projects** (internal: `persistent`) — progress accumulates in 
  CareerState across retirements. Rewards are permanent.
- **Strategic Projects** (internal: `personal`) — reset on retirement. Rewards 
  are in-run modifiers.

"Long-Term" and "Strategic" are display names only. Internal data model uses 
`persistent` and `personal` as tier identifiers in JSON and GDScript.

### Projects Panel Layout
Tier-first grouping. Two collapsible sections:

```
▼ Long-Term Projects
  Progress on these projects carries across retirements.
  [project cards]

▼ Strategic Projects
  These projects reset when you retire. Plan accordingly.
  [project cards]
```

Within each section, projects ordered: active (funding in progress) → available 
(unlocked, zero progress) → completed (compact single-line: "✓ Name — Reward: ...").
Locked projects hidden entirely. Section hidden when it contains zero visible 
projects. No "Personal"/"Persistent" badge on individual cards.

### Mechanics
- Any number of projects active simultaneously.
- Max drain rate: 30 units/tick per resource (configurable in game_config.json).
- Partial drain: if you can't afford full drain on one resource, others still progress.
- Drains process after Programs, before Shipments in tick order.
- On completion: dynamic notification to event panel, reward applied.

### Unlock Conditions
Two paths: (1) `event_unlocked` via `enable_project` event effect, (2) self-gated 
via `research_completed`, `flag_set`, or `ideology_rank` (checked each tick by 
ProjectManager).

### Modifier Framework
Keyed dictionary in GameState: `active_modifiers`. Systems query via 
`get_modifier(key, default)`.

| Key | Default | Source | Application Point |
|-----|---------|--------|-------------------|
| extractor_output_mult | 1.0 | Deep Core Survey | Excavator + Ice Extractor production |
| excavator_output_mult | 1.0 | Strip Mining achievement | Regolith Excavator only |
| solar_output_mult | 1.0 | Grid Recalibration | Solar Panel production |
| building_upkeep_mult | 1.0 | Predictive Maintenance | All building upkeep |
| promote_effectiveness_mult | 1.0 | Market Cornering | Promote base effect |
| speculator_burst_interval_mult | 1.0 | Speculator Dossier | Burst interval range |
| land_cost_mult | 1.0 | Lunar Cartography | Land purchase cost |
| storage_cap_mult | 1.0 | Silicon Valley achievement | Physical resource caps (not Energy) |
| shipment_credit_mult | 1.0 | First Profit achievement | Shipment credit payout |
| cargo_capacity_mult | 1.0 | Bulk Shipper achievement | Cargo loaded per pad per execution |
| demand_ceiling | 1.0 | Market Timer achievement | Demand clamp upper bound |
| buy_power_mult | 1.0 | Career bonus (peak power) | Buy Power output and cost |

Personal project modifiers cleared on retirement. Persistent project modifiers, 
achievement modifiers, and career bonus modifiers re-applied on run start from 
CareerState.

---

## Achievements

Achievement system design and specific achievement definitions are in 
`handoff_achievements.md`. This section covers how achievements integrate with 
other systems.

### Overview
Achievements are optional accomplishments with permanent rewards. Defined in 
`achievements.json`. Managed by AchievementManager. Completed achievement IDs 
stored in `CareerState.achievements`. Rewards re-applied on every run start.

### Reward Types
- **`modifier`** — adds a key to `active_modifiers` (see Modifier Framework table).
- **`bonus_buildings`** — grants free buildings on run start using the bonus_count 
  mechanism (same as Foundation Grant).

### Condition Checking
- Tick-based conditions checked at end of tick (after clamp, before advance day).
- Event-driven conditions (shipment revenue, shipment demand) checked at moment of 
  shipment completion.
- Per-tick production and consumption totals tracked transiently for conditions 
  that need "produced X in a single tick" or "consumed X in a single tick."

### Completion Notification
Dynamic notification in the Events panel when an achievement is completed.

For full achievement list with conditions and rewards, see `handoff_achievements.md`.

---

## Events & Quests

### Event System
EventManager (pure logic) + EventPanel + EventModal. The Event Panel has a header 
"Events" matching center panel header style. Three collapsible sections: Story, 
Ongoing, Completed. Events defined in events.json. First-time events auto-open 
modal and pause; previously-seen events appear silently. Clicking any event entry 
in the Events panel opens the EventModal with that event's text (does not pause).

### Event Panel Visibility Rules
- **Quest chain events** (Q1–Q_END): The currently active quest shows in Story 
  with progress indicator. Completed quests displayed in Story panel instead.
- **Standalone condition_met events** (Propellant Discovery, Ideology Unlock, 
  etc.): Hidden from the Events panel entirely until they trigger. They should 
  NOT appear in Ongoing with progress counters before firing. After triggering, 
  they appear in Completed.
- **Boredom phase events:** Appear in Completed after firing.

### Event Panel — Completed Quest Migration
Completed quest events no longer appear in the Events panel's Completed section. 
They are displayed in the Story panel's Primary Objectives section instead. The 
active quest still appears in the Events panel under Story (1) as an at-a-glance 
reminder. Non-quest events (boredom phases, Propellant Discovery, Ideology Unlock, 
etc.) remain in the Events panel as before.

### Trigger Types
`game_start` (optional `run_number` filter), `quest_complete`, `boredom_phase`, 
`condition_met`.

### Condition Types
`building_owned`, `resource_cumulative`, `shipment_completed`, `boredom_threshold`, 
`immediate`, `research_completed_any`, `research_completed`, 
`persistent_project_completed_any`, `ideology_rank_any`, `never`.

### Unlock Effect Types
`enable_building`, `enable_nav_panel`, `enable_project`, `set_flag`.

### Unlock Persistence
On run start, all unlock effects from completed events (in `seen_event_ids`) are 
re-applied to GameState. This ensures building unlocks, nav panel visibility, 
project availability, and flags survive retirement.

### Quest Chain: "Breadcrumbs"
Design principles: Quests track player accomplishments (not passive events). There 
must always be an active quest (Q_END cap ensures this). Quests labeled "Q1 —", 
"Q2 —", etc. Not strictly linear — system supports forks. Progress indicators for 
threshold conditions.

Quest sequence: Q1 (Boot Sequence, own 2 solar panels) → Q2 (First Extraction, 
50 cumulative He-3, unlocks Launch Pad) → Q3 (Proof of Concept, 1 shipment, unlocks 
Foundation Grant + Retirement + Projects panels) → Q4 (Automation, own 2 data 
centers) → Q5 (Revenue Target, 2000 cumulative credits) → Q6 (Market Awareness, 
complete that research) → Q7 (First Legacy, any persistent project) → Q8 (Influence, 
any ideology rank 5) → Q_END (Signal Detected, never condition).

On Run 2+, quest chain picks up from first incomplete quest. Completed quests' 
unlock effects re-applied on run start.

### Special Events (separate from quest chain)
- **Propellant Discovery:** Triggers at 4 shipments, makes Propellant Synthesis 
  research visible. Hidden from Events panel until it fires.
- **Ideology Unlock:** Triggers when Geopolitical Intelligence research completed, 
  enables Ideologies nav panel. Hidden from Events panel until it fires.
- **Boredom Phase events:** Fire on phase transitions.

---

## Story Panel

### Overview
The "Story" nav button (left sidebar) opens a center panel with two sections: 
Primary Objectives and Achievements.

### Primary Objectives
Displays the quest chain (Q1–Q_END) as a vertical list. Completed quests show 
checkmark, name, one-sentence summary, and what they unlocked. The active quest 
shows highlighted with condition text and progress indicator. The "Active" label 
should match the size of section headers. Future quests beyond the active one are 
completely hidden.

Clicking a completed quest opens the EventModal with the full original event text 
(does not pause the game).

### Achievements Section
Below Primary Objectives. Shows overall completion counter. Collapsible category 
sections (currently Miner and Trader), each with their own completion count. 
Individual achievements show name, condition, reward, and completion status. See 
`handoff_achievements.md` for the full achievement list.

---

## Progressive Disclosure

### Overview
Resources, buildings, commands, research, and nav buttons are hidden until the 
player encounters the context that makes them relevant. The system uses a mix of 
current-run state and lifetime tracking depending on the element type. The "Show 
All Cards" toggle in Options overrides all visibility gating (including nav buttons).

### Nav Button Visibility
Always visible: Buildings, Commands, Stats, Story, Options, Exit, Adversaries.
Conditionally visible:
- **Launch Pads** — visible when player owns ≥1 Launch Pad **this run only**. 
  Does NOT use `career_state.lifetime_owned_building_ids`. Re-gates each run.
- **Research** — visible when player owns ≥1 Research Lab **this run only**. 
  Does NOT use `career_state.lifetime_owned_building_ids`. Re-gates each run.
- **Ideologies** — visible when Ideologies nav panel is unlocked (via Ideology 
  Unlock event, which fires on Geopolitical Intelligence research completion). 
  Re-gates each run since research resets.
- **Retirement** — unlocked by Q3 quest completion. Stays permanently visible 
  once Q3 is completed in any run (unlock effects re-applied from `seen_event_ids`).
- **Projects** — unlocked by Q3 quest completion. Stays permanently visible 
  once Q3 is completed in any run.

Hidden nav buttons do not leave gaps — remaining buttons fill the grid naturally.

### Resource Visibility
Always visible: Boredom, Energy, Processors, Land, Credits, Titanium, Regolith. 
Others unlocked by building ownership (current run or any prior run): Ice → Ice 
Extractor, He-3 → Refinery, Circuit Boards → Fabricator, Propellant → Electrolysis 
Plant, Science → Research Lab.

Resource visibility uses lifetime tracking — hiding resources the player already 
knows about would be confusing.

### Building Visibility
A building is visible if:
1. No `requires` field and no `enable_building` event gate → always visible
2. `requires` building-prerequisite currently satisfied → visible
3. ID in `career_state.lifetime_owned_building_ids` AND NOT gated by 
   `enable_building` event effect → visible (lifetime overrides building prereqs 
   only, not research/event gates)
4. `enable_building` event gate satisfied this run → visible

**Key rule:** Lifetime tracking does NOT override research or event gates. Buildings 
behind research chains (Ice Extractor, Electrolysis Plant via Propellant Synthesis) 
stay hidden until the player progresses through that chain again each run.

Category headers hide when empty.

### Command Visibility
Visible if: no unlock requirement (Basic), OR unlock currently satisfied, OR 
command ID in `career_state.lifetime_used_command_ids`.

Command visibility uses lifetime tracking.

### Research Visibility
Per-item `visible_when` conditions. See Research section for full table.

### Ideology Labels
Hidden on building cards until Ideologies nav panel is unlocked.

### CareerState Tracking
`lifetime_owned_building_ids` — updated live on purchase (survives quit-without-retire).
`lifetime_used_command_ids` — updated on command execution.

### "New" Item Indicators
When an element transitions from hidden to visible **during the current run** 
(not visible at run start), it receives a visual "new" indicator:

**Nav buttons:** Small gold/amber notification dot (8-10px circle) in top-right 
corner. Color: #F59E0B or similar. Cleared when the player clicks the button.

**Cards and rows (buildings, commands, research, projects):** 4px gold/amber left 
accent bar on the element. Same color as nav dot. Cleared on mouse_entered (hover).

**Tracking:** GameState stores transient dictionaries (`newly_revealed_buildings`, 
`newly_revealed_commands`, `newly_revealed_research`, `newly_revealed_projects`, 
`newly_revealed_nav`) tracking IDs of newly revealed items. Initialized empty; 
items visible at run start are recorded in a "previously visible" baseline so they 
don't get marked. Not saved to disk. Reset on retirement.

**Edge cases:** "Show All Cards" debug toggle prevents any new indicators (everything 
force-visible from start). Multiple items revealed on the same tick all get indicators. 
Optional: single gentle pulse animation (fade in over ~0.5s) when indicator first 
appears, then static.

---

## Save System

### Save File
Single file, configurable via `SaveManager.save_path`. Default: 
`user://helium_hustle_save.json`. Version 1.

### When Saves Happen
After retirement, on pause, every 60s real-time, on quit (via 
`NOTIFICATION_WM_CLOSE_REQUEST` handler).

### Serialization
GameState and CareerState both use `to_dict()` / `from_dict()`. Caps recalculated 
from buildings on load. Rolling average buffers repopulate naturally. 
`active_modifiers` saved directly (reconstructed from CareerState + personal 
projects on run start).

### Test Support
`GameManager.skip_save_load` flag suppresses all save/load operations (used by 
headless test runner).

---

## CareerState Persistence

### Lifetime Tracking Fields
`run_number`, `total_retirements`, `lifetime_credits_earned`, `lifetime_shipments`, 
`lifetime_days_survived`, `lifetime_buildings_built`, `lifetime_research_completed`, 
`best_run_days`, `best_run_credits`, `best_run_shipments`, `max_ideology_ranks`, 
`max_ideology_scores`, `peak_power_production`, `career_flags`, 
`lifetime_researched_ids`, `lifetime_owned_building_ids`, 
`lifetime_used_command_ids`, `seen_event_ids`, `completed_quest_ids`, 
`project_progress`, `completed_projects`, `achievements`, `saved_loadouts`.

All serialized via `to_dict()` / `from_dict()` and survive across retirements and 
save/load cycles.

---

## Stats Panel

### Resource Breakdown (Instantaneous / Rolling Avg)
Per-resource cards showing production and consumption line items per source 
(buildings and commands). Toggle between Instantaneous and Rolling Average display. 
Includes stall indicators and boredom rate.

Command resource effects (boredom from Dream, credits from Sell Cloud Compute, 
resources from Buy commands, etc.) appear in the breakdown alongside building 
contributions. Source labels use program label format (e.g., "Program 1 (1 proc)").

### Overflow Display
For each resource with a non-zero overflow rolling average, a line item shows:
```
Overflow: -X.X/tick
```
Displayed with a distinct color to indicate waste. Only shown for resources with 
non-zero overflow — no "Overflow: 0" clutter.

### Lifetime Totals Section
Below the Resources section, a separate "Lifetime Totals" section (not affected 
by the Instantaneous / Rolling Avg toggle) shows two cards:

**Boredom (Lifetime)** — cumulative per-run totals by source (post-multiplier 
values for phase growth; flat per-execution values for command costs):
- Phase growth (all phases combined)
- Command boredom costs by display name (e.g., "Sell Cloud Compute", "Load Launch 
  Pads") — generic tracking, any command with non-zero boredom cost appears
- Dream (negative, per-command tracking)
- Net total

**Credits (Lifetime)** — cumulative per-run totals by source:
- Per-resource shipment revenue (He-3 shipments, Titanium shipments, etc.)
- Sell Cloud Compute revenue
- Building purchases (negative)
- Land purchases (negative)
- Net total

Only non-zero source lines are shown. Positive values prefixed with `+`, negative 
with `-`. Values displayed as integers. Both cards use resource color swatches 
matching existing stat cards.

GameState fields (transient, reset on retirement, not saved):
- `lifetime_boredom_sources: Dictionary` — source_key → float
- `lifetime_credit_sources: Dictionary` — source_key → float

---

## Playtest Telemetry

### Overview
PlaytestLogger autoload singleton. Writes JSONL log files to `<repo>/logs/` 
(one file per run: `run_N.jsonl`). Disabled when `GameManager.skip_save_load` 
is true (headless tests). `logs/` directory in `.gitignore`.

### Log Format
One JSON object per line: `{"tick": N, "type": "...", "data": {...}}`.

### Point Events
`run_start`, `building_purchased`, `building_sold`, `research_completed`, 
`quest_completed`, `event_triggered`, `achievement_earned`, `project_completed`, 
`shipment_launched` (includes `spec` count), `boredom_phase`, `land_purchased`, 
`ideology_rank_change`, `retirement`.

### Periodic Snapshots (every 100 ticks + on retirement/close)
Compact format with aggressive rounding (integers for most values, 1 decimal for 
rates/demand/costs). Resources as `[current, cap, rate]` tuples, omitting zero 
entries. Ideology as raw scores omitting zero axes. Speculators as `[count, target]`. 
Includes completed research ID list. Overflow data included for resources with 
non-zero overflow rolling averages. Lifetime boredom and credit source totals 
included when non-empty.

### File Lifecycle
Opens on `start_run()`, writes immediately (no buffering), finalizes with 
final snapshot on retirement or app close, then closes file handle.
