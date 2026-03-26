# Optimizer Design: Scenario-Based Single-Lifetime Optimization

## Two Different Concepts — Don't Conflate Them

**Design milestones (M1–M14)** are the progression framework from the handoff 
doc. They describe the player's journey across multiple runs and retirements. 
Many are qualitative ("speed becomes useful," "credit surplus") and span 
multiple lifetimes. These are design vocabulary for reasoning about pacing. 
**They are not optimization targets.**

**Optimizer objectives** are concrete, measurable states within a single 
simulated run. "Accumulate 50 He-3" is measurable. "Build a Data Center" is 
measurable. The optimizer chases these as fast as possible within one lifetime.

Design milestones inform which scenarios to simulate and what starting 
conditions to use. Optimizer objectives are what the optimizer actually scores 
against within each scenario.

## Architecture: Scenario-Based Runs

Each scenario represents a "type of run" at a different stage of meta-
progression. The optimizer always simulates a single lifetime with specified 
starting conditions and concrete objectives.

```
sim/
  economy.py          ← tick-accurate economic model (unchanged)
  optimizer.py         ← greedy/beam search over purchase orderings (unchanged)
  run_optimizer.py     ← CLI entry point: loads a scenario, runs optimizer
  scenarios/
    run1_fresh.json
    run2_foundation.json
    run5_trade.json
    run10_ideology.json
```

### Scenario File Format

```json
{
  "name": "Run 1 — Fresh Start",
  "description": "Brand new player, no persistence, no research.",

  "starting_conditions": {
    "resources": {
      "eng": 100, "reg": 0, "ice": 0, "he3": 0,
      "ti": 0, "cir": 0, "prop": 0, "cred": 50,
      "sci": 0, "land": 20, "boredom": 0
    },
    "buildings": { "panel": 1, "excavator": 1 },
    "processors": 1,
    "research": [],
    "persistent_rewards": []
  },

  "available_actions": {
    "buildings": [
      "panel", "excavator", "ice_extractor", "smelter", "refinery",
      "fabricator", "electrolysis", "launch_pad", "research_lab",
      "data_center", "battery", "storage_depot"
    ],
    "commands": [
      "idle", "cloud_compute", "buy_regolith", "buy_ice",
      "buy_titanium", "buy_propellant", "load_pads", "launch_pads"
    ],
    "notes": "No research-gated commands available. No Arbitrage Engine."
  },

  "objectives": [
    { "id": "smelter",       "type": "building",  "value": "smelter",    "target": [40, 100] },
    { "id": "refinery",      "type": "building",  "value": "refinery",   "target": [100, 200] },
    { "id": "he3_50",        "type": "resource",  "value": "he3",  "threshold": 50, "target": [200, 350] },
    { "id": "first_ship",    "type": "event",     "value": "shipment_complete",    "target": [350, 500] },
    { "id": "data_center",   "type": "building",  "value": "data_center","target": [150, 300] },
    { "id": "research_lab",  "type": "building",  "value": "research_lab","target": [200, 400] },
    { "id": "retirement",    "type": "event",     "value": "boredom_100","target": [900, 1300] }
  ],

  "command_policy": "auto",

  "end_condition": { "type": "boredom", "threshold": 100 }
}
```

### Field Definitions

**starting_conditions** — Overrides for resources, buildings, processors, 
research state, and persistent project rewards. Represents "what does tick 0 
look like for this type of run?"

**available_actions** — Which buildings and commands the optimizer is allowed 
to use. Gates research-locked commands out of early scenarios. The optimizer 
should not consider actions outside this list.

**objectives** — Ordered list of concrete targets. Each has:
- `id`: unique name for reporting
- `type`: one of `building` (building exists), `resource` (resource ≥ 
  threshold), `event` (specific game event fired)
- `target`: [min_tick, max_tick] — the window where this objective should 
  land for an optimal player. If it lands before min, constants are too 
  easy. If after max, too hard.

**command_policy** — How the reference program operates. `"auto"` means the 
optimizer picks from a set of program templates (e.g., "cloud compute heavy," 
"trade cycle," "dream-balanced"). Can also be a fixed program definition for 
controlled experiments.

**end_condition** — When the run ends. Usually boredom hitting 100.

### Planned Scenarios

**run1_fresh.json** — Brand new player. No persistence, no research-gated 
commands. Validates the core building/resource loop and that the first 
lifetime has a satisfying arc from nothing to productive operation to 
retirement. This is the primary tuning scenario.

**run2_foundation.json** — Post-first-retirement. Modest passive scaling 
bonuses. Validates that Run 2 feels faster than Run 1 by the right amount. 
Objectives shift to include first research cluster purchase.

**run5_trade.json** — Experienced player, Foundation Grant completed (free 
starting solar panel + excavator beyond base). Research is routine. Validates 
that the trade/shipment loop is the dominant income source and that market 
manipulation (Promote, Disrupt) creates meaningful value.

**run10_ideology.json** — Late Arc 1. Player is pushing toward rank 5 in a 
chosen ideology. Validates that ideology investment is feasible within a 
single extended run and that the rank 5 project unlock is reachable within 
the target lifetime range.

## Optimizer Scoring

For each scenario, the optimizer scores a trajectory by how close each 
objective lands to the center of its target window. Objectives that land 
inside the window score 0 (perfect). Objectives outside the window score 
proportional to distance from the nearest edge. The total score is the sum 
across all objectives.

This means the optimizer isn't just "go fast" — it's "hit the target 
windows." If an objective lands too early, the constants are too easy and 
should be tightened.

## Workflow

1. Start with `run1_fresh.json`. Tune constants until all objectives land 
   in their windows.
2. Without changing constants, run `run2_foundation.json` with post-
   retirement starting conditions. Check that objectives shift earlier 
   by a reasonable amount (15-25%).
3. Iterate: if Run 2 is too fast, persistence rewards are too strong. If 
   too slow, they're too weak.
4. Extend to later scenarios as systems come online.

## Relationship to Design Milestones

The handoff's M1–M14 milestones map onto scenarios like this:

| Design Milestone | Scenario | Optimizer Objective |
|-----------------|----------|-------------------|
| M1 First Light | run1 | (starting condition — satisfied at tick 1) |
| M2 First Shipment | run1 | first_ship event |
| M3 Program Awakening | run1 | data_center building |
| M4 First Retirement | run1 | boredom_100 end condition |
| M5 Positive Credit Flow | run2–run5 | sustained_credits resource threshold |
| M6 Speed Becomes Useful | run2–run5 | qualitative — not directly optimized |
| M7 Boredom Management | run5 | research_self_maintenance + dream usage |
| M8–M14 | run5–run10 | TBD as systems are implemented |

Not every design milestone needs a corresponding optimizer objective. 
Qualitative milestones like M6 are validated by inspection, not optimization.
