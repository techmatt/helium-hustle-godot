# Helium Hustle — Implementation Stage 1: Resource Tick Loop + Buildings

## Goal
Get resources ticking and buildings purchasable. When I run the game, I should see 
resource numbers changing in real time and be able to buy buildings that affect those 
numbers. No programs, no boredom, no shipments yet.

## Reference Files
- `docs/tech_spec.md` — full technical spec. Read the Architecture, Tick System, 
  Resources, and Buildings sections. Ignore Programs, Shipments, Boredom, and 
  Retirement for now.
- `data/game_config.json` — starting resources and starting buildings.
- `data/generated/resources.json` — resource definitions (names, short names, storage caps).
- `data/generated/buildings.json` — building definitions (costs, production, upkeep, 
  effects, scaling).

## What to Build

### 1. GameState
A simple object (Resource or RefCounted class) that holds:
- `resources`: dict of `{short_name: {amount, cap}}`, initialized from game_config + resources.json
- `buildings_owned`: dict of `{short_name: count}`, initialized from game_config
- `current_day`: int, starts at 0

### 2. GameSimulation  
A class with a `tick()` method that processes one game tick:
- **Building production/upkeep**: For each building type, in the order they appear in 
  buildings.json: multiply production and upkeep by count owned. Check if all upkeep 
  can be paid. If yes, deduct upkeep and add production. If no, this building type 
  produces nothing this tick.
- **Storage effects**: Buildings with `store_` effects add to resource caps. Recalculate 
  caps based on current buildings owned (base cap from resources.json + sum of all 
  store_ effects).
- **Clamp**: After all production, clamp every resource to its cap.
- **Advance day**: Increment current_day.

Also needs:
- `can_buy_building(short_name)`: checks if player can afford costs + has land
- `buy_building(short_name)`: deducts costs (using scaled cost formula: 
  base × scaling^num_owned), increments building count, deducts land

### 3. GameManager (autoload singleton)
- Owns one GameState and one GameSimulation
- Runs a timer that calls `tick()` at the current speed (1x = 1 tick/sec)
- Exposes methods for the UI to call: `buy_building(id)`, `get_state()`
- Speed control: the speed buttons (already in UI) should change the tick rate. 
  1x=1/sec, 3x=3/sec, 10x=10/sec, 50x=50/sec, 200x=200/sec. Pause=0.

### 4. Wire Up the Existing UI
- **Resource list** (left sidebar): update every tick to show actual values from 
  GameState. Format: "Energy: 50 / 100  +2.0/s" where the rate is net 
  production minus consumption per tick.
- **Buildings panel** (center): For each building in buildings.json, show a card with: 
  name, count owned, cost of next purchase, production/upkeep summary, and a Buy 
  button. Disable the Buy button if can't afford. Update every tick (costs change 
  as you buy more).
- **Speed buttons**: wire to GameManager to change tick rate. Highlight current speed.
- **System uptime**: show current_day from GameState.

## What NOT to Build Yet
- Programs / processors / commands
- Boredom
- Shipments / launch pad queue
- Retirement
- Events
- Building unlock requirements (show all buildings from the start for now)
- The nav buttons on the left (Commands, Research, etc.) remain non-functional

## Architecture Reminder
Keep game logic (GameState, GameSimulation) in pure GDScript with no UI references.
Keep UI scripts separate — they read from GameState and call GameManager methods.
This separation matters for later when we add headless simulation.
