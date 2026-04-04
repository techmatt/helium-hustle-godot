extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_multi_pass_chain_dependency()
	_test_multi_pass_three_building_chain()
	_test_multi_pass_phase2_priority()
	_test_overflow_at_cap()
	_test_partial_overflow()
	_test_no_overflow_with_headroom()
	_test_overflow_rolling_avg()
	_test_buy_command_partial()
	_test_buy_command_full()
	_test_buy_command_cap_skip()
	_test_buy_command_near_cap_overflow()
	_test_two_processors_same_buy_command()


# 1. Multi-pass: excavator produces reg before smelter checks (same Phase 1 pass)
# Excavator (idx 1) comes before smelter (idx 3) in definition order.
# Verifies: excav produces reg atomically with upkeep, smelter then gets full reg.
func _test_multi_pass_chain_dependency() -> void:
	print("--- Overflow: Multi-Pass Chain Dependency ---")

	var exc_bdef := TF.get_building_def("excavator")
	var sml_bdef := TF.get_building_def("smelter")
	var exc_upkeep_eng: float = float(exc_bdef.get("upkeep", {}).get("eng", 0.0))
	var exc_prod_reg: float = float(exc_bdef.get("production", {}).get("reg", 0.0))
	var sml_upkeep_eng: float = float(sml_bdef.get("upkeep", {}).get("eng", 0.0))
	var sml_upkeep_reg: float = float(sml_bdef.get("upkeep", {}).get("reg", 0.0))
	var sml_prod_ti: float = float(sml_bdef.get("production", {}).get("ti", 0.0))

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	TF.add_building(state, "smelter")
	# Start with exactly enough reg for smelter only after excavator produces
	state.amounts["reg"] = 0.0
	state.amounts["eng"] = 100.0
	state.amounts["ti"] = 0.0
	sim.tick(state, true)

	# excavator produces exc_prod_reg → smelter sees exc_prod_reg reg (>= sml_upkeep_reg)
	# Both run at full capacity in Phase 1 pass 1.
	_assert_approx(state.amounts.get("ti", 0.0), sml_prod_ti, 0.001,
		"multi-pass chain: smelter runs at full capacity after excavator produces reg")
	_assert_approx(state.amounts.get("reg", 0.0), exc_prod_reg - sml_upkeep_reg, 0.001,
		"multi-pass chain: reg = exc_prod - sml_upkeep (smelter consumed its full share)")
	_assert_stall_status(state, "smelter", "running",
		"multi-pass chain: smelter not input_starved")
	_assert_stall_status(state, "excavator", "running",
		"multi-pass chain: excavator not stalled")


# 2. Three-building chain: panel → excavator → smelter, all start at 0
func _test_multi_pass_three_building_chain() -> void:
	print("--- Overflow: Three-Building Chain ---")

	# panel (idx 0): no upkeep, produces eng.
	# excavator (idx 1): needs eng, produces reg.
	# smelter (idx 3): needs eng + reg, produces ti.
	# Start all resources at 0. Verify all three produce in one tick.
	var pan_bdef := TF.get_building_def("panel")
	var exc_bdef := TF.get_building_def("excavator")
	var sml_bdef := TF.get_building_def("smelter")
	var pan_prod_eng: float = float(pan_bdef.get("production", {}).get("eng", 0.0))
	var exc_upkeep_eng: float = float(exc_bdef.get("upkeep", {}).get("eng", 0.0))
	var exc_prod_reg: float = float(exc_bdef.get("production", {}).get("reg", 0.0))
	var sml_upkeep_eng: float = float(sml_bdef.get("upkeep", {}).get("eng", 0.0))
	var sml_upkeep_reg: float = float(sml_bdef.get("upkeep", {}).get("reg", 0.0))
	var sml_prod_ti: float = float(sml_bdef.get("production", {}).get("ti", 0.0))

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "panel")
	TF.add_building(state, "excavator")
	TF.add_building(state, "smelter")
	state.amounts["eng"] = 0.0
	state.amounts["reg"] = 0.0
	state.amounts["ti"] = 0.0
	sim.tick(state, true)

	# Phase 1: panel (no upkeep) produces eng. Then excavator checks eng: has pan_prod_eng.
	# If pan_prod_eng >= exc_upkeep_eng: excavator pays and produces reg.
	# Then smelter checks: needs exc_upkeep_eng + sml_upkeep_eng total eng available,
	# and exc_prod_reg reg available.
	var eng_after_pan := pan_prod_eng
	var can_excav := eng_after_pan >= exc_upkeep_eng
	if can_excav:
		var eng_after_excav := eng_after_pan - exc_upkeep_eng
		var can_smelter := eng_after_excav >= sml_upkeep_eng and exc_prod_reg >= sml_upkeep_reg
		if can_smelter:
			_assert_approx(state.amounts.get("ti", 0.0), sml_prod_ti, 0.001,
				"three-building chain: smelter produces ti in Phase 1")
			_assert_stall_status(state, "smelter", "running",
				"three-building chain: smelter not stalled")
		else:
			# smelter goes to Phase 2 — just verify it gets some ti
			_assert_true(state.amounts.get("ti", 0.0) > 0.0,
				"three-building chain: smelter produces some ti via Phase 2")
	_assert_true(state.amounts.get("reg", 0.0) >= 0.0,
		"three-building chain: reg non-negative after tick")
	_assert_stall_status(state, "panel", "running",
		"three-building chain: panel runs (no upkeep)")
	_assert_stall_status(state, "excavator", "running",
		"three-building chain: excavator runs")


# 3. Phase 2 priority: first building (definition order) gets Phase 1 resources,
# second does partial in Phase 2 when there's not enough for both.
func _test_multi_pass_phase2_priority() -> void:
	print("--- Overflow: Phase 2 Priority By Definition Order ---")

	# Excavator (idx 1) and ice_extractor (idx 2) both need eng upkeep.
	# Give exactly enough eng for excavator's full upkeep + 50% of ice_extractor's.
	var exc_bdef := TF.get_building_def("excavator")
	var ice_bdef := TF.get_building_def("ice_extractor")
	var exc_upkeep_eng: float = float(exc_bdef.get("upkeep", {}).get("eng", 0.0))
	var ice_upkeep_eng: float = float(ice_bdef.get("upkeep", {}).get("eng", 0.0))
	var exc_prod_reg: float = float(exc_bdef.get("production", {}).get("reg", 0.0))
	var ice_prod_ice: float = float(ice_bdef.get("production", {}).get("ice", 0.0))

	var eng_start: float = exc_upkeep_eng + ice_upkeep_eng * 0.5

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	TF.add_building(state, "ice_extractor")
	state.amounts["eng"] = eng_start
	state.amounts["reg"] = 0.0
	state.amounts["ice"] = 0.0
	sim.tick(state, true)

	# Phase 1: excavator pays full upkeep, produces reg. Succeeds.
	# ice_extractor can't pay full upkeep (only 50% left) → retry queue.
	# Phase 1 retry: no other building succeeds with new resources → retry fails → stop.
	# Phase 2: ice_extractor fraction = 0.5, pays 0.5 * ice_upkeep_eng, produces 0.5 * ice_prod_ice.
	_assert_approx(state.amounts.get("reg", 0.0), exc_prod_reg, 0.001,
		"phase2_priority: excavator (first) produces full reg")
	_assert_approx(state.amounts.get("ice", 0.0), ice_prod_ice * 0.5, 0.001,
		"phase2_priority: ice_extractor (second) runs at 0.5 fraction in Phase 2")
	_assert_stall_status(state, "excavator", "running",
		"phase2_priority: excavator not stalled")
	_assert_stall_status(state, "ice_extractor", "input_starved",
		"phase2_priority: ice_extractor flagged input_starved")


# 4. Overflow when building produces into a full storage
func _test_overflow_at_cap() -> void:
	print("--- Overflow: Building Produces At Cap ---")

	var exc_bdef := TF.get_building_def("excavator")
	var exc_upkeep_eng: float = float(exc_bdef.get("upkeep", {}).get("eng", 0.0))
	var exc_prod_reg: float = float(exc_bdef.get("production", {}).get("reg", 0.0))

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	var reg_cap: float = state.caps.get("reg", 50.0)
	state.amounts["reg"] = reg_cap  # exactly at cap
	state.amounts["eng"] = 100.0
	sim.tick(state, true)

	_assert_approx(state.amounts.get("reg", 0.0), reg_cap, 0.001,
		"overflow_at_cap: reg stays at cap after end-of-tick clamp")
	_assert_approx(state.overflow_this_tick.get("reg", 0.0), exc_prod_reg, 0.001,
		"overflow_at_cap: overflow_this_tick records full production as overflow")
	_assert_true(state.overflow_rolling_avg.get("reg", 0.0) > 0.0,
		"overflow_at_cap: overflow_rolling_avg updated for reg")


# 5. Partial overflow: production pushes just above cap
func _test_partial_overflow() -> void:
	print("--- Overflow: Partial Overflow ---")

	var exc_bdef := TF.get_building_def("excavator")
	var exc_upkeep_eng: float = float(exc_bdef.get("upkeep", {}).get("eng", 0.0))
	var exc_prod_reg: float = float(exc_bdef.get("production", {}).get("reg", 0.0))

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	var reg_cap: float = state.caps.get("reg", 50.0)
	# Set reg so that production puts it 1.0 above cap
	var headroom: float = exc_prod_reg - 1.0  # production will exceed cap by 1.0
	state.amounts["reg"] = reg_cap - headroom
	state.amounts["eng"] = 100.0
	sim.tick(state, true)

	_assert_approx(state.amounts.get("reg", 0.0), reg_cap, 0.001,
		"partial_overflow: reg clamped to cap")
	_assert_approx(state.overflow_this_tick.get("reg", 0.0), 1.0, 0.001,
		"partial_overflow: overflow_this_tick = excess above cap (1.0)")


# 6. No overflow when resource has headroom
func _test_no_overflow_with_headroom() -> void:
	print("--- Overflow: No Overflow With Headroom ---")

	var exc_bdef := TF.get_building_def("excavator")
	var exc_upkeep_eng: float = float(exc_bdef.get("upkeep", {}).get("eng", 0.0))

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["reg"] = 0.0  # plenty of headroom
	state.amounts["eng"] = 100.0
	sim.tick(state, true)

	_assert_true(not state.overflow_this_tick.has("reg"),
		"no_overflow_headroom: overflow_this_tick has no reg entry when headroom exists")
	_assert_approx(state.overflow_rolling_avg.get("reg", 0.0), 0.0, 0.001,
		"no_overflow_headroom: overflow_rolling_avg stays at 0.0 for reg")


# 7. Overflow rolling average updates over multiple ticks
func _test_overflow_rolling_avg() -> void:
	print("--- Overflow: Rolling Average Convergence ---")

	# Use panel (no upkeep, produces eng) + excavator so eng never runs out.
	# Reset reg to cap each tick to produce constant overflow = exc_prod_reg.
	# EMA_n = exc_prod_reg * (1 - (1-alpha)^n), alpha=1/20.
	var exc_bdef := TF.get_building_def("excavator")
	var exc_prod_reg: float = float(exc_bdef.get("production", {}).get("reg", 0.0))
	const ALPHA: float = 1.0 / 20.0
	const N_TICKS: int = 20

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "panel")     # sustains eng
	TF.add_building(state, "excavator")
	var reg_cap: float = state.caps.get("reg", 50.0)
	state.amounts["reg"] = reg_cap
	state.amounts["eng"] = 0.0  # panel will produce eng

	for _i in range(N_TICKS):
		state.amounts["reg"] = reg_cap  # keep at cap to force overflow every tick
		sim.tick(state, true)

	var avg: float = state.overflow_rolling_avg.get("reg", 0.0)
	# Expected: exc_prod_reg * (1 - (1-ALPHA)^N_TICKS)
	var expected_avg: float = exc_prod_reg * (1.0 - pow(1.0 - ALPHA, N_TICKS))
	_assert_true(avg > 0.0,
		"overflow_rolling_avg: non-zero after sustained overflow")
	_assert_approx(avg, expected_avg, expected_avg * 0.05,
		"overflow_rolling_avg: matches EMA formula within 5%")


# 8. Buy command partial: insufficient inputs → scaled output
func _test_buy_command_partial() -> void:
	print("--- Overflow: Buy Command Partial Production ---")

	var ice_bdef := TF.get_building_def("ice_extractor")  # not needed; use commands.json data
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)

	# buy_ice: costs {cred:10, eng:1}, production {ice:1}
	# Give 50% of cred needed, full eng → fraction = 0.5
	var buy_ice_cost_cred: float = 10.0
	var buy_ice_cost_eng: float = 1.0
	var buy_ice_prod_ice: float = 1.0

	TF.setup_program(state, "buy_ice", 0)
	state.amounts["cred"] = buy_ice_cost_cred * 0.5  # 5 cred (need 10)
	state.amounts["eng"] = buy_ice_cost_eng * 5.0
	state.amounts["ice"] = 0.0
	state.total_processors = 1
	sim.tick(state, true)

	var expected_fraction: float = 0.5
	_assert_approx(state.amounts.get("ice", 0.0), buy_ice_prod_ice * expected_fraction, 0.001,
		"buy_command_partial: ice output scaled by cred fraction (0.5)")
	_assert_approx(state.amounts.get("cred", 0.0), 0.0, 0.001,
		"buy_command_partial: all available cred consumed")
	_assert_approx(state.amounts.get("eng", 0.0), buy_ice_cost_eng * 5.0 - buy_ice_cost_eng * expected_fraction, 0.001,
		"buy_command_partial: eng consumed at same fraction")


# 9. Buy command full: sufficient inputs → full output
func _test_buy_command_full() -> void:
	print("--- Overflow: Buy Command Full Production ---")

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)

	# buy_ice: costs {cred:10, eng:1}, production {ice:1}
	TF.setup_program(state, "buy_ice", 0)
	state.amounts["cred"] = 100.0
	state.amounts["eng"] = 100.0
	state.amounts["ice"] = 0.0
	state.total_processors = 1
	sim.tick(state, true)

	_assert_approx(state.amounts.get("ice", 0.0), 1.0, 0.001,
		"buy_command_full: produces full ice output")
	_assert_approx(state.amounts.get("cred", 0.0), 90.0, 0.001,
		"buy_command_full: consumes full cred cost")


# 10. Buy command with output at cap: command SKIPS (no inputs consumed, no outputs produced)
func _test_buy_command_cap_skip() -> void:
	print("--- Overflow: Buy Command Cap Skip ---")

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)

	# buy_ice: costs {cred:10, eng:1}, production {ice:1}
	TF.setup_program(state, "buy_ice", 0)
	state.amounts["cred"] = 100.0
	state.amounts["eng"] = 100.0
	var ice_cap: float = state.caps.get("ice", 50.0)
	state.amounts["ice"] = ice_cap  # already at cap
	state.total_processors = 1
	sim.tick(state, true)

	# Command skips: no inputs consumed, no outputs produced
	_assert_approx(state.amounts.get("cred", 0.0), 100.0, 0.001,
		"buy_command_cap_skip: cred NOT consumed when output at cap")
	_assert_approx(state.amounts.get("ice", 0.0), ice_cap, 0.001,
		"buy_command_cap_skip: ice stays at cap (nothing produced)")
	_assert_true(not state.overflow_this_tick.has("ice"),
		"buy_command_cap_skip: no overflow tracked (command did not execute)")


# 11. Buy command with output below cap but close: executes, overflow tracked at end of tick
func _test_buy_command_near_cap_overflow() -> void:
	print("--- Overflow: Buy Command Near-Cap Overflow ---")

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)

	# buy_ice: costs {cred:10, eng:1}, production {ice:1}
	# Set ice to cap-0.3 so there's headroom → command executes, then ice exceeds cap by 0.7
	TF.setup_program(state, "buy_ice", 0)
	state.amounts["cred"] = 100.0
	state.amounts["eng"] = 100.0
	var ice_cap: float = state.caps.get("ice", 50.0)
	state.amounts["ice"] = ice_cap - 0.3  # 0.3 below cap
	state.total_processors = 1
	sim.tick(state, true)

	# Command executes (headroom exists): consumes full inputs, produces full output
	_assert_approx(state.amounts.get("cred", 0.0), 90.0, 0.001,
		"buy_command_near_cap: cred consumed (command executed)")
	_assert_approx(state.amounts.get("ice", 0.0), ice_cap, 0.001,
		"buy_command_near_cap: ice clamped to cap at end of tick")
	_assert_approx(state.overflow_this_tick.get("ice", 0.0), 0.7, 0.001,
		"buy_command_near_cap: overflow_this_tick records excess above cap (0.7)")


# 12. Two processors on same Buy command with insufficient inputs
func _test_two_processors_same_buy_command() -> void:
	print("--- Overflow: Two Processors Same Buy Command ---")

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)

	# buy_ice: costs {cred:10, eng:1}, production {ice:1}
	# Give cred for 1.5 full executions. Processor 1 gets fraction=1.0 (full).
	# Processor 2 sees cred=5 remaining, needs 10 → fraction=0.5.
	# Total ice = 1.0 + 0.5 = 1.5. Total cred spent = 10 + 5 = 15.
	TF.setup_program(state, "buy_ice", 0)
	state.programs[0].processors_assigned = 2
	state.amounts["cred"] = 15.0  # 1 full + 0.5 partial
	state.amounts["eng"] = 100.0
	state.amounts["ice"] = 0.0
	state.total_processors = 2
	sim.tick(state, true)

	_assert_approx(state.amounts.get("ice", 0.0), 1.5, 0.001,
		"two_processors_buy: total ice = 1.5 (1.0 from proc1, 0.5 from proc2)")
	_assert_approx(state.amounts.get("cred", 0.0), 0.0, 0.001,
		"two_processors_buy: all cred consumed across both processors")
