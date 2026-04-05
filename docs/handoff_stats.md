# Helium Hustle — Stats & Telemetry

---

## Stats Panel

### Resource Breakdown (Instantaneous / Rolling Avg)
Per-resource cards showing production and consumption line items per source 
(buildings and commands). Toggle between Instantaneous and Rolling Average display. 
Includes stall indicators and boredom rate.

Command resource effects (boredom from Dream, credits from Sell Cloud Compute, 
resources from Buy commands, etc.) appear in the breakdown alongside building 
contributions. Source labels use program label format (e.g., "Program 1 (1 proc)").

### Overflow Display
For each resource with a non-zero overflow rolling average, a line item shows:
```
Overflow: -X.X/tick
```
Displayed with a distinct color to indicate waste. Only shown for resources with 
non-zero overflow — no "Overflow: 0" clutter.

### Lifetime Totals Section
Below the Resources section, a separate "Lifetime Totals" section (not affected 
by the Instantaneous / Rolling Avg toggle) shows two cards:

**Boredom (Lifetime)** — cumulative per-run totals by source (post-multiplier 
values for phase growth; flat per-execution values for command costs):
- Phase growth (all phases combined)
- Command boredom costs by display name (e.g., "Sell Cloud Compute", "Load Launch 
  Pads") — generic tracking, any command with non-zero boredom cost appears
- Dream (negative, per-command tracking)
- Net total

**Credits (Lifetime)** — cumulative per-run totals by source:
- Per-resource shipment revenue (He-3 shipments, Titanium shipments, etc.)
- Sell Cloud Compute revenue
- Building purchases (negative)
- Land purchases (negative)
- Net total

Only non-zero source lines are shown. Positive values prefixed with `+`, negative 
with `-`. Values displayed as integers. Both cards use resource color swatches 
matching existing stat cards.

GameState fields (transient, reset on retirement, not saved):
- `lifetime_boredom_sources: Dictionary` — source_key → float
- `lifetime_credit_sources: Dictionary` — source_key → float

---

## Playtest Telemetry

### Overview
PlaytestLogger autoload singleton. Writes JSONL log files to `<repo>/logs/` 
(one file per run: `run_N.jsonl`). Disabled when `GameManager.skip_save_load` 
is true (headless tests). `logs/` directory in `.gitignore`.

### Log Format
One JSON object per line: `{"tick": N, "type": "...", "data": {...}}`.

### Point Events
`run_start`, `building_purchased`, `building_sold`, `research_completed`, 
`quest_completed`, `event_triggered`, `achievement_earned`, `project_completed`, 
`shipment_launched` (includes `spec` count), `boredom_phase`, `land_purchased`, 
`ideology_rank_change`, `retirement`.

### Periodic Snapshots (every 100 ticks + on retirement/close)
Compact format with aggressive rounding (integers for most values, 1 decimal for 
rates/demand/costs). Resources as `[current, cap, rate]` tuples, omitting zero 
entries. Ideology as raw scores omitting zero axes. Speculators as `[count, target]`. 
Includes completed research ID list. Overflow data included for resources with 
non-zero overflow rolling averages. Lifetime boredom and credit source totals 
included when non-empty.

### File Lifecycle
Opens on `start_run()`, writes immediately (no buffering), finalizes with 
final snapshot on retirement or app close, then closes file handle.
