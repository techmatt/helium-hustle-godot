# Helium Hustle — MVP UI Skeleton

## Goal
Create the bare minimum Godot 4.x UI scene that establishes the game's layout. 
No game logic, no data loading, no tick system. Just panels, buttons, and labels 
that prove the layout works. Buttons should print their name to the console when 
clicked, nothing more.

## Reference
There is a PyQt prototype screenshot showing the target layout. The Godot version 
should follow the same general structure but does NOT need to match it exactly.

## Layout: Three Columns

```
+------------------+----------------------------------+----------------------+
|   LEFT SIDEBAR   |          CENTER PANEL            |    RIGHT PANEL       |
|                  |                                  |                      |
|  [Commands]      |  Buildings                       |  Programs            |
|  [Buildings]     |  +---------+ +---------+         |  [1] [2] [3] [4] [5]|
|  [Research]      |  | (empty) | | (empty) |         |                      |
|  [Projects]      |  +---------+ +---------+         |  (program editor     |
|  [Ideologies]    |                                  |   placeholder)       |
|  [Adversaries]   |                                  |                      |
|  [Stats]         |                                  |  Events              |
|  [Achievements]  |                                  |  (event log          |
|  [Options]       |                                  |   placeholder)       |
|  [Exit]          |                                  |                      |
|                  |                                  |                      |
|  Game Speed      |                                  |                      |
|  [||][1x][3x]... |                                  |                      |
|                  |                                  |                      |
|  Resources       |                                  |                      |
|  Energy: 0/0     |                                  |                      |
|  Credits: 0/0    |                                  |                      |
|  Regolith: 0/0   |                                  |                      |
|  (etc.)          |                                  |                      |
+------------------+----------------------------------+----------------------+
```

## What to Build

### Left Sidebar (fixed width ~220px)
1. **Nav buttons**: A vertical list of buttons with these labels: Commands, Buildings, 
   Research, Projects, Ideologies, Adversaries, Stats, Achievements, Options, Exit. 
   Each button prints its label to console on click. No icons needed yet.
2. **Game Speed row**: A horizontal row of buttons: ||, 1x, 3x, 10x, 50x, 200x. 
   Print the speed value on click. 1x should look "selected" by default (different 
   color or pressed state).
3. **Resource list**: Vertical list of labels, one per resource: Energy, Credits, 
   Regolith, Ice, Helium-3, Land, Boredom, Processors. Format: "Energy: 0 / 100  0.0/s". 
   Just static text for now, no live updates.

### Center Panel (flexible width, scrollable)
1. **Header**: Label saying "Buildings" at the top.
2. **Empty content area**: Just a placeholder Label saying "(No buildings yet)". 
   This will eventually hold building cards in a grid/flow layout.

### Right Panel (fixed width ~280px)
1. **Programs section**: 
   - Header label "Programs"
   - Row of 5 small buttons labeled 1-5 (program slots). Print slot number on click.
   - Placeholder text "(Program editor)"
2. **Events section**:
   - Header label "Events"  
   - Placeholder text "(No events)"

### Bottom Bar (optional, skip if easier)
- A thin status bar with "System uptime: 0 days" label. Skip if it complicates layout.

## Technical Notes
- Use Godot 4.x Control nodes. Build the layout in a .tscn scene file.
- Use a top-level HSplitContainer or HBoxContainer for the three-column layout, 
  with the center panel set to expand.
- Use Godot's built-in theme/styling. Don't spend time on custom themes yet. 
  A dark theme is fine.
- The scene should be the main scene (set in project settings).
- Put the scene at res://scenes/main_ui.tscn and the script at res://scripts/ui/main_ui.gd.
- Keep it simple. One scene, one script. We'll break it apart later.

## What NOT to Build
- No game logic, no tick system, no resource management
- No data loading from JSON
- No building cards or program editing
- No custom art or icons
- No save/load
