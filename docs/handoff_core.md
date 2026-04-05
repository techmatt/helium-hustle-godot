# Helium Hustle — Core Handoff

## Instructions for Claude

Read this document and any companion documents provided. The handoff is split into parts:

- **handoff_core.md** (this file) — what the game is, architecture, conventions, 
  design philosophy, repo structure, testing. Rarely changes.
- **handoff_systems.md** — mechanical specifications for each game system. Formulas, 
  interactions, design rationale. Updated when systems change.
- **handoff_active.md** — implementation status, changelog, priority list, open 
  design questions, future ideas. Updated every session.
- **handoff_constants.md** — auto-generated reference of all game numbers (buildings, 
  commands, research, projects, events, config). Regenerated from JSON ground truth 
  via `python docs/generate_constants.py`. **Do not hand-edit this file.**
- **handoff_achievements.md** — achievement system design: categories, specific 
  achievements, conditions, rewards, and the Story panel UI spec. Attach when 
  working on achievements, the Story panel, or quest display.

Not all files will be attached every session. If you need information that would be 
in a missing file, ask for it. For example:
- Balancing or tuning work → ask for `handoff_constants.md`
- New feature design → ask for `handoff_systems.md` (or the relevant section)
- Prioritization or status → ask for `handoff_active.md`
- Achievement design or Story panel → ask for `handoff_achievements.md`

The **"Helium Hustle Game Design"** doc in Google Drive (ID: 
`134ThxsDfcZb1z880Y3z2_cnCmaX9z0WA_e3IbE_QQtM`) provides the full creative vision 
and long-term arc. The handoff files are authoritative for decisions already made; 
the Game Design doc provides broader context.

**These documents are used by both claude.ai (for design discussions) and Claude Code 
(for implementation).** Write all specifications with enough detail that either 
context can act on them without additional clarification.

**Each handoff file must be self-contained within its scope.** Do not use phrases 
like "unchanged from prior handoff" or "see prior session." If information is 
relevant to a file's scope, it must be present in that file.

**Session end protocol:** At the end of a design session on claude.ai, produce 
updated versions of whichever handoff files were modified. The user will save them 
and attach them to the next session.

**Claude Code prompt convention:** When producing prompts for Claude Code, export 
them as `.md` files (downloadable) rather than pasting inline in conversation. This 
makes them easy to feed directly to Claude Code.

---

## What This Is

Helium Hustle is an idle game built in Godot 4.x (GDScript). You play as an AI 
managing helium-3 mining on the Moon. The game has a long-term arc involving rival 
AIs, a hegemonizing swarm, and time travel prestiges. The current development focus 
is building a playable Arc 1 — the core economic loop within the boredom-retirement 
cycle.

---

## Design Philosophy

- The program/processor system is the game's core identity. It's both the automation 
  mechanic and the primary skill expression for experienced players.
- Boredom is a speed governor, not a punishment. It prevents fast-forwarding through 
  learning.
- The game should be interesting at max speed. Players design scripts, then accelerate.
- Keep the first milestone simple: is the building/resource/program loop fun?
- Buildings = infrastructure decisions (what you build, capital allocation).
- Programs = operational decisions (logistics timing, market manipulation, burst 
  production).

---

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
    achievements.json      ← GROUND TRUTH for achievement definitions
    game_config.json       ← GROUND TRUTH for starting state, boredom, shipment, demand, etc.
  scenes/
    main_ui.tscn           ← Main scene (three-column layout)
    ui/BuildingCard.tscn
    ui/CommandRow.tscn
    ui/EventPanel.tscn
    ui/EventModal.tscn
    ui/RetirementSummary.tscn
  scripts/
    game/
      game_state.gd        ← class_name GameState — pure data, no UI
      game_simulation.gd   ← class_name GameSimulation — core economy logic, no UI
      demand_system.gd     ← class_name DemandSystem — demand/speculator/rival logic
      game_manager.gd      ← autoload singleton, owns state + sim
      event_manager.gd     ← class_name EventManager — event logic, no UI
      achievement_manager.gd ← class_name AchievementManager — achievement logic, no UI
      resource_rate_tracker.gd ← class_name ResourceRateTracker — per-source rate tracking
      career_state.gd      ← class_name CareerState — cross-run persistent data
      save_manager.gd      ← class_name SaveManager — disk save/load utility
      project_manager.gd   ← class_name ProjectManager — project drain/unlock/completion logic
      game_settings.gd     ← autoload singleton — display and debug settings
    ui/                    ← All UI scripts (see repo for full listing)
  tests/
    run_tests.gd           ← Headless test runner entry point
    test_suite_base.gd     ← Base class with assertion helpers
    test_fixtures.gd       ← Shared fixture factory for test state
    test_*.gd              ← Test suites (see Testing section)
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
  handoff_core.md          ← this file
  handoff_systems.md       ← system mechanical specs
  handoff_active.md        ← status, priorities, changelog
  handoff_achievements.md  ← achievement system design and Story panel spec
  handoff_constants.md     ← auto-generated constants reference
  generate_constants.py    ← script to regenerate handoff_constants.md
  project_system_spec.md   ← project system implementation spec
  quest_system_revision.md ← quest chain revision spec
  optimizer_design.md      ← optimizer architecture spec (scenario-based approach)
```

**Deleted files (no longer in repo):**
- `docs/tech_spec.md` — original MVP spec, fully superseded by handoff files.
- `docs/program_system_spec.md` — fully implemented, spec now lives in 
  `handoff_systems.md`.

---

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

### Resource Display Names
All player-facing resource names come from the `display_name` field in 
`resources.json`. UI code uses a `get_resource_display_name(resource_id)` helper 
rather than hardcoding name strings. Internal IDs (e.g., `circuits`) are for code 
use only; display names (e.g., "Circuit Boards") are for player-facing text.

### Implementation Note
All resources are **float internally**, displayed as integers or one decimal place 
depending on context. This avoids rounding edge cases with fractional production 
rates, Overclock multipliers, demand floats, etc. We prefer integer values in the 
data files where possible; fractional values are reserved for systems that 
inherently need them (circuit production, demand floats, etc.).

---

## Architecture Notes

- Game logic (GameState, GameSimulation) has no UI references — designed for 
  headless simulation support (which now exists in both `sim/` and `godot/tests/`).
- Tick order: Boredom → Buildings (multi-pass resolution) → Demand Update → 
  Programs → Projects → Shipments (using current demand, apply launch saturation 
  hits) → Speculator Revenue Tracking → Speculator/Rival Burst Check → End-of-tick 
  Clamp & Overflow Tracking → Events → Achievement checks → Ideology max rank 
  update → Advance day.
- Building processing uses multi-pass resolution: Phase 1 iterates attempting full 
  production, retrying until stable; Phase 2 applies partial production to remaining 
  buildings. Definition order from `buildings.json` is the tiebreaker. See 
  `handoff_systems.md` for full specification.
- Building production/upkeep uses `active_count` (not `owned_count`). Only active 
  buildings produce, consume, and grant effects.
- **Buildings always produce, even when output is at cap.** Overflow is clamped at 
  end of tick and tracked as waste in the Stats panel. There is no output-cap skip 
  for buildings.
- **Commands DO skip when output is at cap.** Buy commands skip execution (advance 
  pointer, don't pay inputs) when all output resources are at storage cap. This is 
  intentional — commands are player-authored automation and wasting processor ticks 
  on capped output is a signal to fix the program.
- **Command boredom costs are base command properties.** Some commands have a 
  `boredom` cost field in `commands.json` (e.g., Sell Cloud Compute costs 0.1 
  boredom per execution). These costs are inherent to the command and are NOT 
  gated on any flag or project. The AI Consciousness Act modifies command 
  costs/production values but does not act as a gate that enables boredom costs.
- **DemandSystem is a separate class** (`demand_system.gd`), extracted from 
  GameSimulation. Owns all demand config, Perlin noise, speculator/rival logic.
- **ProjectManager is a separate class** (`project_manager.gd`). Owns project 
  definitions, unlock checks, drain processing, completion logic.
- **AchievementManager is a separate class** (`achievement_manager.gd`). Owns 
  achievement definitions, condition checking, reward application.
- **GameSettings is an autoload singleton** (`game_settings.gd`). Owns display 
  preferences (dark mode) and debug flags (no boredom). Emits `theme_changed` 
  signal for UI retheming.

### Design Rules
- **No same-resource production and upkeep.** No building should both produce and 
  consume the same resource. Consolidate to net value in the data.
- **Tick parameter decoupling.** Currently `GameSimulation.tick()` takes 
  `(state, debug_no_boredom)`. As more per-tick parameters are needed, consider 
  passing a tick-params dictionary or config object.
- **Bonus buildings don't inflate costs.** Buildings granted by persistent projects 
  or achievements track `bonus_count` separately. Cost scaling uses 
  `max(0, owned_count - bonus_count)`. This applies to Foundation Grant, 
  achievement rewards, and any future bonus building sources.
- **Floating point epsilon for affordability checks.** Building upkeep affordability 
  checks use a `RESOURCE_EPSILON` constant (0.001) to prevent false stalls from 
  floating point precision errors. The epsilon applies to the input check only 
  (`available >= needed - RESOURCE_EPSILON`), not to actual consumption amounts. 
  Any resulting tiny negative resource values are handled by the end-of-tick clamp.

---

## Tempo & Tick Assumptions

- **1 tick = 1 day** (may be revised to 1 tick = 1 hour if pacing requires it)
- **Early runs: ~800–1,100 ticks** for optimal play, target ~1,500 ticks for 
  casual play (~30 min real-time at mixed speeds).
- **Energy budget target: ~25 energy/tick** at comfortable mid-run.

---

## Testing

### Overview
Test suites with assertions covering all core game systems including achievements. 
Tests run headlessly without launching the full game UI.

### How to Run
```
godot --headless --path godot/ --script tests/run_tests.gd
```

### Architecture
- **`run_tests.gd`** — entry point, extends `SceneTree`. Loads all suite scripts 
  via `preload()`, sets `GameManager.skip_save_load = true`, iterates suites, 
  reports pass/fail totals, exits.
- **`test_suite_base.gd`** — base class with assertion helpers (`_assert_equal`, 
  `_assert_true`, `_assert_false`, `_assert_gt`, `_assert_lt`, `_assert_approx`, 
  `_assert_stall_status`). Each assertion increments `tests_passed` or 
  `tests_failed`.
- **`test_fixtures.gd`** — shared factory methods that build configured 
  GameState/GameSimulation/DemandSystem instances without needing the full scene 
  tree. Creates minimal valid state with resources, buildings, config data loaded 
  from the real JSON files.

### Adding New Tests
1. Create `tests/test_<name>.gd` extending `"res://tests/test_suite_base.gd"`
2. Override `func run(scene_root: Node) -> void:`
3. Use `test_fixtures.gd` to create state, call assertions
4. Add `preload("res://tests/test_<name>.gd")` to `_SUITES` in `run_tests.gd`

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

### Optimizer Command Reference
```
python sim/run_optimizer.py                          # default scenario
python sim/run_optimizer.py sim/scenarios/run1.json  # specific scenario
python sim/run_optimizer.py --debug-tick 38          # debug scoring
python sim/trace.py 38                               # trace tables
```

---

## Collaboration Model

### Two-Track Development
- **Design discussions** happen on claude.ai with the relevant handoff files attached.
- **Implementation** happens in Claude Code with `handoff_core.md` + relevant 
  system sections + `handoff_constants.md` (if numbers matter).
- **Small/obvious changes** (rename a field, tweak a number, fix a bug) can go 
  directly to Claude Code. Log them in the changelog section of `handoff_active.md`.
- **Design decisions** (new systems, mechanic changes, balancing) go through 
  claude.ai first.
- **Claude Code prompts** are exported as `.md` files from claude.ai, not pasted 
  inline. This makes them easy to feed directly to Claude Code.

### Rule of Thumb
If the change could affect another system's balance or design assumptions, discuss 
on claude.ai first. If it's self-contained within one system and the spec is clear, 
go direct to Claude Code.
