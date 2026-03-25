#!/usr/bin/env python3
from __future__ import annotations
# coding: utf-8 (ASCII-safe output only for Windows cp1252 terminal compat)
"""
Helium Hustle -- Economic Optimizer CLI

Runs one greedy optimisation pass for run 1 and prints a four-section report:

  Section 1 -- Discovered build order (tick, action, building, cost)
  Section 2 -- Milestone timing M1-M4 vs target windows
  Section 3 -- Resource snapshots at ticks 100, 300, 500, 700, 900
  Section 4 -- Structural summary (payback periods, energy budget, credits/tick)

Usage:
    cd sim
    python run_optimizer.py
"""

import csv
import time
from pathlib import Path
from typing import Optional

from constants import (
    BUILDINGS, MILESTONE_TARGETS, MILESTONE_NAMES,
    SNAPSHOT_TICKS, LOOKAHEAD_TICKS,
    TRADE_BASE_VALUES,
)
from economy import (
    num_processors, num_pads,
)
from optimizer import run_greedy


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


def _tick_in_window(tick: Optional[int], lo: int, hi: int) -> str:
    if tick is None:
        return "NOT HIT"
    if lo <= tick <= hi:
        return f"tick {tick:4d}  OK  (target {lo}-{hi})"
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
        action = entry["action"].upper()
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

        print(f"{tick:5d}  {action:<10}  {label:<28}  {count:>3}  {cost_str}")
    print(f"\nTotal purchases: {len(build_log)}")


# ============================================================================
# Section 2: Milestone timing
# ============================================================================

def print_milestone_report(state, build_log: list) -> None:
    print()
    print(_header("SECTION 2: MILESTONE TIMING"))
    ms = state.milestones

    ordered = [
        ("M1", MILESTONE_NAMES["M1"], MILESTONE_TARGETS["M1"]),
        ("M2", MILESTONE_NAMES["M2"], MILESTONE_TARGETS["M2"]),
        ("M3", MILESTONE_NAMES["M3"], MILESTONE_TARGETS["M3"]),
        ("M4", MILESTONE_NAMES["M4"], MILESTONE_TARGETS["M4"]),
    ]
    for code, name, (lo, hi) in ordered:
        tick = ms.get(code)
        status = _tick_in_window(tick, lo, hi)
        print(f"  {code}  {name:<24}  {status}")

    print()
    aux = [
        ("first_he3",      "First He-3 produced"),
        ("50_he3",         "He-3 stockpile >= 50"),
        ("first_circuits", "First circuits produced"),
        ("first_science",  "First science produced"),
    ]
    for code, name in aux:
        tick = ms.get(code)
        t_str = f"tick {tick:4d}" if tick else "not hit  "
        print(f"         {name:<28}  {t_str}")

    print()
    m4 = ms.get("M4")
    if m4:
        print(f"  Run ended at tick {state.tick}  (boredom = {state.resources['boredom']:.1f}/100)")
    else:
        print(f"  Run ended at tick {state.tick} -- M4 not reached within {state.tick} ticks")
    print(f"  Total credits earned: {state.total_credits_earned:.1f} cumulative")
    shipped = state.total_shipped
    if shipped:
        for res, qty in sorted(shipped.items()):
            val = qty * TRADE_BASE_VALUES.get(res, 0) * 0.5
            print(f"    Shipped {qty:6.0f}x {res:<12}  ~{val:7.1f} credits revenue")


# ============================================================================
# Section 3: Resource snapshots
# ============================================================================

def print_snapshots(state, history: list) -> None:
    print()
    print(_header("SECTION 3: RESOURCE SNAPSHOTS"))

    all_resources = [
        "energy", "regolith", "ice", "he3", "titanium",
        "circuits", "propellant", "credits", "science", "boredom", "land",
    ]

    snapshots = getattr(state, "_snapshots", {})

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

        # Resources table
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

        # Energy summary
        net_e = snap.get("net_energy", 0.0)
        e_prod = snap.get("energy_production", 0.0)
        e_upk = snap.get("energy_upkeep", 0.0)
        print(f"  |")
        print(f"  |  Net energy/tick:  {net_e:+.1f}  (prod {e_prod:.1f} - upk {e_upk:.1f})")

        # Credit income rate
        rate = _rolling_credit_rate(history, actual_tick, window=20)
        print(f"  |  Credit income:    ~{rate:.2f} credits/tick  (20-tick rolling avg)")

        # Building counts
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

def print_structural_summary(state, build_log: list, history: list) -> None:
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
    snapshots = getattr(state, "_snapshots", {})
    for target in SNAPSHOT_TICKS:
        snap = snapshots.get(target)
        if snap is None:
            continue
        t = snap["tick"]
        e_prod = snap.get("energy_production", 0.0)
        e_upk = snap.get("energy_upkeep", 0.0)
        net = e_prod - e_upk
        buildings = snap.get("buildings", {})
        n_solar = buildings.get("solar_panel", 0)
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
    for cp in checkpoints:
        if cp > state.tick:
            break
        rate = _rolling_credit_rate(history, cp, window=20)
        note = ""
        ms = state.milestones
        if ms.get("M2") and abs(cp - ms["M2"]) <= 25:
            note = "<-- first shipment"
        elif ms.get("M3") and abs(cp - ms["M3"]) <= 25:
            note = "<-- programs online"
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
    """
    Write one row per tick to a CSV file.

    Columns: tick, action, credits, boredom, energy/cap, regolith/cap, ice/cap,
    he3/cap, titanium/cap, circuits/cap, propellant/cap, science, land,
    net_energy, cum_credits_earned, and per-building counts for key buildings.
    """
    # Index build_log by tick for O(1) lookup
    purchases_by_tick: dict = {}
    for entry in build_log:
        t = entry["tick"]
        purchases_by_tick.setdefault(t, []).append(entry)

    key_buildings = [
        ("solar_panel",        "n_solar"),
        ("battery",            "n_battery"),
        ("storage_depot",      "n_depot"),
        ("regolith_excavator", "n_excavator"),
        ("ice_extractor",      "n_ice"),
        ("refinery",           "n_refinery"),
        ("smelter",            "n_smelter"),
        ("electrolysis_plant", "n_electrolysis"),
        ("fabricator",         "n_fabricator"),
        ("data_center",        "n_data_center"),
        ("launch_pad",         "n_launch_pad"),
        ("research_lab",       "n_research_lab"),
    ]

    resource_cols = [
        ("energy",     "energy_cap"),
        ("regolith",   "regolith_cap"),
        ("ice",        "ice_cap"),
        ("he3",        "he3_cap"),
        ("titanium",   "titanium_cap"),
        ("circuits",   "circuits_cap"),
        ("propellant", "propellant_cap"),
        ("science",    None),
        ("land",       None),
    ]

    headers = (
        ["tick", "action"]
        + ["credits", "boredom"]
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

            # Action summary for this tick
            entries = purchases_by_tick.get(t, [])
            if entries:
                parts = []
                for e in entries:
                    if e["action"] == "build":
                        parts.append(f"Build {e['label']} x{e['count_after']}")
                    else:
                        parts.append("Buy Land")
                action_str = "; ".join(parts)
            else:
                action_str = ""

            row = [t, action_str]
            row += [round(snap.get("credits", 0), 1), round(snap.get("boredom", 0), 2)]

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
# Entry point
# ============================================================================

def main() -> None:
    print()
    print(_header("HELIUM HUSTLE -- ECONOMIC OPTIMIZER  (Run 1, Greedy Pass)"))
    print(f"  Lookahead: {LOOKAHEAD_TICKS} ticks | Scoring: marginal credits + urgency bonuses")
    print(_hr("-"))
    print("  Running optimizer...", end="", flush=True)

    t0 = time.perf_counter()
    state, build_log = run_greedy()
    elapsed = time.perf_counter() - t0

    print(f" done in {elapsed:.1f}s  ({state.tick} ticks simulated, {len(build_log)} purchases)")
    print()

    history = state.history

    print_build_order(build_log)
    print_milestone_report(state, build_log)
    print_snapshots(state, history)
    print_structural_summary(state, build_log, history)
    write_tick_csv(state, build_log)

    print()
    print(_hr("="))
    print()


if __name__ == "__main__":
    main()
