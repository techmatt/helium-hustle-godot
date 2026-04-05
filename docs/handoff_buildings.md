# Helium Hustle — Building System

For exact numbers (costs, rates, thresholds), see `handoff_constants.md`.

---

## Purchase & Cost Scaling

`base_cost × pow(scaling, purchased_count) × ideology_cost_mult`

Where `purchased_count = max(0, owned_count - bonus_count)` — free buildings from 
persistent projects or achievements don't inflate cost curves. 
`ideology_cost_mult = pow(0.97, rank)` for buildings with an aligned ideology axis.

## Enable/Disable

Each building type tracks `active_count` and `owned_count`. Only active buildings 
produce, consume, and grant effects. Disabled buildings still occupy land.

## Sell

Sell 1 or Sell All (double-click confirmation). Refunds land only, no credit refund.

## Building Processing: Multi-Pass Resolution

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

## Floating Point Epsilon

Phase 1 affordability checks use `RESOURCE_EPSILON = 0.001` tolerance to prevent 
false stalls from floating point precision errors. A building can pay its upkeep 
if `available >= needed - RESOURCE_EPSILON`. The actual consumption still uses the 
exact `needed` value. Any resulting tiny negative resource values are handled by 
the end-of-tick clamp to 0.

## No Output-Cap Skip for Buildings

Buildings always produce, even when their output resources are at storage cap. 
Excess production is clamped at end of tick and tracked as overflow (waste). This 
avoids cascading edge cases where skipping one building changes resource 
availability for others.

## End-of-Tick Clamp & Overflow Tracking

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

## Partial Production (Input-Constrained)

Buildings with insufficient upkeep resources run at reduced capacity in Phase 2. 
Capacity fraction = min(available_i / needed_i) across all upkeep resources. All 
inputs consumed and outputs produced are scaled by this fraction. A fraction of 0 
means no activity. Buildings running below 100% are flagged `input_starved` in 
`building_stall_status`.

## Building Stall Tracking

`GameState.building_stall_status` tracks per-building stall state each tick. Two 
types: `input_starved` (ran at partial capacity in Phase 2) and `output_capped` 
(all outputs at or above cap at start of tick — informational only, building still 
produces).

## Building Card Status Row

Building cards always reserve vertical space for the status row (stall indicators) 
to prevent height flickering when statuses appear/disappear.

## Bonus Building Cost Scaling

Buildings granted free by persistent projects (e.g., Foundation Grant) or 
achievements (e.g., Powerhouse) track `bonus_count` separately. Cost scaling uses 
`max(0, owned_count - bonus_count)`. Bonus buildings are granted on run start, 
with `owned_count`, `active_count`, and `bonus_count` all incremented. Storage 
caps are recalculated after granting.

## Building Alignment

Buildings are assigned to ideology axes. Aligned buildings get per-rank cost 
discount `pow(0.97, rank)`.

- **Nationalist:** Launch Pad, Arbitrage Engine, Microwave Receiver, Fuel Cell Array
- **Humanist:** Data Center, Battery
- **Rationalist:** Fabricator, Research Lab

Ideology alignment labels are hidden on building cards until the Ideologies nav 
panel is unlocked.

## Unlock Requirements

Buildings with a non-empty `requires` field or gated by `enable_building` event 
effects are not purchasable until requirements are met. The `requires` field 
supports `building_id` (own at least 1) and `building_id:N` (own at least N). 
GameSimulation enforces this (defense in depth).

## Building Visibility (Progressive Disclosure)

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
(like Ice Extractor/Electrolysis Plant behind Propellant Synthesis research chain, 
or Fuel Cell Array behind Chemical Energy Initiative project). The player must 
progress through research/event/project chains again each run.

Category headers hide when they contain zero visible buildings. The "Show All 
Cards" debug toggle overrides all visibility gating.

Notable requires gates: Research Lab requires `data_center:2` (player starts 
with 1). Smelter requires Regolith Excavator. Fabricator requires Smelter.
