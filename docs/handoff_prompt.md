# Helium Hustle — Development Context Handoff

## Instructions for Claude

Read this entire document carefully, then respond: "Ready. I've read the Helium 
Hustle handoff." Do not summarize or ask questions until prompted.

Also read the "Helium Hustle Game Design" document in the user's Google Drive 
for the full creative vision. This handoff document is the authoritative source 
for decisions already made; the Game Design doc provides broader context.

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
    game_config.json       ← GROUND TRUTH for starting state, boredom, shipment, etc.
  scenes/
    main_ui.tscn           ← Main scene (three-column layout)
    ui/BuildingCard.tscn
    ui/CommandRow.tscn     ← Program command row (reusable)
    ui/LaunchPadCard.tscn  ← Launch pad widget (full-width)
  scripts/
    game/
      game_state.gd        ← class_name GameState — pure data, no UI
      game_simulation.gd   ← class_name GameSimulation — pure logic, no UI
      game_manager.gd      ← autoload singleton, owns state + sim
    ui/
      main_ui.gd           ← Main UI controller
      building_card.gd     ← BuildingCard (PanelContainer subclass)
      command_row.gd       ← CommandRow for program list
      launch_pad_card.gd   ← LaunchPadCard widget
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
   resource list), center panel (buildings/commands/launch pads), right panel 
   (programs, events placeholder). Bottom status bar with system uptime.

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

5. **Program/processor system** — fully implemented (see Programs & Processors 
   section for design details):
   - 5 program tabs in right panel with processor assignment (+/−/Reset)
   - Command queue per program: reorderable rows with repeat count, progress 
     bars, −/+/× controls
   - Commands view in center panel (via left nav) with Add buttons per command
   - Command cards grouped by category (Basic, Trade, Operations, Advanced)
   - Locked commands visible but Add disabled, showing research requirement
   - Execution: top-to-bottom, failed rows turn red, resets on wrap
   - Program panel UI throttled to ~10fps at high game speeds
   - Resource rate display in left sidebar shows net rates from buildings + programs

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

9. **Net income display** — resource rates show actual net per tick from 
   buildings and programs, with green/red coloring.

### In the Python Optimizer (`sim/`)

1. **Scenario-based architecture** — optimizer loads scenario JSON files that 
   define starting conditions, available actions, objectives with target windows, 
   and end conditions. See `docs/optimizer_design.md` for full spec.
2. **Tick-accurate economy model** (`economy.py`) — pure state machine matching 
   the Godot tick order. Buildings, programs (fixed policy), shipments, boredom, 
   storage caps all modeled. Includes production-gated upkeep and per-pad launch 
   mechanics with cooldown.
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

1. **Boredom system in Godot** — phase-based accumulation, display, hard cutoff 
   at 100 (see Boredom & Retirement section)
2. **Retirement** — forced at boredom 100, voluntary anytime, reset logic (see 
   Boredom & Retirement section)
3. **Research system** — clusters, science spending, command unlocks (see Research 
   section)
4. **Building unlock requirements** — "Requires" field exists in data but isn't 
   enforced in Godot
5. **Demand system** — price fluctuations, speculator pressure (see Shipment & 
   Trade Economy section)
6. **Quest chain / event system** — Q1–Q10 implicit tutorial (see Quest Chain 
   section)
7. **Speculators & rival AIs** — see Speculators & Rival AIs section
8. **Ideology** — see Ideology section
9. **Projects** — see Projects section
10. **Land purchasing** — land is a scaling resource. Needs a home in the 
    Buildings panel (Buy Land button with escalating cost)
11. **Auto-pause on events** — see Event System section
12. **Milestone boredom reductions** — see Future Design Ideas section
13. **Save/load programs** — loadout system for saving/loading program configs
14. **Block/Skip toggle** — per-program entry option
15. **Cross-retirement program persistence**

---

## Architecture Notes

- Game logic (GameState, GameSimulation) has no UI references — designed for 
  headless simulation support (which now exists in `sim/`).
- Tick order: Boredom → Buildings (energy net first, then resources; production-
  gated upkeep applied) → Programs → Shipments → Clamp → Events → Advance day.
- Buildings process in JSON row order (Solar Panel first).
- Building costs: `base_cost × (scaling ^ num_owned)`. Land cost per building is 
  constant but land itself has escalating purchase cost.
- Building production/upkeep uses `active_count` (not `owned_count`). Only active 
  buildings produce, consume, and grant effects.
- Program panel UI updates are throttled to ~10fps regardless of game speed to 
  prevent lag at 200x.

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
| Electrolysis | 50 | 1.25 | 1 | 2 prop + 1 eng | 2 ice, 2 eng |
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

### Key Command Costs
| Command | Costs | Production | Notes |
|---------|-------|------------|-------|
| Idle | — | 1 cred | Zero cost filler |
| Sell Cloud Compute | 3 eng | 5 cred | +0.04 boredom per execution |
| Buy Regolith | 8 cred + 2 eng | 1 reg | Tactical gap-bridging |
| Buy Ice | 10 cred + 2 eng | 1 ice | Tactical gap-bridging |
| Buy Titanium | 20 cred + 3 eng | 0.5 ti | Expensive, fractional output |
| Buy Propellant | 12 cred + 2 eng | 1 prop | Tactical gap-bridging |
| Dream | 8 eng | — | -0.2 boredom (requires research) |

Buy commands are intentionally expensive — 3-5x the cost of building-based 
production per unit. They exist for tactical gap-bridging (need 2 titanium for 
a specific build) not as a primary resource strategy.

### Land System
- Base cost: 15 credits, scaling: 1.5x per purchase
- 10 land per purchase
- Starting land: 40

---

## Resource Flow — Arc 1 Economy

### Raw Extraction (both consume energy)
- **Regolith Excavator** — energy → regolith
- **Ice Extractor** — energy → ice

### Processing Buildings (each has one clear purpose)
- **Refinery** — regolith + energy → He-3
- **Smelter** — regolith + energy → titanium
- **Fabricator** — regolith + energy (lots) → circuit boards
- **Electrolysis Plant** — ice + energy → propellant + energy (net energy positive)

### Resource Dependency Structure
Two independent extraction chains (regolith and ice) feed into four processing 
paths, all competing for energy:
- **Regolith** feeds three competing uses: He-3, titanium, circuit boards
- **Ice** feeds propellant/energy via electrolysis
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
  Spent on research upgrades and ideology.
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
Caps are **always shown** in the resource list: `47/100`. At cap, visually 
signal waste (color change, flash, or similar).

### Production-Gated Upkeep
Buildings with production outputs automatically skip upkeep on ticks where ALL 
their produced resources are at storage cap. If even one produced resource has 
room, the building pays full upkeep and produces normally (any at-cap production 
is wasted). Buildings with no production (Battery, Storage Depot, Launch Pad, 
Data Center) always pay upkeep since their value is passive. This is automatic 
and separate from the player's manual enable/disable controls.

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

## Programs & Processors

### Implementation Status: COMPLETE in Godot

The program system is fully implemented in Godot with the following design:

### UI Layout (Right Panel)
- **Tab bar:** 5 numbered program tabs across top. Active tab highlighted green. 
  Tabs with commands show a dot indicator.
- **Processor row:** "N assigned (M free)" with −/+/Reset buttons. Total 
  processors = number of active Data Centers.
- **Command list:** Scrollable list of command rows. Each row shows command name 
  + repeat count (e.g. "Sell Cloud Compute (x3)"), progress bar, and −/+/× 
  buttons.
- **Events placeholder:** Below command list, minimal "Events — Coming soon".

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
Full Pads). The remaining 11 require research cluster unlocks (Dream, Overclock 
Mining/Factories, Promote ×4, Disrupt Speculators, Fund ×3). Buy Power (Nationalist 
rank 5) is deferred — requires Microwave Receiver persistent project unlock.

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
- **Load Launch Pads command:** Costs 2 energy. Loads 5 units from player's 
  stockpile into the first not-full active pad of the highest-priority resource.
- **Launch Full Pads command:** Launches ALL full active pads. Each launch costs 
  20 propellant (separate from cargo). Payout = base_value × demand × cargo_loaded.
- **Cooldown:** 10 ticks after launch before pad is available again.
- **Manual launch:** Button on each pad card, in addition to program command.

### Key Parameters (in `game_config.json`)
- Pad cargo capacity: 100 units
- Fuel per pad launch: 20 propellant
- Load per command execution: 5 units per enabled pad
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

### Milestone Boredom Reductions (Design Idea — Not Yet Implemented)
Major milestones should grant large one-time boredom reductions per run. This 
creates memorable moments and rewards meaningful progress rather than passive 
time. Planned examples:
- **First profitable launch:** -30 boredom for first launch earning more than X 
  credits
- **First research cluster unlocked:** -15 to -20 boredom
- **Credits-per-tick threshold crossed:** -15 boredom when net credit income first 
  exceeds a target threshold

These are one-time per run, tied to concrete player actions, and reward engaging 
with different systems. They give experienced players who know the optimal 
milestone order a significant run extension advantage. Exact thresholds TBD 
during implementation.

### Retirement
- Forced at boredom 100. Hard cutoff.
- Voluntary anytime via Retirement nav panel.
- What persists: programs/loadouts, persistent project progress, achievements, 
  lifetime stats, quest progress.
- What resets: all resources, buildings, research, ideology, speculator pressure, 
  demand, boredom, day counter, land.

---

## Research

(Unchanged from prior handoff. Four clusters totaling 4,250 science.)

### Clusters
1. **Self-Maintenance Protocols** (100 sci unlock) — Dream command + boredom upgrades
2. **Overclock Algorithms** (150 sci unlock) — Overclock Mining/Factories + duration/cost upgrades
3. **Market Analysis** (200 sci unlock) — Promote ×4 + Disrupt Speculators + market upgrades
4. **Political Influence** (250 sci unlock) — Fund ×3 + ideology upgrades

Research visibility gated at 50% of cost. Session-local (resets on retirement) 
except Rationalist rank 5 project provides 25% re-purchase discount.

---

## Ideology

### Updated Rank Thresholds (scaled to +1/execution)
| Rank | Cumulative Value |
|------|-----------------|
| 1 | 70 |
| 2 | 175 |
| 3 | 333 |
| 4 | 570 |
| 5 | 925 |

Fund commands push +1 to target axis, -0.5 to each other axis.

(All other ideology design unchanged from prior handoff — three axes, continuous 
per-rank bonuses, rank 5 persistent project unlocks.)

---

## Speculators & Rival AIs

(Design unchanged from prior handoff. Parameters now in `game_config.json`.)
- Speculator burst window: ~500 ticks, burst pressure: 0.3, natural decay: 0.01
- Rival AI dump interval: ~300 ticks, demand reduction: 0.15

---

## Projects

(Unchanged from prior handoff — personal projects reset on retirement, persistent 
projects accumulate across retirements, all use drain-over-time cost model.)

---

## Arc 1 Quest Chain: "Breadcrumbs"

(Unchanged from prior handoff — 10 quests, Q1–Q10, linear in Arc 1.)

---

## Arc 1 Milestone Graph: The Boredom Loop

(Design milestones M1–M14 unchanged from prior handoff. These are design vocabulary 
for reasoning about player progression — they are NOT optimizer targets. See the 
Economic Balancing section below for how they relate to the optimizer.)

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
   pipeline online. Simple, unambiguous.
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

**Note:** The optimizer should be re-run after the production-gated upkeep and 
per-pad launch mechanics were added to `sim/economy.py`. Results may have shifted.

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

Established during this session. Apply consistently:

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
```

Button states: inactive = light bg + subtle border + dark text; active/selected = 
green accent + white text; disabled = gray bg + gray text; hover = slightly darker 
than inactive. Small +/−/× buttons use a clean system font for legibility at 
small sizes.

---

## Areas Needing Further Design Work

1. **Boredom system in Godot** — phase-based accumulation, display, hard cutoff 
   at 100, milestone boredom reductions
2. **Retirement flow in Godot** — what happens at boredom 100 or voluntary retire, 
   reset logic, retirement summary screen
3. **Research system** — clusters, visibility gating, session-local with Rationalist 
   discount path, UI for research panel
4. **Optimizer scenario refinement** — fix he3_50 objective, adjust target windows, 
   re-run after production-gated upkeep changes
5. **Run 2+ scenarios** — build scenarios for post-retirement runs with varying 
   persistence levels to validate meta-progression pacing
6. **Program command policy optimization** — current optimizer uses a fixed program 
   cycle; explore letting the optimizer choose from program templates
7. **Demand system & demand graph** — replace demand placeholder with actual 
   fluctuations and visualization
8. **Achievement design** — specific achievements, rewards, implicit tutorial
9. **Ideology building assignments** — which buildings are aligned to which axis
10. **Demand/speculator tuning** — via optimizer once demand system is in Godot
11. **Quest chain implementation** — Q1–Q10, modal/non-modal event system
12. **Narrative writing pass** — replace placeholder quest text
13. **Building unlock requirements** — enforce "Requires" field in Godot
14. **Land purchasing UI** — Buy Land button with escalating cost in Buildings panel
15. **Save/load programs** — loadout system
16. **Block/Skip toggle** — per-program entry

---

## Future Design Ideas

### Milestone Boredom Reductions
See Boredom & Retirement section. One-time per-run boredom drops for hitting 
meaningful milestones. Rewards engagement over passive accumulation.

### Retirement Forecast Display
Show "at current rates, retirement in ~N days" in the UI. Makes boredom an 
active planning constraint rather than a background threat. Dream unlocks and 
milestone reductions become tangibly visible as the forecast jumps.

### Resource Waste Indicator
Subtle visual signal (color change, pulse) on resources that have been at cap 
for several ticks. Teaches players they need more storage or faster shipping 
without a tutorial popup.

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

---

## Future Design Notes

(Unchanged from prior handoff.)

### Arc 2 Research Evolution
Research evolves into a talent-tree with reallocatable points. Arc 1 flat-purchase 
clusters are the foundation.

### Consciousness Declaration Mechanic
Optional per-run toggle with immediate gameplay tradeoffs. Separate from the 
AI Consciousness Act persistent project.

### Timeline Reset and Foregone Tech
Deliberately not completing persistent projects creates alternative paths in 
future timelines.

### Opposition Modeling
Reducing cross-axis ideology penalty is an Arc 2 mechanism, not a mid-run buy.

### Magic Research 2 Storage Investigation
Review MR2's cap/overflow/upgrade UI for inspiration.
