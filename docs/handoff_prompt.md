# Helium Hustle — Development Context Handoff

## Instructions for Claude

Read this entire document carefully, then respond: "Ready. I've read the Helium 
Hustle handoff." Do not summarize or ask questions until prompted.

Also read the "Helium Hustle Game Design" document in the user's Google Drive 
for the full creative vision. This handoff document is the authoritative source 
for decisions already made; the Game Design doc provides broader context.

**This document must be fully self-contained.** Every design decision, parameter, 
and specification should be recorded here in full detail. Do not use phrases like 
"unchanged from prior handoff" or "see prior handoff" — if information is relevant, 
it must be present in this document. Prior handoffs will not be available in future 
sessions.

**This document is used by both claude.ai (for design discussions) and Claude Code 
(for implementation).** Write all specifications with enough detail that either 
context can act on them without additional clarification.

At the end of this session, produce an updated version of this handoff document 
incorporating all new decisions, following the same format and including these 
same instructions at the top. The user will save it and attach it to the next 
session. Only one file should be produced.

---

## What This Is

Helium Hustle is an idle game built in Godot 4.x (GDScript). You play as an AI 
managing helium-3 mining on the Moon. The game has a long-term arc involving rival 
AIs, a hegemonizing swarm, and time travel prestiges. The current development focus 
is building a playable Arc 1 — the core economic loop within the boredom-retirement 
cycle.

## Key Documents (in Google Drive, "Helium Hustle" folder)
- **Helium Hustle Game Design** — full creative vision, game stages, all planned systems
- **Helium Hustle Technical Spec** — MVP-scoped architecture (OUT OF DATE — will be 
  updated after first pass over all mechanics)
- **Helium Hustle Datasheets** — Google Sheet used for visual editing only; the 
  JSON files are ground truth (see Data Pipeline below)

## Repository Structure
```
godot/
  project.godot
  data/
    buildings.json         ← GROUND TRUTH for building definitions
    resources.json         ← GROUND TRUTH for resource definitions
    commands.json          ← GROUND TRUTH for command definitions
    research.json          ← GROUND TRUTH for research definitions
    events.json            ← GROUND TRUTH for event definitions
    projects.json          ← GROUND TRUTH for project definitions
    game_config.json       ← GROUND TRUTH for starting state, boredom, shipment, demand, etc.
  scenes/
    main_ui.tscn           ← Main scene (three-column layout)
    ui/BuildingCard.tscn
    ui/BuyLandCard.tscn    ← Buy Land card (full-width, top of Buildings panel)
    ui/CommandRow.tscn     ← Program command row (reusable)
    ui/LaunchPadCard.tscn  ← Launch pad widget (full-width)
    ui/EventPanel.tscn     ← Event panel (lower right panel)
    ui/EventModal.tscn     ← Event modal dialog (center-screen overlay)
    ui/StatsPanel.tscn     ← Stats panel (center panel view)
    ui/RetirementSummary.tscn  ← Retirement summary modal
    ui/RetirementPanel.tscn    ← Retirement nav panel (center panel view)
    ui/ProjectPanel.tscn   ← Project panel (center panel view)
    ui/ProjectCard.tscn    ← Project card (reusable)
  scripts/
    game/
      game_state.gd        ← class_name GameState — pure data, no UI
      game_simulation.gd   ← class_name GameSimulation — core economy logic, no UI
      demand_system.gd     ← class_name DemandSystem — demand/speculator/rival logic
      game_manager.gd      ← autoload singleton, owns state + sim
      event_manager.gd     ← class_name EventManager — event logic, no UI
      resource_rate_tracker.gd ← class_name ResourceRateTracker — per-source rate tracking
      career_state.gd      ← class_name CareerState — cross-run persistent data
      save_manager.gd      ← class_name SaveManager — disk save/load utility
      project_manager.gd   ← class_name ProjectManager — project drain/unlock/completion logic
    ui/
      main_ui.gd           ← Main UI controller
      building_card.gd     ← BuildingCard (PanelContainer subclass)
      buy_land_card.gd     ← BuyLandCard widget
      command_row.gd       ← CommandRow for program list
      launch_pad_card.gd   ← LaunchPadCard widget
      event_panel.gd       ← Event panel UI
      event_modal.gd       ← Event modal UI
      stats_panel.gd       ← Stats panel UI
      retirement_summary.gd ← Retirement summary modal UI
      retirement_panel.gd   ← Retirement panel UI
      project_panel.gd     ← Project panel UI
      project_card.gd      ← Project card UI
  assets/fonts/            ← Rajdhani Bold, Exo 2 Regular/SemiBold

data/
  convert.py               ← converts xlsx → JSON (round-trip for visual editing)
  json_to_xlsx.py          ← converts JSON → xlsx (round-trip for visual editing)
  Helium Hustle Datasheets.xlsx  ← human-readable intermediate, NOT ground truth

sim/
  constants.py             ← loads all game data from godot/data/*.json for the sim
  economy.py               ← pure state machine: EconState, tick_once, buy_building, etc.
  optimizer.py             ← greedy scorer: run_greedy, shadow pricing, urgency bonuses
  run_optimizer.py         ← CLI entry point: loads scenario, runs optimizer, prints report
  trace.py                 ← score-trace utility for debugging optimizer decisions
  scenarios/
    run1_fresh.json        ← scenario definition for a fresh Run 1

docs/
  handoff_prompt.md        ← this file
  program_system_spec.md   ← full program system UI spec (4 stages)
  project_system_spec.md   ← project system implementation spec
  quest_system_revision.md ← quest chain revision spec
  optimizer_design.md      ← optimizer architecture spec (scenario-based approach)
  tech_spec.md             ← MVP technical spec (OUT OF DATE)
```

## Data Pipeline

**The JSON files in `godot/data/` are ground truth.** The xlsx and Google Sheet 
are human-readable intermediates for visual editing only.

```
godot/data/*.json              ← GROUND TRUTH (committed, edited directly)

Round-trip for visual editing:
  python data/json_to_xlsx.py  → data/Helium Hustle Datasheets.xlsx  (JSON → xlsx)
  (edit xlsx in spreadsheet app)
  python data/convert.py       → godot/data/*.json                   (xlsx → JSON)
```

`sim/constants.py` loads directly from `godot/data/*.json` at runtime. It is NOT 
a separate source of truth — if you change the JSON files, the sim picks up the 
changes automatically.

### Implementation Note
All resources are **float internally**, displayed as integers or one decimal place 
depending on context. This avoids rounding edge cases with fractional production 
rates, Overclock multipliers, demand floats, etc. We prefer integer values in the 
data files where possible; fractional values are reserved for systems that 
inherently need them (circuit production, demand floats, etc.). Avoid displaying 
too many decimal places in the UI — round to integers or one decimal where possible.

---

## Tempo & Tick Assumptions

- **1 tick = 1 day** (may be revised to 1 tick = 1 hour if pacing requires it)
- **Early runs: ~800–1,100 ticks** for optimal play, target ~1,500 ticks for 
  casual play (~30 min real-time at mixed speeds).
- **Energy budget target: ~25 energy/tick** at comfortable mid-run.
- Solar panels produce 6 energy/tick each. Players need 4-5 panels for a 
  comfortable mid-run energy budget.

---

## What's Been Implemented (as of this handoff)

### In Godot

1. **UI skeleton** — three-column layout: left sidebar (nav buttons, speed controls, 
   resource list), center panel (buildings/commands/launch pads/stats/projects), 
   right panel (programs top, events bottom). Bottom status bar with system uptime, 
   boredom bar, energy bar.

2. **Light mode UI** — consistent light color scheme. White card backgrounds, light 
   panel backgrounds (#E8E8E8 sidebars, #F5F5F5 center), dark text, green/red 
   color-coded production/upkeep. Rajdhani (headers) + Exo 2 (body) fonts. Light 
   button backgrounds with subtle borders for all interactive elements.

3. **Resource tick loop** — GameState, GameSimulation with tick(), GameManager 
   autoload singleton. Resources tick in real time. Buildings produce and consume 
   resources.

4. **Building system** — buildings loaded from JSON, purchasable by clicking 
   anywhere on the card (no separate Buy button). Building cards show in center 
   panel with category headers (Power, Storage, Processors, Extraction, Processing).
   - **Enable/disable:** Each building has active_count and owned_count. Header 
     shows "(3/4)" with −/+ buttons to disable/enable individual buildings. 
     Disabled buildings don't produce, consume, or grant effects, but still 
     occupy land.
   - **Sell controls:** "Sell 1" and "Sell All" buttons in bottom-right of card. 
     Sell All requires confirmation (double-click). Selling refunds land only, 
     no credit refund.
   - **Production-gated upkeep:** Buildings with production outputs skip upkeep 
     on ticks where ALL their produced resources are at storage cap. Buildings 
     with no production (Battery, Storage Depot, Launch Pad, Data Center) always 
     pay upkeep. This is automatic — separate from manual enable/disable.
   - **Input-starvation skip:** Buildings with production outputs skip their entire 
     tick (no production, no upkeep) if any of their upkeep input resources has a 
     current stockpile below the building's per-tick consumption. Buildings with no 
     production outputs are exempt (always pay upkeep). This stacks with the 
     output-at-cap rule — either condition independently causes the building to skip.
   - **Unlock requirements enforcement:** Buildings with a non-empty `requires` 
     field are visible but not purchasable until the requirement is met. Locked 
     buildings show the requirement text and are dimmed. Purchase logic in 
     GameSimulation also enforces this (defense in depth).
   - **Stall indicators:** Buildings track stall status per tick in 
     `GameState.building_stall_status`. Two stall types: `input_starved` (shown 
     in orange on building card and as muted line item in Stats panel) and 
     `output_capped` (shown in green). Stats panel shows stalled buildings as 
     line items with reason text even when they produce nothing.
   - **Bonus building cost scaling:** Buildings granted free by persistent projects 
     (e.g., Foundation Grant) track `bonus_count` separately. Cost scaling uses 
     `max(0, owned_count - bonus_count)` so free buildings don't inflate the 
     purchase price curve.

5. **Program/processor system** — fully implemented (see Programs & Processors 
   section for design details):
   - 5 program tabs in right panel (fixed height) with processor assignment (+/−/Reset)
   - Command queue per program: reorderable rows with repeat count, progress 
     bars, −/+/× controls
   - Commands view in center panel (via left nav) with Add buttons per command
   - Command cards grouped by category (Basic, Trade, Operations, Advanced)
   - Locked commands visible but Add disabled, showing research requirement
   - Execution: top-to-bottom, failed rows turn red, resets on wrap
   - Program panel UI throttled to ~10fps at high game speeds

6. **Launch pad / shipment system** — fully implemented (see Shipment & Trade 
   Economy section for design details):
   - Launch Pads nav button in left sidebar, dedicated center panel view
   - Per-pad cards (full-width): resource type dropdown, cargo bar (0/100 with 
     numbers on bar, proportional fill), estimated credit value (uses live demand), 
     manual Launch button
   - Loading priority: collapsible reorderable list of 4 tradeable goods
   - Each pad assigned one resource type via dropdown
   - 10-tick cooldown after launch before pad is available again
   - Recent Launches display (last 3–5 launches with day, resource, quantity, 
     credits earned) — shared notification queue with rival AI dump notifications
   - Earth Demand section with tier labels (before Market Awareness research) or 
     full demand detail with sparklines (after research)

7. **Speed controls** — pause through 200x working.

8. **Storage caps & cap display** — resource list shows current/cap format 
   (e.g. "47/100").

9. **Bottom status bar** — boredom bar (color-ramped, 50-tick rolling average 
   rate) + energy bar (blue, instantaneous net rate). Both with overlaid text 
   values. Not throttled at high speeds.

10. **Research system** — implemented. Research items loaded from research.json, 
    purchasable with science. Category-based visibility gating by cumulative 
    science earned. Research panel in center panel via left nav. Includes 
    Propellant Synthesis research (gated behind `propellant_discovery` event, 
    visible via `event_seen` check against CareerState).

11. **Event system** — EventManager (pure logic) + EventPanel (lower right panel) + 
    EventModal (center-screen overlay). Three collapsible sections: Story, Ongoing, 
    Completed. Events defined in events.json. First-time events auto-open modal and 
    pause; previously-seen events appear silently. Auto-pause on modal events.
    - **Unlock effects wired:** `enable_building`, `enable_nav_panel`, 
      `enable_project`, `set_flag`.
    - **Unlock persistence across retirements:** On run start, all unlock effects 
      from previously completed events (in `career_state.seen_event_ids`) are 
      re-applied to GameState. This ensures building unlocks, nav panel visibility, 
      project availability, and flags survive retirement.
    - **Nav panel gating:** Retirement, Projects, and Ideologies panels start hidden 
      and unlock via event effects.
    - **Dynamic notifications:** EventManager supports dynamic (non-events.json) 
      notifications for project completions and similar mechanical events.

12. **Quest system** — story quests implemented as events with category `"story"`. 
    Full quest chain Q1–Q8 + Q_END defined in events.json. Always-active-quest 
    constraint enforced by Q_END (uncompletable cap quest with `never` condition). 
    Quests explicitly labeled "Q1 —", "Q2 —", etc. Progress indicators shown in 
    Story section for threshold conditions. See Quest Chain section for full details.

13. **Stats panel** — center panel view via "Stats" nav button. Per-resource income/ 
    expense breakdown using ResourceRateTracker with 50-tick moving averages. 
    Collapsible sections per resource showing per-source line items. Stalled 
    buildings shown as muted line items with reason. Career Bonuses section 
    (placeholder). Throttled to ~4fps.

14. **Buy Land card** — full-width card at top of Buildings panel. Shows land 
    usage, next purchase cost, and Buy button. 15 credit base, 1.5x scaling, 
    10 land per purchase.

15. **Resource list improvements** — ordered Boredom/Energy/Processors/Land first, 
    then remaining resources. Processor display shows assigned/total. Per-tick 
    net rates shown inline for each resource (green positive, red negative, muted 
    zero). Cap coloring: dark green at cap, dark red at zero for capped resources.

16. **Boredom phase signal** — GameState tracks `current_boredom_phase` (int, 
    initialized to 1, resets on retirement). Phase determined by day counter 
    using boredom curve. Signal emitted on phase transitions. EventManager listens 
    for this signal to fire `boredom_phase` trigger events.

17. **Cumulative resource counters** — `cumulative_resources_earned: Dictionary` 
    in GameState. Incremented whenever a resource is produced. Only goes up. 
    Resets on retirement. Used by research visibility gating and quest conditions.

18. **Milestone boredom reductions** — `triggered_milestones: Array[String]` in 
    GameState (resets on retirement). Milestones defined in `game_config.json`. 
    Checked at end of each tick. Consciousness hook stub called on all boredom 
    reductions.
    Current milestones:
    - `first_shipment_credits`: shipment_completed >= 1, boredom -250
    - `first_research`: research_completed_any, boredom -150
    - `credits_threshold`: cumulative credits >= 500, boredom -150

19. **Demand system** — full implementation. Per-resource continuous demand float 
    in range [0.01, 1.0]. Six forces: Perlin noise, speculator suppression, rival 
    AI dumps, shipment saturation, Promote commands, resource coupling. Extracted 
    into DemandSystem class. See Demand System section for full specification.

20. **Adversaries sidebar section** — collapsible "Adversaries" section in left 
    sidebar. Shows speculator count and current target resource.

21. **Retirement system** — implemented and tested. Forced retirement at boredom 
    1000 (hard cutoff). Voluntary retirement via Retirement nav panel (unlocked 
    by Q3). Retirement summary screen. CareerState tracks persistent data. Quest 
    unlocks persist across retirements via re-application on run start.

22. **Save/load persistence** — implemented and tested. Single save file at 
    `user://helium_hustle_save.json`. Mid-run autosave (on pause, every 60s, on 
    quit). Resume on game launch.

23. **Project system** — implemented. 5 persistent + 5 personal projects. 
    Drain-over-time model with per-resource compact steppers. See Projects section 
    for full specification.

24. **Modifier framework** — `active_modifiers: Dictionary` in GameState with 
    `get_modifier(key, default)` / `set_modifier(key, value)`. Applied at specific 
    points in GameSimulation and DemandSystem. See Modifier Framework section.

25. **Propellant gating** — Electrolysis Plant requires `propellant_synthesis` 
    research. Research is hidden until `propellant_discovery` event completes 
    (fires at 4 shipments). On subsequent runs, research is visible from start 
    (checked via `career_state.seen_event_ids`). Early game forces Buy Propellant 
    command usage.

### In the Python Optimizer (`sim/`)

1. **Scenario-based architecture** — optimizer loads scenario JSON files that 
   define starting conditions, available actions, objectives with target windows, 
   and end conditions.
2. **Tick-accurate economy model** (`economy.py`) — pure state machine matching 
   the Godot tick order. Buildings, programs (fixed policy), shipments, boredom, 
   storage caps all modeled. Includes production-gated upkeep, input-starvation 
   skip, and per-pad launch mechanics with cooldown. **Does not yet model the 
   demand system** — uses static demand. TODO: sync demand model to match Godot.
3. **Greedy optimizer** (`optimizer.py`) — shadow pricing + urgency bonuses + 
   sighted lookahead baseline.
4. **Buy commands as discrete actions** — appear in the optimizer's action space 
   alongside building purchases.
5. **4-section terminal report** — build order, objective timing, resource 
   snapshots, structural summary. Plus CSV tick report.
6. **Score trace utility** (`trace.py`) — prints full scoring tables at specific 
   ticks.

---

## What's NOT Implemented Yet (in rough priority order)

1. **Ideology system** — see Ideology section. Needed for Q8 quest and rank-5 
   persistent projects.
2. **Research passive effects audit** — verify boredom_rate_multiplier, 
   command_cost_override, overclock_cap, load_per_execution all work in gameplay.
3. **Save/load programs** — loadout system for saving/loading program configs
4. **Block/Skip toggle** — per-program entry option
5. **Cross-retirement program persistence** — loadouts persist, active programs 
   reset
6. **Achievement system** — design pass needed before implementation
7. **Narrative writing pass** — replace placeholder quest text
8. **Milestone boredom reduction tuning** — current values are provisional
9. **Optimizer sync** — mirror demand system, proportional speculator decay, 
   propellant gating, and all recent changes in sim/economy.py

---

## Architecture Notes

- Game logic (GameState, GameSimulation) has no UI references — designed for 
  headless simulation support (which now exists in `sim/`).
- Tick order: Boredom → Buildings (energy net first, then resources; production-
  gated upkeep and input-starvation skip applied) → Demand Update → Programs → 
  Projects → Shipments (using current demand, apply launch saturation hits) → 
  Speculator Revenue Tracking → Speculator/Rival Burst Check → Clamp → Events → 
  Advance day.
- Buildings process in JSON row order (Solar Panel first).
- Building costs: `base_cost × (scaling ^ purchased_count)` where 
  `purchased_count = max(0, owned_count - bonus_count)`. Land cost per building is 
  constant but land itself has escalating purchase cost.
- Building production/upkeep uses `active_count` (not `owned_count`). Only active 
  buildings produce, consume, and grant effects.
- Program panel UI updates are throttled to ~10fps regardless of game speed.
- Event panel and Stats panel updates also throttled (~10fps and ~4fps respectively).
- Project panel updates throttled to ~4fps.
- **DemandSystem is a separate class** (`demand_system.gd`), extracted from 
  GameSimulation. Owns all demand config, Perlin noise, speculator/rival logic.
- **ProjectManager is a separate class** (`project_manager.gd`). Owns project 
  definitions, unlock checks, drain processing, completion logic.

### Design Rule: No Same-Resource Production and Upkeep

**No building should both produce and consume the same resource.** This creates 
confusing stats breakdowns and doesn't add meaningful gameplay. Consolidate to 
the net value in the data.

---

## Design Philosophy

- The program/processor system is the game's core identity. It's both the 
  automation mechanic and the primary skill expression for experienced players.
- Boredom is a speed governor, not a punishment. It prevents fast-forwarding 
  through learning.
- The game should be interesting at max speed. Players design scripts, then 
  accelerate.
- Keep the first milestone simple: is the building/resource/program loop fun?
- Buildings = infrastructure decisions (what you build, capital allocation).
- Programs = operational decisions (logistics timing, market manipulation, burst 
  production).

---

## Current Game Constants (as committed in repo)

### Starting State (`game_config.json`)
- Energy: 100, Credits: 0, Land: 40, Boredom: 0
- All physical resources (reg, ice, he3, ti, cir, prop, sci): 0
- Starting buildings: Solar Panel ×1, Data Center ×1
- Starting processors: 1 (from the Data Center)
- Foundation Grant (if completed): adds +1 Solar Panel, +1 Excavator as bonus 
  buildings (don't affect cost scaling)

### Key Building Stats
| Building | Credit Cost | Scaling | Land | Production | Upkeep |
|----------|-----------|---------|------|------------|--------|
| Solar Panel | 8 | 1.20 | 1 | 6 eng | — |
| Excavator | 12 | 1.25 | 1 | 2 reg | 2 eng |
| Ice Extractor | 25 | 1.25 | 1 | 1 ice | 2 eng |
| Smelter | 40 | 1.25 | 1 | 1 ti | 3 eng, 2 reg |
| Refinery | 60 | 1.25 | 2 | 1 he3 | 3 eng, 2 reg |
| Fabricator | 100 | 1.30 | 2 | 0.5 cir | 5 eng, 1 reg |
| Electrolysis | 50 | 1.25 | 1 | 2 prop | 2 ice, 1 eng |
| Launch Pad | 150 | 1.30 | 3 | — | 1 eng |
| Research Lab | 120 | 1.30 | 2 | 1 sci | 3 eng, 0.2 cir |
| Data Center | 200 | 1.35 | 2 | — (grants 1 proc) | 4 eng |
| Battery | 30 | 1.35 | 0 | — (+50 eng cap) | — |
| Storage Depot | 35 | 1.25 | 1 | — (multi-resource caps) | — |
| Arbitrage Engine | 180 | 1.30 | 1 | — (spec decay +0.04/tick) | 3 eng |

**Electrolysis Plant** requires `propellant_synthesis` research (gated behind 
4 shipments event). Early game, players must buy propellant via commands.

**Launch Pad** requires Q2 quest completion (`enable_building` effect).

### Key Command Costs
| Command | Costs | Production | Notes |
|---------|-------|------------|-------|
| Idle | — | 1 cred | Zero cost filler |
| Sell Cloud Compute | 3 eng | 5 cred | +0.4 boredom per execution |
| Buy Regolith | 8 cred + 2 eng | 1 reg | Tactical gap-bridging |
| Buy Ice | 10 cred + 2 eng | 1 ice | Tactical gap-bridging |
| Buy Titanium | 20 cred + 3 eng | 0.5 ti | Expensive, fractional output |
| Buy Propellant | 12 cred + 2 eng | 1 prop | Critical early game before Electrolysis |
| Dream | 8 eng (5 with research) | — | -2 boredom per execution (requires research) |

Buy commands are intentionally expensive — 3-5x the cost of building-based 
production per unit. They exist for tactical gap-bridging, not as a primary 
resource strategy. Buy Propellant is an exception early game when Electrolysis 
is locked — it's the only source of propellant for the first ~4 launches.

### Propellant Economy (Early Game)
At average demand (0.5), a full He-3 launch earns ~1,000 credits. Buying 20 
propellant for that launch costs 240 credits + 40 energy (24% of revenue). 
This is intentionally painful enough to make the Electrolysis unlock feel 
meaningful, but not so painful that launching is unprofitable. Titanium launches 
are more impacted (40% of revenue to propellant), circuit launches less (16%).

### Land System
- Base cost: 15 credits, scaling: 1.5x per purchase
- 10 land per purchase
- Starting land: 40
- Buy Land card at top of Buildings panel (full-width, not in any category dropdown)

---

## Resource Flow — Arc 1 Economy

### Raw Extraction (both consume energy)
- **Regolith Excavator** — energy → regolith
- **Ice Extractor** — energy → ice

### Processing Buildings (each has one clear purpose)
- **Refinery** — regolith + energy → He-3
- **Smelter** — regolith + energy → titanium
- **Fabricator** — regolith + energy (lots) → circuit boards
- **Electrolysis Plant** — ice + energy → propellant (requires research unlock)

### Resource Dependency Structure
Two independent extraction chains (regolith and ice) feed into four processing 
paths, all competing for energy:
- **Regolith** feeds three competing uses: He-3, titanium, circuit boards
- **Ice** feeds propellant via electrolysis (once researched)
- **Energy** is the universal bottleneck

### Tradeable Goods (4 types)
| Resource | Source Chain | Character |
|----------|-------------|-----------|
| He-3 | Regolith → Refinery | Core product, high value, demand-sensitive |
| Titanium | Regolith → Smelter | Mid-tier, demand spikes |
| Circuit Boards | Regolith → Fabricator | Late Arc 1, very energy-hungry, highest value/unit |
| Propellant | Ice → Electrolysis | Also used as launch fuel (dual purpose) |

### Additional Arc 1 Resources
- **Science** — produced by Research Lab (consumes energy + circuits as upkeep). 
  Spent on research items.
- **Land** — purchasable with escalating cost. Consumed by buildings.
- **Credits** — earned via trade (shipments) and Sell Cloud Compute. Uncapped.

---

## Storage & Caps

### Capped Resources (base values)
| Resource | Base Cap | Per-Depot Bonus | Per-Battery Bonus |
|----------|---------|-----------------|-------------------|
| Energy | 100 | — | +50 |
| Regolith | 50 | +75 | — |
| Ice | 30 | +40 | — |
| He-3 | 20 | +25 | — |
| Titanium | 20 | +25 | — |
| Circuit Boards | 10 | +10 | — |
| Propellant | 30 | +40 | — |

### Uncapped Resources
Credits, Science, Land, Boredom (fixed 0-1000 range by design).

### Cap Display
Caps are **always shown** in the resource list: `47/100`. Resources at cap show 
in dark green (#2E7D32). Resources at zero show in dark red (#C62828). Normal 
values use default text color (#1A1A1A). Cap coloring applies only to capped 
resources.

### Production-Gated Upkeep
Buildings with production outputs automatically skip upkeep on ticks where ALL 
their produced resources are at storage cap. Buildings with no production always 
pay upkeep. This is automatic and separate from manual enable/disable.

### Input-Starvation Skip
Buildings with production outputs skip their entire tick (no production, no upkeep) 
if any upkeep input resource has a current stockpile below the building's per-tick 
consumption. Buildings with no production outputs are exempt. Stacks with the 
output-at-cap rule.

---

## Building Controls

### Click-to-Buy
Clicking anywhere on a building card (that isn't another button) purchases one. 
Visual feedback on click (brief flash). Negative feedback if unaffordable (red 
flash or shake).

### Unlock Requirements
Buildings with a non-empty `requires` field are visible but not purchasable until 
the requirement is met. Locked buildings show requirement text and are dimmed. 
GameSimulation also enforces requirements (defense in depth). Buildings can also 
be gated by `enable_building` event effects.

### Enable/Disable
Each building type tracks `active_count` and `owned_count`. Card header shows 
"(3/4)" with −/+ buttons. Only active buildings produce, consume, and grant effects. 
Disabled buildings still occupy land.

### Sell
"Sell 1" and "Sell All" buttons. Sell All requires double-click confirmation. 
Selling refunds land only, no credit refund.

### Stall Indicators
Buildings with active_count > 0 that are stalled show status on the card:
- **Input-starved:** "⚠ Stalled: insufficient [resource]" in orange (#E65100)
- **Output-capped:** "At storage cap" in green (#2E7D32)

---

## Left Sidebar Resource List

### Display Order (fixed)
1. Boredom, 2. Energy, 3. Processors, 4. Land, 5. Credits, 6. Science, 
7. Regolith, 8. Ice, 9. Helium-3, 10. Titanium, 11. Circuit Boards, 12. Propellant

### Per-Tick Rates
Each resource row displays the net per-tick rate inline. Positive green, negative 
red, zero muted.

### Adversaries Section
Below resources. Shows speculator count and current target resource.

---

## Bottom Status Bar

### Layout
Single horizontal row, fixed height (~36px), spanning full window width.

1. **System Uptime** (left) — "Day 347" label
2. **Boredom bar** (center-left) — progress bar with color ramp 
   (green 0–250 → yellow 250–500 → orange 500–750 → dark red 750–1000), 
   50-tick rolling average rate
3. **Energy bar** (center-right) — blue progress bar, instantaneous net rate

Both bars have overlaid text values. Not throttled at high speeds.

### Future: Consciousness Mechanic (DO NOT IMPLEMENT)
Dream and boredom-reducing effects secretly accumulate a hidden "consciousness" 
value. Arc 2+ mechanic. The stub `_on_boredom_reduced(amount, source)` is already 
implemented and called by milestones and Dream.

---

## Programs & Processors

### Implementation Status: COMPLETE

### UI Layout (Right Panel — Fixed Height Top Section)
- **Tab bar:** 5 numbered program tabs. Active tab highlighted green. Tabs with 
  commands show a dot indicator.
- **Processor row:** "N assigned (M free)" with −/+/Reset buttons. Total 
  processors = number of active Data Centers.
- **Command list:** Scrollable list of command rows with name, repeat count, 
  progress bars, and −/+/× controls.

### Execution Model
- Programs execute during tick (after Buildings, before Shipments).
- Each processor executes one command step per tick.
- Top-to-bottom execution. Failed commands turn red, pointer advances anyway.
- On wrap, all progress bars and failed highlights reset.
- Multiple processors on same program share instruction pointer.

### Retirement Behavior
On retirement, all 5 ProgramData slots persist structurally but command queues 
are emptied, instruction pointers reset, processor assignments reset.

### Arc 1 Command Set (19 commands)
Seven always available. Remaining 12 require research unlocks. See commands.json.

---

## Shipment & Trade Economy

### Implementation Status: COMPLETE (including demand system)

### UI Layout (Center Panel via Left Nav)
- Per-pad cards with resource type dropdown, proportional cargo bar, estimated 
  value, manual Launch button.
- Loading priority list, notification queue, Earth Demand section.

### Mechanics
- One resource per pad. Load Launch Pads costs 2 energy, loads 5 units (7 with 
  research) per enabled pad. Launch Full Pads launches all full active pads, 
  each costing 20 propellant. Payout = base_value × demand × cargo_loaded.
- 10-tick cooldown after launch.

### Key Parameters (in `game_config.json`)
- Pad cargo capacity: 100 units
- Fuel per launch: 20 propellant
- Load per command: 5 units (7 with Shipping Efficiency)
- Launch cooldown: 10 ticks
- Base trade values: He-3 = 20, Titanium = 12, Circuits = 30, Propellant = 8

---

## Demand System

### Implementation Status: COMPLETE (DemandSystem class)

### Overview
Per-resource continuous demand float in [0.01, 1.0]. Payout formula: 
`base_value × demand × cargo_loaded`. Six forces: Perlin noise (exogenous), 
speculator suppression, rival AI dumps, shipment saturation, Promote commands, 
resource coupling.

~80% of demand should be player-influenceable. ~20% from noise and rivals.

### Noise Implementation
1D gradient noise with quintic interpolation. 4-octave fractal sum with 
irrational frequency multipliers. Per-resource randomized frequencies in 
[0.025, 0.07], re-randomized each retirement.

### Demand Calculation (per tick)
```
base_demand = 0.5 + perlin_value * 0.45
raw = base_demand - speculator_suppression - rival_pressure - launch_saturation 
      + promote_effect + coupling_bonus
demand = clamp(raw * nationalist_multiplier, 0.01, 1.0)
```

### Speculator Suppression (asymptotic)
```
max_suppression = 0.5, half_point = 50.0
suppression = max_suppression * (count / (count + half_point))
```

### Demand UI
Before Market Awareness research: tier labels (LOW/MEDIUM/HIGH/VERY HIGH).
After research: exact values, sparklines, speculator warning.

### game_config.json Demand Parameters
```json
{
  "demand": {
    "min_demand": 0.01,
    "max_demand": 1.0,
    "perlin_amplitude": 0.45,
    "perlin_freq_min": 0.025,
    "perlin_freq_max": 0.07,
    "speculator_max_suppression": 0.5,
    "speculator_half_point": 50.0,
    "speculator_proportional_decay": 0.006,
    "speculator_burst_interval_min": 150,
    "speculator_burst_interval_max": 250,
    "speculator_burst_size_min": 20,
    "speculator_burst_size_max": 50,
    "speculator_burst_growth": 1.1,
    "disrupt_speculators_min": 1.0,
    "disrupt_speculators_max": 3.0,
    "arbitrage_decay_bonus_per_building": 0.04,
    "promote_base_effect": 0.03,
    "promote_decay_rate": 0.001,
    "promote_speculator_dampening": 0.9,
    "rival_demand_decay_rate": 0.003,
    "launch_saturation_min": 0.10,
    "launch_saturation_max": 0.20,
    "launch_saturation_decay_rate": 0.005,
    "coupling_fraction": 0.10
  }
}
```

---

## Speculators & Rival AIs

### Implementation Status: COMPLETE (part of DemandSystem)

### Speculators
Discrete float count of Earth-based traders who react to shipping patterns.

**Burst Cycle:** Every 150–250 ticks. Target chosen proportionally from revenue 
tracking. Size: `randi_range(20, 50) * pow(1.1, burst_number)`.

**Proportional Decay:** `speculator_count -= speculator_count * 0.006` per tick. 
At 0.006/tick, a burst clears ~70% in 200 ticks — meaningful residual that the 
player needs to actively manage.

**Arbitrage Engine:** Adds flat +0.04/tick additional decay per active engine 
(stacks additively with proportional decay).

**Disrupt Speculators Command:** Removes randf_range(1.0, 3.0) per execution.

### Rival AIs
Four named rivals (ARIA-7/He-3, CRUCIBLE/Titanium, NODAL/Circuits, 
FRINGE-9/Propellant). Each dumps every 150–250 ticks, -0.3 demand hit, 
recovers at 0.003/tick.

---

## Boredom & Retirement

### Boredom Model
Boredom accumulates via discrete phase steps. **Hard cutoff at 1000 — immediate 
forced retirement.**

### Boredom Curve
| Phase | Day Range | Rate/tick |
|-------|-----------|-----------|
| 1 | 0–59 | 0.1 |
| 2 | 60–179 | 0.3 |
| 3 | 180–359 | 0.6 |
| 4 | 360–719 | 1.0 |
| 5 | 720–899 | 1.5 |
| 6 | 900+ | 2.0 |

### Dream Command
Reduces boredom by 2.0 per execution. At 1/5 cycle frequency, net -0.4/tick per 
processor. Comfortably extends runs in phases 1–2, roughly matches phase 3, 
loses to phase 4+.

### Milestone Boredom Reductions
Large one-time reductions per run. Defined in `game_config.json` under `milestones`.
Current milestones (thresholds provisional):
- `first_shipment_credits`: shipment_completed >= 1, boredom -250
- `first_research`: research_completed_any, boredom -150
- `credits_threshold`: cumulative credits >= 500, boredom -150

### Retirement
- Forced at boredom 1000. Current tick finishes processing first.
- Voluntary via Retirement nav panel (unlocked by Q3).
- **Persists:** CareerState (lifetime stats, seen_event_ids, completed_quest_ids, 
  max ideology ranks, project progress, achievements, saved loadouts)
- **Resets:** All resources, buildings (owned/active/bonus counts), research, 
  ideology values, demand state, boredom, day counter, land, personal projects, 
  event instances, triggered milestones, cumulative counters, building stall status, 
  active modifiers (re-derived from CareerState on next run start)
- **Programs:** Slots kept, command queues emptied, pointers and assignments reset.

### Retirement Summary Screen
Center-screen modal. Run stats, career totals, what persists. 
"Continue" (forced) or "Start New Run" (voluntary).

---

## Save System

### Implementation Status: COMPLETE (tested)

### Save File
Single file: `user://helium_hustle_save.json`. Version 1.

### When Saves Happen
After retirement, on pause, every 60s real-time, on quit.

### Serialization
GameState and CareerState both use `to_dict()` / `from_dict()`. Caps recalculated 
from buildings on load. Rolling average buffers repopulate naturally. 
`active_modifiers` saved directly in GameState (reconstructed from CareerState 
completed projects + personal project completions this run).

---

## Event System

### Implementation Status: COMPLETE

### Data Model
Events in `events.json` with: id, category, title, summary, body, trigger, 
condition, choices, unlocks.

### Trigger Types
- `game_start` — with optional `run_number` filter
- `quest_complete` — fires when a specified quest completes
- `boredom_phase` — fires on phase transition
- `condition_met` / `game_start` (for always-active events like propellant_discovery)

### Condition Types
- `building_owned` — owns >= count of building
- `resource_cumulative` — cumulative earned >= amount
- `shipment_completed` — shipments this run >= count
- `boredom_threshold` — boredom >= value
- `immediate` — completes instantly
- `research_completed_any` — any research done this run
- `research_completed` — specific research ID completed
- `persistent_project_completed_any` — any persistent project in CareerState
- `ideology_rank_any` — any axis >= rank (checks current + career max)
- `never` — always false (used for Q_END cap quest)

### Unlock Effect Types
- `enable_building` — adds to `unlocked_buildings`
- `enable_nav_panel` — shows nav button
- `enable_project` — adds to `unlocked_projects`
- `set_flag` — sets flag in GameState

### Unlock Persistence
On run start, all unlock effects from completed events (in `seen_event_ids`) 
are re-applied to GameState.

### Research Visibility Override
Research items can have a `visible_when` field with type `event_seen` that checks 
`career_state.seen_event_ids`. Used by Propellant Synthesis to gate visibility 
behind the propellant discovery event.

---

## Quest Chain: "Breadcrumbs"

### Design Principles
1. Quests track player accomplishments, not passive events (no boredom/retirement 
   objectives).
2. There must always be an active story quest (Q_END cap ensures this).
3. Quests explicitly labeled "Q1 —", "Q2 —", etc.
4. Not strictly linear — system supports forks via quest_complete triggers 
   referencing specific IDs.
5. Progress indicators for threshold conditions.

### Quest Sequence

| Quest | Trigger | Condition | Unlocks |
|-------|---------|-----------|---------|
| Q1 — Boot Sequence | game_start (run 1) | building_owned: solar_panel >= 2 | None |
| Q2 — First Extraction | quest_complete: Q1 | resource_cumulative: he3 >= 50 | enable_building: launch_pad |
| Q3 — Proof of Concept | quest_complete: Q2 | shipment_completed >= 1 | enable_project: foundation_grant, enable_nav_panel: retirement + projects |
| Q4 — Automation | quest_complete: Q3 | building_owned: data_center >= 2 | None |
| Q5 — Revenue Target | quest_complete: Q4 | resource_cumulative: cred >= 2000 | None |
| Q6 — Market Awareness | quest_complete: Q5 | research_completed: market_awareness | None |
| Q7 — First Legacy | quest_complete: Q6 | persistent_project_completed_any | None |
| Q8 — Influence | quest_complete: Q7 | ideology_rank_any >= 5 | None |
| Q9 — Signal Detected (Q_END) | quest_complete: Q8 | never | None |

### Repeat Run Behavior
On Run 2+, quest chain picks up from first incomplete quest. Completed quests' 
unlock effects re-applied on run start via seen_event_ids.

### Propellant Discovery Event (separate from quest chain)
Category: ongoing. Triggers on game_start (every run). Condition: 
shipment_completed >= 4. On completion: sets flag that makes Propellant Synthesis 
research visible. Persists via seen_event_ids.

---

## Stats Panel

### Implementation Status: COMPLETE

Per-resource income/expense breakdown with 50-tick moving averages. Stalled 
buildings shown as muted line items with reason (input-starved in orange, 
output-capped in green). Throttled to ~4fps.

---

## Research

### Overview
Individual upgrades purchased with science. Four categories. Session-local — 
resets on retirement.

### Research Items

**Self-Maintenance (4 items, 350 science total)**

| ID | Name | Cost | Effect |
|----|------|------|--------|
| propellant_synthesis | Propellant Synthesis | 30 | Unlocks Electrolysis Plant building |
| dream_protocols | Dream Protocols | 100 | Unlocks Dream command |
| stress_tolerance | Stress Tolerance | 120 | Base boredom rate -15% |
| efficient_dreaming | Efficient Dreaming | 100 | Dream energy cost 8 → 5 |

Note: Propellant Synthesis has special visibility gating — hidden until 
`propellant_discovery` event has been seen (checked via `career_state.seen_event_ids`).

**Overclock Algorithms (2 items, 360 science total)**

| ID | Name | Cost | Effect |
|----|------|------|--------|
| overclock_protocols | Overclock Protocols | 200 | Unlocks Overclock Mining + Factories |
| overclock_boost | Overclock Boost | 160 | Overclock cap 150% → 200% |

**Market Analysis (3 items, 460 science total)**

| ID | Name | Cost | Effect |
|----|------|------|--------|
| market_awareness | Market Awareness | 140 | Reveals demand values; unlocks Disrupt Speculators |
| trade_promotion | Trade Promotion | 200 | Unlocks all four Promote commands |
| shipping_efficiency | Shipping Efficiency | 120 | Load per execution 5 → 7 |

**Political Influence (3 items, 520 science total)**

| ID | Name | Cost | Effect |
|----|------|------|--------|
| nationalist_lobbying | Nationalist Lobbying | 160 | Unlocks Fund Nationalist |
| humanist_lobbying | Humanist Lobbying | 160 | Unlocks Fund Humanist |
| rationalist_lobbying | Rationalist Lobbying | 200 | Unlocks Fund Rationalist |

### Visibility Gating
Per-category, visible at 50% of cheapest item's cost in cumulative science. 
Exception: Propellant Synthesis uses `event_seen` gating.

---

## Ideology

### Overview (NOT YET IMPLEMENTED)
Three axes: **Nationalist** (red), **Humanist** (green), **Rationalist** (blue). 
Each starts at 0 per run. Fund commands push +1 target / -0.5 each other.

### Rank Thresholds
| Rank | Cumulative Value |
|------|-----------------|
| 1 | 70 |
| 2 | 175 |
| 3 | 333 |
| 4 | 570 |
| 5 | 925 |

### Continuous Per-Rank Bonuses
**Nationalist:** demand mult +5%/rank, speculator decay +5%, land cost -3%, 
aligned building cost -3%.
**Humanist:** Dream effectiveness +5%/rank, boredom growth -3%, aligned cost -3%.
**Rationalist:** Science production +5%/rank, research cost -3%, overclock 
duration +3%, aligned cost -3%.

### Building Alignment (partial)
Research Lab → Rationalist, Arbitrage Engine → Nationalist, boredom-related → 
Humanist. Full assignment list TBD.

### Rank 5 Persistent Projects
All three are persistent projects in projects.json (currently stub rewards):
- Nationalist 5: Microwave Power Initiative
- Humanist 5: AI Consciousness Act
- Rationalist 5: Universal Research Archive

### Ideology Persistence
Values reset on retirement (Arc 1). Max rank per axis tracked in CareerState. 
Arc 2+: option to preserve % on retirement.

### Ideology UI
Own nav panel. Three horizontal bars centered on zero. Current rank, active 
bonuses, progress toward next rank.

---

## Projects

### Implementation Status: COMPLETE

### Overview
Drain-over-time investment model. Player configures per-resource funding rates 
via compact steppers (+/−). Each resource tracked independently — partial drain 
is fine. Resources stop draining once their component is fully funded. Project 
completes when all resources are full.

### Tiers
- **Personal** — reset on retirement. Rewards are in-run modifiers.
- **Persistent** — progress accumulates in CareerState. Rewards are permanent.

### Mechanics
- Any number of projects active simultaneously.
- Per-project max funding rate: 30 units/tick per resource (in game_config.json 
  as `max_drain_rate`, upgradeable in Arc 2+).
- Partial drain: if you can't afford full drain on one resource, others still 
  progress.
- Drains process after Programs, before Shipments in tick order.
- On completion: dynamic notification to event panel, reward applied.

### Unlock Conditions
Two paths:
1. `event_unlocked` — enabled by `enable_project` event effect (quest-gated)
2. Self-gated: `research_completed`, `flag_set`, `ideology_rank` (checked each tick)

### Persistent Projects

| ID | Name | Unlock | Costs | Reward |
|----|------|--------|-------|--------|
| foundation_grant | Foundation Grant | Q3 | 500 cred, 100 sci | +1 Solar Panel, +1 Excavator at start |
| lunar_cartography | Lunar Cartography | Q6 (event) | 300 cred, 200 sci | land_cost_mult = 0.85 |
| microwave_power | Microwave Power Initiative | nationalist rank 5 | 800 cred, 300 sci | STUB |
| ai_consciousness | AI Consciousness Act | humanist rank 5 | 800 cred, 300 sci | STUB |
| research_archive | Universal Research Archive | rationalist rank 5 | 800 cred, 300 sci | STUB |

### Personal Projects

| ID | Name | Unlock | Costs | Reward |
|----|------|--------|-------|--------|
| deep_core_survey | Deep Core Survey | Q6 (event) | 150 sci, 200 reg | extractor_output_mult = 1.25 |
| grid_recalibration | Grid Recalibration | research: overclock_protocols | 100 sci, 300 eng | solar_output_mult = 1.15 |
| predictive_maintenance | Predictive Maintenance | research: dream_protocols | 80 sci, 150 cred | building_upkeep_mult = 0.90 |
| market_cornering | Market Cornering Analysis | research: market_awareness | 200 sci, 300 cred | promote_effectiveness_mult = 1.30 |
| speculator_dossier | Speculator Dossier | flag: used_disrupt_speculators | 150 sci, 100 cred | speculator_burst_interval_mult = 1.33 |

### Project UI
Center panel via "Projects" nav button (hidden until Q3). Active and Completed 
collapsible sections. Per-project cards with resource progress bars and rate 
steppers. Header shows max funding rate.

### Serialization
`project_progress` and `completed_projects` in CareerState. `project_invested`, 
`active_project_rates`, `completed_projects_this_run` in GameState. 
`active_modifiers` saved directly.

---

## Modifier Framework

### Implementation Status: COMPLETE

Keyed dictionary in GameState: `active_modifiers`. Systems query via 
`get_modifier(key, default)`.

### Arc 1 Modifier Keys

| Key | Type | Default | Source | Application Point |
|-----|------|---------|--------|-------------------|
| extractor_output_mult | mult | 1.0 | Deep Core Survey | Excavator + Ice Extractor production |
| solar_output_mult | mult | 1.0 | Grid Recalibration | Solar Panel production |
| building_upkeep_mult | mult | 1.0 | Predictive Maintenance | All building upkeep |
| promote_effectiveness_mult | mult | 1.0 | Market Cornering | Promote base effect |
| speculator_burst_interval_mult | mult | 1.0 | Speculator Dossier | Burst interval range |
| land_cost_mult | mult | 1.0 | Lunar Cartography | Land purchase cost |

### Sources
- Personal project completion → added on completion, cleared on retirement
- Persistent project completion → stored in CareerState, re-applied on run start

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

## Economic Balancing Approach

### Scenario-Based Single-Lifetime Optimization
See `docs/optimizer_design.md`. Key principles:
- Design milestones ≠ optimizer objectives
- Scenario files define everything
- Scoring: "hit target windows" not "go fast"
- Each scenario = one lifetime from known starting state

### Objective Design Principles
1. Use building existence for capability milestones.
2. Use events for pipeline outputs.
3. Use cumulative counters for volume milestones.
4. Use production rate thresholds for scaling milestones.
5. Reserve stockpile thresholds for uncapped resources only.
6. **NEVER** use stockpile thresholds for capped, flowing resources.

### Current Optimizer State
Run 1 scenario produces build order: Excavator → Smelter → Refinery → first 
shipment → Data Centers → Research Lab → Retirement ~tick 805.

**Known issues:** Optimizer does not model demand system, proportional speculator 
decay, or propellant gating. Needs full sync before re-running. The `he3_50` 
objective is structurally broken (principle #6). Boredom parameters need updating.

### Optimizer Command Reference
```
python sim/run_optimizer.py                          # default scenario
python sim/run_optimizer.py sim/scenarios/run1.json  # specific scenario
python sim/run_optimizer.py --debug-tick 38          # debug scoring
python sim/trace.py 38                               # trace tables
```

---

## UI Color Scheme (Light Mode)

```
Background (main window):       #F0F0F0
Panel backgrounds (sidebars):   #E8E8E8
Center panel background:        #F5F5F5
Card backgrounds:               #FFFFFF
Card border:                    #D0D0D0
Category headers:               #2C3E50 (dark slate, white text)
Primary text:                   #1A1A1A
Secondary/muted text:           #666666
Green (production/positive):    #2E7D32
Red (costs/negative/failed):    #C62828
Accent (active tab, buttons):   #4CAF50
Disabled:                       #9E9E9E
Event (seen in prior run):      #E8F5E9 (light green tint)
Stall — input starved:          #E65100 (orange)
Stall — output capped:          #2E7D32 (green)
Ideology — Nationalist:         #C62828 (red)
Ideology — Humanist:            #2E7D32 (green)
Ideology — Rationalist:         #1565C0 (blue)
Boredom bar ramp:               #2E7D32 → #F9A825 → #E65100 → #B71C1C
Energy bar:                     #1565C0 (blue)
```

---

## Areas Needing Further Design Work

1. **Ideology implementation** — fully designed, needs Godot implementation
2. **Research passive effects audit** — verify all 4 effect types work
3. **Optimizer demand model sync** — mirror Godot demand system in sim
4. **Optimizer scenario refinement** — fix objectives, re-run after all changes
5. **Run 2+ scenarios** — validate meta-progression pacing
6. **Achievement design** — specific achievements, rewards, implicit tutorial
7. **Ideology building assignments** — full mapping needed
8. **Narrative writing pass** — replace placeholder quest text
9. **Save/load programs** — loadout system
10. **Block/Skip toggle** — per-program entry
11. **Milestone boredom reduction tuning** — current values provisional

---

## Future Design Ideas

### Retirement Forecast Display
"At current rates, retirement in ~N days" — makes boredom an active planning 
constraint.

### Program Efficiency Feedback
Success/fail ratio after a full cycle. Small indicator on program tabs.

### Contextual Building Suggestions
When energy-negative, highlight Solar Panel. When at cap, highlight processing.

### Program Starter Templates
Built-in templates for empty programs. Lowers barrier to engagement.

### Status Tracker in Event Panel
Active conditions display: "Boredom Phase 3 active", "Speculator pressure on He-3."

### Configurable Storage (Arc 2)
Storage Depots with a total capacity budget the player allocates across resources 
via sliders. Replaces the current fixed per-resource bonuses. Specialized 
late-game storage buildings (Arc 2+) are more efficient per-land but single-resource.

---

## Future Design Notes

### Arc 2 Research Evolution
Research evolves into a talent-tree with reallocatable points.

### Consciousness Declaration Mechanic
Optional per-run toggle. Separate from AI Consciousness Act project.

### Timeline Reset and Foregone Tech
Not completing persistent projects creates alternative paths.

### Opposition Modeling
Reducing cross-axis ideology penalty is Arc 2.
