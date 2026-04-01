extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_building_production()
	_test_production_gated_upkeep()
	_test_input_starvation_skip()
	_test_stall_status_tracking()
	_test_storage_caps()
	_test_building_cost_scaling()
	_test_land_system()


func _test_building_production() -> void:
	print("--- Building Production ---")

	# Solar panel: no upkeep. Production comes from JSON.
	# Drain eng to 0 so the production isn't invisible behind the cap.
	var panel_bdef := TF.get_building_def("panel")
	var panel_eng_prod: float = float(panel_bdef.get("production", {}).get("eng", 0.0))
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "panel")
	state.amounts["eng"] = 0.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), panel_eng_prod, 0.001,
		"production: solar panel produces correct eng per tick")

	# Excavator: upkeep and production from JSON.
	var exc_bdef := TF.get_building_def("excavator")
	var exc_upkeep_eng: float = float(exc_bdef.get("upkeep", {}).get("eng", 0.0))
	var exc_prod_reg: float = float(exc_bdef.get("production", {}).get("reg", 0.0))
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["reg"] = 0.0
	state.amounts["eng"] = 20.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("reg", 0.0), exc_prod_reg, 0.001,
		"production: excavator produces correct reg per tick")
	_assert_approx(state.amounts.get("eng", 0.0), 20.0 - exc_upkeep_eng, 0.001,
		"production: excavator consumes correct eng upkeep per tick")

	# Smelter: upkeep and production from JSON.
	var sm_bdef := TF.get_building_def("smelter")
	var sm_upkeep_eng: float = float(sm_bdef.get("upkeep", {}).get("eng", 0.0))
	var sm_upkeep_reg: float = float(sm_bdef.get("upkeep", {}).get("reg", 0.0))
	var sm_prod_ti: float = float(sm_bdef.get("production", {}).get("ti", 0.0))
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "smelter")
	state.amounts["ti"] = 0.0
	state.amounts["eng"] = 20.0
	state.amounts["reg"] = 20.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("ti", 0.0), sm_prod_ti, 0.001,
		"production: smelter produces correct ti per tick")
	_assert_approx(state.amounts.get("reg", 0.0), 20.0 - sm_upkeep_reg, 0.001,
		"production: smelter consumes correct reg upkeep per tick")
	_assert_approx(state.amounts.get("eng", 0.0), 20.0 - sm_upkeep_eng, 0.001,
		"production: smelter consumes correct eng upkeep per tick")


func _test_production_gated_upkeep() -> void:
	print("--- Production Gated Upkeep ---")

	# Solar panel is a free producer (no upkeep). When its only output (eng) is
	# at cap, Pass 2 marks it output_capped and skips production entirely.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "panel")
	state.amounts["eng"] = 100.0  # at eng cap
	sim.tick(state, true)
	_assert_stall_status(state, "panel", "output_capped",
		"gated_upkeep: solar panel stalls output_capped when eng at cap")

	# Excavator: when reg is at cap, the output-capped check fires in Pass 1
	# before upkeep is paid — so upkeep is NOT deducted and production is skipped.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["eng"] = 10.0
	var reg_cap: float = state.caps.get("reg", 0.0)
	state.amounts["reg"] = reg_cap  # at reg cap
	var eng_before: float = state.amounts["eng"]
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), eng_before, 0.001,
		"gated_upkeep: excavator does not pay eng upkeep when reg output is at cap")
	_assert_approx(state.amounts.get("reg", 0.0), reg_cap, 0.001,
		"gated_upkeep: excavator does not produce reg when output is at cap")
	_assert_stall_status(state, "excavator", "output_capped",
		"gated_upkeep: excavator stall status is output_capped when reg at cap")


func _test_input_starvation_skip() -> void:
	print("--- Input Starvation: Zero Input (Fraction = 0) ---")

	# With partial production, fraction = min(available / needed). When any input is 0,
	# fraction = 0 → no consumption, no production (same as old skip for the zero case).

	# Smelter with reg=0: fraction=0 → no ti, no eng consumed, no reg consumed.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "smelter")
	state.amounts["eng"] = 20.0
	state.amounts["reg"] = 0.0   # zero → fraction=0
	state.amounts["ti"] = 0.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("ti", 0.0), 0.0, 0.001,
		"starvation: smelter produces no ti when reg=0 (fraction=0)")
	_assert_approx(state.amounts.get("eng", 0.0), 20.0, 0.001,
		"starvation: smelter consumes no eng when fraction=0")

	# Smelter with eng=0: fraction=0 → no ti, no reg consumed.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "smelter")
	state.amounts["eng"] = 0.0   # zero → fraction=0
	state.amounts["reg"] = 20.0
	state.amounts["ti"] = 0.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("ti", 0.0), 0.0, 0.001,
		"starvation: smelter produces no ti when eng=0 (fraction=0)")
	_assert_approx(state.amounts.get("reg", 0.0), 20.0, 0.001,
		"starvation: smelter consumes no reg when fraction=0")


func _test_stall_status_tracking() -> void:
	print("--- Stall Status Tracking ---")

	# Excavator input starved: eng=0 → can't pay upkeep → input_starved.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["eng"] = 0.0
	state.amounts["reg"] = 0.0
	sim.tick(state, true)
	_assert_stall_status(state, "excavator", "input_starved",
		"stall: excavator is input_starved when eng=0")

	# Excavator output capped: reg at cap → output_capped (upkeep not paid).
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["eng"] = 10.0
	state.amounts["reg"] = state.caps.get("reg", 0.0)  # at reg cap
	sim.tick(state, true)
	_assert_stall_status(state, "excavator", "output_capped",
		"stall: excavator is output_capped when reg at cap")

	# Excavator running normally: eng available, reg below cap.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	TF.add_building(state, "excavator")
	state.amounts["eng"] = 10.0
	state.amounts["reg"] = 0.0   # well below cap
	sim.tick(state, true)
	_assert_stall_status(state, "excavator", "running",
		"stall: excavator is running when eng available and reg below cap")


func _test_storage_caps() -> void:
	print("--- Storage Caps ---")

	# Verify base caps match resources.json before any storage buildings.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	_assert_approx(state.caps.get("reg", 0.0), 50.0, 0.001,
		"caps: base reg cap is 50")
	_assert_approx(state.caps.get("eng", 0.0), 100.0, 0.001,
		"caps: base eng cap is 100")

	# Storage Depot effects per buildings.json:
	# reg+75, ice+40, he3+30, ti+25, cir+10, prop+40.
	TF.add_building(state, "storage_depot")
	sim.recalculate_caps(state)
	_assert_approx(state.caps.get("reg", 0.0), 125.0, 0.001,
		"caps: 1 storage depot raises reg cap to 125")
	_assert_approx(state.caps.get("ice", 0.0), 70.0, 0.001,
		"caps: 1 storage depot raises ice cap to 70")
	_assert_approx(state.caps.get("he3", 0.0), 50.0, 0.001,
		"caps: 1 storage depot raises he3 cap to 50")
	_assert_approx(state.caps.get("ti", 0.0), 45.0, 0.001,
		"caps: 1 storage depot raises ti cap to 45")
	_assert_approx(state.caps.get("cir", 0.0), 20.0, 0.001,
		"caps: 1 storage depot raises cir cap to 20")
	_assert_approx(state.caps.get("prop", 0.0), 70.0, 0.001,
		"caps: 1 storage depot raises prop cap to 70")

	# Battery adds eng+50.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state(sim)
	_assert_approx(state.caps.get("eng", 0.0), 100.0, 0.001,
		"caps: base eng cap is 100 before battery")
	TF.add_building(state, "battery")
	sim.recalculate_caps(state)
	_assert_approx(state.caps.get("eng", 0.0), 150.0, 0.001,
		"caps: 1 battery raises eng cap to 150")


func _test_building_cost_scaling() -> void:
	print("--- Building Cost Scaling ---")

	# Solar panel: read base costs and scaling from JSON.
	# Formula: base_cost * scaling^purchased, where purchased = max(0, owned - bonus).
	var panel_bdef2 := TF.get_building_def("panel")
	var base_cred: float = float(panel_bdef2.get("costs", {}).get("cred", 0.0))
	var base_ti: float = float(panel_bdef2.get("costs", {}).get("ti", 0.0))
	var scaling: float = float(panel_bdef2.get("cost_scaling", 1.0))
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)

	# 0 owned → purchased=0 → scaling^0 = 1, costs = base costs
	state.buildings_owned["panel"] = 0
	state.buildings_bonus["panel"] = 0
	var costs: Dictionary = sim.get_scaled_costs(state, "panel")
	_assert_approx(costs.get("cred", 0.0), base_cred, 0.001,
		"cost_scaling: panel 0 owned → cred cost equals base")
	_assert_approx(costs.get("ti", 0.0), base_ti, 0.001,
		"cost_scaling: panel 0 owned → ti cost equals base")

	# 1 owned → purchased=1 → base * scaling^1
	state.buildings_owned["panel"] = 1
	costs = sim.get_scaled_costs(state, "panel")
	_assert_approx(costs.get("cred", 0.0), base_cred * scaling, 0.001,
		"cost_scaling: panel 1 owned → cred cost = base * scaling")

	# 5 owned → purchased=5 → base * scaling^5
	state.buildings_owned["panel"] = 5
	costs = sim.get_scaled_costs(state, "panel")
	_assert_approx(costs.get("cred", 0.0), base_cred * pow(scaling, 5.0), 0.001,
		"cost_scaling: panel 5 owned → cred cost = base * scaling^5")

	# Bonus offset: owned=3, bonus=1 → purchased=max(0,2)=2 → base * scaling^2
	state.buildings_owned["panel"] = 3
	state.buildings_bonus["panel"] = 1
	costs = sim.get_scaled_costs(state, "panel")
	_assert_approx(costs.get("cred", 0.0), base_cred * pow(scaling, 2.0), 0.001,
		"cost_scaling: panel owned=3 bonus=1 → purchased=2, cred cost = base * scaling^2")

	# Bonus matches owned: owned=1, bonus=1 → purchased=max(0,0)=0 → base cost
	state.buildings_owned["panel"] = 1
	state.buildings_bonus["panel"] = 1
	costs = sim.get_scaled_costs(state, "panel")
	_assert_approx(costs.get("cred", 0.0), base_cred, 0.001,
		"cost_scaling: panel owned=1 bonus=1 → purchased=0, cred cost = base")


func _test_land_system() -> void:
	print("--- Land System ---")

	# Read land config from JSON — base_cost, scaling, land_per_purchase.
	var cfg := TF.load_game_config()
	var land_cfg: Dictionary = cfg.get("land", {})
	var land_base: float = float(land_cfg.get("base_cost", 0.0))
	var land_scaling: float = float(land_cfg.get("cost_scaling", 1.5))
	var land_per_buy: int = int(land_cfg.get("land_per_purchase", 10))

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)

	# Land purchase cost formula: int(floor(base * scaling^land_purchases)).
	# At land_purchases=0: cost = base.
	_assert_equal(sim.get_land_purchase_cost(state), int(land_base),
		"land: 1st purchase costs base_cost cred (scaling^0 = 1)")
	# At land_purchases=1: cost = floor(base * scaling).
	state.land_purchases = 1
	_assert_equal(sim.get_land_purchase_cost(state), int(floor(land_base * land_scaling)),
		"land: 2nd purchase cost = floor(base * scaling^1)")
	# At land_purchases=2: cost = floor(base * scaling^2).
	state.land_purchases = 2
	_assert_equal(sim.get_land_purchase_cost(state), int(floor(land_base * pow(land_scaling, 2.0))),
		"land: 3rd purchase cost = floor(base * scaling^2)")
	state.land_purchases = 0  # reset for buy test

	# buy_land: deducts cost from cred, adds land_per_purchase land, increments land_purchases.
	state.amounts["cred"] = land_base
	var land_before: float = state.amounts.get("land", 0.0)
	sim.buy_land(state)
	_assert_approx(state.amounts.get("cred", 0.0), 0.0, 0.001,
		"land: buy_land deducts base_cost cred")
	_assert_approx(state.amounts.get("land", 0.0), land_before + land_per_buy, 0.001,
		"land: buy_land adds land_per_purchase land")
	_assert_equal(state.land_purchases, 1,
		"land: land_purchases increments after buy_land")

	# Building purchase consumes land. Solar panel costs 1 land.
	var panel_bdef3 := TF.get_building_def("panel")
	var panel_costs3: Dictionary = panel_bdef3.get("costs", {})
	sim = TF.create_fresh_sim()
	state = TF.fresh_state(sim)
	state.buildings_owned["panel"] = 0  # ensure purchased=0, costs = base
	for res: String in panel_costs3:
		state.amounts[res] = float(panel_costs3[res]) * 2.0  # more than enough
	var land_start: float = state.amounts.get("land", 0.0)
	sim.buy_building(state, "panel")
	_assert_approx(state.amounts.get("land", 0.0), land_start - 1.0, 0.001,
		"land: buying a solar panel consumes 1 land")
	_assert_equal(state.buildings_owned.get("panel", 0), 1,
		"land: panel owned count is 1 after purchase")
