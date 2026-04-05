# Helium Hustle — Progression Systems

For exact numbers (costs, rates, thresholds), see `handoff_constants.md`.

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
  completed_sub_objectives, max ideology ranks, max ideology scores, 
  lifetime_researched_ids, lifetime_owned_building_ids, 
  lifetime_used_command_ids, project progress, achievements, saved loadouts, 
  career_flags, peak_power_production)
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
At 800 days: ~1% reduction. At 1500 days: ~1.9%. Stacks multiplicatively with 
other boredom modifiers in `_get_boredom_multiplier()`.

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
- Partial drain: if you can't afford full drain on one resource, others still 
  progress.
- Drains process after Programs, before Shipments in tick order.
- On completion: dynamic notification to event panel, reward applied.

### Unlock Conditions
Two paths: (1) `event_unlocked` via `enable_project` event effect, (2) self-gated 
via `research_completed`, `flag_set`, `ideology_rank`, or `quest_active` (checked 
each tick by ProjectManager).

### Chemical Energy Initiative
Persistent project. Costs 2,000 credits, 1,000 science, 1,000 propellant. Gated 
on Q6 (Open Horizons) being active (`quest_active` condition). On completion, 
unlocks the Fuel Cell Array building via `enable_building` effect. Completion 
carries across retirements; `enable_building` reward re-applied on run start.

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
`completed_sub_objectives`, `project_progress`, `completed_projects`, 
`achievements`, `saved_loadouts`.

All serialized via `to_dict()` / `from_dict()` and survive across retirements and 
save/load cycles.
