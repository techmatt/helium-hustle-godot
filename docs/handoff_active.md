# Helium Hustle — Active Development Status

---

## Changes Since Last Design Session

- 2026-04-03: Playtest telemetry system designed and prompted (PlaytestLogger 
  autoload, JSONL output to `<repo>/logs/`, per-run files, 100-tick snapshots)
- 2026-04-03: Telemetry fixes prompted (aggressive rounding, compact snapshot 
  format, missing event hooks for land/research/ideology, speculator count in 
  shipment events)
- 2026-04-03: Projects panel refactor prompted — tier-first grouping, "Long-Term 
  Projects" / "Strategic Projects" naming, compact completed display
- 2026-04-03: Retirement career bonuses designed and prompted — 4 career-high 
  stats with passive bonuses (starting credits, boredom resilience, buy power 
  scaling, ideology head start)
- 2026-04-03: Ideology rank formula reworked — geometric series replacing lookup 
  table, base cost 100, multiplier 1.5x, rank cap 99
- 2026-04-03: Pre-retirement panel designed and prompted — this-run stats, career 
  records with NEW indicators, next-run bonus preview with deltas
- 2026-04-03: Propellant Discovery event visibility fix prompted — hide 
  condition_met standalone events from Ongoing until triggered
- 2026-04-03: Save-on-close verification included in telemetry prompt
- 2026-04-03: Command partial production and output-cap skip identified as needed 
  (not yet prompted — design discussion complete, prompt pending)

---

## Implementation Status

### Complete (all tested)
- UI skeleton (three-column layout, light/dark mode)
- Resource tick loop (GameState, GameSimulation, GameManager)
- Building system (purchase, enable/disable, sell, stall tracking, cost scaling, 
  bonus buildings, ideology discounts, unlock gating, partial production, 
  producers-first processing order, no-upkeep buildings always produce)
- Program/processor system (5 tabs, command queues, execution model, 20 commands)
- Launch pad / shipment system (per-pad cards, loading, cooldown, recent launches)
- Speed controls (pause through 200x)
- Storage caps & display
- Boredom system (phase curve, milestone reductions, consciousness stub, Stats 
  panel rate display)
- Research system (12 items, 4 categories, per-item visibility gating, cost 
  modifiers, all passive effects verified working)
- Event system (triggers, conditions, unlock effects, persistence, dynamic 
  notifications, Events panel header, click-to-reread modals)
- Quest system (Q1–Q8 + Q_END, progress indicators)
- Stats panel (per-resource breakdown, stall indicators, boredom rate)
- Demand system (Perlin noise, 6 forces, DemandSystem class, speculator bleedover, 
  configurable demand ceiling)
- Speculators & rival AIs (bursts, decay, targeting, Arbitrage Engine, bleedover)
- Retirement system (forced/voluntary, summary screen, CareerState)
- Save/load persistence (single file, autosave, version 1)
- Project system (5 persistent + 5 personal, drain model, modifier framework, 
  all 6 modifiers verified working)
- Ideology system (3 axes, continuous bonuses, rank 5 projects)
- Headless test infrastructure (14+ suites, assertions covering all systems)
- Options panel (light/dark mode, debug: disable boredom, show all cards, 
  fill resources, clear save data)
- Propellant gating (event → research → building unlock chain)
- Progressive disclosure (resources, buildings, commands, research phased in based 
  on progression; CareerState lifetime tracking; ideology labels hidden until 
  unlocked; building card status row reserves space)
- Story panel (Primary Objectives section with quest chain display, Achievements 
  section with collapsible categories)
- Achievement system (6 achievements in 2 categories, tick-based and event-driven 
  condition checking, modifier and bonus building rewards, CareerState persistence)

### Prompted but Not Yet Verified
- Playtest telemetry system (PlaytestLogger autoload, JSONL logging)
- Telemetry fixes (rounding, compact format, missing hooks)
- Projects panel refactor (Long-Term / Strategic tier-first grouping)
- Retirement career bonuses (4 stats, passive bonuses, ideology formula rework)
- Pre-retirement panel (stats, career records, bonus preview with deltas)
- Propellant Discovery event visibility fix (hide standalone events from Ongoing)

### Python Optimizer (`sim/`)
- Scenario-based architecture
- Tick-accurate economy model (does NOT yet model demand system)
- Greedy optimizer with shadow pricing
- Buy commands as discrete actions
- 4-section terminal report + CSV tick report
- Score trace utility

---

## What's NOT Implemented Yet (rough priority order)

### Blocking Playtest Quality
1. **Command partial production & output-cap skip** — Buy commands waste inputs 
   when output is capped; need building-style skip and partial production logic. 
   Design complete, prompt not yet written.
2. **Playtest pass & pacing tuning** — manual Run 1 playthrough needed after 
   current prompted changes land
3. **Milestone boredom reduction tuning** — current values provisional

### Important for Arc 1 Completeness
4. **More achievements** — Programmer category, additional Miner/Trader, Scholar, 
   Diplomat, Veteran, Anomaly categories (see `handoff_achievements.md` for design)
5. **Narrative writing pass** — replace placeholder quest text
6. **Save/load programs** — loadout system for saving/loading program configs
7. **Block/Skip toggle** — per-program entry option
8. **Cross-retirement program persistence** — loadouts persist, active programs 
   reset (design details TBD: auto-apply? multiple named loadouts?)

### Polish & UI Enhancement
9. **Speculator Intelligence UI** — display burst timing/targets/size after 
   research (data exists in GameState, needs UI design decisions)
10. **Recent Launches color coding** — color by profitability or demand tier
11. **Retirement forecast display** — "retire in ~N days" on status bar
12. **Ideology UI polish** — low priority
13. **Story panel "Active" label size fix** — currently too small, should match 
    section headers

### Optimizer & Balancing
14. **Optimizer demand model sync** — mirror Godot demand system in `sim/economy.py`
15. **Optimizer scenario refinement** — fix broken `he3_50` objective, sync all 
    changes including ideology formula
16. **Run 2+ scenarios** — validate meta-progression pacing with career bonuses

---

## Arc 1 Milestone Graph

Internal design framework milestones (not player-facing):

**M1 — First Light** (Run 1, early): Self-sustaining energy.
**M2 — First Shipment** (Run 1, mid): Full pipeline working.
**M3 — Program Awakening** (Run 1–2): First meaningful automation.
**M4 — First Retirement** (End of Run 1): Boredom fills.
**M5 — Positive Credit Flow** (Runs 2–4): Reliable income.
**M6 — Speed Becomes Useful** (Runs 3–5): Automation + speed synergy.
**M7 — Boredom Management** (Runs 4–8): Dream/research extends runs.
**M8 — Diversified Trade** (Runs 5–8): Multiple resource types shipped.
**M9 — Credit Surplus** (Runs 5–10): Economy outpaces spending.
**M10 — Market Manipulation** (Runs 6–10): Promote + Disrupt active.
**M11 — First Major Project** (Runs 8–15): Persistent project completed.
**M12 — Adversary Subverted** (Runs 8–15): Speculators managed.
**M13 — Ideology Influence** (Runs 10–18): Rank 3+ in an axis.
**M14 — Timeline Unlocked** (Runs 15–20): Arc 1 → Arc 2.

Graph: M5/M6/M7 simultaneous → M8/M9/M10 overlap → M11/M12 converge → M13 → M14.

---

## Current Optimizer State

Run 1 scenario produces build order: Excavator → Smelter → Refinery → first 
shipment → Data Centers → Research Lab → Retirement ~tick 805.

**Known issues:** Optimizer does not model demand system, ideology bonuses, 
proportional speculator decay, partial production, or propellant gating. Needs 
full sync before re-running. The `he3_50` objective is structurally broken 
(violates objective design principle #6). Boredom parameters need updating. 
Ideology formula has changed (see handoff_systems.md).

---

## Claude Code Prompts Produced This Session

1. `projects_panel_refactor.md` — tier-first grouping, Long-Term / Strategic naming
2. `playtest_telemetry.md` — PlaytestLogger system + save-on-close verification
3. `retirement_career_bonuses.md` — career-high stats, bonuses, ideology formula 
   rework, rank cap 99
4. `retire_panel.md` — pre-retirement panel with stats, records, bonus preview
5. `telemetry_fixes.md` — rounding, compact snapshots, missing hooks
6. `fix_propellant_event.md` — hide standalone events from Ongoing until triggered

---

## Future Design Ideas

### UI Enhancements
- **Retirement Forecast:** "At current rates, retirement in ~N days"
- **Program Efficiency Feedback:** Success/fail ratio after a full cycle
- **Contextual Building Suggestions:** Highlight Solar Panel when energy-negative
- **Program Starter Templates:** Built-in templates for empty programs
- **Status Tracker in Event Panel:** Active conditions display

### Milestone Boredom Reduction Ideas (not yet implemented)
Major milestones should grant large boredom reductions to create memorable moments:
- First launch earning more than X credits: -30 boredom
- First research cluster unlocked: -15 to -20 boredom
- Crossing a credits-per-tick threshold: -15 boredom

### Arc 2+ Ideas
- **Configurable Storage:** Storage Depots with player-allocated capacity budget
- **Research Evolution:** Talent-tree with reallocatable points
- **Consciousness Declaration:** Optional per-run toggle
- **Timeline Reset and Foregone Tech:** Uncompleted persistent projects create 
  alternative paths
- **Opposition Modeling:** Reducing cross-axis ideology penalty
