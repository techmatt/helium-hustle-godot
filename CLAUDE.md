# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Helium Hustle is a browser-style idle game about an AI managing a lunar helium-3 mining operation. The MVP is a single boredom-gated run: build up the economy, run programs on processors, ship He-3 to Earth, and retire before boredom forces you out. The goal is to validate the building/resource/program loop.

## Engine & Configuration

- **Godot version**: 4.6
- **Language**: GDScript (`.gd` files) — the project has a C#/dotnet config (`HeliumHustle.csproj`) but all active game and UI code is GDScript
- **Rendering**: GL Compatibility (D3D12 on Windows)
- **Project root**: `godot/` subdirectory — open `godot/project.godot` in the editor
- **Run**: Godot editor only (F5). No CLI build command.

## Architecture

Logic is strictly separated from UI so headless simulation is possible later.

- **`GameState`** (`scripts/game/game_state.gd`) — plain data object: `amounts`, `caps`, `buildings_owned`, `current_day`. No Godot node references.
- **`GameSimulation`** (`scripts/game/game_simulation.gd`) — pure logic. `tick(state)`, `can_buy_building`, `buy_building`, `get_scaled_costs`, `recalculate_caps`. No UI references.
- **`GameManager`** (`scripts/game/game_manager.gd`) — autoload singleton. Owns `GameState` and `GameSimulation`. Runs the tick `Timer`. Emits `tick_completed` signal. UI calls methods here for player actions.
- **UI scripts** — read `GameManager.state` for rendering, connect to `tick_completed` for updates.

## Tick System

One tick = one in-game day. At 1x speed = 1 tick/second. Tick order:
1. Boredom increment + threshold checks
2. Buildings: upkeep consumed → production applied (if upkeep fails, building skips)
3. Programs: each processor executes one command (blocks on insufficient resources)
4. Shipments: Launch Pad firing logic
5. Clamp all resources to storage caps
6. Increment day counter

Building processing order matches the row order in `buildings.json`.

## Data Pipeline

**The JSON files are ground truth.** Do not treat the xlsx or Google Sheet as authoritative — they are human-readable intermediates for visual inspection and editing only.

```
godot/data/*.json              ← GROUND TRUTH (committed, edited directly or via xlsx round-trip)

Round-trip for visual editing:
  python data/json_to_xlsx.py  → data/Helium Hustle Datasheets.xlsx  (JSON → xlsx, 4 tabs)
  (edit xlsx)
  python data/convert.py       → godot/data/*.json                   (xlsx → JSON)
```

Key data files (all in `godot/data/`):
- `buildings.json` — building definitions: `name`, `short_name`, `category`, `costs`, `production`, `upkeep`, `effects`, `land`, `cost_scaling`
- `resources.json` — resource definitions: `name`, `short_name`, `storage_base`
- `commands.json` — program command definitions
- `game_config.json` — starting resources/buildings, boredom curve, shipment params, land costs, etc.

Building purchase cost formula: `base_cost × (cost_scaling ^ num_owned)`. Land cost is fixed (doesn't scale). All costs must be affordable simultaneously.

**sim/constants.py** mirrors game data for use by the Python optimizer. It is NOT ground truth — if you change the JSON files, update `sim/constants.py` to match.

## Repository Structure

```
godot/
  project.godot
  data/
    game_config.json
    generated/
      buildings.json
      resources.json
  scenes/
    main_ui.tscn          # Main scene (three-column layout)
    ui/
      BuildingCard.tscn   # Building card shell (children built by script)
  scripts/
    game/
      game_state.gd       # class_name GameState
      game_simulation.gd  # class_name GameSimulation
      game_manager.gd     # autoload singleton
    ui/
      main_ui.gd          # Main UI controller
      building_card.gd    # class_name BuildingCard (PanelContainer subclass)
  assets/
    fonts/
      Rajdhani-Bold.ttf
      Exo2-Regular.ttf    # Exo2 variable font
      Exo2-SemiBold.ttf   # same variable font file
```

## UI Structure

Three-column layout: left sidebar (440px fixed) | center panel (flex) | right panel (540px fixed).

- **Left sidebar**: "Helium Hustle" title, 3×3 nav grid (mode-switch buttons), collapsible speed controls, collapsible resource list
- **Center panel**: mode-dependent content. Default: Buildings view with collapsible category sections (Mining, Power, Storage, Processors) containing `BuildingCard` instances in an `HFlowContainer`
- **Right panel**: Program slots (1–5), program editor area, Events section
- **Status bar**: system uptime

`window/stretch/mode="disabled"` in `project.godot` is required for fixed-pixel panel widths. Do not change it to `canvas_items`.

## Typography

- **Headers/titles**: Rajdhani Bold — `_font_rajdhani_bold`
- **Body/data/labels**: Exo 2 Regular — `_font_exo2_regular`
- **Values/counts/buttons**: Exo 2 SemiBold — `_font_exo2_semibold`
- Color conventions: positive rates/production = `#7FBF7F`, negative/upkeep = `#BF7F7F`, zero = `#808080`

Fonts are applied per-node via `add_theme_font_override` / `add_theme_font_size_override`. A global `Theme` on the root Control sets Exo2-Regular as the default.

## BuildingCard

`BuildingCard` is a `PanelContainer` subclass. Call `setup(bdef, font_rb, font_e2r, font_e2s)` after instantiating (builds child nodes). Call `refresh()` each tick to update count, affordability background color (green/red tint), scaled costs, and per-resource cost coloring.

## MVP Scope

Implemented: resource tick loop, building purchase with cost scaling, speed controls, building card grid UI.

Not yet implemented (per tech_spec.md): Programs/processor execution, shipments (Launch Pad firing), boredom system, retirement screen, event system.

## Notes

- `project.godot` `config/name` and dotnet assembly are both "Helium Hustle" / "HeliumHustle"
- The `.godot/` directory is editor cache — not committed
- GDScript strict typing is enforced: variables inferred from autoload properties must have explicit type annotations (e.g., `var st: GameState = GameManager.state`)
- `HFlowContainer` is used for the building card grid — cards wrap to fill available center panel width
