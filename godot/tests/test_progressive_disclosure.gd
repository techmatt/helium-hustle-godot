extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(scene_root: Node) -> void:
	var gm: Node = scene_root.get_node("/root/GameManager")
	var gs: Node = scene_root.get_node("/root/GameSettings")
	_test_resource_visibility(gm)
	_test_building_visibility(gm, gs)
	_test_research_lab_requires()
	_test_lifetime_owned_building_ids(gm)
	_test_storage_depot_visible_resources(gm)
	_test_buy_ice_command_gating()
	_test_show_all_cards_override(gm, gs)


# ── Resource visibility ───────────────────────────────────────────────────────

func _test_resource_visibility(gm: Node) -> void:
	print("--- Progressive Disclosure: Resource Visibility ---")

	# Save state
	var saved_owned: Dictionary = gm.state.buildings_owned.duplicate()
	var saved_lifetime: Array = gm.career.lifetime_owned_building_ids.duplicate()
	var saved_cmds: Array = gm.career.lifetime_used_command_ids.duplicate()

	# Fresh state: no extra buildings owned, no lifetime buildings, no prior commands
	gm.state.buildings_owned.clear()
	gm.career.lifetime_owned_building_ids.clear()
	gm.career.lifetime_used_command_ids.clear()

	var visible: Array = gm.get_visible_resources()

	# Always-visible resources must be present
	var always_visible: Array[String] = ["boredom", "eng", "proc", "land", "cred", "ti", "reg"]
	for res: String in always_visible:
		_assert_true(visible.has(res), "resource visibility: %s always visible" % res)

	# Gated resources must NOT be visible without their building or a prior buy command
	for res: String in ["ice", "he3", "cir", "prop", "sci"]:
		_assert_false(visible.has(res), "resource visibility: %s hidden without building" % res)

	# Owning ice_extractor this run makes ice visible
	gm.state.buildings_owned["ice_extractor"] = 1
	visible = gm.get_visible_resources()
	_assert_true(visible.has("ice"), "resource visibility: ice visible with ice_extractor this run")
	gm.state.buildings_owned.erase("ice_extractor")

	# Prior lifetime ownership of refinery makes he3 visible
	gm.career.lifetime_owned_building_ids.append("refinery")
	visible = gm.get_visible_resources()
	_assert_true(visible.has("he3"), "resource visibility: he3 visible via lifetime refinery ownership")
	gm.career.lifetime_owned_building_ids.clear()

	# Running buy_ice makes ice visible (even without ice_extractor)
	gm.career.lifetime_used_command_ids.append("buy_ice")
	visible = gm.get_visible_resources()
	_assert_true(visible.has("ice"), "resource visibility: ice visible after buy_ice run")
	gm.career.lifetime_used_command_ids.clear()

	# Running buy_propellant makes prop visible
	gm.career.lifetime_used_command_ids.append("buy_propellant")
	visible = gm.get_visible_resources()
	_assert_true(visible.has("prop"), "resource visibility: prop visible after buy_propellant run")
	gm.career.lifetime_used_command_ids.clear()

	# Restore
	gm.state.buildings_owned = saved_owned
	gm.career.lifetime_owned_building_ids.assign(saved_lifetime)
	gm.career.lifetime_used_command_ids.assign(saved_cmds)


# ── Building visibility ───────────────────────────────────────────────────────

func _test_building_visibility(gm: Node, gs: Node) -> void:
	print("--- Progressive Disclosure: Building Visibility ---")

	var saved_owned: Dictionary = gm.state.buildings_owned.duplicate()
	var saved_lifetime: Array = gm.career.lifetime_owned_building_ids.duplicate()
	var saved_unlocked: Array = gm.state.unlocked_buildings.duplicate()
	var saved_show_all: bool = gs.show_all_cards

	gm.state.buildings_owned.clear()
	gm.career.lifetime_owned_building_ids.clear()
	gm.state.unlocked_buildings.clear()
	gs.show_all_cards = false

	# Always-visible buildings (no requires)
	_assert_true(gm.is_building_visible("panel"), "building visibility: panel always visible")
	_assert_true(gm.is_building_visible("battery"), "building visibility: battery always visible")
	_assert_true(gm.is_building_visible("storage_depot"), "building visibility: storage_depot always visible")
	_assert_true(gm.is_building_visible("data_center"), "building visibility: data_center always visible")

	# Excavator requires Q1 — hidden without quest unlock
	_assert_false(gm.is_building_visible("excavator"), "building visibility: excavator hidden without Q1")
	gm.state.unlocked_buildings.append("excavator")
	_assert_true(gm.is_building_visible("excavator"), "building visibility: excavator visible after Q1 unlock")
	gm.state.unlocked_buildings.erase("excavator")

	# Ice Extractor requires propellant_synthesis research — hidden without it
	_assert_false(gm.is_building_visible("ice_extractor"), "building visibility: ice_extractor hidden without propellant_synthesis")
	gm.state.completed_research.append("propellant_synthesis")
	_assert_true(gm.is_building_visible("ice_extractor"), "building visibility: ice_extractor visible with propellant_synthesis")
	gm.state.completed_research.erase("propellant_synthesis")

	# Smelter requires excavator — hidden until excavator is owned
	_assert_false(gm.is_building_visible("smelter"), "building visibility: smelter hidden without excavator")
	gm.state.buildings_owned["excavator"] = 1
	_assert_true(gm.is_building_visible("smelter"), "building visibility: smelter visible with excavator owned")
	gm.state.buildings_owned.erase("excavator")

	# Fabricator requires smelter — hidden until smelter is owned
	_assert_false(gm.is_building_visible("fabricator"), "building visibility: fabricator hidden without smelter")
	gm.state.buildings_owned["smelter"] = 1
	_assert_true(gm.is_building_visible("fabricator"), "building visibility: fabricator visible with smelter owned")
	gm.state.buildings_owned.erase("smelter")

	# Lifetime ownership makes building visible even without current requires (building-prereq gate)
	gm.career.lifetime_owned_building_ids.append("smelter")
	_assert_true(gm.is_building_visible("smelter"), "building visibility: smelter visible via lifetime ownership")
	gm.career.lifetime_owned_building_ids.clear()

	# Lifetime ownership does NOT override event/quest gates (excavator is quest-gated)
	gm.career.lifetime_owned_building_ids.append("excavator")
	_assert_false(gm.is_building_visible("excavator"), "building visibility: excavator hidden via lifetime ownership (quest gate)")
	gm.career.lifetime_owned_building_ids.clear()

	# Restore
	gm.state.buildings_owned = saved_owned
	gm.career.lifetime_owned_building_ids.assign(saved_lifetime)
	gm.state.unlocked_buildings.assign(saved_unlocked)
	gs.show_all_cards = saved_show_all


# ── Research Lab requires data_center:2 ──────────────────────────────────────

func _test_research_lab_requires() -> void:
	print("--- Progressive Disclosure: Research Lab Requires 2 Data Centers ---")

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)

	# 0 data centers — research lab locked
	state.buildings_owned.erase("data_center")
	_assert_true(sim.is_building_locked(state, "research_lab"),
		"research_lab: locked with 0 data centers")

	# 1 data center — still locked
	state.buildings_owned["data_center"] = 1
	_assert_true(sim.is_building_locked(state, "research_lab"),
		"research_lab: locked with 1 data center")

	# 2 data centers — unlocked
	state.buildings_owned["data_center"] = 2
	_assert_false(sim.is_building_locked(state, "research_lab"),
		"research_lab: unlocked with 2 data centers")


# ── lifetime_owned_building_ids persists ─────────────────────────────────────

func _test_lifetime_owned_building_ids(gm: Node) -> void:
	print("--- Progressive Disclosure: lifetime_owned_building_ids ---")

	var saved_lifetime: Array = gm.career.lifetime_owned_building_ids.duplicate()

	gm.career.lifetime_owned_building_ids.clear()
	_assert_false(gm.career.lifetime_owned_building_ids.has("smelter"),
		"lifetime_owned: smelter not in lifetime before purchase")

	# Simulate purchase tracking (the actual buy_building path updates this)
	gm.career.lifetime_owned_building_ids.append("smelter")
	_assert_true(gm.career.lifetime_owned_building_ids.has("smelter"),
		"lifetime_owned: smelter present after tracking")

	# Serialization round-trip
	var dict: Dictionary = gm.career.to_dict()
	var restored: CareerState = CareerState.from_dict(dict)
	_assert_true(restored.lifetime_owned_building_ids.has("smelter"),
		"lifetime_owned: smelter survives to_dict/from_dict round-trip")

	# Restore
	gm.career.lifetime_owned_building_ids.assign(saved_lifetime)


# ── Storage Depot visible-resource filtering ─────────────────────────────────

func _test_storage_depot_visible_resources(gm: Node) -> void:
	print("--- Progressive Disclosure: Storage Depot Resource Visibility ---")

	var saved_owned: Dictionary = gm.state.buildings_owned.duplicate()
	var saved_lifetime: Array = gm.career.lifetime_owned_building_ids.duplicate()

	gm.state.buildings_owned.clear()
	gm.career.lifetime_owned_building_ids.clear()

	var saved_cmds: Array = gm.career.lifetime_used_command_ids.duplicate()
	gm.career.lifetime_used_command_ids.clear()

	# Without ice_extractor: ice should not be in visible resources
	var visible: Array = gm.get_visible_resources()
	_assert_false(visible.has("ice"),
		"storage depot filter: ice not visible without ice_extractor")

	# With ice_extractor: ice becomes visible
	gm.state.buildings_owned["ice_extractor"] = 1
	visible = gm.get_visible_resources()
	_assert_true(visible.has("ice"),
		"storage depot filter: ice visible with ice_extractor")

	# Restore
	gm.state.buildings_owned = saved_owned
	gm.career.lifetime_owned_building_ids.assign(saved_lifetime)
	gm.career.lifetime_used_command_ids.assign(saved_cmds)


# ── Buy Ice command gated on ice_extractor ────────────────────────────────────

func _test_buy_ice_command_gating() -> void:
	print("--- Progressive Disclosure: Buy Ice Command Gating ---")

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)

	# Ensure plenty of credits and energy
	state.amounts["cred"] = 9999.0
	state.amounts["eng"] = 9999.0

	# buy_ice has no prerequisites — executable regardless of ice_extractor
	state.buildings_owned.erase("ice_extractor")
	_assert_true(sim.is_command_executable(state, "buy_ice"),
		"buy_ice: executable without ice_extractor (no prerequisites)")

	# Also executable with ice_extractor owned
	state.buildings_owned["ice_extractor"] = 1
	state.buildings_active["ice_extractor"] = 1
	_assert_true(sim.is_command_executable(state, "buy_ice"),
		"buy_ice: executable with ice_extractor owned")


# ── Show All Cards override ───────────────────────────────────────────────────

func _test_show_all_cards_override(gm: Node, gs: Node) -> void:
	print("--- Progressive Disclosure: Show All Cards Override ---")

	var saved_owned: Dictionary = gm.state.buildings_owned.duplicate()
	var saved_lifetime: Array = gm.career.lifetime_owned_building_ids.duplicate()
	var saved_show_all: bool = gs.show_all_cards

	gm.state.buildings_owned.clear()
	gm.career.lifetime_owned_building_ids.clear()
	gs.show_all_cards = false

	# Without override: smelter hidden (no excavator)
	_assert_false(gm.is_building_visible("smelter"),
		"show_all_cards off: smelter hidden without excavator")
	# buy_ice has no prerequisites — always visible
	_assert_true(gm.is_command_visible("buy_ice"),
		"show_all_cards off: buy_ice always visible (no prerequisites)")

	# With override: everything visible
	gs.show_all_cards = true
	_assert_true(gm.is_building_visible("smelter"),
		"show_all_cards on: smelter visible regardless of requires")
	_assert_true(gm.is_command_visible("buy_ice"),
		"show_all_cards on: buy_ice visible regardless of requires")
	_assert_true(gm.is_command_visible("fund_nationalist"),
		"show_all_cards on: fund_nationalist visible without geopolitical_intelligence")

	# Restore
	gm.state.buildings_owned = saved_owned
	gm.career.lifetime_owned_building_ids.assign(saved_lifetime)
	gs.show_all_cards = saved_show_all
