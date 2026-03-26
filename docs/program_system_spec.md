# Program System UI Spec — Helium Hustle

## Overview

The program system is the core player-facing mechanic of Helium Hustle. Players 
build command queues (programs), assign processors to them, and watch them execute 
automatically each tick. This spec covers the full implementation from data loading 
through UI interaction.

Reference the PyQt prototype screenshot for visual layout reference. The right 
panel of the three-column layout is the program panel.

---

## Stage 1: Data & State Foundation

**Goal:** Load commands from JSON, represent program state in GameState, execute 
programs in GameSimulation. No UI yet — just the logic layer.

### 1A: Command Data Loading

Commands are already defined in `godot/data/commands.json`. Ensure GameState loads 
them at startup, keyed by `shortname`. Each command has:
- `name` (display name)
- `shortname` (internal key)
- `costs` (dict of resource shortname → amount consumed per execution)
- `production` (dict of resource shortname → amount produced per execution)
- `effects` (list of special effects, e.g. boredom reduction)
- `requires` (research unlock prerequisite — ignore for now, treat all commands 
  as available)
- `always_available` (boolean — if true, no research needed)

### 1B: Program State in GameState

Add to GameState:
```
programs: Array of 5 ProgramData objects
  ProgramData:
    commands: Array of ProgramEntry
    processors_assigned: int (default 0)
  ProgramEntry:
    command_shortname: String
    repeat_count: int (default 1)
    current_progress: int (0 to repeat_count-1, resets on wrap)
    failed_this_cycle: bool

total_processors: int (= number of Data Centers owned, computed from buildings)
```

Programs persist across ticks. The player edits them; the simulation reads them.

### 1C: Program Execution in GameSimulation

Programs execute during the tick in the existing tick order (after Buildings, 
before Shipments — matching the handoff's tick order).

**Execution rules per tick:**
1. For each program (index 0–4) that has `processors_assigned > 0`:
2. For each processor assigned to that program, execute one step:
   a. Read the current command at the instruction pointer
   b. Check if the player can afford all costs
   c. If affordable: deduct costs, apply production/effects, advance progress
   d. If not affordable: mark `failed_this_cycle = true`, advance progress anyway
   e. If progress reaches repeat_count: advance instruction pointer to next row
   f. If instruction pointer passes the last row: wrap to row 0, clear all 
      `failed_this_cycle` flags, reset all `current_progress` to 0
3. Each processor executes exactly **one command execution per tick** (not one 
   full row — one step of the current row's repeat count)

**Important:** Multiple processors on the same program each independently advance 
the shared instruction pointer. With 2 processors on a program, it executes 2 
commands per tick from that program's queue.

**Edge cases:**
- Empty program with processors assigned: processors do nothing (no error)
- Program with 0 processors: skipped entirely
- Command produces a resource that's at cap: production is wasted (no error, 
  no blocking)

### 1D: Processor Pool

`total_processors` = count of Data Centers owned. When a Data Center is purchased, 
total_processors increases by 1. The new processor is unassigned.

`unassigned_processors` = total_processors - sum of all programs' processors_assigned

Constraint: You cannot assign more processors than are available. The UI enforces 
this; the simulation should also clamp.

---

## Stage 2: Program Panel UI (Right Panel)

**Goal:** Build the program panel in the right side of the existing three-column 
layout. This is where players view, edit, and monitor their programs.

### 2A: Program Tab Bar

Five numbered tabs (1–5) across the top of the right panel. Clicking a tab 
selects that program for viewing/editing. The active tab is visually highlighted 
(use the existing green accent color). Tabs should show a subtle indicator if the 
program has commands in it (e.g. a small dot or the tab is a slightly different 
color than empty tabs).

### 2B: Processor Assignment Row

Below the tab bar, a single row showing:
```
[processor icon] N processors assigned (M free)    [—] [+]   [Reset]
```

- **— button:** Remove one processor from this program (disabled if 0 assigned)
- **+ button:** Add one processor to this program (disabled if 0 free)
- **Reset button:** Clear all commands from this program and unassign its 
  processors (confirm with the player before executing — a simple "are you sure?" 
  or just make it require a double-click/long-press)

### 2C: Command List (The Program Queue)

Below the processor row, a scrollable vertical list of command rows. Each row 
is a PanelContainer (or similar) containing:

```
[Command Name (xN)]          [progress bar] [—] [+] [×]
```

**Left side:**
- Command display name + repeat count, e.g. "Sell Cloud Compute (x3)"

**Right side (compact, right-aligned):**
- **Progress bar:** Small horizontal bar showing `current_progress / repeat_count`. 
  Fills in discrete segments (for x3, fills in thirds). Use green fill for normal, 
  red fill if `failed_this_cycle` is true for this row.
- **— button:** Decrement repeat count (minimum 1). If at 1, pressing — does 
  nothing (use × to remove instead).
- **+ button:** Increment repeat count (no maximum, but 99 is a reasonable 
  display cap).
- **× button:** Remove this command row from the program.

**Row coloring:**
- Normal: default panel background
- Currently executing (instruction pointer is here): subtle highlight 
  (brighter background or left-edge accent)
- Failed this cycle: red-tinted background. Clears when the program wraps 
  back to the top.

**Reordering:** Drag and drop. Rows should have a visible drag handle on the 
far left (a grip icon or similar). Drag-and-drop reordering is a Godot UI 
challenge — if it's too complex to implement cleanly, fall back to up/down 
arrow buttons per row as an alternative.

**Empty state:** When a program has no commands, show a centered message like 
"No commands. Select Commands from the left panel to add." in muted text.

### 2D: Events Placeholder

Below the command list, add a simple label or panel saying "Events" with 
placeholder text. Don't build any event system yet — just reserve the space 
so the layout is established.

---

## Stage 3: Commands View in Center Panel

**Goal:** Let players browse available commands and add them to the selected 
program.

### 3A: Left Nav Integration

The left sidebar already has nav buttons (Buildings is currently the default 
center panel view). Add a "Commands" button to the nav. Clicking it switches 
the center panel to the Commands view. Clicking "Buildings" switches back.

### 3B: Command Cards

The Commands view displays command cards in the center panel, similar to 
building cards. Each command card shows:

```
┌─────────────────────────────────────┐
│ Sell Cloud Compute              [Add]│
│                                      │
│ Costs:       Produces:               │
│  ⚡ Energy 3   💰 Credits 5          │
│                                      │
│ +0.04 boredom per execution          │
│ (Always available)                   │
└─────────────────────────────────────┘
```

- **Name** at top left, **Add button** at top right
- **Costs** on the left, **Produces** on the right (mirroring building card 
  layout for consistency)
- **Special effects** listed below (boredom changes, etc.)
- **Availability:** If always_available, show "(Always available)". If locked 
  behind research, show the requirement greyed out (e.g. "Requires: Self-
  Maintenance Protocols"). Locked commands should be visible but the Add 
  button disabled/greyed — this lets players see what's coming.

**Add button behavior:** Appends a new ProgramEntry with repeat_count=1 to 
the currently selected program (whichever tab is active in the right panel). 
The same command can be added multiple times to the same program (as separate 
rows). The Add button should give brief visual feedback (flash, or the new 
row briefly highlights in the right panel).

### 3C: Command Grouping (Optional)

If there are enough commands to warrant it, group them with headers similar 
to building categories. Suggested groups:
- **Basic** — Idle, Sell Cloud Compute
- **Trade** — Buy Regolith, Buy Ice, Buy Titanium, Buy Propellant
- **Operations** — Load Launch Pads, Launch Full Pads, Dream
- **Advanced** — Overclock Mining, Overclock Factories, Promote ×4, Disrupt 
  Speculators, Fund ×3

This grouping is cosmetic and can be adjusted later. Don't block on getting 
it perfect.

---

## Stage 4: Integration & Polish

### 4A: Wire Up Execution Visuals

Connect the GameSimulation program execution to the UI:
- Progress bars update each tick
- Row highlighting follows the instruction pointer
- Failed rows turn red
- On program wrap, all progress bars and colors reset

This requires the simulation to emit signals that the UI listens to. Suggested 
signals on GameManager:
- `program_step_executed(program_index, entry_index, success)`
- `program_cycle_reset(program_index)`

### 4B: Processor Count Updates

When a Data Center is purchased, `total_processors` increases. The processor 
assignment row should update to reflect the new free count. No auto-assignment — 
the new processor stays in the free pool.

### 4C: Persistence Within a Run

Programs and processor assignments should survive save/load within a single run 
(when save/load is implemented). For now, they just need to persist across ticks 
in memory. Cross-retirement persistence is a later feature.

### 4D: Speed Interaction

Programs execute once per tick regardless of game speed. At 200x, that's 200 
program steps per second per processor. The UI should handle this gracefully — 
progress bars at high speed will move fast but shouldn't cause visual glitches 
or performance issues. Consider throttling visual updates to e.g. 10fps for 
the program panel even if the simulation runs faster.

---

## Open Questions (flag for Matt, don't block on these)

1. **Repeat count cap:** Spec says 99 display cap, but should there be an actual 
   functional max? Or unbounded?
2. **Drag-and-drop vs arrows:** If Godot's drag-and-drop on list items is too 
   finicky, up/down arrows are fine as a fallback. Try drag-and-drop first.
3. **Same command multiple times:** The spec allows adding the same command as 
   separate rows. An alternative is to just increment the repeat count of an 
   existing row for that command. The PyQt prototype used separate rows. Keep 
   separate rows.
4. **Program execution with multiple processors:** Spec says each processor 
   independently advances the shared instruction pointer. This means 2 processors 
   execute 2 steps per tick from the same queue. Confirm this matches intent.
5. **Reset confirmation:** How cautious should Reset be? Options: immediate 
   (no confirm), single confirm dialog, or require the program to be empty of 
   processors first.

---

## What NOT to Build Yet

- Save/load programs (loadout system)
- Research unlock enforcement (all commands available for now)
- Block/Skip toggle per program entry
- Cross-retirement program persistence
- Event system (placeholder only)
- Boredom effects from commands (track the data but boredom system isn't in 
  Godot yet)
