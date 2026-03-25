"""
Helium Hustle — Pure economic state machine.

No policy, no heuristics. Functions take state + action and return new state
(or mutate in-place where noted). Tick order matches the Godot implementation:
  1. Boredom increment
  2. Buildings: energy net applied, then resource production/upkeep
  3. Programs: fixed command policy
  4. Shipments: launch full pads (checked every LAUNCH_CHECK_INTERVAL ticks)
  5. Clamp all resources to storage caps
  6. Milestone checks

Callers are responsible for purchase actions (buy_building / buy_land) between ticks.
"""

from __future__ import annotations
import copy
from dataclasses import dataclass, field
from typing import Optional

from constants import (
    BUILDINGS, BASE_CAPS, UNCAPPED, STARTING_RESOURCES,
    LAND_BASE_COST, LAND_COST_SCALING, LAND_STARTING_PURCHASED,
    BOREDOM_PHASES,
    LAUNCH_FUEL_COST, PAD_CARGO_CAPACITY, PAD_LOAD_PER_COMMAND,
    LAUNCH_CHECK_INTERVAL, TRADE_BASE_VALUES, DEMAND_BASELINE,
    SELL_CLOUD_COMPUTE_ENERGY, SELL_CLOUD_COMPUTE_CREDITS, SELL_CLOUD_COMPUTE_BOREDOM,
    PROG_CREDITS_PER_PROC, PROG_BOREDOM_PER_PROC, PROG_ENERGY_PER_PROC,
    PROG_LOAD_UNITS_PER_PROC,
)


# ============================================================================
# STATE
# ============================================================================

@dataclass
class EconState:
    tick: int = 0
    resources: dict = field(default_factory=dict)
    buildings: dict = field(default_factory=dict)    # key -> count
    land_purchased: int = 0
    pads_assigned: dict = field(default_factory=dict) # pad_index -> resource
    pads_cargo: dict = field(default_factory=dict)    # pad_index -> float
    total_credits_earned: float = 0.0                 # cumulative (shipments + programs)
    total_shipped: dict = field(default_factory=dict) # resource -> units shipped
    program_ticks: int = 0                            # ticks where programs ran
    milestones: dict = field(default_factory=dict)    # name -> tick
    history: list = field(default_factory=list)       # list of snapshot dicts
    # Rolling credit income tracking (last 50 ticks)
    _credit_gains: list = field(default_factory=list)


def init_state() -> EconState:
    """Create a fresh run-1 starting state."""
    state = EconState()
    state.resources = dict(STARTING_RESOURCES)
    state.buildings = {k: v.starts_with for k, v in BUILDINGS.items()}

    # Compute free land from purchased total minus what starting buildings use
    used = sum(
        BUILDINGS[k].land_cost * state.buildings[k]
        for k in state.buildings
    )
    state.land_purchased = LAND_STARTING_PURCHASED
    state.resources["land"] = float(LAND_STARTING_PURCHASED - used)
    return state


# ============================================================================
# DERIVED PROPERTIES
# ============================================================================

def get_cap(state: EconState, resource: str) -> Optional[float]:
    if resource in UNCAPPED:
        return None
    base = BASE_CAPS.get(resource)
    if base is None:
        return None
    extra = 0.0
    if resource == "eng":
        for k, count in state.buildings.items():
            if count > 0:
                extra += BUILDINGS[k].energy_cap_bonus * count
    else:
        for k, count in state.buildings.items():
            if count > 0:
                extra += BUILDINGS[k].storage_cap_bonus.get(resource, 0) * count
    return base + extra


def get_energy_production(state: EconState) -> float:
    return sum(
        BUILDINGS[k].energy_production * count
        for k, count in state.buildings.items()
        if count > 0
    )


def get_energy_upkeep(state: EconState) -> float:
    return sum(
        BUILDINGS[k].energy_upkeep * count
        for k, count in state.buildings.items()
        if count > 0
    )


def get_net_energy(state: EconState) -> float:
    return get_energy_production(state) - get_energy_upkeep(state)


def num_processors(state: EconState) -> int:
    return state.buildings.get("data_center", 0)


def num_pads(state: EconState) -> int:
    return state.buildings.get("launch_pad", 0)


def clamp_resources(state: EconState) -> None:
    for res in list(state.resources.keys()):
        cap = get_cap(state, res)
        if cap is not None:
            state.resources[res] = min(state.resources[res], cap)
        state.resources[res] = max(0.0, state.resources[res])


# ============================================================================
# PURCHASE ACTIONS
# ============================================================================

def get_building_cost(state: EconState, key: str) -> dict:
    """Return {credits: X, resource: Y, ..., _land: Z} for next copy."""
    bdef = BUILDINGS[key]
    count = state.buildings.get(key, 0)
    scale = bdef.cost_scaling ** count
    costs = {"cred": bdef.base_cost_credits * scale}
    for res, amt in bdef.base_cost_resources.items():
        costs[res] = amt * scale
    costs["_land"] = bdef.land_cost
    return costs


def can_afford_building(state: EconState, key: str) -> bool:
    costs = get_building_cost(state, key)
    if costs.get("_land", 0) > state.resources.get("land", 0):
        return False
    for res, amt in costs.items():
        if res == "_land":
            continue
        if state.resources.get(res, 0) < amt:
            return False
    return True


def get_land_cost(state: EconState) -> float:
    return LAND_BASE_COST * (LAND_COST_SCALING ** state.land_purchased)


def can_afford_land(state: EconState) -> bool:
    return state.resources.get("cred", 0) >= get_land_cost(state)


def buy_building(state: EconState, key: str) -> dict:
    """Deduct costs, increment count, assign pad if launch_pad. Returns cost dict."""
    costs = get_building_cost(state, key)
    for res, amt in costs.items():
        if res == "_land":
            state.resources["land"] -= amt
        else:
            state.resources[res] -= amt
    state.buildings[key] = state.buildings.get(key, 0) + 1

    # Auto-assign pad resource
    if key == "launch_pad":
        pad_idx = num_pads(state) - 1
        # First two pads → he3, third → propellant (for launch fuel), rest → he3
        assignments = ["he3", "he3", "propellant"]
        state.pads_assigned[pad_idx] = assignments[pad_idx % len(assignments)]
        state.pads_cargo[pad_idx] = 0.0

    return costs


def buy_land(state: EconState) -> float:
    """Deduct credit cost, add 1 land. Returns credits spent."""
    cost = get_land_cost(state)
    state.resources["cred"] -= cost
    state.resources["land"] += 1.0
    state.land_purchased += 1
    return cost


# ============================================================================
# TICK COMPONENTS
# ============================================================================

def _tick_boredom(state: EconState) -> None:
    rate = 0.0
    for start, end, r in BOREDOM_PHASES:
        if start <= state.tick < end:
            rate = r
            break
    state.resources["boredom"] += rate


def _tick_buildings(state: EconState) -> None:
    """Energy net applied first, then resource production/upkeep."""
    # Net energy delta (all buildings combined)
    energy_delta = get_net_energy(state)
    state.resources["eng"] = state.resources.get("eng", 0.0) + energy_delta
    # Clamp energy immediately so it doesn't carry overflow into resource calc
    energy_cap = get_cap(state, "eng")
    if energy_cap is not None:
        state.resources["eng"] = min(state.resources["eng"], energy_cap)
    state.resources["eng"] = max(0.0, state.resources["eng"])

    # Resource production and upkeep (simplified: all buildings always run)
    for key, count in state.buildings.items():
        if count <= 0:
            continue
        bdef = BUILDINGS[key]
        for res, rate in bdef.production.items():
            state.resources[res] = state.resources.get(res, 0.0) + rate * count
        for res, rate in bdef.upkeep.items():
            state.resources[res] = state.resources.get(res, 0.0) - rate * count


def _tick_programs(state: EconState) -> None:
    """Fixed command policy:
    - Pre-processors (no data centers): sell cloud compute once if energy allows
    - With processors: run averaged program cycle (SCC x2 / Load x2 / Dream x1)
    """
    n_proc = num_processors(state)

    if n_proc == 0:
        # Manual sell cloud compute
        if state.resources.get("eng", 0) >= SELL_CLOUD_COMPUTE_ENERGY:
            state.resources["eng"] -= SELL_CLOUD_COMPUTE_ENERGY
            gained = SELL_CLOUD_COMPUTE_CREDITS
            state.resources["cred"] = state.resources.get("cred", 0.0) + gained
            state.total_credits_earned += gained
            state.resources["boredom"] += SELL_CLOUD_COMPUTE_BOREDOM
        return

    # Program running — averaged fractions of the 5-command cycle
    state.program_ticks += 1
    for _ in range(n_proc):
        energy_avail = state.resources.get("eng", 0)
        if energy_avail < PROG_ENERGY_PER_PROC:
            continue  # processor stalls on energy
        state.resources["eng"] -= PROG_ENERGY_PER_PROC
        gained = PROG_CREDITS_PER_PROC
        state.resources["cred"] = state.resources.get("cred", 0.0) + gained
        state.total_credits_earned += gained
        state.resources["boredom"] += PROG_BOREDOM_PER_PROC
        state.resources["boredom"] = max(0.0, state.resources["boredom"])

        # Load pads
        n_p = num_pads(state)
        if n_p > 0:
            load_per_pad = PROG_LOAD_UNITS_PER_PROC / n_p
            for i in range(n_p):
                res = state.pads_assigned.get(i, "he3")
                avail = state.resources.get(res, 0.0)
                space = PAD_CARGO_CAPACITY - state.pads_cargo.get(i, 0.0)
                loaded = min(load_per_pad, avail, space)
                if loaded > 0:
                    state.pads_cargo[i] = state.pads_cargo.get(i, 0.0) + loaded
                    state.resources[res] -= loaded


def _tick_shipments(state: EconState) -> None:
    """Launch all full pads if propellant available."""
    n_p = num_pads(state)
    if n_p == 0:
        return
    credits_gained = 0.0
    for i in range(n_p):
        cargo = state.pads_cargo.get(i, 0.0)
        if cargo >= PAD_CARGO_CAPACITY:
            if state.resources.get("prop", 0) >= LAUNCH_FUEL_COST:
                res = state.pads_assigned.get(i, "he3")
                base_val = TRADE_BASE_VALUES.get(res, 1.0)
                payout = base_val * DEMAND_BASELINE * cargo
                state.resources["cred"] = state.resources.get("cred", 0.0) + payout
                state.total_credits_earned += payout
                credits_gained += payout
                state.resources["prop"] = state.resources.get("prop", 0.0) - LAUNCH_FUEL_COST
                state.total_shipped[res] = state.total_shipped.get(res, 0.0) + cargo
                state.pads_cargo[i] = 0.0


def _check_milestones(state: EconState) -> None:
    ms = state.milestones

    # M1 — First Light: net energy > 0 with at least one excavator
    if "M1" not in ms:
        if (state.buildings.get("excavator", 0) >= 1
                and get_net_energy(state) > 0):
            ms["M1"] = state.tick

    # M2 — First Shipment: any resource has been shipped
    if "M2" not in ms:
        if sum(state.total_shipped.values()) > 0:
            ms["M2"] = state.tick

    # M3 — Program Awakening: program has run for 10+ ticks
    if "M3" not in ms:
        if state.program_ticks >= 10:
            ms["M3"] = state.tick

    # M4 — First Retirement: boredom maxed
    if "M4" not in ms:
        if state.resources.get("boredom", 0) >= 100:
            ms["M4"] = state.tick

    # Supplementary milestones for report
    if "first_he3" not in ms and state.resources.get("he3", 0) > 0:
        ms["first_he3"] = state.tick
    if "first_science" not in ms and state.resources.get("sci", 0) > 0:
        ms["first_science"] = state.tick
    if "first_circuits" not in ms and state.resources.get("cir", 0) > 0:
        ms["first_circuits"] = state.tick
    if "50_he3" not in ms and state.resources.get("he3", 0) >= 50:
        ms["50_he3"] = state.tick


# ============================================================================
# SNAPSHOT / HISTORY
# ============================================================================

def take_snapshot(state: EconState) -> dict:
    """Return a dict of current state metrics for the report."""
    snap = {
        "tick": state.tick,
        "net_energy": get_net_energy(state),
        "energy_production": get_energy_production(state),
        "energy_upkeep": get_energy_upkeep(state),
        "n_processors": num_processors(state),
        "n_pads": num_pads(state),
        "total_credits_earned": state.total_credits_earned,
    }
    all_resources = [
        "eng", "reg", "ice", "he3", "ti",
        "cir", "prop", "cred", "sci", "boredom", "land",
    ]
    for res in all_resources:
        snap[res] = state.resources.get(res, 0.0)
        cap = get_cap(state, res)
        snap[f"{res}_cap"] = cap
    snap["buildings"] = dict(state.buildings)
    return snap


def _record_history(state: EconState) -> None:
    state.history.append(take_snapshot(state))


# ============================================================================
# MAIN TICK FUNCTION
# ============================================================================

def tick_once(state: EconState, record_history: bool = False) -> None:
    """Advance state by one tick (mutates in place)."""
    state.tick += 1
    _tick_boredom(state)
    _tick_buildings(state)
    _tick_programs(state)
    if state.tick % LAUNCH_CHECK_INTERVAL == 0:
        _tick_shipments(state)
    clamp_resources(state)
    _check_milestones(state)
    if record_history:
        _record_history(state)


def _clone_for_scoring(state: EconState) -> EconState:
    """
    Shallow-clone state for scoring lookahead — copies only the mutable fields
    that tick logic writes, skipping the history list (which can be large).
    This is ~10-50x faster than copy.deepcopy(state) after many ticks.
    """
    s = EconState()
    s.tick = state.tick
    s.resources = dict(state.resources)
    s.buildings = dict(state.buildings)
    s.land_purchased = state.land_purchased
    s.pads_assigned = dict(state.pads_assigned)
    s.pads_cargo = dict(state.pads_cargo)
    s.total_credits_earned = state.total_credits_earned
    s.total_shipped = dict(state.total_shipped)
    s.program_ticks = state.program_ticks
    s.milestones = dict(state.milestones)
    # Intentionally omit history and _credit_gains — not needed for scoring
    return s


def sim_forward(state: EconState, n_ticks: int, record_history: bool = False) -> EconState:
    """
    Return a copy of state advanced by n_ticks with no purchase actions.
    Uses a fast clone when record_history=False (for scoring lookaheads).
    """
    s = _clone_for_scoring(state) if not record_history else copy.deepcopy(state)
    for _ in range(n_ticks):
        tick_once(s, record_history=record_history)
        if s.resources.get("boredom", 0) >= 100:
            break
    return s
