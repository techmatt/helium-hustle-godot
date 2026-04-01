extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_basic_residual_drain()
	_test_multi_tick_convergence()
	_test_multi_resource_stall()
	_test_no_drain_when_running()
	_test_no_drain_for_output_capped()
	_test_rate_tracking()


func _test_basic_residual_drain() -> void:
	print("--- Residual Drain: Basic ---")

	# Research Lab is input_starved when eng < upkeep. After tick:
	# - Residual drain: all available eng consumed, producing nothing.
	var rl_bdef := TF.get_building_def("research_lab")
	var rl_upkeep_eng: float = float(rl_bdef.get("upkeep", {}).get("eng", 0.0))

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "research_lab")
	# Give less eng than upkeep so research_lab is input_starved.
	state.amounts["eng"] = rl_upkeep_eng - 2.0
	state.amounts["cir"] = 5.0
	state.amounts["sci"] = 0.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), 0.0, 0.001,
		"residual_drain: eng drained to 0 when research_lab starved")
	_assert_approx(state.amounts.get("sci", 0.0), 0.0, 0.001,
		"residual_drain: no sci produced when research_lab starved")
	_assert_stall_status(state, "research_lab", "input_starved",
		"residual_drain: research_lab remains input_starved after residual drain")


func _test_multi_tick_convergence() -> void:
	print("--- Residual Drain: Multi-Tick Convergence ---")

	# 1 solar panel produces eng; 3 excavators consume more eng than the panel produces.
	# Net eng is negative, so excavators will stall and residual-drain any remaining eng.
	# Over 10 ticks, eng should converge to 0.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "panel")      # +5 eng/tick
	TF.add_building(state, "excavator", 3)  # -6 eng/tick upkeep → net -1 eng
	# Start with eng = 5 to give 1 tick of normal operation before stalling.
	state.amounts["eng"] = 5.0
	state.amounts["reg"] = 0.0
	for _i in range(10):
		sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), 0.0, 0.5,
		"residual_drain: eng converges to 0 over 10 ticks when net consumption > production")


func _test_multi_resource_stall() -> void:
	print("--- Residual Drain: Multi-Resource Stall ---")

	# Refinery is input_starved on eng; reg drains by full upkeep amount even though
	# eng is the missing resource.
	var ref_bdef := TF.get_building_def("refinery")
	var ref_upkeep_reg: float = float(ref_bdef.get("upkeep", {}).get("reg", 0.0))

	var reg_start: float = ref_upkeep_reg * 5.0  # plenty of reg

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "refinery")
	state.amounts["eng"] = 0.0         # starved
	state.amounts["reg"] = reg_start   # plentiful
	state.amounts["he3"] = 0.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("he3", 0.0), 0.0, 0.001,
		"residual_drain multi: no he3 produced when refinery eng-starved")
	_assert_approx(state.amounts.get("eng", 0.0), 0.0, 0.001,
		"residual_drain multi: eng stays 0 (nothing to drain from starved resource)")
	_assert_approx(state.amounts.get("reg", 0.0), reg_start - ref_upkeep_reg, 0.001,
		"residual_drain multi: reg drained by full upkeep amount even when eng is starved")
	_assert_stall_status(state, "refinery", "input_starved",
		"residual_drain multi: refinery still input_starved after residual drain")


func _test_no_drain_when_running() -> void:
	print("--- Residual Drain: No Drain When Running ---")

	# Excavator with enough energy runs normally — no extra drain, produces reg.
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
		"residual_drain: running excavator pays only normal upkeep (no extra drain)")
	_assert_approx(state.amounts.get("reg", 0.0), exc_prod_reg, 0.001,
		"residual_drain: running excavator produces reg normally")
	_assert_stall_status(state, "excavator", "running",
		"residual_drain: excavator is running, not stalled")


func _test_no_drain_for_output_capped() -> void:
	print("--- Residual Drain: No Drain for Output-Capped ---")

	# Excavator output-capped (reg at cap). No upkeep paid, no production, no residual drain.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["eng"] = 10.0
	state.amounts["reg"] = state.caps.get("reg", 50.0)  # at storage cap
	var eng_before: float = state.amounts["eng"]
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), eng_before, 0.001,
		"residual_drain: output-capped excavator has no residual drain on eng")
	_assert_stall_status(state, "excavator", "output_capped",
		"residual_drain: output-capped excavator is output_capped, not input_starved")


func _test_rate_tracking() -> void:
	print("--- Residual Drain: Rate Tracking ---")

	# Research Lab starved (eng < upkeep). rate_tracker should record the actual
	# drained amount, not the full upkeep cost.
	var rl_bdef := TF.get_building_def("research_lab")
	var rl_upkeep_eng: float = float(rl_bdef.get("upkeep", {}).get("eng", 0.0))
	var eng_available: float = rl_upkeep_eng - 2.0  # less than upkeep

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "research_lab")
	var rt := ResourceRateTracker.new()
	sim.rate_tracker = rt
	state.amounts["eng"] = eng_available
	state.amounts["cir"] = 5.0
	sim.tick(state, true)
	var tracked: float = rt.get_instant("building:research_lab:upkeep", "eng")
	_assert_approx(tracked, -eng_available, 0.001,
		"residual_drain rate: tracker records actual drain not full upkeep")
