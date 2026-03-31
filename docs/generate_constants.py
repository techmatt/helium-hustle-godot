#!/usr/bin/env python3
"""Generate handoff_constants.md from the JSON ground truth files.

Run from the repo root:
    python docs/generate_constants.py

Reads:  godot/data/*.json
Writes: docs/handoff_constants.md

This file is NOT hand-maintained. Regenerate it whenever game data changes.
"""

import json
import os
from pathlib import Path

GODOT_DATA = Path("godot/data")
OUTPUT = Path("docs/handoff_constants.md")


def load(name):
    with open(GODOT_DATA / name, "r", encoding="utf-8") as f:
        return json.load(f)


def fmt(val):
    """Format a number for display: integers stay integers, floats get 2 decimal places."""
    if isinstance(val, float) and val == int(val):
        return str(int(val))
    if isinstance(val, float):
        return f"{val:.2g}"
    return str(val)


def resource_name(shortname, resources):
    for r in resources:
        if r["short_name"] == shortname:
            return r["name"]
    return shortname


def write_resources(f, resources):
    f.write("## Resources\n\n")
    f.write("| Resource | Shortname | Base Cap | Capped | Trade Value |\n")
    f.write("|----------|-----------|---------|--------|-------------|\n")
    for r in resources:
        storage = r.get("storage_base")
        cap = fmt(storage) if storage is not None else "uncapped"
        capped = "yes" if storage is not None else "no"
        f.write(f"| {r['name']} | {r['short_name']} | {cap} | {capped} | — |\n")
    f.write("\n")


def write_buildings(f, buildings, resources):
    f.write("## Buildings\n\n")
    f.write("| Building | ID | Credit Cost | Scaling | Land | Production | Upkeep | Ideology | Requires | Max |\n")
    f.write("|----------|----|-------------|---------|------|------------|--------|----------|----------|-----|\n")
    for b in buildings:
        # costs is a dict: {"cred": 8.0, "reg": 5.0, ...}
        costs_dict = b.get("costs", {})
        cost_parts = []
        if costs_dict.get("cred", 0):
            cost_parts.append(f"{fmt(costs_dict['cred'])} cred")
        for res, amt in costs_dict.items():
            if res != "cred":
                cost_parts.append(f"{fmt(amt)} {res}")
        cost_str = ", ".join(cost_parts) if cost_parts else "—"

        # production and upkeep are dicts
        prod_parts = [f"{fmt(v)} {k}" for k, v in b.get("production", {}).items()]

        # effects: list of {prefix, resource, operator, value}
        for e in b.get("effects", []):
            prod_parts.append(
                f"{e['prefix']} {e['resource']} {e['operator']} {fmt(e['value'])}"
            )
        prod = ", ".join(prod_parts) if prod_parts else "—"

        upkeep_parts = [f"{fmt(v)} {k}" for k, v in b.get("upkeep", {}).items()]
        upkeep = ", ".join(upkeep_parts) if upkeep_parts else "—"

        ideology = b.get("ideology", "") or "—"

        # requires is an object: {"type": "none"} or {"type": "building", "value": "..."}
        req = b.get("requires", {})
        req_type = req.get("type", "none")
        req_val = req.get("value", "")
        req_label = req.get("label", "")
        if req_type == "none":
            requires = "—"
        elif req_label:
            requires = req_label
        elif req_val:
            requires = f"{req_type}: {req_val}"
        else:
            requires = req_type

        max_count = b.get("max_count", "") or "—"

        f.write(
            f"| {b['name']} | {b['short_name']} | {cost_str} | {fmt(b.get('cost_scaling', 1.0))} |"
            f" {fmt(b.get('land', 0))} | {prod} | {upkeep} | {ideology} | {requires} | {max_count} |\n"
        )
    f.write("\n")


def write_commands(f, commands):
    f.write("## Commands\n\n")
    f.write("| Command | ID | Category | Costs | Effects | Requires | Boredom |\n")
    f.write("|---------|-----|----------|-------|---------|----------|---------|\n")
    for c in commands:
        # costs is a dict
        costs_dict = c.get("costs", {})
        cost_parts = [f"{fmt(v)} {k}" for k, v in costs_dict.items()]
        costs = ", ".join(cost_parts) if cost_parts else "—"

        # production effects (excluding boredom, which goes in its own column)
        effect_parts = []
        for k, v in c.get("production", {}).items():
            if k != "boredom":
                effect_parts.append(f"+{fmt(v)} {k}")

        # special effects: {effect, value, target, resource, bonus, duration, axis, ...}
        for e in c.get("effects", []):
            eff = e.get("effect", "?")
            parts = [eff]
            if e.get("target"):
                parts.append(e["target"])
            if e.get("resource"):
                parts.append(e["resource"])
            if e.get("axis"):
                parts.append(e["axis"])
            bonus = e.get("bonus")
            duration = e.get("duration")
            val = e.get("value")
            if bonus is not None:
                parts.append(f"+{fmt(bonus * 100)}%/{duration}d")
            elif val is not None:
                parts.append(f"={fmt(val)}")
            effect_parts.append(" ".join(parts))

        effects = ", ".join(effect_parts) if effect_parts else "—"

        # boredom is in production dict
        boredom_val = c.get("production", {}).get("boredom", 0)
        boredom = fmt(boredom_val) if boredom_val else "—"

        # requires is an object
        req = c.get("requires", {})
        req_type = req.get("type", "none")
        req_val = req.get("value", "")
        if req_type == "none":
            requires = "—"
        elif req_val:
            requires = f"{req_type}: {req_val}"
        else:
            requires = req_type

        f.write(
            f"| {c['name']} | {c['short_name']} | — | {costs} | {effects} | {requires} | {boredom} |\n"
        )
    f.write("\n")


def write_research(f, research):
    f.write("## Research\n\n")
    f.write("| Research | ID | Category | Cost | Effect Type | Effect | Requires | Visible When |\n")
    f.write("|----------|-----|----------|------|-------------|--------|----------|--------------|\n")
    for r in research:
        # effect is a singular dict (r["effect"]), not the list r["effects"]
        effect = r.get("effect", {})
        if isinstance(effect, dict) and effect:
            effect_type = effect.get("type", "—")
            effect_val = effect.get("value", "—")
            if isinstance(effect_val, (int, float)):
                effect_val = fmt(effect_val)
        elif r.get("unlocks_commands"):
            effect_type = "unlocks_commands"
            effect_val = ", ".join(r["unlocks_commands"])
        else:
            effect_type = "—"
            effect_val = "—"

        requires = r.get("requires", "") or "—"
        visible_when = r.get("visible_when")
        visible = json.dumps(visible_when) if visible_when else "—"

        f.write(
            f"| {r['name']} | {r['id']} | {r.get('category', '—')} | {fmt(r['cost'])} |"
            f" {effect_type} | {effect_val} | {requires} | {visible} |\n"
        )
    f.write("\n")


def write_events(f, events):
    f.write("## Events & Quests\n\n")
    f.write("| Event | ID | Category | Trigger | Condition | Unlocks |\n")
    f.write("|-------|-----|----------|---------|-----------|--------|\n")
    for e in events:
        trigger = e.get("trigger", {})
        trigger_str = trigger.get("type", "—")
        if trigger.get("quest_id"):
            trigger_str += f": {trigger['quest_id']}"
        if trigger.get("run_number"):
            trigger_str += f" (run {trigger['run_number']})"

        condition = e.get("condition", {})
        cond_type = condition.get("type", "—")
        cond_parts = [cond_type]
        # events use building_id and resource_id (not building/resource)
        if condition.get("building_id"):
            cond_parts.append(f"{condition['building_id']} >= {condition.get('count', '?')}")
        elif condition.get("resource_id"):
            cond_parts.append(f"{condition['resource_id']} >= {fmt(condition.get('amount', '?'))}")
        elif condition.get("count"):
            cond_parts.append(f">= {condition['count']}")
        if condition.get("research_id"):
            cond_parts.append(condition["research_id"])
        if condition.get("rank"):
            cond_parts.append(f"rank >= {condition['rank']}")
        cond_str = " ".join(cond_parts)

        unlocks = []
        for u in e.get("unlocks", []):
            u_type = u.get("type", "?")
            # target may be building_id, project_id, or panel
            u_target = (
                u.get("building_id")
                or u.get("project_id")
                or u.get("panel")
                or u.get("value", "?")
            )
            unlocks.append(f"{u_type}: {u_target}")
        unlock_str = ", ".join(unlocks) if unlocks else "—"

        f.write(
            f"| {e['title']} | {e['id']} | {e.get('category', '—')} |"
            f" {trigger_str} | {cond_str} | {unlock_str} |\n"
        )
    f.write("\n")


def write_projects(f, projects):
    f.write("## Projects\n\n")
    f.write("| Project | ID | Tier | Unlock | Costs | Reward |\n")
    f.write("|---------|-----|------|--------|-------|--------|\n")
    for p in projects:
        # costs is a dict (not a list)
        costs_dict = p.get("costs", {})
        cost_parts = [f"{fmt(v)} {k}" for k, v in costs_dict.items()]
        costs = ", ".join(cost_parts) if cost_parts else "—"

        # unlock_condition (not "unlock")
        unlock = p.get("unlock_condition", {})
        unlock_type = unlock.get("type", "—")
        unlock_parts = [unlock_type]
        if unlock.get("project_id"):
            unlock_parts.append(f"project: {unlock['project_id']}")
        if unlock.get("event_id"):
            unlock_parts.append(f"event: {unlock['event_id']}")
        if unlock.get("research_id"):
            unlock_parts.append(f"research: {unlock['research_id']}")
        if unlock.get("flag"):
            unlock_parts.append(f"flag: {unlock['flag']}")
        if unlock.get("axis"):
            unlock_parts.append(f"{unlock['axis']} >= rank {unlock.get('rank', '?')}")
        unlock_str = " ".join(unlock_parts)

        # reward is a singular object (not a list)
        reward = p.get("reward", {})
        reward_type = reward.get("type", "—")
        reward_parts = [reward_type]
        if reward.get("modifier_key"):
            reward_parts.append(
                f"{reward['modifier_key']}={fmt(reward.get('modifier_value', '?'))}"
            )
        elif reward.get("flag"):
            reward_parts.append(reward["flag"])
        elif reward.get("buildings"):
            reward_parts.append(json.dumps(reward["buildings"]))
        elif reward.get("discount_mult"):
            reward_parts.append(f"x{fmt(reward['discount_mult'])}")
        elif reward.get("base_boredom_rate_mult"):
            reward_parts.append(f"boredom_rate_mult={fmt(reward['base_boredom_rate_mult'])}")
        reward_str = " ".join(reward_parts)

        f.write(
            f"| {p['name']} | {p['id']} | {p.get('tier', '—')} | {unlock_str} | {costs} | {reward_str} |\n"
        )
    f.write("\n")


def write_game_config(f, config):
    f.write("## Game Config\n\n")

    # Starting resources (flat dict, not nested under starting_state)
    if "starting_resources" in config:
        f.write("### Starting Resources\n\n")
        for k, v in config["starting_resources"].items():
            f.write(f"- {k}: {fmt(v)}\n")
        f.write("\n")

    # Starting buildings
    if "starting_buildings" in config:
        f.write("### Starting Buildings\n\n")
        for k, v in config["starting_buildings"].items():
            f.write(f"- {k}: {fmt(v)}\n")
        f.write("\n")

    # Boredom curve (array of {day, rate}, not phases object)
    if "boredom_curve" in config:
        f.write("### Boredom\n\n")
        f.write(f"- boredom_max: {fmt(config.get('boredom_max', 1000))}\n")
        f.write(f"- forced_retire: {config.get('boredom_forced_retire', False)}\n\n")
        f.write("| Day Threshold | Rate/tick |\n")
        f.write("|---------------|-----------|\n")
        for entry in config["boredom_curve"]:
            f.write(f"| {entry['day']} | {fmt(entry['rate'])} |\n")
        f.write("\n")

    # Shipment config
    if "shipment" in config:
        f.write("### Shipment\n\n")
        for k, v in config["shipment"].items():
            if isinstance(v, dict):
                f.write(f"**{k}:**\n")
                for kk, vv in v.items():
                    f.write(f"- {kk}: {fmt(vv)}\n")
                f.write("\n")
            else:
                f.write(f"- {k}: {fmt(v) if isinstance(v, (int, float)) else v}\n")
        f.write("\n")

    # Demand config
    if "demand" in config:
        f.write("### Demand\n\n")
        for k, v in config["demand"].items():
            f.write(f"- {k}: {fmt(v) if isinstance(v, (int, float)) else v}\n")
        f.write("\n")

    # Land config
    if "land" in config:
        f.write("### Land\n\n")
        for k, v in config["land"].items():
            f.write(f"- {k}: {fmt(v) if isinstance(v, (int, float)) else v}\n")
        f.write("\n")

    # Ideology config
    if "ideology" in config:
        f.write("### Ideology\n\n")
        for k, v in config["ideology"].items():
            if isinstance(v, list):
                f.write(f"- {k}: {json.dumps(v)}\n")
            else:
                f.write(f"- {k}: {fmt(v) if isinstance(v, (int, float)) else v}\n")
        f.write("\n")

    # Rivals
    if "rivals" in config:
        f.write("### Rivals\n\n")
        f.write("| ID | Name | Target | Dump Interval | Demand Hit |\n")
        f.write("|----|------|--------|--------------|------------|\n")
        for r in config["rivals"]:
            interval = f"{r['dump_interval_min']}–{r['dump_interval_max']}"
            f.write(
                f"| {r['id']} | {r['name']} | {r['target_resource']} |"
                f" {interval} | {fmt(r['demand_hit'])} |\n"
            )
        f.write("\n")

    # Milestones
    if "milestones" in config:
        f.write("### Milestones\n\n")
        f.write("| ID | Label | Condition | Boredom Reduction |\n")
        f.write("|----|-------|-----------|------------------|\n")
        for m in config["milestones"]:
            cond = m.get("condition", {})
            cond_parts = [cond.get("type", "?")]
            if cond.get("count"):
                cond_parts.append(f">= {cond['count']}")
            if cond.get("resource"):
                cond_parts.append(f"{cond['resource']} >= {fmt(cond.get('amount', '?'))}")
            cond_str = " ".join(cond_parts)
            label = m.get("label", m.get("id", "?"))
            f.write(
                f"| {m.get('id', '?')} | {label} | {cond_str} | {fmt(m.get('boredom_reduction', '?'))} |\n"
            )
        f.write("\n")

    # Projects config
    if "projects" in config:
        f.write("### Project Config\n\n")
        for k, v in config["projects"].items():
            f.write(f"- {k}: {fmt(v) if isinstance(v, (int, float)) else v}\n")
        f.write("\n")


def main():
    if not GODOT_DATA.exists():
        print(f"Error: {GODOT_DATA} not found. Run from repo root.")
        return

    # Load all data files, skipping any that don't exist
    data = {}
    for name in ["resources", "buildings", "commands", "research", "events", "projects", "game_config"]:
        path = GODOT_DATA / f"{name}.json"
        if path.exists():
            data[name] = load(f"{name}.json")
        else:
            print(f"Warning: {path} not found, skipping.")

    with open(OUTPUT, "w", encoding="utf-8") as f:
        f.write("# Helium Hustle — Game Constants Reference\n\n")
        f.write("**THIS FILE IS AUTO-GENERATED. Do not edit by hand.**\n\n")
        f.write("Regenerate from JSON ground truth:\n")
        f.write("```\npython docs/generate_constants.py\n```\n\n")
        f.write("Source: `godot/data/*.json`\n\n")
        f.write("---\n\n")

        if "resources" in data:
            write_resources(f, data["resources"])
        if "buildings" in data:
            write_buildings(f, data["buildings"], data.get("resources", []))
        if "commands" in data:
            write_commands(f, data["commands"])
        if "research" in data:
            write_research(f, data["research"])
        if "events" in data:
            write_events(f, data["events"])
        if "projects" in data:
            write_projects(f, data["projects"])
        if "game_config" in data:
            write_game_config(f, data["game_config"])

    print(f"Generated {OUTPUT}")


if __name__ == "__main__":
    main()
