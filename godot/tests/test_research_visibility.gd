extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(scene_root: Node) -> void:
	var gm: Node = scene_root.get_node("/root/GameManager")
	var gs: Node = scene_root.get_node("/root/GameSettings")
	_test_fresh_start_only_market_awareness(gm)
	_test_boredom_gate(gm)
	_test_dream_chain(gm)
	_test_building_count_gate(gm)
	_test_overclock_chain(gm)
	_test_trade_promotion_gate(gm)
	_test_shipment_gate(gm)
	_test_quest_gate(gm)
	_test_lifetime_override(gm)
	_test_show_all_cards_override(gm, gs)
	_test_category_header_hiding(gm)
	_test_rename_verification()


# Helper: save and restore all state touched by these tests
func _save_state(gm: Node) -> Dictionary:
	return {
		"boredom": gm.state.amounts.get("boredom", 0.0),
		"completed_research": gm.state.completed_research.duplicate(),
		"buildings_owned": gm.state.buildings_owned.duplicate(),
		"total_shipments": gm.state.total_shipments_completed,
		"lifetime_shipments": gm.career.lifetime_shipments,
		"completed_quest_ids": gm.career.completed_quest_ids.duplicate(),
		"lifetime_researched_ids": gm.career.lifetime_researched_ids.duplicate(),
		"event_instances": gm.state.event_instances.duplicate(true),
	}


func _restore_state(gm: Node, saved: Dictionary) -> void:
	gm.state.amounts["boredom"] = saved["boredom"]
	gm.state.completed_research.assign(saved["completed_research"])
	gm.state.buildings_owned = saved["buildings_owned"]
	gm.state.total_shipments_completed = saved["total_shipments"]
	gm.career.lifetime_shipments = saved["lifetime_shipments"]
	gm.career.completed_quest_ids.assign(saved["completed_quest_ids"])
	gm.career.lifetime_researched_ids.assign(saved["lifetime_researched_ids"])
	gm.state.event_instances.assign(saved["event_instances"])


# 1. Fresh start: only Market Awareness visible
func _test_fresh_start_only_market_awareness(gm: Node) -> void:
	print("--- Research Visibility: Fresh Start ---")
	var saved := _save_state(gm)

	gm.state.amounts["boredom"] = 0.0
	gm.state.completed_research.clear()
	gm.state.buildings_owned.clear()
	gm.state.total_shipments_completed = 0
	gm.career.lifetime_shipments = 0
	gm.career.completed_quest_ids.clear()
	gm.career.lifetime_researched_ids.clear()

	_assert_true(gm.is_research_item_visible("market_awareness"),
		"fresh start: market_awareness always visible")
	_assert_false(gm.is_research_item_visible("dream_protocols"),
		"fresh start: dream_protocols not visible (boredom=0)")
	_assert_false(gm.is_research_item_visible("stress_tolerance"),
		"fresh start: stress_tolerance not visible")
	_assert_false(gm.is_research_item_visible("efficient_dreaming"),
		"fresh start: efficient_dreaming not visible")
	_assert_false(gm.is_research_item_visible("overclock_protocols"),
		"fresh start: overclock_protocols not visible")
	_assert_false(gm.is_research_item_visible("overclock_boost"),
		"fresh start: overclock_boost not visible")
	_assert_false(gm.is_research_item_visible("speculator_analysis"),
		"fresh start: speculator_analysis not visible")
	_assert_false(gm.is_research_item_visible("trade_promotion"),
		"fresh start: trade_promotion not visible")
	_assert_false(gm.is_research_item_visible("shipping_efficiency"),
		"fresh start: shipping_efficiency not visible (0 shipments)")
	_assert_false(gm.is_research_item_visible("geopolitical_intelligence"),
		"fresh start: geopolitical_intelligence not visible (Q7 not done)")

	_restore_state(gm, saved)


# 2. Boredom gate for Dream Protocols
func _test_boredom_gate(gm: Node) -> void:
	print("--- Research Visibility: Boredom Gate ---")
	var saved := _save_state(gm)

	gm.state.completed_research.clear()
	gm.career.lifetime_researched_ids.clear()

	gm.state.amounts["boredom"] = 250.0
	_assert_false(gm.is_research_item_visible("dream_protocols"),
		"boredom gate: dream_protocols not visible at boredom=250")

	gm.state.amounts["boredom"] = 301.0
	_assert_true(gm.is_research_item_visible("dream_protocols"),
		"boredom gate: dream_protocols visible at boredom=301")

	_restore_state(gm, saved)


# 3. Dream research chain
func _test_dream_chain(gm: Node) -> void:
	print("--- Research Visibility: Dream Chain ---")
	var saved := _save_state(gm)

	gm.state.completed_research.clear()
	gm.career.lifetime_researched_ids.clear()

	_assert_false(gm.is_research_item_visible("stress_tolerance"),
		"dream chain: stress_tolerance not visible without dream_protocols")
	_assert_false(gm.is_research_item_visible("efficient_dreaming"),
		"dream chain: efficient_dreaming not visible without dream_protocols")

	gm.state.completed_research.append("dream_protocols")

	_assert_true(gm.is_research_item_visible("stress_tolerance"),
		"dream chain: stress_tolerance visible after dream_protocols purchased")
	_assert_true(gm.is_research_item_visible("efficient_dreaming"),
		"dream chain: efficient_dreaming visible after dream_protocols purchased")

	_restore_state(gm, saved)


# 4. Building count gate for Overclock Protocols
func _test_building_count_gate(gm: Node) -> void:
	print("--- Research Visibility: Building Count Gate ---")
	var saved := _save_state(gm)

	gm.state.completed_research.clear()
	gm.career.lifetime_researched_ids.clear()

	gm.state.buildings_owned["excavator"] = 4
	_assert_false(gm.is_research_item_visible("overclock_protocols"),
		"building count gate: overclock_protocols not visible with 4 excavators")

	gm.state.buildings_owned["excavator"] = 5
	_assert_true(gm.is_research_item_visible("overclock_protocols"),
		"building count gate: overclock_protocols visible with 5 excavators")

	_restore_state(gm, saved)


# 5. Overclock chain
func _test_overclock_chain(gm: Node) -> void:
	print("--- Research Visibility: Overclock Chain ---")
	var saved := _save_state(gm)

	gm.state.completed_research.clear()
	gm.career.lifetime_researched_ids.clear()

	_assert_false(gm.is_research_item_visible("overclock_boost"),
		"overclock chain: overclock_boost not visible without overclock_protocols")

	gm.state.completed_research.append("overclock_protocols")
	_assert_true(gm.is_research_item_visible("overclock_boost"),
		"overclock chain: overclock_boost visible after overclock_protocols purchased")

	_restore_state(gm, saved)


# 6. Trade Promotion gate on Market Awareness
func _test_trade_promotion_gate(gm: Node) -> void:
	print("--- Research Visibility: Trade Promotion Gate ---")
	var saved := _save_state(gm)

	gm.state.completed_research.clear()
	gm.career.lifetime_researched_ids.clear()

	_assert_false(gm.is_research_item_visible("trade_promotion"),
		"trade promotion gate: not visible without market_awareness")

	gm.state.completed_research.append("market_awareness")
	_assert_true(gm.is_research_item_visible("trade_promotion"),
		"trade promotion gate: visible after market_awareness purchased")

	_restore_state(gm, saved)


# 7. Shipment gate for Shipping Efficiency
func _test_shipment_gate(gm: Node) -> void:
	print("--- Research Visibility: Shipment Gate ---")
	var saved := _save_state(gm)

	gm.career.lifetime_researched_ids.clear()
	gm.state.total_shipments_completed = 5
	gm.career.lifetime_shipments = 4  # total = 9

	_assert_false(gm.is_research_item_visible("shipping_efficiency"),
		"shipment gate: shipping_efficiency not visible at 9 total shipments")

	gm.career.lifetime_shipments = 5  # total = 10
	_assert_true(gm.is_research_item_visible("shipping_efficiency"),
		"shipment gate: shipping_efficiency visible at 10 total shipments")

	_restore_state(gm, saved)


# 8. Quest gate for Geopolitical Intelligence
func _test_quest_gate(gm: Node) -> void:
	print("--- Research Visibility: Quest Gate ---")
	var saved := _save_state(gm)

	gm.career.lifetime_researched_ids.clear()
	gm.career.completed_quest_ids.clear()
	gm.state.event_instances.clear()

	_assert_false(gm.is_research_item_visible("geopolitical_intelligence"),
		"quest gate: geopolitical_intelligence not visible without Q5")

	# Via career (prior-run retirement path)
	gm.career.completed_quest_ids.append("qmarket_awareness")
	_assert_true(gm.is_research_item_visible("geopolitical_intelligence"),
		"quest gate: geopolitical_intelligence visible after Q5 in career")

	# Via current-run event_instances (same run Q5 was completed — before retirement)
	gm.career.completed_quest_ids.clear()
	gm.state.event_instances.append({"id": "qmarket_awareness", "state": "completed"})
	_assert_true(gm.is_research_item_visible("geopolitical_intelligence"),
		"quest gate: geopolitical_intelligence visible when Q5 completed in current run")

	# Incomplete instance does not count
	gm.state.event_instances.clear()
	gm.state.event_instances.append({"id": "qmarket_awareness", "state": "active"})
	_assert_false(gm.is_research_item_visible("geopolitical_intelligence"),
		"quest gate: geopolitical_intelligence not visible when Q5 only active (not completed)")

	_restore_state(gm, saved)


# 9. Lifetime researched override
func _test_lifetime_override(gm: Node) -> void:
	print("--- Research Visibility: Lifetime Override ---")
	var saved := _save_state(gm)

	gm.state.amounts["boredom"] = 0.0
	gm.state.completed_research.clear()
	gm.state.buildings_owned.clear()
	gm.state.total_shipments_completed = 0
	gm.career.lifetime_shipments = 0
	gm.career.completed_quest_ids.clear()
	gm.career.lifetime_researched_ids.clear()

	# None visible
	_assert_false(gm.is_research_item_visible("dream_protocols"),
		"lifetime override: dream_protocols not visible before")

	# Add to lifetime (simulating prior run purchase)
	gm.career.lifetime_researched_ids.append("dream_protocols")
	_assert_true(gm.is_research_item_visible("dream_protocols"),
		"lifetime override: dream_protocols visible when in lifetime_researched_ids")

	_restore_state(gm, saved)


# 10. Show All Cards override
func _test_show_all_cards_override(gm: Node, gs: Node) -> void:
	print("--- Research Visibility: Show All Cards ---")
	var saved := _save_state(gm)
	var saved_show_all: bool = gs.show_all_cards

	gm.state.amounts["boredom"] = 0.0
	gm.state.completed_research.clear()
	gm.state.buildings_owned.clear()
	gm.state.total_shipments_completed = 0
	gm.career.lifetime_shipments = 0
	gm.career.completed_quest_ids.clear()
	gm.career.lifetime_researched_ids.clear()

	gs.show_all_cards = true
	_assert_true(gm.is_research_item_visible("dream_protocols"),
		"show_all_cards: dream_protocols visible regardless of boredom")
	_assert_true(gm.is_research_item_visible("geopolitical_intelligence"),
		"show_all_cards: geopolitical_intelligence visible regardless of quest")
	_assert_true(gm.is_research_item_visible("shipping_efficiency"),
		"show_all_cards: shipping_efficiency visible regardless of shipments")
	_assert_true(gm.is_research_item_visible("overclock_protocols"),
		"show_all_cards: overclock_protocols visible regardless of building count")

	gs.show_all_cards = saved_show_all
	_restore_state(gm, saved)


# 11. Category header hiding (checked by counting visible items per category)
func _test_category_header_hiding(gm: Node) -> void:
	print("--- Research Visibility: Category Header Hiding ---")
	var saved := _save_state(gm)
	var saved_show_all: bool = false

	gm.state.amounts["boredom"] = 0.0
	gm.state.completed_research.clear()
	gm.state.buildings_owned.clear()
	gm.state.total_shipments_completed = 0
	gm.career.lifetime_shipments = 0
	gm.career.completed_quest_ids.clear()
	gm.career.lifetime_researched_ids.clear()

	# Count visible items per category
	var research_data: Array = gm.get_research_data()
	var visible_by_cat: Dictionary = {}
	for item: Dictionary in research_data:
		if gm.is_research_item_visible(item.get("id", "")):
			var cat: String = item.get("category", "Other")
			visible_by_cat[cat] = visible_by_cat.get(cat, 0) + 1

	# Self-Maintenance, Overclock Algorithms, Political Influence should have 0 visible items
	_assert_false(visible_by_cat.has("Self-Maintenance"),
		"category hiding: Self-Maintenance has no visible items on fresh start")
	_assert_false(visible_by_cat.has("Overclock Algorithms"),
		"category hiding: Overclock Algorithms has no visible items on fresh start")
	_assert_false(visible_by_cat.has("Political Influence"),
		"category hiding: Political Influence has no visible items on fresh start")

	# Market Analysis has at least Market Awareness
	_assert_true(visible_by_cat.get("Market Analysis", 0) >= 1,
		"category hiding: Market Analysis visible (contains market_awareness)")

	_restore_state(gm, saved)


# 12. Rename verification: no ideology_lobbying in data files
func _test_rename_verification() -> void:
	print("--- Research Visibility: Rename Verification ---")

	# research.json must not contain ideology_lobbying
	var research_data: Array = TF.load_json("res://data/research.json")
	for item: Dictionary in research_data:
		_assert_false(item.get("id", "") == "ideology_lobbying",
			"rename: research.json has no ideology_lobbying id")

	# Find geopolitical_intelligence and verify it unlocks fund commands
	var geo_item: Dictionary = {}
	for item: Dictionary in research_data:
		if item.get("id", "") == "geopolitical_intelligence":
			geo_item = item
			break
	_assert_false(geo_item.is_empty(),
		"rename: geopolitical_intelligence exists in research.json")
	var unlocks: Array = geo_item.get("unlocks_commands", [])
	_assert_true(unlocks.has("fund_nationalist"),
		"rename: geopolitical_intelligence unlocks fund_nationalist")
	_assert_true(unlocks.has("fund_humanist"),
		"rename: geopolitical_intelligence unlocks fund_humanist")
	_assert_true(unlocks.has("fund_rationalist"),
		"rename: geopolitical_intelligence unlocks fund_rationalist")

	# commands.json: fund commands require geopolitical_intelligence
	var commands_data: Array = TF.load_json("res://data/commands.json")
	for cmd: Dictionary in commands_data:
		var sn: String = cmd.get("short_name", "")
		if sn in ["fund_nationalist", "fund_humanist", "fund_rationalist"]:
			var req: Dictionary = cmd.get("requires", {})
			_assert_equal(req.get("value", ""), "geopolitical_intelligence",
				"rename: %s requires geopolitical_intelligence" % sn)

	# events.json: ideology_unlock condition uses geopolitical_intelligence
	var events_data: Array = TF.load_json("res://data/events.json")
	for ev: Dictionary in events_data:
		if ev.get("id", "") == "ideology_unlock":
			var cond: Dictionary = ev.get("condition", {})
			_assert_equal(cond.get("research_id", ""), "geopolitical_intelligence",
				"rename: ideology_unlock event condition uses geopolitical_intelligence")
			break
