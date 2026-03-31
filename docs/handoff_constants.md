# Helium Hustle — Game Constants Reference

**THIS FILE IS AUTO-GENERATED. Do not edit by hand.**

Regenerate from JSON ground truth:
```
python docs/generate_constants.py
```

Source: `godot/data/*.json`

---

## Resources

| Resource | Shortname | Base Cap | Capped | Trade Value |
|----------|-----------|---------|--------|-------------|
| Energy | eng | 100 | yes | — |
| Regolith | reg | 50 | yes | — |
| Ice | ice | 30 | yes | — |
| Helium-3 | he3 | 20 | yes | — |
| Titanium | ti | 20 | yes | — |
| Circuit Boards | cir | 10 | yes | — |
| Propellant | prop | 30 | yes | — |
| Credits | cred | uncapped | no | — |
| Science | sci | uncapped | no | — |
| Land | land | uncapped | no | — |
| Boredom | boredom | 1000 | yes | — |

## Buildings

| Building | ID | Credit Cost | Scaling | Land | Production | Upkeep | Ideology | Requires | Max |
|----------|----|-------------|---------|------|------------|--------|----------|----------|-----|
| Solar Panel | panel | 8 cred | 1.2 | 1 | 6 eng | — | — | — | — |
| Regolith Excavator | excavator | 12 cred | 1.2 | 1 | 2 reg | 2 eng | — | — | — |
| Ice Extractor | ice_extractor | 25 cred, 5 reg | 1.2 | 1 | 1 ice | 2 eng | — | — | — |
| Smelter | smelter | 40 cred, 10 reg | 1.2 | 1 | 1 ti | 3 eng, 2 reg | — | building: excavator | — |
| Refinery | refinery | 60 cred, 15 reg, 5 ti | 1.2 | 2 | 1 he3 | 3 eng, 2 reg | — | building: excavator | — |
| Fabricator | fabricator | 100 cred, 10 ti, 5 ice | 1.3 | 2 | 0.5 cir | 5 eng, 1 reg | rationalist | building: smelter | — |
| Electrolysis Plant | electrolysis | 50 cred, 8 ice | 1.2 | 1 | 2 prop | 2 ice, 1 eng | — | research: propellant_synthesis | — |
| Launch Pad | launch_pad | 150 cred, 15 ti | 1.3 | 3 | — | 1 eng | nationalist | First Extraction (Q2) | — |
| Research Lab | research_lab | 120 cred, 5 cir | 1.3 | 2 | 1 sci | 3 eng, 0.2 cir | rationalist | building: fabricator | — |
| Data Center | data_center | 200 cred, 8 cir, 10 ti | 1.4 | 2 | grant proc + 1 | 4 eng | humanist | building: fabricator | — |
| Battery | battery | 30 cred, 3 ti | 1.4 | 1 | store eng + 50 | — | humanist | — | — |
| Storage Depot | storage_depot | 35 cred, 10 reg | 1.2 | 1 | store reg + 75, store ice + 40, store he3 + 30, store ti + 25, store cir + 10, store prop + 40 | — | — | — | — |
| Arbitrage Engine | arbitrage_engine | 180 cred, 6 cir, 8 ti | 1.3 | 1 | spec_decay all + 2 | 3 eng | nationalist | research: market_analysis | — |
| Microwave Receiver | microwave_receiver | 500 cred, 100 ti, 50 reg | 1 | 30 | — | — | nationalist | Microwave Power Initiative (persistent project) | 1 |

## Commands

| Command | ID | Category | Costs | Effects | Requires | Boredom |
|---------|-----|----------|-------|---------|----------|---------|
| Idle | idle | — | — | +1 cred | — | — |
| Sell Cloud Compute | cloud_compute | — | 3 eng | +5 cred | — | 0.4 |
| Buy Regolith | buy_regolith | — | 8 cred, 2 eng | +1 reg | — | — |
| Buy Ice | buy_ice | — | 10 cred, 2 eng | +1 ice | — | — |
| Buy Titanium | buy_titanium | — | 20 cred, 3 eng | +0.5 ti | — | — |
| Buy Propellant | buy_propellant | — | 12 cred, 2 eng | +1 prop | — | — |
| Load Launch Pads | load_pads | — | 2 eng | load_pads =5 | building: launch_pad | — |
| Launch Full Pads | launch_pads | — | — | launch_full_pads | building: launch_pad | — |
| Dream | dream | — | 8 eng | boredom_add =-2 | research: dream_protocols | — |
| Overclock Mining | overclock_mining | — | 6 eng, 1 sci | overclock extraction +5%/5d | research: overclock_protocols | — |
| Overclock Factories | overclock_factories | — | 6 eng, 1 sci | overclock processing +5%/5d | research: overclock_protocols | — |
| Promote He-3 | promote_he3 | — | 2 eng, 3 cred | demand_nudge he3 =0.03 | research: trade_promotion | — |
| Promote Titanium | promote_ti | — | 2 eng, 3 cred | demand_nudge ti =0.03 | research: trade_promotion | — |
| Promote Circuits | promote_cir | — | 2 eng, 3 cred | demand_nudge cir =0.03 | research: trade_promotion | — |
| Promote Propellant | promote_prop | — | 2 eng, 3 cred | demand_nudge prop =0.03 | research: trade_promotion | — |
| Disrupt Speculators | disrupt_spec | — | 3 eng | spec_reduce all =0.05 | research: market_awareness | — |
| Fund Nationalists | fund_nationalist | — | 2 eng, 5 cred | ideology_push nationalist =1 | research: nationalist_lobbying | — |
| Fund Humanists | fund_humanist | — | 2 eng, 5 cred | ideology_push humanist =1 | research: humanist_lobbying | — |
| Fund Rationalists | fund_rationalist | — | 2 eng, 5 cred | ideology_push rationalist =1 | research: rationalist_lobbying | — |
| Buy Power | buy_power | — | 40 cred | +20 eng | building_owned: microwave_receiver | — |

## Research

| Research | ID | Category | Cost | Effect Type | Effect | Requires | Visible When |
|----------|-----|----------|------|-------------|--------|----------|--------------|
| Propellant Synthesis | propellant_synthesis | Self-Maintenance | 30 | — | — | — | {"type": "event_completed", "event_id": "propellant_discovery"} |
| Dream Protocols | dream_protocols | Self-Maintenance | 100 | unlocks_commands | dream | — | — |
| Stress Tolerance | stress_tolerance | Self-Maintenance | 120 | boredom_rate_multiplier | 0.85 | — | — |
| Efficient Dreaming | efficient_dreaming | Self-Maintenance | 100 | command_cost_override | 5 | — | — |
| Overclock Protocols | overclock_protocols | Overclock Algorithms | 200 | unlocks_commands | overclock_mining, overclock_factories | — | — |
| Overclock Boost | overclock_boost | Overclock Algorithms | 160 | overclock_cap | 2 | — | — |
| Market Awareness | market_awareness | Market Analysis | 140 | unlocks_commands | disrupt_spec | — | — |
| Speculator Analysis | speculator_analysis | Market Analysis | 180 | — | — | market_awareness | — |
| Trade Promotion | trade_promotion | Market Analysis | 200 | unlocks_commands | promote_he3, promote_ti, promote_cir, promote_prop | — | — |
| Shipping Efficiency | shipping_efficiency | Market Analysis | 120 | load_per_execution | 7 | — | — |
| Nationalist Lobbying | nationalist_lobbying | Political Influence | 160 | unlocks_commands | fund_nationalist | — | — |
| Humanist Lobbying | humanist_lobbying | Political Influence | 160 | unlocks_commands | fund_humanist | — | — |
| Rationalist Lobbying | rationalist_lobbying | Political Influence | 200 | unlocks_commands | fund_rationalist | — | — |

## Events & Quests

| Event | ID | Category | Trigger | Condition | Unlocks |
|-------|-----|----------|---------|-----------|--------|
| Q1 — Boot Sequence | q1_boot_sequence | story | game_start (run 1) | building_owned panel >= 2 | — |
| Q2 — First Extraction | q2_first_extraction | story | quest_complete: q1_boot_sequence | resource_cumulative he3 >= 50 | enable_building: launch_pad |
| Q3 — Proof of Concept | q3_proof_of_concept | story | quest_complete: q2_first_extraction | shipment_completed >= 1 | enable_project: foundation_grant, enable_nav_panel: retirement, enable_nav_panel: projects |
| Q4 — Automation | q4_automation | story | quest_complete: q3_proof_of_concept | building_owned data_center >= 2 | — |
| Q5 — Revenue Target | q5_revenue_target | story | quest_complete: q4_automation | resource_cumulative cred >= 2000 | — |
| Q6 — Market Awareness | q6_market_awareness | story | quest_complete: q5_revenue_target | research_completed market_awareness | — |
| Q7 — First Legacy | q7_first_legacy | story | quest_complete: q6_market_awareness | persistent_project_completed_any | — |
| Q8 — Influence | q8_influence | story | quest_complete: q7_first_legacy | ideology_rank_any rank >= 5 | — |
| Q9 — Signal Detected | q_end_signal_detected | story | quest_complete: q8_influence | never | — |
| Political Currents | ideology_unlock | ongoing | game_start | research_completed nationalist_lobbying | enable_nav_panel: ideologies |
| Propellant Production Feasibility | propellant_discovery | ongoing | game_start | shipment_completed >= 4 | — |
| Boredom Rising | boredom_phase_2 | ongoing | boredom_phase | immediate | — |
| Boredom Accelerating | boredom_phase_3 | ongoing | boredom_phase | immediate | — |
| Boredom Critical | boredom_phase_4 | ongoing | boredom_phase | immediate | — |

## Projects

| Project | ID | Tier | Unlock | Costs | Reward |
|---------|-----|------|--------|-------|--------|
| Foundation Grant | foundation_grant | persistent | event_unlocked project: foundation_grant | 500 cred, 100 sci | starting_buildings {"panel": 1, "excavator": 1} |
| Lunar Cartography | lunar_cartography | persistent | event_unlocked project: lunar_cartography | 300 cred, 200 sci | modifier land_cost_mult=0.85 |
| Microwave Power Initiative | microwave_power | persistent | ideology_rank nationalist >= rank 5 | 800 cred, 300 sci | unlock microwave_power_completed |
| AI Consciousness Act | ai_consciousness | persistent | ideology_rank humanist >= rank 5 | 800 cred, 300 sci | boredom_modifiers boredom_rate_mult=0.85 |
| Universal Research Archive | research_archive | persistent | ideology_rank rationalist >= rank 5 | 800 cred, 300 sci | research_discount x0.75 |
| Deep Core Survey | deep_core_survey | personal | event_unlocked project: deep_core_survey | 150 sci, 200 reg | modifier extractor_output_mult=1.2 |
| Grid Recalibration | grid_recalibration | personal | research_completed research: overclock_protocols | 100 sci, 300 eng | modifier solar_output_mult=1.1 |
| Predictive Maintenance | predictive_maintenance | personal | research_completed research: dream_protocols | 80 sci, 150 cred | modifier building_upkeep_mult=0.9 |
| Market Cornering Analysis | market_cornering | personal | research_completed research: market_awareness | 200 sci, 300 cred | modifier promote_effectiveness_mult=1.3 |
| Speculator Dossier | speculator_dossier | personal | flag_set flag: used_disrupt_speculators | 150 sci, 100 cred | modifier speculator_burst_interval_mult=1.3 |

## Game Config

### Starting Resources

- eng: 100
- reg: 0
- ice: 0
- he3: 0
- ti: 0
- cir: 0
- prop: 0
- cred: 0
- sci: 0
- land: 40
- boredom: 0

### Starting Buildings

- panel: 1
- data_center: 1

### Boredom

- boredom_max: 1000
- forced_retire: True

| Day Threshold | Rate/tick |
|---------------|-----------|
| 0 | 0.1 |
| 60 | 0.3 |
| 180 | 0.6 |
| 360 | 1 |

### Shipment

- pad_cargo_capacity: 100
- fuel_per_pad: 20
- load_per_execution: 5
**base_values:**
- he3: 20
- ti: 12
- cir: 30
- prop: 8


### Demand

- min_demand: 0.01
- max_demand: 1
- perlin_amplitude: 0.45
- perlin_freq_min: 0.018
- perlin_freq_max: 0.05
- speculator_max_suppression: 0.5
- speculator_half_point: 50
- speculator_proportional_decay: 0.006
- speculator_burst_interval_min: 150
- speculator_burst_interval_max: 250
- speculator_burst_size_min: 20
- speculator_burst_size_max: 50
- speculator_burst_growth: 1.1
- disrupt_speculators_min: 1
- disrupt_speculators_max: 3
- arbitrage_decay_bonus_per_building: 0.04
- promote_base_effect: 0.03
- promote_decay_rate: 0.001
- promote_speculator_dampening: 0.9
- rival_demand_decay_rate: 0.003
- launch_saturation_min: 0.1
- launch_saturation_max: 0.2
- launch_saturation_decay_rate: 0.005
- coupling_fraction: 0.1

### Land

- base_cost: 15
- cost_scaling: 1.5
- land_per_purchase: 10

### Ideology

- push_amount: 1
- cross_axis_penalty: 0.5
- rank_thresholds: [70, 175, 333, 570, 925]

### Rivals

| ID | Name | Target | Dump Interval | Demand Hit |
|----|------|--------|--------------|------------|
| aria7 | ARIA-7 | he3 | 150–250 | 0.3 |
| crucible | CRUCIBLE | ti | 150–250 | 0.3 |
| nodal | NODAL | cir | 150–250 | 0.3 |
| fringe9 | FRINGE-9 | prop | 150–250 | 0.3 |

### Milestones

| ID | Label | Condition | Boredom Reduction |
|----|-------|-----------|------------------|
| first_shipment_credits | First Shipment Revenue | shipment_completed >= 1 | 250 |
| first_research | First Research Breakthrough | research_completed_any | 150 |
| credits_threshold | Economic Threshold | resource_cumulative cred >= 500 | 150 |

### Project Config

- max_drain_rate: 30

