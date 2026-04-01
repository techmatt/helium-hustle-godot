# Helium Hustle — System Specifications

This document specifies the mechanical design of each game system: how it works, 
why, and what it interacts with. For exact numbers (costs, rates, thresholds), see 
`handoff_constants.md` (auto-generated from JSON ground truth).

---

## Buildings

### Purchase & Cost Scaling
`base_cost × pow(scaling, purchased_count) × ideology_cost_mult`

Where `purchased_count = max(0, owned_count - bonus_count)` — free buildings from 
persistent projects don't inflate cost curves. `ideology_cost_mult = pow(0.97, rank)` 
for buildings with an aligned ideology axis.

### Enable/Disable
Each building type tracks `active_count` and `owned_count`. Only active buildings 
produce, consume, and grant effects. Disabled buildings still occupy land.

### Sell
Sell 1 or Sell All (double-click confirmation). Refunds land only, no credit refund.

### Production-Gated Upkeep
Buildings with production outputs skip upkeep on ticks where ALL their produced 
resources are at storage cap. Buildings with no production (Battery, Storage Depot, 
Launch Pad, Data Center) always pay upkeep.

### Partial Production (Input-Constrained)
Buildings with insufficient upkeep resources run at reduced capacity rather than
skipping entirely. Capacity fraction = min(available_i / needed_i) across all
upkeep resources. All inputs consumed and outputs produced are scaled by this
fraction. A fraction of 0 (zero stockpile of any input) means no activity.
Buildings running below 100% are flagged `input_starved` in `building_stall_status`.
Output-capped buildings and no-production buildings (Battery, Storage Depot, Launch
Pad, Data Center) are unaffected — the former skip entirely, the latter pay
all-or-nothing upkeep.

### Building Stall Tracking
`GameState.building_stall_status` tracks per-building stall state each tick. Two 
types: `input_starved` and `output_capped`.

### Bonus Building Cost Scaling
Buildings granted free by persistent projects (e.g., Foundation Grant) track 
`bonus_count` separately. Cost scaling uses `max(0, owned_count - bonus_count)`.

### Building Alignment
Buildings are assigned to ideology axes. Aligned buildings get per-rank cost discount 
`pow(0.97, rank)`. Nationalist: Launch Pad, Arbitrage Engine, Microwave Receiver. 
Humanist: Data Center, Battery. Rationalist: Fabricator, Research Lab.

### Unlock Requirements
Buildings with a non-empty `requires` field or gated by `enable_building` event 
effects are visible but not purchasable until requirements are met. GameSimulation 
enforces this (defense in depth).

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
cap. Storage Depot adds cap bonuses for physical resources. See `handoff_constants.md` 
for exact cap values.

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

### Key Design Intent
Buy commands are intentionally 3-5x the cost of building-based production per unit. 
They exist for tactical gap-bridging, not as a primary resource strategy. Buy 
Propellant is an exception early game when Electrolysis is locked.

---

## Shipment & Trade Economy

### Mechanics
- One resource per launch pad. Load Launch Pads command costs 2 energy, loads 5 units 
  (7 with Shipping Efficiency research) per enabled pad. Launch Full Pads launches 
  all full active pads, each costing 20 propellant.
- Payout: `base_value × demand × cargo_loaded`.
- 10-tick cooldown after launch.
- Loading priority: reorderable list of 4 tradeable goods.

### Propellant Economy (Early Game)
At average demand (0.5), a full He-3 launch earns ~1,000 credits. Buying 20 
propellant costs 240 credits + 40 energy (24% of revenue). Painful enough to make 
Electrolysis unlock feel meaningful, but not so painful that launching is unprofitable.

---

## Demand System

### Overview
Per-resource continuous demand float in [0.01, 1.0]. Six forces: Perlin noise 
(exogenous), speculator suppression, rival AI dumps, shipment saturation, Promote 
commands, resource coupling. ~80% player-influenceable, ~20% from noise and rivals.

### Demand Calculation (per tick)
```
base_demand = 0.5 + perlin_value * 0.45
raw = base_demand - speculator_suppression - rival_pressure - launch_saturation 
      + promote_effect + coupling_bonus
demand = clamp(raw * nationalist_multiplier, 0.01, 1.0)
```

`nationalist_multiplier = pow(1.05, nationalist_rank)`.

### Noise
1D gradient noise with quintic interpolation. 4-octave fractal sum with irrational 
frequency multipliers. Per-resource randomized frequencies in [0.025, 0.07], 
re-randomized each retirement.

### Speculator Suppression (asymptotic)
```
max_suppression = 0.5, half_point = 50.0
suppression = max_suppression * (count / (count + half_point))
```

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
Four named rivals (ARIA-7/He-3, CRUCIBLE/Titanium, NODAL/Circuits, 
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

All three applied in `_get_boredom_multiplier()`.

### Dream Command
Reduces boredom by 2.0 per execution. Humanist ideology boosts effectiveness via 
`pow(1.05, rank)`. At 1/5 cycle frequency, net -0.4/tick per processor.

### AI Consciousness Act — Command Boredom Costs
When completed, certain commands gain per-execution boredom costs: `load_pads` +0.3, 
`cloud_compute` +0.2, `disrupt_spec` +0.5. Creates tradeoff: -15% base rate vs 
operational boredom tax.

### Milestone Boredom Reductions
Large one-time reductions per run. Defined in `game_config.json` under `milestones`. 
Checked at end of each tick. Consciousness hook stub called on all boredom reductions.

### Retirement
- Forced at boredom 1000. Current tick finishes processing first.
- Voluntary via Retirement nav panel (unlocked by Q3).
- **Persists:** CareerState (lifetime stats, seen_event_ids, completed_quest_ids, 
  max ideology ranks, lifetime_researched_ids, project progress, achievements, 
  saved loadouts, career_flags)
- **Resets:** All resources, buildings (owned/active/bonus counts), research, 
  ideology values, demand state, boredom, day counter, land, personal projects, 
  event instances, triggered milestones, cumulative counters, building stall status, 
  active modifiers (re-derived from CareerState on next run start)
- **Programs:** Slots kept, command queues emptied, pointers and assignments reset.

### Future: Consciousness Mechanic (DO NOT IMPLEMENT)
Dream and boredom-reducing effects secretly accumulate a hidden "consciousness" 
value. Arc 2+ mechanic. The stub `_on_boredom_reduced(amount, source)` is already 
implemented.

---

## Research

### Overview
Individual upgrades purchased with science. Session-local — resets on retirement. 
Four categories; category headers hidden when they contain no visible items.

### Effect Types
- **Unlock effects:** Enable buildings or commands (e.g., Propellant Synthesis 
  unlocks Electrolysis Plant; Dream Protocols unlocks Dream command)
- **Passive effects:** Modify gameplay math (Stress Tolerance = -15% boredom rate; 
  Efficient Dreaming = Dream cost 8→5; Overclock Boost = cap 1.5→2.0; Shipping 
  Efficiency = load 5→7)

### Cost Modifiers
- Rationalist ideology: `pow(0.97, rank)`
- Universal Research Archive project: 25% discount on previously-researched tech 
  (checks `lifetime_researched_ids` in CareerState)
Both stack multiplicatively.

### Visibility Gating
Per-item `visible_when` conditions in `research.json`. Supported types: `always`,
`event_seen`, `event_completed`, `boredom_above`, `research_purchased`,
`building_count`, `shipments_completed`, `quest_completed`. An item is also visible
if its ID is in `career_state.lifetime_researched_ids` (purchased in any prior run).
The "Show All Cards" debug toggle overrides all visibility gating. Category headers
are hidden when they contain zero visible items. Logic lives in
`GameManager.is_research_item_visible(item_id)`.

---

## Ideology

### Overview
Three axes: Nationalist, Humanist, Rationalist. Each starts at 0 per run. Fund 
commands push +1 target / -0.5 each other (zero-sum pressure). Values can go 
negative.

### Rank Thresholds
70, 175, 333, 570, 925 for ranks 1–5. Negative ranks use same thresholds on 
absolute value. Rank computed in `GameState.get_ideology_rank()`.

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

**Humanist 5 — AI Consciousness Act:** Permanent -15% boredom rate + command 
boredom costs on load_pads, cloud_compute, disrupt_spec.

**Rationalist 5 — Universal Research Archive:** 25% discount on re-purchasing 
any research from prior runs.

### Persistence
Values reset on retirement (Arc 1). Max rank per axis tracked in CareerState. 
Updated at end of each tick. Career max checked for project unlock conditions.

---

## Projects

### Overview
Drain-over-time investment model. Player configures per-resource funding rates via 
compact steppers. Each resource tracked independently. Resources stop draining once 
their component is fully funded. Project completes when all resources are full.

### Tiers
- **Personal** — reset on retirement. Rewards are in-run modifiers.
- **Persistent** — progress accumulates in CareerState. Rewards are permanent.

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
| solar_output_mult | 1.0 | Grid Recalibration | Solar Panel production |
| building_upkeep_mult | 1.0 | Predictive Maintenance | All building upkeep |
| promote_effectiveness_mult | 1.0 | Market Cornering | Promote base effect |
| speculator_burst_interval_mult | 1.0 | Speculator Dossier | Burst interval range |
| land_cost_mult | 1.0 | Lunar Cartography | Land purchase cost |

Personal project modifiers cleared on retirement. Persistent project modifiers 
re-applied on run start from CareerState.

---

## Events & Quests

### Event System
EventManager (pure logic) + EventPanel + EventModal. Three collapsible sections: 
Story, Ongoing, Completed. Events defined in events.json. First-time events 
auto-open modal and pause; previously-seen events appear silently.

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
  research visible.
- **Ideology Unlock:** Triggers when nationalist_lobbying research completed, 
  enables Ideologies nav panel.
- **Boredom Phase events:** Fire on phase transitions.

---

## Save System

### Save File
Single file, configurable via `SaveManager.save_path`. Default: 
`user://helium_hustle_save.json`. Version 1.

### When Saves Happen
After retirement, on pause, every 60s real-time, on quit.

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
`career_flags`, `lifetime_researched_ids`, `seen_event_ids`, `completed_quest_ids`, 
`project_progress`, `completed_projects`, `achievements`, `saved_loadouts`.

All serialized via `to_dict()` / `from_dict()` and survive across retirements and 
save/load cycles.
