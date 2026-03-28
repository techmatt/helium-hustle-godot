"""
Helium Hustle — Pure economic state machine.

No policy, no heuristics. Functions take state + action and return new state
(or mutate in-place where noted). Tick order matches the Godot implementation:
  1. Boredom increment
  2. Buildings: energy net applied, then resource production/upkeep
  3. Demand update (Perlin drift + accumulator decay)
  4. Programs: fixed command policy (includes pad loading)
  5. Shipments: launch full pads (checked every LAUNCH_CHECK_INTERVAL ticks)
  6. Rival dumps + speculator burst check
  7. Clamp all resources to storage caps
  8. Event recording

Callers are responsible for purchase actions (buy_building / buy_land) between ticks.
"""

from __future__ import annotations
import copy
import math
import random
from dataclasses import dataclass, field
from typing import Optional

from constants import (
    BUILDINGS, BASE_CAPS, UNCAPPED, STARTING_RESOURCES,
    LAND_BASE_COST, LAND_COST_SCALING,
    BOREDOM_PHASES,
    LAUNCH_FUEL_COST, PAD_CARGO_CAPACITY, PAD_LOAD_PER_COMMAND,
    LAUNCH_CHECK_INTERVAL, LAUNCH_COOLDOWN_TICKS, TRADE_BASE_VALUES, DEMAND_BASELINE,
    DEMAND_CFG, RIVALS,
    SELL_CLOUD_COMPUTE_ENERGY, SELL_CLOUD_COMPUTE_CREDITS, SELL_CLOUD_COMPUTE_BOREDOM,
    PROG_CREDITS_PER_PROC, PROG_BOREDOM_PER_PROC, PROG_ENERGY_PER_PROC,
    PROG_LOAD_UNITS_PER_PROC, PURCHASABLE_COMMANDS,
)

TRADEABLE: list[str] = ["he3", "ti", "cir", "prop"]


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
    pads_cooldown: dict = field(default_factory=dict) # pad_index -> ticks remaining
    loading_priority: list = field(default_factory=lambda: ["he3", "ti", "cir", "prop"])
    total_credits_earned: float = 0.0                 # cumulative (shipments + programs)
    total_shipped: dict = field(default_factory=dict) # resource -> units shipped
    program_ticks: int = 0                            # ticks where programs ran
    events: dict = field(default_factory=dict)        # event_name -> tick first occurred
    history: list = field(default_factory=list)       # list of snapshot dicts
    # Rolling credit income tracking (last 50 ticks)
    _credit_gains: list = field(default_factory=list)
    completed_research: list = field(default_factory=list)   # list of research IDs purchased
    cumulative_science_earned: float = 0.0                   # monotonically increasing

    # ── Demand state ──────────────────────────────────────────────────────────
    demand: dict = field(default_factory=dict)                    # resource -> float [0.01, 1.0]
    demand_promote: dict = field(default_factory=dict)            # resource -> float accumulator
    demand_rival: dict = field(default_factory=dict)              # resource -> float accumulator
    demand_launch: dict = field(default_factory=dict)             # resource -> float accumulator
    demand_perlin_seeds: dict = field(default_factory=dict)       # resource -> float offset
    demand_perlin_freq: dict = field(default_factory=dict)        # resource -> float
    speculator_count: float = 0.0
    speculator_target: str = ""
    speculator_burst_number: int = 0
    speculator_next_burst_tick: int = 200
    speculator_revenue_tracking: dict = field(default_factory=dict)
    rival_next_dump_tick: dict = field(default_factory=dict)      # rival_id -> tick
    _rng: random.Random = field(default_factory=lambda: random.Random(42))


def init_state() -> EconState:
    """Create a fresh run-1 starting state."""
    state = EconState()
    state.resources = dict(STARTING_RESOURCES)
    state.buildings = {k: v.starts_with for k, v in BUILDINGS.items()}

    # Free land comes directly from starting_resources; land_purchased starts at 0
    # so purchase cost scaling reflects actual purchases, not starting land.
    state.land_purchased = 0
    state.resources["land"] = float(STARTING_RESOURCES.get("land", 0))

    initialize_demand(state)
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
        # Assign based on loading priority order
        res = state.loading_priority[pad_idx % len(state.loading_priority)] if state.loading_priority else "he3"
        state.pads_assigned[pad_idx] = res
        state.pads_cargo[pad_idx] = 0.0
        state.pads_cooldown[pad_idx] = 0

    return costs


def can_afford_command(state: EconState, short_name: str) -> bool:
    cmd = PURCHASABLE_COMMANDS.get(short_name)
    if cmd is None:
        return False
    for res, cost in cmd["costs"].items():
        if state.resources.get(res, 0) < cost:
            return False
    return True


def execute_command(state: EconState, short_name: str) -> dict:
    """Execute one instance of a buy_* command. Returns cost dict."""
    cmd = PURCHASABLE_COMMANDS[short_name]
    for res, cost in cmd["costs"].items():
        state.resources[res] = state.resources.get(res, 0.0) - cost
    for res, amt in cmd["production"].items():
        state.resources[res] = state.resources.get(res, 0.0) + amt
    return dict(cmd["costs"])


def buy_land(state: EconState) -> float:
    """Deduct credit cost, add LAND_PER_PURCHASE land. Returns credits spent."""
    from constants import LAND_PER_PURCHASE
    cost = get_land_cost(state)
    state.resources["cred"] -= cost
    state.resources["land"] += float(LAND_PER_PURCHASE)
    state.land_purchased += 1
    return cost


# ============================================================================
# DEMAND SYSTEM
# ============================================================================

def _hash_noise(i: int) -> float:
    """Deterministic integer hash → [0, 1]. Matches GDScript _hash_noise."""
    x = (i * 1664525 + 1013904223) & 0x7FFFFFFF
    x = (x ^ (x >> 16)) & 0x7FFFFFFF
    return float(x) / float(0x7FFFFFFF)


def _perlin_1d(t: float) -> float:
    """1D value noise returning [-1, 1]. Matches GDScript _perlin_1d."""
    xi = int(math.floor(t))
    xf = t - math.floor(t)
    u = xf * xf * (3.0 - 2.0 * xf)          # smoothstep
    a = _hash_noise(xi) * 2.0 - 1.0           # remap [0,1] → [-1,1]
    b = _hash_noise(xi + 1) * 2.0 - 1.0
    return a + (b - a) * u                     # lerp


def initialize_demand(state: EconState, seed: int = 42) -> None:
    """Set up per-resource Perlin seeds/freqs, rival timers, and burst timer.
    Uses a fixed seed so sim runs are reproducible (values differ from GDScript
    since Python's RNG differs, but the system is structurally identical).
    """
    state._rng = random.Random(seed)
    cfg = DEMAND_CFG
    freq_min = float(cfg.get("perlin_freq_min", 0.005))
    freq_max = float(cfg.get("perlin_freq_max", 0.015))
    burst_min = int(cfg.get("speculator_burst_interval_min", 150))
    burst_max = int(cfg.get("speculator_burst_interval_max", 250))

    for res in TRADEABLE:
        state.demand_perlin_seeds[res] = state._rng.random() * 100.0
        state.demand_perlin_freq[res]  = state._rng.uniform(freq_min, freq_max)
        state.demand_promote[res]      = 0.0
        state.demand_rival[res]        = 0.0
        state.demand_launch[res]       = 0.0
        state.demand[res]              = 0.5
        state.speculator_revenue_tracking[res] = 0.0

    for rival in RIVALS:
        rid = rival.get("id", "")
        if rid:
            state.rival_next_dump_tick[rid] = state._rng.randint(150, 250)

    state.speculator_next_burst_tick = state._rng.randint(burst_min, burst_max)

    # Compute initial demand values at tick 0
    _tick_demand_update(state)


def _tick_demand_update(state: EconState) -> None:
    """Decay accumulators and recompute live demand for each tradeable resource."""
    cfg = DEMAND_CFG
    spec_count  = state.speculator_count
    spec_target = state.speculator_target
    max_sup       = float(cfg.get("speculator_max_suppression", 0.5))
    half_pt       = float(cfg.get("speculator_half_point", 50.0))
    amplitude     = float(cfg.get("perlin_amplitude", 0.15))
    promote_decay = float(cfg.get("promote_decay_rate", 0.001))
    rival_decay   = float(cfg.get("rival_demand_decay_rate", 0.003))
    launch_decay  = float(cfg.get("launch_saturation_decay_rate", 0.005))
    min_d         = float(cfg.get("min_demand", 0.01))
    max_d         = float(cfg.get("max_demand", 1.0))
    coupling      = float(cfg.get("coupling_fraction", 0.10))

    # Speculator suppression magnitude on the target resource
    spec_sup_on_target = 0.0
    if spec_target and spec_count > 0.0:
        spec_sup_on_target = max_sup * (spec_count / (spec_count + half_pt))

    for res in TRADEABLE:
        # Decay accumulators
        state.demand_promote[res] = max(0.0, state.demand_promote.get(res, 0.0) - promote_decay)
        state.demand_rival[res]   = max(0.0, state.demand_rival.get(res, 0.0)   - rival_decay)
        state.demand_launch[res]  = max(0.0, state.demand_launch.get(res, 0.0)  - launch_decay)

        # Perlin base demand centered on 0.5
        t = float(state.tick) * state.demand_perlin_freq.get(res, 0.01) + state.demand_perlin_seeds.get(res, 0.0)
        base_demand = 0.5 + _perlin_1d(t) * amplitude

        # Per-resource speculator suppression
        spec_sup = spec_sup_on_target if spec_target == res else 0.0

        # Coupling: other resources get a small lift when one is suppressed
        coupling_bonus = 0.0
        if spec_target and spec_target != res:
            coupling_bonus = spec_sup_on_target * coupling / 3.0

        # Nationalist ideology bonus (stub — rank 0 until ideology system lands)
        nationalist_mult = 1.0

        raw = (base_demand
               - spec_sup
               - state.demand_rival.get(res, 0.0)
               - state.demand_launch.get(res, 0.0)
               + state.demand_promote.get(res, 0.0)
               + coupling_bonus)
        state.demand[res] = max(min_d, min(max_d, raw * nationalist_mult))


def _pick_speculator_target(state: EconState) -> str:
    """Choose a resource to target, weighted by recent revenue (falls back to random)."""
    total = sum(state.speculator_revenue_tracking.get(res, 0.0) for res in TRADEABLE)
    if total <= 0.0:
        return state._rng.choice(TRADEABLE)
    roll = state._rng.random() * total
    cumulative = 0.0
    for res in TRADEABLE:
        cumulative += state.speculator_revenue_tracking.get(res, 0.0)
        if roll <= cumulative:
            return res
    return TRADEABLE[0]


def _fire_speculator_burst(state: EconState) -> None:
    cfg = DEMAND_CFG
    state.speculator_target = _pick_speculator_target(state)
    size_min = int(cfg.get("speculator_burst_size_min", 20))
    size_max = int(cfg.get("speculator_burst_size_max", 50))
    growth   = float(cfg.get("speculator_burst_growth", 1.1))
    burst    = float(state._rng.randint(size_min, size_max)) * (growth ** state.speculator_burst_number)
    state.speculator_count += burst
    for res in TRADEABLE:
        state.speculator_revenue_tracking[res] = 0.0
    int_min = int(cfg.get("speculator_burst_interval_min", 150))
    int_max = int(cfg.get("speculator_burst_interval_max", 250))
    state.speculator_next_burst_tick = state.tick + state._rng.randint(int_min, int_max)
    state.speculator_burst_number += 1


def _tick_speculators(state: EconState) -> None:
    """Decay speculator count; fire a burst if the scheduled tick has arrived."""
    cfg = DEMAND_CFG
    active_arb = state.buildings.get("arbitrage_engine", 0)
    decay = (float(cfg.get("speculator_natural_decay", 0.15))
             + active_arb * float(cfg.get("arbitrage_decay_bonus_per_building", 0.04)))
    state.speculator_count = max(0.0, state.speculator_count - decay)
    if state.tick >= state.speculator_next_burst_tick:
        _fire_speculator_burst(state)


def _tick_rivals(state: EconState) -> None:
    """Check each rival; if their dump timer has expired, apply a demand hit."""
    for rival in RIVALS:
        rid = rival.get("id", "")
        if not rid:
            continue
        if state.tick >= state.rival_next_dump_tick.get(rid, 0):
            target_res = rival.get("target_resource", "")
            hit = float(rival.get("demand_hit", 0.3))
            state.demand_rival[target_res] = state.demand_rival.get(target_res, 0.0) + hit
            imin = int(rival.get("dump_interval_min", 150))
            imax = int(rival.get("dump_interval_max", 250))
            state.rival_next_dump_tick[rid] = state.tick + state._rng.randint(imin, imax)


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
    """Per-building tick: skip upkeep+production if all outputs are at cap."""
    for key, count in state.buildings.items():
        if count <= 0:
            continue
        bdef = BUILDINGS[key]

        # Build full output dict (energy + non-energy)
        all_outputs: dict = dict(bdef.production)
        if bdef.energy_production > 0:
            all_outputs["eng"] = bdef.energy_production

        # If building has outputs and ALL are at cap, skip entirely
        if all_outputs:
            all_at_cap = True
            for res in all_outputs:
                cap = get_cap(state, res)
                if cap is None or state.resources.get(res, 0.0) < cap:
                    all_at_cap = False
                    break
            if all_at_cap:
                continue

            # Input-starvation: skip if any upkeep resource is insufficient
            starved = any(
                state.resources.get(res, 0.0) < rate * count
                for res, rate in bdef.upkeep.items()
            )
            if not starved and bdef.energy_upkeep > 0:
                starved = state.resources.get("eng", 0.0) < bdef.energy_upkeep * count
            if starved:
                continue

        # Apply energy delta for this building
        energy_delta = bdef.energy_production - bdef.energy_upkeep
        if energy_delta != 0:
            state.resources["eng"] = state.resources.get("eng", 0.0) + energy_delta * count

        # Apply non-energy production and upkeep
        for res, rate in bdef.production.items():
            delta = rate * count
            state.resources[res] = state.resources.get(res, 0.0) + delta
            if res == "sci":
                state.cumulative_science_earned += delta
        for res, rate in bdef.upkeep.items():
            state.resources[res] = state.resources.get(res, 0.0) - rate * count

    # Clamp energy after all buildings processed
    energy_cap = get_cap(state, "eng")
    if energy_cap is not None:
        state.resources["eng"] = min(state.resources["eng"], energy_cap)
    state.resources["eng"] = max(0.0, state.resources["eng"])


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

        # Load pads — one pad per execution, first eligible by priority
        n_p = num_pads(state)
        if n_p > 0:
            load_amt = PAD_LOAD_PER_COMMAND
            for res in state.loading_priority:
                for i in range(n_p):
                    if state.pads_cooldown.get(i, 0) > 0:
                        continue  # pad on cooldown
                    if state.pads_assigned.get(i, "he3") != res:
                        continue
                    cargo = state.pads_cargo.get(i, 0.0)
                    if cargo >= PAD_CARGO_CAPACITY:
                        continue  # pad already full
                    avail = state.resources.get(res, 0.0)
                    space = PAD_CARGO_CAPACITY - cargo
                    loaded = min(load_amt, avail, space)
                    if loaded > 0:
                        state.pads_cargo[i] = cargo + loaded
                        state.resources[res] -= loaded
                    break  # one pad per execution
                else:
                    continue
                break  # found a pad for this resource priority


def _tick_pad_cooldowns(state: EconState) -> None:
    """Decrement pad cooldowns; pads at 0 cooldown are available again."""
    for i in list(state.pads_cooldown.keys()):
        if state.pads_cooldown[i] > 0:
            state.pads_cooldown[i] -= 1


def _tick_shipments(state: EconState) -> None:
    """Launch all full pads if propellant available; apply demand saturation hit."""
    cfg = DEMAND_CFG
    sat_min = float(cfg.get("launch_saturation_min", 0.10))
    sat_max = float(cfg.get("launch_saturation_max", 0.20))

    n_p = num_pads(state)
    if n_p == 0:
        return
    for i in range(n_p):
        if state.pads_cooldown.get(i, 0) > 0:
            continue  # pad on cooldown
        cargo = state.pads_cargo.get(i, 0.0)
        if cargo >= PAD_CARGO_CAPACITY:
            if state.resources.get("prop", 0) >= LAUNCH_FUEL_COST:
                res = state.pads_assigned.get(i, "he3")
                base_val = TRADE_BASE_VALUES.get(res, 1.0)
                demand   = state.demand.get(res, DEMAND_BASELINE)
                payout   = base_val * demand * cargo
                state.resources["cred"] = state.resources.get("cred", 0.0) + payout
                state.total_credits_earned += payout
                state.resources["prop"] = state.resources.get("prop", 0.0) - LAUNCH_FUEL_COST
                state.total_shipped[res] = state.total_shipped.get(res, 0.0) + cargo
                # Saturation hit — proportional to fill fraction (always 1.0 here)
                sat_hit = state._rng.uniform(sat_min, sat_max) * (cargo / PAD_CARGO_CAPACITY)
                state.demand_launch[res] = state.demand_launch.get(res, 0.0) + sat_hit
                # Revenue tracking for speculator target selection
                state.speculator_revenue_tracking[res] = (
                    state.speculator_revenue_tracking.get(res, 0.0) + payout
                )
                state.pads_cargo[i] = 0.0
                state.pads_cooldown[i] = LAUNCH_COOLDOWN_TICKS


def _record_events(state: EconState) -> None:
    """Record named events the first time their condition becomes true.

    Only events that cannot be recovered by scanning history are tracked here —
    specifically those tied to state that isn't captured in snapshots.
    Building/resource conditions are resolved by check_objectives() via history.
    """
    ev = state.events
    # shipment_complete: total_shipped is cumulative but not in snapshots
    if "shipment_complete" not in ev and sum(state.total_shipped.values()) > 0:
        ev["shipment_complete"] = state.tick
    # boredom_100: detectable from history but cheap to track here too
    if "boredom_100" not in ev and state.resources.get("boredom", 0) >= 100:
        ev["boredom_100"] = state.tick


def check_objectives(state: EconState, objectives: list) -> dict:
    """Evaluate scenario objectives against run history and events.

    Returns {obj_id: tick_first_satisfied} for satisfied objectives,
    {obj_id: None} for objectives not yet hit.

    Objective types:
      "building"  — first tick where buildings[value] >= 1
      "resource"  — first tick where resource[value] >= threshold
      "event"     — tick recorded in state.events[value]

    Requires state.history (record_history=True in tick_once) for
    building and resource objectives.
    """
    result: dict = {}
    for obj in objectives:
        otype = obj["type"]
        oid   = obj["id"]

        if otype == "event":
            result[oid] = state.events.get(obj["value"])

        elif otype == "building":
            key      = obj["value"]
            required = obj.get("count", 1)
            tick = None
            for snap in state.history:
                if snap.get("buildings", {}).get(key, 0) >= required:
                    tick = snap["tick"]
                    break
            # Fallback: check current state if history is incomplete
            if tick is None and state.buildings.get(key, 0) >= required:
                tick = state.tick
            result[oid] = tick

        elif otype == "resource":
            res       = obj["value"]
            threshold = obj.get("threshold", 1)
            tick = None
            for snap in state.history:
                if snap.get(res, 0) >= threshold:
                    tick = snap["tick"]
                    break
            if tick is None and state.resources.get(res, 0) >= threshold:
                tick = state.tick
            result[oid] = tick

        else:
            result[oid] = None

    return result


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
    snap["total_credits_earned"] = state.total_credits_earned
    # Include live demand for analysis
    snap["demand"] = {res: state.demand.get(res, DEMAND_BASELINE) for res in TRADEABLE}
    snap["speculator_count"] = state.speculator_count
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
    _tick_pad_cooldowns(state)
    # Demand update before programs/shipments so payout uses fresh demand values
    _tick_demand_update(state)
    _tick_programs(state)
    if state.tick % LAUNCH_CHECK_INTERVAL == 0:
        _tick_shipments(state)
    # Rival dumps and speculator bursts modify demand accumulators for the next tick
    _tick_rivals(state)
    _tick_speculators(state)
    clamp_resources(state)
    _record_events(state)
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
    s.pads_cooldown = dict(state.pads_cooldown)
    s.loading_priority = list(state.loading_priority)
    s.total_credits_earned = state.total_credits_earned
    s.total_shipped = dict(state.total_shipped)
    s.program_ticks = state.program_ticks
    s.events = dict(state.events)
    s.completed_research = list(state.completed_research)
    s.cumulative_science_earned = state.cumulative_science_earned
    # Demand state
    s.demand = dict(state.demand)
    s.demand_promote = dict(state.demand_promote)
    s.demand_rival = dict(state.demand_rival)
    s.demand_launch = dict(state.demand_launch)
    s.demand_perlin_seeds = dict(state.demand_perlin_seeds)
    s.demand_perlin_freq = dict(state.demand_perlin_freq)
    s.speculator_count = state.speculator_count
    s.speculator_target = state.speculator_target
    s.speculator_burst_number = state.speculator_burst_number
    s.speculator_next_burst_tick = state.speculator_next_burst_tick
    s.speculator_revenue_tracking = dict(state.speculator_revenue_tracking)
    s.rival_next_dump_tick = dict(state.rival_next_dump_tick)
    s._rng = copy.copy(state._rng)
    # Intentionally omit history and _credit_gains — not needed for scoring
    return s


def sim_forward(
    state: EconState,
    n_ticks: int,
    buy_policy=None,
    record_history: bool = False,
) -> EconState:
    """
    Return a copy of state advanced by n_ticks.
    Uses a fast clone when record_history=False (for scoring lookaheads).

    buy_policy: optional callable(state) -> None called once per tick after
    tick_once. Used for sighted lookahead scoring in the optimizer.
    """
    s = _clone_for_scoring(state) if not record_history else copy.deepcopy(state)
    for _ in range(n_ticks):
        tick_once(s, record_history=record_history)
        if s.resources.get("boredom", 0) >= 100:
            break
        if buy_policy is not None:
            buy_policy(s)
    return s
