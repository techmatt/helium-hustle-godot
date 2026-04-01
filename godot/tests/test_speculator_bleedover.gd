extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_no_bleedover_below_threshold()
	_test_bleedover_above_threshold()
	_test_bleedover_scales_with_count()
	_test_targeted_resource_unaffected_by_bleedover()
	_test_bleedover_applies_to_all_non_targeted()
	_test_bleedover_respects_demand_floor()


func _test_no_bleedover_below_threshold() -> void:
	print("--- Speculator Bleedover: No bleedover below threshold ---")
	var sim := TF.create_fresh_sim()

	# Baseline: 0 speculators targeting he3
	var base := TF.fresh_state_demand_isolated(sim)
	base.speculator_count = 0.0
	base.speculator_target = "he3"
	sim.demand_system.tick_demand(base)

	# 150 speculators targeting he3 — below the 200 threshold
	var state := TF.fresh_state_demand_isolated(sim)
	state.speculator_count = 150.0
	state.speculator_target = "he3"
	sim.demand_system.tick_demand(state)

	# Titanium demand should not be suppressed below baseline — coupling bonus
	# actually lifts it slightly above baseline, but no bleedover suppression applies.
	_assert_true(state.demand.get("ti", 0.0) >= base.demand.get("ti", 0.0) - 0.001,
		"bleedover: count=150 (below 200 threshold) causes no bleedover suppression on ti")


func _test_bleedover_above_threshold() -> void:
	print("--- Speculator Bleedover: Bleedover above threshold ---")
	var sim := TF.create_fresh_sim()

	# Baseline: 0 speculators
	var base := TF.fresh_state_demand_isolated(sim)
	base.speculator_count = 0.0
	base.speculator_target = "he3"
	sim.demand_system.tick_demand(base)

	# 500 speculators targeting he3
	# direct_suppression = 0.5 * (500/550) ≈ 0.4545
	# excess = 300, bleedover_fraction = (300/600) * 0.5 = 0.25
	# bleedover_suppression ≈ 0.4545 * 0.25 ≈ 0.1136
	var state := TF.fresh_state_demand_isolated(sim)
	state.speculator_count = 500.0
	state.speculator_target = "he3"
	sim.demand_system.tick_demand(state)

	var ti_delta: float = base.demand.get("ti", 0.0) - state.demand.get("ti", 0.0)
	# Expected bleedover ≈ 0.114, but demand may be clamped; allow generous tolerance
	# and account for coupling bonus which partially offsets suppression
	_assert_gt(ti_delta, 0.05,
		"bleedover: count=500 reduces ti demand by more than 0.05 (net of coupling)")
	_assert_lt(ti_delta, 0.20,
		"bleedover: count=500 reduces ti demand by less than 0.20")


func _test_bleedover_scales_with_count() -> void:
	print("--- Speculator Bleedover: Bleedover scales with count ---")
	var sim := TF.create_fresh_sim()

	var base := TF.fresh_state_demand_isolated(sim)
	base.speculator_count = 0.0
	base.speculator_target = "he3"
	sim.demand_system.tick_demand(base)

	var state_300 := TF.fresh_state_demand_isolated(sim)
	state_300.speculator_count = 300.0
	state_300.speculator_target = "he3"
	sim.demand_system.tick_demand(state_300)

	var state_1000 := TF.fresh_state_demand_isolated(sim)
	state_1000.speculator_count = 1000.0
	state_1000.speculator_target = "he3"
	sim.demand_system.tick_demand(state_1000)

	var delta_300: float = base.demand.get("ti", 0.0) - state_300.demand.get("ti", 0.0)
	var delta_1000: float = base.demand.get("ti", 0.0) - state_1000.demand.get("ti", 0.0)

	_assert_gt(delta_1000, delta_300,
		"bleedover: count=1000 suppresses ti more than count=300")


func _test_targeted_resource_unaffected_by_bleedover() -> void:
	print("--- Speculator Bleedover: Targeted resource uses only direct suppression ---")
	var sim := TF.create_fresh_sim()

	# At count=500, targeting he3:
	# direct_suppression = 0.5 * (500/550) ≈ 0.4545
	# bleedover_suppression ≈ 0.1136
	# he3 should see direct_suppression only, NOT direct + bleedover
	var base := TF.fresh_state_demand_isolated(sim)
	base.speculator_count = 0.0
	base.speculator_target = "he3"
	sim.demand_system.tick_demand(base)

	var state := TF.fresh_state_demand_isolated(sim)
	state.speculator_count = 500.0
	state.speculator_target = "he3"
	sim.demand_system.tick_demand(state)

	var he3_delta: float = base.demand.get("he3", 0.0) - state.demand.get("he3", 0.0)
	var direct_sup: float = sim.demand_system.get_suppression(state, "he3")

	# he3 delta should be approximately direct_suppression, not direct + bleedover
	_assert_approx(he3_delta, direct_sup, 0.01,
		"bleedover: he3 (target) demand delta equals direct suppression, not direct+bleedover")


func _test_bleedover_applies_to_all_non_targeted() -> void:
	print("--- Speculator Bleedover: Applies equally to all non-targeted resources ---")
	var sim := TF.create_fresh_sim()

	var base := TF.fresh_state_demand_isolated(sim)
	base.speculator_count = 0.0
	base.speculator_target = "he3"
	sim.demand_system.tick_demand(base)

	var state := TF.fresh_state_demand_isolated(sim)
	state.speculator_count = 500.0
	state.speculator_target = "he3"
	sim.demand_system.tick_demand(state)

	var delta_ti: float = base.demand.get("ti", 0.0) - state.demand.get("ti", 0.0)
	var delta_cir: float = base.demand.get("cir", 0.0) - state.demand.get("cir", 0.0)
	var delta_prop: float = base.demand.get("prop", 0.0) - state.demand.get("prop", 0.0)

	# All three non-targeted resources receive the same bleedover suppression
	# (coupling bonus is identical across them too, since spec_target is fixed)
	_assert_approx(delta_ti, delta_cir, 0.001,
		"bleedover: ti and cir receive identical bleedover suppression")
	_assert_approx(delta_ti, delta_prop, 0.001,
		"bleedover: ti and prop receive identical bleedover suppression")


func _test_bleedover_respects_demand_floor() -> void:
	print("--- Speculator Bleedover: Demand floor respected under extreme count ---")
	var sim := TF.create_fresh_sim()

	var state := TF.fresh_state_demand_isolated(sim)
	state.speculator_count = 100000.0
	state.speculator_target = "he3"
	sim.demand_system.tick_demand(state)

	for res: String in GameState.TRADEABLE_RESOURCES:
		_assert_true(state.demand.get(res, 0.0) >= 0.01,
			"bleedover: %s demand >= 0.01 floor under extreme speculator count" % res)
