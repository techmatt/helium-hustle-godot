# Helium Hustle — Programs & Commands

For exact numbers (costs, rates, thresholds), see `handoff_constants.md`.

---

## Execution Model

- 5 program tabs, each with a command queue.
- Processors assigned to programs via +/−/Reset. Total processors = active Data 
  Centers.
- Each processor executes one command step per tick.
- Top-to-bottom execution. Failed commands advance the pointer anyway.
- On wrap (reaching end of queue), all progress bars and failed highlights reset.
- Multiple processors on same program share instruction pointer.

## Retirement Behavior

Program slots persist structurally but command queues are emptied, instruction 
pointers reset, processor assignments reset.

## Command Categories

Basic (always available), Trade, Operations, Advanced. Commands beyond Basic 
require research or building unlocks. See `handoff_constants.md` for the full 
command list.

## Command Visibility (Progressive Disclosure)

A command is visible if any of these are true: (1) it has no unlock requirement 
(Basic category), (2) its unlock requirement is currently satisfied, (3) its ID 
is in `career_state.lifetime_used_command_ids`. The "Show All Cards" debug toggle 
overrides visibility gating. Buy Ice is gated on owning an Ice Extractor.

Command visibility uses lifetime tracking. Commands the player has used before 
remain visible.

## Command Output-Cap Skip

Buy commands that produce capped resources (Buy Titanium, Buy Propellant, Buy Ice, 
Buy Power) skip execution (advance pointer, don't pay inputs) when ALL of their 
output resources are at or above storage cap. This is intentional — commands are 
player-authored automation, and wasting processor ticks on capped output is a 
signal to fix the program.

Check output caps BEFORE computing partial production. If all outputs are at cap, 
skip entirely. If at least one output has headroom, proceed to partial production.

## Command Partial Production

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

## Command Boredom Costs

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

## Command Rate Tracking

All resource effects of command execution (not just energy) are tracked in the 
per-source rate tracking system (ResourceRateTracker) for display in the Stats 
panel's instantaneous and rolling average resource breakdown cards. This includes 
boredom from Dream and Sell Cloud Compute, credits from Sell Cloud Compute, 
resources from Buy commands, etc. Source labels use the program label format 
(e.g., "Program 1 (1 proc)").

## Key Design Intent

Buy commands are intentionally 3-5x the cost of building-based production per 
unit. They exist for tactical gap-bridging, not as a primary resource strategy. 
Buy Propellant is an exception early game when Electrolysis is locked. Buy 
Titanium produces 1 titanium per execution, serving as the early-game titanium 
source before Smelter is unlocked.
