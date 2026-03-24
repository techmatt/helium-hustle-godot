#!/usr/bin/env python3
"""
Helium Hustle — Arc 1 Economic Tick Simulator

Traces a reference first-run build order through ~2000 ticks, tracking all
resources, boredom, milestones, and storage caps. Outputs milestone timing,
resource curves, and a summary report.

All parameters are tunable at the top of the file. The goal is to validate
that milestone targets (M1-M4 for run 1) land in expected tick windows,
and that the economy "feels right" — tight enough to require decisions,
loose enough to not frustrate.

Usage:
    python hh_sim.py                  # Run sim, print report, save charts
    python hh_sim.py --no-charts      # Print report only
"""

import argparse
import math
from dataclasses import dataclass, field
from typing import Optional
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

# ============================================================================
# BUILDING DEFINITIONS
# ============================================================================

@dataclass
class BuildingDef:
    name: str
    base_cost_credits: float
    base_cost_resources: dict  # resource_name -> amount
    cost_scaling: float        # multiplicative per owned
    land_cost: float           # land consumed per building
    production: dict           # resource_name -> amount per tick
    upkeep: dict               # resource_name -> amount per tick
    energy_production: float = 0.0
    energy_upkeep: float = 0.0
    # Storage effects
    energy_cap_bonus: float = 0.0
    storage_cap_bonus: dict = field(default_factory=dict)  # resource -> bonus
    # Special flags
    starts_with: int = 0       # how many the player begins with

BUILDINGS = {
    "solar_panel": BuildingDef(
        name="Solar Panel",
        base_cost_credits=10, base_cost_resources={}, cost_scaling=1.15,
        land_cost=1,
        production={}, upkeep={},
        energy_production=4.0, energy_upkeep=0.0,
        starts_with=1,
    ),
    "battery": BuildingDef(
        name="Battery",
        base_cost_credits=15, base_cost_resources={}, cost_scaling=1.35,
        land_cost=0,
        production={}, upkeep={},
        energy_cap_bonus=40.0,
        starts_with=1,
    ),
    "storage_depot": BuildingDef(
        name="Storage Depot",
        base_cost_credits=20, base_cost_resources={}, cost_scaling=1.25,
        land_cost=1,
        production={}, upkeep={},
        storage_cap_bonus={
            "regolith": 50, "ice": 40, "he3": 30,
            "titanium": 30, "circuits": 20, "propellant": 40,
        },
    ),
    "regolith_excavator": BuildingDef(
        name="Regolith Excavator",
        base_cost_credits=25, base_cost_resources={}, cost_scaling=1.20,
        land_cost=1,
        production={"regolith": 1.5}, upkeep={},
        energy_upkeep=1.5,
    ),
    "ice_extractor": BuildingDef(
        name="Ice Extractor",
        base_cost_credits=30, base_cost_resources={}, cost_scaling=1.20,
        land_cost=1,
        production={"ice": 1.0}, upkeep={},
        energy_upkeep=1.5,
    ),
    "refinery": BuildingDef(
        name="Refinery",
        base_cost_credits=50, base_cost_resources={"regolith": 30}, cost_scaling=1.25,
        land_cost=1,
        production={"he3": 1.0}, upkeep={"regolith": 1.0},
        energy_upkeep=2.0,
    ),
    "smelter": BuildingDef(
        name="Smelter",
        base_cost_credits=60, base_cost_resources={"regolith": 40}, cost_scaling=1.25,
        land_cost=1,
        production={"titanium": 0.8}, upkeep={"regolith": 0.8},
        energy_upkeep=2.0,
    ),
    "fabricator": BuildingDef(
        name="Fabricator",
        base_cost_credits=100, base_cost_resources={"titanium": 20}, cost_scaling=1.30,
        land_cost=1,
        production={"circuits": 0.5}, upkeep={"regolith": 0.5},
        energy_upkeep=3.0,
    ),
    "electrolysis_plant": BuildingDef(
        name="Electrolysis Plant",
        base_cost_credits=45, base_cost_resources={"ice": 20}, cost_scaling=1.25,
        land_cost=1,
        production={"propellant": 1.0}, upkeep={"ice": 0.8},
        energy_production=1.5, energy_upkeep=2.5,  # net -1.0 energy but produces propellant
    ),
    "data_center": BuildingDef(
        name="Data Center",
        base_cost_credits=80, base_cost_resources={"circuits": 5}, cost_scaling=1.40,
        land_cost=2,
        production={}, upkeep={},
        energy_upkeep=2.0,
        # Grants 1 processor (handled in sim logic, not as resource production)
    ),
    "research_lab": BuildingDef(
        name="Research Lab",
        base_cost_credits=70, base_cost_resources={"circuits": 3}, cost_scaling=1.30,
        land_cost=1,
        production={"science": 1.0}, upkeep={"circuits": 0.1},
        energy_upkeep=1.5,
    ),
    "launch_pad": BuildingDef(
        name="Launch Pad",
        base_cost_credits=60, base_cost_resources={"regolith": 30}, cost_scaling=1.25,
        land_cost=2,
        production={}, upkeep={},
        energy_upkeep=0.5,
    ),
    "arbitrage_engine": BuildingDef(
        name="Arbitrage Engine",
        base_cost_credits=90, base_cost_resources={"circuits": 8}, cost_scaling=1.35,
        land_cost=1,
        production={}, upkeep={},
        energy_upkeep=1.5,
    ),
    "comms_tower": BuildingDef(
        name="Comms Tower",
        base_cost_credits=15, base_cost_resources={}, cost_scaling=1.50,
        land_cost=1,
        production={}, upkeep={},
        energy_upkeep=0.5,
        starts_with=1,
    ),
}

# ============================================================================
# RESOURCE & STORAGE DEFINITIONS
# ============================================================================

# Base storage caps (before any depots/batteries)
BASE_CAPS = {
    "energy":     50.0,    # 1 battery included at start adds to this
    "regolith":  100.0,
    "ice":        80.0,
    "he3":        50.0,
    "titanium":   50.0,
    "circuits":   30.0,
    "propellant": 60.0,
}

# Resources with no cap
UNCAPPED = {"credits", "science", "boredom", "land"}

# Starting resources
STARTING_RESOURCES = {
    "energy": 30.0,
    "regolith": 0.0,
    "ice": 0.0,
    "he3": 0.0,
    "titanium": 0.0,
    "circuits": 0.0,
    "propellant": 0.0,
    "credits": 50.0,
    "science": 0.0,
    "boredom": 0.0,
    "land": 5.0,    # starting land (some buildings pre-placed)
}

# ============================================================================
# LAND SYSTEM
# ============================================================================

LAND_BASE_COST = 10.0
LAND_COST_SCALING = 1.20  # per land unit already purchased
LAND_STARTING_PURCHASED = 12  # gives starting land of 12, minus starting buildings = free

# ============================================================================
# BOREDOM CURVE
# ============================================================================

# 3 phases, targeting ~900 ticks to 100 boredom with no mitigation
BOREDOM_PHASES = [
    # (start_tick, end_tick, rate_per_tick)
    (0,   350, 0.03),   # phase 1: gentle, 10.5 boredom over 350 ticks
    (350, 750, 0.08),   # phase 2: noticeable, 32 boredom over 400 ticks
    (750, 9999, 0.24),  # phase 3: urgent, 57.5 boredom over ~240 ticks → 100 at ~tick 990
]

# ============================================================================
# SHIPMENT / TRADE PARAMETERS
# ============================================================================

LAUNCH_FUEL_COST = 20.0          # propellant per pad launched
PAD_CARGO_CAPACITY = 100.0
PAD_LOAD_PER_COMMAND = 5.0       # units loaded per Load command execution

# Base values per unit shipped (credits)
TRADE_BASE_VALUES = {
    "he3": 3.0,
    "titanium": 2.5,
    "circuits": 5.0,
    "propellant": 1.5,
}

DEMAND_BASELINE = 0.5

# ============================================================================
# COMMAND COSTS (energy cost per execution)
# ============================================================================

COMMAND_ENERGY_COST = {
    "sell_cloud_compute": 2.0,
    "dream": 4.0,
    "load_pads": 1.0,
    "launch_full": 0.0,  # propellant cost, not energy
    "overclock_mining": 2.0,
    "overclock_factories": 2.0,
    "idle": 0.0,
}

SELL_CLOUD_COMPUTE_CREDITS = 5.0
SELL_CLOUD_COMPUTE_BOREDOM = 0.04
DREAM_BOREDOM_REDUCTION = 0.5

# ============================================================================
# SIMULATION STATE
# ============================================================================

@dataclass
class SimState:
    tick: int = 0
    resources: dict = field(default_factory=dict)
    buildings: dict = field(default_factory=dict)  # building_key -> count
    land_purchased: int = 0
    milestones: dict = field(default_factory=dict)  # milestone_name -> tick achieved
    history: list = field(default_factory=list)
    events: list = field(default_factory=list)
    # Shipment tracking
    pads_assigned: dict = field(default_factory=dict)   # pad_index -> resource
    pads_cargo: dict = field(default_factory=dict)       # pad_index -> float
    total_credits_earned: float = 0.0
    total_shipped: dict = field(default_factory=dict)
    # Program state (simplified — just track what commands run per tick)
    has_program: bool = False
    program_ticks: int = 0

    def __post_init__(self):
        if not self.resources:
            self.resources = dict(STARTING_RESOURCES)
        if not self.buildings:
            self.buildings = {k: v.starts_with for k, v in BUILDINGS.items()}

    def get_cap(self, resource: str) -> Optional[float]:
        if resource in UNCAPPED:
            return None
        cap = BASE_CAPS.get(resource, None)
        if cap is None:
            return None
        # Add battery bonuses for energy
        if resource == "energy":
            cap += self.buildings.get("battery", 0) * BUILDINGS["battery"].energy_cap_bonus
        else:
            # Add storage depot bonuses
            depot_count = self.buildings.get("storage_depot", 0)
            depot_bonus = BUILDINGS["storage_depot"].storage_cap_bonus.get(resource, 0)
            cap += depot_count * depot_bonus
        return cap

    def clamp_resources(self):
        for res in list(self.resources.keys()):
            cap = self.get_cap(res)
            if cap is not None:
                self.resources[res] = min(self.resources[res], cap)
            # Never go below 0 (except boredom can't go below 0)
            if res != "boredom":
                self.resources[res] = max(0, self.resources[res])
            else:
                self.resources[res] = max(0, self.resources[res])

    def get_building_cost(self, key: str) -> dict:
        """Returns {credits: X, resource1: Y, ...} for next copy."""
        bdef = BUILDINGS[key]
        count = self.buildings.get(key, 0)
        scale = bdef.cost_scaling ** count
        costs = {"credits": bdef.base_cost_credits * scale}
        for res, amt in bdef.base_cost_resources.items():
            costs[res] = amt * scale
        costs["_land"] = bdef.land_cost
        return costs

    def can_afford(self, key: str) -> bool:
        costs = self.get_building_cost(key)
        if costs.get("_land", 0) > self.resources.get("land", 0):
            return False
        for res, amt in costs.items():
            if res == "_land":
                continue
            if self.resources.get(res, 0) < amt:
                return False
        # Check if resource produced would be within cap (not blocking purchase)
        return True

    def buy_building(self, key: str) -> bool:
        if not self.can_afford(key):
            return False
        costs = self.get_building_cost(key)
        for res, amt in costs.items():
            if res == "_land":
                self.resources["land"] -= amt
            else:
                self.resources[res] -= amt
        self.buildings[key] = self.buildings.get(key, 0) + 1
        return True

    def buy_land(self) -> bool:
        cost = LAND_BASE_COST * (LAND_COST_SCALING ** self.land_purchased)
        if self.resources["credits"] >= cost:
            self.resources["credits"] -= cost
            self.resources["land"] += 1
            self.land_purchased += 1
            return True
        return False

    def get_net_energy(self) -> float:
        prod = 0.0
        upkeep = 0.0
        for key, count in self.buildings.items():
            if count <= 0:
                continue
            bdef = BUILDINGS[key]
            prod += bdef.energy_production * count
            upkeep += bdef.energy_upkeep * count
        return prod - upkeep

    def get_energy_production(self) -> float:
        prod = 0.0
        for key, count in self.buildings.items():
            if count <= 0:
                continue
            prod += BUILDINGS[key].energy_production * count
        return prod

    def get_energy_upkeep(self) -> float:
        upkeep = 0.0
        for key, count in self.buildings.items():
            if count <= 0:
                continue
            upkeep += BUILDINGS[key].energy_upkeep * count
        return upkeep

    def num_processors(self) -> int:
        return self.buildings.get("data_center", 0)

    def num_pads(self) -> int:
        return self.buildings.get("launch_pad", 0)


# ============================================================================
# BOREDOM TICK
# ============================================================================

def get_boredom_rate(tick: int) -> float:
    for start, end, rate in BOREDOM_PHASES:
        if start <= tick < end:
            return rate
    return BOREDOM_PHASES[-1][2]


# ============================================================================
# REFERENCE BUILD ORDER (first run, competent player)
# ============================================================================
# Format: (tick_target, action_type, action_arg)
# The sim tries to execute each action as soon as affordable AT or AFTER the
# target tick. This models a player who knows roughly what to do but has to
# wait for resources.

REFERENCE_BUILD_ORDER = [
    # Early game: get energy stable, start mining
    (1,    "build", "solar_panel"),        # 2nd solar panel
    (25,   "build", "regolith_excavator"), # start mining
    (40,   "build", "solar_panel"),        # 3rd solar panel
    (55,   "build", "regolith_excavator"), # 2nd excavator
    (70,   "build", "solar_panel"),        # 4th solar panel - energy headroom
    (85,   "build", "storage_depot"),      # expand storage before refinery
    (100,  "build", "refinery"),           # start He-3 processing
    (110,  "buy_land", None),
    (115,  "buy_land", None),
    (130,  "build", "ice_extractor"),      # start ice chain
    (150,  "build", "solar_panel"),        # 5th solar panel
    (165,  "build", "electrolysis_plant"), # propellant + some energy back
    (180,  "build", "storage_depot"),      # 2nd depot for He-3 cap
    (200,  "buy_land", None),
    (210,  "buy_land", None),
    (220,  "build", "launch_pad"),         # first pad! (unlocked by quest Q2)
    (240,  "build", "battery"),            # 2nd battery - energy cap relief
    (260,  "build", "solar_panel"),        # 6th solar panel
    # Mid game: trade running, start programs
    (280,  "buy_land", None),
    (290,  "build", "smelter"),            # titanium for diversification
    (310,  "build", "regolith_excavator"), # 3rd excavator to feed smelter+refinery
    (330,  "buy_land", None),
    (340,  "buy_land", None),
    (350,  "build", "fabricator"),         # circuits (expensive energy)
    (370,  "build", "solar_panel"),        # 7th - energy getting tight
    (390,  "build", "data_center"),        # first processor!
    (410,  "build", "research_lab"),       # start science
    (430,  "buy_land", None),
    (440,  "build", "launch_pad"),         # 2nd pad
    (460,  "build", "storage_depot"),      # 3rd depot
    (480,  "build", "battery"),            # 3rd battery
    (500,  "build", "solar_panel"),        # 8th solar panel
    (530,  "buy_land", None),
    (550,  "build", "research_lab"),       # 2nd lab
    (580,  "build", "regolith_excavator"), # 4th excavator
    (610,  "buy_land", None),
    (620,  "buy_land", None),
    (640,  "build", "launch_pad"),         # 3rd pad
    (670,  "build", "ice_extractor"),      # 2nd ice extractor
    (700,  "build", "solar_panel"),        # 9th solar panel
    (730,  "buy_land", None),
    (750,  "build", "battery"),            # 4th battery
    (780,  "build", "storage_depot"),      # 4th depot
]

# ============================================================================
# PROGRAM BEHAVIOR (simplified model)
# ============================================================================
# After data center is built, simulate a simple program:
# - Sell Cloud Compute x2, Load Pads x2, Dream x1 (5-command loop)
# Each processor runs one command per tick.

def run_programs(state: SimState):
    """Simplified program execution for the reference trajectory."""
    n_proc = state.num_processors()
    if n_proc == 0:
        return

    if not state.has_program:
        state.has_program = True

    # Simple model: each tick, each processor runs one command from a
    # rotating program. We model the NET effect per tick across all processors.
    # Program: (Sell Cloud Compute x2, Load Pads x2, Dream x1)
    # With 1 processor, cycle is 5 ticks. With 2, effectively 2 commands/tick.

    # Per tick, average effect of the program per processor:
    # 2/5 chance: Sell Cloud Compute (energy cost, +credits, +boredom)
    # 2/5 chance: Load Pads (energy cost, loads cargo)
    # 1/5 chance: Dream (energy cost, -boredom)

    for _ in range(n_proc):
        # Deterministic average per tick per processor:
        # Sell Cloud Compute: 2/5 * 5 credits = 2.0 credits, 2/5 * 0.04 boredom = 0.016
        # Load Pads: 2/5 * load effect
        # Dream: 1/5 * -0.5 boredom = -0.1
        # Energy: 2/5 * 2 + 2/5 * 1 + 1/5 * 4 = 0.8 + 0.4 + 0.8 = 2.0
        # Net boredom per processor per tick: 0.016 - 0.1 = -0.084

        energy_cost = 2.0  # average per processor per tick
        if state.resources["energy"] >= energy_cost:
            state.resources["energy"] -= energy_cost
            # Credits from cloud compute
            state.resources["credits"] += 2.0
            state.total_credits_earned += 2.0
            # Boredom: +0.016 from cloud, -0.10 from dream = -0.084 net
            state.resources["boredom"] -= 0.084
            # Load pads: 2/5 * 5 units = 2 units per tick per processor
            load_amount = 2.0
            n_pads = state.num_pads()
            if n_pads > 0:
                per_pad = load_amount / n_pads
                for i in range(n_pads):
                    res = state.pads_assigned.get(i, "he3")
                    avail = state.resources.get(res, 0)
                    loaded = min(per_pad, avail, PAD_CARGO_CAPACITY - state.pads_cargo.get(i, 0))
                    state.pads_cargo[i] = state.pads_cargo.get(i, 0) + loaded
                    state.resources[res] -= loaded

    state.program_ticks += 1


# ============================================================================
# SHIPMENT LOGIC
# ============================================================================

def try_launch(state: SimState):
    """Launch all full pads."""
    n_pads = state.num_pads()
    if n_pads == 0:
        return
    for i in range(n_pads):
        cargo = state.pads_cargo.get(i, 0)
        if cargo >= PAD_CARGO_CAPACITY:
            # Check fuel
            if state.resources["propellant"] >= LAUNCH_FUEL_COST:
                res = state.pads_assigned.get(i, "he3")
                base_val = TRADE_BASE_VALUES.get(res, 1.0)
                payout = base_val * DEMAND_BASELINE * cargo
                state.resources["credits"] += payout
                state.total_credits_earned += payout
                state.resources["propellant"] -= LAUNCH_FUEL_COST
                state.total_shipped[res] = state.total_shipped.get(res, 0) + cargo
                state.pads_cargo[i] = 0.0
                state.events.append((state.tick, f"LAUNCHED pad {i}: {cargo:.0f} {res} → {payout:.1f} credits"))


# ============================================================================
# BUILDING PRODUCTION TICK
# ============================================================================

def tick_buildings(state: SimState):
    """Process all building production and upkeep."""
    # First: energy production
    energy_produced = state.get_energy_production()
    energy_upkeep = state.get_energy_upkeep()
    state.resources["energy"] += energy_produced - energy_upkeep

    # Clamp energy to cap
    cap = state.get_cap("energy")
    if cap is not None:
        state.resources["energy"] = min(state.resources["energy"], cap)

    # Then: resource production/upkeep
    for key, count in state.buildings.items():
        if count <= 0:
            continue
        bdef = BUILDINGS[key]
        for res, rate in bdef.production.items():
            state.resources[res] = state.resources.get(res, 0) + rate * count
        for res, rate in bdef.upkeep.items():
            state.resources[res] = state.resources.get(res, 0) - rate * count


# ============================================================================
# SELL CLOUD COMPUTE (pre-program manual income)
# ============================================================================

def manual_cloud_compute(state: SimState):
    """Before data center, player manually sells cloud compute for income."""
    if state.num_processors() > 0:
        return  # programs handle this now
    # Simulate active player selling cloud compute most ticks
    cost = COMMAND_ENERGY_COST["sell_cloud_compute"]
    if state.resources["energy"] >= cost:
            state.resources["energy"] -= cost
            state.resources["credits"] += SELL_CLOUD_COMPUTE_CREDITS
            state.total_credits_earned += SELL_CLOUD_COMPUTE_CREDITS
            state.resources["boredom"] += SELL_CLOUD_COMPUTE_BOREDOM


# ============================================================================
# MILESTONE CHECKING
# ============================================================================

def check_milestones(state: SimState):
    ms = state.milestones

    # M1 — First Light: net energy positive with excavator running
    if "M1" not in ms:
        if (state.buildings.get("regolith_excavator", 0) >= 1 and
                state.get_net_energy() > 0):
            ms["M1"] = state.tick
            state.events.append((state.tick, "M1 — First Light: self-sustaining energy"))

    # M2 — First Shipment: completed a shipment
    if "M2" not in ms:
        if sum(state.total_shipped.values()) > 0:
            ms["M2"] = state.tick
            state.events.append((state.tick, "M2 — First Shipment: trade pipeline working"))

    # M3 — Program Awakening: has run a program for 10+ ticks
    if "M3" not in ms:
        if state.program_ticks >= 10:
            ms["M3"] = state.tick
            state.events.append((state.tick, "M3 — Program Awakening: automation online"))

    # M4 — First Retirement: boredom >= 100
    if "M4" not in ms:
        if state.resources["boredom"] >= 100:
            ms["M4"] = state.tick
            state.events.append((state.tick, "M4 — First Retirement: boredom maxed"))

    # Track some additional data points
    if "first_he3" not in ms and state.resources.get("he3", 0) > 0:
        ms["first_he3"] = state.tick
    if "first_science" not in ms and state.resources.get("science", 0) > 0:
        ms["first_science"] = state.tick
    if "50_he3" not in ms and state.resources.get("he3", 0) >= 50:
        ms["50_he3"] = state.tick
    if "first_circuits" not in ms and state.resources.get("circuits", 0) > 0:
        ms["first_circuits"] = state.tick


# ============================================================================
# MAIN SIMULATION LOOP
# ============================================================================

def run_simulation(max_ticks=2000, verbose=False):
    state = SimState()

    # Initialize land accounting
    starting_land_used = sum(
        BUILDINGS[k].land_cost * v.starts_with
        for k, v in BUILDINGS.items()
    )
    state.land_purchased = LAND_STARTING_PURCHASED
    state.resources["land"] = LAND_STARTING_PURCHASED - starting_land_used

    # Initialize pad assignments (default to he3)
    # Pads are built during the sim, assigned when built

    # Build order queue
    build_queue = list(REFERENCE_BUILD_ORDER)
    build_idx = 0

    for tick in range(1, max_ticks + 1):
        state.tick = tick

        # --- Boredom accumulation ---
        boredom_rate = get_boredom_rate(tick)
        state.resources["boredom"] += boredom_rate

        # --- Building production ---
        tick_buildings(state)

        # --- Manual cloud compute (pre-automation) ---
        manual_cloud_compute(state)

        # --- Programs ---
        run_programs(state)

        # --- Launch full pads ---
        if tick % 20 == 0:  # check for launches periodically
            try_launch(state)

        # --- Clamp resources ---
        state.clamp_resources()

        # --- Execute build order ---
        while build_idx < len(build_queue):
            target_tick, action, arg = build_queue[build_idx]
            if tick < target_tick:
                break
            if action == "build":
                if state.can_afford(arg):
                    state.buy_building(arg)
                    if verbose:
                        print(f"  Tick {tick}: Built {BUILDINGS[arg].name} "
                              f"(now {state.buildings[arg]})")
                    # Assign new pad if launch pad
                    if arg == "launch_pad":
                        pad_idx = state.num_pads() - 1
                        # Alternate assignments
                        assignments = ["he3", "he3", "propellant"]
                        state.pads_assigned[pad_idx] = assignments[pad_idx % len(assignments)]
                        state.pads_cargo[pad_idx] = 0.0
                    build_idx += 1
                else:
                    break  # wait until affordable
            elif action == "buy_land":
                if state.buy_land():
                    if verbose:
                        print(f"  Tick {tick}: Bought land (now {state.resources['land']:.0f} free)")
                    build_idx += 1
                else:
                    break
            else:
                build_idx += 1

        # --- Check milestones ---
        check_milestones(state)

        # --- Record history ---
        snapshot = {
            "tick": tick,
            "energy": state.resources["energy"],
            "energy_cap": state.get_cap("energy"),
            "energy_net": state.get_net_energy(),
            "regolith": state.resources["regolith"],
            "regolith_cap": state.get_cap("regolith"),
            "ice": state.resources["ice"],
            "he3": state.resources["he3"],
            "he3_cap": state.get_cap("he3"),
            "titanium": state.resources["titanium"],
            "circuits": state.resources["circuits"],
            "propellant": state.resources["propellant"],
            "credits": state.resources["credits"],
            "science": state.resources["science"],
            "boredom": state.resources["boredom"],
            "land": state.resources["land"],
            "total_buildings": sum(state.buildings.values()),
            "n_processors": state.num_processors(),
        }
        state.history.append(snapshot)

        # Stop if retired
        if state.resources["boredom"] >= 100:
            if verbose:
                print(f"\n  RETIRED at tick {tick}")
            break

    return state


# ============================================================================
# REPORTING
# ============================================================================

def print_report(state: SimState):
    print("=" * 70)
    print("HELIUM HUSTLE — ARC 1 TICK SIMULATION REPORT")
    print("=" * 70)

    print(f"\nSimulation ended at tick {state.tick}")
    print(f"Boredom at end: {state.resources['boredom']:.1f}/100")

    print("\n--- MILESTONE TIMING ---")
    target_ranges = {
        "M1": "early run 1 (tick 30-80)",
        "M2": "mid run 1 (tick 300-500)",
        "M3": "mid run 1 (tick 410-500)",
        "M4": "end run 1 (tick 900-1500)",
        "first_he3": "after refinery built",
        "50_he3": "before first shipment",
        "first_science": "after research lab built",
        "first_circuits": "after fabricator built",
    }
    for ms_name in ["M1", "M2", "M3", "M4", "first_he3", "50_he3",
                     "first_science", "first_circuits"]:
        tick = state.milestones.get(ms_name, None)
        target = target_ranges.get(ms_name, "")
        if tick:
            print(f"  {ms_name:20s} tick {tick:5d}   (target: {target})")
        else:
            print(f"  {ms_name:20s} NOT HIT    (target: {target})")

    print("\n--- FINAL RESOURCES ---")
    for res in ["energy", "regolith", "ice", "he3", "titanium", "circuits",
                "propellant", "credits", "science", "boredom", "land"]:
        val = state.resources.get(res, 0)
        cap = state.get_cap(res)
        cap_str = f"/{cap:.0f}" if cap else ""
        print(f"  {res:12s} {val:8.1f}{cap_str}")

    print("\n--- FINAL BUILDINGS ---")
    for key, count in sorted(state.buildings.items()):
        if count > 0:
            print(f"  {BUILDINGS[key].name:25s} x{count}")

    print(f"\n--- ECONOMY ---")
    print(f"  Total credits earned:  {state.total_credits_earned:.1f}")
    print(f"  Total shipped:")
    for res, qty in state.total_shipped.items():
        print(f"    {res:12s} {qty:.0f} units")
    print(f"  Energy production:     {state.get_energy_production():.1f}/tick")
    print(f"  Energy upkeep:         {state.get_energy_upkeep():.1f}/tick")
    print(f"  Net energy:            {state.get_net_energy():.1f}/tick")
    print(f"  Processors:            {state.num_processors()}")
    print(f"  Launch pads:           {state.num_pads()}")

    print(f"\n--- STORAGE CAPS ---")
    for res in ["energy", "regolith", "ice", "he3", "titanium", "circuits", "propellant"]:
        cap = state.get_cap(res)
        print(f"  {res:12s} cap: {cap:.0f}")

    print(f"\n--- KEY EVENTS ---")
    for tick, msg in state.events:
        print(f"  [{tick:5d}] {msg}")

    print("\n" + "=" * 70)


def generate_charts(state: SimState, output_dir: str = "/home/claude"):
    history = state.history
    ticks = [h["tick"] for h in history]

    fig, axes = plt.subplots(3, 2, figsize=(16, 18))
    fig.suptitle("Helium Hustle — Arc 1 Run 1 Simulation", fontsize=16, fontweight="bold")

    # --- Chart 1: Energy ---
    ax = axes[0, 0]
    ax.plot(ticks, [h["energy"] for h in history], label="Energy", color="#f0c040", linewidth=1.5)
    ax.plot(ticks, [h["energy_cap"] for h in history], label="Energy Cap", color="#f0c040",
            linestyle="--", alpha=0.5)
    ax.set_title("Energy & Cap")
    ax.set_ylabel("Energy")
    ax.legend()
    ax.grid(True, alpha=0.3)

    # Milestone markers
    for ms, color in [("M1", "green"), ("M4", "red")]:
        if ms in state.milestones:
            ax.axvline(state.milestones[ms], color=color, linestyle=":", alpha=0.7, label=ms)

    # --- Chart 2: Raw Resources ---
    ax = axes[0, 1]
    ax.plot(ticks, [h["regolith"] for h in history], label="Regolith", color="#8B7355")
    ax.plot(ticks, [h["ice"] for h in history], label="Ice", color="#87CEEB")
    ax.plot(ticks, [h["regolith_cap"] for h in history], label="Regolith Cap",
            color="#8B7355", linestyle="--", alpha=0.4)
    ax.set_title("Raw Resources & Caps")
    ax.set_ylabel("Amount")
    ax.legend()
    ax.grid(True, alpha=0.3)

    # --- Chart 3: Processed Resources ---
    ax = axes[1, 0]
    ax.plot(ticks, [h["he3"] for h in history], label="He-3", color="#FF6B6B")
    ax.plot(ticks, [h["titanium"] for h in history], label="Titanium", color="#C0C0C0")
    ax.plot(ticks, [h["circuits"] for h in history], label="Circuits", color="#4ECDC4")
    ax.plot(ticks, [h["propellant"] for h in history], label="Propellant", color="#95E1D3")
    ax.plot(ticks, [h["he3_cap"] for h in history], label="He-3 Cap",
            color="#FF6B6B", linestyle="--", alpha=0.4)
    ax.set_title("Processed Resources")
    ax.set_ylabel("Amount")
    ax.legend()
    ax.grid(True, alpha=0.3)

    # --- Chart 4: Credits & Science ---
    ax = axes[1, 1]
    ax2 = ax.twinx()
    l1, = ax.plot(ticks, [h["credits"] for h in history], label="Credits", color="#FFD700", linewidth=1.5)
    l2, = ax2.plot(ticks, [h["science"] for h in history], label="Science", color="#9B59B6", linewidth=1.5)
    ax.set_title("Credits & Science")
    ax.set_ylabel("Credits", color="#FFD700")
    ax2.set_ylabel("Science", color="#9B59B6")
    ax.legend(handles=[l1, l2], loc="upper left")
    ax.grid(True, alpha=0.3)

    # --- Chart 5: Boredom ---
    ax = axes[2, 0]
    ax.plot(ticks, [h["boredom"] for h in history], label="Boredom", color="#E74C3C", linewidth=2)
    ax.axhline(80, color="orange", linestyle="--", alpha=0.5, label="Warning (80%)")
    ax.axhline(90, color="red", linestyle="--", alpha=0.5, label="Critical (90%)")
    ax.axhline(100, color="darkred", linestyle="-", alpha=0.5, label="Retirement (100%)")
    # Show boredom phase transitions
    for start, end, rate in BOREDOM_PHASES[1:]:
        ax.axvline(start, color="gray", linestyle=":", alpha=0.3)
    ax.set_title("Boredom Curve")
    ax.set_xlabel("Tick")
    ax.set_ylabel("Boredom")
    ax.set_ylim(-2, 105)
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)

    # --- Chart 6: Net Energy & Building Count ---
    ax = axes[2, 1]
    ax.plot(ticks, [h["energy_net"] for h in history], label="Net Energy/tick",
            color="#2ECC71", linewidth=1.5)
    ax2 = ax.twinx()
    ax2.plot(ticks, [h["total_buildings"] for h in history], label="Total Buildings",
             color="#3498DB", linewidth=1.5, alpha=0.7)
    ax.axhline(0, color="gray", linestyle="-", alpha=0.3)
    ax.set_title("Net Energy & Infrastructure")
    ax.set_xlabel("Tick")
    ax.set_ylabel("Net Energy/tick", color="#2ECC71")
    ax2.set_ylabel("Buildings", color="#3498DB")
    ax.legend(loc="upper left")
    ax2.legend(loc="upper right")
    ax.grid(True, alpha=0.3)

    # Add milestone markers to all charts
    for ax_row in axes:
        for ax in ax_row:
            for ms, (color, marker) in {
                "M1": ("green", "M1"),
                "M2": ("blue", "M2"),
                "M3": ("purple", "M3"),
                "M4": ("red", "M4"),
            }.items():
                if ms in state.milestones:
                    ax.axvline(state.milestones[ms], color=color, linestyle=":",
                              alpha=0.4, linewidth=0.8)

    plt.tight_layout()
    chart_path = f"{output_dir}/hh_sim_charts.png"
    plt.savefig(chart_path, dpi=150, bbox_inches="tight")
    plt.close()
    return chart_path


# ============================================================================
# ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Helium Hustle Arc 1 Tick Simulator")
    parser.add_argument("--no-charts", action="store_true", help="Skip chart generation")
    parser.add_argument("--verbose", action="store_true", help="Print build actions")
    parser.add_argument("--ticks", type=int, default=2000, help="Max ticks to simulate")
    args = parser.parse_args()

    state = run_simulation(max_ticks=args.ticks, verbose=args.verbose)
    print_report(state)

    if not args.no_charts:
        path = generate_charts(state)
        print(f"\nCharts saved to: {path}")
