# Helium Hustle — Project Index

Helium Hustle is an idle game built in Godot 4.x (GDScript). You play as an AI 
managing helium-3 mining on the Moon. The long-term arc involves rival AIs, a 
hegemonizing swarm, and time travel prestiges. Current development focus: 
playable Arc 1 — the core economic loop within the boredom-retirement cycle.

**This is pre-playtest.** No save migration code. No legacy compatibility.

---

## Handoff File Map

Always attach **this file** plus **handoff_core.md** to every session. Attach 
others as needed based on what you're working on. **Handoff files must be 
manually attached each session — they are not auto-available.**

**Sparse upload policy:** Only files that are attached in the current session 
should be modified at session end. Claude must never produce an updated handoff 
file from memory/recollection alone — only from the actual attached document 
plus the session's design changes. If a file wasn't attached, it stays unchanged.

| File | Scope | When to Attach |
|------|-------|----------------|
| `handoff_index.md` | This file. Project overview, system index, file map. | Always |
| `handoff_core.md` | Architecture, conventions, repo structure, testing, data pipeline, collaboration model. | Always |
| `handoff_active.md` | Implementation status, changelog, priorities, optimizer state, future ideas. | Always for design sessions. Optional for focused Claude Code prompts. |
| `handoff_buildings.md` | Building system: purchase, cost scaling, multi-pass resolution, partial production, stall tracking, overflow, visibility, categories. | Working on buildings, production, balancing |
| `handoff_programs.md` | Programs, processors, commands, partial production, output-cap skip, command boredom costs, rate tracking. | Working on programs, commands, automation |
| `handoff_economy.md` | Resource flow, storage/caps, shipments, launch pads, trade, propellant economy. | Working on resources, shipments, trade, launch pads |
| `handoff_demand.md` | Demand system, per-resource speculator pools, rival AIs, Perlin noise. | Working on demand, speculators, market mechanics |
| `handoff_progression.md` | Boredom, retirement, career bonuses, CareerState, run initialization, research, ideology, projects, modifier framework. | Working on progression, retirement, research, ideology, projects, modifiers |
| `handoff_narrative.md` | Events, quests (semantic IDs), achievements, Story panel, progressive disclosure (nav buttons, visibility rules, "new" indicators). | Working on events, quests, achievements, story, progressive disclosure |
| `handoff_stats.md` | Stats panel, rate tracking, overflow display, lifetime totals, playtest telemetry. | Working on Stats panel, telemetry |
| `handoff_achievements.md` | Achievement definitions, conditions, rewards. | Working on achievements or Story panel |
| `handoff_constants.md` | Auto-generated reference of all game numbers. | Balancing, tuning, or when exact numbers matter |

The **"Helium Hustle Game Design"** doc in Google Drive (ID: 
`134ThxsDfcZb1z880Y3z2_cnCmaX9z0WA_e3IbE_QQtM`) provides the full creative 
vision and long-term arc. The handoff files are authoritative for decisions 
already made; the Game Design doc provides broader context.

---

## System Index

### Core Loop
| System | Status | File | Notes |
|--------|--------|------|-------|
| Resource tick loop | Stable | `handoff_core.md` | GameState, GameSimulation, GameManager |
| Building system | Stable | `handoff_buildings.md` | Multi-pass resolution, partial production, overflow |
| Program/processor system | Stable | `handoff_programs.md` | 5 tabs, 20 commands, partial production |
| Storage caps | Stable | `handoff_economy.md` | Modifier-aware caps |

### Economy & Trade
| System | Status | File | Notes |
|--------|--------|------|-------|
| Resource flow (Arc 1) | Stable | `handoff_economy.md` | 4 tradeable goods, energy bottleneck |
| Shipment/launch pads | Stable | `handoff_economy.md` | Pause toggle, propellant costs |
| Demand system | **Prompted** | `handoff_demand.md` | 4 per-resource speculator pools, no bleedover |
| Speculators & rivals | **Prompted** | `handoff_demand.md` | Per-resource pools, independent decay |

### Progression & Meta
| System | Status | File | Notes |
|--------|--------|------|-------|
| Boredom & retirement | **Prompted** | `handoff_progression.md` | Dynamic cap (500 + Recreation Domes) |
| Career bonuses | **Prompted** | `handoff_progression.md` | Buy Power formula revised |
| Research | Stable | `handoff_progression.md` | 12 items, visibility gating |
| Ideology | Stable | `handoff_progression.md` | 3 axes, geometric rank formula |
| Projects | Stable | `handoff_progression.md` | Persistent + personal, drain model |
| Modifier framework | Stable | `handoff_progression.md` | 12 modifier keys |
| CareerState | Stable | `handoff_progression.md` | Cross-run persistence |

### Narrative & Content
| System | Status | File | Notes |
|--------|--------|------|-------|
| Events | Stable | `handoff_narrative.md` | Triggers, conditions, unlock effects |
| Quest chain | **Prompted** | `handoff_narrative.md` | Semantic IDs, multi-objective sidebar display |
| Achievements | Stable | `handoff_narrative.md`, `handoff_achievements.md` | 6 achievements, 2 categories |
| Story panel | Stable | `handoff_narrative.md` | Primary Objectives + Achievements |
| Progressive disclosure | Stable | `handoff_narrative.md` | Per-element-type visibility rules |

### UI & Display
| System | Status | File | Notes |
|--------|--------|------|-------|
| Stats panel | Stable | `handoff_stats.md` | Per-resource breakdown, lifetime totals |
| Playtest telemetry | Stable | `handoff_stats.md` | JSONL logging per run |
| UI skeleton | Stable | `handoff_core.md` | Three-column layout, light/dark mode |
| Speed controls | **Prompted** | — | Icon pause, highlighted active speed |
| Options panel | Stable | — | Debug toggles |
| Rate display | **Prompted** | — | All rates shown as /day |

### Infrastructure
| System | Status | File | Notes |
|--------|--------|------|-------|
| Save/load | Stable | `handoff_progression.md` | Single file, autosave, version 1 |
| Headless tests | Stable | `handoff_core.md` | 14+ suites, ~1500 assertions |
| Python optimizer | **Needs sync** | `handoff_active.md` | Does not model demand, overflow, etc. |

---

## Key Design Principles (quick reference)

- Programs/processors are the game's core identity and primary skill expression.
- Boredom is a speed governor, not a punishment.
- The game should be interesting at max speed.
- Buildings = infrastructure decisions. Programs = operational decisions.
- JSON files in `godot/data/` are ground truth. Everything else derives from them.
- Game logic (GameState, GameSimulation) has no UI references.
- No same-resource production and upkeep in buildings.
- Bonus buildings don't inflate cost curves.
- Player-facing rates always display as `/day`. Internal code may use "per tick."

---

## Tick Order

Boredom → Buildings (multi-pass) → Demand Update → Programs → Projects → 
Shipments → Speculator Revenue Tracking → Speculator/Rival Burst Check → 
End-of-tick Clamp & Overflow → Events → Achievement checks → Ideology max rank 
update → Advance day.
