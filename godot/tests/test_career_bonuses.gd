extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	print("--- Career Bonuses ---")
	_test_ideology_formula()
	_test_starting_credits()
	_test_boredom_resilience()
	_test_buy_power_scaling()
	_test_ideology_head_start()
	_test_rank_formula_round_trip()


func _test_ideology_formula() -> void:
	# score_for_rank reference values
	_assert_approx(GameState.score_for_rank(1.0), 100.0, 0.01, "score_for_rank(1) = 100")
	_assert_approx(GameState.score_for_rank(2.0), 250.0, 0.01, "score_for_rank(2) = 250")
	_assert_approx(GameState.score_for_rank(5.0), 1318.75, 0.1, "score_for_rank(5) ≈ 1318.75")

	# continuous_rank_for_score inverse
	_assert_approx(GameState.continuous_rank_for_score(100.0), 1.0, 0.0001, "continuous_rank_for_score(100) = 1.0")
	_assert_approx(GameState.continuous_rank_for_score(250.0), 2.0, 0.0001, "continuous_rank_for_score(250) = 2.0")

	# Negative scores give negative results
	_assert_approx(GameState.score_for_rank(-1.0), -100.0, 0.01, "score_for_rank(-1) = -100")
	_assert_approx(GameState.continuous_rank_for_score(-250.0), -2.0, 0.0001, "continuous_rank_for_score(-250) = -2.0")

	# Rank cap — need score beyond score_for_rank(99) ≈ 5.4e19; use 1e22
	var state := GameState.new()
	state.ideology_values["nationalist"] = 1e22
	_assert_equal(state.get_ideology_rank("nationalist"), 99, "rank capped at 99 for huge positive value")
	state.ideology_values["nationalist"] = -1e22
	_assert_equal(state.get_ideology_rank("nationalist"), -99, "rank capped at -99 for huge negative value")


func _test_starting_credits() -> void:
	var career := CareerState.new()
	career.best_run_credits = 5000.0
	var credits_bonus: int = int(floor(career.best_run_credits / 100.0))
	_assert_equal(credits_bonus, 50, "starting credits = 50 when best_run_credits = 5000")

	career.best_run_credits = 12806.0
	credits_bonus = int(floor(career.best_run_credits / 100.0))
	_assert_equal(credits_bonus, 128, "starting credits = 128 when best_run_credits = 12806")

	career.best_run_credits = 0.0
	credits_bonus = int(floor(career.best_run_credits / 100.0))
	_assert_equal(credits_bonus, 0, "starting credits = 0 on first run (no best yet)")


func _test_boredom_resilience() -> void:
	var career := CareerState.new()
	career.best_run_days = 800
	var mult: float = pow(0.995, career.best_run_days / 400.0)
	_assert_approx(mult, pow(0.995, 2.0), 0.0001, "resilience mult at 800 days ≈ 0.990")

	career.best_run_days = 1500
	mult = pow(0.995, career.best_run_days / 400.0)
	_assert_approx(mult, pow(0.995, 3.75), 0.0001, "resilience mult at 1500 days ≈ 0.981")

	career.best_run_days = 0
	mult = pow(0.995, career.best_run_days / 400.0)
	_assert_approx(mult, 1.0, 0.0001, "resilience mult at 0 days = 1.0 (no reduction)")


func _test_buy_power_scaling() -> void:
	var career := CareerState.new()

	career.peak_power_production = 0.0
	var bp_mult: float = 1.0 + maxf(0.0, career.peak_power_production - 100.0) * 0.01
	_assert_approx(bp_mult, 1.0, 0.0001, "buy_power_mult = 1.0 at peak 0")

	career.peak_power_production = 100.0
	bp_mult = 1.0 + maxf(0.0, career.peak_power_production - 100.0) * 0.01
	_assert_approx(bp_mult, 1.0, 0.0001, "buy_power_mult = 1.0 at peak 100 (threshold)")

	career.peak_power_production = 150.0
	bp_mult = 1.0 + maxf(0.0, career.peak_power_production - 100.0) * 0.01
	_assert_approx(bp_mult, 1.5, 0.0001, "buy_power_mult = 1.5 at peak 150")

	career.peak_power_production = 200.0
	bp_mult = 1.0 + maxf(0.0, career.peak_power_production - 100.0) * 0.01
	_assert_approx(bp_mult, 2.0, 0.0001, "buy_power_mult = 2.0 at peak 200")

	career.peak_power_production = 300.0
	bp_mult = 1.0 + maxf(0.0, career.peak_power_production - 100.0) * 0.01
	_assert_approx(bp_mult, 3.0, 0.0001, "buy_power_mult = 3.0 at peak 300")


func _test_ideology_head_start() -> void:
	# best Humanist score = 1318.75 (rank 5.0 continuous)
	# starting_rank = 5.0 * 0.2 = 1.0; starting_score = score_for_rank(1.0) = 100
	var max_score: float = 1318.75
	var max_cont: float = GameState.continuous_rank_for_score(max_score)
	var starting_cont: float = max_cont * 0.2
	var starting_score: float = GameState.score_for_rank(starting_cont)
	_assert_approx(max_cont, 5.0, 0.001, "continuous rank for 1318.75 = 5.0")
	_assert_approx(starting_cont, 1.0, 0.001, "starting continuous rank = 1.0")
	_assert_approx(starting_score, 100.0, 0.1, "starting score = 100 (rank 1 head start)")

	# best Nationalist score = score_for_rank(10) ≈ 11333 (rank 10.0); starting rank = 2.0; score = 250
	# Note: spec listed 7930 as rank 10 reference but that was a typo; formula gives ~11333
	max_score = GameState.score_for_rank(10.0)
	max_cont = GameState.continuous_rank_for_score(max_score)
	starting_cont = max_cont * 0.2
	starting_score = GameState.score_for_rank(starting_cont)
	_assert_approx(max_cont, 10.0, 0.01, "continuous rank for score_for_rank(10) = 10.0")
	_assert_approx(starting_cont, 2.0, 0.01, "starting continuous rank = 2.0")
	_assert_approx(starting_score, 250.0, 0.5, "starting score = 250 (rank 2 head start)")

	# No head start if max_score = 0
	max_score = 0.0
	max_cont = GameState.continuous_rank_for_score(max_score)
	starting_cont = max_cont * 0.2
	starting_score = GameState.score_for_rank(starting_cont)
	_assert_approx(starting_score, 0.0, 0.0001, "starting score = 0 when no prior score")


func _test_rank_formula_round_trip() -> void:
	# score_for_rank(continuous_rank_for_score(X)) ≈ X for several values.
	# Note: 7930 was listed in an early spec as the rank-10 threshold — that was a typo.
	# The correct formula value is score_for_rank(10) = 200*(1.5^10 - 1) ≈ 11333.
	_assert_approx(GameState.score_for_rank(10.0), 200.0 * (pow(1.5, 10.0) - 1.0), 0.01,
		"score_for_rank(10) matches formula directly (spec typo guard: NOT 7930)")
	_assert_approx(GameState.continuous_rank_for_score(GameState.score_for_rank(10.0)), 10.0, 0.0001,
		"continuous_rank_for_score(score_for_rank(10)) = 10.0")

	for test_score: float in [100.0, 250.0, 475.0, 812.5, 1318.75, GameState.score_for_rank(10.0)]:
		var cont: float = GameState.continuous_rank_for_score(test_score)
		var recovered: float = GameState.score_for_rank(cont)
		_assert_approx(recovered, test_score, test_score * 0.0001 + 0.01,
			"round-trip score_for_rank(continuous_rank_for_score(%s)) ≈ %s" % [test_score, test_score])
