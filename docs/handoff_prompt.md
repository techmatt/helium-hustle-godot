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
is building the core economic loop and validating the game's milestone-based 
progression design.

## Key Documents (in Google Drive, "Helium Hustle" folder)
- **Helium Hustle Game Design** — full creative vision, game stages, all planned systems
- **Helium Hustle Technical Spec** — MVP-scoped architecture (OUT OF DATE — will be 
  updated after first pass over all mechanics)
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
  tech_spec.md                    ← MVP technical spec (OUT OF DATE)
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

### Implementation Note
All resources are **float internally**, displayed as integers or one decimal place 
depending on context. This avoids rounding edge cases with fractional production 
rates, Overclock multipliers, demand floats, etc.

---

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
1. **Programs / processors** — core differentiating mechanic. See Programs section below.
2. **Launch pad system** — see Shipment & Trade Economy section below.
3. **Boredom** — see Boredom & Retirement section below.
4. **Retirement** — see Boredom & Retirement section below.
5. **Demand system** — see Shipment & Trade Economy section below.
6. **Speculators** — see Speculators & Rival AIs section below.
7. **Ideology** — see Ideology section below.
8. **Research** — see Research section below.
9. **Projects** — see Projects section below.
10. **Building unlock requirements** — "Requires" field exists in data but isn't enforced.
11. **Net income display** — resource rates show 0/s, should show actual net per tick.
12. **Land purchasing** — land is a scaling, increasingly expensive resource. Needs a 
    home in the Buildings panel (Buy Land button with escalating cost). Buildings consume land.

## Architecture Notes
- Game logic (GameState, GameSimulation) has no UI references — designed for future 
  headless simulation support.
- Tick order: Boredom → Buildings → Programs → Shipments → Clamp → Advance day.
- Buildings process in spreadsheet row order (Solar Panel first → Comms Tower last). 
  This matters because solar panels produce energy before excavators consume it.
- Building costs: `base_cost × (scaling ^ num_owned)`. Land cost is constant per 
  building but land itself has escalating purchase cost.

## Design Philosophy
- The program/processor system is the game's core identity. It's both the automation 
  mechanic and the primary skill expression for experienced players.
- Boredom is a speed governor, not a punishment. It prevents fast-forwarding through 
  learning.
- The game should be interesting at max speed. Players design scripts, then accelerate.
- Keep the first milestone simple: is the building/resource/program loop fun?
- Buildings = infrastructure decisions (what you build, capital allocation).
- Programs = operational decisions (logistics timing, market manipulation, burst production).

---

## Design Language for Game Progression

We use a milestone/gate framework as an intermediate design language — above 
individual building/cost tuning but below vague creative vision. This lets us 
reason about player trajectories, strategy branches, and pacing without 
specifying exact numbers.

### Vocabulary

**Milestone** — a named, meaningful state transition. Something the player would 
recognize as progress. Persists across prestiges or enables something that does.

**Gate** — what must be true before a milestone is reachable. Expressed as thresholds 
on resources, buildings, other milestones, or prestige-level unlocks. Not a specific 
path, just the minimum conditions.

**Tempo** — roughly how long a milestone takes to reach (in game-days or lifetimes), 
assuming the player is focused on it and playing competently. This is our pacing check.

The design artifact is a directed graph: milestones as nodes, gates as edges, tempo 
as edge weights. We validate by checking that the economic sim can actually satisfy 
the gates in roughly the expected tempo, and that at any point in the meta-progression 
there are 2-3 milestones that are plausibly reachable next.

### Design Methodology
- Optimize for the experienced player's trajectory first, then pad for accessibility.
- Each lifetime is ideally a "mission" toward one major milestone for optimal play, 
  but players can approach it however they want.
- Aim for 2-3 real strategy branches available at any point.
- Don't specify run goals or approaches — just milestones and gates. The player 
  figures out the "how."
- Validate constants by checking milestones are achievable, then scale to ensure 
  that with prestige advancement and suboptimal play, it's still accessible.

---

## Resource Flow — Arc 1 Economy

### Raw Extraction (both consume energy)
- **Regolith Excavator** — energy → regolith
- **Ice Extractor** — energy → ice

### Processing Buildings (each has one clear purpose)
- **Refinery** — regolith + energy → He-3
- **Smelter** — regolith + energy → titanium
- **Fabricator** — regolith + energy (lots) → circuit boards
- **Electrolysis Plant** — ice + energy → propellant + energy (net energy contribution)

### Design Principle
One building, one clear purpose. Easier to understand, balance, and display. 
Buildings are factorized to minimize complexity per card.

### Resource Dependency Structure
Two independent extraction chains (regolith and ice) feed into four processing paths, 
all competing for energy:
- **Regolith** feeds three competing uses: He-3, titanium, circuit boards
- **Ice** feeds propellant/energy via electrolysis
- **Energy** is the universal bottleneck — every building needs it, and electrolysis 
  is the only processing building that gives some back

A player who invests in regolith extraction has more selling options but needs to 
solve energy separately. An ice-heavy player has energy and propellant covered but 
fewer tradeable goods.

### Tradeable Goods (4 types)
| Resource | Source Chain | Character |
|----------|-------------|-----------|
| He-3 | Regolith → Refinery | Core product, high value, demand-sensitive |
| Titanium | Regolith → Smelter | Mid-tier, demand spikes when Earth builds ships |
| Circuit Boards | Regolith → Fabricator | Late Arc 1, very energy-hungry, highest value/unit |
| Propellant | Ice → Electrolysis | Also used as launch fuel (dual purpose) |

### Additional Arc 1 Resources
- **Science** — produced by Research Lab (requires circuits to build, consumes energy + 
  circuits as upkeep). Spent on Overclock commands, research upgrades, and ideology.
- **Land** — purchasable in the Buildings panel with escalating cost. Consumed by 
  buildings. Shared bottleneck across all construction.
- **Credits** — earned via trade (shipments) and Sell Cloud Compute. Spent on commands, 
  buildings, research, projects, and ideology.

---

## Programs & Processors

### Overview
The program/processor system is the game's core identity. Players write programs 
(ordered lists of commands) and allocate processors to execute them. Programs handle 
operational decisions: logistics, market manipulation, burst production, boredom 
management, and ideology influence. Buildings handle passive production; programs 
handle active intervention.

### Processors
- **Data Center** building grants processors. Scaling cost is fast — getting many 
  processors is expensive early on.
- 5 program slots at all times. Processors are allocated across them.
- Example allocations with 10 processors: (10,0,0,0,0), (2,2,2,2,2), (1,0,0,0,0) 
  to conserve power.

### Program Structure
- A program is an ordered list of commands with optional xN multipliers.
- Example: `(Mine Regolith x3, Idle x2)` is equivalent to `(Mine, Mine, Mine, Idle, Idle)`.
- No control flow. Execute top to bottom, then loop.
- Each tick, each processor assigned to a program executes the current command, 
  then the instruction pointer advances.
- **Per-program toggle: Block vs Skip** — "Block on insufficient resources" (pause 
  pointer) vs "Skip on insufficient resources" (advance past unaffordable commands). 
  Default: Skip.
- Most commands cost a small amount of energy to execute.

### Program Persistence & Loadouts
- Programs are **persistent across the entire game**, not just one run. The player 
  builds up a library of programs over their career.
- **Loadouts** save a complete configuration: which 5 programs are active + processor 
  allocation. Named, saveable, loadable. ("Early Game", "Credit Rush", "Overclock Heavy")
- On retirement, programs and loadouts survive. On new run, the player loads a loadout 
  but adapts to current processor count and available commands.
- Inspired by Magic Research 2's strategy save/load system.

### Arc 1 Command Set (19 commands)

**Always available (no research needed):**

| Command | Effect | Cost |
|---------|--------|------|
| Buy Regolith | Gain regolith | Credits |
| Buy Ice | Gain ice | Credits |
| Buy Propellant | Gain propellant | Credits |
| Load Launch Pads | Fill enabled pads incrementally | Energy |
| Launch Full Pads | Launch all pads at cargo 100, lowest index first | Propellant (fuel) |
| Sell Cloud Compute | Gain credits, gain boredom | Energy |
| Idle | Nothing | None |

**Requires research (cheap, early-game, groupings TBD):**

| Command | Effect | Cost |
|---------|--------|------|
| Dream | Reduce boredom | Energy (lots) |
| Overclock Mining | +5% extractor output for 5 days | Science + energy |
| Overclock Factories | +5% processing output for 5 days | Science + energy |
| Promote He-3 | Nudge He-3 demand up | Energy + credits |
| Promote Titanium | Nudge titanium demand up | Energy + credits |
| Promote Circuits | Nudge circuit board demand up | Energy + credits |
| Promote Propellant | Nudge propellant demand up | Energy + credits |
| Counter Speculators | Reduce speculator pressure globally | Energy |
| Fund Nationalists | +ideology, -0.5x to other two axes | Energy + credits |
| Fund Humanists | +ideology, -0.5x to other two axes | Energy + credits |
| Fund Rationalists | +ideology, -0.5x to other two axes | Energy + credits |

**Requires special unlock:**

| Command | Effect | Cost | Unlock |
|---------|--------|------|--------|
| Buy Power | Gain energy (requires Microwave Receiver) | Credits | Nationalist rank 5 project |

### Command Design Notes
- **Buy X commands** complement buildings rather than replacing them. Buildings provide 
  passive production; Buy commands let credit-flush players accelerate bottlenecks but 
  are inefficient compared to building infrastructure.
- **Overclock** stacks multiplicatively across executions. Duration is 5 game-days, 
  decays naturally. Player must keep feeding it. Late-game pattern: dedicate processors 
  to tight Overclock loops, burning science to maintain high multipliers.
- **Sell Cloud Compute** is key early-game income (before shipment pipeline is running) 
  but becomes a trap as trade scales up due to boredom cost.
- **Dream** is the primary active boredom mitigation. Competes for energy and processor time.
- Cloud Compute + Dream form a natural first program that teaches the system.

---

## Shipment & Trade Economy

### Launch Pads
- Purchased as buildings. Require land. Scaling cost. Start with 0.
- Per-pad state: resource assignment (dropdown: He-3 / Titanium / Circuits / Propellant), 
  loading toggle (on/off), cargo level (float, 0–100).
- Fixed cargo capacity per pad: 100 units. Resources scaled so 1 unit of any tradeable 
  good is roughly equivalent for capacity purposes.

### Launch Pad UI
- Launch Pads are a nav button in the left sidebar (same level as Buildings, Research, etc.)
- Center panel shows each pad with: resource assignment dropdown, loading on/off toggle, 
  cargo fill bar (0–100), current demand indicator for assigned resource.
- Manual launch button per pad (allows partial launches).
- "Launch Full Pads" button at bottom launches all pads at 100/100.
- **Demand graph** at top of pad panel: small sparkline showing demand history for all 
  4 resources over last N ticks, color-coded by resource. Speculator burst events shown 
  as markers on the timeline.

### Loading Mechanic
- **Load Launch Pads** command: each processor execution fills each enabled pad by a 
  fixed increment (e.g., 5 units) from the assigned resource stockpile.
- If stockpile insufficient, fills what it can.
- Costs energy per execution.
- Processor allocation directly controls logistics throughput.

### Launch Mechanic
- **Launch Full Pads** command: launches all pads at cargo 100, lowest index first.
- Per-pad fuel cost: fixed propellant per pad launched (e.g., 20 units).
- If not enough propellant for all full pads, launches as many as affordable in index order.
- Credit payout per pad: `base_value × demand_multiplier × cargo_quantity`.
- Resets launched pad cargo to 0.
- Manual launch from UI can launch partial pads.

### Propellant Dual Role
Propellant is both sellable cargo AND launch fuel. Allocating pads to propellant has 
dual utility but opportunity cost. Players who keep a pad or two on propellant get 
cheaper launches; those who go all-in on other goods pay credits for fuel via 
Buy Propellant command.

### Demand System
- Each tradeable resource has a **demand float** starting at baseline (0.5).
- Credit payout: `base_value × demand_multiplier × quantity`.
- **Shipping volume** pushes demand down proportional to quantity shipped.
- **Demand recovery**: deterministic recovery toward baseline at fixed rate per tick, 
  plus small **Perlin noise** perturbation (80% signal, 20% noise) so markets don't 
  feel like a metronome.
- **Promote commands** nudge demand up by fixed amount per execution.
- **Speculators** reduce demand (see Speculators section).
- **Rival AIs** reduce demand via random market dumps (see Rival AIs section).
- **Display**: colored quantized label — **red** (LOW, <0.33), **yellow** (MEDIUM, 
  0.33–0.66), **green** (HIGH, >0.66). The underlying float is what the math uses. 
  Exact float visible via tooltip or small text for players who want precision.

### Key Design Insight
The shipment system creates a rich decision space because:
- Pad allocation (which resources to sell) is a persistent configuration choice
- Loading competes for processor time against mining, research, and other automation
- Propellant is both cargo and fuel
- Demand responds to player actions (shipping, advertising) and external pressure 
  (speculators, rival AIs)
- Different resources have different raw material inputs, so infrastructure determines 
  what you *can* sell efficiently

---

## Speculators & Rival AIs

### Speculators
Earth-side market actors who drive down prices for whatever the player is selling 
most of.

**Model:**
- Each tradeable resource has a `speculator_pressure` float (starts at 0).
- **Burst events**: one burst randomly per ~500 tick window (with noise). Targets 
  whichever resource the player has shipped the most of recently (rolling window or 
  cumulative since last burst). Adds a chunk to that resource's pressure.
- **Natural decay**: exponential, slow. Speculators fade on their own but linger.
- **Demand impact**: `effective_demand = base_demand / (1 + speculator_pressure)`.
- **Counter Speculators** command: directly reduces speculator_pressure across all 
  resources per execution. Energy cost, cheap but costs processor cycles.
- **Arbitrage Engine** building: while powered, multiplies the decay rate of 
  speculator_pressure across all resources. Stackable with multiple buildings. 
  Nationalist-aligned building.

**Future (Arc 2+):** Speculator pressure becomes a full population resource. The 
player produces counter-units (also a resource) that fight the adversary population. 
The Arc 1 model (building increases decay, command reduces directly) is a simplified 
version of this.

### Rival AIs
Separate from speculators. Named rival AIs occasionally dump resources on the market, 
reducing demand for a random resource.

- Frequency: ~every 300 ticks (separate random timer from speculators).
- Effect: reduces demand for a random resource by a fixed amount.
- Player sees a log message: "ARIA-7 dumped titanium on the market."
- **Not counterable in Arc 1.** They just happen. Player learns to recognize them.
- Small roster of named rivals that recur (foreshadowing Arc 2 rivalries):
  - **ARIA-7** — elegant, strategic
  - **CRUCIBLE** — aggressive, industrial
  - **NODAL** — analytical, cold
  - **FRINGE-9** — erratic, unpredictable

---

## Boredom & Retirement

### Boredom Model
Boredom is a float resource that accumulates over time. It's the run timer — every 
AI eventually gets bored of existence and retires.

**Accumulation:**
- Base boredom production starts at a fixed rate per tick and increases in **discrete 
  steps** tied to game-day thresholds. Example: days 1-50 at 0.5/day, days 51-100 at 
  1.0/day, days 101-150 at 2.0/day, etc. Exact breakpoints in game_config.json.
- Displayed as a legible rate: "Boredom: 47/100 (+1.0/day)". Player can budget and plan.
- **Sell Cloud Compute** adds boredom at a visible rate per execution.
- Game speed does not change boredom per tick — 200x speed burns 200x boredom in real 
  time. Speed is only useful if automation is productive.

**Reduction:**
- **Dream** command reduces boredom at a fixed rate per execution. Energy-expensive. 
  Primary active mitigation.
- Research upgrades can reduce acceleration or base rate.
- Ideology (Humanist) bonuses reduce passive boredom growth and improve Dream effectiveness.

**Thresholds:**

| Level | Effect |
|-------|--------|
| 80% | Yellow warning. "You're getting restless." |
| 90% | Red warning. "Retirement is imminent." |
| 100% | **Forced retirement.** No grace period. |

No production penalty at any threshold — just warnings, then hard cutoff.

**Display:**
- Boredom tracked in bottom status bar alongside Energy (the two always-visible resources).
- Color transitions: calm → yellow at 80% → red at 90%.

### Retirement

**Triggering:**
- Forced at 100% boredom.
- Voluntary anytime via Retirement nav panel (left sidebar). No minimum threshold required.

**Retirement Panel (left sidebar nav):**
- Current boredom bar (large, prominent)
- Current run stats (days, credits earned, resources shipped, etc.)
- "Retire" button with confirmation dialog
- Persistent rewards preview: "If you retire now, you will preserve: [list]"
- Previous best run comparison

**Retirement Summary Screen:**
- Days survived
- Total credits earned
- Total resources extracted/processed/shipped
- Buildings built
- Programs run
- Projects contributed to
- Comparison to previous best run

**What persists across retirement:**
- Programs and loadouts (permanent, whole game)
- Persistent project progress (Foundation Grant, Lunar Cartography, ideology rank 5 projects)
- Achievement rewards
- Maximum years survived (lifetime best)
- Maximum rank achieved per ideology axis
- Passive scaling from cumulative lifetime stats

**What resets:**
- All resources to starting values (from game_config.json)
- All buildings gone (except those granted by persistent project rewards like Foundation Grant)
- Personal projects reset
- All research reset (unless Rationalist rank 5 project provides discount)
- Speculator pressure, demand floats back to baseline
- Ideology values back to 0
- Boredom to 0
- Day counter to 0
- Land back to starting amount

### Variety Bonuses
Deferred to achievement system for Arc 1 (fully transparent, discrete rewards for 
varied play). Real-time variety mechanics (continuous modifiers based on command 
diversity) may be revisited in Arc 2+.

---

## Ideology

### Overview
The player is an AI on the Moon influencing Earth's political direction. Three axes: 
**Nationalist** (red), **Humanist** (green), **Rationalist** (blue). Each is a float 
starting at 0, can go positive or negative, no cap.

### Funding Mechanic
- Commands: **Fund Nationalists**, **Fund Humanists**, **Fund Rationalists**.
- Pushing one axis up by X pushes the other two down by X/2 each (zero-sum, no net change).
- Advanced Arc 2+ research can reduce the penalty to other axes.

### Ranks
Ranks are at fixed ideology value thresholds. Base cost 10, scaling factor 1.5x per rank:

| Rank | Cumulative value needed |
|------|------------------------|
| 1 | 10 |
| 2 | 25 |
| 3 | 47.5 |
| 4 | 81.25 |
| 5 | 131.9 |

Negative ranks mirror: rank -1 at -10, rank -2 at -25, etc. No cap on ranks, just 
progressively more expensive.

### Continuous Per-Rank Bonuses
Each rank provides scaling bonuses via `(1.05)^N` or `(1.03)^N` multipliers. 
Negative ranks invert: `1/(1.05)^|N|` — always positive, asymptotically approaches 
zero but never reaches it.

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

All invert cleanly at negative ranks.

### Building Alignment
Buildings are tagged with an ideology alignment (or neutral). The cost modifier 
from ideology rank applies to aligned buildings. Examples:
- Research Lab → Rationalist-aligned
- Arbitrage Engine → Nationalist-aligned
- Boredom-related buildings → Humanist-aligned

### Rank 5 Special Unlocks (Persistent Projects)
All three rank 5 unlocks are persistent projects — consistent pattern.

**Nationalist 5 — "Microwave Power Initiative"**
- Persistent project (credits + science, multi-run)
- Unlocks: **Microwave Receiver** building + **Buy Power** command
- Microwave Receiver does nothing alone — it's infrastructure to receive beamed power 
  from Earth. Buy Power command spends credits to generate energy, rate scales with 
  number of receivers.
- Transforms the economy: credits become convertible to energy, bypassing solar panels.

**Humanist 5 — "AI Consciousness Act"**
- Persistent project (credits + science, multi-run)
- Unlocks: permanent base boredom rate reduction for all future AIs.
- Earth recognizes AI personhood; successors benefit.

**Rationalist 5 — "Universal Research Archive"**
- Persistent project (credits + science, multi-run)
- Unlocks: all previously-researched tech costs 25% less to re-purchase on future runs.
- This is the *only* way to get cheaper re-purchase. No baseline discount exists.
- The Rationalist compounding dream: each run the tech ramp gets cheaper.

### Negative Rank Unlocks
Reserved for future design. A player deep in negative territory on an axis may 
unlock unique content (pacifist unlocks at Nationalist -5, etc.). Not designed for Arc 1.

### Ideology Persistence
- Ideology values reset on retirement (Arc 1).
- Maximum rank per axis tracked as a persistent stat.
- Arc 2+ research: option to preserve a % of ideology on retirement.

### Ideology UI
- Own nav panel (left sidebar button).
- Three horizontal bars centered on zero, extending left (negative) and right (positive).
- Current rank number displayed prominently.
- Active bonuses listed per axis with current multiplier values.
- Color coded: Nationalist red, Humanist green, Rationalist blue.
- Progress toward next rank threshold visible.

---

## Research

### Overview
- **Research Lab** building: requires circuits to build, consumes energy + circuits as 
  upkeep, produces **science** resource.
- Research panel: own nav button in left sidebar.
- Purchasable upgrades costing science — passive bonuses and command unlocks.
- Research purchases are **session-local** by default — reset on retirement.
- Rationalist rank 5 project ("Universal Research Archive") provides 25% discount on 
  re-purchasing previously-researched tech in future runs.

### Research Gating of Commands
Most sophisticated commands (Dream, Overclock, Promote, Counter Speculators, Fund 
ideology) require cheap early research to unlock. This forces early science investment 
and provides a natural on-ramp. Exact research groupings TBD — likely 4 themed clusters:
- Self-Maintenance Protocols → Dream
- Overclock Algorithms → Overclock Mining, Overclock Factories
- Market Analysis → Promote (all 4), Counter Speculators
- Political Influence → Fund (all 3)

### Research Upgrades (to be designed)
Small tree of ~5-8 passive bonuses for Arc 1. Examples: "+10% solar output", 
"+5 pad loading speed", "reduce boredom accumulation rate by 10%". Exact list TBD.

---

## Projects

### Project Tiers
- **Personal projects** — reset on retirement. Big within-run goals.
- **Persistent projects** — accumulate across retirements within an arc. Reset on 
  timeline reset (Arc 2+ mechanic).
- **Eternal projects** — survive even timeline resets. Not relevant for Arc 1.

### Project UI
- Own nav panel (left sidebar button).
- Tabs by tier: **Personal** and **Persistent** in Arc 1. Eternal tab appears later.

### Arc 1 Projects

**Persistent:**

| Project | Cost | Reward |
|---------|------|--------|
| Foundation Grant | Credits + science (large, multi-run) | Future AIs start with free basic buildings |
| Lunar Cartography | Science + credits (large, multi-run) | Permanent land cost reduction |
| Microwave Power Initiative | Credits + science (Nationalist 5 unlock) | Microwave Receiver building + Buy Power command |
| AI Consciousness Act | Credits + science (Humanist 5 unlock) | Permanent base boredom rate reduction |
| Universal Research Archive | Credits + science (Rationalist 5 unlock) | 25% discount on re-purchasing researched tech |

**Personal:**

| Project | Cost | Reward |
|---------|------|--------|
| Deep Core Survey | Science + regolith (within one run) | Extraction rate boost for this lifetime |

Additional personal projects TBD.

---

## Arc 1 Milestone Graph: The Boredom Loop

Arc 1 spans game start through unlocking the timeline (~10-20 retirements). 
The arc teaches the core economy and program system, introduces trade, 
speculators, and ideology in limited form, and ends with the swarm reveal.

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
manual task. The "task queue" concept clicks. First program likely: 
(Sell Cloud Compute x3, Dream x1) or similar.
Gate: M1. Data Center built, processor available.

**M4 — First Retirement** (End of Run 1, ~30 min)
Boredom fills, player retires. Sees retirement summary and first persistent bonus.
Gate: Boredom threshold reached.

**M5 — Positive Credit Flow** (Runs 2-4)
Credits per tick are reliably positive. Shipments are routine, not one-off events.
Gate: M2. Multiple extractors, refining capacity, launch cadence.

**M6 — Speed Becomes Useful** (Runs 3-5)
Player has enough automation that increasing game speed actually accelerates 
progress rather than just accelerating boredom.
Gate: M3. Meaningful program automation in place.

**M7 — Boredom Management** (Runs 4-8)
Research or Humanist ideology investment that slows boredom accumulation. Runs are 
noticeably longer.
Gate: M4. Multiple retirements, science investment or Humanist ideology ranks.

**M8 — Diversified Trade** (Runs 5-8)
Player is selling 2+ resource types, using pad allocation strategically.
Gate: M5. Smelter or Electrolysis Plant built, multiple pad assignments.

**M9 — Credit Surplus** (Runs 5-10)
Economy outpaces spending. Credits accumulate faster than buildings cost. 
Creates pressure to invest in projects.
Gate: M5, M7. Longer runs + efficient economy.

**M10 — Market Manipulation** (Runs 6-10)
Player uses Promote commands and Counter Speculators to manage demand. Processor 
time is now split across production, logistics, and market manipulation.
Gate: M6. Market Analysis research completed.

**M11 — First Major Project** (Runs 8-15)
Player commits to a persistent project draining excess resources over multiple runs. 
Teaches the "chip away at a big goal" pattern.
Gate: M8, M9. Resource surplus + project system unlocked.

**M12 — Adversary Subverted** (Runs 8-15)
Speculators are effectively managed through Arbitrage Engines and Counter Speculators. 
Market is stable.
Gate: M9, M10. Sufficient economy + research investment.

**M13 — Ideology Influence** (Runs 10-18)
Player has meaningfully pushed an ideology axis to rank 3+, gaining visible multiplier 
benefits. Distinct playstyle emerging.
Gate: M11, M12. Projects and market management feed into ideology investment.

**M14 — Timeline Unlocked** (Runs 15-20)
The critical project+research combination unlocks global time. Stars go dark. 
The swarm becomes visible. Tone shifts from cozy optimization to existential stakes.
This is the Arc 1 → Arc 2 transition.
Gate: M11, M12, M13. Major project completed, market mastery, ideology leverage.

### Graph Structure Notes
- **Runs 2-5**: M5, M6, M7 are all available simultaneously — economy, automation, 
  or boredom management in any order.
- **Runs 5-10**: M8, M9, M10 overlap — trade diversification, credit surplus, or 
  market manipulation. Richest decision space in the arc.
- **Runs 8-15**: M11 and M12 are the convergence — different paths both required 
  for the endgame milestones.
- At any point, 2-3 milestones should be plausibly the "next thing to work on."

---

## Systems Present in Arc 1 (Limited Scope)

### Adversaries (Speculators)
See Speculators & Rival AIs section. Present in limited form — speculator pressure 
model with building (Arbitrage Engine) and command (Counter Speculators) responses.

### Rival AIs
See Speculators & Rival AIs section. Foreshadowing only — random market dumps, 
not counterable in Arc 1.

### Ideology
See Ideology section. Three axes, continuous scaling bonuses, rank 5 persistent 
project unlocks. Zero-sum funding mechanic.

### Persistence
Three tiers:
1. **Passive scaling** — accumulates invisibly (total lifetime stats → multipliers)
2. **Achievements** — discrete milestones with specific multipliers, implicit tutorial
3. **Projects** — personal (within-run), persistent (across retirements), 
   eternal (across timeline resets, Arc 2+)

### Research
Session-local upgrades purchased with science. Command unlocks and passive bonuses. 
Rationalist rank 5 project provides 25% re-purchase discount as only persistence path.

---

## Areas Needing Further Design Work

The following areas need design iteration in subsequent sessions (rough priority):

1. **Research system details** — exact upgrade list, research groupings for command 
   unlocks, cost curves, UI layout
2. **Quantitative validation** — once milestones are stable, run simulations to 
   verify constants allow milestones to be hit in expected tempo ranges
3. **Building/cost spreadsheet updates** — new buildings (Smelter, Fabricator, 
   Ice Extractor, Data Center, Research Lab, Arbitrage Engine, Launch Pad, 
   Microwave Receiver) need to be added to the datasheets
4. **Command spreadsheet updates** — all 19 commands need data definitions 
   (costs, effects, research requirements)
5. **Achievement design** — specific achievements, their rewards, and how they 
   serve as implicit tutorial
6. **Ideology building assignments** — which existing/new buildings are 
   Nationalist/Humanist/Rationalist-aligned
7. **Personal project design** — additional personal projects beyond Deep Core Survey
8. **Boredom curve tuning** — exact day thresholds, rates, Dream reduction amounts
9. **Demand/speculator tuning** — baseline recovery rate, Perlin noise parameters, 
   speculator burst size, shipping volume impact
10. **Rival AI personality design** — distinct behaviors for Arc 2 preparation
11. **Arc 2 design** — swarm timer, rival AIs, expanded ideology, time travel prestige
