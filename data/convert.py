#!/usr/bin/env python3
"""
Helium Hustle Datasheet Converter
Converts helium_hustle_datasheets.xlsx into JSON files for Godot.

Usage:
    python convert.py [path_to_xlsx]

If no path given, looks for "Helium Hustle Datasheets.xlsx" in the same directory.
Outputs to generated/ subdirectory next to this script.

========================================================================
SPREADSHEET FORMAT SPEC
========================================================================

The source spreadsheet lives in Google Drive and is downloaded as .xlsx.
It has three tabs: Resources, Buildings, Commands.

CELL ENCODING:
  "x"                   = empty/null (ignored by parser)
  "shortname=amount"    = cost (one-time purchase price, operator =)
  "shortname+amount"    = production (per-tick gain, operator +)
  "shortname-amount"    = upkeep (per-tick drain, operator -)
  "prefix_shortname+amount" = effect (e.g. store_eng+50, load_he3+2)
  "flagname"            = flag effect with no value (e.g. next_cmd_double)

Operators are CONFIRMATORY: the parser validates that = appears in Cost
columns, + in Prod columns, - in Upkeep columns. Mismatches are errors.
Effect columns accept any operator or bare flags.

Resource short names are defined in the Resources tab (eng, reg, ice,
he3, cred, land, boredom, proc).

SHEET SCHEMAS:
  Resources: Resource | Short name | Storage base
  Buildings: Building | Short name | Requires | Land | Scaling |
             Cost 1-4 | Prod 1-3 | Upkeep 1-2 | Effect 1-3 | Desc
  Commands:  Command | Short name | Requires |
             Cost 1-3 | Prod 1-3 | Effect 1-3 | Desc

Column caps (Cost 1-4, Prod 1-3, etc.) are intentional design limits.
Headers are normalized to lowercase+stripped, so casing doesn't matter.

REQUIRES COLUMN:
  "none"                = no prerequisite
  "building=short_name" = requires at least one of that building
  "research=short_name" = (future) requires a research unlock

EXTENDING THIS SCRIPT:
  - New resource: add row to Resources tab. No script changes needed.
  - New building/command: add row to respective tab. No script changes.
  - New column cap (e.g. Cost 5): update the range() in the converter
    function AND update the xlsx generation if applicable.
  - New effect prefix (e.g. "mult_"): no script changes needed, the
    prefix parser handles any prefix_resource+value pattern.
  - New requires type: add handling in parse_requires() if needed.
  - New sheet (e.g. Research): add a convert_research() function
    following the same pattern, add to converters dict in main().

Global game params (starting resources, starting buildings, boredom
curve, shipment thresholds, speed caps) live in a separate JSON file
in the game repo, NOT in this spreadsheet.
========================================================================
"""

import json
import os
import sys
import re
from pathlib import Path
from typing import Optional

try:
    import openpyxl
except ImportError:
    print("ERROR: openpyxl required. Install with: pip install openpyxl")
    sys.exit(1)


# --- Cell Parsing ---

# Operators and which column types expect them
COLUMN_OPERATORS = {
    "cost": "=",
    "prod": "+",
    "upkeep": "-",
}

def classify_column(header: str) -> Optional[str]:
    """Map a column header to its type for operator validation."""
    h = header.lower()
    if h.startswith("cost"):
        return "cost"
    if h.startswith("prod"):
        return "prod"
    if h.startswith("upkeep"):
        return "upkeep"
    if h.startswith("effect"):
        return "effect"
    return None

def parse_resource_cell(raw: str, col_type: Optional[str], context: str) -> Optional[dict]:
    """
    Parse a cell like 'cred=80', 'eng+4', 'eng-2', 'store_eng+50', 'load_he3+2',
    'next_cmd_double', or 'x'.

    Returns None for 'x'.
    Returns dict with keys: resource, operator, value, prefix (if any).
    """
    if raw is None or str(raw).strip().lower() == "x":
        return None

    raw = str(raw).strip()

    # Handle flag-style effects with no operator (like 'next_cmd_double')
    if col_type == "effect" and not any(op in raw for op in "=+-"):
        return {"effect": raw}

    # Parse: optional_prefix + resource_shortname + operator + value
    match = re.match(r'^([a-z_]*?)([a-z][a-z0-9]*)([=+\-])(.+)$', raw)
    if not match:
        raise ValueError(f"{context}: Cannot parse cell '{raw}'")

    prefix_and_resource = raw
    # Re-parse: split on the operator
    for op in "=+-":
        if op in raw:
            left, right = raw.split(op, 1)
            try:
                value = float(right)
            except ValueError:
                raise ValueError(f"{context}: Bad numeric value in '{raw}'")

            # Validate operator matches column type
            if col_type in COLUMN_OPERATORS:
                expected_op = COLUMN_OPERATORS[col_type]
                if op != expected_op:
                    raise ValueError(
                        f"{context}: Operator mismatch in '{raw}'. "
                        f"Column type '{col_type}' expects '{expected_op}', got '{op}'"
                    )

            # Split prefix from resource name (e.g., 'store_eng' -> prefix='store', resource='eng')
            if "_" in left and col_type == "effect":
                parts = left.rsplit("_", 1)
                return {"prefix": parts[0], "resource": parts[1], "operator": op, "value": value}
            else:
                return {"resource": left, "operator": op, "value": value}

    raise ValueError(f"{context}: No operator found in '{raw}'")


def parse_requires(raw: str) -> dict:
    """Parse a Requires cell like 'none', 'building=refinery', 'research=something'."""
    if raw is None or str(raw).strip().lower() == "none":
        return {"type": "none"}
    raw = str(raw).strip()
    if "=" in raw:
        req_type, req_value = raw.split("=", 1)
        return {"type": req_type, "value": req_value}
    raise ValueError(f"Cannot parse Requires value: '{raw}'")


# --- Sheet Readers ---

def read_sheet(wb, sheet_name: str) -> tuple:
    """Read a sheet into (headers, rows). Rows are dicts keyed by normalized header."""
    ws = wb[sheet_name]
    raw_headers = [ws.cell(row=1, column=c).value for c in range(1, ws.max_column + 1)]
    # Normalize: strip whitespace, lowercase
    headers = [h.strip().lower() if h else "" for h in raw_headers]

    rows = []
    for r in range(2, ws.max_row + 1):
        values = [ws.cell(row=r, column=c).value for c in range(1, ws.max_column + 1)]
        if all(v is None for v in values):
            continue
        rows.append(dict(zip(headers, values)))
    return headers, rows


def get(row, key, sheet_name, row_index, headers, required=True):
    """Safely access a row dict key with a clear error on missing columns."""
    if key in row:
        return row[key]
    if required:
        raise KeyError(
            f"\n  Sheet '{sheet_name}', row {row_index}: missing column '{key}'"
            f"\n  Available headers: {headers}"
            f"\n  Row data: {row}"
        )
    return None


def convert_resources(wb) -> list:
    headers, rows = read_sheet(wb, "Resources")
    resources = []
    for i, row in enumerate(rows, start=2):
        g = lambda key, req=True: get(row, key, "Resources", i, headers, req)
        storage = g("storage base")
        entry = {
            "name": g("resource"),
            "short_name": g("short name"),
            "storage_base": storage if storage != "x" else None,
        }
        resources.append(entry)
    return resources


def convert_buildings(wb) -> list:
    headers, rows = read_sheet(wb, "Buildings")
    buildings = []

    for i, row in enumerate(rows, start=2):
        g = lambda key, req=True: get(row, key, "Buildings", i, headers, req)
        name = g("building")
        ctx = f"Buildings/{name}"

        # Parse grouped columns
        costs = []
        for j in range(1, 5):
            key = f"cost {j}"
            parsed = parse_resource_cell(row.get(key), "cost", f"{ctx}/Cost {j}")
            if parsed:
                costs.append(parsed)

        productions = []
        for j in range(1, 4):
            key = f"prod {j}"
            parsed = parse_resource_cell(row.get(key), "prod", f"{ctx}/Prod {j}")
            if parsed:
                productions.append(parsed)

        upkeeps = []
        for j in range(1, 3):
            key = f"upkeep {j}"
            parsed = parse_resource_cell(row.get(key), "upkeep", f"{ctx}/Upkeep {j}")
            if parsed:
                upkeeps.append(parsed)

        effects = []
        for j in range(1, 4):
            key = f"effect {j}"
            parsed = parse_resource_cell(row.get(key), "effect", f"{ctx}/Effect {j}")
            if parsed:
                effects.append(parsed)

        entry = {
            "name": name,
            "short_name": g("short name"),
            "requires": parse_requires(g("requires", req=False)),
            "land": int(g("land")),
            "cost_scaling": float(g("scaling")),
            "costs": {c["resource"]: c["value"] for c in costs},
            "production": {p["resource"]: p["value"] for p in productions},
            "upkeep": {u["resource"]: abs(u["value"]) for u in upkeeps},
            "effects": effects,
            "description": g("desc", req=False) or "",
        }
        buildings.append(entry)

    return buildings


def convert_commands(wb) -> list:
    headers, rows = read_sheet(wb, "Commands")
    commands = []

    for i, row in enumerate(rows, start=2):
        g = lambda key, req=True: get(row, key, "Commands", i, headers, req)
        name = g("command")
        ctx = f"Commands/{name}"

        costs = []
        for j in range(1, 4):
            key = f"cost {j}"
            parsed = parse_resource_cell(row.get(key), "cost", f"{ctx}/Cost {j}")
            if parsed:
                costs.append(parsed)

        productions = []
        for j in range(1, 4):
            key = f"prod {j}"
            parsed = parse_resource_cell(row.get(key), "prod", f"{ctx}/Prod {j}")
            if parsed:
                productions.append(parsed)

        effects = []
        for j in range(1, 4):
            key = f"effect {j}"
            parsed = parse_resource_cell(row.get(key), "effect", f"{ctx}/Effect {j}")
            if parsed:
                effects.append(parsed)

        entry = {
            "name": name,
            "short_name": g("short name"),
            "requires": parse_requires(g("requires", req=False)),
            "costs": {c["resource"]: c["value"] for c in costs},
            "production": {p["resource"]: p["value"] for p in productions},
            "effects": effects,
            "description": g("desc", req=False) or "",
        }
        commands.append(entry)

    return commands


# --- Main ---

def main():
    script_dir = Path(__file__).parent
    if len(sys.argv) > 1:
        xlsx_path = Path(sys.argv[1])
    else:
        xlsx_path = script_dir / "Helium Hustle Datasheets.xlsx"

    if not xlsx_path.exists():
        print(f"ERROR: File not found: {xlsx_path}")
        sys.exit(1)

    print(f"Reading: {xlsx_path}")
    wb = openpyxl.load_workbook(xlsx_path, data_only=True)

    output_dir = script_dir / "generated"
    output_dir.mkdir(exist_ok=True)

    errors = []

    # Convert each sheet
    converters = {
        "resources.json": lambda: convert_resources(wb),
        "buildings.json": lambda: convert_buildings(wb),
        "commands.json": lambda: convert_commands(wb),
    }

    for filename, converter in converters.items():
        try:
            data = converter()
            out_path = output_dir / filename
            with open(out_path, "w") as f:
                json.dump(data, f, indent=2)
            print(f"  Wrote {filename}: {len(data)} entries")
        except ValueError as e:
            errors.append(str(e))
            print(f"  ERROR in {filename}: {e}")

    if errors:
        print(f"\n{'='*60}")
        print(f"FAILED: {len(errors)} validation error(s):")
        for err in errors:
            print(f"  - {err}")
        print(f"{'='*60}")
        sys.exit(1)
    else:
        print(f"\nDone. Output in: {output_dir}")


if __name__ == "__main__":
    main()
