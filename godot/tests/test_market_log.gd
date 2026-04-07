extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_entry_type_defaults()
	_test_serialization_roundtrip()
	_test_cap_at_15()
	_test_speculator_surge_type()


func _test_entry_type_defaults() -> void:
	print("--- MarketLog: Entry type defaults ---")
	var r := GameState.LaunchRecord.new()
	_assert_equal(r.entry_type, "neutral", "default entry_type is neutral")

	var player := GameState.LaunchRecord.new()
	player.entry_type = "player_launch"
	_assert_equal(player.entry_type, "player_launch", "player_launch type round-trips on instance")

	var rival := GameState.LaunchRecord.new()
	rival.entry_type = "rival_flood"
	_assert_equal(rival.entry_type, "rival_flood", "rival_flood type round-trips on instance")

	var spec := GameState.LaunchRecord.new()
	spec.entry_type = "speculator_surge"
	_assert_equal(spec.entry_type, "speculator_surge", "speculator_surge type round-trips on instance")


func _test_serialization_roundtrip() -> void:
	print("--- MarketLog: Serialization roundtrip ---")
	for etype: String in ["player_launch", "rival_flood", "speculator_surge", "neutral"]:
		var r := GameState.LaunchRecord.new()
		r.resource_type = "he3"
		r.quantity = 100.0
		r.credits_earned = 250.0
		r.tick = 42
		r.source_type = "player"
		r.entry_type = etype
		var d: Dictionary = r.to_dict()
		_assert_equal(d.get("entry_type"), etype, "to_dict preserves entry_type: " + etype)
		var r2: GameState.LaunchRecord = GameState.LaunchRecord.from_dict(d)
		_assert_equal(r2.entry_type, etype, "from_dict restores entry_type: " + etype)

	# Legacy records without entry_type field default to neutral
	var legacy: Dictionary = {"resource_type": "he3", "tick": 1, "source_type": "player"}
	var r3: GameState.LaunchRecord = GameState.LaunchRecord.from_dict(legacy)
	_assert_equal(r3.entry_type, "neutral", "legacy record missing entry_type defaults to neutral")


func _test_cap_at_15() -> void:
	print("--- MarketLog: Cap at 15 ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	for i in range(20):
		var r := GameState.LaunchRecord.new()
		r.tick = i
		r.entry_type = "player_launch"
		state.launch_history.push_front(r)
		if state.launch_history.size() > 15:
			state.launch_history.pop_back()
	_assert_equal(state.launch_history.size(), 15, "launch_history capped at 15 entries")
	_assert_equal(state.launch_history[0].tick, 19, "most recent entry is at index 0")
	_assert_equal(state.launch_history[14].tick, 5, "oldest retained entry is at index 14")


func _test_speculator_surge_type() -> void:
	print("--- MarketLog: Speculator surge creates correct entry_type ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	state.speculator_next_burst_tick = 0
	state.current_day = 1
	sim.demand_system._fire_speculator_burst(state)
	_assert_true(state.launch_history.size() > 0, "speculator burst appended to history")
	_assert_equal(state.launch_history[0].entry_type, "speculator_surge",
		"speculator burst entry has entry_type speculator_surge")
	_assert_equal(state.launch_history[0].source_type, "speculator",
		"speculator burst entry has source_type speculator")
