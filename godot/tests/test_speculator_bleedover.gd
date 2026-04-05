extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_surge_adds_to_correct_pool()
	_test_per_pool_independent_suppression()
	_test_multiple_pools_simultaneous()
	_test_demand_floor_under_extreme_pools()
	_test_disrupt_targets_priority_order()
	_test_disrupt_does_nothing_when_no_pool()
	_test_speculators_ever_seen_tracking()
	_test_save_load_round_trip()


func _test_surge_adds_to_correct_pool() -> void:
	print("--- Speculators: Surge adds to correct resource pool ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_demand_isolated(sim)

	# Force a burst immediately targeting he3 by pre-loading scores
	state.speculator_next_burst_tick = 0
	for res: String in GameState.TRADEABLE_RESOURCES:
		state.speculator_target_scores[res] = 0.0
	state.speculator_target_scores["he3"] = 1.0  # will be chosen

	var he3_before: float = state.speculators.get("he3", 0.0)
	var ti_before: float = state.speculators.get("ti", 0.0)
	sim.demand_system.tick_speculators(state)

	_assert_gt(state.speculators.get("he3", 0.0), he3_before,
		"surge: he3 pool increases when burst targets he3")
	_assert_approx(state.speculators.get("ti", 0.0), ti_before, 0.001,
		"surge: ti pool unchanged when burst targets he3")


func _test_per_pool_independent_suppression() -> void:
	print("--- Speculators: Per-pool independent suppression ---")
	var sim := TF.create_fresh_sim()

	var base := TF.fresh_state_demand_isolated(sim)
	sim.demand_system.tick_demand(base)

	# he3 pool suppresses only he3
	var state_he3 := TF.fresh_state_demand_isolated(sim)
	state_he3.speculators["he3"] = 200.0
	sim.demand_system.tick_demand(state_he3)

	# ti pool suppresses only ti
	var state_ti := TF.fresh_state_demand_isolated(sim)
	state_ti.speculators["ti"] = 200.0
	sim.demand_system.tick_demand(state_ti)

	_assert_lt(state_he3.demand.get("he3", 0.0), base.demand.get("he3", 0.0),
		"per-pool: he3 pool suppresses he3 demand")
	_assert_approx(state_he3.demand.get("ti", 0.0), base.demand.get("ti", 0.0), 0.05,
		"per-pool: he3 pool does not suppress ti demand")
	_assert_lt(state_ti.demand.get("ti", 0.0), base.demand.get("ti", 0.0),
		"per-pool: ti pool suppresses ti demand")
	_assert_approx(state_ti.demand.get("he3", 0.0), base.demand.get("he3", 0.0), 0.05,
		"per-pool: ti pool does not suppress he3 demand")


func _test_multiple_pools_simultaneous() -> void:
	print("--- Speculators: Multiple pools active simultaneously ---")
	var sim := TF.create_fresh_sim()

	var base := TF.fresh_state_demand_isolated(sim)
	sim.demand_system.tick_demand(base)

	var state := TF.fresh_state_demand_isolated(sim)
	state.speculators["he3"] = 200.0
	state.speculators["cir"] = 200.0
	sim.demand_system.tick_demand(state)

	_assert_lt(state.demand.get("he3", 0.0), base.demand.get("he3", 0.0),
		"multi-pool: he3 suppressed when he3 pool is active")
	_assert_lt(state.demand.get("cir", 0.0), base.demand.get("cir", 0.0),
		"multi-pool: cir suppressed when cir pool is active")
	# ti and prop have no pools — should be near baseline (coupling may lift them slightly)
	_assert_true(state.demand.get("ti", 0.0) >= base.demand.get("ti", 0.0) - 0.001,
		"multi-pool: ti not suppressed (no ti pool)")


func _test_demand_floor_under_extreme_pools() -> void:
	print("--- Speculators: Demand floor respected under extreme pools ---")
	var sim := TF.create_fresh_sim()

	var state := TF.fresh_state_demand_isolated(sim)
	for res: String in GameState.TRADEABLE_RESOURCES:
		state.speculators[res] = 100000.0
	sim.demand_system.tick_demand(state)

	for res: String in GameState.TRADEABLE_RESOURCES:
		_assert_true(state.demand.get(res, 0.0) >= 0.01,
			"floor: %s demand >= 0.01 under extreme per-resource pools" % res)


func _test_disrupt_targets_priority_order() -> void:
	print("--- Speculators: Disrupt targets first pool in loading priority ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_with_research(sim, ["disruption_protocols"])
	state.amounts["eng"] = 100.0
	state.amounts["cred"] = 100.0

	# Loading priority: [he3, ti, cir, prop] (default)
	# Set pools on ti and cir but not he3 — disrupt should hit ti (first with pool > 0)
	state.speculators["he3"] = 0.0
	state.speculators["ti"] = 50.0
	state.speculators["cir"] = 30.0
	state.speculators["prop"] = 0.0
	var ti_before: float = state.speculators["ti"]
	var cir_before: float = state.speculators["cir"]

	sim.execute_command(state, "disrupt_speculators")

	_assert_lt(state.speculators.get("ti", 0.0), ti_before,
		"disrupt: ti pool reduced (first priority resource with speculators)")
	_assert_approx(state.speculators.get("cir", 0.0), cir_before, 0.001,
		"disrupt: cir pool unchanged (ti came first in priority)")


func _test_disrupt_does_nothing_when_no_pool() -> void:
	print("--- Speculators: Disrupt does nothing when no priority resource has speculators ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_with_research(sim, ["disruption_protocols"])
	state.amounts["eng"] = 100.0
	state.amounts["cred"] = 100.0

	for res: String in GameState.TRADEABLE_RESOURCES:
		state.speculators[res] = 0.0

	sim.execute_command(state, "disrupt_speculators")

	for res: String in GameState.TRADEABLE_RESOURCES:
		_assert_approx(state.speculators.get(res, 0.0), 0.0, 0.001,
			"disrupt: %s pool stays at 0 when no pools have speculators" % res)


func _test_speculators_ever_seen_tracking() -> void:
	print("--- Speculators: speculators_ever_seen tracks burst targets ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_demand_isolated(sim)

	# No burst yet — nothing ever seen
	for res: String in GameState.TRADEABLE_RESOURCES:
		_assert_true(not state.speculators_ever_seen.get(res, false),
			"ever_seen: %s is false before any burst" % res)

	# Force a burst targeting cir
	state.speculator_next_burst_tick = 0
	for res: String in GameState.TRADEABLE_RESOURCES:
		state.speculator_target_scores[res] = 0.0
	state.speculator_target_scores["cir"] = 1.0
	sim.demand_system.tick_speculators(state)

	_assert_true(state.speculators_ever_seen.get("cir", false),
		"ever_seen: cir is true after burst targeted cir")
	_assert_true(not state.speculators_ever_seen.get("he3", false),
		"ever_seen: he3 still false after cir burst")


func _test_save_load_round_trip() -> void:
	print("--- Speculators: speculators dict round-trips through save/load ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_demand_isolated(sim)

	state.speculators["he3"] = 42.5
	state.speculators["ti"] = 0.0
	state.speculators["cir"] = 15.0
	state.speculators["prop"] = 0.0
	state.speculators_ever_seen["he3"] = true
	state.speculators_ever_seen["cir"] = true

	var data: Dictionary = state.to_dict()
	var restored: GameState = GameState.from_dict(data)

	_assert_approx(restored.speculators.get("he3", -1.0), 42.5, 0.001,
		"save/load: he3 pool round-trips correctly")
	_assert_approx(restored.speculators.get("cir", -1.0), 15.0, 0.001,
		"save/load: cir pool round-trips correctly")
	_assert_approx(restored.speculators.get("ti", -1.0), 0.0, 0.001,
		"save/load: ti pool round-trips as 0")
	_assert_true(restored.speculators_ever_seen.get("he3", false),
		"save/load: he3 speculators_ever_seen round-trips true")
	_assert_true(restored.speculators_ever_seen.get("cir", false),
		"save/load: cir speculators_ever_seen round-trips true")
	_assert_true(not restored.speculators_ever_seen.get("ti", false),
		"save/load: ti speculators_ever_seen round-trips false")
