"""
Helium Hustle — Game constants loaded from godot/data/*.json.

All building definitions, resource caps, starting state, boredom curve,
shipment parameters, trade values, and command costs are derived directly
from the ground-truth JSON files. Do NOT hand-edit values here.

Only the sections marked OPTIMIZER/SIM-SPECIFIC are hardcoded here — they
are not in the game data and exist only to tune the Python optimizer.
"""

from __future__ import annotations
import json
from dataclasses import dataclass, field
from pathlib import Path


# ============================================================================
# JSON LOADER
# ============================================================================

_GODOT_DATA = Path(__file__).parent.parent / "godot" / "data"


def _load(name: str):
    return json.loads((_GODOT_DATA / name).read_text(encoding="utf-8"))


_buildings_raw = _load("buildings.json")
_resources_raw = _load("resources.json")
_cfg           = _load("game_config.json")
_commands_raw  = _load("commands.json")
_commands      = {c["short_name"]: c for c in _commands_raw}
_research_raw  = _load("research.json")
RESEARCH: dict[str, dict] = {r["id"]: r for r in _research_raw}


# ============================================================================
# BUILDING DEFINITIONS  (from buildings.json)
# ============================================================================

@dataclass
class BuildingDef:
    name: str
    base_cost_credits: float          # always the "cred" cost
    base_cost_resources: dict         # other resource costs (short_name -> amount)
    cost_scaling: float
    land_cost: float
    production: dict                  # non-energy production (short_name -> rate)
    upkeep: dict                      # non-energy upkeep consumed (short_name -> rate)
    energy_production: float = 0.0
    energy_upkeep: float = 0.0
    energy_cap_bonus: float = 0.0     # from store_eng effects
    storage_cap_bonus: dict = field(default_factory=dict)  # from other store_ effects
    starts_with: int = 0


def _build_buildings(raw: list, starting: dict) -> dict:
    result = {}
    for b in raw:
        sn = b["short_name"]
        costs      = b.get("costs", {})
        production = b.get("production", {})
        upkeep     = b.get("upkeep", {})
        effects    = b.get("effects", [])

        eng_cap_bonus   = 0.0
        storage_bonuses = {}
        for e in effects:
            if e.get("prefix") == "store":
                res = e["resource"]
                val = float(e["value"])
                if res == "eng":
                    eng_cap_bonus += val
                else:
                    storage_bonuses[res] = storage_bonuses.get(res, 0.0) + val

        result[sn] = BuildingDef(
            name=b["name"],
            base_cost_credits=float(costs.get("cred", 0)),
            base_cost_resources={k: float(v) for k, v in costs.items() if k != "cred"},
            cost_scaling=float(b["cost_scaling"]),
            land_cost=float(b["land"]),
            production={k: float(v) for k, v in production.items() if k != "eng"},
            upkeep={k: float(v) for k, v in upkeep.items() if k != "eng"},
            energy_production=float(production.get("eng", 0)),
            energy_upkeep=float(upkeep.get("eng", 0)),
            energy_cap_bonus=eng_cap_bonus,
            storage_cap_bonus=storage_bonuses,
            starts_with=int(starting.get(sn, 0)),
        )
    return result


_starting_buildings = _cfg["starting_buildings"]
BUILDINGS: dict[str, BuildingDef] = _build_buildings(_buildings_raw, _starting_buildings)


# ============================================================================
# RESOURCE & STORAGE  (from resources.json)
# ============================================================================

# Base storage caps for capped resources.
# boredom is treated as uncapped in the sim (retirement check fires at
# game_config.boredom_max; we don't want clamp_resources to suppress it).
# proc is not tracked as a resource in the sim.
_SIM_UNCAPPED_OVERRIDE = {"boredom", "proc"}

BASE_CAPS: dict[str, float] = {
    r["short_name"]: float(r["storage_base"])
    for r in _resources_raw
    if r["storage_base"] is not None
    and r["short_name"] not in _SIM_UNCAPPED_OVERRIDE
}

UNCAPPED: set[str] = (
    {r["short_name"] for r in _resources_raw if r["storage_base"] is None}
    | _SIM_UNCAPPED_OVERRIDE
)


# ============================================================================
# STARTING STATE  (from game_config.json)
# ============================================================================

STARTING_RESOURCES: dict[str, float] = {
    k: float(v) for k, v in _cfg["starting_resources"].items()
}

# ============================================================================
# LAND SYSTEM  (from game_config.json)
# ============================================================================

LAND_BASE_COST: float    = float(_cfg["land"]["base_cost"])
LAND_COST_SCALING: float = float(_cfg["land"]["cost_scaling"])
LAND_PER_PURCHASE: int   = int(_cfg["land"].get("land_per_purchase", 1))


# ============================================================================
# BOREDOM CURVE  (from game_config.json)
# ============================================================================

# Convert [{day, rate}, ...] -> [(start_tick, end_tick, rate), ...]
def _build_boredom_phases(curve: list) -> list:
    phases = []
    for i, entry in enumerate(curve):
        start = int(entry["day"])
        end   = int(curve[i + 1]["day"]) if i + 1 < len(curve) else 9999
        phases.append((start, end, float(entry["rate"])))
    return phases

BOREDOM_PHASES: list = _build_boredom_phases(_cfg["boredom_curve"])


# ============================================================================
# SHIPMENT / TRADE  (from game_config.json)
# ============================================================================

_shipment = _cfg["shipment"]

LAUNCH_FUEL_COST:      float = float(_shipment["fuel_per_pad"])
PAD_CARGO_CAPACITY:    float = float(_shipment["pad_cargo_capacity"])
PAD_LOAD_PER_COMMAND:  float = float(_shipment["load_per_execution"])
TRADE_BASE_VALUES:     dict  = {k: float(v) for k, v in _shipment["base_values"].items()}
DEMAND_BASELINE:       float = 0.5   # mid-point used for shadow pricing only
DEMAND_CFG:            dict  = _cfg.get("demand", {})
RIVALS:                list  = _cfg.get("rivals", [])


# ============================================================================
# COMMAND COSTS  (from commands.json)
# ============================================================================

def _cmd_cost(short_name: str, resource: str, default: float = 0.0) -> float:
    return float(_commands.get(short_name, {}).get("costs", {}).get(resource, default))

def _cmd_prod(short_name: str, resource: str, default: float = 0.0) -> float:
    return float(_commands.get(short_name, {}).get("production", {}).get(resource, default))

def _cmd_effect_val(short_name: str, effect_name: str, default: float = 0.0) -> float:
    for e in _commands.get(short_name, {}).get("effects", []):
        if e.get("effect") == effect_name:
            return float(e.get("value", default))
    return default

SELL_CLOUD_COMPUTE_ENERGY:  float = _cmd_cost("cloud_compute", "eng",  2.0)
SELL_CLOUD_COMPUTE_CREDITS: float = _cmd_prod("cloud_compute", "cred", 5.0)
SELL_CLOUD_COMPUTE_BOREDOM: float = _cmd_prod("cloud_compute", "boredom", 0.04)

# Commands the optimizer can execute as one-shot discrete actions (buy_* resource purchases).
# Each entry: short_name -> {costs: {res: amt}, production: {res: amt}}
PURCHASABLE_COMMANDS: dict[str, dict] = {
    sn: {"name": c["name"], "costs": c.get("costs", {}), "production": c.get("production", {})}
    for sn, c in _commands.items()
    if sn.startswith("buy_")
}


# ============================================================================
# PROGRAM MODEL  (sim-specific — derived from commands.json)
#
# Policy: Sell Cloud Compute x2, Load Pads x2, Idle x1 per cycle
# Dream is excluded — it requires self_maintenance research (not in Run 1 scope).
# Idle replaces it in the cycle: cheap boredom-neutral filler.
# Fractions per processor per tick (averaged over 5-command cycle):
# ============================================================================

LAUNCH_CHECK_INTERVAL: int  = 20   # ticks between automatic launch checks (sim detail)
LAUNCH_COOLDOWN_TICKS: int  = 10   # ticks a pad is offline after launching

_f_scc  = 2 / 5
_f_load = 2 / 5
_f_idle = 1 / 5

PROG_CREDITS_PER_PROC:    float = (
    _f_scc  * _cmd_prod("cloud_compute", "cred", 0)
    + _f_idle * _cmd_prod("idle",        "cred", 0)
)
PROG_BOREDOM_PER_PROC:    float = (
    _f_scc * _cmd_prod("cloud_compute", "boredom", 0)
    # idle and load_pads have no boredom production
)
PROG_ENERGY_PER_PROC:     float = (
    _f_scc  * _cmd_cost("cloud_compute", "eng", 0)
    + _f_load * _cmd_cost("load_pads",   "eng", 0)
    # idle has no energy cost
)
PROG_LOAD_UNITS_PER_PROC: float = _f_load * _cmd_effect_val("load_pads", "load_pads", 5)


# ============================================================================
# OPTIMIZER SETTINGS  (sim-specific, not in game data)
# ============================================================================

LOOKAHEAD_TICKS: int       = 60
MAX_RUN_TICKS:   int       = 1500
SNAPSHOT_TICKS:  list[int] = [100, 300, 500, 700, 900]


# ============================================================================
# SHADOW PRICING  (optimizer -- not in game data)
#
# Direct shadow prices from tradeable good values x demand_baseline.
# data_center gets a "program income proxy" equal to PROG_CREDITS_PER_PROC.
# ============================================================================

SHADOW_PRICES: dict[str, float] = {
    res: float(val) * DEMAND_BASELINE
    for res, val in TRADE_BASE_VALUES.items()
}
# Add processor income proxy for data_center
SHADOW_PRICES["proc"] = PROG_CREDITS_PER_PROC

SHADOW_WEIGHT: int = 30  # ticks of shadow production added to score


def _bldg_shadow_delta(bdef) -> float:
    prod = sum(SHADOW_PRICES.get(r, 0.0) * v for r, v in bdef.production.items())
    upk  = sum(SHADOW_PRICES.get(r, 0.0) * v for r, v in bdef.upkeep.items())
    return prod - upk


BUILDING_SHADOW_DELTAS: dict[str, float] = {
    sn: _bldg_shadow_delta(bdef) for sn, bdef in BUILDINGS.items()
}
# data_center's proc grant is in effects, not production -- patch manually
BUILDING_SHADOW_DELTAS["data_center"] = PROG_CREDITS_PER_PROC
