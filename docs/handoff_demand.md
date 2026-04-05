# Helium Hustle — Demand System

For exact numbers (costs, rates, thresholds), see `handoff_constants.md`.

---

## Overview

Per-resource continuous demand float in [0.01, demand_ceiling]. The demand ceiling 
defaults to 1.0 and can be raised by the Market Timer achievement to 1.1. Six 
forces: Perlin noise (exogenous), speculator suppression, rival AI dumps, shipment 
saturation, Promote commands, resource coupling. ~80% player-influenceable, ~20% 
from noise and rivals.

## Demand Calculation (per tick)

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

## Noise

1D gradient noise with quintic interpolation. 4-octave fractal sum with irrational 
frequency multipliers. Per-resource randomized frequencies in [0.025, 0.07], 
re-randomized each retirement.

## Speculator Suppression (asymptotic, targeted resource only)

```
max_suppression = 0.5, half_point = 50.0
suppression = max_suppression * (count / (count + half_point))
```

## Speculator Bleedover (non-targeted resources)

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

## Demand Display

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
