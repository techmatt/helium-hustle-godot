extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_demand_config_values()
	_test_demand_bounds()
	_test_demand_speculator_suppression()
	_test_demand_speculator_decay()
	_test_demand_rival_dumps()
	_test_demand_promote_effect()
	_test_demand_perlin_noise()


func _test_demand_config_values() -> void:
	print("--- Demand: Config Values ---")
	var config := TF.load_game_config()
	var d: Dictionary = config.get("demand", {})
	_assert_approx(float(d.get("min_demand", -1.0)), 0.01, 0.0001,
		"config: min_demand = 0.01")
	_assert_approx(float(d.get("max_demand", -1.0)), 1.0, 0.0001,
		"config: max_demand = 1.0")
	_assert_approx(float(d.get("speculator_max_suppression", -1.0)), 0.5, 0.0001,
		"config: speculator_max_suppression = 0.5")
	_assert_approx(float(d.get("speculator_half_point", -1.0)), 50.0, 0.0001,
		"config: speculator_half_point = 50.0")
	_assert_true(float(d.get("perlin_freq_min", 0.0)) < float(d.get("perlin_freq_max", 0.0)),
		"config: perlin_freq_min < perlin_freq_max")
	_assert_true(int(d.get("speculator_burst_interval_min", 0)) < int(d.get("speculator_burst_interval_max", 0)),
		"config: speculator_burst_interval_min < speculator_burst_interval_max")
	for key: String in d:
		_assert_true(float(d[key]) >= 0.0,
			"config: demand." + key + " is non-negative")


func _test_demand_bounds() -> void:
	print("--- Demand: Bounds ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	# Defer bursts and rival dumps so speculator count stays zero during this run
	TF.defer_random_events(state)

	for _i in range(100):
		sim.tick(state, true)
		for res: String in GameState.TRADEABLE_RESOURCES:
			var d: float = state.demand.get(res, 0.5)
			_assert_true(d >= 0.01,
				"bounds: %s demand >= 0.01 (day %d)" % [res, state.current_day])
			_assert_true(d <= 1.0,
				"bounds: %s demand <= 1.0 (day %d)" % [res, state.current_day])

	# Min floor holds under extreme speculator suppression
	var state_extreme := TF.fresh_state_demand_isolated(sim)
	state_extreme.speculator_count = 10000.0
	state_extreme.speculator_target = "he3"
	sim.demand_system.tick_demand(state_extreme)
	_assert_true(state_extreme.demand.get("he3", 0.0) >= 0.01,
		"bounds: min floor holds under extreme speculator suppression (count=10000)")

	# Max ceiling holds under extreme promote
	var state_promo := TF.fresh_state_demand_isolated(sim)
	state_promo.demand_promote["he3"] = 1000.0
	sim.demand_system.tick_demand(state_promo)
	_assert_true(state_promo.demand.get("he3", 0.0) <= 1.0,
		"bounds: max ceiling holds under extreme promote effect")


func _test_demand_speculator_suppression() -> void:
	print("--- Demand: Speculator Suppression ---")
	var sim := TF.create_fresh_sim()

	# Verify the suppression value directly via get_suppression()
	var state_sup := TF.fresh_state_demand_isolated(sim)
	state_sup.speculator_target = "he3"

	state_sup.speculator_count = 50.0
	_assert_approx(sim.demand_system.get_suppression(state_sup, "he3"), 0.25, 0.001,
		"suppression: count=50 (half-point) returns suppression 0.25")

	state_sup.speculator_count = 200.0
	_assert_approx(sim.demand_system.get_suppression(state_sup, "he3"), 0.4, 0.001,
		"suppression: count=200 returns suppression 0.4")

	state_sup.speculator_count = 10000.0
	var max_sup: float = sim.demand_system.get_config("speculator_max_suppression")
	_assert_lt(sim.demand_system.get_suppression(state_sup, "he3"), max_sup,
		"suppression: asymptotic — count=10000 never reaches max_suppression")

	# Non-target resource is unaffected
	_assert_approx(sim.demand_system.get_suppression(state_sup, "ti"), 0.0, 0.001,
		"suppression: non-target resource has zero suppression")

	# Verify suppression effect on demand using identical noise (fixed seeds, same day).
	# All three states use the same seeds and day=0, so noise is identical.
	# Only difference is speculator_count — demand delta equals suppression delta exactly.
	var state_0 := TF.fresh_state_demand_isolated(sim)
	var state_50 := TF.fresh_state_demand_isolated(sim)
	var state_200 := TF.fresh_state_demand_isolated(sim)
	for s: GameState in [state_0, state_50, state_200]:
		s.speculator_target = "he3"
	state_0.speculator_count = 0.0
	state_50.speculator_count = 50.0
	state_200.speculator_count = 200.0
	sim.demand_system.tick_demand(state_0)
	sim.demand_system.tick_demand(state_50)
	sim.demand_system.tick_demand(state_200)

	var d0: float = state_0.demand["he3"]
	var d50: float = state_50.demand["he3"]
	var d200: float = state_200.demand["he3"]
	_assert_gt(d0, d50, "suppression: demand at count=50 is less than at count=0")
	_assert_gt(d50, d200, "suppression: demand at count=200 is less than at count=50")
	_assert_approx(d0 - d50, 0.25, 0.005,
		"suppression: demand delta at half-point matches get_suppression")
	_assert_approx(d0 - d200, 0.4, 0.005,
		"suppression: demand delta at count=200 matches get_suppression")


func _test_demand_speculator_decay() -> void:
	print("--- Demand: Speculator Decay ---")
	var sim := TF.create_fresh_sim()

	# Single tick proportional decay: 100 * 0.006 = 0.6 removed → 99.4
	var state := TF.fresh_state_demand_isolated(sim)
	state.speculator_count = 100.0
	sim.demand_system.tick_speculators(state)
	_assert_approx(state.speculator_count, 99.4, 0.001,
		"decay: single tick removes 0.6 (100 * 0.006)")

	# 200 ticks: geometric decay — 100 * (1 - 0.006)^200 ≈ 29.9
	state = TF.fresh_state_demand_isolated(sim)
	state.speculator_count = 100.0
	for _i in range(200):
		sim.demand_system.tick_speculators(state)
	_assert_lt(state.speculator_count, 50.0,
		"decay: count drops significantly after 200 ticks")
	_assert_gt(state.speculator_count, 0.0,
		"decay: proportional decay never reaches exactly zero")
	_assert_approx(state.speculator_count, 100.0 * pow(1.0 - 0.006, 200.0), 0.1,
		"decay: 200-tick count matches geometric decay formula")

	# Arbitrage Engine bonus: adds 0.04 per active engine per tick
	# Expected: 100 - 0.6 (proportional) - 0.04 (arbitrage) = 99.36
	state = TF.fresh_state_demand_isolated(sim)
	state.speculator_count = 100.0
	TF.add_building(state, "arbitrage_engine", 1)
	sim.demand_system.tick_speculators(state)
	_assert_approx(state.speculator_count, 99.36, 0.001,
		"decay: arbitrage engine contributes 0.04 extra decay per tick")


func _test_demand_rival_dumps() -> void:
	print("--- Demand: Rival Dumps ---")
	var sim := TF.create_fresh_sim()

	# Inject rival pressure directly and verify tick_demand decays it.
	# rival_demand_decay_rate = 0.003/tick. 0.3 / 0.003 = 100 ticks to fully clear.
	var state := TF.fresh_state_demand_isolated(sim)
	state.demand_rival["he3"] = 0.3
	_assert_approx(state.demand_rival.get("he3", 0.0), 0.3, 0.001,
		"rival: initial pressure injected as 0.3")

	for i in range(100):
		state.current_day = i
		sim.demand_system.tick_demand(state)
	_assert_approx(state.demand_rival.get("he3", 0.0), 0.0, 0.001,
		"rival: demand_rival pressure fully decays after 100 ticks (0.003/tick)")

	# Mid-recovery: 50 ticks decay 0.3 - 50*0.003 = 0.15 remaining
	state = TF.fresh_state_demand_isolated(sim)
	state.demand_rival["he3"] = 0.3
	for i in range(50):
		state.current_day = i
		sim.demand_system.tick_demand(state)
	_assert_approx(state.demand_rival.get("he3", 0.0), 0.15, 0.005,
		"rival: demand_rival pressure halved after 50 ticks")

	# Rival pressure is resource-specific: he3 pressure does not affect ti
	state = TF.fresh_state_demand_isolated(sim)
	state.demand_rival["he3"] = 0.3
	state.demand_rival["ti"] = 0.0
	sim.demand_system.tick_demand(state)
	_assert_approx(state.demand_rival.get("ti", 0.0), 0.0, 0.001,
		"rival: he3 rival pressure does not spill to ti")


func _test_demand_promote_effect() -> void:
	print("--- Demand: Promote Effect ---")
	var sim := TF.create_fresh_sim()

	# Executing Promote He-3 adds promote_base_effect (0.03) to demand_promote["he3"]
	var state := TF.fresh_state_with_research(sim, ["trade_promotion"])
	state.amounts["eng"] = 100.0
	state.amounts["cred"] = 100.0
	state.speculator_count = 0.0
	var promote_before: float = state.demand_promote.get("he3", 0.0)
	sim.execute_command(state, "promote_he3")
	_assert_approx(state.demand_promote.get("he3", 0.0), promote_before + 0.03, 0.001,
		"promote: Promote He-3 adds 0.03 to demand_promote")

	# demand_promote decays at 0.001/tick via tick_demand.
	# Starting at 0.03: after 30 ticks, fully decayed to 0.
	state = TF.fresh_state_demand_isolated(sim)
	state.demand_promote["he3"] = 0.03
	for i in range(30):
		state.current_day = i
		sim.demand_system.tick_demand(state)
	_assert_approx(state.demand_promote.get("he3", 0.0), 0.0, 0.002,
		"promote: demand_promote fully decays after 30 ticks (0.001/tick)")

	# Half-decay: after 15 ticks, 0.03 - 15*0.001 = 0.015 remaining
	state = TF.fresh_state_demand_isolated(sim)
	state.demand_promote["he3"] = 0.03
	for i in range(15):
		state.current_day = i
		sim.demand_system.tick_demand(state)
	_assert_approx(state.demand_promote.get("he3", 0.0), 0.015, 0.002,
		"promote: demand_promote half-decayed after 15 ticks")

	# Promote is resource-specific: promoting he3 does not affect ti
	state = TF.fresh_state_demand_isolated(sim)
	state.demand_promote["he3"] = 0.03
	state.demand_promote["ti"] = 0.0
	sim.demand_system.tick_demand(state)
	_assert_approx(state.demand_promote.get("ti", 0.0), 0.0, 0.002,
		"promote: he3 promote does not affect ti demand_promote")


func _test_demand_perlin_noise() -> void:
	print("--- Demand: Perlin Noise ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	TF.defer_random_events(state)
	state.speculator_count = 0.0
	state.speculator_target = ""

	var values: Array = []
	for i in range(500):
		state.current_day = i
		sim.demand_system.tick_demand(state)
		values.append(state.demand.get("he3", 0.5))

	var min_val: float = 1.0
	var max_val: float = 0.0
	var sum: float = 0.0
	for v: float in values:
		if v < min_val:
			min_val = v
		if v > max_val:
			max_val = v
		sum += v
	var mean: float = sum / float(values.size())

	# All values in bounds
	_assert_true(min_val >= 0.01,
		"noise: he3 min over 500 ticks is >= 0.01")
	_assert_true(max_val <= 1.0,
		"noise: he3 max over 500 ticks is <= 1.0")

	# Noise actually varies
	_assert_true(min_val < max_val,
		"noise: he3 demand is not constant over 500 ticks")

	# Range spans meaningful amplitude (perlin_amplitude=0.45 means range ~0.9 before clamp)
	_assert_gt(max_val - min_val, 0.2,
		"noise: he3 demand range spans at least 0.2 over 500 ticks")

	# Non-zero variance
	var variance: float = 0.0
	for v: float in values:
		var diff: float = v - mean
		variance += diff * diff
	variance /= float(values.size())
	_assert_gt(variance, 0.0,
		"noise: he3 demand has non-zero variance over 500 ticks")
