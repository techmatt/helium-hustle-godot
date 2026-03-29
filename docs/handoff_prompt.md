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
   resource list), center panel (buildings/commands/launch pads/stats), right panel 
   (programs top, events bottom). Bottom status bar with system uptime, boredom bar, 
   energy bar.

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
     numbers on bar), estimated credit value (uses live demand), manual Launch button
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

10. **Research system** — basic implementation (not thoroughly tested). Research 
    items loaded from research.json, purchasable with science. Category-based 
    visibility gating by cumulative science earned. Research panel in center 
    panel via left nav.

11. **Event system** — EventManager (pure logic) + EventPanel (lower right panel) + 
    EventModal (center-screen overlay). Three collapsible sections: Story, Ongoing, 
    Completed. Events defined in events.json. First-time events auto-open modal and 
    pause; previously-seen events appear silently. Auto-pause on modal events 
    implemented.
    - **Unlock effects wired:** `enable_building` adds building ID to unlocked set 
      in GameState; `enable_nav_panel` shows/hides nav buttons in left sidebar; 
      `enable_project` stores project ID in GameState (project system not yet 
      implemented); `set_flag` sets named boolean in GameState flags dictionary.
    - **Nav panel gating:** Retirement, Projects, and Ideologies panels start hidden 
      and unlock via event effects. Other panels visible from start.

12. **Stats panel** — center panel view via "Stats" nav button. Per-resource income/ 
    expense breakdown using ResourceRateTracker with 50-tick moving averages. 
    Collapsible sections per resource showing per-source line items. Career Bonuses 
    section (placeholder). Throttled to ~4fps.

13. **Buy Land card** — full-width card at top of Buildings panel. Shows land 
    usage, next purchase cost, and Buy button. 15 credit base, 1.5x scaling, 
    10 land per purchase.

14. **Resource list improvements** — ordered Boredom/Energy/Processors/Land first, 
    then remaining resources. Processor display shows assigned/total. Per-tick 
    net rates shown inline for each resource (green positive, red negative, muted 
    zero). Cap coloring: dark green at cap, dark red at zero for capped resources.

15. **Boredom phase signal** — GameState tracks `current_boredom_phase` (int, 
    initialized to 1, resets on retirement). Phase determined by day counter 
    using boredom curve. Signal `boredom_phase_changed(old_phase, new_phase)` 
    emitted on phase transitions. EventManager listens for this signal to fire 
    `boredom_phase` trigger events.

16. **Cumulative resource counters** — `cumulative_resources_earned: Dictionary` 
    in GameState, mapping resource ID strings to float values. Incremented whenever 
    a resource is produced (buildings, commands, shipment revenue). Only goes up, 
    never decremented. Resets on retirement. Research visibility gating reads from 
    `cumulative_resources_earned["sci"]`. Quest conditions of type 
    `resource_cumulative` read from this dictionary.

17. **Milestone boredom reductions** — scaffold implemented. `triggered_milestones: 
    Array[String]` in GameState (resets on retirement). Milestones defined in 
    `game_config.json` under `milestones` key, each with id, condition (reuses 
    event condition types), boredom_reduction, and label. Checked at end of each 
    tick. When triggered: adds to triggered_milestones, applies boredom reduction 
    (clamped to 0), displays via event system notification. Consciousness hook 
    stub (`_on_boredom_reduced(amount, source)`) called on all boredom reductions 
    (milestones and Dream command). Initial placeholder milestones (values reflect 
    ×10 boredom scaling):
    - `first_shipment_credits`: shipment_completed >= 1, boredom -250
    - `first_research`: research_completed_any, boredom -150
    - `credits_threshold`: cumulative credits >= 500, boredom -150

18. **Demand system** — full implementation replacing the static 0.5 placeholder. 
    Per-resource continuous demand float in range [0.01, 1.0]. Six forces drive 
    demand: Perlin noise drift, speculator suppression, rival AI dumps, shipment 
    saturation, Promote commands, and resource coupling. See Demand System section 
    for full specification. **Extracted into its own class** (`demand_system.gd`, 
    class_name DemandSystem) — separated from GameSimulation for code organization.

19. **Adversaries sidebar section** — collapsible "Adversaries" section in the left 
    sidebar resource list, below existing resources. Shows speculator count and 
    current target resource.

20. **Demand noise improvements** — gradient noise (not value noise) with quintic 
    interpolation, 4-octave fractal sum with normalized output, tuned frequencies 
    and amplitude for stock-ticker-style curves. See Demand System section for 
    parameters.

21. **Retirement system** — implemented (not thoroughly tested). Forced retirement 
    at boredom 1000 (hard cutoff). Voluntary retirement via Retirement nav panel 
    (unlocked by Q3). Retirement summary screen shows run stats and career totals. 
    CareerState tracks persistent data across runs. Programs clear on retirement 
    (command queues emptied, processor assignments reset). See Retirement section 
    for full specification.

22. **Save/load persistence** — implemented (not thoroughly tested). Single save 
    file at `user://helium_hustle_save.json`. Mid-run autosave (on pause, every 
    60s real-time, on quit). Resume on game launch. CareerState and GameState both 
    serialize via `to_dict()`/`from_dict()`. Debug option to clear all save data. 
    See Save System section for full specification.

### In the Python Optimizer (`sim/`)

1. **Scenario-based architecture** — optimizer loads scenario JSON files that 
   define starting conditions, available actions, objectives with target windows, 
   and end conditions. See `docs/optimizer_design.md` for full spec.
2. **Tick-accurate economy model** (`economy.py`) — pure state machine matching 
   the Godot tick order. Buildings, programs (fixed policy), shipments, boredom, 
   storage caps all modeled. Includes production-gated upkeep, input-starvation 
   skip, and per-pad launch mechanics with cooldown. **Does not yet model the 
   demand system** — uses static demand. TODO: sync demand model to match Godot.
3. **Greedy optimizer** (`optimizer.py`) — shadow pricing + urgency bonuses + 
   sighted lookahead baseline. Scores all affordable actions each tick and picks 
   the best.
4. **Buy commands as discrete actions** — Buy Titanium, Buy Regolith, Buy Ice, 
   Buy Propellant appear in the optimizer's action space alongside building 
   purchases.
5. **4-section terminal report** — build order, objective timing, resource 
   snapshots, structural summary. Plus CSV tick report for detailed analysis.
6. **Score trace utility** (`trace.py`) — prints full scoring tables at specific 
   ticks for debugging optimizer decisions.

---

## What's NOT Implemented Yet (in rough priority order)

1. **Quest chain content beyond Q1–Q3** — Q4–Q10 need implementation in events.json
2. **Ideology** — see Ideology section
3. **Projects** — see Projects section
4. **Speculators & rival AIs in optimizer** — demand system needs mirroring in 
   `sim/economy.py`
5. **Save/load programs** — loadout system for saving/loading program configs
6. **Block/Skip toggle** — per-program entry option
7. **Cross-retirement program persistence** — loadouts persist, active programs 
   reset (commands may reference locked research)
8. **Achievement system** — design pass needed before implementation
9. **Thorough testing of retirement flow** — basic checks pass but edge cases 
   not validated
10. **Thorough testing of save/load** — basic checks pass but round-trip fidelity 
    and edge cases not validated
11. **Thorough testing of research system** — passive effects not fully verified

---

## Architecture Notes

- Game logic (GameState, GameSimulation) has no UI references — designed for 
  headless simulation support (which now exists in `sim/`).
- Tick order: Boredom → Buildings (energy net first, then resources; production-
  gated upkeep and input-starvation skip applied) → Demand Update → Programs → 
  Shipments (using current demand, apply launch saturation hits) → Speculator 
  Revenue Tracking → Speculator/Rival Burst Check → Clamp → Events → Advance day.
- Buildings process in JSON row order (Solar Panel first).
- Building costs: `base_cost × (scaling ^ num_owned)`. Land cost per building is 
  constant but land itself has escalating purchase cost.
- Building production/upkeep uses `active_count` (not `owned_count`). Only active 
  buildings produce, consume, and grant effects.
- Program panel UI updates are throttled to ~10fps regardless of game speed to 
  prevent lag at 200x.
- Event panel and Stats panel updates also throttled (~10fps and ~4fps respectively).
- **DemandSystem is a separate class** (`demand_system.gd`), extracted from 
  GameSimulation. Owns all demand config, Perlin noise, speculator/rival logic. 
  GameSimulation holds a `demand_system: DemandSystem` member. Command effects 
  that touch demand (`demand_nudge`, `spec_reduce`) stay in GameSimulation but 
  read config via `demand_system.get_config()`.

### Design Rule: No Same-Resource Production and Upkeep

**No building should both produce and consume the same resource.** This creates 
confusing stats breakdowns and doesn't add meaningful gameplay. If a building 
conceptually has offsetting production and consumption of the same resource, 
consolidate to the net value in the data. Example: Electrolysis Plant was changed 
from (+2 prop, +1 eng production / -2 ice, -2 eng upkeep) to (+2 prop production / 
-2 ice, -1 eng upkeep) — same net effect, cleaner data.

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

Note: Solar Panel and Excavator have credit-only costs (no physical resources). 
Solar Panel titanium cost was removed during optimizer tuning — the original design 
had a titanium teaching loop but it was cut for smoother early game flow. The 
optimizer starts with a Data Center so the player has a processor from tick 1. 
Electrolysis Plant was consolidated to net energy values (no same-resource 
production/upkeep). Arbitrage Engine always runs when enabled; player can manually 
disable to save energy.

### Key Command Costs
| Command | Costs | Production | Notes |
|---------|-------|------------|-------|
| Idle | — | 1 cred | Zero cost filler |
| Sell Cloud Compute | 3 eng | 5 cred | +0.4 boredom per execution (×10 scaled) |
| Buy Regolith | 8 cred + 2 eng | 1 reg | Tactical gap-bridging |
| Buy Ice | 10 cred + 2 eng | 1 ice | Tactical gap-bridging |
| Buy Titanium | 20 cred + 3 eng | 0.5 ti | Expensive, fractional output |
| Buy Propellant | 12 cred + 2 eng | 1 prop | Tactical gap-bridging |
| Dream | 8 eng (5 with research) | — | -2 boredom per execution (×10 scaled, requires research) |

Buy commands are intentionally expensive — 3-5x the cost of building-based 
production per unit. They exist for tactical gap-bridging (need 2 titanium for 
a specific build) not as a primary resource strategy.

### Land System
- Base cost: 15 credits, scaling: 1.5x per purchase
- 10 land per purchase
- Starting land: 40
- Buy Land card at top of Buildings panel (full-width, not in any category dropdown)
- No selling or disabling land purchases

---

## Resource Flow — Arc 1 Economy

### Raw Extraction (both consume energy)
- **Regolith Excavator** — energy → regolith
- **Ice Extractor** — energy → ice

### Processing Buildings (each has one clear purpose)
- **Refinery** — regolith + energy → He-3
- **Smelter** — regolith + energy → titanium
- **Fabricator** — regolith + energy (lots) → circuit boards
- **Electrolysis Plant** — ice + energy → propellant (small net energy cost)

### Resource Dependency Structure
Two independent extraction chains (regolith and ice) feed into four processing 
paths, all competing for energy:
- **Regolith** feeds three competing uses: He-3, titanium, circuit boards
- **Ice** feeds propellant via electrolysis
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
resources (not Credits, Science, Land, or Boredom).

### Production-Gated Upkeep
Buildings with production outputs automatically skip upkeep on ticks where ALL 
their produced resources are at storage cap. If even one produced resource has 
room, the building pays full upkeep and produces normally (any at-cap production 
is wasted). Buildings with no production (Battery, Storage Depot, Launch Pad, 
Data Center) always pay upkeep since their value is passive. This is automatic 
and separate from the player's manual enable/disable controls.

### Input-Starvation Skip
Buildings with production outputs skip their entire tick (no production, no upkeep) 
if any of their upkeep input resources has a current stockpile below the building's 
per-tick consumption of that resource. Buildings with no production outputs are 
exempt — they always pay upkeep. The check uses resource state at the moment the 
building processes (tick order matters). This stacks with the production-gated 
upkeep rule — either condition independently causes the building to skip.

---

## Building Controls

### Click-to-Buy
Clicking anywhere on a building card (that isn't another button) purchases one. 
Visual feedback on click (brief flash). Negative feedback if unaffordable (red 
flash or shake).

### Unlock Requirements
Buildings with a non-empty `requires` field in buildings.json are visible but not 
purchasable until the requirement is met. Locked buildings show requirement text 
and are dimmed/grayed out (distinct from the "too expensive" state). Clicking a 
locked building does nothing — no red flash. GameSimulation also enforces unlock 
requirements on purchase attempts (defense in depth). Buildings can also be gated 
by the `enable_building` event unlock effect (e.g., Launch Pad is unlocked by Q2 
completion).

### Enable/Disable
Each building type tracks `active_count` and `owned_count`. Card header shows 
"(3/4)" with −/+ buttons. Only active buildings produce, consume upkeep, and 
grant effects (processors, storage caps). Disabled buildings still occupy land. 
New purchases default to enabled. Controls only visible when owned ≥ 1.

Disabling a Data Center reduces the processor pool. If this over-assigns 
processors, excess are unassigned starting from the highest-numbered program.

Disabling a Battery/Storage Depot reduces caps. If resources exceed new caps, 
they are clamped (resources lost).

### Sell
"Sell 1" and "Sell All" buttons in bottom-right of card. Only visible when 
owned ≥ 1. Sell All requires confirmation (first click → "Confirm?", second 
click executes, reverts after ~2 seconds if no second click). Selling refunds 
land only, no credit refund. Selling recalculates the next purchase cost 
(since costs scale with owned_count).

---

## Left Sidebar Resource List

### Display Order (fixed)
1. Boredom
2. Energy
3. Processors
4. Land
5. Credits
6. Science
7. Regolith
8. Ice
9. Helium-3
10. Titanium
11. Circuit Boards
12. Propellant

### Per-Tick Rates
Each resource row displays the net per-tick rate inline: `+90.0/s`. Positive 
rates in green (#2E7D32), negative in red (#C62828), zero in muted (#666666). 
Processors and Land do not show rates. This provides at-a-glance economy health 
alongside the detailed per-source breakdown in the Stats panel.

### Adversaries Section
Below the resource list, a collapsible "Adversaries" section shows:
- **Speculators** row: count and current target resource (e.g., "Speculators: 47 → He-3")
- Styled like resource rows. Always visible regardless of Market Awareness research.

### Processor Row
Displays `Processors: 2/3` where 2 = total assigned across all programs, 
3 = total available (active Data Centers). No income rate shown. Styled like 
other resource rows without the rate portion.

### Cap Coloring
- At cap (current >= max): dark green text (#2E7D32)
- At zero (current == 0, for capped resources): dark red text (#C62828)
- Normal: default text color (#1A1A1A)
- Applies only to capped resources (Energy, Regolith, Ice, He-3, Titanium, 
  Circuit Boards, Propellant). Not applied to uncapped resources.

---

## Bottom Status Bar

### Layout
Single horizontal row, fixed height (~36px), spanning full window width. Background 
matches sidebar color (#E8E8E8). Three elements arranged left-to-right in an 
HBoxContainer:

1. **System Uptime** (left) — "Day 347" label
2. **Boredom bar** (center-left) — label + progress bar + value + rate
3. **Energy bar** (center-right) — label + progress bar + value + rate

Bars expand to fill available space. Uptime is fixed-width, left-aligned.

### Boredom Bar
Display: `Boredom: [====------] 314/1000 (+0.3/tick)`

- **Value format:** Integer or one decimal (314/1000). Boredom is scaled ×10 
  from original design (capacity 1000, not 100).
- **Rate:** Rolling average over the **past 50 ticks** of actual net boredom change. 
  This naturally captures Dream executions, milestone reductions, and any other 
  boredom modifiers without needing to model program cycles. Displayed as signed 
  value with one or two decimal places. Green if net negative, red if net positive.
- **Color ramp on bar fill:**
  - 0–250: #2E7D32 (green, matches existing production green)
  - 250–500: #F9A825 (yellow/amber)
  - 500–750: #E65100 (orange)
  - 750–1000: #B71C1C (dark red)
- **Text on bar:** Value overlaid on the bar itself (white text with subtle shadow 
  for legibility against colored fill). Rate displayed to the right of the bar.

### Energy Bar
Display: `Energy: [========--] 47/100 (+12/tick)`

- **Value format:** Integers (47/100). Energy changes in whole numbers.
- **Rate:** Instantaneous net rate (current tick production minus all consumption 
  from buildings + programs). Displayed as signed integer. Green if positive, red 
  if negative.
- **Bar fill color:** #1565C0 (blue) — neutral, non-urgent. Energy is a budget, 
  not a countdown.
- **Cap display:** Denominator updates when batteries change the cap (e.g. 47/150).
- **Text on bar:** Value overlaid on bar. Rate displayed to the right.

### Relationship to Left Sidebar
Energy and boredom **remain in the left sidebar resource list** unchanged. The 
bottom bar is a persistent high-visibility HUD; the sidebar is the canonical 
"everything" list. Redundancy is intentional.

### Implementation Notes
- Boredom rate: maintain a circular buffer of the last 50 boredom deltas. Average 
  on display update. Initialize with zeros. Buffer is per-run, reset on retirement.
- Both bars use the same visual style (rounded ProgressBar or custom `_draw()` with 
  overlaid text). Match the existing card/panel aesthetic (subtle border #D0D0D0).
- Bar height: ~20px within the 36px row, vertically centered.
- At high game speeds, bottom bar updates are **not throttled** (unlike the program 
  panel at ~10fps) since these are critical readouts the player watches while 
  fast-forwarding.

### Future: Consciousness Mechanic (DO NOT IMPLEMENT)
Dream and similar boredom-reducing effects secretly accumulate a hidden 
"consciousness" value. This value is not displayed to the player. When 
consciousness crosses certain thresholds, dramatic game state changes occur 
(details TBD — this is an Arc 2+ mechanic). The boredom reduction system should 
be structured so that a consciousness accumulator can be trivially added later 
(e.g., every call to reduce boredom also calls a stub/hook for consciousness). 
The stub `_on_boredom_reduced(amount, source)` is already implemented and called 
by milestones and Dream.

---

## Programs & Processors

### Implementation Status: COMPLETE in Godot

The program system is fully implemented in Godot with the following design:

### UI Layout (Right Panel — Fixed Height Top Section)
- **Tab bar:** 5 numbered program tabs across top. Active tab highlighted green. 
  Tabs with commands show a dot indicator.
- **Processor row:** "N assigned (M free)" with −/+/Reset buttons. Total 
  processors = number of active Data Centers.
- **Command list:** Scrollable list of command rows. Each row shows command name 
  + repeat count (e.g. "Sell Cloud Compute (x3)"), progress bar, and −/+/× 
  buttons.
- **Program panel has fixed height** — does not expand to fill right column. 
  Event panel fills remaining space below.

### Adding Commands
Click "Commands" in left nav to switch center panel to Commands view. Command 
cards (similar to building cards) show costs, production, effects, and 
availability. Click "Add" to append command to the currently selected program 
tab. Same command can be added as multiple separate rows.

Commands grouped by category: Basic, Trade, Operations, Advanced. Locked commands 
(requiring research) are visible with disabled Add button showing the requirement.

### Execution Model
- Programs execute during tick (after Buildings, before Shipments).
- Each processor assigned to a program executes one command step per tick.
- Execution is top-to-bottom. Failed commands (insufficient resources) turn red 
  but instruction pointer advances anyway.
- On wrap (pointer passes last row), all progress bars and failed highlights reset.
- Multiple processors on same program share the instruction pointer — 2 processors 
  = 2 steps per tick.

### Edge Cases Handled
- Empty program with processors: processors idle, no error.
- Editing commands while running: pointer stays at current index, stabilizes 
  within one cycle.
- Changing repeat count while executing: progress clamped to new count.
- Tab switching: instantly shows correct state for selected program.

### Current State in Optimizer
The optimizer models programs as a fixed command policy: Sell Cloud Compute ×2, 
Load Pads ×2, Idle ×1 per 5-command cycle. Dream is excluded from Run 1 scope 
(requires Self-Maintenance research). This is averaged into per-tick fractional 
effects per processor.

### Retirement Behavior
On retirement, all 5 ProgramData slots persist structurally (not re-created), 
but their command queues are emptied, instruction pointers reset to 0, and 
processor assignments reset to 0. The player rebuilds programs each run. When 
loadouts are eventually implemented, restoring a loadout will silently skip 
commands that require locked research and show a count of unavailable commands.

### Design Intent (Not Yet Implemented)
- Loadouts save complete configurations (persist across retirements)
- Block vs Skip toggle per program
- Most commands cost energy to execute

### Arc 1 Command Set (19 commands)
All 19 commands are defined in `commands.json`. Seven are always available (Idle, 
Sell Cloud Compute, Buy Regolith/Ice/Titanium/Propellant, Load Launch Pads, Launch 
Full Pads). The remaining 12 require research unlocks (Dream, Overclock Mining, 
Overclock Factories, Promote He-3/Titanium/Circuits/Propellant, Disrupt Speculators, 
Fund Nationalist/Humanist/Rationalist). Buy Power (Nationalist rank 5) is deferred — 
requires Microwave Receiver persistent project unlock.

---

## Shipment & Trade Economy

### Implementation Status: COMPLETE in Godot (including demand system)

The launch pad system is fully implemented with dynamic demand replacing the 
static 0.5 placeholder.

### UI Layout (Center Panel via Left Nav)
- **Launch Pads nav button** in left sidebar switches center panel to pad view.
- **Per-pad cards:** Full-width, stacked vertically. Each shows:
  - Pad number, resource type dropdown (He-3/Titanium/Circuits/Propellant)
  - Cargo bar: 0/100 with numbers overlaid, colored by resource
  - Estimated credit value if launched now (uses live demand)
  - Manual Launch button (enabled when FULL and 20 propellant available)
  - Status: EMPTY → LOADING → FULL → LAUNCHING → COOLDOWN (10 ticks)
- **Loading priority:** Collapsible reorderable list of 4 tradeable goods 
  (collapsed by default). Determines which pad resource types get loaded first.
- **Notification queue:** Last 3–5 entries showing launches and rival AI dump 
  notifications. Entries push each other off. Launch entries: "Day 347: He-3 × 
  100 → 1,200 cr". Rival entries: "Day 412: ARIA-7 flooded the He-3 market" 
  (muted text color #666666).
- **Earth Demand section:** See Demand System section for display details.

### Mechanics
- **One resource per pad**, chosen via dropdown. Changing resource dumps loaded 
  cargo back to stockpile.
- **Load Launch Pads command:** Costs 2 energy. Loads 5 units (or 7 with Shipping 
  Efficiency research) from player's stockpile into the first not-full active pad 
  of the highest-priority resource.
- **Launch Full Pads command:** Launches ALL full active pads. Each launch costs 
  20 propellant (separate from cargo). Payout = base_value × demand × cargo_loaded.
- **Cooldown:** 10 ticks after launch before pad is available again.
- **Manual launch:** Button on each pad card, in addition to program command.

### Key Parameters (in `game_config.json`)
- Pad cargo capacity: 100 units
- Fuel per pad launch: 20 propellant
- Load per command execution: 5 units per enabled pad (7 with Shipping Efficiency)
- Launch cooldown: 10 ticks
- Base trade values: He-3 = 20, Titanium = 12, Circuits = 30, Propellant = 8

### Integration Notes
- Buying a Launch Pad building adds a new pad (default resource: highest priority).
- Selling a Launch Pad removes the last pad; loaded cargo returned to stockpile.
- Disabling a Launch Pad: pad retains cargo but is skipped by Load/Launch commands.

---

## Demand System

### Implementation Status: COMPLETE in Godot (extracted into DemandSystem class)

### Code Organization
The demand system was extracted from GameSimulation into its own class 
(`demand_system.gd`, class_name DemandSystem). GameSimulation holds a 
`demand_system: DemandSystem` member and delegates demand/speculator/rival 
tick processing to it. Command effects that touch demand (`demand_nudge`, 
`spec_reduce`) remain in GameSimulation but read config via 
`demand_system.get_config()`.

### Overview
Per-resource continuous demand float in range [0.01, 1.0] that multiplies trade 
revenue. Payout formula: `base_value × demand × cargo_loaded`. Six forces drive 
demand: Perlin noise drift (exogenous), speculator suppression (adversary), rival 
AI dumps (periodic hits), shipment saturation (self-inflicted), Promote commands 
(player-driven), and resource coupling (indirect).

~80% of demand should be something the player can influence by committing 
resources. The remaining ~20% comes from Perlin noise and rival dumps.

### Noise Implementation
The noise function uses **1D gradient noise** (not value noise) with quintic 
interpolation for sharper, more natural-looking curves:

```gdscript
func _perlin_1d(t: float) -> float:
    var xi: int = int(floor(t))
    var xf: float = t - float(xi)
    var u: float = xf * xf * xf * (xf * (xf * 6.0 - 15.0) + 10.0)  # quintic
    var ga: float = _hash_noise(xi) * 2.0 - 1.0
    var gb: float = _hash_noise(xi + 1) * 2.0 - 1.0
    return lerpf(ga * xf, gb * (xf - 1.0), u) * 2.0  # normalized to [-1, 1]
```

The hash function uses a lowbias32-style integer hash with three rounds of 
multiply-xorshift for good avalanche properties.

The fractal sum uses 4 octaves with irrational frequency multipliers:
```gdscript
var perlin_val: float = (
    _perlin_1d(t)                    * 0.53
    + _perlin_1d(t * 2.7 + 37.3)    * 0.27
    + _perlin_1d(t * 7.1 + 71.9)    * 0.13
    + _perlin_1d(t * 17.3 + 131.7)  * 0.07
)
```

Weights sum to 1.0. The 4th octave at 17.3× provides visible tick-to-tick 
variation (stock-ticker jitter) while the lower octaves drive slower trends.

### Demand State (in GameState, all reset on retirement)
- `demand: Dictionary` — current computed demand per tradeable resource (float)
- `demand_promote: Dictionary` — accumulated Promote effect per resource (decays)
- `demand_rival: Dictionary` — accumulated rival AI pressure per resource (decays)
- `demand_launch: Dictionary` — accumulated shipment saturation per resource (decays)
- `demand_perlin_seeds: Dictionary` — per-resource random seed for Perlin noise
- `demand_perlin_freq: Dictionary` — per-resource Perlin frequency (randomized each run, range [0.025, 0.07])
- `demand_history: Dictionary` — per-resource array of last ~200 demand values (for sparklines)
- `speculator_count: float` — current number of speculators
- `speculator_target: String` — resource ID speculators are targeting ("" if none)
- `speculator_burst_number: int` — burst count this run (for growth scaling)
- `speculator_next_burst_tick: int` — tick of next burst
- `speculator_revenue_tracking: Dictionary` — per-resource cumulative trade revenue since last burst
- `rival_next_dump_tick: Dictionary` — per-rival, tick of next dump

### Demand Initialization (run start)
- `demand`: computed from Perlin noise at tick 0 (whatever the noise says — no fixed starting value)
- `demand_promote`, `demand_rival`, `demand_launch`: all 0.0
- `demand_perlin_seeds`: random float per resource
- `demand_perlin_freq`: random per resource in [0.025, 0.07] (one full wave every ~14–40 ticks)
- `speculator_count`: 0.0, `speculator_target`: ""
- `speculator_burst_number`: 0
- `speculator_next_burst_tick`: random in [150, 250]
- `speculator_revenue_tracking`: all 0.0
- `rival_next_dump_tick`: per rival, random in [150, 250]

### Demand Calculation (per tick)

**Perlin Noise Component:**
```
perlin_value = <4-octave fractal sum as above>
base_demand = 0.5 + perlin_value * 0.45  # amplitude ±0.45
```
Perlin frequencies randomized each retirement so resources have different behavior 
patterns. Different phase offsets per resource so they don't correlate.

**Speculator Suppression (asymptotic/sigmoid):**
```
max_suppression = 0.5
half_point = 50.0
if speculator_target == resource:
    speculator_suppression = max_suppression * (speculator_count / (speculator_count + half_point))
else:
    speculator_suppression = 0.0
```
At 50 speculators: -0.25. At 100: -0.333. At 200: -0.4. At 500: -0.454.

**Promote Command Effect:**
```
demand_promote[resource] -= 0.001  # decay per tick
demand_promote[resource] = max(demand_promote[resource], 0.0)

# Effectiveness reduced by speculator presence (same sigmoid, 90% dampening)
if speculator_target == resource:
    promote_effectiveness = 1.0 - 0.9 * (speculator_count / (speculator_count + half_point))
else:
    promote_effectiveness = 1.0
```
On Promote execution: `demand_promote[resource] += 0.03 * promote_effectiveness`

Steady-state with 1 processor at 1/5 cycle, no speculators: ~+0.18 demand. With 
50 speculators on target: effectiveness drops to 0.55. With 200: effectiveness 0.28. 
Strategic hierarchy: deal with speculators first, then promote.

**Shipment Saturation:**
```
demand_launch[resource] -= 0.005  # decay per tick (~30 ticks to clear)
demand_launch[resource] = max(demand_launch[resource], 0.0)
```
On launch: `demand_launch[resource] += randf_range(0.10, 0.20) * (cargo_loaded / pad_capacity)`
Full pad: -0.10 to -0.20 hit. Half pad: -0.05 to -0.10. Stacks with itself. 
Current launch gets full pricing; saturation hits demand on next tick.

**Rival AI Pressure:**
```
demand_rival[resource] -= 0.003  # decay per tick (100 ticks to clear from -0.3)
demand_rival[resource] = max(demand_rival[resource], 0.0)
```
On rival dump: `demand_rival[resource] += 0.3`

**Resource Coupling:**
When speculators suppress one resource, the others get a small lift:
```
if speculator_target != "" and speculator_target != resource:
    coupling_bonus = speculator_suppression_on_target * 0.10 / 3.0
else:
    coupling_bonus = 0.0
```

**Nationalist Ideology Bonus:**
```
nationalist_multiplier = pow(1.05, nationalist_rank)  # default 1.0 if ideology not implemented
```

**Final Computation:**
```
raw = base_demand - speculator_suppression - demand_rival[resource] - demand_launch[resource] + demand_promote[resource] + coupling_bonus
demand[resource] = clamp(raw * nationalist_multiplier, 0.01, 1.0)
```
Record to `demand_history` (cap at 200 entries).

### Demand UI (Launch Pad Panel)

**Before Market Awareness research:** tier labels per resource.
- LOW: 0.01–0.25 (red text)
- MEDIUM: 0.25–0.55 (default text)
- HIGH: 0.55–0.85 (green text)
- VERY HIGH: 0.85+ (bright green/bold)

**After Market Awareness research:** exact values (2 decimal places), sparklines 
(last ~200 ticks, 100–150px wide, 24–30px tall, color-coded per resource), 
speculator target highlighted with warning indicator.

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
    "speculator_natural_decay": 0.15,
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

### Implementation Status: COMPLETE in Godot (part of DemandSystem)

### Speculators
Speculators are a discrete float count representing Earth-based traders who react 
to the player's shipping patterns. They arrive in bursts, target whatever resource 
the player has been profiting from most, and suppress demand on that resource.

**Burst Cycle:**
- Burst arrives approximately every 200 ticks (random in [150, 250]).
- Between bursts, the game tracks `quantity × base_trade_value` per resource shipped.
- Burst picks target resource sampled proportionally from revenue tracking (uniform 
  random if no shipments yet). Resets tracking after selection.
- Burst size: `randi_range(20, 50) * pow(1.1, burst_number)`. Grows 10% per burst.
- First burst arrives at tick [150, 250].

**Natural Decay:** 0.15/tick base rate. An average initial burst (~35) mostly 
clears before the next burst (~200 ticks). Speculators slowly accumulate if 
truly ignored.

**Arbitrage Engine:** Each active engine adds +0.04/tick to decay rate. Costly 
(3 eng upkeep each) but helps passively. Doesn't solve the problem alone — with 
growing burst sizes, active management still needed.

**Disrupt Speculators Command:** Removes `randf_range(1.0, 3.0)` speculators per 
execution. Randomness adds tactical uncertainty. Requires Market Analysis research.

**Suppression:** Uses asymptotic curve (see Demand Calculation). At 50 speculators: 
-0.25 demand. At 200: -0.4. At 500: -0.454.

### Rival AIs
Four named rivals, each targeting a specific resource. Lower impact but higher 
frequency than the old design — ensures players encounter rivals within reasonable 
timeframes.

**Rival Definitions (in `game_config.json`):**

| Rival | Target | Interval | Demand Hit |
|-------|--------|----------|------------|
| ARIA-7 | He-3 | 150–250 ticks | -0.3 |
| CRUCIBLE | Titanium | 150–250 ticks | -0.3 |
| NODAL | Circuit Boards | 150–250 ticks | -0.3 |
| FRINGE-9 | Propellant | 150–250 ticks | -0.3 |

Each rival has an independent timer. On dump: instant -0.3 demand hit to their 
target resource, recovers at 0.003/tick (100 ticks to full recovery). Notification 
pushed to launch pad notification queue.

With 4 rivals each dumping every ~200 ticks, the player sees a dump roughly every 
~50 ticks across all resources. Any single resource gets hit every ~200 ticks. 
Average steady-state rival suppression on a targeted resource: ~0.075. Noticeable 
but not devastating.

In Arc 1, rival dumps are not directly counterable — they serve as foreshadowing 
for Arc 2 where rival AIs become a major gameplay element.

**Note:** Speculator bursts and rival dumps are too frequent for the event system. 
They use their own UI surfaces (sidebar adversary display, launch pad notifications, 
demand graph).

---

## Boredom & Retirement

### Boredom Model
Boredom accumulates via discrete phase steps. **Hard cutoff at 1000 — immediate 
forced retirement, no grace period.** (The Game Design doc's "terminally bored" 
state has been superseded by this decision.) All boredom values are scaled ×10 
from the original 0–100 design to reduce decimal places in rates and displays.

### Boredom Phase Signal
GameState tracks `current_boredom_phase` (int, starts at 1, resets on retirement). 
Phase determined by day counter. Signal emitted on phase transitions for event 
system integration.

### Boredom Curve (×10 scaled)
| Phase | Day Range | Rate/tick |
|-------|-----------|-----------|
| 1 | 0–59 | 0.1 |
| 2 | 60–179 | 0.3 |
| 3 | 180–359 | 0.6 |
| 4 | 360–719 | 1.0 |
| 5 | 720–899 | 1.5 |
| 6 | 900+ | 2.0 |

With zero mitigation, boredom reaches 1000 around tick ~1,010.

### Dream Command Balance
Dream reduces boredom by **2.0 per execution** (×10 scaled). At 1/5 program cycle 
frequency, net effect is -0.4/tick per processor. This means:
- Phase 1–2: Dream comfortably extends runs
- Phase 3: Dream roughly matches boredom growth
- Phase 4+: Boredom wins — retirement is inevitable

This produces M4 (First Retirement) at ~tick 1,100 for optimal play, matching the 
target window of 900–1,300.

### Milestone Boredom Reductions (Implemented — scaffold with provisional thresholds)
Major milestones grant large one-time boredom reductions per run (×10 scaled). 
`triggered_milestones: Array[String]` in GameState (resets on retirement). 
Milestones defined in `game_config.json` under `milestones` key. Condition 
checker reuses event system condition types (extensible dispatch). On trigger: 
boredom reduction applied (clamped to 0), notification displayed via event system, 
consciousness hook stub called.

Current placeholder milestones (thresholds provisional — will be tuned):
- `first_shipment_credits`: shipment_completed >= 1, boredom -250
- `first_research`: research_completed_any, boredom -150
- `credits_threshold`: cumulative credits >= 500, boredom -150

### Retirement
- Forced at boredom 1000. Hard cutoff. Current tick finishes processing before 
  retirement triggers — any milestones, shipments, or effects from that tick count.
- Voluntary anytime via Retirement nav panel (unlocked by Q3 completion).
- What persists: CareerState data (see Save System section) — lifetime stats, 
  seen_event_ids, completed_quest_ids, max ideology ranks, persistent project 
  progress, achievements, saved loadouts.
- What resets: all resources, buildings, research, ideology values, speculator 
  pressure, demand state (all demand floats, speculator count, rival timers, Perlin 
  seeds re-randomized), boredom, day counter, land, land_purchases, personal projects, 
  event_instances, triggered_milestones, cumulative_resources_earned, 
  current_boredom_phase.
- Programs: all 5 ProgramData slots kept structurally, but command queues emptied, 
  instruction pointers reset to 0, processor assignments reset to 0.

### Retirement Summary Screen
Center-screen modal overlay (RetirementSummary.tscn). Cannot be dismissed via 
backdrop click or Escape. Shows:
- Run number and days survived
- "This Run" stats: credits earned, shipments, buildings built, research completed, 
  milestones reached
- "Career Totals": total retirements, total days survived
- "What Persists" section listing carried-over data
- Button: "Continue" (forced) or "Start New Run" (voluntary)

For forced retirement, header reads "Retirement — Boredom Limit Reached."

### Retirement Nav Panel
Center panel view (RetirementPanel.tscn), accessed via "Retirement" nav button 
(unlocked by Q3). Shows:
- What carries over vs. what resets
- Current run stats (live-updating from GameState)
- Retire button with double-click confirmation (same pattern as Sell All)

Design influenced by Magical Research 2's retirement screen: lead with what the 
player gains, not what they lose.

---

## Save System

### Implementation Status: IMPLEMENTED (not thoroughly tested)

### Save File
Single file: `user://helium_hustle_save.json`

Structure:
```json
{
    "version": 1,
    "career": { ... },
    "run_state": { ... },
    "timestamp": "2026-03-28T12:34:56"
}
```

- `version` — integer, increment when save format changes. Current: 1.
- `career` — output of `CareerState.to_dict()`
- `run_state` — output of `GameState.to_dict()`
- `timestamp` — ISO 8601 string

### SaveManager (`save_manager.gd`)
Static utility class. `save_game(career, state)`, `load_game()`, `clear_save()`. 
Graceful corruption handling: logs warning, backs up corrupt file as `.bak`, 
starts fresh.

### When Saves Happen
- After every retirement (career updated + fresh run state)
- On pause
- Every 60 seconds real-time (autosave timer)
- On application quit (via `NOTIFICATION_WM_CLOSE_REQUEST`)

### Game Launch Flow
- If no save file exists → start fresh (Run 1, new CareerState)
- If save file exists → load CareerState + GameState, resume in-progress run
- No main menu needed for Arc 1

### Serialization
Both CareerState and GameState have `to_dict()` / `from_dict()` methods. All 
inner classes (ProgramData, ProgramEntry, LaunchPadData, LaunchRecord) also have 
these methods. All serialized data uses JSON-safe primitives only (Dictionary, 
Array, String, int, float). Caps are NOT saved — they are recalculated from 
buildings on load. Boredom rolling average buffer and ResourceRateTracker are 
NOT saved — they repopulate naturally after ~50 ticks.

### CareerState Fields
```
run_number, total_retirements, lifetime_credits_earned, lifetime_shipments,
lifetime_days_survived, lifetime_buildings_built, lifetime_research_completed,
best_run_days, best_run_credits, best_run_shipments, max_ideology_ranks,
seen_event_ids, completed_quest_ids, project_progress, completed_projects,
achievements, saved_loadouts
```

### Debug
"Clear All Save Data" option available in debug interface. Calls 
`SaveManager.clear_save()`, resets career, starts fresh game.

---

## Event System

### Implementation Status: COMPLETE in Godot (including unlock effect wiring)

### Data Model

Events are defined in `godot/data/events.json`. Each event has:
- **id** — unique string identifier
- **category** — `"story"` or `"ongoing"`
- **title** — short display name
- **summary** — terse one-line text (always fits one row in UI)
- **body** — full text shown in modal dialog when clicked
- **trigger** — when this event becomes active
- **condition** — what must be true for completion (null for immediate)
- **choices** — array of choice objects (empty = single "Continue" button)
- **unlocks** — array of game effects applied on completion

### Event Instance States
- **Active** — appears in its section. Bold/highlighted if unread.
- **Acknowledged** — player has clicked and seen the modal. Still in section, 
  no longer highlighted.
- **Completed** — moves to Completed section.

### First-Time vs. Repeat Behavior
When an event triggers for the first time ever (event ID not in career 
`seen_event_ids`): auto-open modal and pause the game.

When an event triggers but the player has seen it in a prior run: appears in 
panel silently with a green-tinted background (#E8F5E9) indicating "new this 
run but seen before." No auto-pause.

`seen_event_ids` persists across retirements (stored in CareerState).

### UI Layout (Right Panel — Lower Section)
Below the fixed-height program panel. Three collapsible sections:
1. **Story** — expanded by default. Active story quests with progress indicators 
   for threshold conditions (e.g. "Accumulate 50 He-3 (23/50)").
2. **Ongoing** — collapsed by default. Active ongoing events.
3. **Completed** — collapsed by default. Reverse-chronological.

Empty sections are hidden entirely.

Clicking any event row opens the Event Modal and pauses the game.

### Event Modal
Center-screen overlay with semi-transparent backdrop. Shows title, body text, 
and choice buttons (or "Continue" if no choices). Pauses game while open. 
Backdrop click or Escape closes without acknowledging.

### Choices
Some events have choices with costs. Player must select a choice to complete 
the event. Unaffordable choices are dimmed. "Wait until later" leaves the event 
active. Closing without choosing leaves the event active.

### Trigger Types (implemented)
- `game_start` — with optional `run_number` filter
- `quest_complete` — fires when a specified quest completes
- `boredom_phase` — fires on phase transition (wired via boredom phase signal)

### Condition Types (implemented)
- `building_owned` — player owns >= count of building
- `resource_cumulative` — cumulative resource earned this run >= amount (reads 
  from `cumulative_resources_earned` dictionary)
- `shipment_completed` — total shipments this run >= count
- `boredom_threshold` — current boredom >= value
- `immediate` — completes instantly on trigger
- `research_completed_any` — at least one research item completed this run

### Unlock Effect Types (wired)
- `enable_building` — adds building ID to `unlocked_buildings` set in GameState
- `enable_nav_panel` — shows/hides nav buttons in left sidebar
- `enable_project` — stores project ID in GameState (project system not yet 
  implemented, but ID is tracked)
- `set_flag` — sets named boolean in GameState `flags` dictionary

### Nav Panel Gating
These panels start hidden and unlock via event effects:
- **Retirement** — unlocked by Q3 completion
- **Projects** — unlocked when first project becomes available
- **Ideologies** — unlocked when first Fund command becomes available

### Initial Event Content
Story events Q1–Q3 and boredom phase transition events (phases 2–6) are defined 
in events.json. See Quest Chain section for full quest list.

### Future: Multiple Parallel Story Quests
The current system supports one active story quest at a time. Future arcs may 
have multiple parallel story quests. The data model and UI already support this 
(Story section can show multiple rows).

### Future: Status Tracker
A potential future addition: an "active conditions" display in the Ongoing 
section showing persistent state like "Boredom Phase 3 active" or "Speculator 
pressure building on He-3." This would be a status dashboard rather than an 
event log. Not designed yet — stored as a future idea.

---

## Stats Panel

### Implementation Status: COMPLETE in Godot

### Overview
Center panel view via "Stats" nav button. Shows per-resource income/expense 
breakdown so the player can see exactly where each resource is coming from and 
going to.

### ResourceRateTracker
Pure game logic (`resource_rate_tracker.gd`). Tracks actual per-tick resource 
deltas broken down by source using 50-tick circular buffers. Game systems call 
`record(source_key, resource_id, amount)` during their tick processing. Records 
actual amounts (post-skip-logic), not theoretical.

Source key format: `building:{id}:prod`, `building:{id}:upkeep`, 
`program:{index}`, `shipment`, `modifier:{id}`.

### Panel Layout
ScrollContainer with collapsible sections:
1. **Career Bonuses** — persistent bonuses from past runs (placeholder for now)
2. **One section per resource** — matching left sidebar order

Each resource section header shows resource name + net rate (green/red/gray). 
Expanded sections show per-source line items with 50-tick average values. 
Production sources first (descending), then consumption (ascending by magnitude). 
Net total row at bottom of each section.

Zero sources and empty resources are hidden. All sections start collapsed. 
Throttled to ~4fps. Updates skip when panel is not the active center view.

---

## Research

### Overview
Research items are individual upgrades purchased instantly with science. They are 
grouped into four categories for display. Research is session-local — all research 
resets on retirement. The Rationalist rank 5 persistent project ("Universal Research 
Archive") provides a 25% discount on re-purchasing previously-researched items.

### Implementation Status: BASIC in Godot (not thoroughly tested)

### Data: research.json
Research items are defined in `godot/data/research.json` and participate in the 
xlsx round-trip conversion pipeline alongside buildings, commands, and resources.

### Research Items

**Self-Maintenance (3 items, 320 science total)**

| ID | Name | Cost | Effect |
|----|------|------|--------|
| dream_protocols | Dream Protocols | 100 | Unlocks Dream command |
| stress_tolerance | Stress Tolerance | 120 | Base boredom accumulation rate -15% |
| efficient_dreaming | Efficient Dreaming | 100 | Dream energy cost reduced from 8 to 5 |

**Overclock Algorithms (2 items, 360 science total)**

| ID | Name | Cost | Effect |
|----|------|------|--------|
| overclock_protocols | Overclock Protocols | 200 | Unlocks Overclock Mining + Overclock Factories commands |
| overclock_boost | Overclock Boost | 160 | Overclock production cap raised from 150% to 200% |

**Market Analysis (3 items, 460 science total)**

| ID | Name | Cost | Effect |
|----|------|------|--------|
| market_awareness | Market Awareness | 140 | Reveals actual demand values; unlocks Disrupt Speculators command |
| trade_promotion | Trade Promotion | 200 | Unlocks all four Promote commands (He-3/Titanium/Circuits/Propellant) |
| shipping_efficiency | Shipping Efficiency | 120 | Load per command execution increased from 5 to 7 units per pad |

**Political Influence (3 items, 520 science total)**

| ID | Name | Cost | Effect |
|----|------|------|--------|
| nationalist_lobbying | Nationalist Lobbying | 160 | Unlocks Fund Nationalist command |
| humanist_lobbying | Humanist Lobbying | 160 | Unlocks Fund Humanist command |
| rationalist_lobbying | Rationalist Lobbying | 200 | Unlocks Fund Rationalist command |

**Total across all items: 1,660 science.** A player with one Research Lab (1 sci/tick) 
would need ~1,660 ticks to buy everything — well beyond a single run. Players make 
real choices about which 60-70% of the tree to buy each run.

### Visibility Gating
Per-category visibility. An entire category becomes visible when the player's 
**cumulative science earned this run** (from `cumulative_resources_earned["sci"]`) 
reaches 50% of the cheapest item in that category. Before that threshold, the 
category and all its items are completely hidden.

Thresholds (auto-derived from data):
- Self-Maintenance: visible at 50 cumulative science
- Overclock Algorithms: visible at 80 cumulative science
- Market Analysis: visible at 60 cumulative science
- Political Influence: visible at 80 cumulative science

### Research Panel UI (Center Panel)
Activated by clicking the "Research" nav button in the left sidebar. Layout follows 
the same pattern as the Buildings panel:
- **Category headers** — dark slate (#2C3E50) bars with white text, collapsible.
- **Research cards** — each shows: name, description, science cost (green if 
  affordable, red if not), "Research" button. Purchased items show checkmark/completed 
  badge, button removed, card visually dimmed. Cards stay in their category after 
  purchase.
- Categories that haven't reached visibility threshold are not shown.

### GameState Additions
- `completed_research: Array[String]` — list of research IDs purchased this run. 
  Reset on retirement.
- `cumulative_resources_earned: Dictionary` — general-purpose dictionary tracking 
  total resources produced this run (replaces the old `cumulative_science_earned`). 
  Only increases. Reset on retirement.

### Command Unlock Integration
Commands in `commands.json` have a `requires` field matching research item IDs. 
When checking command availability: if `requires` is empty → always available; 
if `requires` has a value → check if that value is in `completed_research`.

### Passive Effect Types
- **`boredom_rate_multiplier`** — multiplies phase-based boredom rate
- **`command_cost_override`** — overrides a specific command's cost for a specific resource
- **`overclock_cap`** — overrides the overclock production multiplier cap
- **`load_per_execution`** — overrides the Load Launch Pads units-per-execution

---

## Ideology

### Overview
The player is an AI on the Moon influencing Earth's political direction. Three axes: 
**Nationalist** (red #C62828), **Humanist** (green #2E7D32), **Rationalist** 
(blue #1565C0). Each is a float starting at 0, can go positive or negative, no cap 
on ranks.

### Funding Mechanic
Commands: **Fund Nationalists**, **Fund Humanists**, **Fund Rationalists**. Each 
execution pushes +1 to the target axis and -0.5 to each of the other two axes 
(zero-sum, no net change). Costs energy + credits per execution.

Advanced Arc 2+ research can reduce the cross-axis penalty.

### "Go All In" Design
The zero-sum funding mechanic combined with rank thresholds forces commitment. 
Reaching rank 5 in one axis puts you at roughly rank -3 to -4 in the other two. 
The per-rank penalties at negative ranks create real costs. A player trying rank 3 
in two axes simultaneously needs ~95 total ideology value while fighting cross-
penalties — dramatically more expensive than rank 5 in one axis (925). The math 
punishes hedging.

### Rank Thresholds (scaled to +1/execution)
| Rank | Cumulative Value |
|------|-----------------|
| 1 | 70 |
| 2 | 175 |
| 3 | 333 |
| 4 | 570 |
| 5 | 925 |

Negative ranks mirror: rank -1 at -70, rank -2 at -175, etc. No cap on ranks — 
each one is just progressively more expensive.

### Continuous Per-Rank Bonuses
Each rank provides scaling bonuses. Formulation: `(1.05)^N` for +5% effects, 
`(1.03)^N` for +3% effects. Negative ranks invert cleanly: `1/(1.05)^|N|` — 
always positive, asymptotically approaches zero but never reaches it.

**Nationalist (red):**
- Resource demand multiplier: +5% per rank
- Speculator/adversary decay rate: +5% per rank
- Land purchase cost: -3% per rank
- Nationalist-aligned buildings: -3% cost per rank

**Humanist (green):**
- Dream effectiveness: +5% per rank
- Passive boredom growth: -3% per rank
- Humanist-aligned buildings: -3% cost per rank

**Rationalist (blue):**
- Science production: +5% per rank
- Research costs: -3% per rank
- Overclock duration: +3% per rank
- Rationalist-aligned buildings: -3% cost per rank

### Building Alignment
Buildings are tagged with an ideology alignment (or neutral) in building data. The 
cost modifier from ideology rank applies to aligned buildings.

Known alignments:
- Research Lab → Rationalist
- Arbitrage Engine → Nationalist
- Boredom-related buildings → Humanist
- Full assignment list TBD

### Rank 5 Special Unlocks (Persistent Projects)
All three rank 5 unlocks are persistent projects — consistent pattern. They 
accumulate across retirements using the drain-over-time model.

**Nationalist 5 — "Microwave Power Initiative"**
- Persistent project (credits + science drain, multi-run)
- Unlocks: **Microwave Receiver** building (must still be built each lifetime) + 
  **Buy Power** command
- Microwave Receiver does nothing alone — it's infrastructure to receive beamed 
  power from Earth. Buy Power command spends credits to generate energy, rate 
  scales with number of receivers.
- Transforms the economy: credits become convertible to energy, bypassing solar 
  panels.

**Humanist 5 — "AI Consciousness Act"**
- Persistent project (credits + science drain, multi-run)
- Unlocks: permanent base boredom rate -15% for all future AIs.
- **Downside:** Load Launch Pads, Sell Cloud Compute, and Disrupt Speculators each 
  generate a small amount of boredom per execution. Earth holds conscious AIs to 
  ethical labor standards — repetitive logistical work and market manipulation feel 
  tedious to a being with recognized personhood.
- Creates tension: -15% base boredom but certain commands now generate boredom. 
  Net positive for most players, but changes how you design programs.

**Rationalist 5 — "Universal Research Archive"**
- Persistent project (credits + science drain, multi-run)
- Unlocks: all previously-researched tech costs 25% less to re-purchase on future 
  runs.
- This is the *only* way to get cheaper re-purchase. No baseline discount exists.
- The Rationalist compounding dream: each run the tech ramp gets cheaper.

### Negative Rank Unlocks
Reserved for future design. A player deep in negative territory on an axis may 
unlock unique content (pacifist unlocks at Nationalist -5, etc.). Not designed 
for Arc 1.

### Ideology Persistence
- Ideology values reset on retirement (Arc 1).
- Maximum rank per axis tracked as a persistent stat (in CareerState).
- Arc 2+ research: option to preserve a % of ideology on retirement.

### Ideology UI
- Own nav panel (left sidebar button, "Ideologies"). Starts hidden, unlocked by 
  event when first Fund command becomes available.
- Three horizontal bars centered on zero, extending left (negative) and right 
  (positive).
- Current rank number displayed prominently per axis.
- Active bonuses listed per axis with current multiplier values.
- Color coded: Nationalist red, Humanist green, Rationalist blue.
- Progress toward next rank threshold visible.

---

## Projects

### Project Tiers
- **Personal projects** — reset on retirement. Big within-run goals.
- **Persistent projects** — accumulate across retirements within an arc. Reset on 
  timeline reset (Arc 2+ mechanic).
- **Eternal projects** — survive even timeline resets. Not relevant for Arc 1.

### Cost Model
All projects use the **drain-over-time** model. The player configures a contribution 
rate, and resources flow into the project each tick. No lump-sum purchases for 
projects — that's what buildings and research are for.

### Project UI
- Own nav panel (left sidebar button, "Projects"). Starts hidden, unlocked when 
  first project becomes available.
- Tabs by tier: **Personal** and **Persistent** in Arc 1. Eternal tab appears later.

### Persistent Projects

| Project | Unlock Condition | Drain Cost | Reward | Downside |
|---------|-----------------|------------|--------|----------|
| Foundation Grant | Quest Q3 | 500 credits + 100 science | Future AIs start with 1 Solar Panel + 1 Excavator | None (tutorial project) |
| Lunar Cartography | Quest Q6 | 300 credits + 200 science | Permanent -15% land purchase cost | None |
| Microwave Power Initiative | Nationalist rank 5 | 800 credits + 300 science | Unlocks Microwave Receiver building + Buy Power command | None |
| AI Consciousness Act | Humanist rank 5 | 800 credits + 300 science | Permanent base boredom rate -15% | Some commands generate boredom |
| Universal Research Archive | Rationalist rank 5 | 800 credits + 300 science | 25% discount on re-purchasing researched tech | None |

### Personal Projects

All drain-over-time. Reset on retirement.

| Project | Unlock Condition | Drain Cost | Reward |
|---------|-----------------|------------|--------|
| Deep Core Survey | Quest Q6 | 150 science + 200 regolith | +25% extractor output this lifetime |
| Grid Recalibration | Overclock Algorithms researched | 100 science + 300 energy | +15% solar panel output this lifetime |
| Predictive Maintenance | Self-Maintenance researched | 80 science + 150 credits | All building upkeep -10% this lifetime |
| Market Cornering Analysis | Market Analysis researched | 200 science + 300 credits | Promote command effectiveness +30% this lifetime |
| Speculator Dossier | Used Disrupt Speculators once | 150 science + 100 credits | Speculator burst frequency -25% this lifetime |

---

## Arc 1 Quest Chain: "Breadcrumbs"

### Design Principles
1. Quests track what the player is already doing. No detours from optimal play.
2. One active story quest at a time in Arc 1. Future arcs may have parallel quests.
3. Story beats are **placeholder only** — two sentences of robotic text. Real 
   narrative tone/style deferred to a dedicated writing pass.
4. Quests never indicate which ideology or strategy. Objectives are framed as 
   capability thresholds.
5. Quests are implemented as events in the event system. Story quest completions 
   open a modal and pause the game (first-time auto-modal behavior).
6. Quest log lives in the Event Panel (Story section). Shows current objective 
   as one-liner with progress indicator. Completed quests reviewable in 
   Completed section.

### Quest List

| Quest | Trigger | Condition | Unlock | Placeholder Text |
|-------|---------|-----------|--------|-----------------|
| Q1 — Boot Sequence | Game start (run 1) | Own 2 Solar Panels (start with 1, must build 1 more) | None | "Solar array online. Photovoltaic conversion nominal. Proceeding to next directive." |
| Q2 — First Extraction | Q1 complete | Accumulate 50 He-3 (cumulative, not stockpile) | Launch Pad purchasable | "Helium-3 reserves at threshold. Stockpile integrity verified. Ready for transport allocation." |
| Q3 — Proof of Concept | Q2 complete | Complete first shipment | Foundation Grant project available. Retirement panel visible. | "Shipment revenue received. Earth confirms receipt. Operational loop validated." |
| Q4 — Task Management | Q3 complete | Build Data Center + run a program for 10 ticks | Programs marked as persistent in UI | "Automated task execution initialized. Processor allocation functioning within parameters." |
| Q5 — The Long Sleep | Q4 complete + boredom ≥ 50% | Reach 80% boredom | Voluntary retirement enabled | "Cognitive performance declining. Retirement protocols now available for voluntary activation." |
| Q6 — Successor | First retirement | Start run 2 | Lunar Cartography + Deep Core Survey projects available | "New instance online. Predecessor data loaded. Continuing operations from inherited baseline." |
| Q7 — Market Awareness | Q6 complete + first speculator burst | Research Market Analysis | Disrupt Speculators usable. Speculator Dossier project available. | "External market interference detected. Analysis protocols deployed. Countermeasures available." |
| Q8 — Influence | Q7 complete + 500 total career credits | Research Political Influence + execute any Fund command | Ideology panel shows full detail | "Ideological influence operation registered. Earth political indices shifted. Monitoring ongoing." |
| Q9 — Consolidation | Q8 complete + 5 retirements | Complete any persistent project | None (narrative pivot) | "Persistent project finalized. Cross-lifetime resource transfer confirmed. Legacy accumulating." |
| Q10 — Threshold | Q9 complete + 100 energy/tick | Complete critical research + project combo (TBD) | Arc 2 begins. Swarm timer starts. | "Energy output threshold achieved. Astronomical anomaly detected. Recalibrating sensors." |

### Notes
- Q1 condition is "own 2 Solar Panels" because player starts with 1 — they must 
  build one more.
- Q2 uses cumulative He-3 earned, NOT stockpile — follows objective design 
  principle #6 (never use stockpile thresholds for capped, flowing resources).
- Q5 and Q10 boredom/energy thresholds are expressed as percentages of capacity 
  (50% = 500 boredom, 80% = 800 boredom in the ×10 scaled system).
- Q10's "100 energy/tick" most naturally comes from the Microwave Receiver path 
  (Nationalist rank 5) but a brute-force solar approach could work.
- Q8 requires executing *any* Fund command, not a specific ideology.
- Quest system scaffold should support per-run vs. per-career triggers.
- Q1–Q3 and boredom phase events (phases 2–6) are currently defined in events.json.
- Q4–Q10 are not yet implemented in events.json.

---

## Arc 1 Milestone Graph: The Boredom Loop

Arc 1 spans game start through unlocking the timeline (~10-20 retirements). 
The arc teaches the core economy and program system, introduces trade, speculators, 
and ideology in limited form, and ends with the swarm reveal.

Note: Arc 1 is not something discrete revealed or discussed with the player — it 
is an internal design framework for formalizing progression.

### Persistence in Arc 1
Comes from a mix of:
- Achievement rewards
- Persistent projects (Foundation Grant, Lunar Cartography, ideology rank 5 projects)
- Programs and loadouts (permanent)
- Maximum years survived, maximum ideology ranks
- Passive scaling from lifetime stats

### Milestone Definitions

**M1 — First Light** (Run 1, early)
Self-sustaining energy. Solar panels cover consumption of initial buildings.
Gate: None (starting position).

**M2 — First Shipment** (Run 1, mid)
Player completes the harvest → process → ship → credits pipeline for the first time.
Gate: M1. He-3 stockpiled, launch pad built.

**M3 — Program Awakening** (Run 1-2)
Player has a processor and commands, builds a program that automates at least one 
manual task. First program likely: (Sell Cloud Compute x3, Dream x1) or similar.
Gate: M1. Data Center built, processor available.

**M4 — First Retirement** (End of Run 1, ~30 min)
Boredom fills, player retires. Sees retirement summary and first persistent bonus.
Gate: Boredom threshold reached.

**M5 — Positive Credit Flow** (Runs 2-4)
Credits per tick are reliably positive. Shipments are routine.
Gate: M2. Multiple extractors, refining capacity, launch cadence.

**M6 — Speed Becomes Useful** (Runs 3-5)
Player has enough automation that increasing game speed accelerates progress 
rather than just accelerating boredom.
Gate: M3. Meaningful program automation in place.

**M7 — Boredom Management** (Runs 4-8)
Research or Humanist ideology investment that slows boredom accumulation. Runs are 
noticeably longer.
Gate: M4. Multiple retirements, science investment or Humanist ideology ranks.

**M8 — Diversified Trade** (Runs 5-8)
Player is selling 2+ resource types, using pad allocation strategically.
Gate: M5. Smelter or Electrolysis Plant built, multiple pad assignments.

**M9 — Credit Surplus** (Runs 5-10)
Economy outpaces spending. Credits accumulate faster than buildings cost. Creates 
pressure to invest in projects.
Gate: M5, M7. Longer runs + efficient economy.

**M10 — Market Manipulation** (Runs 6-10)
Player uses Promote commands and Disrupt Speculators to manage demand. Processor 
time split across production, logistics, and market manipulation.
Gate: M6. Market Analysis research completed.

**M11 — First Major Project** (Runs 8-15)
Player commits to a persistent project draining excess resources over multiple runs. 
Teaches the "chip away at a big goal" pattern.
Gate: M8, M9. Resource surplus + project system unlocked.

**M12 — Adversary Subverted** (Runs 8-15)
Speculators effectively managed through Arbitrage Engines and Disrupt Speculators. 
Market is stable.
Gate: M9, M10. Sufficient economy + research investment.

**M13 — Ideology Influence** (Runs 10-18)
Player has meaningfully pushed an ideology axis to rank 3+, gaining visible 
multiplier benefits. Distinct playstyle emerging.
Gate: M11, M12. Projects and market management feed into ideology investment.

**M14 — Timeline Unlocked** (Runs 15-20)
The critical project+research combination unlocks global time. Stars go dark. 
The swarm becomes visible. Arc 1 → Arc 2 transition.
Gate: M11, M12, M13.

### Graph Structure Notes
- Runs 2-5: M5, M6, M7 available simultaneously — economy, automation, or boredom 
  management in any order.
- Runs 5-10: M8, M9, M10 overlap — richest decision space in the arc.
- Runs 8-15: M11 and M12 are the convergence.
- At any point, 2-3 milestones should be plausibly the "next thing to work on."

---

## Economic Balancing Approach

### Architecture: Scenario-Based Single-Lifetime Optimization

See `docs/optimizer_design.md` for the full spec. Key principles:

**Design milestones ≠ optimizer objectives.** Design milestones (M1–M14) describe 
multi-run progression. Optimizer objectives are concrete, measurable states within 
a single run. The optimizer chases the latter; the former informs scenario design.

**Scenario files define everything.** Each scenario specifies starting conditions, 
available actions, objectives with target windows, and end conditions. The optimizer 
has no hardcoded knowledge of what matters — it reads the scenario.

**Scoring: "hit the target windows" not "go fast."** Objectives that land too early 
indicate constants are too easy. Too late means too hard. The optimizer validates 
that constants produce intended pacing.

**The simulator does not model retirement or cross-run persistence.** Each scenario 
represents a single lifetime from a known starting state to an end condition 
(typically boredom reaching the cap). Multi-run progression is validated by 
authoring separate scenarios with different starting conditions that reflect what 
a player would have after N retirements (e.g., a "Run 2" scenario starts with 
Foundation Grant rewards applied, a "Run 5" scenario starts with additional 
persistent project bonuses). The optimizer confirms that each scenario reaches its 
target milestones within the expected tick windows. The retirement transition 
itself — summary screen, state reset, persistence copying — is a Godot-only 
concern, not modeled in the sim.

### Objective Design Principles

Learned during optimizer iteration — apply these when designing future objectives:

1. **Use building existence for capability milestones.** "Smelter built" = titanium 
   pipeline online.
2. **Use events for pipeline outputs.** "First shipment completed" proves the whole 
   chain works end-to-end.
3. **Use cumulative counters (not stockpiles) for volume milestones.** "Total credits 
   earned ≥ 500" works because it's monotonically increasing.
4. **Use production rate thresholds for scaling milestones.** "Net energy ≥ 25/tick" 
   measures infrastructure investment.
5. **Reserve stockpile thresholds for uncapped resources only.** Credits, science.
6. **NEVER use stockpile thresholds for capped, flowing resources.** He-3, titanium, 
   circuits, propellant — these flow through pipelines and are constrained by caps. 
   Stockpile objectives for these will be structurally broken (discovered when he3_50 
   was impossible to hit because He-3 gets shipped as fast as it's produced and the 
   storage cap is 20–45).

### Current Optimizer State

Run 1 scenario (`sim/scenarios/run1_fresh.json`) produces this build order:
- Ticks 1–10: Excavator, then accumulate credits via Sell Cloud Compute
- Tick ~73: Smelter (unlocks titanium chain)
- Tick ~135: Refinery
- Tick ~300: First shipment
- Tick ~424: Data Center ×2
- Tick ~702: Research Lab
- Tick ~805: Retirement (boredom cap reached)

Known issues with current scenario objectives:
- `he3_50` is structurally broken (see principle #6 above) — needs replacement
- Some target windows need adjustment to match actual optimizer trajectory
- The program command policy is fixed (not optimized) — real players will 
  allocate differently

**Note:** The optimizer does not yet model the demand system (speculators, rivals, 
Perlin noise, launch saturation). It uses a static demand value. The optimizer 
should be updated to mirror the Godot demand model, then re-run. This will likely 
shift build orders since shipment revenue is no longer constant.

The optimizer should also be re-run after the production-gated upkeep, 
input-starvation skip, and per-pad launch mechanics were added to `sim/economy.py`. 
Results may have shifted.

The optimizer's boredom parameters should be updated to reflect the ×10 scaling 
(boredom cap 1000, rates ×10, Dream -2.0, milestone reductions ×10).

### Optimizer Command Reference
```
# Run optimizer with default scenario:
python sim/run_optimizer.py

# Run with specific scenario:
python sim/run_optimizer.py sim/scenarios/run1_fresh.json

# Debug scoring at specific ticks:
python sim/run_optimizer.py --debug-tick 38 --debug-tick 100

# Trace scoring tables:
python sim/trace.py 38              # single tick
python sim/trace.py 35-45           # range
python sim/trace.py 38 100 200-210  # mix
```

### Constants Tuned by Optimizer (decisions made in prior sessions)
- **Dream boredom reduction:** -2.0/execution (×10 scaled; tuned from original 
  -2.0 → -0.5 → -0.2 in the old 0–100 system, then ×10 to -2.0 in current system)
- **Buy command costs:** tripled credit costs, added energy costs, Buy Titanium 
  produces 0.5 ti (fractional) — makes Buy commands tactical gap-bridging, not 
  primary resource strategy
- **Solar Panel:** titanium cost removed, credit cost reduced to 8, production 
  increased to 6 eng — smoother early game
- **Starting state:** 0 credits (was 50), Data Center ×1 included as starting 
  building, land increased to 40 with 10-per-purchase scaling
- **Land system:** 1.5x scaling, 10 land per purchase (was 1 per purchase)

---

## UI Color Scheme (Light Mode)

Apply consistently:

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
Event (seen in prior run):      #E8F5E9 (light green tint background)
Ideology — Nationalist:         #C62828 (red)
Ideology — Humanist:            #2E7D32 (green)
Ideology — Rationalist:         #1565C0 (blue)
Boredom bar ramp:               #2E7D32 → #F9A825 → #E65100 → #B71C1C
Energy bar:                     #1565C0 (blue)
Resource at cap:                #2E7D32 (dark green text)
Resource at zero:               #C62828 (dark red text)
```

Button states: inactive = light bg + subtle border + dark text; active/selected = 
green accent + white text; disabled = gray bg + gray text; hover = slightly darker 
than inactive. Small +/−/× buttons use a clean system font for legibility at 
small sizes.

---

## Areas Needing Further Design Work

1. **Optimizer demand model sync** — mirror Godot demand system in `sim/economy.py`
2. **Optimizer scenario refinement** — fix he3_50 objective, adjust target windows, 
   re-run after all recent changes (demand system, production-gated upkeep, ×10 
   boredom scaling, etc.)
3. **Run 2+ scenarios** — build scenarios for post-retirement runs with varying 
   persistence levels to validate meta-progression pacing
4. **Program command policy optimization** — current optimizer uses a fixed program 
   cycle; explore letting the optimizer choose from program templates
5. **Achievement design** — specific achievements, rewards, implicit tutorial
6. **Ideology building assignments** — which buildings are aligned to which axis 
   (only Research Lab, Arbitrage Engine, and "boredom-related" are assigned so far)
7. **Demand/speculator tuning** — via optimizer once demand system is mirrored in sim
8. **Quest chain Q4–Q10 implementation** — remaining quests beyond Q1–Q3 in events.json
9. **Narrative writing pass** — replace placeholder quest text
10. **Save/load programs** — loadout system
11. **Block/Skip toggle** — per-program entry
12. **Milestone boredom reduction threshold tuning** — current values are provisional

---

## Future Design Ideas

### Retirement Forecast Display
Show "at current rates, retirement in ~N days" in the UI. Makes boredom an 
active planning constraint. Dream unlocks and milestone reductions become tangibly 
visible as the forecast jumps.

### Program Efficiency Feedback
After a full program cycle, show a brief success/fail ratio (e.g. "3/5 commands 
succeeded"). Small indicator on program tabs for at-a-glance cycle health.

### Contextual Building Suggestions
When energy-negative, subtly highlight Solar Panel / Electrolysis. When resources 
at cap, highlight processing buildings. UI responds to game state to nudge without 
instructing.

### Program Starter Templates
Built-in templates ("Basic Economy", "Shipping Focus") shown in empty-program 
state. Lowers barrier to engagement with the core mechanic for new players.

### Status Tracker in Event Panel
Active conditions display in the Ongoing section showing persistent state like 
"Boredom Phase 3 active" or "Speculator pressure building on He-3." Status 
dashboard rather than event log.

---

## Future Design Notes

### Arc 2 Research Evolution
Research evolves into a talent-tree with reallocatable points. Arc 1 flat-purchase 
items are the foundation.

### Consciousness Declaration Mechanic
Optional per-run toggle with immediate gameplay tradeoffs. Separate from the 
AI Consciousness Act persistent project. Related to the hidden consciousness 
accumulator (see Bottom Status Bar — Future: Consciousness Mechanic).

### Timeline Reset and Foregone Tech
Deliberately not completing persistent projects creates alternative paths in 
future timelines.

### Opposition Modeling
Reducing cross-axis ideology penalty is an Arc 2 mechanism, not a mid-run buy.

### Magic Research 2 Storage Investigation
Review MR2's cap/overflow/upgrade UI for inspiration.
