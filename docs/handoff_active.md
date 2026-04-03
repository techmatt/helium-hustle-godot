# Helium Hustle — Active Development Status

---

## Changes Since Last Design Session

- 2026-04-02: Events panel header added ("Events" title matching center panel style)
- 2026-04-02: Click-to-reread events implemented (click any event entry to open 
  EventModal without pausing)
- 2026-04-02: Building processing order fixed (producers before consumers)
- 2026-04-02: Production-gated skip fixed (no-upkeep buildings always produce)
- 2026-04-02: Boredom rate now shown in Stats panel as a line item
- 2026-04-02: `tech_spec.md` and `program_system_spec.md` deleted from repo 
  (fully superseded by handoff files)
- 2026-04-02: Story panel implemented (Primary Objectives + Achievements sections)
- 2026-04-02: Achievement system implemented (6 initial achievements: 3 Miner, 
  3 Trader, with condition checking, rewards, persistence)
- 2026-04-02: Completed quests migrated from Events panel to Story panel
- 2026-04-02: New modifier keys added: `excavator_output_mult`, `storage_cap_mult`, 
  `shipment_credit_mult`, `cargo_capacity_mult`, `demand_ceiling`

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
- Options panel (light/dark mode, debug: disable boredom, show all cards)
- Propellant gating (event → research → building unlock chain)
- Progressive disclosure (resources, buildings, commands, research phased in based 
  on progression; CareerState lifetime tracking; ideology labels hidden until 
  unlocked; building card status row reserves space)
- Story panel (Primary Objectives section with quest chain display, Achievements 
  section with collapsible categories)
- Achievement system (6 achievements in 2 categories, tick-based and event-driven 
  condition checking, modifier and bonus building rewards, CareerState persistence)

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
1. **Playtest pass & pacing tuning** — manual Run 1 playthrough needed
2. **Milestone boredom reduction tuning** — current values provisional

### Important for Arc 1 Completeness
3. **More achievements** — Programmer category, additional Miner/Trader, Scholar, 
   Diplomat, Veteran, Anomaly categories (see `handoff_achievements.md` for design)
4. **Narrative writing pass** — replace placeholder quest text
5. **Save/load programs** — loadout system for saving/loading program configs
6. **Block/Skip toggle** — per-program entry option
7. **Cross-retirement program persistence** — loadouts persist, active programs reset

### Polish & UI Enhancement
8. **Speculator Intelligence UI** — display burst timing/targets/size after research 
   (data exists in GameState, purely UI task)
9. **Recent Launches color coding** — color by profitability or demand tier
10. **Retirement forecast display** — "retire in ~N days" on status bar
11. **Ideology UI polish** — low priority

### Optimizer & Balancing
12. **Optimizer demand model sync** — mirror Godot demand system in `sim/economy.py`
13. **Optimizer scenario refinement** — fix broken `he3_50` objective, sync all changes
14. **Run 2+ scenarios** — validate meta-progression pacing

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
