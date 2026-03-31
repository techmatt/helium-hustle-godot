extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_resource_system()
	_test_boredom_system()


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

	sim.tick(state, true)  # boredom suppressed — isolates resource production

	_assert_equal(state.current_day, 1, "resource: day advances after tick")
	_assert_gt(state.amounts.get("eng", 0.0), 0.0, "resource: solar panel produces energy")

	for res: String in state.amounts:
		_assert_true(state.amounts[res] >= 0.0, "resource: " + res + " non-negative after tick")

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
