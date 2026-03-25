#!/usr/bin/env python3
# coding: utf-8
"""
Helium Hustle -- Optimizer score tracer.

Replays the full optimizer run and prints the complete scoring table at each
requested tick: every feasible action with its score, marginal credits, urgency,
whether it passed the save_threshold, and which action was chosen.

Usage:
    python trace.py <tick> [<tick> ...]       individual ticks
    python trace.py <start>-<end>             inclusive range
    python trace.py 38 100 200-210            mix of both

Examples:
    python trace.py 38
    python trace.py 35-45
    python trace.py 38 100 777
"""

from __future__ import annotations
import sys
from pathlib import Path

# Ensure sim/ is on the path when called from repo root
sys.path.insert(0, str(Path(__file__).parent))

from constants import BUILDINGS, LOOKAHEAD_TICKS
from optimizer import run_greedy
from run_optimizer import _hr, _header, print_score_traces


# ============================================================================
# Tick spec parsing
# ============================================================================

def parse_tick_specs(args: list[str]) -> list[int]:
    """
    Parse a mix of individual tick numbers and N-M ranges.
    Examples: ["38", "100", "200-210"] -> [38, 100, 200, 201, ..., 210]
    """
    ticks: list[int] = []
    for arg in args:
        if "-" in arg and not arg.startswith("-"):
            parts = arg.split("-", 1)
            lo, hi = int(parts[0]), int(parts[1])
            ticks.extend(range(lo, hi + 1))
        else:
            ticks.append(int(arg))
    return sorted(set(ticks))


# ============================================================================
# Entry point
# ============================================================================

def main() -> None:
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        sys.exit(0)

    ticks = parse_tick_specs(args)
    if not ticks:
        print("No ticks specified. Run with --help for usage.")
        sys.exit(1)

    print()
    print(_header(f"HELIUM HUSTLE -- OPTIMIZER TRACE  (ticks: {_fmt_ticks(ticks)})"))
    print(f"  Lookahead: {LOOKAHEAD_TICKS} ticks | Running full optimizer pass...")
    print(_hr("-"))

    state, build_log, score_traces = run_greedy(debug_ticks=set(ticks))

    missing = [t for t in ticks if t not in score_traces]
    if missing:
        print(f"  Note: ticks {missing} were not reached "
              f"(run ended at tick {state.tick}).")

    print_score_traces(score_traces)
    print(_hr("="))
    print()


def _fmt_ticks(ticks: list[int]) -> str:
    """Compact representation: [38, 100, 200-210] -> '38 100 200-210'"""
    if not ticks:
        return ""
    parts: list[str] = []
    i = 0
    while i < len(ticks):
        j = i
        while j + 1 < len(ticks) and ticks[j + 1] == ticks[j] + 1:
            j += 1
        if j > i:
            parts.append(f"{ticks[i]}-{ticks[j]}")
        else:
            parts.append(str(ticks[i]))
        i = j + 1
    return "  ".join(parts)


if __name__ == "__main__":
    main()
