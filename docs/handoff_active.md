# Helium Hustle — Active Development Status

---

## Changes Since Last Design Session

_(Add entries here when making changes directly via Claude Code without a 
claude.ai design session. Format: date, what changed, one line.)_

- 2026-03-31: Partial production replaces input-starvation skip and residual drain.
  Buildings with insufficient inputs now run at reduced capacity (fraction = min of
  available/needed across all inputs). All inputs/outputs scale proportionally.
  Resources naturally drain to zero. Stall flag preserved for UI. No-production
  buildings (Battery, Storage Depot, Launch Pad, Data Center) unaffected.
  New `test_partial_production.gd` suite (8 tests); all 1341 tests passing.
- 2026-03-31: Research passive effects audit — all 4 research effects and 6 project
  modifiers verified working via new `test_passive_effects.gd` suite (~10 new tests).
- 2026-03-31: Research progressive disclosure — per-item visible_when conditions
  replace category-based science gating. Items appear when players encounter the
  relevant problem. Ideology Lobbying renamed to Geopolitical Intelligence (ID:
  geopolitical_intelligence), gated on Q7 completion. Category headers hide when
  empty. New test_research_visibility.gd suite (12 tests); all 1396 tests passing.
- 2026-03-31: Progressive disclosure system — resources/buildings/commands hidden until
  earned; CareerState lifetime tracking; `building_count` requires type; ideology lobbying
  merged to single `ideology_lobbying` research; `show_all_cards` debug toggle; Solar Panel
  cost updated to 20 cred + 10 ti; Buy Ice requires ice_extractor; Buy Titanium yields 1.0
  ti; new `test_progressive_disclosure.gd` suite (7 tests); all 1307 tests passing.

---

## Implementation Status

### Complete (all tested)
- UI skeleton (three-column layout, light/dark mode)
- Resource tick loop (GameState, GameSimulation, GameManager)
- Building system (purchase, enable/disable, sell, stall tracking, cost scaling, 
  bonus buildings, ideology discounts, unlock gating)
- Program/processor system (5 tabs, command queues, execution model, 20 commands)
- Launch pad / shipment system (per-pad cards, loading, cooldown, recent launches)
- Speed controls (pause through 200x)
- Storage caps & display
- Boredom system (phase curve, milestone reductions, consciousness stub)
- Research system (13 items, 4 categories, visibility gating, cost modifiers, 
  all passive effects verified working)
- Event system (triggers, conditions, unlock effects, persistence, dynamic notifications)
- Quest system (Q1–Q8 + Q_END, progress indicators)
- Stats panel (per-resource breakdown, stall indicators)
- Demand system (Perlin noise, 6 forces, DemandSystem class)
- Speculators & rival AIs (bursts, decay, targeting, Arbitrage Engine)
- Retirement system (forced/voluntary, summary screen, CareerState)
- Save/load persistence (single file, autosave, version 1)
- Project system (5 persistent + 5 personal, drain model, modifier framework, 
  all 6 modifiers verified working)
- Ideology system (3 axes, continuous bonuses, rank 5 projects)
- Headless test infrastructure (13 suites, 1396 assertions)
- Options panel (light/dark mode, debug: disable boredom, show all cards)
- Propellant gating (event → research → building unlock chain)
- Progressive disclosure (resources/buildings/commands hidden until earned; CareerState
  lifetime tracking; building_count requires type; ideology lobbying merged)

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
1. ~~Research passive effects audit~~ ✅ DONE
2. **Playtest pass & pacing tuning** — manual Run 1 playthrough needed
3. **Milestone boredom reduction tuning** — current values provisional

### Important for Arc 1 Completeness
4. **Achievement system** — design pass needed before implementation (implicit 
   tutorial function)
5. **Narrative writing pass** — replace placeholder quest text
6. **Save/load programs** — loadout system for saving/loading program configs
7. **Block/Skip toggle** — per-program entry option
8. **Cross-retirement program persistence** — loadouts persist, active programs reset

### Polish & UI Enhancement
9. **Speculator Intelligence UI** — display burst timing/targets/size after research 
   (data exists in GameState, purely UI task)
10. **Recent Launches color coding** — color by profitability or demand tier
11. **Retirement forecast display** — "retire in ~N days" on status bar
12. **Ideology UI polish** — low priority

### Optimizer & Balancing
13. **Optimizer demand model sync** — mirror Godot demand system in `sim/economy.py`
14. **Optimizer scenario refinement** — fix broken `he3_50` objective, sync all changes
15. **Run 2+ scenarios** — validate meta-progression pacing

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
proportional speculator decay, or propellant gating. Needs full sync before 
re-running. The `he3_50` objective is structurally broken (violates objective 
design principle #6). Boredom parameters need updating.

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
