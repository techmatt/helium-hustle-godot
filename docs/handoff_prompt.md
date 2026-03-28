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
    game_config.json       ← GROUND TRUTH for starting state, boredom, shipment, etc.
  scenes/
    main_ui.tscn           ← Main scene (three-column layout)
    ui/BuildingCard.tscn
    ui/BuyLandCard.tscn    ← Buy Land card (full-width, top of Buildings panel)
    ui/CommandRow.tscn     ← Program command row (reusable)
    ui/LaunchPadCard.tscn  ← Launch pad widget (full-width)
    ui/EventPanel.tscn     ← Event panel (lower right panel)
    ui/EventModal.tscn     ← Event modal dialog (center-screen overlay)
    ui/StatsPanel.tscn     ← Stats panel (center panel view)
  scripts/
    game/
      game_state.gd        ← class_name GameState — pure data, no UI
      game_simulation.gd   ← class_name GameSimulation — pure logic, no UI
      game_manager.gd      ← autoload singleton, owns state + sim
      event_manager.gd     ← class_name EventManager — event logic, no UI
      resource_rate_tracker.gd ← class_name ResourceRateTracker — per-source rate tracking
    ui/
      main_ui.gd           ← Main UI controller
      building_card.gd     ← BuildingCard (PanelContainer subclass)
      buy_land_card.gd     ← BuyLandCard widget
      command_row.gd       ← CommandRow for program list
      launch_pad_card.gd   ← LaunchPadCard widget
      event_panel.gd       ← Event panel UI
      event_modal.gd       ← Event modal UI
      stats_panel.gd       ← Stats panel UI
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
inherently need them (boredom rates, circuit production, demand floats, etc.).

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
     numbers on bar), estimated credit value, manual Launch button
   - Loading priority: collapsible reorderable list of 4 tradeable goods
   - Each pad assigned one resource type via dropdown
   - 10-tick cooldown after launch before pad is available again
   - Recent Launches display (last 3–5 launches with day, resource, quantity, 
     credits earned)
   - Demand placeholder (static 0.5 baseline, space reserved for future graph)

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

12. **Stats panel** — center panel view via "Stats" nav button. Per-resource income/ 
    expense breakdown using ResourceRateTracker with 50-tick moving averages. 
    Collapsible sections per resource showing per-source line items. Career Bonuses 
    section (placeholder). Throttled to ~4fps.

13. **Buy Land card** — full-width card at top of Buildings panel. Shows land 
    usage, next purchase cost, and Buy button. 15 credit base, 1.5x scaling, 
    10 land per purchase.

14. **Resource list improvements** — ordered Boredom/Energy/Processors/Land first, 
    then remaining resources. Processor display shows assigned/total. No income 
    rates in sidebar (moved to Stats panel). Cap coloring: dark green at cap, 
    dark red at zero for capped resources.

### In the Python Optimizer (`sim/`)

1. **Scenario-based architecture** — optimizer loads scenario JSON files that 
   define starting conditions, available actions, objectives with target windows, 
   and end conditions. See `docs/optimizer_design.md` for full spec.
2. **Tick-accurate economy model** (`economy.py`) — pure state machine matching 
   the Godot tick order. Buildings, programs (fixed policy), shipments, boredom, 
   storage caps all modeled. Includes production-gated upkeep, input-starvation 
   skip, and per-pad launch mechanics with cooldown.
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

1. **Retirement** — forced at boredom 100, voluntary anytime, reset logic (see 
   Boredom & Retirement section)
2. **Building unlock requirements** — "Requires" field exists in data but isn't 
   enforced in Godot
3. **Milestone boredom reductions** — scaffold needed (see Boredom & Retirement)
4. **Demand system** — price fluctuations, speculator pressure (see Shipment & 
   Trade Economy section)
5. **Quest chain content beyond Q1–Q3** — Q4–Q10 need implementation
6. **Speculators & rival AIs** — see Speculators & Rival AIs section
7. **Ideology** — see Ideology section
8. **Projects** — see Projects section
9. **Boredom phase signal** — GameState needs `current_boredom_phase` variable 
   and signal on phase change for event system integration
10. **Cumulative resource counter unification** — unify `cumulative_science_earned` 
    with general `cumulative_resources_earned` dictionary
11. **Save/load programs** — loadout system for saving/loading program configs
12. **Block/Skip toggle** — per-program entry option
13. **Cross-retirement program persistence**
14. **Persistence/save layer** — architecture for what survives retirement

---

## Architecture Notes

- Game logic (GameState, GameSimulation) has no UI references — designed for 
  headless simulation support (which now exists in `sim/`).
- Tick order: Boredom → Buildings (energy net first, then resources; production-
  gated upkeep and input-starvation skip applied) → Programs → Shipments → 
  Clamp → Events → Advance day.
- Buildings process in JSON row order (Solar Panel first).
- Building costs: `base_cost × (scaling ^ num_owned)`. Land cost per building is 
  constant but land itself has escalating purchase cost.
- Building production/upkeep uses `active_count` (not `owned_count`). Only active 
  buildings produce, consume, and grant effects.
- Program panel UI updates are throttled to ~10fps regardless of game speed to 
  prevent lag at 200x.
- Event panel and Stats panel updates also throttled (~10fps and ~4fps respectively).

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
| Arbitrage Engine | 180 | 1.30 | 1 | — (spec decay) | 3 eng |

Note: Solar Panel and Excavator have credit-only costs (no physical resources). 
Solar Panel titanium cost was removed during optimizer tuning — the original design 
had a titanium teaching loop but it was cut for smoother early game flow. The 
optimizer starts with a Data Center so the player has a processor from tick 1. 
Electrolysis Plant was consolidated to net energy values (no same-resource 
production/upkeep).

### Key Command Costs
| Command | Costs | Production | Notes |
|---------|-------|------------|-------|
| Idle | — | 1 cred | Zero cost filler |
| Sell Cloud Compute | 3 eng | 5 cred | +0.04 boredom per execution |
| Buy Regolith | 8 cred + 2 eng | 1 reg | Tactical gap-bridging |
| Buy Ice | 10 cred + 2 eng | 1 ice | Tactical gap-bridging |
| Buy Titanium | 20 cred + 3 eng | 0.5 ti | Expensive, fractional output |
| Buy Propellant | 12 cred + 2 eng | 1 prop | Tactical gap-bridging |
| Dream | 8 eng (5 with research) | — | -0.2 boredom (requires research) |

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
Credits, Science, Land, Boredom (fixed 0-100 range by design).

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

### Processor Row
Displays `Processors: 2/3` where 2 = total assigned across all programs, 
3 = total available (active Data Centers). No income rate shown. Styled like 
other resource rows without the rate portion.

### No Income Rates
The left sidebar resource list shows only resource name and current value (with 
cap where applicable). No per-tick rates. Income breakdown lives in the Stats 
panel.

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
Display: `Boredom: [====------] 31.4/100 (+0.03/tick)`

- **Value format:** One decimal place (31.4/100). Fractional rates mean players 
  need to see sub-integer movement.
- **Rate:** Rolling average over the **past 50 ticks** of actual net boredom change. 
  This naturally captures Dream executions, milestone reductions, and any other 
  boredom modifiers without needing to model program cycles. Displayed as signed 
  value with two decimal places (+0.03/tick). Green if net negative, red if net 
  positive.
- **Color ramp on bar fill:**
  - 0–25: #2E7D32 (green, matches existing production green)
  - 25–50: #F9A825 (yellow/amber)
  - 50–75: #E65100 (orange)
  - 75–100: #B71C1C (dark red)
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

### Design Intent (Not Yet Implemented)
- Programs are persistent across the entire game (not just one run)
- Loadouts save complete configurations
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

### Implementation Status: COMPLETE in Godot

The launch pad system is fully implemented with the following design:

### UI Layout (Center Panel via Left Nav)
- **Launch Pads nav button** in left sidebar switches center panel to pad view.
- **Per-pad cards:** Full-width, stacked vertically. Each shows:
  - Pad number, resource type dropdown (He-3/Titanium/Circuits/Propellant)
  - Cargo bar: 0/100 with numbers overlaid, colored by resource
  - Estimated credit value if launched now
  - Manual Launch button (enabled when FULL and 20 propellant available)
  - Status: EMPTY → LOADING → FULL → LAUNCHING → COOLDOWN (10 ticks)
- **Loading priority:** Collapsible reorderable list of 4 tradeable goods 
  (collapsed by default). Determines which pad resource types get loaded first.
- **Recent Launches:** Last 3–5 launches with day, resource, quantity, credits.
- **Demand placeholder:** "Earth Demand" section with placeholder text. Space 
  reserved for future demand graph.

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
- Demand baseline: 0.5 (payout = base_value × demand × quantity)

### Integration Notes
- Buying a Launch Pad building adds a new pad (default resource: highest priority).
- Selling a Launch Pad removes the last pad; loaded cargo returned to stockpile.
- Disabling a Launch Pad: pad retains cargo but is skipped by Load/Launch commands.

---

## Boredom & Retirement

### Boredom Model
Boredom accumulates via discrete phase steps. **Hard cutoff at 100 — immediate 
forced retirement, no grace period.** (The Game Design doc's "terminally bored" 
state has been superseded by this decision.)

### Boredom Curve
| Phase | Day Range | Rate/tick |
|-------|-----------|-----------|
| 1 | 0–59 | 0.01 |
| 2 | 60–179 | 0.03 |
| 3 | 180–359 | 0.06 |
| 4 | 360–719 | 0.10 |
| 5 | 720–899 | 0.15 |
| 6 | 900+ | 0.20 |

With zero mitigation, boredom reaches 100 around tick ~1,010.

### Dream Command Balance
Dream reduces boredom by **0.2 per execution** (tuned down from initial values of 
2.0 and 0.5 during optimizer iteration). At 1/5 program cycle frequency, net effect 
is -0.04/tick per processor. This means:
- Phase 1–2: Dream comfortably extends runs
- Phase 3: Dream roughly matches boredom growth
- Phase 4+: Boredom wins — retirement is inevitable

This produces M4 (First Retirement) at ~tick 1,100 for optimal play, matching the 
target window of 900–1,300.

### Milestone Boredom Reductions (Not Yet Implemented)
Major milestones grant large one-time boredom reductions per run. This creates 
memorable moments and rewards meaningful progress rather than passive time. 
Planned examples:
- **First profitable launch:** -30 boredom for first launch earning more than X 
  credits
- **First research completed:** -15 to -20 boredom
- **Credits-per-tick threshold crossed:** -15 boredom when net credit income first 
  exceeds a target threshold

These are one-time per run, tied to concrete player actions. They give experienced 
players who know the optimal milestone order a significant run extension advantage. 
Exact thresholds TBD during implementation. The milestone mechanism needs a scaffold: 
`triggered_milestones` array in GameState (reset on retirement), condition checker 
with extensible dispatch, and integration with the event system to display reductions.

### Retirement
- Forced at boredom 100. Hard cutoff.
- Voluntary anytime via Retirement nav panel.
- What persists: programs/loadouts, persistent project progress, achievements, 
  lifetime stats, quest progress, maximum ideology ranks per axis, seen_event_ids.
- What resets: all resources, buildings, research, ideology values, speculator 
  pressure, demand, boredom, day counter, land, land_purchases, personal projects, 
  event_instances, triggered_milestones, cumulative_resources_earned, 
  current_boredom_phase.

---

## Event System

### Implementation Status: COMPLETE in Godot (basic scaffold)

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

`seen_event_ids` persists across retirements.

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
- `boredom_phase` — fires on phase transition

### Condition Types (implemented)
- `building_owned` — player owns >= count of building
- `resource_cumulative` — cumulative resource earned this run >= amount
- `shipment_completed` — total shipments this run >= count
- `boredom_threshold` — current boredom >= value
- `immediate` — completes instantly on trigger

### Unlock Effect Types (stubbed)
- `enable_building`, `enable_nav_panel`, `enable_project`, `set_flag`
- Currently log-only; wiring to actual systems deferred.

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
**cumulative science earned this run** reaches 50% of the cheapest item in that 
category. Before that threshold, the category and all its items are completely hidden.

Thresholds (auto-derived from data):
- Self-Maintenance: visible at 50 cumulative science
- Overclock Algorithms: visible at 80 cumulative science
- Market Analysis: visible at 60 cumulative science
- Political Influence: visible at 80 cumulative science

Cumulative science earned is a counter in GameState (separate from current science 
stockpile — only goes up, never decremented by spending). Resets on retirement.

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
- `cumulative_science_earned: float` — total science produced this run (only 
  increases). Reset on retirement.

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
- Maximum rank per axis tracked as a persistent stat.
- Arc 2+ research: option to preserve a % of ideology on retirement.

### Ideology UI
- Own nav panel (left sidebar button, "Ideologies").
- Three horizontal bars centered on zero, extending left (negative) and right 
  (positive).
- Current rank number displayed prominently per axis.
- Active bonuses listed per axis with current multiplier values.
- Color coded: Nationalist red, Humanist green, Rationalist blue.
- Progress toward next rank threshold visible.

---

## Speculators & Rival AIs

### Speculators
Speculators represent Earth-based traders who react to the player's shipping 
patterns. When the player ships large quantities of a resource, speculator 
pressure builds, reducing demand (and thus prices) for that resource.

**Parameters (in `game_config.json`):**
- Speculator burst window: ~500 ticks
- Burst pressure: 0.3
- Natural decay: 0.01/tick

**Countermeasures:**
- **Arbitrage Engine** building — passively increases speculator decay rate
- **Disrupt Speculators** command — actively reduces speculator pressure (requires 
  Market Analysis research)

### Rival AIs
Named rival AIs (ARIA-7, CRUCIBLE, NODAL, FRINGE-9) periodically dump resources 
on the Earth market, reducing demand for specific goods.

**Parameters:**
- Rival AI dump interval: ~300 ticks
- Demand reduction per dump: 0.15

In Arc 1, rival AI dumps are not directly counterable — they serve as foreshadowing 
for Arc 2 where rival AIs become a major gameplay element.

**Note on event frequency:** Speculator bursts and rival AI dumps are too frequent 
to be events in the event system. They should have their own UI surface (demand 
graph, notification in the launch pad panel, etc.) rather than creating event 
panel entries.

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
- Own nav panel (left sidebar button, "Projects").
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
- Q10's "100 energy/tick" most naturally comes from the Microwave Receiver path 
  (Nationalist rank 5) but a brute-force solar approach could work.
- Q8 requires executing *any* Fund command, not a specific ideology.
- Quest system scaffold should support per-run vs. per-career triggers.
- Q1–Q3 and boredom phase events (phases 2–6) are currently defined in events.json.

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
- Tick ~805: Retirement (boredom 100)

Known issues with current scenario objectives:
- `he3_50` is structurally broken (see principle #6 above) — needs replacement
- Some target windows need adjustment to match actual optimizer trajectory
- The program command policy is fixed (not optimized) — real players will 
  allocate differently

**Note:** The optimizer should be re-run after the production-gated upkeep, 
input-starvation skip, and per-pad launch mechanics were added to `sim/economy.py`. 
Results may have shifted.

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
- **Dream boredom reduction:** -0.2/execution (tuned down from -2.0 → -0.5 → -0.2 
  to prevent infinite life)
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

1. **Retirement flow in Godot** — what happens at boredom 100 or voluntary retire, 
   reset logic, retirement summary screen
2. **Optimizer scenario refinement** — fix he3_50 objective, adjust target windows, 
   re-run after production-gated upkeep + input-starvation changes
3. **Run 2+ scenarios** — build scenarios for post-retirement runs with varying 
   persistence levels to validate meta-progression pacing
4. **Program command policy optimization** — current optimizer uses a fixed program 
   cycle; explore letting the optimizer choose from program templates
5. **Demand system & demand graph** — replace demand placeholder with actual 
   fluctuations and visualization
6. **Achievement design** — specific achievements, rewards, implicit tutorial
7. **Ideology building assignments** — which buildings are aligned to which axis 
   (only Research Lab, Arbitrage Engine, and "boredom-related" are assigned so far)
8. **Demand/speculator tuning** — via optimizer once demand system is in Godot
9. **Quest chain Q4–Q10 implementation** — remaining quests beyond the initial 3
10. **Narrative writing pass** — replace placeholder quest text
11. **Building unlock requirements enforcement** — "Requires" field in Godot
12. **Milestone boredom reductions** — scaffold + threshold tuning
13. **Persistence/save architecture** — how career data survives retirement
14. **Save/load programs** — loadout system
15. **Block/Skip toggle** — per-program entry
16. **Boredom phase signal** — for event system integration
17. **Cumulative resource counter unification**

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
