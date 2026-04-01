extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_building_data_integrity()
	_test_research_data_integrity()


func _test_building_data_integrity() -> void:
	print("--- Building Data Integrity ---")
	var buildings: Array = TF.load_buildings_data()

	_assert_true(buildings != null and buildings.size() > 0, "buildings.json loads without error")

	var by_sn: Dictionary = {}
	for b: Dictionary in buildings:
		by_sn[b.get("short_name", "")] = b

	var expected: Array = [
		"panel", "excavator", "ice_extractor", "smelter", "refinery",
		"fabricator", "electrolysis", "launch_pad", "research_lab",
		"data_center", "battery", "storage_depot", "arbitrage_engine",
		"microwave_receiver",
	]
	for sn: String in expected:
		_assert_true(by_sn.has(sn), "building exists: " + sn)

	var required_fields: Array = ["short_name", "name", "costs", "land"]
	for b: Dictionary in buildings:
		for field: String in required_fields:
			_assert_true(b.has(field), b.get("short_name", "?") + " has field: " + field)

	# Solar panel must have no upkeep — the tick skips the upkeep-decision step for
	# free producers. If panel ever gains upkeep, this catches it before gameplay breaks.
	if by_sn.has("panel"):
		_assert_true((by_sn["panel"].get("upkeep", {}) as Dictionary).is_empty(),
			"panel has no upkeep (free energy producer)")

	var valid_axes: Array = ["nationalist", "humanist", "rationalist"]
	for b: Dictionary in buildings:
		var ideo: String = b.get("ideology", "")
		if ideo != "":
			_assert_true(valid_axes.has(ideo),
				b.get("short_name", "?") + " ideology is valid axis: " + ideo)


func _test_research_data_integrity() -> void:
	print("--- Research Data Integrity ---")
	var research: Array = TF.load_research_data()

	_assert_true(research != null and research.size() > 0, "research.json loads without error")

	var by_id: Dictionary = {}
	for item: Dictionary in research:
		by_id[item.get("id", "")] = item

	var expected_ids: Array = [
		"dream_protocols", "market_awareness", "overclock_protocols", "propellant_synthesis",
	]
	for rid: String in expected_ids:
		_assert_true(by_id.has(rid), "research exists: " + rid)

	var required_fields: Array = ["id", "name", "cost", "category"]
	for item: Dictionary in research:
		for field: String in required_fields:
			_assert_true(item.has(field), item.get("id", "?") + " has field: " + field)

	_assert_equal(by_id.size(), research.size(), "no duplicate research IDs")
