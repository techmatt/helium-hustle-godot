# Building UI Rework — Card Grid Style

## Goal
Rework the Buildings center panel from a flat vertical list of full-width rows into 
a card-grid layout matching the PyQt reference implementation (see `screenshots/HHustle.png`).

This is a **UI-only change**. No game logic modifications. GameState, GameSimulation, 
and GameManager are untouched.

## Reference Screenshots
- **Target style**: `screenshots/HHustle.png` — PyQt prototype with card grid, category 
  headers, thumbnail images, colored affordability backgrounds.
- **Current style**: `screenshots/current_godot.png` (the dark flat-list layout currently 
  in the Godot build).

Study `screenshots/HHustle.png` carefully. Every visual detail described below comes 
from that image.

## What the Target Looks Like

### Card Layout
Each building is a **fixed-width card** (roughly 220–260px wide) containing:
1. **Header row**: Building name (left, bold) + count owned like "(1)" (right)
2. **Cost list**: Vertical list of resource costs. Each line has a small colored 
   circle/icon matching the resource color, the resource name, and the cost amount 
   right-aligned. Costs that the player cannot currently afford should be displayed 
   in **red text**; affordable costs in neutral/white text.
3. **Description**: Short italic or smaller text (the building's `description` field).
4. **Production lines**: Green text lines like "Produces:" followed by resource name 
   and "+X.X/s" amounts.
5. **Upkeep lines**: (if any) Red text lines showing resource consumption.
6. **Effects**: (if any) Listed below production, showing things like storage bonuses.
7. **Thumbnail image**: Square image on the left side of the card (the existing building 
   icons). If no image exists for a building, show a colored placeholder rectangle.
8. **Buy controls**: An "x" button (top-right corner) to remove/sell one building. 
   For buildings that have resource consumption (upkeep), also show "−" and "+" buttons 
   to disable/enable buildings.

### Card Background Color
- **Green-tinted** (`Color(0.2, 0.4, 0.2, 0.3)` or similar) when the player can afford 
  the next purchase.
- **Red/pink-tinted** (`Color(0.4, 0.2, 0.2, 0.3)` or similar) when the player cannot 
  afford it.
- Update this every frame or on resource change signals.

### Category Sections
Buildings are grouped by their `category` field from the JSON data. Each category gets:
- A **horizontal divider/header bar** spanning the full panel width.
- Category name **centered** in the bar.
- A **collapse triangle** (▼/▶) to show/hide that category's cards.
- Keep existing categories: Mining, Power, Storage, Processors (and any others in the data).

### Grid Flow
Cards within a category flow in an **HFlowContainer** or equivalent — they wrap to 
fill available width, showing 2–3 cards per row depending on panel width. Cards should 
have consistent spacing (8–12px gaps).

### Scrolling
The entire center panel should be a **ScrollContainer** so all categories and cards 
are scrollable when they exceed the viewport.

## Implementation Plan

### Step 1: Create the new BuildingCard scene
Create a new scene `godot/scenes/ui/BuildingCard.tscn` (or replace the existing building 
card scene). Structure:

```
PanelContainer (root — for the colored background)
  MarginContainer (padding)
    HBoxContainer (image left, info right)
      TextureRect (thumbnail, ~64x64, fixed size)
      VBoxContainer (all text content)
        HBoxContainer (name + count + buttons)
          Label (building name, bold)
          Label (count, right-aligned, e.g. "(3)")
          [spacer]
          Button ("x" — remove)
          Button ("−" — disable, only if building has upkeep)
          Button ("+" — enable, only if building has upkeep)
        Label (description, smaller/dimmer text)
        VBoxContainer (production lines — green colored)
        VBoxContainer (upkeep lines — red colored)  
        VBoxContainer (effects lines)
        HSeparator
        VBoxContainer (cost list with resource icons)
```

The exact node tree can vary — the key constraint is that it's a self-contained scene 
with a script that receives a building data dictionary and a reference to GameState, 
then renders itself.

### Step 2: Create the BuildingCard script
The script (`BuildingCard.gd`) should:
- Have a `setup(building_data: Dictionary, game_state)` method.
- Read building name, description, costs, production, upkeep, effects from the data dict.
- Display the cost list with per-resource lines (colored circle + name + amount).
- Show production in green, upkeep in red.
- Update `_process()` or connect to signals to:
  - Refresh affordability (card background color + individual cost text colors).
  - Update count owned display.
  - Enable/disable buy controls.
- Emit signals for buy/remove/enable/disable actions that the parent panel connects to GameManager.

### Step 3: Create the CategorySection scene
A simple collapsible container:
```
VBoxContainer (root)
  Button or HBoxContainer (header bar — clickable to toggle)
    Label ("▼ Mining" — updates triangle on collapse)
  HFlowContainer (holds BuildingCard instances)
```
When collapsed, hide the HFlowContainer. The header bar should have a distinct 
background color or style.

### Step 4: Rework the center panel
The center panel (whatever node currently holds the building list) becomes:
```
ScrollContainer
  VBoxContainer
    CategorySection ("Mining")
    CategorySection ("Power")
    CategorySection ("Storage")
    CategorySection ("Processors")
```
The script that currently populates the building list needs to:
1. Group buildings by category.
2. Create a CategorySection for each category.
3. Instantiate BuildingCard scenes for each building and add them to the appropriate 
   category's HFlowContainer.

### Step 5: Wire up interactions
- **Buy**: Clicking the card body (or a subtle buy area) calls `GameManager.buy_building(building_id)`.
- **Remove ("x")**: Calls `GameManager.remove_building(building_id)` (if this exists; 
  check current code).
- **Enable/Disable (+/−)**: Calls whatever mechanism currently exists for toggling buildings.
- All of these should already exist in GameManager from the current implementation — 
  just reconnect the signals.

### Step 6: Style pass
- Use the existing fonts: Rajdhani for headers, Exo 2 for body text.
- Resource color circles: use the same color mapping already in the game for the left 
  sidebar resource display.
- Card minimum size: roughly 220px wide, flexible height.
- Keep the dark theme consistent with the rest of the UI.

## Important Notes

- **Check the language**: The CLAUDE.md says C#, but the actual codebase appears to be 
  GDScript (.gd files). Look at the existing scripts to confirm before writing code. 
  Match whatever the existing code uses.
- **Don't break existing functionality**: The building purchase logic, cost scaling, 
  affordability checks, and resource display all already work. This is re-skinning, 
  not reimplementing.
- **Read existing code first**: Before creating new files, read the current building 
  card scene/script and the center panel scene to understand what signals and methods 
  already exist. Preserve the same API where possible.
- **Building data format**: Buildings are loaded from `data/generated/buildings.json`. 
  Each building has fields like: `name`, `shortname`, `description`, `category`, 
  `costs` (array of {resource, amount}), `production` (array), `upkeep` (array), 
  `effects` (array), `land_cost`, `scaling`. Check the actual JSON structure before 
  coding.
- **Test incrementally**: After creating the BuildingCard scene, test it with one 
  building before wiring up the full grid. Make sure affordability coloring updates 
  in real time.

## Out of Scope
- No changes to game logic, tick system, or GameManager.
- No changes to the left sidebar (resource list, speed controls, nav buttons).
- No changes to the right panel (programs, events).
- No new building images — use existing ones or colored placeholder rects.
- No building unlock/requirements enforcement (that's a separate task).
