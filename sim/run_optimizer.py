#!/usr/bin/env python3
from __future__ import annotations
# coding: utf-8 (ASCII-safe output only for Windows cp1252 terminal compat)
"""
Helium Hustle -- Economic Optimizer CLI

Runs one greedy optimisation pass for a scenario and prints a four-section report:

  Section 1 -- Discovered build order (tick, action, building, cost)
  Section 2 -- Objective timing vs target windows
  Section 3 -- Resource snapshots at ticks 100, 300, 500, 700, 900
  Section 4 -- Structural summary (payback periods, energy budget, credits/tick)

Usage:
    python sim/run_optimizer.py                              # uses run1_fresh.json
    python sim/run_optimizer.py sim/scenarios/run1_fresh.json
    python sim/run_optimizer.py sim/scenarios/run1_fresh.json --debug-tick 38
"""

import csv
import json
import sys
import time
from pathlib import Path
from typing import Optional

from constants import (
    BUILDINGS, SNAPSHOT_TICKS, LOOKAHEAD_TICKS,
    TRADE_BASE_VALUES,
)
from economy import (
    num_processors, num_pads, check_objectives,
)
from optimizer import run_greedy

_SCENARIOS_DIR = Path(__file__).parent / "scenarios"
_DEFAULT_SCENARIO = _SCENARIOS_DIR / "run1_fresh.json"


# ============================================================================
# Formatting helpers (ASCII-safe)
# ============================================================================

def _hr(char: str = "-", width: int = 78) -> str:
    return char * width


def _header(title: str, char: str = "=", width: int = 78) -> str:
    pad = max(0, width - len(title) - 2)
    left = pad // 2
    right = pad - left
    return f"{char * left} {title} {char * right}"


def _tick_status(tick: Optional[int], lo: int, hi: int) -> str:
    if tick is None:
        return "MISSED  (not achieved)"
    if lo <= tick <= hi:
        return f"tick {tick:4d}  OK     (target {lo}-{hi})"
    elif tick < lo:
        return f"tick {tick:4d}  EARLY  (target {lo}-{hi})"
    else:
        return f"tick {tick:4d}  LATE   (target {lo}-{hi})"


def _rolling_credit_rate(history: list, at_tick: int, window: int = 20) -> float:
    """Average credits earned per tick over the window ending at at_tick."""
    entries = [h for h in history if h["tick"] <= at_tick]
    if len(entries) < 2:
        return 0.0
    end = entries[-1]
    start_candidates = [h for h in entries if h["tick"] <= at_tick - window]
    start = start_candidates[-1] if start_candidates else entries[0]
    delta_ticks = end["tick"] - start["tick"]
    if delta_ticks <= 0:
        return 0.0
    delta_credits = end["total_credits_earned"] - start["total_credits_earned"]
    return delta_credits / delta_ticks


# ============================================================================
# Section 1: Build order
# ============================================================================

def print_build_order(build_log: list) -> None:
    print(_header("SECTION 1: BUILD ORDER"))
    header = f"{'Tick':>5}  {'Action':<10}  {'Building / Item':<28}  {'#':>3}  Cost"
    print(header)
    print(_hr("-", len(header) + 20))
    for entry in build_log:
        tick = entry["tick"]
        label = entry["label"]
        count = f"x{entry['count_after']}" if entry["count_after"] is not None else "  "

        cost_parts = []
        land_cost = entry["cost"].get("_land", 0)
        for k, v in entry["cost"].items():
            if k == "_land":
                continue
            cost_parts.append(f"{v:.1f} {k}")
        if land_cost:
            cost_parts.append(f"{land_cost:.0f} land")
        cost_str = "  ".join(cost_parts) if cost_parts else "--"

        action_display = entry["action"].upper()
        if entry["action"] == "command":
            action_display = "CMD"
        print(f"{tick:5d}  {action_display:<10}  {label:<28}  {count:>3}  {cost_str}")
    print(f"\nTotal purchases: {len(build_log)}")


# ============================================================================
# Section 2: Objective timing
# ============================================================================

def print_objective_report(state, scenario: dict, build_log: list) -> None:
    print()
    print(_header("SECTION 2: OBJECTIVE TIMING"))

    objectives = scenario.get("objectives", [])
    obj_results = check_objectives(state, objectives)

    for obj in objectives:
        oid  = obj["id"]
        lo, hi = obj["target"]
        tick = obj_results.get(oid)
        label = oid.replace("_", " ").title()
        status = _tick_status(tick, lo, hi)
        print(f"  {oid:<16}  {label:<20}  {status}")

    print()
    print(f"  Run ended at tick {state.tick}  (boredom = {state.resources['boredom']:.1f}/100)")
    print(f"  Total credits earned: {state.total_credits_earned:.1f} cumulative")
    shipped = state.total_shipped
    if shipped:
        for res, qty in sorted(shipped.items()):
            val = qty * TRADE_BASE_VALUES.get(res, 0) * 0.5
            print(f"    Shipped {qty:6.0f}x {res:<12}  ~{val:7.1f} credits revenue")


# ============================================================================
# Section 3: Resource snapshots
# ============================================================================

def print_snapshots(snapshots: dict, history: list) -> None:
    print()
    print(_header("SECTION 3: RESOURCE SNAPSHOTS"))

    all_resources = [
        "eng", "reg", "ice", "he3", "ti",
        "cir", "prop", "cred", "sci", "boredom", "land",
    ]

    for target_tick in SNAPSHOT_TICKS:
        snap = snapshots.get(target_tick)
        if snap is None:
            print(f"\n  [ Tick {target_tick}: no data ]")
            continue

        actual_tick = snap["tick"]
        label = f"Tick {actual_tick}"
        if actual_tick != target_tick:
            label += f" (~{target_tick})"
        print(f"\n  +-- {label} " + "-" * max(0, 60 - len(label)))

        print(f"  |  {'Resource':<12}  {'Amount':>8}  {'Cap':>8}  {'Fill':>6}")
        print(f"  |  {'':->12}  {'':->8}  {'':->8}  {'':->6}")
        for res in all_resources:
            amt = snap.get(res, 0.0)
            cap = snap.get(f"{res}_cap")
            if cap is not None:
                fill_pct = (amt / cap * 100) if cap > 0 else 0
                cap_str = f"{cap:8.0f}"
                fill_str = f"{fill_pct:5.1f}%"
            else:
                cap_str = "  uncapped"
                fill_str = "     --"
            print(f"  |  {res:<12}  {amt:8.1f}  {cap_str}  {fill_str}")

        net_e = snap.get("net_energy", 0.0)
        e_prod = snap.get("energy_production", 0.0)
        e_upk = snap.get("energy_upkeep", 0.0)
        print(f"  |")
        print(f"  |  Net energy/tick:  {net_e:+.1f}  (prod {e_prod:.1f} - upk {e_upk:.1f})")

        rate = _rolling_credit_rate(history, actual_tick, window=20)
        print(f"  |  Credit income:    ~{rate:.2f} credits/tick  (20-tick rolling avg)")

        buildings = snap.get("buildings", {})
        parts = [f"{BUILDINGS[k].name} x{v}" for k, v in buildings.items() if v > 0]
        if parts:
            line = "  ".join(parts)
            print(f"  |  Buildings: {line[:62]}")
            if len(line) > 62:
                print(f"  |            {line[62:]}")

        print(f"  +" + "-" * 65)


# ============================================================================
# Section 4: Structural summary
# ============================================================================

def print_structural_summary(state, build_log: list, history: list, snapshots: dict) -> None:
    print()
    print(_header("SECTION 4: STRUCTURAL SUMMARY"))

    # --- 4a: Payback periods ---
    print("\n  4a. Payback Periods per Building Purchased")
    col = f"  {'Tick':>5}  {'Building':<28}  {'Cr. Cost':>9}  {'$/tick est':>10}  {'Payback (ticks)':>16}"
    print(col)
    print("  " + _hr("-", 76))
    for entry in build_log:
        if entry["action"] != "build":
            continue
        cred = entry["credits_cost"]
        marginal = entry["marginal_credits"]
        payback = entry["payback_ticks"]
        income_per_tick = (marginal / LOOKAHEAD_TICKS) if marginal > 0 else 0.0
        pb_str = f"{payback:>14.0f}" if payback is not None else "   N/A (infra only)"
        print(
            f"  {entry['tick']:5d}  {entry['label']:<28}  {cred:9.1f}"
            f"  {income_per_tick:10.3f}  {pb_str}"
        )

    # --- 4b: Energy budget at snapshots ---
    print()
    print("  4b. Energy Budget at Snapshots")
    print(f"  {'Tick':>5}  {'Prod':>6}  {'Upkeep':>7}  {'Net':>6}  "
          f"{'N Solar':>8}  {'N DCenter':>10}  {'Headroom':>9}")
    print("  " + _hr("-", 65))
    for target in SNAPSHOT_TICKS:
        snap = snapshots.get(target)
        if snap is None:
            continue
        t = snap["tick"]
        e_prod = snap.get("energy_production", 0.0)
        e_upk = snap.get("energy_upkeep", 0.0)
        net = e_prod - e_upk
        buildings = snap.get("buildings", {})
        n_solar = buildings.get("panel", 0)
        n_proc = buildings.get("data_center", 0)
        print(
            f"  {t:5d}  {e_prod:6.1f}  {e_upk:7.1f}  {net:+6.1f}  "
            f"{n_solar:8d}  {n_proc:10d}  {net:+9.1f}"
        )

    # --- 4c: Credits/tick over time ---
    print()
    print("  4c. Credit Income Rate Over Time  (20-tick rolling avg)")
    print(f"  {'Tick':>5}  {'Credits/tick':>13}  Note")
    print("  " + _hr("-", 55))
    checkpoints = [50, 100, 150, 200, 300, 400, 500, 600, 700, 800, 900]
    first_ship_tick = state.events.get("shipment_complete")
    for cp in checkpoints:
        if cp > state.tick:
            break
        rate = _rolling_credit_rate(history, cp, window=20)
        note = ""
        if first_ship_tick and abs(cp - first_ship_tick) <= 25:
            note = "<-- first shipment"
        print(f"  {cp:5d}  {rate:13.2f}  {note}")

    # --- 4d: Final state ---
    print()
    print("  4d. Final State Summary")
    print(f"  Run length:      {state.tick} ticks")
    print(f"  Boredom at end:  {state.resources.get('boredom', 0):.1f} / 100")
    print(f"  Credits earned:  {state.total_credits_earned:.1f} total")
    print(f"  Processors:      {num_processors(state)}")
    print(f"  Launch pads:     {num_pads(state)}")
    print()
    print("  Buildings at end:")
    for k, v in sorted(state.buildings.items(), key=lambda x: -x[1]):
        if v > 0:
            print(f"    {BUILDINGS[k].name:<28} x{v}")


# ============================================================================
# CSV tick report
# ============================================================================

def write_tick_csv(state, build_log: list, out_path: str = "tick_report.csv") -> None:
    purchases_by_tick: dict = {}
    for entry in build_log:
        t = entry["tick"]
        purchases_by_tick.setdefault(t, []).append(entry)

    key_buildings = [
        ("panel",        "n_solar"),
        ("battery",      "n_battery"),
        ("storage_depot","n_depot"),
        ("excavator",    "n_excavator"),
        ("ice_extractor","n_ice"),
        ("refinery",     "n_refinery"),
        ("smelter",      "n_smelter"),
        ("electrolysis", "n_electrolysis"),
        ("fabricator",   "n_fabricator"),
        ("data_center",  "n_data_center"),
        ("launch_pad",   "n_launch_pad"),
        ("research_lab", "n_research_lab"),
    ]

    resource_cols = [
        ("cred", None),
        ("eng",  "eng_cap"),
        ("reg",  "reg_cap"),
        ("ice",  "ice_cap"),
        ("he3",  "he3_cap"),
        ("ti",   "ti_cap"),
        ("cir",  "cir_cap"),
        ("prop", "prop_cap"),
        ("sci",  None),
        ("land", None),
    ]

    headers = (
        ["tick", "action", "boredom"]
        + [col for r, cap in resource_cols for col in ([r, cap] if cap else [r])]
        + ["net_energy", "cum_credits_earned"]
        + [col for _, col in key_buildings]
    )

    out = Path(__file__).parent / out_path
    with open(out, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)

        for snap in state.history:
            t = snap["tick"]
            entries = purchases_by_tick.get(t, [])
            if entries:
                parts = []
                for e in entries:
                    if e["action"] == "build":
                        parts.append(f"Build {e['label']} x{e['count_after']}")
                    elif e["action"] == "command":
                        parts.append(f"Cmd {e['label']}")
                    else:
                        parts.append("Buy Land")
                action_str = "; ".join(parts)
            else:
                action_str = ""

            row = [t, action_str, round(snap.get("boredom", 0), 2)]
            for res, cap_key in resource_cols:
                row.append(round(snap.get(res, 0), 1))
                if cap_key:
                    cap_val = snap.get(cap_key)
                    row.append("" if cap_val is None else int(cap_val))
            row.append(round(snap.get("net_energy", 0), 1))
            row.append(round(snap.get("total_credits_earned", 0), 1))
            buildings = snap.get("buildings", {})
            for bkey, _ in key_buildings:
                row.append(buildings.get(bkey, 0))
            writer.writerow(row)

    print(f"  Tick report written: {out}")


# ============================================================================
# Section 5: Score traces (printed only when --debug-tick is used)
# ============================================================================

def print_score_traces(score_traces: dict) -> None:
    if not score_traces:
        return
    print()
    print(_header("SECTION 5: SCORE TRACES"))

    for tick in sorted(score_traces):
        tr = score_traces[tick]
        res = tr["resources"]
        bldgs = tr["buildings"]

        print(f"\n  === Tick {tick} ===")
        res_parts = ["cred", "eng", "reg", "ice", "he3", "ti", "cir", "prop"]
        res_str = "  ".join(f"{r}={res.get(r, 0):.1f}" for r in res_parts)
        print(f"  Resources: {res_str}")
        print(f"             boredom={res.get('boredom', 0):.2f}  land={res.get('land', 0):.0f}")
        bldg_parts = [f"{BUILDINGS[k].name} x{v}" for k, v in bldgs.items() if v > 0]
        print(f"  Buildings: {', '.join(bldg_parts) or '(none)'}")
        print(f"  max_upcoming_urgency={tr['max_upcoming_urgency']:.0f}  "
              f"save_threshold={tr['save_threshold']:.1f}  "
              f"baseline_credits={tr['base_credits']:.1f}")

        chosen_key = tr.get("chosen")
        if chosen_key:
            print(f"  Chosen: {chosen_key[0]} {chosen_key[1]}")
        else:
            print(f"  Chosen: (none -- all actions failed threshold or scored <= 0)")

        print()
        hdr = (f"  {'Rank':>4}  {'Type':<8}  {'Action':<22}  "
               f"{'Score':>7}  {'Marginal':>9}  {'Urgency':>8}  {'Passes':>6}  {'':>1}")
        print(hdr)
        print("  " + _hr("-", len(hdr) - 2))
        for i, act in enumerate(tr["actions"], 1):
            marker = "*" if act["chosen"] else " "
            passes_str = "YES" if act["passes"] else "no"
            print(
                f"  {i:4d}  {act['action_type']:<8}  {act['action_arg']:<22}  "
                f"{act['score']:7.1f}  {act['marginal']:9.1f}  "
                f"{act['urgency']:8.1f}  {passes_str:>6}  {marker}"
            )
        print()


# ============================================================================
# Argument parsing
# ============================================================================

def _parse_args(argv: list) -> tuple[Path, list[int]]:
    """
    Parse optional scenario path and --debug-tick N flags from argv.
    Returns (scenario_path, debug_ticks).
    """
    debug_ticks: list[int] = []
    scenario_path: Path = _DEFAULT_SCENARIO
    i = 0
    while i < len(argv):
        if argv[i] in ("--debug-tick", "-d") and i + 1 < len(argv):
            debug_ticks.append(int(argv[i + 1]))
            i += 2
        elif not argv[i].startswith("-"):
            scenario_path = Path(argv[i])
            i += 1
        else:
            i += 1
    return scenario_path, debug_ticks


# ============================================================================
# Entry point
# ============================================================================

def main() -> None:
    scenario_path, debug_ticks = _parse_args(sys.argv[1:])

    if not scenario_path.exists():
        print(f"ERROR: scenario file not found: {scenario_path}")
        sys.exit(1)

    scenario = json.loads(scenario_path.read_text(encoding="utf-8"))

    print()
    print(_header(f"HELIUM HUSTLE -- OPTIMIZER  ({scenario['name']})"))
    print(f"  Lookahead: {LOOKAHEAD_TICKS} ticks | Scoring: marginal credits + urgency bonuses")
    if debug_ticks:
        print(f"  Debug ticks: {sorted(debug_ticks)}")
    print(_hr("-"))
    print("  Running optimizer...", end="", flush=True)

    objectives = scenario.get("objectives", [])

    t0 = time.perf_counter()
    state, build_log, score_traces, snapshots = run_greedy(
        debug_ticks=set(debug_ticks), objectives=objectives
    )
    elapsed = time.perf_counter() - t0

    print(f" done in {elapsed:.1f}s  ({state.tick} ticks simulated, {len(build_log)} purchases)")
    print()

    history = state.history

    print_build_order(build_log)
    print_objective_report(state, scenario, build_log)
    print_snapshots(snapshots, history)
    print_structural_summary(state, build_log, history, snapshots)
    if score_traces:
        print_score_traces(score_traces)
    write_tick_csv(state, build_log)

    print()
    print(_hr("="))
    print()


if __name__ == "__main__":
    main()
