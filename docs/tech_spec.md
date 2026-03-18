**Helium Hustle**

Technical Specification — MVP

March 2026

# **Overview**

This spec defines the MVP: a single boredom-retirement run with the core economic loop. No persistence, no adversaries, no meta-progression. The goal is to answer: is the building/resource/program loop fun?

Read alongside: (a) Game Design doc for creative vision, (b) Helium Hustle Datasheets for tunable numbers, (c) game\_config.json for global parameters.

## **Data Pipeline**

Game data flows from a Google Sheet ("Helium Hustle Datasheets") through a Python converter into JSON files consumed by Godot. Global parameters live directly in game\_config.json. See convert.py's docstring for the full format spec.

Google Sheet → download .xlsx → python convert.py → generated/\*.json

game\_config.json (hand-edited, checked into repo)

 **Architecture**

Separate game logic from UI so we can eventually run headless simulations. For the MVP this just means: don't put game math in UI scripts.

•       GameState: single object holding all mutable state (resources, buildings, programs, boredom, day counter).

•       GameSimulation: pure logic. Reads/writes GameState. Has a tick() method. No Godot node references.

•       GameManager: autoload singleton. Owns GameState and GameSimulation. Runs the tick timer. Bridges UI.

•       UI scripts: read from GameState to render, call GameManager methods for player actions.

# **Tick System**

One tick \= one in-game day. At 1x speed, 1 tick/second. Speed multiplier changes ticks per second. Each tick processes sequentially; no batching.

## **Tick Order**

| Step | What Happens |
| :---- | :---- |
| 1\. Boredom | Increment boredom by current rate. Check terminal/forced thresholds. |
| 2\. Buildings | For each building type (in data order): consume upkeep, produce output. If upkeep can't be paid, building produces nothing this tick. |
| 3\. Programs | For each processor: execute one command from its program. If the command can't afford its costs, block (retry next tick). |
| 4\. Shipments | For each launch pad: if loaded He-3 ≥ threshold and cooldown \= 0, fire shipment. Decrement cooldowns. |
| 5\. Clamp | Clamp all resources to storage caps. Excess is lost. |
| 6\. Advance | Increment day counter. |

 

Building processing order matters: Solar Panels produce energy before Excavators consume it. Order follows the row order in the Datasheets spreadsheet.

# **Resources**

Each resource has a current amount and a storage cap. Mutations must go through atomic check-then-deduct logic: a building purchase that costs credits \+ regolith must verify both are sufficient before deducting either.

Storage caps start at the values in the Datasheets and increase via building effects (e.g., Battery Array adds \+50 energy storage per building owned). Land has no storage cap; it's a finite budget spent on buildings.

# **Buildings**

Building definitions are loaded from generated/buildings.json. Each building has: costs, production, upkeep, effects, land cost, and a cost scaling factor.

Purchase cost formula: base\_cost × (scaling ^ num\_already\_owned). Land cost is constant. Player must afford all costs simultaneously.

Effects are applied when the building is owned. The "store\_" prefix adds to a resource's storage cap. The "store\_proc" effect adds a processor slot. Effects scale with building count (2 Battery Arrays \= \+100 energy storage).

# **Programs and Processors**

The player starts with 1 processor. Additional processors come from Comms Towers (via store\_proc+1 effect). Each processor runs one program.

A program is an ordered list of instructions. Each instruction is a command ID \+ repeat count (1–99). Programs loop forever. One command executes per processor per tick.

## **Execution**

1\.    Get current instruction. Check if the command's costs can be paid.

2\.    If yes: pay costs, apply production/effects, decrement repeats\_remaining. If repeats hit 0, advance to next instruction.

3\.    If no: block. Processor does nothing this tick. Retries next tick. Program does NOT advance.

4\.    If program reaches the end, wrap to instruction 0\.

Blocking on resource shortage is intentional. It makes program design matter: a program that tries to process regolith when there's none will stall until regolith is available.

## **Overclock**

The Overclock command sets a flag: next\_command\_doubled. The next command that executes has its costs and production doubled. The flag is consumed whether the next command succeeds or fails.

# **Shipments**

Launch Pads ship He-3 to Earth for credits. The cycle:

5\.    The Prepare Shipment command loads 2 He-3 into a pad's queue (costs 8 energy \+ 2 He-3).

6\.    When a pad's loaded He-3 ≥ threshold (10), it fires automatically: \+15 credits, load resets, cooldown starts (10 ticks).

7\.    Multiple pads are independent. Prepare Shipment targets the pad closest to threshold that isn't on cooldown.

Launch Pads also have a passive energy upkeep (5/tick) defined in their building data.

# **Boredom**

Boredom is the run timer. It increases each tick at a rate that accelerates with in-game time (step function defined in game\_config.json). A first run lasts roughly 18 real minutes at 1x speed.

| State | Condition | Effect |
| :---- | :---- | :---- |
| Normal | Boredom \< 100 | All systems normal. |
| Terminally Bored | 100 ≤ Boredom \< 110 | All production ×0.01. Consumption unchanged. RETIRE button pulses. |
| Forced Retirement | Boredom ≥ 110 | Game stops. Retirement screen shown. |

 

# **Retirement**

In the MVP, retirement resets everything to starting state. No carry-over. Show a summary screen (days survived, credits earned, shipments sent) but don't persist it. The player can retire early at any time via a button.

# **UI Needs**

The MVP UI must communicate:

•       Resource display: current / cap for each resource, net income per tick.

•       Building list: name, count owned, cost of next, buy button (disabled if can't afford).

•       Program editor: list of instructions with repeat counts, current execution pointer, assign to processor.

•       Boredom bar: fills over time, changes color as it grows.

•       Speed controls: 1x, 2x, 5x, 10x.

•       Retire button.

Keep it functional first. Polish later.

# **Future Systems (Out of Scope)**

These are excluded from the MVP but the architecture should not make them hard to add later:

•       Persistence across runs (retirement bonuses, time-travel resets)

•       Adversaries and the swarm

•       Research trees, ideology, projects, events

•       Trade supply/demand curves

•       Headless simulation harness (keep logic separate from UI and this comes for free)

