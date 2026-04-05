extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_stress_tolerance_stacking()
	_test_overclock_boost_cap()
	_test_extractor_output_mult()
	_test_solar_output_mult()
	_test_building_upkeep_mult()
	_test_promote_effectiveness_mult()
	_test_speculator_burst_interval_mult()
	_test_land_cost_mult()


# A (stacking): Stress Tolerance × Humanist ideology — multiplicative combination
func _test_stress_tolerance_stacking() -> void:
	print("--- Stress Tolerance + Humanist Stacking ---")

	# Baseline: 1 tick from plain fresh state, no modifiers → 0.1 boredom (phase-1 rate).
	var sim_base := TF.create_fresh_sim()
	var st_base := TF.fresh_state(sim_base)
	sim_base.tick(st_base, false)
	var baseline: float = st_base.amounts.get("boredom", 0.0)

	# stress_tolerance (0.85) + Humanist rank 2 (ideology=175 → pow(0.97, 2)).
	# fresh_state_with_research pre-triggers "first_research" so the milestone's
	# boredom reduction does not interfere.
	var sim_stack := TF.create_fresh_sim()
	var st_stack := TF.fresh_state_with_research(sim_stack, ["stress_tolerance"])
	st_stack.ideology_values["humanist"] = GameState.score_for_rank(2.0)  # rank 2
	sim_stack.tick(st_stack, false)
	var stacked: float = st_stack.amounts.get("boredom", 0.0)

	var expected_mult: float = 0.85 * pow(0.97, 2.0)
	_assert_approx(stacked, baseline * expected_mult, 0.0001,
		"stress_tolerance + humanist rank 2: combined multiplier is 0.85 * 0.97^2")
	_assert_true(stacked < baseline * 0.85,
		"stress_tolerance + humanist rank 2: stacked boredom is lower than stress_tolerance alone")


# C: Overclock Boost — cap rises from 1.5 to 2.0 with research
func _test_overclock_boost_cap() -> void:
	print("--- Overclock Boost Cap ---")

	# Without overclock_boost: cap is 1.5.
	# Inject 10 overclock states with bonus=0.05 → 1.05^10 ≈ 1.629 (exceeds 1.5).
	# Excavator produces 2 reg/tick; capped mult of 1.5 → expected 3.0 reg.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["reg"] = 0.0
	state.amounts["eng"] = 100.0
	for _i in range(10):
		state.overclock_states.append({"target": "extraction", "bonus": 0.05, "ticks": 1})
	sim.tick(state, true)
	_assert_approx(state.amounts.get("reg", 0.0), 3.0, 0.001,
		"overclock_boost: without research, 10 stacked states cap prod at 1.5x (3.0 reg)")

	# With overclock_boost: cap is 2.0.
	# Inject 15 states → 1.05^15 ≈ 2.079 (exceeds 2.0). Capped mult → 4.0 reg.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["reg"] = 0.0
	state.amounts["eng"] = 100.0
	state.completed_research.append("overclock_boost")
	for _i in range(15):
		state.overclock_states.append({"target": "extraction", "bonus": 0.05, "ticks": 1})
	sim.tick(state, true)
	_assert_approx(state.amounts.get("reg", 0.0), 4.0, 0.001,
		"overclock_boost: with research, 15 stacked states cap prod at 2.0x (4.0 reg)")


# E: extractor_output_mult — Excavator and Ice Extractor production
func _test_extractor_output_mult() -> void:
	print("--- extractor_output_mult ---")

	# Excavator baseline: 2 reg/tick with no modifier.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["reg"] = 0.0
	state.amounts["eng"] = 100.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("reg", 0.0), 2.0, 0.001,
		"extractor_output_mult: excavator baseline 2 reg (mult=1.0)")

	# Excavator with modifier 1.25 → 2.5 reg.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["reg"] = 0.0
	state.amounts["eng"] = 100.0
	state.active_modifiers["extractor_output_mult"] = 1.25
	sim.tick(state, true)
	_assert_approx(state.amounts.get("reg", 0.0), 2.5, 0.001,
		"extractor_output_mult: excavator produces 2.5 reg with modifier 1.25")

	# Ice Extractor with modifier 1.25: base 1 ice/tick → 1.25 ice.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "ice_extractor")
	state.amounts["ice"] = 0.0
	state.amounts["eng"] = 100.0
	state.active_modifiers["extractor_output_mult"] = 1.25
	sim.tick(state, true)
	_assert_approx(state.amounts.get("ice", 0.0), 1.25, 0.001,
		"extractor_output_mult: ice_extractor produces 1.25 ice with modifier 1.25")


# F: solar_output_mult — Solar Panel energy production
func _test_solar_output_mult() -> void:
	print("--- solar_output_mult ---")

	var panel_bdef := TF.get_building_def("panel")
	var panel_eng_prod: float = float(panel_bdef.get("production", {}).get("eng", 0.0))

	# Panel baseline: no modifier, produces exactly what JSON says.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "panel")
	state.amounts["eng"] = 0.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), panel_eng_prod, 0.001,
		"solar_output_mult: panel baseline production correct (mult=1.0)")

	# Panel with modifier 1.15: production * 1.15.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "panel")
	state.amounts["eng"] = 0.0
	state.active_modifiers["solar_output_mult"] = 1.15
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), panel_eng_prod * 1.15, 0.001,
		"solar_output_mult: panel production scales by modifier 1.15")


# G: building_upkeep_mult — all building upkeep costs
func _test_building_upkeep_mult() -> void:
	print("--- building_upkeep_mult ---")

	var exc_bdef := TF.get_building_def("excavator")
	var exc_upkeep_eng: float = float(exc_bdef.get("upkeep", {}).get("eng", 0.0))

	# Excavator baseline upkeep from JSON.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["eng"] = 100.0
	state.amounts["reg"] = 0.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), 100.0 - exc_upkeep_eng, 0.001,
		"building_upkeep_mult: excavator baseline upkeep correct (mult=1.0)")

	# Excavator with modifier 0.90: upkeep = base * 0.90.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["eng"] = 100.0
	state.amounts["reg"] = 0.0
	state.active_modifiers["building_upkeep_mult"] = 0.90
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), 100.0 - exc_upkeep_eng * 0.90, 0.001,
		"building_upkeep_mult: excavator upkeep scales by modifier 0.90")


# H: promote_effectiveness_mult — Promote command demand accumulator
func _test_promote_effectiveness_mult() -> void:
	print("--- promote_effectiveness_mult ---")

	# Base: promote_he3 has demand_nudge value=0.03 in commands.json.
	# With no speculators on he3, effectiveness = 1.0, so demand_promote["he3"] += 0.03.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	state.completed_research.append("trade_promotion")
	state.amounts["eng"] = 100.0
	state.amounts["cred"] = 100.0
	state.demand_promote["he3"] = 0.0
	state.speculators["he3"] = 0.0
	sim.execute_command(state, "promote_he3")
	_assert_approx(state.demand_promote.get("he3", 0.0), 0.03, 0.0001,
		"promote_effectiveness_mult: base promote adds 0.03 to demand_promote (mult=1.0)")

	# With modifier 1.30: demand_promote["he3"] += 0.03 * 1.30 = 0.039.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	state.completed_research.append("trade_promotion")
	state.amounts["eng"] = 100.0
	state.amounts["cred"] = 100.0
	state.demand_promote["he3"] = 0.0
	state.speculators["he3"] = 0.0
	state.active_modifiers["promote_effectiveness_mult"] = 1.30
	sim.execute_command(state, "promote_he3")
	_assert_approx(state.demand_promote.get("he3", 0.0), 0.03 * 1.30, 0.0001,
		"promote_effectiveness_mult: with modifier 1.30, promote adds 0.039")


# I: speculator_burst_interval_mult — burst scheduling reads the modifier
func _test_speculator_burst_interval_mult() -> void:
	print("--- speculator_burst_interval_mult ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_demand_isolated(sim)

	var int_min: int = int(sim.demand_system.get_config("speculator_burst_interval_min"))
	# Trigger a burst on this tick by setting next_burst_tick = current_day.
	state.speculator_next_burst_tick = state.current_day
	state.active_modifiers["speculator_burst_interval_mult"] = 2.0
	sim.demand_system.tick_speculators(state)
	# With mult=2.0, the scheduled interval is randi_range(min,max)*2.0.
	# Since randi_range(min,max) >= min, the new next_burst_tick >= current_day + int(min*2.0).
	_assert_true(
		state.speculator_next_burst_tick >= state.current_day + int(float(int_min) * 2.0),
		"speculator_burst_interval_mult: next burst tick >= current_day + int_min*2.0 (modifier read)")


# J: land_cost_mult — land purchase cost, stacks with Nationalist ideology
func _test_land_cost_mult() -> void:
	print("--- land_cost_mult ---")
	var land_cfg2: Dictionary = TF.load_game_config().get("land", {})
	var land_base2: float = float(land_cfg2.get("base_cost", 0.0))
	var land_scaling2: float = float(land_cfg2.get("cost_scaling", 1.5))
	var raw_at_4: float = land_base2 * pow(land_scaling2, 4.0)

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	state.land_purchases = 4

	# Base at land_purchases=4: floor(base * scaling^4).
	_assert_equal(sim.get_land_purchase_cost(state), int(floor(raw_at_4)),
		"land_cost_mult: base cost at land_purchases=4 = floor(base * scaling^4)")

	# With modifier 0.85: floor(raw * 0.85).
	state.active_modifiers["land_cost_mult"] = 0.85
	_assert_equal(sim.get_land_purchase_cost(state), int(floor(raw_at_4 * 0.85)),
		"land_cost_mult: modifier 0.85 multiplies raw cost before floor")

	# With modifier 0.85 + Nationalist rank 1, stacks multiplicatively.
	state.ideology_values["nationalist"] = GameState.score_for_rank(1.0)
	_assert_equal(sim.get_land_purchase_cost(state), int(floor(raw_at_4 * 0.85 * 0.97)),
		"land_cost_mult: modifier and Nationalist rank 1 stack multiplicatively")
