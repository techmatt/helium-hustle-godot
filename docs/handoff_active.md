# Helium Hustle — Active Development Status

---

## Changes Since Last Design Session

- 2026-04-05: Handoff file restructure — split `handoff_systems.md` into 7 
  domain-specific files. Added `handoff_index.md` as the opening document.
- 2026-04-05: Fuel Cell Array building + Chemical Energy Initiative project 
  prompted — new building (propellant → energy), gated on persistent project, 
  gated on Q6 active. Nationalist alignment.
- 2026-04-05: Quest chain revision prompted — removed old Q5 (Revenue Target), 
  Q7 (First Legacy), Q8 (Influence). Renumbered Market Awareness → Q5. Added 
  Q6 (Open Horizons) multi-objective quest with 4 sub-goals.
- 2026-04-04: Command boredom cost tracking fix prompted — generic tracking of 
  command boredom costs in `lifetime_boredom_sources` (e.g., Sell Cloud Compute 
  0.1 boredom/execution). Clarified that command boredom costs are base command 
  properties, NOT gated on AI Consciousness Act.
- 2026-04-04: Building resolution epsilon prompted — `RESOURCE_EPSILON = 0.001` 
  tolerance on Phase 1 upkeep affordability checks to prevent floating point 
  false stalls.
- 2026-04-04: Command rate tracking fix prompted — all command resource effects 
  (boredom, credits, resources) should appear in Stats panel instantaneous/rolling 
  avg breakdown, not just energy.
- 2026-04-04: Launch pad pause toggle prompted — replaces "None (disabled)" 
  dropdown with per-pad pause button. Paused pads skip Load/Launch commands, 
  retain resource+cargo, manual Launch still works, yellow tint. Saved/loaded, 
  resets on retirement.
- 2026-04-04: Progressive disclosure re-gating prompted — nav buttons (Launch Pads, 
  Research) gate on current-run ownership only (no lifetime override). Building 
  visibility lifetime override does NOT override research/event gates. Resources 
  and commands keep lifetime visibility.
- 2026-04-04: "New" item indicators prompted — gold/amber dot on nav buttons, 
  gold left accent bar on cards/rows when items transition hidden→visible mid-run. 
  Cleared on click/hover. Ephemeral, not saved.
- 2026-04-04: Retirement panel UI polish prompted — card-style career bonus rows 
  with colored accent bars, green "▲ NEW" badges, compact "What Persists", section 
  header backgrounds.
- 2026-04-04: Research purchase bug prompted — affordability check not recognizing 
  sufficient science for purchase.
- 2026-04-04: Production overhaul prompted (prior session) — multi-pass building 
  resolution, overflow model, command partial production, command output-cap skip, 
  end-of-tick clamp.
- 2026-04-04: Nav progressive disclosure prompted (prior session) — Launch Pads 
  and Research nav button gating.
- 2026-04-04: Retirement panel bug fixes prompted (prior session) — dark mode 
  dialog, Buy Power format string.
- 2026-04-04: Consistent resource display names prompted (prior session).
- 2026-04-04: Ideology nav visibility fix prompted (prior session).
- 2026-04-04: Lifetime stats cards prompted (prior session).
- 2026-04-04: Milestone boredom reduction system removed (prior session).

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
   telemetry to validate pacing, progressive disclosure flow, career bonus feel

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
8. **Speculator Intelligence UI** — display burst timing/targets/size after 
   research (data exists in GameState, needs UI design decisions)
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
command partial production, or propellant gating. Needs full sync before 
re-running. The `he3_50` objective is structurally broken (violates objective 
design principle #6). Boredom parameters need updating. Ideology formula has 
changed (see `handoff_progression.md`). Milestone system has been removed.

---

## Claude Code Prompts Produced This Session

### Current session (quest chain + fuel cell + restructure)
1. `quest_chain_revision.md` — revised quest chain: remove Q5/Q7/Q8, renumber 
   Market Awareness→Q5, add Q6 Open Horizons multi-objective quest
2. `fuel_cell_array.md` — Fuel Cell Array building + Chemical Energy Initiative 
   persistent project

### Prior session (playtest + polish)
3. `fix_command_boredom_tracking.md` — generic command boredom cost tracking in 
   `lifetime_boredom_sources`
4. `fix_building_stall_epsilon.md` — floating point epsilon for building upkeep 
   affordability checks
5. `fix_command_rate_tracking.md` — all command resource effects in Stats panel 
   instantaneous/rolling avg breakdown
6. `launch_pad_pause_toggle.md` — pause button replacing "None (disabled)" dropdown
7. `fix_progressive_disclosure_regating.md` — current-run nav gating, event-gate 
   respect for building visibility
8. `new_item_indicators.md` — gold dot/accent bar "new" indicators
9. `retirement_panel_polish.md` — card-style career bonuses, section headers, 
   compact layout
10. `fix_research_purchase.md` — research affordability check bug

### Earlier session (production overhaul + cleanup)
11. `production_overhaul.md` — multi-pass building resolution, overflow model, 
    command partial production, command output-cap skip, end-of-tick clamp
12. `nav_progressive_disclosure.md` — Launch Pads and Research nav button gating
13. `fix_retirement_panel.md` — dark mode dialog fix, Buy Power format string fix
14. `consistent_resource_names.md` — display names from JSON, "Circuit Boards" 
    canonical name
15. `fix_ideology_nav.md` — Ideologies button and sidebar hidden until unlock
16. `lifetime_stats.md` — Boredom and Credits lifetime breakdown cards in Stats
17. `remove_milestones.md` — remove milestone boredom reduction system

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
