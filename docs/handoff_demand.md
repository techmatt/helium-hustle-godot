# Helium Hustle — Demand System

For exact numbers (costs, rates, thresholds), see `handoff_constants.md`.

---

## Overview

Per-resource continuous demand float in [0.01, demand_ceiling]. The demand ceiling 
defaults to 1.0 and can be raised by the Market Timer achievement to 1.1. Five 
forces: Perlin noise (exogenous), per-resource speculator suppression, rival AI 
dumps, shipment saturation, Promote commands, resource coupling. ~80% 
player-influenceable, ~20% from noise and rivals.

## Demand Calculation (per tick)

```
raw = base_demand - speculator_suppression(speculators[resource]) 
      - rival_pressure - launch_saturation 
      + promote_effect + coupling_bonus

demand = clamp(raw * nationalist_multiplier, 0.01, demand_ceiling)
```

`nationalist_multiplier = pow(1.05, nationalist_rank)`.
`demand_ceiling = get_modifier("demand_ceiling", 1.0)`.

Speculator suppression is computed per-resource from that resource's own pool 
(see Speculator Suppression below). There is no bleedover mechanic.

## Noise

1D gradient noise with quintic interpolation. 4-octave fractal sum with irrational 
frequency multipliers. Per-resource randomized frequencies in [0.025, 0.07], 
re-randomized each retirement.

## Speculator Suppression (per-resource, asymptotic)

Each resource's speculator pool suppresses demand for that resource only:

```
suppression = max_suppression * (pool_count / (pool_count + half_point))
```

Where `pool_count = speculators[resource]`. Default config: `max_suppression = 0.5`, 
`half_point = 50.0`. Applied uniformly to all resources — no targeted/non-targeted 
distinction.

Note: `half_point` was calibrated for a single global pool. With 4 independent 
pools, individual pools will be smaller per-resource. May need retuning after 
playtesting.

## Demand Display

Before Market Awareness research: tier labels (LOW/MEDIUM/HIGH/VERY HIGH). After: 
exact values, sparklines, speculator warning.

---

## Speculators & Rival AIs

### Per-Resource Speculator Pools

Four independent speculator pools, one per tradeable resource:

```
speculators = { "he3": 0.0, "titanium": 0.0, "circuits": 0.0, "propellant": 0.0 }
```

All pools initialized to 0.0 on new game and on retirement reset.

**Burst Cycle:** Every 150–250 ticks. Target chosen proportionally from revenue 
tracking (`speculator_target_scores`). Size: `randi_range(min, max) * pow(growth, burst_number)`. 
Burst amount added to the targeted resource's pool. `burst_number` is a global 
counter (not per-resource), so escalation applies regardless of which resource 
is targeted.

**Proportional Decay (per-pool, per-tick):**
```
for resource in speculators:
    speculators[resource] -= speculators[resource] * proportional_decay_rate
```
Default `proportional_decay_rate = 0.006`. At this rate, a burst clears ~70% 
in 200 ticks.

**Arbitrage Engine:** Adds flat decay to **every** pool independently:
```
for resource in speculators:
    speculators[resource] -= arbitrage_flat_decay_per_engine * num_arbitrage_engines
```
Default `arbitrage_flat_decay_per_engine = 0.04`.

**Nationalist Ideology Decay Boost:** `pow(1.05, nationalist_rank)` multiplier 
applied to both proportional decay and Arbitrage Engine flat decay, for all pools.

**Floor:** Each pool clamped to `max(0.0, value)` after decay.

**No cap on individual pools.** Decay is the only limiter.

### Disrupt Speculators Command

Reads the **global loading priority list** (the ordered resource list configured 
in the launch pad, independent of what is actually loaded or whether pads are 
active).

```
var priority_list = get_global_loading_priority()
var amount = randf_range(1.0, 3.0)

for resource in priority_list:
    if speculators[resource] > 0:
        speculators[resource] = max(0.0, speculators[resource] - amount)
        return  # one execution targets one pool

# If no priority-list resource has speculators > 0, do nothing.
# Command execution is consumed (not refunded).
```

### Adversaries Sidebar

One line per tradeable resource, shown via progressive disclosure: a resource's 
line appears once that pool has been > 0 at least once in the current run. 
Tracked via `speculators_ever_seen: Dictionary` (bool per resource) in GameState, 
reset on retirement.

```
▼ Adversaries
  Speculators (He-3)             0
  Speculators (Circuit Boards)  20
  Speculators (Propellant)       5
```

Uses `get_resource_display_name(resource_id)` for labels. If no resource has 
ever had speculators, the Adversaries section is hidden entirely.

### Speculator Intelligence (research-gated)

Shows per-resource pool counts and the suppression amount each pool is causing:

```
▼ Speculator Intelligence
  Circuit Boards: 20 speculators (demand -0.10)
  Propellant: 5 speculators (demand -0.02)
```

Only shows resources with `speculators_ever_seen == true`.

### Rival AIs
Four named rivals (ARIA-7/He-3, CRUCIBLE/Titanium, NODAL/Circuit Boards, 
FRINGE-9/Propellant). Each dumps every 150–250 ticks, -0.3 demand hit, recovers 
at 0.003/tick. Rival targeting behavior unchanged — they pick targets dynamically, 
not based on their associated resource.
