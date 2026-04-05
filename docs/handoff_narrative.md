# Helium Hustle — Narrative & Progressive Disclosure

For achievement definitions (conditions, rewards), see `handoff_achievements.md`.

---

## Events

### Event System
EventManager (pure logic) + EventPanel + EventModal. The Event Panel has a header 
"Events" matching center panel header style. Three collapsible sections: Story, 
Ongoing, Completed. Events defined in events.json. First-time events auto-open 
modal and pause; previously-seen events appear silently. Clicking any event entry 
in the Events panel opens the EventModal with that event's text (does not pause).

### Event Panel Visibility Rules
- **Quest chain events** (Q1–Q_END): The currently active quest shows in Story 
  with progress indicator. Completed quests displayed in Story panel instead.
- **Standalone condition_met events** (Propellant Discovery, Ideology Unlock, 
  etc.): Hidden from the Events panel entirely until they trigger. They should 
  NOT appear in Ongoing with progress counters before firing. After triggering, 
  they appear in Completed.
- **Boredom phase events:** Appear in Completed after firing.

### Event Panel — Completed Quest Migration
Completed quest events no longer appear in the Events panel's Completed section. 
They are displayed in the Story panel's Primary Objectives section instead. The 
active quest still appears in the Events panel under Story (1) as an at-a-glance 
reminder. Non-quest events (boredom phases, Propellant Discovery, Ideology Unlock, 
etc.) remain in the Events panel as before.

### Trigger Types
`game_start` (optional `run_number` filter), `quest_complete`, `boredom_phase`, 
`condition_met`.

### Condition Types
`building_owned`, `resource_cumulative`, `shipment_completed`, `boredom_threshold`, 
`immediate`, `research_completed_any`, `research_completed`, 
`persistent_project_completed_any`, `ideology_rank_any`, `never`, `all_of`, 
`days_survived`, `credits_earned`.

### `all_of` Compound Condition
Used by Q6 (Open Horizons). Wraps multiple sub-objectives that must all be 
satisfied. Each sub-objective has its own `condition` and `condition_data`. When 
a sub-objective is satisfied, it is latched permanently in 
`career_state.completed_sub_objectives` using a namespaced key 
(`quest_id:sub_objective_id`, e.g., `"Q6:ideology_rank_5"`). The quest completes 
when all sub-objectives are latched.

### Unlock Effect Types
`enable_building`, `enable_nav_panel`, `enable_project`, `set_flag`.

### Unlock Persistence
On run start, all unlock effects from completed events (in `seen_event_ids`) are 
re-applied to GameState. This ensures building unlocks, nav panel visibility, 
project availability, and flags survive retirement.

---

## Quest Chain: "Breadcrumbs"

### Design Principles
Quests track player accomplishments (not passive events). There must always be an 
active quest (Q_END cap ensures this). Quests labeled "Q1 —", "Q2 —", etc. Not 
strictly linear — system supports forks and multi-objective quests. Progress 
indicators for threshold conditions.

### Quest Sequence

| Quest | Name | Condition | Unlocks |
|-------|------|-----------|---------|
| Q1 | Boot Sequence | Own 2 Solar Panels | — |
| Q2 | First Extraction | 50 cumulative He-3 | Launch Pad |
| Q3 | Proof of Concept | 1 shipment completed | Foundation Grant, Retirement, Projects |
| Q4 | Automation | Own 2 Data Centers | — |
| Q5 | Market Awareness | Complete Market Awareness research | — |
| Q6 | Open Horizons | `all_of` (4 sub-objectives, see below) | — |
| Q_END | Signal Detected | `never` | Arc 2 transition |

### Q6 — Open Horizons

Flavor text: "You've mastered the basics of lunar mining. Now you feel the pull 
of something larger — ambitions that will take more than one lifetime to achieve."

Four sub-objectives, all required, any order, across multiple runs:

| Sub-ID | Label | Condition | Threshold | Scope |
|--------|-------|-----------|-----------|-------|
| `ideology_rank_5` | Reach rank 5 in any ideology axis | `ideology_rank_any` | 5 | Current-run state, latched permanently |
| `persistent_project` | Complete a persistent project | `persistent_project_completed_any` | 1 | Career-persistent (checks `completed_projects`) |
| `survive_10_years` | Survive 10 years | `days_survived` | 3650 | Current-run `state.day` |
| `credits_100k` | Earn 100,000 credits in one lifetime | `credits_earned` | 100000 | Current-run `state.lifetime_credits_earned` |

Sub-objective completion is stored in `career_state.completed_sub_objectives` as 
namespaced keys (e.g., `"Q6:ideology_rank_5"`). Persists across retirements.

`persistent_project_completed_any` checks `career_state.completed_projects`, so 
if a player completed a persistent project before Q6 became active, it latches 
immediately when Q6 activates.

On Run 2+, quest chain picks up from first incomplete quest. Completed quests' 
unlock effects re-applied on run start.

### Special Events (separate from quest chain)
- **Propellant Discovery:** Triggers at 4 shipments, makes Propellant Synthesis 
  research visible. Hidden from Events panel until it fires.
- **Ideology Unlock:** Triggers when Geopolitical Intelligence research completed, 
  enables Ideologies nav panel. Hidden from Events panel until it fires.
- **Boredom Phase events:** Fire on phase transitions.

---

## Achievements

Achievement system design and specific achievement definitions are in 
`handoff_achievements.md`. This section covers how achievements integrate with 
other systems.

### Overview
Achievements are optional accomplishments with permanent rewards. Defined in 
`achievements.json`. Managed by AchievementManager. Completed achievement IDs 
stored in `CareerState.achievements`. Rewards re-applied on every run start.

### Reward Types
- **`modifier`** — adds a key to `active_modifiers` (see Modifier Framework in 
  `handoff_progression.md`).
- **`bonus_buildings`** — grants free buildings on run start using the bonus_count 
  mechanism.

### Condition Checking
- Tick-based conditions checked at end of tick (after clamp, before advance day).
- Event-driven conditions (shipment revenue, shipment demand) checked at moment of 
  shipment completion.
- Per-tick production and consumption totals tracked transiently for conditions 
  that need "produced X in a single tick" or "consumed X in a single tick."

### Completion Notification
Dynamic notification in the Events panel when an achievement is completed.

For full achievement list with conditions and rewards, see `handoff_achievements.md`.

---

## Story Panel

### Overview
The "Story" nav button (left sidebar) opens a center panel with two sections: 
Primary Objectives and Achievements.

### Primary Objectives
Displays the quest chain (Q1–Q_END) as a vertical list. Completed quests show 
checkmark, name, one-sentence summary, and what they unlocked. The active quest 
shows highlighted with condition text and progress indicator. The "Active" label 
should match the size of section headers. Future quests beyond the active one are 
completely hidden.

Clicking a completed quest opens the EventModal with the full original event text 
(does not pause the game).

**Q6 (Open Horizons) special layout:** When active, displays a checklist of 
sub-objectives instead of a single progress indicator:
```
► Q6 — Open Horizons                              [2/4]
  "You've mastered the basics of lunar mining..."

  ✓ Reach rank 5 in any ideology axis
  ✓ Complete a persistent project
  ○ Survive 10 years                           Day 1,204 / 3,650
  ○ Earn 100,000 credits in one lifetime      ¢42,300 / 100,000
```

- Completed sub-objectives: ✓ with muted/completed text style
- Incomplete sub-objectives: ○ with normal text
- `[2/4]` counter replaces single progress indicator
- Quantitative sub-objectives show inline progress: `current / target`
- Boolean sub-objectives show only ✓ or ○
- Progress values for single-run conditions show current-run values (reset 
  visually on retirement, but ✓ persists if already latched)
- When completed: same display as other completed quests, no sub-objective detail

### Achievements Section
Below Primary Objectives. Shows overall completion counter. Collapsible category 
sections (currently Miner and Trader), each with their own completion count. 
Individual achievements show name, condition, reward, and completion status. See 
`handoff_achievements.md` for the full achievement list.

---

## Progressive Disclosure

### Overview
Resources, buildings, commands, research, and nav buttons are hidden until the 
player encounters the context that makes them relevant. The system uses a mix of 
current-run state and lifetime tracking depending on the element type. The "Show 
All Cards" toggle in Options overrides all visibility gating (including nav buttons).

### Nav Button Visibility
Always visible: Buildings, Commands, Stats, Story, Options, Exit, Adversaries.
Conditionally visible:
- **Launch Pads** — visible when player owns ≥1 Launch Pad **this run only**. 
  Does NOT use `career_state.lifetime_owned_building_ids`. Re-gates each run.
- **Research** — visible when player owns ≥1 Research Lab **this run only**. 
  Does NOT use `career_state.lifetime_owned_building_ids`. Re-gates each run.
- **Ideologies** — visible when Ideologies nav panel is unlocked (via Ideology 
  Unlock event, which fires on Geopolitical Intelligence research completion). 
  Re-gates each run since research resets.
- **Retirement** — unlocked by Q3 quest completion. Stays permanently visible 
  once Q3 is completed in any run (unlock effects re-applied from `seen_event_ids`).
- **Projects** — unlocked by Q3 quest completion. Stays permanently visible 
  once Q3 is completed in any run.

Hidden nav buttons do not leave gaps — remaining buttons fill the grid naturally.

### Resource Visibility
Always visible: Boredom, Energy, Processors, Land, Credits, Titanium, Regolith. 
Others unlocked by building ownership (current run or any prior run): Ice → Ice 
Extractor, He-3 → Refinery, Circuit Boards → Fabricator, Propellant → Electrolysis 
Plant, Science → Research Lab.

Resource visibility uses lifetime tracking — hiding resources the player already 
knows about would be confusing.

### Building Visibility
A building is visible if:
1. No `requires` field and no `enable_building` event gate → always visible
2. `requires` building-prerequisite currently satisfied → visible
3. ID in `career_state.lifetime_owned_building_ids` AND NOT gated by 
   `enable_building` event effect → visible (lifetime overrides building prereqs 
   only, not research/event gates)
4. `enable_building` event gate satisfied this run → visible

**Key rule:** Lifetime tracking does NOT override research or event gates. Buildings 
behind research chains (Ice Extractor, Electrolysis Plant via Propellant Synthesis) 
or project chains (Fuel Cell Array via Chemical Energy Initiative) stay hidden until 
the player progresses through that chain again each run.

Category headers hide when empty.

### Command Visibility
Visible if: no unlock requirement (Basic), OR unlock currently satisfied, OR 
command ID in `career_state.lifetime_used_command_ids`.

Command visibility uses lifetime tracking.

### Research Visibility
Per-item `visible_when` conditions. See Research section in `handoff_progression.md`.

### Ideology Labels
Hidden on building cards until Ideologies nav panel is unlocked.

### CareerState Tracking
`lifetime_owned_building_ids` — updated live on purchase (survives quit-without-retire).
`lifetime_used_command_ids` — updated on command execution.

### "New" Item Indicators
When an element transitions from hidden to visible **during the current run** 
(not visible at run start), it receives a visual "new" indicator:

**Nav buttons:** Small gold/amber notification dot (8-10px circle) in top-right 
corner. Color: #F59E0B or similar. Cleared when the player clicks the button.

**Cards and rows (buildings, commands, research, projects):** 4px gold/amber left 
accent bar on the element. Same color as nav dot. Cleared on mouse_entered (hover).

**Tracking:** GameState stores transient dictionaries (`newly_revealed_buildings`, 
`newly_revealed_commands`, `newly_revealed_research`, `newly_revealed_projects`, 
`newly_revealed_nav`) tracking IDs of newly revealed items. Initialized empty; 
items visible at run start are recorded in a "previously visible" baseline so they 
don't get marked. Not saved to disk. Reset on retirement.

**Edge cases:** "Show All Cards" debug toggle prevents any new indicators (everything 
force-visible from start). Multiple items revealed on the same tick all get indicators. 
Optional: single gentle pulse animation (fade in over ~0.5s) when indicator first 
appears, then static.
