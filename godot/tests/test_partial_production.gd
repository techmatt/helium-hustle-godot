extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_basic_partial_production()
	_test_steady_state_convergence()
	_test_zero_input_zero_production()
	_test_full_input_full_production()
	_test_multi_resource_bottleneck()
	_test_output_capped_unaffected()
	_test_no_production_building_unaffected()
	_test_processing_order_priority()


# 1. Basic partial production
func _test_basic_partial_production() -> void:
	print("--- Partial Production: Basic ---")

	# 1 Excavator produces 2 reg/tick. 1 Smelter needs 2 reg + 3 eng/tick.
	# Start: reg=1 (half of what Smelter needs), plenty of eng.
	# Excavator runs first → reg: 1 + 2 = 3. Smelter sees 3 reg, needs 2 → fraction=1.0?
	# Wait — upkeep is Pass 1, Excavator is Pass 1 too. Let's think again.
	# Excavator has upkeep (eng) so it's in Pass 1. Smelter has upkeep too.
	# Both are processed in JSON row order. Excavator runs first.
	# But upkeep (Pass 1) and production (Pass 2) are separate.
	# Pass 1: Excavator pays 2 eng upkeep. Smelter checks reg fraction: reg=1, needs 2 → fraction=0.5.
	# Pass 2: Excavator produces 2 reg. Smelter produces 0.5 ti.
	# Post-tick: reg = 1 - 1(smelter) + 2(excav) = 2.

	var exc_bdef := TF.get_building_def("excavator")
	var sml_bdef := TF.get_building_def("smelter")
	var sml_upkeep_reg: float = float(sml_bdef.get("upkeep", {}).get("reg", 0.0))
	var sml_prod_ti: float = float(sml_bdef.get("production", {}).get("ti", 0.0))
	var exc_prod_reg: float = float(exc_bdef.get("production", {}).get("reg", 0.0))

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	TF.add_building(state, "smelter")
	var reg_start: float = sml_upkeep_reg * 0.5  # half what smelter needs
	state.amounts["reg"] = reg_start
	state.amounts["ti"] = 0.0
	state.amounts["eng"] = 100.0
	sim.tick(state, true)

	var expected_fraction: float = reg_start / sml_upkeep_reg  # 0.5
	# Pass 1: smelter pays reg_start * fraction (= reg_start). Pass 2: excavator adds exc_prod_reg.
	var expected_reg: float = reg_start - (sml_upkeep_reg * expected_fraction) + exc_prod_reg
	var expected_ti: float = sml_prod_ti * expected_fraction

	_assert_approx(state.amounts.get("ti", 0.0), expected_ti, 0.001,
		"partial_production: smelter produces titanium scaled by fraction")
	_assert_approx(state.amounts.get("reg", 0.0), expected_reg, 0.001,
		"partial_production: reg = start - smelter_fraction_upkeep + excavator_prod")
	_assert_stall_status(state, "smelter", "input_starved",
		"partial_production: smelter flagged input_starved when running at fraction < 1.0")


# 2. Steady-state convergence
func _test_steady_state_convergence() -> void:
	print("--- Partial Production: Steady State ---")

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	TF.add_building(state, "smelter")
	state.amounts["reg"] = 1.0
	state.amounts["ti"] = 0.0
	state.amounts["eng"] = 1000.0

	var ti_prev: float = 0.0
	for _i in range(10):
		sim.tick(state, true)
		var ti_now: float = state.amounts.get("ti", 0.0)
		_assert_true(ti_now > ti_prev,
			"partial_production steady: titanium increases each tick")
		ti_prev = ti_now

	# Reg should not grow unbounded (smelter consuming some each tick)
	_assert_true(state.amounts.get("reg", 0.0) < 50.0,
		"partial_production steady: reg does not accumulate unbounded")


# 3. Zero input = zero production
func _test_zero_input_zero_production() -> void:
	print("--- Partial Production: Zero Input ---")

	var sml_bdef := TF.get_building_def("smelter")
	var sml_upkeep_eng: float = float(sml_bdef.get("upkeep", {}).get("eng", 0.0))

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "smelter")
	state.amounts["reg"] = 0.0   # zero of a needed resource
	state.amounts["eng"] = sml_upkeep_eng * 5.0
	state.amounts["ti"] = 0.0
	sim.tick(state, true)

	_assert_approx(state.amounts.get("ti", 0.0), 0.0, 0.001,
		"partial_production zero: no production when one input is 0")
	_assert_approx(state.amounts.get("reg", 0.0), 0.0, 0.001,
		"partial_production zero: no reg consumed when fraction=0")
	# eng should also be unchanged (fraction=0 means nothing is consumed)
	_assert_approx(state.amounts.get("eng", 0.0), sml_upkeep_eng * 5.0, 0.001,
		"partial_production zero: no eng consumed when fraction=0")
	_assert_stall_status(state, "smelter", "input_starved",
		"partial_production zero: smelter flagged input_starved when fraction=0")


# 4. Full input = full production, not flagged input_starved
func _test_full_input_full_production() -> void:
	print("--- Partial Production: Full Input ---")

	var exc_bdef := TF.get_building_def("excavator")
	var exc_upkeep_eng: float = float(exc_bdef.get("upkeep", {}).get("eng", 0.0))
	var exc_prod_reg: float = float(exc_bdef.get("production", {}).get("reg", 0.0))

	var eng_start: float = exc_upkeep_eng * 5.0

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["eng"] = eng_start
	state.amounts["reg"] = 0.0
	sim.tick(state, true)

	_assert_approx(state.amounts.get("eng", 0.0), eng_start - exc_upkeep_eng, 0.001,
		"partial_production full: excavator pays full upkeep")
	_assert_approx(state.amounts.get("reg", 0.0), exc_prod_reg, 0.001,
		"partial_production full: excavator produces full output")
	_assert_stall_status(state, "excavator", "running",
		"partial_production full: excavator NOT flagged input_starved when inputs sufficient")


# 5. Multi-resource bottleneck: tightest constraint wins
func _test_multi_resource_bottleneck() -> void:
	print("--- Partial Production: Multi-Resource Bottleneck ---")

	# Smelter upkeep: eng=3, reg=2.
	# Give 50% of reg needed but 30% of eng needed.
	# Fraction = min(0.5, 0.3) = 0.3 → tightest constraint is eng.
	var sml_bdef := TF.get_building_def("smelter")
	var sml_upkeep_eng: float = float(sml_bdef.get("upkeep", {}).get("eng", 0.0))
	var sml_upkeep_reg: float = float(sml_bdef.get("upkeep", {}).get("reg", 0.0))
	var sml_prod_ti: float = float(sml_bdef.get("production", {}).get("ti", 0.0))

	var eng_start: float = sml_upkeep_eng * 0.3
	var reg_start: float = sml_upkeep_reg * 0.5

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "smelter")
	state.amounts["eng"] = eng_start
	state.amounts["reg"] = reg_start
	state.amounts["ti"] = 0.0
	sim.tick(state, true)

	var expected_fraction: float = 0.3
	_assert_approx(state.amounts.get("ti", 0.0), sml_prod_ti * expected_fraction, 0.001,
		"partial_production bottleneck: ti scaled by tightest fraction (0.3)")
	_assert_approx(state.amounts.get("eng", 0.0), eng_start - sml_upkeep_eng * expected_fraction, 0.001,
		"partial_production bottleneck: eng consumed at 0.3 fraction")
	_assert_approx(state.amounts.get("reg", 0.0), reg_start - sml_upkeep_reg * expected_fraction, 0.001,
		"partial_production bottleneck: reg consumed at 0.3 fraction")
	_assert_stall_status(state, "smelter", "input_starved",
		"partial_production bottleneck: smelter flagged input_starved")


# 6. Output-capped buildings skip entirely (no partial production)
func _test_output_capped_unaffected() -> void:
	print("--- Partial Production: Output-Capped Unaffected ---")

	var exc_bdef := TF.get_building_def("excavator")
	var exc_upkeep_eng: float = float(exc_bdef.get("upkeep", {}).get("eng", 0.0))

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["eng"] = exc_upkeep_eng * 5.0
	state.amounts["reg"] = state.caps.get("reg", 50.0)  # at storage cap
	var eng_before: float = state.amounts["eng"]
	sim.tick(state, true)

	_assert_approx(state.amounts.get("eng", 0.0), eng_before, 0.001,
		"partial_production output_capped: no upkeep paid when output at cap")
	_assert_stall_status(state, "excavator", "output_capped",
		"partial_production output_capped: excavator flagged output_capped, not input_starved")


# 7. No-production buildings pay full upkeep all-or-nothing
func _test_no_production_building_unaffected() -> void:
	print("--- Partial Production: No-Production Building ---")

	# Data center: upkeep eng, no production outputs.
	# Give partial eng. It should skip entirely (not partial).
	var dc_bdef := TF.get_building_def("data_center")
	var dc_upkeep_eng: float = float(dc_bdef.get("upkeep", {}).get("eng", 0.0))

	# Case A: insufficient eng → skip (no upkeep paid)
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "data_center")
	state.amounts["eng"] = dc_upkeep_eng * 0.5  # half needed
	var eng_before: float = state.amounts["eng"]
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), eng_before, 0.001,
		"partial_production no-prod: data_center skips entirely when eng < upkeep (all-or-nothing)")

	# Case B: sufficient eng → pays full upkeep
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "data_center")
	state.amounts["eng"] = dc_upkeep_eng * 5.0
	eng_before = state.amounts["eng"]
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), eng_before - dc_upkeep_eng, 0.001,
		"partial_production no-prod: data_center pays full upkeep when eng sufficient")


# 8. Processing order: first building in JSON order gets priority on scarce resources
func _test_processing_order_priority() -> void:
	print("--- Partial Production: Processing Order Priority ---")

	# Excavator and Smelter both need eng upkeep. Excavator comes first in JSON.
	# Give exactly enough eng for excavator's full upkeep but not both.
	# Excavator should run at fraction=1.0; Smelter at lower fraction.
	var exc_bdef := TF.get_building_def("excavator")
	var sml_bdef := TF.get_building_def("smelter")
	var exc_upkeep_eng: float = float(exc_bdef.get("upkeep", {}).get("eng", 0.0))
	var sml_upkeep_eng: float = float(sml_bdef.get("upkeep", {}).get("sml_eng", 0.0))
	sml_upkeep_eng = float(sml_bdef.get("upkeep", {}).get("eng", 0.0))

	# Give exactly excavator_upkeep_eng + half of smelter_upkeep_eng.
	var eng_start: float = exc_upkeep_eng + sml_upkeep_eng * 0.5
	# Also give plenty of reg so smelter's reg fraction isn't the tightest constraint.
	var sml_upkeep_reg: float = float(sml_bdef.get("upkeep", {}).get("reg", 0.0))

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	TF.add_building(state, "smelter")
	state.amounts["eng"] = eng_start
	state.amounts["reg"] = sml_upkeep_reg * 10.0  # plenty of reg
	state.amounts["ti"] = 0.0
	sim.tick(state, true)

	# Excavator ran at full fraction (fraction=1.0): produced full reg, paid full eng upkeep.
	var exc_prod_reg: float = float(exc_bdef.get("production", {}).get("reg", 0.0))
	# After excavator paid its upkeep, remaining eng = sml_upkeep_eng * 0.5
	# Smelter fraction for eng = 0.5. Reg fraction >= 1.0. So fraction = 0.5.
	_assert_stall_status(state, "excavator", "running",
		"partial_production order: excavator (first) runs at full capacity")
	_assert_stall_status(state, "smelter", "input_starved",
		"partial_production order: smelter (second) runs at partial capacity")
