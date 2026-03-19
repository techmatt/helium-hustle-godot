# Helium Hustle — Development Context Handoff

## What This Is
Helium Hustle is an idle game built in Godot 4.x (GDScript). You play as an AI 
managing helium-3 mining on the Moon. The game has a long-term arc involving rival 
AIs, a hegemonizing swarm, and time travel prestiges, but right now we're building 
the MVP: a single boredom-retirement run with the core economic loop.

## Key Documents (in Google Drive, "Helium Hustle" folder)
- **Helium Hustle Game Design** — full creative vision, game stages, all planned systems
- **Helium Hustle Technical Spec** — MVP-scoped architecture: tick system, resources, 
  buildings, programs, shipments, boredom. Lean and focused on what to build now.
- **Helium Hustle Datasheets** — Google Sheet with three tabs (Resources, Buildings, 
  Commands) using a compact cell encoding format

## Key Files in the Repo
```
data/
  Helium Hustle Datasheets.xlsx   ← downloaded from Google Sheets
  convert.py                      ← converts xlsx → JSON, see docstring for full format spec
  game_config.json                ← starting resources/buildings, boredom curve, shipment params
  generated/
    resources.json
    buildings.json  
    commands.json
docs/
  tech_spec.md                    ← MVP technical spec (may or may not be checked in yet)
  stage1_prompt.md                ← prompt used for first implementation stage
  ui_skeleton_prompt.md           ← prompt used for initial UI layout
  ui_styling_prompt.md            ← prompt used for font/styling pass
```

## Data Pipeline
Game data lives in a Google Sheet, gets downloaded as .xlsx, then converted:
```
Google Sheet → download .xlsx → python data/convert.py → data/generated/*.json
```
Global params (starting resources, boredom curve, shipment config) live in 
`data/game_config.json`, edited by hand.

### Cell Encoding Format (in the spreadsheet)
- `shortname=amount` → cost (operator `=`)
- `shortname+amount` → production per tick (operator `+`)
- `shortname-amount` → upkeep per tick (operator `-`)
- `prefix_shortname+value` → effect (e.g., `store_eng+50`, `load_he3+2`)
- `x` → null/empty
- Operators are confirmatory (parser validates operator matches column type)

## What's Been Implemented (as of this handoff)
1. **UI skeleton** — three-column layout: left sidebar (nav buttons, speed controls, 
   resource list), center panel (buildings), right panel (programs placeholder, events 
   placeholder). Bottom status bar with system uptime.
2. **Resource tick loop** — GameState, GameSimulation with tick(), GameManager autoload 
   singleton. Resources tick in real time. Buildings produce and consume resources.
3. **Building system** — buildings loaded from JSON, purchasable with scaling costs, 
   production/upkeep/effects working. Building cards in center panel with Buy button.
4. **Speed controls** — pause through 200x working.
5. **UI styling** — Rajdhani (headers) + Exo 2 (body) fonts. Green/red color-coded 
   production/upkeep numbers.

## What's NOT Implemented Yet (in rough priority order)
1. **Programs / processors** — the core differentiating mechanic. Command execution, 
   program editor UI, processor assignment. Commands defined in commands.json.
2. **Boredom** — accelerating curve (in game_config.json), terminally bored state 
   (production ×0.01), forced retirement at 110.
3. **Retirement** — reset to starting state, summary screen.
4. **Shipments** — launch pad queue, Prepare Shipment command, burst credit payouts.
5. **Building unlock requirements** — "Requires" field exists in data but isn't enforced.
6. **Net income display** — resource rates show 0/s, should show actual net per tick.

## Architecture Notes
- Game logic (GameState, GameSimulation) has no UI references — designed for future 
  headless simulation support.
- Tick order: Boredom → Buildings → Programs → Shipments → Clamp → Advance day.
- Buildings process in spreadsheet row order (Solar Panel first → Comms Tower last). 
  This matters because solar panels produce energy before excavators consume it.
- Building costs: `base_cost × (scaling ^ num_owned)`. Land cost is constant.

## Design Philosophy
- The program/processor system is the game's core identity. It's both the automation 
  mechanic and the primary skill expression for experienced players.
- Boredom is a speed governor, not a punishment. It prevents fast-forwarding through 
  learning. Terminally bored = production ×0.01, not a hard cutoff.
- The game should be interesting at max speed. Players design scripts, then accelerate.
- Keep the first milestone simple: is the building/resource/program loop fun?
