"""
Helium Hustle — All tunable parameters in one place.

Mirrors what will eventually live in game_config.json and the datasheets.
Initial values ported from sim/hh_sim.py prototype — not yet validated.
The optimizer workflow will produce calibrated replacements.
"""

from __future__ import annotations
from dataclasses import dataclass, field


# ============================================================================
# BUILDING DEFINITIONS
# ============================================================================

@dataclass
class BuildingDef:
    name: str
    base_cost_credits: float
    base_cost_resources: dict  # resource_name -> amount
    cost_scaling: float        # multiplicative per copy owned
    land_cost: float           # land consumed per building
    production: dict           # resource_name -> amount per tick
    upkeep: dict               # resource_name -> amount per tick (consumed)
    energy_production: float = 0.0
    energy_upkeep: float = 0.0
    energy_cap_bonus: float = 0.0
    storage_cap_bonus: dict = field(default_factory=dict)
    starts_with: int = 0


BUILDINGS: dict[str, BuildingDef] = {
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
        energy_production=1.5, energy_upkeep=2.5,  # net -1.0 energy
    ),
    "data_center": BuildingDef(
        name="Data Center",
        base_cost_credits=80, base_cost_resources={"circuits": 5}, cost_scaling=1.40,
        land_cost=2,
        production={}, upkeep={},
        energy_upkeep=2.0,
        # Grants 1 processor (= 1 data_center building count)
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
BASE_CAPS: dict[str, float] = {
    "energy":     50.0,   # 1 battery at start adds +40 → effective start cap = 90
    "regolith":  100.0,
    "ice":        80.0,
    "he3":        50.0,
    "titanium":   50.0,
    "circuits":   30.0,
    "propellant": 60.0,
}

# Resources with no storage cap
UNCAPPED: set[str] = {"credits", "science", "boredom", "land"}

# Starting resource amounts
STARTING_RESOURCES: dict[str, float] = {
    "energy":     30.0,
    "regolith":    0.0,
    "ice":         0.0,
    "he3":         0.0,
    "titanium":    0.0,
    "circuits":    0.0,
    "propellant":  0.0,
    "credits":    50.0,
    "science":     0.0,
    "boredom":     0.0,
    "land":        5.0,   # computed properly in init_state()
}

# ============================================================================
# LAND SYSTEM
# ============================================================================

LAND_BASE_COST: float = 10.0
LAND_COST_SCALING: float = 1.20   # multiplier per land unit already purchased
LAND_STARTING_PURCHASED: int = 12  # total land purchased at start of run

# ============================================================================
# BOREDOM CURVE
# ============================================================================

# Three phases targeting ~900 ticks to 100 boredom with no mitigation
BOREDOM_PHASES: list[tuple[int, int, float]] = [
    (0,   350,  0.03),   # phase 1: gentle  — 10.5 boredom over 350 ticks
    (350, 750,  0.08),   # phase 2: notable — 32 boredom over 400 ticks
    (750, 9999, 0.24),   # phase 3: urgent  — 57.5 boredom over ~240 ticks → 100 at ~tick 990
]

# ============================================================================
# SHIPMENT / TRADE PARAMETERS
# ============================================================================

LAUNCH_FUEL_COST: float = 20.0        # propellant per pad launched
PAD_CARGO_CAPACITY: float = 100.0
PAD_LOAD_PER_COMMAND: float = 5.0     # units loaded per Load Pads command execution
LAUNCH_CHECK_INTERVAL: int = 20       # ticks between automatic launch attempts

# Base trade value per unit shipped (credits), multiplied by demand
TRADE_BASE_VALUES: dict[str, float] = {
    "he3":       3.0,
    "titanium":  2.5,
    "circuits":  5.0,
    "propellant": 1.5,
}

DEMAND_BASELINE: float = 0.5

# ============================================================================
# COMMAND COSTS & EFFECTS
# ============================================================================

SELL_CLOUD_COMPUTE_ENERGY: float = 2.0
SELL_CLOUD_COMPUTE_CREDITS: float = 5.0
SELL_CLOUD_COMPUTE_BOREDOM: float = 0.04

DREAM_ENERGY: float = 4.0
DREAM_BOREDOM_REDUCTION: float = 0.5

LOAD_PADS_ENERGY: float = 1.0

# ============================================================================
# PROGRAM MODEL (simplified averaged fractions of a 5-command cycle)
#
# Cycle: Sell Cloud Compute x2, Load Pads x2, Dream x1
# Per processor per tick (averaged over the 5-command cycle):
# ============================================================================

PROG_CREDITS_PER_PROC: float = 2.0      # 2/5 × 5 credits
PROG_BOREDOM_PER_PROC: float = -0.084   # +0.016 from SCC – 0.1 from Dream
PROG_ENERGY_PER_PROC: float = 2.0       # (2/5×2 + 2/5×1 + 1/5×4) = 2.0 avg
PROG_LOAD_UNITS_PER_PROC: float = 2.0   # 2/5 × 5 units per Load command

# ============================================================================
# MILESTONE TARGETS (tick windows for run 1, competent player)
# ============================================================================

MILESTONE_TARGETS: dict[str, tuple[int, int]] = {
    "M1": (30,   80),    # First Light — self-sustaining energy
    "M2": (300, 500),    # First Shipment — trade pipeline operational
    "M3": (410, 500),    # Program Awakening — automation running 10+ ticks
    "M4": (900, 1500),   # First Retirement — boredom reaches 100
}

MILESTONE_NAMES: dict[str, str] = {
    "M1": "First Light",
    "M2": "First Shipment",
    "M3": "Program Awakening",
    "M4": "First Retirement",
}

# ============================================================================
# OPTIMIZER SETTINGS
# ============================================================================

LOOKAHEAD_TICKS: int = 60     # ticks of forward simulation per scoring evaluation
MAX_RUN_TICKS: int = 1100     # hard cap on simulation length
SNAPSHOT_TICKS: list[int] = [100, 300, 500, 700, 900]

# Urgency bonus table (added on top of lookahead delta to guide infrastructure)
URGENCY_BONUSES: dict[str, dict] = {
    "land_critical":        {"bonus": 80, "condition": "free_land <= 1"},
    "land_low":             {"bonus": 40, "condition": "free_land == 2"},
    "energy_tight_solar":   {"bonus": 25, "condition": "net_energy_ratio < 1.3"},
    "energy_very_tight":    {"bonus": 50, "condition": "net_energy < 2"},
    "battery_cap_full":     {"bonus": 15, "condition": "energy_fill > 0.85"},
    "storage_cap_near":     {"bonus": 15, "condition": "any_resource_fill > 0.80"},
    "first_launch_pad":     {"bonus": 35, "condition": "he3 > 20 and n_pads == 0"},
    "first_data_center":    {"bonus": 20, "condition": "circuits >= 5 and n_procs == 0"},
}
