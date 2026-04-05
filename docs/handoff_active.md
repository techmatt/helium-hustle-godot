# Helium Hustle — Active Development Status

---

## Changes Since Last Design Session

- 2026-04-04: Production overhaul designed and prompted — removed output-cap skip 
  for buildings, implemented multi-pass building resolution (Phase 1 iterative full 
  production + Phase 2 partial production), end-of-tick clamp with overflow tracking, 
  command partial production for Buy commands, command output-cap skip (commands DO 
  skip when output at cap, unlike buildings)
- 2026-04-04: Nav progressive disclosure prompted — Launch Pads visible when 
  player owns ≥1 Launch Pad, Research visible when player owns ≥1 Research Lab 
  (both respect CareerState lifetime tracking)
- 2026-04-04: Retirement panel bug fixes prompted — dark mode dialog in light mode, 
  Buy Power scaling format string displayed literally instead of interpolated
- 2026-04-04: Consistent resource display names prompted — all player-facing names 
  from `resources.json` `display_name` field via helper, "Circuit Boards" as 
  canonical name (not "Circuits")
- 2026-04-04: Ideology nav visibility fix prompted — Ideologies button and sidebar 
  section hidden until Ideology Unlock event fires (Geopolitical Intelligence 
  research completion)
- 2026-04-04: Lifetime stats cards designed and prompted — "Lifetime Totals" 
  section in Stats panel with Boredom (Lifetime) and Credits (Lifetime) breakdown 
  cards, per-source tracking
- 2026-04-04: Milestone boredom reduction system removed — milestones overlapped 
  with quests and achievements, boredom reduction role to be absorbed into future 
  achievement batch

---

## Implementation Status

### Complete (all tested)
- UI skeleton (three-column layout, light/dark mode)
- Resource tick loop (GameState, GameSimulation, GameManager)
- Building system (purchase, enable/disable, sell, stall tracking, cost scaling, 
  bonus buildings, ideology discounts, unlock gating, multi-pass resolution with 
  partial production, overflow tracking)
- Program/processor system (5 tabs, command queues, execution model, 20 commands, 
  command partial production for Buy commands, output-cap skip for Buy commands)
- Launch pad / shipment system (per-pad cards, loading, cooldown, recent launches)
- Speed controls (pause through 200x)
- Storage caps & display
- Boredom system (phase curve, consciousness stub, Stats panel rate display)
- Research system (12 items, 4 categories, per-item visibility gating, cost 
  modifiers, all passive effects verified working)
- Event system (triggers, conditions, unlock effects, persistence, dynamic 
  notifications, Events panel header, click-to-reread modals)
- Quest system (Q1–Q8 + Q_END, progress indicators)
- Stats panel (per-resource breakdown, stall indicators, boredom rate, overflow 
  display, lifetime totals section with boredom and credits breakdown)
- Demand system (Perlin noise, 6 forces, DemandSystem class, speculator bleedover, 
  configurable demand ceiling)
- Speculators & rival AIs (bursts, decay, targeting, Arbitrage Engine, bleedover)
- Retirement system (forced/voluntary, pre-retirement panel with stats/records/
  bonus preview, CareerState)
- Save/load persistence (single file, autosave, version 1)
- Project system (5 persistent + 5 personal, drain model, modifier framework, 
  all 6 modifiers verified working, tier-first panel layout)
- Ideology system (3 axes, continuous bonuses, rank 5 projects, geometric series 
  formula, rank cap 99)
- Headless test infrastructure (14+ suites, assertions covering all systems)
- Options panel (light/dark mode, debug: disable boredom, show all cards, 
  fill resources, clear save data)
- Propellant gating (event → research → building unlock chain)
- Progressive disclosure (resources, buildings, commands, research, nav buttons 
  phased in based on progression; CareerState lifetime tracking; ideology labels 
  and sidebar hidden until unlocked; building card status row reserves space)
- Story panel (Primary Objectives section with quest chain display, Achievements 
  section with collapsible categories)
- Achievement system (6 achievements in 2 categories, tick-based and event-driven 
  condition checking, modifier and bonus building rewards, CareerState persistence)
- Career bonuses (starting credits, boredom resilience, buy power scaling, 
  ideology head start — 4 stats derived from career bests)
- Playtest telemetry (PlaytestLogger autoload, JSONL logging, point events, 
  periodic snapshots)
- Consistent resource display names (all from `resources.json` `display_name`)

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
1. **Playtest pass & pacing tuning** — manual Run 1-2-3 playthrough needed with 
   telemetry to validate pacing, progressive disclosure flow, career bonus feel

### Important for Arc 1 Completeness
2. **More achievements** — Programmer category, additional Miner/Trader, Scholar, 
   Diplomat, Veteran, Anomaly categories (see `handoff_achievements.md` for design). 
   Some achievements should include boredom reduction rewards (replacing the removed 
   milestone system's pacing role).
3. **Narrative writing pass** — replace placeholder quest text
4. **Save/load programs** — loadout system for saving/loading program configs
5. **Block/Skip toggle** — per-program entry option
6. **Cross-retirement program persistence** — loadouts persist, active programs 
   reset (design details TBD: auto-apply? multiple named loadouts?)

### Polish & UI Enhancement
7. **Speculator Intelligence UI** — display burst timing/targets/size after 
   research (data exists in GameState, needs UI design decisions)
8. **Recent Launches color coding** — color by profitability or demand tier
9. **Retirement forecast display** — "retire in ~N days" on status bar
10. **Ideology UI polish** — low priority
11. **Story panel "Active" label size fix** — currently too small, should match 
    section headers

### Optimizer & Balancing
12. **Optimizer production model sync** — update `sim/economy.py` to use multi-pass 
    resolution, overflow model, command partial production
13. **Optimizer demand model sync** — mirror Godot demand system in `sim/economy.py`
14. **Optimizer scenario refinement** — fix broken `he3_50` objective, sync all 
    changes including ideology formula, remove milestone references
15. **Run 2+ scenarios** — validate meta-progression pacing with career bonuses

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
proportional speculator decay, multi-pass building resolution, overflow model, 
command partial production, or propellant gating. Needs full sync before 
re-running. The `he3_50` objective is structurally broken (violates objective 
design principle #6). Boredom parameters need updating. Ideology formula has 
changed (see handoff_systems.md). Milestone system has been removed.

---

## Claude Code Prompts Produced This Session

1. `production_overhaul.md` — multi-pass building resolution, overflow model, 
   command partial production, command output-cap skip, end-of-tick clamp
2. `nav_progressive_disclosure.md` — Launch Pads and Research nav button gating
3. `fix_retirement_panel.md` — dark mode dialog fix, Buy Power format string fix
4. `consistent_resource_names.md` — display names from JSON, "Circuit Boards" 
   canonical name
5. `fix_ideology_nav.md` — Ideologies button and sidebar hidden until unlock
6. `lifetime_stats.md` — Boredom and Credits lifetime breakdown cards in Stats
7. `remove_milestones.md` — remove milestone boredom reduction system

---

## Future Design Ideas

### UI Enhancements
- **Retirement Forecast:** "At current rates, retirement in ~N days"
- **Program Efficiency Feedback:** Success/fail ratio after a full cycle
- **Contextual Building Suggestions:** Highlight Solar Panel when energy-negative
- **Program Starter Templates:** Built-in templates for empty programs
- **Status Tracker in Event Panel:** Active conditions display

### Achievement Boredom Rewards (replacing removed milestones)
Some achievements should grant one-time boredom reductions as rewards, replacing 
the pacing role that the removed milestone system served. These create visible, 
discoverable moments rather than invisible mechanics. Candidate triggers:
- First profitable launch (earning more than X credits): large boredom reduction
- First research cluster unlocked: moderate boredom reduction
- Crossing a credits-per-tick threshold: moderate boredom reduction

### Arc 2+ Ideas
- **Configurable Storage:** Storage Depots with player-allocated capacity budget
- **Research Evolution:** Talent-tree with reallocatable points
- **Consciousness Declaration:** Optional per-run toggle
- **Timeline Reset and Foregone Tech:** Uncompleted persistent projects create 
  alternative paths
- **Opposition Modeling:** Reducing cross-axis ideology penalty
