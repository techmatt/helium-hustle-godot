from __future__ import annotations
"""
Helium Hustle — Greedy economic optimizer.

At each tick where an action is affordable, scores all feasible options and
picks the highest-scoring one. Score = marginal credits earned over a lookahead
window (no new purchases during lookahead) + urgency bonuses for infrastructure
whose value the pure credit lookahead undersells.

Action space: buy_building(key) for any building, or buy_land.
Between purchase decisions, the fixed command policy runs (cloud compute /
program / shipments). One purchase per tick maximum.
"""

import copy
from typing import Optional

from constants import (
    BUILDINGS, LOOKAHEAD_TICKS, MAX_RUN_TICKS, SNAPSHOT_TICKS,
    TRADE_BASE_VALUES, DEMAND_BASELINE, MILESTONE_TARGETS, PURCHASABLE_COMMANDS,
    LAUNCH_FUEL_COST,
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
    """Return all currently affordable (action_type, arg) pairs."""
    actions = []
    for key in BUILDINGS:
        if can_afford_building(state, key):
            actions.append(("build", key))
    if can_afford_land(state):
        actions.append(("buy_land", None))
    for sn in PURCHASABLE_COMMANDS:
        if can_afford_command(state, sn):
            actions.append(("command", sn))
    return actions


# ============================================================================
# URGENCY BONUSES
# ============================================================================

def _urgency_bonus(state: EconState, action_type: str, action_arg: Optional[str]) -> float:
    """
    Milestone-directed urgency bonuses.

    Priority ladder (approximate score levels):
      100+ data_center (M3 gate — critical)
       85  fabricator (step to data_center)
       80  excavator #1 (starts everything)
       70  smelter (titanium chain for DC)
       60  refinery (he3 for trade)
       55  launch pad (once DC chain is progressing)
       45  electrolysis (propellant / launch fuel)
       35  ice extractor
       25  solar (only when energy genuinely tight)
       20  storage depot (only with real consumers near cap)
       10  battery (tight energy with consumers)
        5  land buffer

    The save_threshold in run_greedy (0.6 × max_upcoming_urgency) means:
      - When smelter has urgency 70, threshold ≈ 42 → solar(25) blocked ✓
      - When fabricator has urgency 85, threshold ≈ 51 → storage(20) blocked ✓
      - When DC has urgency 100, threshold ≈ 60 → everything else blocked ✓
      - Land (70-110) always passes threshold ✓
    """
    bonus = 0.0
    res = state.resources
    net_e = get_net_energy(state)
    e_upkeep = get_energy_upkeep(state)
    free_land = res.get("land", 0)
    n_procs = num_processors(state)
    n_p = num_pads(state)
    he3 = res.get("he3", 0)
    titanium = res.get("ti", 0)
    circuits = res.get("cir", 0)
    regolith = res.get("reg", 0)
    propellant = res.get("prop", 0)

    n_excavators = state.buildings.get("excavator", 0)
    n_refineries = state.buildings.get("refinery", 0)
    n_ice = state.buildings.get("ice_extractor", 0)
    n_elec = state.buildings.get("electrolysis", 0)
    n_smelters = state.buildings.get("smelter", 0)
    n_fabricators = state.buildings.get("fabricator", 0)
    n_labs = state.buildings.get("research_lab", 0)

    # ── Purchasable commands (buy_titanium, etc.) ──
    if action_type == "command":
        key = action_arg
        cred = res.get("cred", 0)
        if key == "buy_titanium":
            # Early game: buy ti to unlock solar panels before smelter is online
            if n_smelters == 0:
                if titanium < 2:
                    bonus += 350  # can't build first panel yet — critical
                elif titanium < 4 and cred >= 26:
                    bonus += 200  # room for 2nd panel purchase soon
                elif titanium < 8:
                    bonus += 80   # modest stockpile building
            elif titanium < 4 and n_smelters > 0:
                bonus += 50   # smelter running but slow; bridge gap
        elif key == "buy_regolith":
            if regolith < 10 and (n_smelters == 0 or n_fabricators == 0):
                bonus += 60   # need reg to buy smelter or ice_extractor
        elif key == "buy_ice":
            if res.get("ice", 0) < 5 and n_fabricators == 0 and titanium >= 10:
                bonus += 150  # ti ready, just need ice to build fabricator
        elif key == "buy_propellant":
            if n_p > 0 and res.get("prop", 0) < LAUNCH_FUEL_COST and n_elec == 0:
                bonus += 100  # pad exists, no electrolysis, need fuel
        return bonus

    # ── Land: hard constraint, always dominant ──
    if action_type == "buy_land":
        if free_land <= 0:
            return 110
        elif free_land <= 1:
            return 70
        elif free_land <= 2:
            return 25
        return 5

    if action_type != "build":
        return 0.0

    key = action_arg

    # ──────────────────────────────────────────────────────────────────────────
    # DATA CENTER CHAIN: smelter → titanium → fabricator → circuits → DC
    # This is the critical path to M3 (and M2 via programs loading pads).
    # Scored highest so save_threshold blocks cheaper diversionary purchases.
    # ──────────────────────────────────────────────────────────────────────────

    if key == "data_center":
        if n_procs == 0:
            if circuits >= 5:
                bonus += 500  # resource gate passed — M3 critical
            elif circuits >= 3:
                bonus += 400
            elif n_fabricators > 0:
                bonus += 300  # fabricator running, circuits incoming
            elif n_smelters > 0:
                bonus += 150  # titanium chain started

    elif key == "fabricator":
        if n_fabricators == 0:
            if titanium >= 10 and circuits < 8:
                bonus += 400  # prereq met, build immediately
            elif n_smelters > 0 and titanium >= 5:
                bonus += 300  # smelter running, almost there
            elif n_smelters > 0:
                bonus += 200  # smelter running

    elif key == "smelter":
        if n_smelters == 0:
            if regolith >= 30 and n_excavators >= 1:
                bonus += 300  # regolith stocked, start titanium chain now
            elif regolith >= 10 and n_excavators >= 1:
                bonus += 250
            elif n_excavators >= 1:
                bonus += 100

    # ──────────────────────────────────────────────────────────────────────────
    # MINING BACKBONE: first excavator + energy start everything
    # ──────────────────────────────────────────────────────────────────────────

    elif key == "excavator":
        if n_excavators == 0:
            if net_e > 1.5:
                bonus += 80   # first excavator: start regolith production NOW
            else:
                bonus += 25
        elif n_excavators == 1 and n_smelters >= 1:
            bonus += 35       # smelter uses reg upkeep — second excavator keeps reg flowing
        elif n_excavators == 1 and net_e > 2.0:
            bonus += 20       # general second excavator
        elif n_excavators == 2 and net_e > 4.0:
            bonus += 15       # third: keeps up with multiple processors

    elif key == "panel":
        # Panel requires titanium — only affordable after smelter runs
        # Urgent when energy is net negative or very tight
        if net_e < 0:
            bonus += 350      # energy deficit: restore net positive immediately
        elif net_e < 2.0 and e_upkeep > 2.0:
            bonus += 200
        elif net_e < 4.0 and e_upkeep > 3.0:
            bonus += 100
        elif net_e < 6.0 and e_upkeep > 5.0:
            bonus += 50

    elif key == "battery":
        # Only valuable when energy consumers exist and cap is a real constraint
        if e_upkeep >= 4.0 and net_e < 4.0:
            energy_cap = get_cap(state, "energy")
            if energy_cap and res.get("energy", 0) >= energy_cap * 0.90:
                bonus += 10

    # ──────────────────────────────────────────────────────────────────────────
    # HE-3 / TRADE PIPELINE: refinery → he3 → launch pad → M2
    # Lower priority than DC chain but still important
    # ──────────────────────────────────────────────────────────────────────────

    elif key == "refinery":
        if n_refineries == 0:
            if n_smelters > 0 and regolith >= 15:
                bonus += 250  # M2 critical path — same tier as ice_extractor
            elif n_smelters > 0:
                bonus += 200
            elif n_excavators >= 1:
                bonus += 80

    elif key == "ice_extractor":
        if n_ice == 0 and n_excavators >= 1:
            # Critical path: ice_extractor → ice → fabricator → circuits → data_center
            if n_smelters > 0:
                bonus += 250  # smelter running, ice needed for fabricator ASAP
            else:
                bonus += 150  # build alongside smelter chain

    elif key == "electrolysis":
        if n_elec == 0:
            if n_p > 0 and propellant < 40:
                bonus += 55   # pad exists, no fuel — critical
            elif n_ice > 0 and net_e > 0.5:
                bonus += 35
            elif n_ice > 0:
                bonus += 15

    elif key == "launch_pad":
        # Only urgency once we're progressing toward the data center
        # (without programs, the pad never gets loaded)
        if n_p == 0:
            if n_procs > 0:
                bonus += 80   # DC exists, programs can load immediately
            elif n_fabricators > 0 and he3 >= 10:
                bonus += 55   # DC chain nearly done + he3 stocked
            elif n_smelters > 0 and he3 >= 20:
                bonus += 35   # titanium chain started + he3 stocked
            elif n_refineries > 0 and he3 >= 30:
                bonus += 20   # refinery running but DC not started yet

    # ──────────────────────────────────────────────────────────────────────────
    # STORAGE: only when active resources hit cap
    # ──────────────────────────────────────────────────────────────────────────

    elif key == "storage_depot":
        consumer_map = {
            "reg":  n_refineries > 0 or n_smelters > 0,
            "he3":  n_p > 0,
            "ice":  n_elec > 0,
            "ti":   n_smelters > 0,
            "prop": n_p > 0,
            "cir":  n_fabricators > 0 or n_procs > 0 or n_labs > 0,
        }
        cap_pressure = 0.0
        for r, has_consumer in consumer_map.items():
            if not has_consumer:
                continue
            cap_val = get_cap(state, r)
            if cap_val and cap_val > 0:
                fill = res.get(r, 0) / cap_val
                if fill > 0.85:
                    cap_pressure = max(cap_pressure, fill)
        if cap_pressure > 0.95:
            bonus += 25
        elif cap_pressure > 0.85:
            bonus += 15

    elif key == "research_lab":
        if n_labs == 0 and n_procs > 0 and circuits >= 3:
            bonus += 25

    return bonus


# ============================================================================
# ACTION SCORING
# ============================================================================

def score_action_with_baseline(
    state: EconState,
    action_type: str,
    action_arg: Optional[str],
    base_credits: float,
    lookahead: int = LOOKAHEAD_TICKS,
) -> tuple[float, float]:
    """
    Score one action given a pre-computed baseline credit total.

    Returns (total_score, marginal_credits) where:
      total_score      = marginal_credits + urgency_bonus
      marginal_credits = credits earned WITH action minus base_credits

    Accepts base_credits so the caller can compute baseline once and reuse
    it across all candidate actions — avoids redundant sim_forward calls.
    """
    test = _clone_for_scoring(state)
    if action_type == "build":
        buy_building(test, action_arg)
    elif action_type == "command":
        execute_command(test, action_arg)
    else:
        buy_land(test)
    after = sim_forward(test, lookahead)
    marginal = after.total_credits_earned - base_credits
    urgency = _urgency_bonus(state, action_type, action_arg)
    return marginal + urgency, marginal


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
) -> tuple[EconState, list[dict], dict]:
    """
    Run one greedy optimisation pass for run 1.

    Each tick:
      1. Advance state by one tick (boredom, buildings, programs, shipments).
      2. Enumerate affordable actions.
      3. Score each; buy the highest-scoring one (if any).
      4. Halt when boredom >= 100 or max_ticks reached.

    Args:
        max_ticks:   hard cap on ticks simulated.
        debug_ticks: set of tick numbers at which to capture full scoring
                     tables.  Returned as the third element (score_traces).

    Returns:
        state        — final EconState with full history recorded
        build_log    — list of purchase records:
                       {tick, action, key, cost, score, marginal_credits, payback_ticks}
        score_traces — dict[tick -> trace_dict] for each tick in debug_ticks.
                       Each trace_dict contains: save_threshold, max_upcoming_urgency,
                       base_credits, resources, buildings, actions (list), chosen.
    """
    _debug_ticks: set = set(debug_ticks or [])
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

        # Compute the maximum urgency of desired-but-NOT-yet-affordable buildings.
        # If an expensive, high-urgency building is almost within reach, we apply
        # a "saving threshold" so the optimizer doesn't fritter credits on low-value
        # cheap purchases that would delay the critical buy.
        max_upcoming_urgency = 0.0
        for key in BUILDINGS:
            if not can_afford_building(state, key):
                urg = _urgency_bonus(state, "build", key)
                if urg > max_upcoming_urgency:
                    max_upcoming_urgency = urg
        # Threshold: require affordable actions to score >= 60% of upcoming urgency
        # before we'll spend credits on them.  Land buys bypass this gate.
        save_threshold = max_upcoming_urgency * 0.6

        # Compute baseline ONCE for this tick (reused for all candidates)
        baseline_result = sim_forward(state, LOOKAHEAD_TICKS)
        base_credits = baseline_result.total_credits_earned

        # Score all feasible actions
        scored = []
        for action_type, action_arg in feasible:
            s, marginal = score_action_with_baseline(
                state, action_type, action_arg, base_credits
            )
            scored.append((s, marginal, action_type, action_arg))

        scored.sort(key=lambda x: x[0], reverse=True)

        # Walk the sorted list and pick the best-scored action that passes the
        # threshold.  Checking only scored[0] caused a deadlock: a tied or
        # slightly-higher action that fails the threshold would block a lower-
        # scored action whose urgency clears the threshold (e.g. panel blocking
        # ice_extractor, or buy_ice blocking ice_extractor).
        free_land = state.resources.get("land", 10)
        chosen = None
        for s, marginal, atype, aarg in scored:
            is_land_critical = (atype == "buy_land" and free_land <= 1)
            if s <= 0 and not is_land_critical:
                break
            urg = _urgency_bonus(state, atype, aarg)
            if is_land_critical or urg >= save_threshold or s >= save_threshold:
                chosen = (s, marginal, atype, aarg)
                break
        # Capture score trace BEFORE purchase (state is still pre-buy)
        if state.tick in _debug_ticks:
            trace_actions = []
            for s, marginal, atype, aarg in scored:
                urg = _urgency_bonus(state, atype, aarg)
                is_lc = (atype == "buy_land" and free_land <= 1)
                passes = is_lc or urg >= save_threshold or s >= save_threshold
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
        urgency = _urgency_bonus(state, best_type, best_arg)

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

    state._snapshots = snapshots  # stash for report
    return state, build_log, score_traces
