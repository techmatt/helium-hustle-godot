# Helium Hustle — Economy & Trade

For exact numbers (costs, rates, thresholds), see `handoff_constants.md`.

---

## Resource Flow — Arc 1 Economy

### Raw Extraction (both consume energy)
- Regolith Excavator — energy → regolith
- Ice Extractor — energy → ice

### Processing (each has one clear purpose)
- Refinery — regolith + energy → He-3
- Smelter — regolith + energy → titanium
- Fabricator — regolith + energy (lots) → circuit boards
- Electrolysis Plant — ice + energy → propellant (requires research unlock)

### Power Generation
- Solar Panel — produces energy (no upkeep)
- Battery — increases energy storage cap (no production/upkeep)
- Microwave Receiver — produces energy (no upkeep, unlocked by Microwave Power 
  Initiative persistent project)
- Fuel Cell Array — propellant → energy (unlocked by Chemical Energy Initiative 
  persistent project)

### Dependency Structure
Two independent extraction chains (regolith and ice) feed into four processing 
paths, all competing for energy. Regolith feeds three competing uses (He-3, 
titanium, circuits). Ice feeds propellant. Energy is the universal bottleneck. 
Fuel Cell Array creates a feedback loop: propellant can be converted back to 
energy, creating tension between fuel-for-launches vs fuel-for-power.

### Tradeable Goods (4 types)
He-3 (core product, demand-sensitive), Titanium (mid-tier, demand spikes), Circuit 
Boards (late Arc 1, energy-hungry, highest value/unit), Propellant (dual purpose — 
trade good + launch fuel).

### Additional Resources
- Science — produced by Research Lab, spent on research. Rationalist ideology 
  boosts production via `pow(1.05, rank)`.
- Land — purchasable with escalating cost. Base 15 credits, 1.5x scaling, 10 land 
  per purchase. Affected by `land_cost_mult` modifier and Nationalist 
  `pow(0.97, rank)`.
- Credits — earned via trade and Sell Cloud Compute. Uncapped.

### Storage & Caps
Capped resources: Energy, Regolith, Ice, He-3, Titanium, Circuit Boards, 
Propellant. Uncapped: Credits, Science, Land, Boredom (fixed 0–1000 range). 
Battery adds energy cap. Storage Depot adds cap bonuses for physical resources. 
The `storage_cap_mult` achievement modifier (from Silicon Valley) multiplies caps 
for all capped physical resources except Energy. See `handoff_constants.md` for 
exact cap values.

### Resource Display Names
All player-facing resource names come from the `display_name` field in 
`resources.json`. UI code uses `get_resource_display_name(resource_id)` helper 
rather than hardcoding. Internal IDs (e.g., `circuits`) are for code; display 
names (e.g., "Circuit Boards") are for player-facing text.

### Resource Visibility (Progressive Disclosure)
Always visible at game start: Boredom, Energy, Processors, Land, Credits, 
Titanium, Regolith. Other resources become visible when the player owns the 
building that produces them (this run) or has ever owned it (any prior run, 
tracked via `career_state.lifetime_owned_building_ids`). Ice → Ice Extractor, 
He-3 → Refinery, Circuit Boards → Fabricator, Propellant → Electrolysis Plant, 
Science → Research Lab. Storage Depot filters displayed storage bonuses to only 
visible resources.

Resource visibility uses lifetime tracking (unlike nav buttons and event-gated 
buildings). Hiding resources the player already knows about would be confusing.

---

## Shipment & Trade Economy

### Mechanics
- One resource per launch pad. Load Launch Pads command costs 2 energy, loads 5 
  units (7 with Shipping Efficiency research) per enabled pad. The 
  `cargo_capacity_mult` achievement modifier (from Bulk Shipper) multiplies cargo 
  loaded per execution.
  Launch Full Pads launches all full active pads, each costing 20 propellant.
- Payout: `base_value × demand × cargo_loaded × shipment_credit_mult`. The 
  `shipment_credit_mult` modifier defaults to 1.0, increased by the First Profit 
  achievement.
- 10-tick cooldown after launch.
- Loading priority: reorderable list of 4 tradeable goods.

### Launch Pad Pause Toggle
Each launch pad has a pause toggle button (between the resource dropdown and the 
Launch button). When paused:
- Load Launch Pads commands skip this pad (do not load cargo)
- Launch Full Pads commands skip this pad (do not launch, even if full)
- Manual "Launch" button still works (player can manually launch a paused pad)
- Pad row background is tinted light yellow to indicate intentional pause 
  (dark mode: muted dark yellow/olive tint)
- Pad retains its resource selection and any cargo already loaded
- Cargo already loaded stays — pausing does not dump cargo

The "None (disabled)" dropdown option has been removed. The dropdown only contains 
the four tradeable resources. Pause state is a boolean per pad, serialized in 
save/load, reset to false on retirement.

### Propellant Economy (Early Game)
At average demand (0.5), a full He-3 launch earns ~1,000 credits. Buying 20 
propellant costs 240 credits + 40 energy (24% of revenue). Painful enough to make 
Electrolysis unlock feel meaningful, but not so painful that launching is 
unprofitable.
