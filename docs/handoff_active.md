# Helium Hustle — Active Development Status

---

## Changes Since Last Design Session

- 2026-04-06: Speculator per-resource pools redesign prompted — 4 independent 
  pools (one per tradeable resource), remove bleedover, Disrupt targets loading 
  priority order, 4-line Adversaries sidebar, Arbitrage Engine applies to all 
  pools, Speculator Intelligence updated.
- 2026-04-06: Buy Power scaling formula fix prompted — changed from 
  `1.0 + floor(peak/20) * 0.25` to `1.0 + max(0, peak - 100) * 0.01`. No 
  bonus until peak energy production exceeds 100.
- 2026-04-06: Rate display units prompted — all player-facing rates changed 
  from `/s` and `/tick` to `/day`.
- 2026-04-06: Boredom cap reduction + Recreation Dome prompted — base cap 
  1000→500, Recreation Dome building (+100 cap per active unit, Humanist, 
  300cr/30circuits/3land, gated on QHorizon), Dream Protocols threshold 300→200.
- 2026-04-06: Quest ID rename + multi-objective sidebar prompted — all quest 
  IDs changed to semantic names (QPower, QExtract, QShipment, QAutomate, 
  QMarket, QHorizon, QEnd), Events sidebar shows sub-objective checklist for 
  multi-objective quests, click-to-open dialog shows sub-objectives.
- 2026-04-06: Building display fixes prompted — research requirement shows 
  display name, Recreation Dome gated on QHorizon (not visible at start), 
  moved to Storage category, Infrastructure category removed.
- 2026-04-06: Retirement summary modal pause fix prompted — game must pause 
  when modal appears, verify forced retirement uses dynamic boredom cap.
- 2026-04-06: Retirement panel redesign prompted — merged This Run + Career 
  Records into single section with RECORD badges, hide inactive bonuses, 
  source hints on bonus lines.
- 2026-04-06: Bonus building active count bug fix prompted — bonus buildings 
  should have active_count incremented on grant.
- 2026-04-06: Data Center Fabricator requirement removal prompted.
- 2026-04-06: Building category merge prompted — Power + Processors → Core.
- 2026-04-06: Game speed control bar improvement prompted — icon pause button, 
  spacing, active highlight, remove section header.
- 2026-04-06: Launch pad pause/play icon toggle prompted — replace text button 
  with SVG icon toggle using pause.svg/play.svg.
- 2026-04-05: Handoff file restructure — split `handoff_systems.md` into 7 
  domain-specific files. Added `handoff_index.md` as the opening document.
- 2026-04-05: Fuel Cell Array building + Chemical Energy Initiative project 
  prompted — new building (propellant → energy), gated on persistent project, 
  gated on QHorizon active. Nationalist alignment.
- 2026-04-05: Quest chain revision prompted — removed old Q5 (Revenue Target), 
  Q7 (First Legacy), Q8 (Influence). Renumbered Market Awareness → Q5. Added 
  Q6 (Open Horizons) multi-objective quest with 4 sub-goals.

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

### Prompted But Not Yet Verified
These Claude Code prompts have been produced but implementation may be in progress 
or not yet confirmed working:
- Speculator per-resource pools (4 pools, no bleedover, Disrupt loading priority)
- Buy Power scaling formula fix (threshold 100, coefficient 0.01)
- Rate display units (/day everywhere)
- Boredom cap 500 + Recreation Dome (+100/dome, QHorizon gated, Storage category)
- Dream Protocols visibility threshold (300→200)
- Quest ID rename (semantic IDs: QPower through QEnd)
- Multi-objective quest sidebar display (sub-objective checklist in Events panel)
- Retirement panel redesign (merged sections, RECORD badges, source hints)
- Retirement summary modal pause fix
- Bonus building active count bug fix
- Data Center Fabricator requirement removal
- Building category merge (Power + Processors → Core)
- Game speed control bar improvement (icon pause, spacing, highlight)
- Launch pad pause/play icon toggle
- Building research requirement display names
- Recreation Dome visibility gating (QHorizon)
- Quest chain revision (Q5 removed, Market Awareness→Q5, Q6 Open Horizons 
  multi-objective, Q7/Q8 removed)
- Fuel Cell Array building + Chemical Energy Initiative project
- Production overhaul (multi-pass resolution, overflow, command partial production)
- Building resolution epsilon (floating point false stall fix)
- Command boredom cost tracking in `lifetime_boredom_sources`
- Command rate tracking in Stats panel (all resource effects, not just energy)
- Launch pad pause toggle (replacing "None (disabled)")
- Progressive disclosure re-gating (current-run nav buttons, event-gate respect)
- "New" item indicators (gold dot/accent bar on newly revealed elements)
- Retirement panel UI polish (card-style bonuses, section headers)
- Research purchase affordability bug fix
- Nav progressive disclosure (Launch Pads, Research button gating)
- Retirement panel bug fixes (dark mode dialog, Buy Power format string)
- Ideology nav visibility fix
- Lifetime stats cards
- Milestone system removal

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
1. **Land all prompted changes** — verify the prompted changes above are 
   implemented and tests pass, then do a clean playtest
2. **Playtest pass & pacing tuning** — manual Run 1-2-3 playthrough needed with 
   telemetry to validate pacing, progressive disclosure flow, career bonus feel. 
   Note: boredom phase curve was calibrated for 0–1000 cap and may need retuning 
   for the new 500 base cap.

### Important for Arc 1 Completeness
3. **More achievements** — Programmer category, additional Miner/Trader, Scholar, 
   Diplomat, Veteran, Anomaly categories (see `handoff_achievements.md` for design). 
   Some achievements should include boredom reduction rewards (replacing the removed 
   milestone system's pacing role).
4. **Narrative writing pass** — replace placeholder quest text
5. **Save/load programs** — loadout system for saving/loading program configs
6. **Block/Skip toggle** — per-program entry option
7. **Cross-retirement program persistence** — loadouts persist, active programs 
   reset (design details TBD: auto-apply? multiple named loadouts?)

### Polish & UI Enhancement
8. **Speculator Intelligence UI** — display per-resource pool counts and 
   suppression amounts after research (data exists in GameState, needs UI)
9. **Recent Launches color coding** — color by profitability or demand tier
10. **Retirement forecast display** — "retire in ~N days" on status bar
11. **Ideology UI polish** — low priority
12. **Story panel "Active" label size fix** — currently too small, should match 
    section headers

### Optimizer & Balancing
13. **Optimizer production model sync** — update `sim/economy.py` to use multi-pass 
    resolution, overflow model, command partial production
14. **Optimizer demand model sync** — mirror Godot demand system in `sim/economy.py`
15. **Optimizer scenario refinement** — fix broken `he3_50` objective, sync all 
    changes including ideology formula, remove milestone references
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
proportional speculator decay, multi-pass building resolution, overflow model, 
command partial production, per-resource speculator pools, dynamic boredom cap, 
or propellant gating. Needs full sync before re-running. The `he3_50` objective 
is structurally broken (violates objective design principle #6). Boredom 
parameters need updating (cap now 500 base). Ideology formula has changed (see 
`handoff_progression.md`). Milestone system has been removed.

---

## Claude Code Prompts Produced This Session

### Current session (2026-04-06)
1. `speculator_per_resource_pools.md` — 4 independent per-resource speculator 
   pools, remove bleedover, Disrupt targets loading priority order
2. `fix_buy_power_scaling.md` — formula: `1.0 + max(0, peak - 100) * 0.01`
3. `retirement_panel_redesign.md` — merged sections, RECORD badges, source hints, 
   hide inactive bonuses
4. `rate_display_units.md` — all player-facing rates to /day
5. `boredom_cap_recreation_dome.md` — cap 1000→500, Recreation Dome +100/dome, 
   Dream Protocols threshold 300→200
6. `quest_id_rename_and_sidebar.md` — semantic quest IDs, multi-objective sidebar
7. `building_display_fixes.md` — research requirement names, Recreation Dome 
   gating + Storage category
8. `merge_building_categories.md` — Power + Processors → Core
9. `fix_retirement_modal_pause.md` — pause on modal, verify dynamic cap
10. `fix_bonus_building_active.md` — active_count increment on bonus grant
11. `fix_data_center_requirement.md` — remove Fabricator requirement
12. `pause_play_icon_toggle.md` — launch pad pause/play SVG icons
13. `improve_speed_controls.md` — icon pause, spacing, highlight, remove header

### Prior session (2026-04-05)
14. `quest_chain_revision.md` — revised quest chain
15. `fuel_cell_array.md` — Fuel Cell Array building + Chemical Energy Initiative

### Earlier prompts (see prior handoff_active.md for full list)
16–30. Production overhaul, building fixes, progressive disclosure, retirement 
    panel polish, research bug, nav gating, ideology fix, lifetime stats, 
    milestone removal, etc.

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
