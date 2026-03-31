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

	# Solar panel: no upkeep, produces 6 eng per tick.
	# Disable data_center so its eng upkeep doesn't interfere.
	# Drain eng to 0 so the production isn't invisible behind the cap.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	state.buildings_active["data_center"] = 0
	state.amounts["eng"] = 0.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), 6.0, 0.001,
		"production: solar panel produces 6 eng per tick")

	# Excavator: upkeep 2 eng, produces 2 reg per tick.
	# Disable panel and data_center so energy balance is controlled.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state(sim)
	state.buildings_active["panel"] = 0
	state.buildings_active["data_center"] = 0
	state.buildings_owned["excavator"] = 1
	state.buildings_active["excavator"] = 1
	state.amounts["reg"] = 0.0
	state.amounts["eng"] = 10.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("reg", 0.0), 2.0, 0.001,
		"production: excavator produces 2 reg per tick")
	_assert_approx(state.amounts.get("eng", 0.0), 8.0, 0.001,
		"production: excavator consumes 2 eng upkeep per tick")

	# Smelter: upkeep 3 eng + 2 reg, produces 1 ti per tick.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state(sim)
	state.buildings_active["panel"] = 0
	state.buildings_active["data_center"] = 0
	state.buildings_owned["smelter"] = 1
	state.buildings_active["smelter"] = 1
	state.amounts["ti"] = 0.0
	state.amounts["eng"] = 20.0
	state.amounts["reg"] = 20.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("ti", 0.0), 1.0, 0.001,
		"production: smelter produces 1 ti per tick")
	_assert_approx(state.amounts.get("reg", 0.0), 18.0, 0.001,
		"production: smelter consumes 2 reg upkeep per tick")
	_assert_approx(state.amounts.get("eng", 0.0), 17.0, 0.001,
		"production: smelter consumes 3 eng upkeep per tick")


func _test_production_gated_upkeep() -> void:
	print("--- Production Gated Upkeep ---")

	# Solar panel is a free producer (no upkeep). When its only output (eng) is
	# at cap, Pass 2 marks it output_capped and skips production entirely.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	state.buildings_active["data_center"] = 0
	state.amounts["eng"] = 100.0  # at eng cap
	sim.tick(state, true)
	var panel_stall: Dictionary = state.building_stall_status.get("panel", {})
	_assert_equal(panel_stall.get("status", ""), "output_capped",
		"gated_upkeep: solar panel stalls output_capped when eng at cap")

	# Excavator: when reg is at cap, the output-capped check fires in Pass 1
	# before upkeep is paid — so upkeep is NOT deducted and production is skipped.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state(sim)
	state.buildings_active["panel"] = 0
	state.buildings_active["data_center"] = 0
	state.buildings_owned["excavator"] = 1
	state.buildings_active["excavator"] = 1
	state.amounts["eng"] = 10.0
	state.amounts["reg"] = 50.0  # at base reg cap (50)
	var eng_before: float = state.amounts["eng"]
	sim.tick(state, true)
	_assert_approx(state.amounts.get("eng", 0.0), eng_before, 0.001,
		"gated_upkeep: excavator does not pay eng upkeep when reg output is at cap")
	_assert_approx(state.amounts.get("reg", 0.0), 50.0, 0.001,
		"gated_upkeep: excavator does not produce reg when output is at cap")
	var exc_stall: Dictionary = state.building_stall_status.get("excavator", {})
	_assert_equal(exc_stall.get("status", ""), "output_capped",
		"gated_upkeep: excavator stall status is output_capped when reg at cap")


func _test_input_starvation_skip() -> void:
	print("--- Input Starvation Skip ---")

	# Smelter starved of regolith: no production, no eng upkeep deducted.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	state.buildings_active["panel"] = 0
	state.buildings_active["data_center"] = 0
	state.buildings_owned["smelter"] = 1
	state.buildings_active["smelter"] = 1
	state.amounts["eng"] = 20.0
	state.amounts["reg"] = 0.0   # starved
	state.amounts["ti"] = 0.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("ti", 0.0), 0.0, 0.001,
		"starvation: smelter skips ti production when reg starved")
	_assert_approx(state.amounts.get("eng", 0.0), 20.0, 0.001,
		"starvation: smelter skips eng upkeep when reg starved")

	# Smelter starved of energy: no production, no reg upkeep deducted.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state(sim)
	state.buildings_active["panel"] = 0
	state.buildings_active["data_center"] = 0
	state.buildings_owned["smelter"] = 1
	state.buildings_active["smelter"] = 1
	state.amounts["eng"] = 0.0   # starved
	state.amounts["reg"] = 20.0
	state.amounts["ti"] = 0.0
	sim.tick(state, true)
	_assert_approx(state.amounts.get("ti", 0.0), 0.0, 0.001,
		"starvation: smelter skips ti production when eng starved")
	_assert_approx(state.amounts.get("reg", 0.0), 20.0, 0.001,
		"starvation: smelter skips reg upkeep when eng starved")


func _test_stall_status_tracking() -> void:
	print("--- Stall Status Tracking ---")

	# Excavator input starved: eng=0 → can't pay upkeep → input_starved.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	state.buildings_active["panel"] = 0
	state.buildings_active["data_center"] = 0
	state.buildings_owned["excavator"] = 1
	state.buildings_active["excavator"] = 1
	state.amounts["eng"] = 0.0
	state.amounts["reg"] = 0.0
	sim.tick(state, true)
	var stall: Dictionary = state.building_stall_status.get("excavator", {})
	_assert_equal(stall.get("status", ""), "input_starved",
		"stall: excavator is input_starved when eng=0")

	# Excavator output capped: reg at cap → output_capped (upkeep not paid).
	sim = TF.create_fresh_sim()
	state = TF.fresh_state(sim)
	state.buildings_active["panel"] = 0
	state.buildings_active["data_center"] = 0
	state.buildings_owned["excavator"] = 1
	state.buildings_active["excavator"] = 1
	state.amounts["eng"] = 10.0
	state.amounts["reg"] = 50.0  # at base reg cap
	sim.tick(state, true)
	stall = state.building_stall_status.get("excavator", {})
	_assert_equal(stall.get("status", ""), "output_capped",
		"stall: excavator is output_capped when reg at cap")

	# Excavator running normally: eng available, reg below cap.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state(sim)
	state.buildings_active["panel"] = 0
	state.buildings_active["data_center"] = 0
	state.buildings_owned["excavator"] = 1
	state.buildings_active["excavator"] = 1
	state.amounts["eng"] = 10.0
	state.amounts["reg"] = 0.0   # well below cap
	sim.tick(state, true)
	stall = state.building_stall_status.get("excavator", {})
	_assert_equal(stall.get("status", ""), "running",
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
	state.buildings_owned["storage_depot"] = 1
	state.buildings_active["storage_depot"] = 1
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
	state.buildings_owned["battery"] = 1
	state.buildings_active["battery"] = 1
	sim.recalculate_caps(state)
	_assert_approx(state.caps.get("eng", 0.0), 150.0, 0.001,
		"caps: 1 battery raises eng cap to 150")


func _test_building_cost_scaling() -> void:
	print("--- Building Cost Scaling ---")

	# Solar panel: base cost 8 cred, scaling 1.2, no ideology alignment.
	# Formula: base_cost * scaling^purchased, where purchased = max(0, owned - bonus).
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)

	# 0 owned → purchased=0 → 8 * 1.2^0 = 8
	state.buildings_owned["panel"] = 0
	state.buildings_bonus["panel"] = 0
	var costs: Dictionary = sim.get_scaled_costs(state, "panel")
	_assert_approx(costs.get("cred", 0.0), 8.0, 0.001,
		"cost_scaling: panel 0 owned → cost 8")

	# 1 owned → purchased=1 → 8 * 1.2^1 = 9.6
	state.buildings_owned["panel"] = 1
	costs = sim.get_scaled_costs(state, "panel")
	_assert_approx(costs.get("cred", 0.0), 9.6, 0.001,
		"cost_scaling: panel 1 owned → cost 9.6")

	# 5 owned → purchased=5 → 8 * 1.2^5 ≈ 19.907
	state.buildings_owned["panel"] = 5
	costs = sim.get_scaled_costs(state, "panel")
	_assert_approx(costs.get("cred", 0.0), 8.0 * pow(1.2, 5.0), 0.001,
		"cost_scaling: panel 5 owned → cost 8 * 1.2^5")

	# Bonus offset: owned=3, bonus=1 → purchased=max(0,2)=2 → 8 * 1.2^2 = 11.52
	state.buildings_owned["panel"] = 3
	state.buildings_bonus["panel"] = 1
	costs = sim.get_scaled_costs(state, "panel")
	_assert_approx(costs.get("cred", 0.0), 8.0 * pow(1.2, 2.0), 0.001,
		"cost_scaling: panel owned=3 bonus=1 → purchased=2, cost 11.52")

	# Bonus matches owned: owned=1, bonus=1 → purchased=max(0,0)=0 → cost 8
	state.buildings_owned["panel"] = 1
	state.buildings_bonus["panel"] = 1
	costs = sim.get_scaled_costs(state, "panel")
	_assert_approx(costs.get("cred", 0.0), 8.0, 0.001,
		"cost_scaling: panel owned=1 bonus=1 → purchased=0, cost 8")


func _test_land_system() -> void:
	print("--- Land System ---")

	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)

	# Fresh state: starting_resources.land=40 minus panel(1 land) minus data_center(2 land) = 37.
	_assert_approx(state.amounts.get("land", 0.0), 37.0, 0.001,
		"land: fresh state has 37 available land after starting buildings")

	# Land purchase cost formula: int(floor(base * scaling^land_purchases)).
	# base=15, scaling=1.5. No ideology or modifier active in fresh state.
	_assert_equal(sim.get_land_purchase_cost(state), 15,
		"land: 1st purchase costs 15 cred (15 * 1.5^0 = 15)")
	state.land_purchases = 1
	_assert_equal(sim.get_land_purchase_cost(state), 22,
		"land: 2nd purchase costs 22 cred (floor(15 * 1.5^1) = floor(22.5) = 22)")
	state.land_purchases = 2
	_assert_equal(sim.get_land_purchase_cost(state), 33,
		"land: 3rd purchase costs 33 cred (floor(15 * 1.5^2) = floor(33.75) = 33)")
	state.land_purchases = 0  # reset for buy test

	# buy_land: deducts cost from cred, adds 10 land, increments land_purchases.
	state.amounts["cred"] = 15.0
	var land_before: float = state.amounts.get("land", 0.0)
	sim.buy_land(state)
	_assert_approx(state.amounts.get("cred", 0.0), 0.0, 0.001,
		"land: buy_land deducts 15 cred")
	_assert_approx(state.amounts.get("land", 0.0), land_before + 10.0, 0.001,
		"land: buy_land adds 10 land")
	_assert_equal(state.land_purchases, 1,
		"land: land_purchases increments after buy_land")

	# Building purchase consumes land. Solar panel costs 1 land.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state(sim)
	state.buildings_owned["panel"] = 0  # reset so purchased=0, cost=8 cred
	state.amounts["cred"] = 8.0
	var land_start: float = state.amounts.get("land", 0.0)
	sim.buy_building(state, "panel")
	_assert_approx(state.amounts.get("land", 0.0), land_start - 1.0, 0.001,
		"land: buying a solar panel consumes 1 land")
	_assert_equal(state.buildings_owned.get("panel", 0), 1,
		"land: panel owned count is 1 after purchase")
