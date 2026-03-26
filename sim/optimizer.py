from __future__ import annotations
"""
Helium Hustle -- Greedy economic optimizer.

At each tick where an action is affordable, scores all feasible options and
picks the highest-scoring one.

Score = marginal credits (sighted lookahead baseline) + shadow_delta x SHADOW_WEIGHT

Shadow pricing: building value is derived from tradeable good prices, so
production buildings score positively without hand-tuned urgency numbers.

Sighted lookahead: the baseline sim_forward runs a buy_policy that makes
purchases during the lookahead window, capturing chain value. Marginal then
measures "buying now vs the sighted baseline buying it later."

Simplified urgency is kept only for four cases where shadow price is 0 but
the building is genuinely critical: land scarcity, solar energy emergency,
first ice extractor, and first launch pad.

Action space: buy_building(key) for any building, or buy_land.
Between purchase decisions, the fixed command policy runs (cloud compute /
program / shipments). One purchase per tick maximum.
"""

import copy
from typing import Optional

from constants import (
    BUILDINGS, LOOKAHEAD_TICKS, MAX_RUN_TICKS, SNAPSHOT_TICKS,
    TRADE_BASE_VALUES, DEMAND_BASELINE, PURCHASABLE_COMMANDS,
    LAUNCH_FUEL_COST,
    SHADOW_PRICES, BUILDING_SHADOW_DELTAS, SHADOW_WEIGHT,
)
from economy import (
    EconState, init_state, tick_once, sim_forward, take_snapshot,
    get_building_cost, get_land_cost, get_net_energy, get_energy_production, get_energy_upkeep,
    get_cap, can_afford_building, can_afford_land, can_afford_command,
    buy_building, buy_land, execute_command, num_processors, num_pads,
    _clone_for_scoring,
)


# ============================================================================
# FEASIBLE ACTION ENUMERATION
# ============================================================================

def get_feasible_actions(state: EconState) -> list[tuple[str, Optional[str]]]:
    """Return all currently affordable (action_type, arg) pairs.

    Buildings that would push net energy below 0 are excluded — buying such a
    building would stall cloud compute income and is never actually desirable.
    """
    actions = []
    current_net_e = get_net_energy(state)
    for key in BUILDINGS:
        if can_afford_building(state, key):
            bdef = BUILDINGS[key]
            net_after = current_net_e + bdef.energy_production - bdef.energy_upkeep
            # Block high-upkeep buildings (fabricator=5, data_center=4) if they
            # would push net energy negative — this stalls cloud compute income.
            # Low-upkeep buildings (smelter=3, refinery=3) are allowed even with
            # a small deficit since the energy cap provides a buffer.
            if bdef.energy_upkeep >= 4 and net_after < 0:
                continue
            actions.append(("build", key))
    if can_afford_land(state):
        actions.append(("buy_land", None))
    for sn in PURCHASABLE_COMMANDS:
        if can_afford_command(state, sn):
            actions.append(("command", sn))
    return actions


# ============================================================================
# SIGHTED LOOKAHEAD BUY POLICY
# ============================================================================

def _shadow_buy_policy(state: EconState) -> None:
    """
    Sighted lookahead purchase policy: buy the best affordable building whose
    shadow delta is positive, subject to energy and cap constraints.
    Also buys land proactively when free land is low, and solar panels when
    energy is negative (so the rest of the policy can function).
    Called once per tick inside sim_forward during scoring lookaheads.
    """
    net_e = get_net_energy(state)
    free_land = state.resources.get("land", 0)

    # Fix energy deficit before anything else: buy solar if affordable and needed
    if net_e < 2 and can_afford_building(state, "panel"):
        bdef = BUILDINGS["panel"]
        if net_e + bdef.energy_production - bdef.energy_upkeep >= 2:
            buy_building(state, "panel")
            return

    # Proactively buy land when supply is low and we can afford it
    if free_land <= 10 and can_afford_land(state):
        buy_land(state)
        return

    best_key: Optional[str] = None
    best_delta: float = 0.0

    for key, delta in BUILDING_SHADOW_DELTAS.items():
        if delta <= 0:
            continue
        if not can_afford_building(state, key):
            continue
        bdef = BUILDINGS[key]
        # Don't buy if it would push net energy below +2 (preserve cloud-compute buffer)
        if net_e - bdef.energy_upkeep + bdef.energy_production < 2:
            continue
        # Don't buy if primary output resource is near cap (>80% full)
        capped = False
        for res, rate in bdef.production.items():
            if res == "eng":
                continue
            cap = get_cap(state, res)
            if cap and state.resources.get(res, 0.0) / cap > 0.80:
                capped = True
                break
        if capped:
            continue
        # Don't buy electrolysis if it would prevent ice accumulation for fabricator
        # (electrolysis consumes 2 ice/tick; if ice_net <= 0 and no fabricator yet,
        # the ice needed to build fabricator can never accumulate)
        if key == "electrolysis":
            n_fab = state.buildings.get("fabricator", 0)
            if n_fab == 0:
                n_elec_existing = state.buildings.get("electrolysis", 0)
                n_ice_ext = state.buildings.get("ice_extractor", 0)
                # Allow at most enough electrolysis that ice still accumulates
                if n_elec_existing * 2 >= n_ice_ext * 1:
                    continue
        if delta > best_delta:
            best_key, best_delta = key, delta

    if best_key is not None:
        buy_building(state, best_key)


# ============================================================================
# URGENCY BONUSES  (simplified -- only 4 cases where shadow price = 0)
# ============================================================================

def _urgency_bonus(state: EconState, action_type: str, action_arg: Optional[str]) -> float:
    """
    Simplified urgency bonuses for buildings where shadow_delta is 0 but the
    building is a critical infrastructure enabler.

    Only 4 cases are handled:
      - buy_land: land scarcity is a hard constraint
      - panel:    energy emergency (eng has no shadow price)
      - ice_extractor: enables fabricator/electrolysis chain (zero shadow delta)
      - launch_pad:    enables shipments (infra only, zero shadow delta)
    """
    res = state.resources
    free_land = res.get("land", 0)

    # Land: critical constraint (10 land per purchase, so thresholds scaled up)
    if action_type == "buy_land":
        if free_land <= 2:
            return 110
        if free_land <= 5:
            return 70
        if free_land <= 10:
            return 25
        return 5

    if action_type != "build":
        return 0.0

    key = action_arg
    net_e = get_net_energy(state)
    n_ice = state.buildings.get("ice_extractor", 0)
    n_excavators = state.buildings.get("excavator", 0)

    # Solar: energy emergency only (shadow price of eng is 0 so it needs a nudge)
    if key == "panel":
        if net_e < 0:
            return 350
        if net_e < 2.0 and get_energy_upkeep(state) > 2.0:
            return 200
        return 0.0

    # Excavator: produces reg which is required by smelter/refinery upkeep and as
    # build cost. Zero shadow delta but critical infra.
    # Urgency fires when reg-consumers exist and net reg production <= 0,
    # meaning we can't accumulate reg for build costs.
    if key == "excavator":
        n_smelters = state.buildings.get("smelter", 0)
        n_refineries = state.buildings.get("refinery", 0)
        # reg production per tick: 2 per excavator
        # reg consumption per tick: 2 per smelter + 2 per refinery
        reg_net = n_excavators * 2 - n_smelters * 2 - n_refineries * 2
        if reg_net <= 0 and (n_smelters >= 1 or n_refineries >= 1):
            # No net reg accumulation — need more excavators
            return 120
        # First excavator if we somehow don't have one
        if n_excavators == 0:
            return 80
        return 0.0

    # Ice extractor: enables fabricator/electrolysis but has zero shadow delta.
    # Urgency fires whenever ice consumption (2 per electrolysis) exceeds ice
    # production (1 per extractor) and fabricator hasn't been built yet.
    if key == "ice_extractor":
        n_elec = state.buildings.get("electrolysis", 0)
        n_fabricators = state.buildings.get("fabricator", 0)
        if n_ice == 0 and n_excavators >= 1:
            return 150
        # More extractors needed when electrolysis drains ice faster than production
        ice_net = n_ice * 1 - n_elec * 2
        if ice_net <= 0 and n_fabricators == 0:
            # Ice never accumulates — can't build fabricator without ice=5
            return 120
        return 0.0

    # Storage depot: urgency fires when any capped resource is blocking a
    # building purchase. Specifically:
    #   - cir at cap and an unaffordable building requires more cir than cap
    #     (e.g. data_center x2 needs 10.8 cir but cap is 10)
    #   - he3 at cap (shipments can't fill pads if stockpile can't grow)
    if key == "storage_depot":
        for res in ("cir", "he3", "ti"):
            cap = get_cap(state, res)
            if cap is None:
                continue
            if state.resources.get(res, 0) < cap * 0.85:
                continue  # not near cap — no urgency from this resource
            # Check if any building purchase needs more of this resource than cap allows
            for bkey, bdef in BUILDINGS.items():
                if not bdef.base_cost_resources.get(res):
                    continue  # this building doesn't cost this resource
                bcosts = get_building_cost(state, bkey)
                if bcosts.get(res, 0) > cap:
                    return 100  # cap is literally blocking next purchase
        return 0.0

    # Launch pad: hard-coded high priority — first pad is M2 critical path.
    # Beats most production buildings (which score ~180) once a refinery exists.
    if key == "launch_pad":
        n_p = num_pads(state)
        if n_p == 0:
            if state.buildings.get("refinery", 0) > 0:
                return 300  # he3 producing but nowhere to send it
            if num_processors(state) > 0:
                return 200  # processor running, pad loading possible
        return 0.0

    return 0.0


def _objective_urgency(
    state: EconState,
    action_type: str,
    action_arg: Optional[str],
    objectives: list,
) -> float:
    """
    Urgency bonus derived from scenario objectives not yet satisfied.

    For each building objective where the current count is below the required
    count, adds urgency scaled to how far through the target window we are:
      - Before window: small nudge so the optimizer doesn't ignore it entirely
      - Inside window: moderate pressure to build it now
      - Past deadline: high pressure to build it ASAP

    This makes the scenario file the source of truth for what matters — no
    need to hardcode each building's importance in the optimizer itself.
    """
    if action_type != "build" or not objectives:
        return 0.0
    for obj in objectives:
        if obj.get("type") != "building":
            continue
        if obj.get("value") != action_arg:
            continue
        required = obj.get("count", 1)
        if state.buildings.get(action_arg, 0) >= required:
            continue  # already satisfied
        lo, hi = obj["target"]
        t = state.tick
        if t > hi:
            return 150.0   # past deadline — high urgency
        elif t >= lo:
            return 80.0    # inside window — moderate pressure
        else:
            return 40.0    # approaching window — light nudge
    return 0.0


# ============================================================================
# ACTION SCORING
# ============================================================================

def _cap_adjusted_shadow_delta(state: EconState, key: str) -> float:
    """
    Shadow delta adjusted for current resource cap saturation.

    If a building's primary output is near cap, its effective ongoing value
    is reduced — a smelter producing ti into a full ti stockpile earns nothing.
    Scales linearly from full value at 80% fill to zero at 100% fill.

    This prevents capped-resource buildings from scoring 180+ and grabbing
    land slots away from uncapped high-value buildings like fabricator.
    """
    from constants import SHADOW_PRICES
    bdef = BUILDINGS[key]
    delta = 0.0
    for res, rate in bdef.production.items():
        if res == "eng":
            continue
        shadow = SHADOW_PRICES.get(res, 0.0)
        if shadow == 0.0:
            continue
        cap = get_cap(state, res)
        if cap and cap > 0:
            fill = state.resources.get(res, 0.0) / cap
            # Full value below 80% fill; ramps to 0 between 80%-100%
            multiplier = max(0.0, 1.0 - max(0.0, fill - 0.8) / 0.2)
        else:
            multiplier = 1.0
        delta += shadow * rate * multiplier
    for res, rate in bdef.upkeep.items():
        if res == "eng":
            continue
        delta -= SHADOW_PRICES.get(res, 0.0) * rate

    # For buildings whose value comes from effects rather than production
    # (e.g. data_center grants a proc), fall back to the precomputed delta.
    precomputed = BUILDING_SHADOW_DELTAS.get(key, 0.0)
    if delta == 0.0 and precomputed > 0.0:
        delta = precomputed

    return delta


def score_action_with_baseline(
    state: EconState,
    action_type: str,
    action_arg: Optional[str],
    base_credits: float,
    objectives: list = None,
    lookahead: int = LOOKAHEAD_TICKS,
) -> tuple[float, float]:
    """
    Score one action.

    Baseline is the sighted lookahead (buy_policy runs during sim_forward),
    so marginal = "how much more do I earn by buying action NOW vs the
    sighted baseline buying it later?"

    Shadow component: cap-adjusted shadow_delta x SHADOW_WEIGHT captures
    ongoing production value beyond the lookahead window, but zeroes out
    when the output resource is already at storage cap.

    Urgency includes both hardcoded infrastructure bonuses (_urgency_bonus)
    and scenario-objective bonuses (_objective_urgency).

    Returns (total_score, marginal_credits).
    """
    test = _clone_for_scoring(state)
    shadow_delta = 0.0
    if action_type == "build":
        shadow_delta = _cap_adjusted_shadow_delta(state, action_arg)
        buy_building(test, action_arg)
    elif action_type == "command":
        execute_command(test, action_arg)
    else:
        buy_land(test)

    after = sim_forward(test, lookahead, buy_policy=_shadow_buy_policy)
    marginal = after.total_credits_earned - base_credits
    urgency = (
        _urgency_bonus(state, action_type, action_arg)
        + _objective_urgency(state, action_type, action_arg, objectives or [])
    )
    return marginal + shadow_delta * SHADOW_WEIGHT + urgency, marginal


# ============================================================================
# PAYBACK PERIOD ESTIMATION
# ============================================================================

def estimate_payback(credits_cost: float, marginal_lookahead_delta: float, lookahead: int) -> Optional[float]:
    """Estimate ticks to recoup the credit cost from marginal income alone."""
    if marginal_lookahead_delta <= 0 or credits_cost <= 0:
        return None
    income_per_tick = marginal_lookahead_delta / lookahead
    return credits_cost / income_per_tick


# ============================================================================
# GREEDY OPTIMIZER MAIN LOOP
# ============================================================================

def run_greedy(
    max_ticks: int = MAX_RUN_TICKS,
    debug_ticks: set = None,
    objectives: list = None,
) -> tuple[EconState, list[dict], dict]:
    """
    Run one greedy optimisation pass for a scenario.

    Each tick:
      1. Advance state by one tick (boredom, buildings, programs, shipments).
      2. Enumerate affordable actions.
      3. Score each; buy the highest-scoring one (if any).
      4. Halt when boredom >= 100 or max_ticks reached.

    Args:
        max_ticks:   hard cap on ticks simulated.
        debug_ticks: set of tick numbers at which to capture full scoring tables.
        objectives:  scenario objective list; passed to scoring so unsatisfied
                     building objectives receive urgency bonuses.

    Returns:
        state        -- final EconState with full history recorded
        build_log    -- list of purchase records:
                       {tick, action, key, cost, score, marginal_credits, payback_ticks}
        score_traces -- dict[tick -> trace_dict] for each tick in debug_ticks.
        snapshots    -- dict[tick -> snap_dict] at each SNAPSHOT_TICKS checkpoint.
    """
    _debug_ticks: set = set(debug_ticks or [])
    _objectives: list = objectives or []
    score_traces: dict[int, dict] = {}

    state = init_state()
    build_log: list[dict] = []
    snapshots: dict[int, dict] = {}

    for _tick in range(max_ticks):
        tick_once(state, record_history=True)

        # Record snapshots at designated ticks
        if state.tick in SNAPSHOT_TICKS:
            snapshots[state.tick] = take_snapshot(state)

        # Halt on retirement
        if state.resources.get("boredom", 0) >= 100:
            break

        # Evaluate purchase decisions
        feasible = get_feasible_actions(state)
        if not feasible:
            continue

        # Compute baseline ONCE for this tick using sighted lookahead
        baseline_result = sim_forward(state, LOOKAHEAD_TICKS, buy_policy=_shadow_buy_policy)
        base_credits = baseline_result.total_credits_earned

        # Score all feasible actions
        scored = []
        for action_type, action_arg in feasible:
            s, marginal = score_action_with_baseline(
                state, action_type, action_arg, base_credits, objectives=_objectives
            )
            scored.append((s, marginal, action_type, action_arg))

        scored.sort(key=lambda x: x[0], reverse=True)

        # Pick the best-scored positive action
        free_land = state.resources.get("land", 10)
        chosen = None
        for s, marginal, atype, aarg in scored:
            is_land_critical = (atype == "buy_land" and free_land <= 1)
            if s <= 0 and not is_land_critical:
                break
            chosen = (s, marginal, atype, aarg)
            break  # take the best-scored positive action

        # Save-for-goal filter: if a high-urgency building is blocked only by
        # credits (ti/land already available), suppress buys that score below
        # that urgency level so credits can accumulate.
        if chosen is not None:
            _SAVE_URGENCY_THRESHOLD = 200   # urgency level that triggers saving
            _SAVE_TICKS_HORIZON    = 120    # only save if reachable within this many ticks
            _SAVE_INCOME_EST       = 2.0    # conservative credit/tick estimate
            _SAVE_SUPPRESS_FRAC    = 0.70   # suppress buys scoring below this fraction
            _max_save_urgency = 0.0
            for _key in BUILDINGS:
                if can_afford_building(state, _key):
                    continue
                _urg = (_urgency_bonus(state, "build", _key)
                        + _objective_urgency(state, "build", _key, _objectives))
                if _urg < _SAVE_URGENCY_THRESHOLD:
                    continue
                # Check that only credits are blocking (ti, land, other resources all OK)
                _costs = get_building_cost(state, _key)
                _cred_gap = max(0.0, _costs.get("cred", 0) - state.resources.get("cred", 0))
                if _cred_gap / _SAVE_INCOME_EST > _SAVE_TICKS_HORIZON:
                    continue  # too far away even if we saved hard
                _non_cred_ok = (
                    _costs.get("_land", 0) <= free_land
                    and all(
                        state.resources.get(r, 0) >= amt
                        for r, amt in _costs.items()
                        if r not in ("cred", "_land")
                    )
                )
                if not _non_cred_ok:
                    continue
                if _urg > _max_save_urgency:
                    _max_save_urgency = _urg
            if _max_save_urgency >= _SAVE_URGENCY_THRESHOLD:
                if chosen[0] < _max_save_urgency * _SAVE_SUPPRESS_FRAC:
                    chosen = None  # save credits for the critical building

        # Land-competition patience filter: when land is tight (<=1 free) and the
        # chosen action uses a land slot, don't grab it if a higher-shadow-value
        # building is coming soon (within ~30 ticks of credit income).
        if chosen is not None:
            _atype, _aarg = chosen[2], chosen[3]
            _uses_land = (_atype == "build" and BUILDINGS[_aarg].land_cost > 0)
            if _uses_land and free_land <= 1:
                _PATIENCE = 30  # skip if better building affordable within this many ticks
                _income_est = max(1.0, 5.0)  # conservative: manual cloud compute baseline
                _best_upcoming = 0.0
                for _key in BUILDINGS:
                    if can_afford_building(state, _key):
                        continue
                    _costs = get_building_cost(state, _key)
                    _cred_gap = max(0.0, _costs.get("cred", 0) - state.resources.get("cred", 0))
                    if _cred_gap / _income_est > _PATIENCE:
                        continue  # too far away
                    # Only blocked by credits (all other resources including land are sufficient)
                    _non_cred_ok = (
                        _costs.get("_land", 0) <= free_land
                        and all(
                            state.resources.get(r, 0) >= amt
                            for r, amt in _costs.items()
                            if r not in ("cred", "_land")
                        )
                    )
                    if not _non_cred_ok:
                        continue
                    _upcoming_score = (
                        BUILDING_SHADOW_DELTAS.get(_key, 0.0) * SHADOW_WEIGHT
                        + _urgency_bonus(state, "build", _key)
                        + _objective_urgency(state, "build", _key, _objectives)
                    )
                    if _upcoming_score > _best_upcoming:
                        _best_upcoming = _upcoming_score
                if chosen[0] < _best_upcoming * 0.88:
                    chosen = None  # wait for the better building

        # Capture score trace BEFORE purchase (state is still pre-buy)
        if state.tick in _debug_ticks:
            # Compute urgency and threshold info for trace display
            max_upcoming_urgency = 0.0
            for key in BUILDINGS:
                if not can_afford_building(state, key):
                    urg = (_urgency_bonus(state, "build", key)
                           + _objective_urgency(state, "build", key, _objectives))
                    if urg > max_upcoming_urgency:
                        max_upcoming_urgency = urg
            save_threshold = 0.0  # no longer used in decision logic

            trace_actions = []
            for s, marginal, atype, aarg in scored:
                urg = (_urgency_bonus(state, atype, aarg)
                       + _objective_urgency(state, atype, aarg, _objectives))
                shadow = BUILDING_SHADOW_DELTAS.get(aarg, 0.0) if atype == "build" else 0.0
                is_lc = (atype == "buy_land" and free_land <= 1)
                passes = s > 0 or is_lc
                is_chosen = (chosen is not None and atype == chosen[2] and aarg == chosen[3])
                trace_actions.append({
                    "action_type": atype,
                    "action_arg":  aarg,
                    "score":       s,
                    "marginal":    marginal,
                    "urgency":     urg,
                    "passes":      passes,
                    "chosen":      is_chosen,
                })
            score_traces[state.tick] = {
                "save_threshold":       save_threshold,
                "max_upcoming_urgency": max_upcoming_urgency,
                "base_credits":         base_credits,
                "resources":            dict(state.resources),
                "buildings":            dict(state.buildings),
                "actions":              trace_actions,
                "chosen":               (chosen[2], chosen[3]) if chosen else None,
            }

        if chosen is None:
            continue

        best_score, best_marginal, best_type, best_arg = chosen
        land_critical = (best_type == "buy_land" and free_land <= 1)

        # Record cost before applying
        if best_type == "build":
            cost_dict = get_building_cost(state, best_arg)
            credits_cost = cost_dict.get("cred", 0.0)
        elif best_type == "command":
            cost_dict = dict(PURCHASABLE_COMMANDS[best_arg]["costs"])
            credits_cost = cost_dict.get("cred", 0.0)
        else:
            credits_cost = get_land_cost(state)
            cost_dict = {"cred": credits_cost}

        marginal_credits = best_marginal
        payback = estimate_payback(credits_cost, marginal_credits, LOOKAHEAD_TICKS)

        # Apply purchase
        if best_type == "build":
            buy_building(state, best_arg)
        elif best_type == "command":
            execute_command(state, best_arg)
        else:
            buy_land(state)

        if best_type == "build":
            label = BUILDINGS[best_arg].name
            count_after = state.buildings.get(best_arg, 0)
        elif best_type == "command":
            label = PURCHASABLE_COMMANDS[best_arg]["name"]
            count_after = None
        else:
            label = "Land"
            count_after = None
        urgency = (_urgency_bonus(state, best_type, best_arg)
                   + _objective_urgency(state, best_type, best_arg, _objectives))

        build_log.append({
            "tick": state.tick,
            "action": best_type,
            "key": best_arg,
            "label": label,
            "count_after": count_after,
            "cost": cost_dict,
            "credits_cost": credits_cost,
            "score": best_score,
            "urgency": urgency,
            "marginal_credits": marginal_credits,
            "payback_ticks": payback,
        })

    # Ensure snapshots for all requested ticks (use nearest history entry if
    # boredom ended before that tick)
    for target in SNAPSHOT_TICKS:
        if target not in snapshots:
            # Find closest recorded tick <= target
            candidates = [h for h in state.history if h["tick"] <= target]
            if candidates:
                snapshots[target] = candidates[-1]
            elif state.history:
                snapshots[target] = state.history[-1]

    return state, build_log, score_traces, snapshots
