#!/usr/bin/env python3
"""
Helium Hustle — Reverse data converter: JSON -> xlsx

Converts data/generated/*.json back into a spreadsheet that data/convert.py
can read. Use this when you want to visually inspect or edit game data:

    1. python data/json_to_xlsx.py          # JSON -> xlsx
    2. (edit the xlsx in Excel / Google Sheets)
    3. python data/convert.py               # xlsx -> JSON  (ground truth)

The JSON files are ground truth. The xlsx is a human-readable intermediate.
Do not treat the xlsx as the source of record.

Output: data/Helium Hustle Datasheets.xlsx  (overwrites if present)
"""

import json
import sys
from pathlib import Path

try:
    import openpyxl
    from openpyxl.styles import Font, PatternFill
except ImportError:
    print("ERROR: openpyxl required. Install with: pip install openpyxl")
    sys.exit(1)

DATA_DIR = Path(__file__).parent
GENERATED_DIR = DATA_DIR / "generated"


# ============================================================================
# Cell encoding helpers
# ============================================================================

def encode_requires(req: dict) -> str:
    if not req or req.get("type") == "none":
        return "none"
    return f"{req['type']}={req['value']}"


def encode_costs(costs: dict) -> list:
    return [f"{res}={val:g}" for res, val in costs.items()]


def encode_production(production: dict) -> list:
    return [f"{res}+{val:g}" for res, val in production.items()]


def encode_upkeep(upkeep: dict) -> list:
    # JSON upkeep values are positive; cell encoding uses '-' operator
    return [f"{res}-{val:g}" for res, val in upkeep.items()]


def encode_effects(effects: list) -> list:
    result = []
    for e in effects:
        if set(e.keys()) == {"effect"}:
            result.append(e["effect"])
        elif "prefix" in e:
            result.append(f"{e['prefix']}_{e['resource']}{e['operator']}{e['value']:g}")
        else:
            result.append(f"{e['resource']}{e['operator']}{e['value']:g}")
    return result


def pad(lst: list, n: int) -> list:
    return (lst + ["x"] * n)[:n]


# ============================================================================
# Sheet writers
# ============================================================================

def write_resources(ws, resources: list) -> None:
    ws.append(["Resource", "Short name", "Storage base"])
    for r in resources:
        ws.append([
            r["name"],
            r["short_name"],
            r["storage_base"] if r["storage_base"] is not None else "x",
        ])


def write_buildings(ws, buildings: list) -> None:
    ws.append([
        "Building", "Short name", "Requires", "Land", "Scaling",
        "Cost 1", "Cost 2", "Cost 3", "Cost 4",
        "Prod 1", "Prod 2", "Prod 3",
        "Upkeep 1", "Upkeep 2",
        "Effect 1", "Effect 2", "Effect 3",
        "Desc",
    ])
    for b in buildings:
        row = [
            b["name"],
            b["short_name"],
            encode_requires(b.get("requires", {})),
            b["land"],
            b["cost_scaling"],
        ]
        row += pad(encode_costs(b.get("costs", {})), 4)
        row += pad(encode_production(b.get("production", {})), 3)
        row += pad(encode_upkeep(b.get("upkeep", {})), 2)
        row += pad(encode_effects(b.get("effects", [])), 3)
        row += [b.get("description") or "x"]
        ws.append(row)


def write_commands(ws, commands: list) -> None:
    ws.append([
        "Command", "Short name", "Requires",
        "Cost 1", "Cost 2", "Cost 3",
        "Prod 1", "Prod 2", "Prod 3",
        "Effect 1", "Effect 2", "Effect 3",
        "Desc",
    ])
    for c in commands:
        row = [
            c["name"],
            c["short_name"],
            encode_requires(c.get("requires", {})),
        ]
        row += pad(encode_costs(c.get("costs", {})), 3)
        row += pad(encode_production(c.get("production", {})), 3)
        row += pad(encode_effects(c.get("effects", [])), 3)
        row += [c.get("description") or "x"]
        ws.append(row)


def style_header(ws) -> None:
    for cell in ws[1]:
        cell.font = Font(bold=True)
        cell.fill = PatternFill("solid", fgColor="D9D9D9")


# ============================================================================
# Main
# ============================================================================

def main():
    missing = [
        name for name in ("resources.json", "buildings.json", "commands.json")
        if not (GENERATED_DIR / name).exists()
    ]
    if missing:
        print(f"ERROR: Missing JSON files in {GENERATED_DIR}:")
        for m in missing:
            print(f"  {m}")
        sys.exit(1)

    resources = json.loads((GENERATED_DIR / "resources.json").read_text(encoding="utf-8"))
    buildings = json.loads((GENERATED_DIR / "buildings.json").read_text(encoding="utf-8"))
    commands  = json.loads((GENERATED_DIR / "commands.json").read_text(encoding="utf-8"))

    wb = openpyxl.Workbook()
    wb.remove(wb.active)

    ws_r = wb.create_sheet("Resources")
    write_resources(ws_r, resources)
    style_header(ws_r)

    ws_b = wb.create_sheet("Buildings")
    write_buildings(ws_b, buildings)
    style_header(ws_b)

    ws_c = wb.create_sheet("Commands")
    write_commands(ws_c, commands)
    style_header(ws_c)

    out = DATA_DIR / "Helium Hustle Datasheets.xlsx"
    wb.save(out)
    print(f"Written: {out}")
    print(f"  Resources: {len(resources)}")
    print(f"  Buildings: {len(buildings)}")
    print(f"  Commands:  {len(commands)}")
    print()
    print("Edit the xlsx, then run: python data/convert.py")


if __name__ == "__main__":
    main()
