# Helium Hustle — Achievement System Design

This document covers the achievement system: categories, specific achievements, 
conditions, rewards, the Story panel UI, and plans for future achievements. For 
how achievements integrate with the modifier framework, CareerState, and tick 
order, see `handoff_systems.md`.

---

## Story Panel

### Nav Button
The left sidebar button is labeled "Story" (renamed from "Achievements"). Opens 
a center panel with two sections: Primary Objectives and Achievements.

### Primary Objectives Section
Displays the quest chain (Q1–Q_END) as a vertical list:

- **Completed quests:** Checkmark, quest name, one-sentence summary, what it 
  unlocked. Clicking opens EventModal with full event text (does not pause).
- **Active quest:** Highlighted, shows condition text and progress indicator.
- **Future quests:** Completely hidden until the prior quest completes.

Completed quests from prior runs show as completed. The active quest also appears 
in the Events panel under "Story (1)" as an at-a-glance reminder.

### Achievements Section
Below Primary Objectives. Header shows overall completion counter (e.g., 
"2 / 6 completed"). Collapsible category sections, each with their own count. 
Categories are collapsed by default.

Each achievement entry shows:
- Name (bold)
- Condition (one-line player-readable text)
- Reward (shown in green when completed, dimmed when incomplete)

At the bottom of each category: "N hidden achievements" in muted text (for future 
temporal or secret achievements). Currently 0 hidden per category.

---

## Achievement Architecture

### Data
Defined in `godot/data/achievements.json` (ground truth). Each achievement has: 
`id`, `name`, `category`, `description`, `condition_type`, `condition_params`, 
`reward_type`, `reward_params`, `reward_description`.

### Condition Checking
- **Tick-based:** Checked at end of each tick (after clamp, before advance day). 
  Iterates all incomplete achievements.
- **Event-driven:** Shipment-related conditions checked at moment of shipment 
  completion, with revenue and demand values passed to the achievement manager.

### Per-Tick Tracking
The building loop and program execution loop accumulate transient per-tick values:
- `tick_production[resource]` — gross production before consumption or clamping
- `tick_consumption[resource]` — total consumed by buildings and programs

These are reset at start of each tick and used by conditions like 
`resource_produced_per_tick` and `resource_consumed_per_tick`.

### Condition Types
| Type | Params | Checked |
|------|--------|---------|
| `resource_produced_per_tick` | resource, threshold | End of tick |
| `resource_consumed_per_tick` | resource, threshold | End of tick |
| `resource_stockpile` | resource, threshold | End of tick |
| `shipments_this_run` | threshold | End of tick |
| `shipment_revenue` | threshold | On shipment completion |
| `shipment_demand` | threshold | On shipment completion |

### Reward Types
| Type | Params | Effect |
|------|--------|--------|
| `modifier` | key, value | Adds to `active_modifiers` (multiplicative) |
| `bonus_buildings` | building, count | Grants free buildings on run start |

### Persistence
Completed achievement IDs in `CareerState.achievements`. Rewards re-applied on 
every run start:
- Modifiers added to `active_modifiers`
- Bonus buildings granted with `bonus_count` mechanism (no cost inflation)

### Completion Notification
Dynamic notification in Events panel: "Achievement Unlocked: [Name] — [Reward]"

---

## Current Achievements

### Miner Category

**Strip Mining**
- Condition: Produce 40+ regolith in a single tick.
- Type: `resource_produced_per_tick` (resource: reg, threshold: 40)
- Reward: +10% regolith production (`excavator_output_mult: 1.10`)
- Note: `excavator_output_mult` applies only to Regolith Excavator, separate from 
  `extractor_output_mult` (which covers both Excavator and Ice Extractor).

**Silicon Valley**
- Condition: Have 1,000+ circuit boards in stockpile.
- Type: `resource_stockpile` (resource: cir, threshold: 1000)
- Reward: +10% storage cap for physical resources (`storage_cap_mult: 1.10`)
- Note: Applies to Regolith, Ice, He-3, Titanium, Circuits, Propellant. Does NOT 
  apply to Energy (that's Battery's domain).

**Powerhouse**
- Condition: Consume 100+ energy in a single tick.
- Type: `resource_consumed_per_tick` (resource: eng, threshold: 100)
- Reward: 2 bonus Batteries at start of each run (`bonus_buildings: battery, 2`)
- Note: Uses same `bonus_count` mechanism as Foundation Grant. Does not inflate 
  Battery purchase cost scaling.

### Trader Category

**First Profit**
- Condition: Complete a shipment earning 1,000+ credits.
- Type: `shipment_revenue` (threshold: 1000)
- Reward: +10% shipment credit payout (`shipment_credit_mult: 1.10`)

**Bulk Shipper**
- Condition: Complete 10 shipments in a single run.
- Type: `shipments_this_run` (threshold: 10)
- Reward: +10% cargo capacity per pad (`cargo_capacity_mult: 1.10`)
- Note: Multiplies base cargo loaded per Load Launch Pads execution (5 base, 
  7 with Shipping Efficiency).

**Market Timer**
- Condition: Complete a shipment when demand is above 0.95.
- Type: `shipment_demand` (threshold: 0.95)
- Reward: Demand ceiling raised to 1.1 (`demand_ceiling: 1.10`)
- Note: Changes demand clamp from [0.01, 1.0] to [0.01, 1.1]. Demand can now 
  exceed 1.0, meaning shipments during peak demand pay more than previously possible.

---

## Planned Future Categories

These are not yet implemented. Achievement counts are rough targets.

### Programmer (~8–12 achievements)
Program system mastery. Rewards: processor-related bonuses, command cost reductions, 
program output multipliers. Examples: complete a full program cycle, run N programs 
simultaneously, complete N cycles without failures.

### Scholar (~6–8 achievements)
Research and science milestones. Rewards: science production, research cost 
discounts. Examples: purchase all research in a single run, accumulate N science.

### Diplomat (~6–8 achievements)
Ideology and project milestones. Rewards: ideology gain rate, project drain 
bonuses. Examples: reach rank 3 in any axis, complete a persistent project, have 
positive and negative ideology ranks simultaneously.

### Veteran (~8–12 achievements)
Cross-run career milestones. Rewards: starting resource bonuses, boredom curve 
shifts. Examples: retire N times, earn N lifetime credits, survive N total days, 
complete all quests.

### Anomaly (~6–10 achievements, hidden)
Secret/joke/edge-case achievements. Hidden until earned (shown as "??? — ???" or 
counted as "N hidden achievements" at bottom of section). Rewards: small universal 
bonuses or cosmetic. Examples: get speculators to exactly 0, fill all programs with 
Dream, trigger a 0-credit shipment, reach boredom 999 and voluntarily retire.

---

## Design Principles

### Reward Philosophy
Each achievement gives a meaningful, specific reward (+10–15% to a particular 
system). No meta-bonuses (no "X% per N achievements"). Rewards are thematically 
tied to the achievement's category. All rewards are permanent (CareerState) and 
re-applied every run.

### Reward Stacking
Achievement modifiers stack multiplicatively with existing modifiers from projects, 
research, and ideology. For example, `excavator_output_mult` from Strip Mining 
(1.10) stacks with `extractor_output_mult` from Deep Core Survey project.

### Difficulty Curve
Achievements should be achievable within the first few runs but require intentional 
play. They are not automatic — the player needs to build toward them. Later 
categories (Veteran, Anomaly) will span many runs.

### Hidden Achievements
Future Anomaly/secret achievements will be hidden until earned. The category header 
shows "N hidden achievements" to hint at their existence. Names and conditions are 
revealed only on completion.

### Temporal Gating
Some future achievements may be gated behind Arc progression, specific run counts, 
or other preconditions. The bottom of each category section shows "N hidden 
achievements" to account for these without revealing specifics.
