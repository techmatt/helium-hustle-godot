extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	print("--- Launch Pad Resource Switch ---")
	_test_cargo_returned_on_resource_switch()
	_test_cargo_clamped_at_cap_on_switch()
	_test_pad_resets_after_switch()
	_test_no_cargo_switch_is_clean()


func _make_pad_state() -> Array:
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	# Inject a launch pad
	var pad := GameState.LaunchPadData.new()
	state.pads.append(pad)
	return [sim, state, pad]


func _test_cargo_returned_on_resource_switch() -> void:
	var arr := _make_pad_state()
	var sim: GameSimulation = arr[0]
	var state: GameState = arr[1]
	var pad: GameState.LaunchPadData = arr[2]

	pad.resource_type = "he3"
	pad.cargo_loaded = 30.0
	pad.status = GameState.PAD_LOADING
	state.amounts["he3"] = 10.0
	# Cap is large enough to absorb the return
	state.caps["he3"] = 500.0

	sim.set_pad_resource(state, 0, "ti")

	_assert_approx(state.amounts.get("he3", 0.0), 40.0, 0.001,
		"pad switch: cargo returned to supply (10 + 30 = 40)")


func _test_cargo_clamped_at_cap_on_switch() -> void:
	var arr := _make_pad_state()
	var sim: GameSimulation = arr[0]
	var state: GameState = arr[1]
	var pad: GameState.LaunchPadData = arr[2]

	pad.resource_type = "he3"
	pad.cargo_loaded = 80.0
	pad.status = GameState.PAD_FULL
	state.amounts["he3"] = 50.0
	state.caps["he3"] = 100.0

	sim.set_pad_resource(state, 0, "ti")

	# 50 + 80 = 130 → clamped to cap 100
	_assert_approx(state.amounts.get("he3", 0.0), 100.0, 0.001,
		"pad switch: returned cargo clamped at storage cap")


func _test_pad_resets_after_switch() -> void:
	var arr := _make_pad_state()
	var sim: GameSimulation = arr[0]
	var state: GameState = arr[1]
	var pad: GameState.LaunchPadData = arr[2]

	pad.resource_type = "ti"
	pad.cargo_loaded = 55.0
	pad.status = GameState.PAD_LOADING
	state.amounts["ti"] = 0.0
	state.caps["ti"] = 500.0

	sim.set_pad_resource(state, 0, "he3")

	_assert_approx(pad.cargo_loaded, 0.0, 0.001, "pad switch: cargo_loaded reset to 0")
	_assert_equal(pad.status, GameState.PAD_EMPTY, "pad switch: status reset to PAD_EMPTY")
	_assert_equal(pad.resource_type, "he3", "pad switch: resource_type updated to new value")


func _test_no_cargo_switch_is_clean() -> void:
	var arr := _make_pad_state()
	var sim: GameSimulation = arr[0]
	var state: GameState = arr[1]
	var pad: GameState.LaunchPadData = arr[2]

	pad.resource_type = "cir"
	pad.cargo_loaded = 0.0
	pad.status = GameState.PAD_EMPTY
	state.amounts["cir"] = 20.0
	state.caps["cir"] = 200.0

	sim.set_pad_resource(state, 0, "prop")

	_assert_approx(state.amounts.get("cir", 0.0), 20.0, 0.001,
		"pad switch (no cargo): supply unchanged")
	_assert_equal(pad.resource_type, "prop", "pad switch (no cargo): resource_type updated")
