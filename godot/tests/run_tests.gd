extends SceneTree

# Execution: _process with a done flag so autoloads are ready.
# class_name declarations outside the autoload chain are NOT auto-registered in
# headless --script mode, so TestFixtures must be preloaded explicitly.

const TF = preload("res://tests/test_fixtures.gd")

var tests_passed := 0
var tests_failed := 0
var done := false


func _process(_delta: float) -> bool:
	if done:
		return false
	done = true
	_run_tests()
	return false


func _run_tests() -> void:
	# Block autosave timer from touching the player's real save file.
	# Note: _ready() has already run and loaded the save by this point.
	# skip_save_load here only prevents future autosave writes.
	var gm: Node = root.get_node("/root/GameManager")
	gm.skip_save_load = true

	_test_game_state_basics()
	_test_ideology_ranks()
	_test_ideology_bonuses()
	_test_building_data_integrity()
	_test_research_data_integrity()
	_test_resource_system()
	_test_boredom_system()
	_test_save_load_roundtrip()
	_test_retirement_reset()

	print("")
	print("=============================")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("=============================")
	if tests_failed > 0:
		print("TESTS FAILED")
	else:
		print("ALL TESTS PASSED")
	quit()


# --- Assertions ---

func _assert_equal(actual: Variant, expected: Variant, test_name: String) -> void:
	if actual == expected:
		tests_passed += 1
	else:
		tests_failed += 1
		print("  FAIL: ", test_name, " — expected ", expected, " got ", actual)


func _assert_true(value: bool, test_name: String) -> void:
	if value:
		tests_passed += 1
	else:
		tests_failed += 1
		print("  FAIL: ", test_name)


func _assert_gt(actual: float, threshold: float, test_name: String) -> void:
	if actual > threshold:
		tests_passed += 1
	else:
		tests_failed += 1
		print("  FAIL: ", test_name, " — expected > ", threshold, " got ", actual)


func _assert_lt(actual: float, threshold: float, test_name: String) -> void:
	if actual < threshold:
		tests_passed += 1
	else:
		tests_failed += 1
		print("  FAIL: ", test_name, " — expected < ", threshold, " got ", actual)


func _assert_approx(actual: float, expected: float, tolerance: float, test_name: String) -> void:
	if abs(actual - expected) <= tolerance:
		tests_passed += 1
	else:
		tests_failed += 1
		print("  FAIL: ", test_name, " — expected ~", expected, " (±", tolerance, ") got ", actual)


# --- Test Suites ---

func _test_game_state_basics() -> void:
	print("--- Game State Basics ---")
	var config := TF.load_game_config()
	var buildings_data := TF.load_buildings_data()
	var state := GameState.from_config(config, buildings_data)

	_assert_equal(state.current_day, 0, "fresh state: current_day = 0")
	_assert_approx(state.amounts.get("boredom", -1.0), 0.0, 0.001, "fresh state: boredom = 0")
	_assert_equal(state.programs.size(), 5, "fresh state: 5 program slots")

	# All starting resources present
	for res: String in config.get("starting_resources", {}).keys():
		_assert_true(state.amounts.has(res), "fresh state: has resource " + res)

	# Starting buildings present
	for bsn: String in config.get("starting_buildings", {}).keys():
		_assert_true(state.buildings_owned.has(bsn), "fresh state: has building " + bsn)

	# Ideology axes all at 0
	_assert_equal(state.ideology_values.get("nationalist", -1.0), 0.0, "fresh state: nationalist = 0")
	_assert_equal(state.ideology_values.get("humanist", -1.0), 0.0, "fresh state: humanist = 0")
	_assert_equal(state.ideology_values.get("rationalist", -1.0), 0.0, "fresh state: rationalist = 0")


func _test_ideology_ranks() -> void:
	print("--- Ideology Ranks ---")
	var state := GameState.new()

	state.ideology_values["nationalist"] = 0.0
	_assert_equal(state.get_ideology_rank("nationalist"), 0, "rank 0 at value 0")

	state.ideology_values["nationalist"] = 69.9
	_assert_equal(state.get_ideology_rank("nationalist"), 0, "rank 0 at value 69.9 (just below threshold)")

	state.ideology_values["nationalist"] = 70.0
	_assert_equal(state.get_ideology_rank("nationalist"), 1, "rank 1 at value 70")

	state.ideology_values["nationalist"] = 174.9
	_assert_equal(state.get_ideology_rank("nationalist"), 1, "rank 1 at value 174.9")

	state.ideology_values["nationalist"] = 175.0
	_assert_equal(state.get_ideology_rank("nationalist"), 2, "rank 2 at value 175")

	state.ideology_values["nationalist"] = 925.0
	_assert_equal(state.get_ideology_rank("nationalist"), 5, "rank 5 at value 925")

	state.ideology_values["nationalist"] = 9999.0
	_assert_equal(state.get_ideology_rank("nationalist"), 5, "rank 5 at value 9999 (above all thresholds)")

	state.ideology_values["nationalist"] = -70.0
	_assert_equal(state.get_ideology_rank("nationalist"), -1, "rank -1 at value -70")

	state.ideology_values["nationalist"] = -175.0
	_assert_equal(state.get_ideology_rank("nationalist"), -2, "rank -2 at value -175")

	state.ideology_values["nationalist"] = -925.0
	_assert_equal(state.get_ideology_rank("nationalist"), -5, "rank -5 at value -925")


func _test_ideology_bonuses() -> void:
	print("--- Ideology Bonuses ---")
	var state := GameState.new()

	state.ideology_values["nationalist"] = 0.0
	_assert_approx(state.get_ideology_bonus("nationalist", 1.0, 1.05), 1.0, 0.0001,
		"bonus 1.0 at rank 0 (no effect)")

	# Nationalist rank 3: pow(1.05, 3) ≈ 1.1576
	state.ideology_values["nationalist"] = 333.0
	_assert_approx(state.get_ideology_bonus("nationalist", 1.0, 1.05), pow(1.05, 3.0), 0.0001,
		"nationalist rank 3 demand mult ≈ 1.1576")

	# Humanist rank 2: pow(0.97, 2) ≈ 0.9409
	state.ideology_values["humanist"] = 175.0
	_assert_approx(state.get_ideology_bonus("humanist", 1.0, 0.97), pow(0.97, 2.0), 0.0001,
		"humanist rank 2 boredom mult ≈ 0.9409")

	# Rationalist negative rank -2: pow(1.05, -2) ≈ 0.9070
	state.ideology_values["rationalist"] = -175.0
	_assert_approx(state.get_ideology_bonus("rationalist", 1.0, 1.05), pow(1.05, -2.0), 0.0001,
		"rationalist rank -2 science mult ≈ 0.9070")

	# Rank 5: pow(1.05, 5) ≈ 1.2763
	state.ideology_values["nationalist"] = 925.0
	_assert_approx(state.get_ideology_bonus("nationalist", 1.0, 1.05), pow(1.05, 5.0), 0.0001,
		"rank 5 bonus ≈ 1.2763")


func _test_building_data_integrity() -> void:
	print("--- Building Data Integrity ---")
	var buildings: Array = TF.load_buildings_data()

	_assert_true(buildings != null and buildings.size() > 0, "buildings.json loads without error")

	# Build a lookup by short_name for O(1) checks below
	var by_sn: Dictionary = {}
	for b: Dictionary in buildings:
		by_sn[b.get("short_name", "")] = b

	# All expected buildings exist
	var expected: Array = [
		"panel", "excavator", "ice_extractor", "smelter", "refinery",
		"fabricator", "electrolysis", "launch_pad", "research_lab",
		"data_center", "battery", "storage_depot", "arbitrage_engine",
	]
	for sn: String in expected:
		_assert_true(by_sn.has(sn), "building exists: " + sn)

	# Required fields on every building
	var required_fields: Array = ["short_name", "name", "costs", "land"]
	for b: Dictionary in buildings:
		for field: String in required_fields:
			_assert_true(b.has(field), b.get("short_name", "?") + " has field: " + field)

	# Solar panel (short_name: "panel") has empty upkeep
	if by_sn.has("panel"):
		_assert_true((by_sn["panel"].get("upkeep", {}) as Dictionary).is_empty(),
			"panel has no upkeep (free energy producer)")

	# Buildings with a non-empty ideology field must use a valid axis name
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

	# Build a lookup by id
	var by_id: Dictionary = {}
	for item: Dictionary in research:
		by_id[item.get("id", "")] = item

	# Key research items exist
	var expected_ids: Array = [
		"dream_protocols", "market_awareness", "overclock_protocols", "propellant_synthesis",
	]
	for rid: String in expected_ids:
		_assert_true(by_id.has(rid), "research exists: " + rid)

	# Required fields on every item
	var required_fields: Array = ["id", "name", "cost", "category"]
	for item: Dictionary in research:
		for field: String in required_fields:
			_assert_true(item.has(field), item.get("id", "?") + " has field: " + field)

	# No duplicate IDs
	_assert_equal(by_id.size(), research.size(), "no duplicate research IDs")


func _test_resource_system() -> void:
	print("--- Resource System ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)

	_assert_equal(state.current_day, 0, "resource: fresh state at day 0")
	_assert_true(state.amounts.has("eng"), "resource: energy resource present")
	_assert_true(not state.caps.is_empty(), "resource: caps populated")

	# Drain energy to 0 so panel production is observable (starting eng=100 is at
	# the storage cap, so production would otherwise be clamped and invisible).
	state.amounts["eng"] = 0.0

	# Tick with boredom suppressed — isolates resource production
	sim.tick(state, true)

	_assert_equal(state.current_day, 1, "resource: day advances after tick")

	# Solar panel produces 6 eng/tick with no upkeep; must be > 0 after tick
	_assert_gt(state.amounts.get("eng", 0.0), 0.0, "resource: solar panel produces energy")

	# Resources must not go negative
	for res: String in state.amounts:
		_assert_true(state.amounts[res] >= 0.0, "resource: " + res + " non-negative after tick")

	# Resources must not exceed caps
	for res: String in state.amounts:
		var cap: float = state.caps.get(res, INF)
		if cap < INF:
			_assert_lt(state.amounts[res], cap + 0.001, "resource: " + res + " within cap")


func _test_boredom_system() -> void:
	print("--- Boredom System ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)

	_assert_approx(state.amounts.get("boredom", -1.0), 0.0, 0.001, "boredom: starts at 0")

	# Tick with boredom enabled — fresh state has no research or flags, so
	# multiplier = 1.0. Phase 1 rate (day 0) = 0.1 → expect exactly 0.1.
	sim.tick(state, false)
	_assert_approx(state.amounts.get("boredom", -1.0), 0.1, 0.0001,
		"boredom: increases by 0.1 on first tick (phase 1 rate)")

	# Tick many more times — boredom must never exceed 1000
	for _i in range(9999):
		sim.tick(state, false)
		if state.amounts.get("boredom", 0.0) >= 990.0:
			break
	_assert_lt(state.amounts.get("boredom", 0.0), 1001.0, "boredom: never exceeds 1000")

	# Verify boredom_curve phase ordering: each day threshold must be ascending
	var config := TF.load_game_config()
	var curve: Array = config.get("boredom_curve", [])
	_assert_true(curve.size() > 0, "boredom: curve has entries")
	var prev_day := -1
	for entry: Dictionary in curve:
		var day := int(entry.get("day", 0))
		_assert_true(day > prev_day, "boredom: curve days in ascending order")
		prev_day = day


func _test_save_load_roundtrip() -> void:
	print("--- Save/Load Roundtrip ---")
	var gm: Node = root.get_node("/root/GameManager")

	# Stamp known values into live state
	gm.state.amounts["boredom"] = 500.0
	gm.state.ideology_values["nationalist"] = 200.0
	gm.state.ideology_values["humanist"] = -50.0
	gm.career.lifetime_credits_earned = 12345.0
	gm.career.total_retirements = 7

	# Save to dict (no file I/O)
	var saved: Dictionary = gm.save_to_dict()

	# Corrupt live state so we know load_from_dict actually restored values
	gm.state.amounts["boredom"] = 0.0
	gm.state.ideology_values["nationalist"] = 0.0
	gm.career.lifetime_credits_earned = 0.0

	# Restore from dict
	gm.load_from_dict(saved)

	_assert_approx(gm.state.amounts.get("boredom", -1.0), 500.0, 0.001,
		"roundtrip: boredom survived")
	_assert_approx(gm.state.ideology_values.get("nationalist", -999.0), 200.0, 0.001,
		"roundtrip: ideology nationalist survived")
	_assert_approx(gm.state.ideology_values.get("humanist", -999.0), -50.0, 0.001,
		"roundtrip: ideology humanist survived")
	_assert_approx(gm.career.lifetime_credits_earned, 12345.0, 0.001,
		"roundtrip: career credits survived")
	_assert_equal(gm.career.total_retirements, 7, "roundtrip: career retirements survived")

	_assert_true(saved.has("version"), "roundtrip: dict has version field")
	_assert_equal(saved.get("version"), 1, "roundtrip: version is 1")


func _test_retirement_reset() -> void:
	print("--- Retirement Reset ---")
	var gm: Node = root.get_node("/root/GameManager")

	# Redirect saves to a temp path so retire+start_new_run don't touch the real file
	var SM = preload("res://scripts/game/save_manager.gd")
	var real_path: String = SM.save_path
	SM.save_path = "user://test_tmp_retirement.json"

	# Set up non-zero state
	gm.state.amounts["boredom"] = 750.0
	gm.state.ideology_values["rationalist"] = 300.0
	gm.state.current_day = 50
	var pre_retirements: int = gm.career.total_retirements
	var pre_run_number: int = gm.career.run_number

	# Retire then start new run (mirrors the normal end-of-run flow)
	gm.retire(true)
	gm.start_new_run()
	gm.set_speed("||")  # stop timer immediately so ticks don't accumulate

	_assert_equal(gm.state.current_day, 0, "retirement: day resets to 0")
	_assert_approx(gm.state.amounts.get("boredom", -1.0), 0.0, 0.001,
		"retirement: boredom resets to 0")
	_assert_approx(gm.state.ideology_values.get("rationalist", -999.0), 0.0, 0.001,
		"retirement: ideology resets to 0")
	_assert_equal(gm.career.total_retirements, pre_retirements + 1,
		"retirement: career retirement count incremented")
	_assert_true(gm.career.run_number > pre_run_number,
		"retirement: career run_number advanced")

	# Restore save path and clean up temp file
	SM.save_path = real_path
	if FileAccess.file_exists("user://test_tmp_retirement.json"):
		DirAccess.remove_absolute("user://test_tmp_retirement.json")
