extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_game_state_basics()
	_test_ideology_ranks()
	_test_ideology_bonuses()


func _test_game_state_basics() -> void:
	print("--- Game State Basics ---")
	var config := TF.load_game_config()
	var buildings_data := TF.load_buildings_data()
	var state := GameState.from_config(config, buildings_data)

	_assert_equal(state.current_day, 0, "fresh state: current_day = 0")
	_assert_approx(state.amounts.get("boredom", -1.0), 0.0, 0.001, "fresh state: boredom = 0")
	_assert_equal(state.programs.size(), 5, "fresh state: 5 program slots")

	for res: String in config.get("starting_resources", {}).keys():
		_assert_true(state.amounts.has(res), "fresh state: has resource " + res)

	for bsn: String in config.get("starting_buildings", {}).keys():
		_assert_true(state.buildings_owned.has(bsn), "fresh state: has building " + bsn)

	_assert_equal(state.ideology_values.get("nationalist", -1.0), 0.0, "fresh state: nationalist = 0")
	_assert_equal(state.ideology_values.get("humanist", -1.0), 0.0, "fresh state: humanist = 0")
	_assert_equal(state.ideology_values.get("rationalist", -1.0), 0.0, "fresh state: rationalist = 0")


func _test_ideology_ranks() -> void:
	print("--- Ideology Ranks (formula: score_for_rank(n) = 200*(1.5^n - 1)) ---")
	var state := GameState.new()

	state.ideology_values["nationalist"] = 0.0
	_assert_equal(state.get_ideology_rank("nationalist"), 0, "rank 0 at value 0")

	state.ideology_values["nationalist"] = GameState.score_for_rank(1.0) - 0.1
	_assert_equal(state.get_ideology_rank("nationalist"), 0, "rank 0 just below rank-1 threshold")

	state.ideology_values["nationalist"] = GameState.score_for_rank(1.0)
	_assert_equal(state.get_ideology_rank("nationalist"), 1, "rank 1 at score_for_rank(1)")

	state.ideology_values["nationalist"] = GameState.score_for_rank(2.0) - 0.1
	_assert_equal(state.get_ideology_rank("nationalist"), 1, "rank 1 just below rank-2 threshold")

	state.ideology_values["nationalist"] = GameState.score_for_rank(2.0)
	_assert_equal(state.get_ideology_rank("nationalist"), 2, "rank 2 at score_for_rank(2)")

	state.ideology_values["nationalist"] = GameState.score_for_rank(5.0)
	_assert_equal(state.get_ideology_rank("nationalist"), 5, "rank 5 at score_for_rank(5)")

	state.ideology_values["nationalist"] = 1e22
	_assert_equal(state.get_ideology_rank("nationalist"), 99, "rank 99 (capped) at very high value (score_for_rank(99) ≈ 5.4e19)")

	state.ideology_values["nationalist"] = -GameState.score_for_rank(1.0)
	_assert_equal(state.get_ideology_rank("nationalist"), -1, "rank -1 at -score_for_rank(1)")

	state.ideology_values["nationalist"] = -GameState.score_for_rank(2.0)
	_assert_equal(state.get_ideology_rank("nationalist"), -2, "rank -2 at -score_for_rank(2)")

	state.ideology_values["nationalist"] = -GameState.score_for_rank(5.0)
	_assert_equal(state.get_ideology_rank("nationalist"), -5, "rank -5 at -score_for_rank(5)")


func _test_ideology_bonuses() -> void:
	print("--- Ideology Bonuses ---")
	var state := GameState.new()

	state.ideology_values["nationalist"] = 0.0
	_assert_approx(state.get_ideology_bonus("nationalist", 1.0, 1.05), 1.0, 0.0001,
		"bonus 1.0 at rank 0 (no effect)")

	# Nationalist rank 3
	state.ideology_values["nationalist"] = GameState.score_for_rank(3.0)
	_assert_approx(state.get_ideology_bonus("nationalist", 1.0, 1.05), pow(1.05, 3.0), 0.0001,
		"nationalist rank 3 demand mult ≈ 1.1576")

	# Humanist rank 2
	state.ideology_values["humanist"] = GameState.score_for_rank(2.0)
	_assert_approx(state.get_ideology_bonus("humanist", 1.0, 0.97), pow(0.97, 2.0), 0.0001,
		"humanist rank 2 boredom mult ≈ 0.9409")

	# Rationalist negative rank -2
	state.ideology_values["rationalist"] = -GameState.score_for_rank(2.0)
	_assert_approx(state.get_ideology_bonus("rationalist", 1.0, 1.05), pow(1.05, -2.0), 0.0001,
		"rationalist rank -2 science mult ≈ 0.9070")

	# Rank 5
	state.ideology_values["nationalist"] = GameState.score_for_rank(5.0)
	_assert_approx(state.get_ideology_bonus("nationalist", 1.0, 1.05), pow(1.05, 5.0), 0.0001,
		"rank 5 bonus ≈ 1.2763")
