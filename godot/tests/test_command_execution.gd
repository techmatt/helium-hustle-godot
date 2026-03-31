extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_command_idle()
	_test_command_sell_cloud_compute()
	_test_command_buy_resources()
	_test_command_dream()
	_test_command_fund_ideology()
	_test_command_failure()
	_test_command_requires_gating()
	_test_shipment_cumulative_credits()


func _test_command_idle() -> void:
	print("--- Command: Idle ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	state.amounts["cred"] = 0.0
	sim.execute_command(state, "idle")
	_assert_approx(state.amounts.get("cred", 0.0), 1.0, 0.001,
		"idle: cred increases by 1")


func _test_command_sell_cloud_compute() -> void:
	print("--- Command: Sell Cloud Compute ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	state.amounts["eng"] = 100.0
	state.amounts["cred"] = 0.0
	state.amounts["boredom"] = 0.0
	sim.execute_command(state, "cloud_compute")
	_assert_approx(state.amounts.get("cred", 0.0), 5.0, 0.001,
		"cloud_compute: cred increases by 5")
	_assert_approx(state.amounts.get("eng", 0.0), 97.0, 0.001,
		"cloud_compute: eng decreases by 3")
	_assert_approx(state.amounts.get("boredom", 0.0), 0.4, 0.001,
		"cloud_compute: boredom increases by 0.4")


func _test_command_buy_resources() -> void:
	print("--- Command: Buy Resources ---")

	# Buy Regolith: costs 8 cred + 2 eng, produces 1 reg
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	state.amounts["cred"] = 100.0
	state.amounts["eng"] = 100.0
	state.amounts["reg"] = 0.0
	sim.execute_command(state, "buy_regolith")
	_assert_approx(state.amounts.get("cred", 0.0), 92.0, 0.001,
		"buy_regolith: cred decreases by 8")
	_assert_approx(state.amounts.get("eng", 0.0), 98.0, 0.001,
		"buy_regolith: eng decreases by 2")
	_assert_approx(state.amounts.get("reg", 0.0), 1.0, 0.001,
		"buy_regolith: reg increases by 1")

	# Buy Ice: costs 10 cred + 2 eng, produces 1 ice
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	state.amounts["cred"] = 100.0
	state.amounts["eng"] = 100.0
	state.amounts["ice"] = 0.0
	sim.execute_command(state, "buy_ice")
	_assert_approx(state.amounts.get("cred", 0.0), 90.0, 0.001,
		"buy_ice: cred decreases by 10")
	_assert_approx(state.amounts.get("eng", 0.0), 98.0, 0.001,
		"buy_ice: eng decreases by 2")
	_assert_approx(state.amounts.get("ice", 0.0), 1.0, 0.001,
		"buy_ice: ice increases by 1")

	# Buy Titanium: costs 20 cred + 3 eng, produces 0.5 ti
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	state.amounts["cred"] = 100.0
	state.amounts["eng"] = 100.0
	state.amounts["ti"] = 0.0
	sim.execute_command(state, "buy_titanium")
	_assert_approx(state.amounts.get("cred", 0.0), 80.0, 0.001,
		"buy_titanium: cred decreases by 20")
	_assert_approx(state.amounts.get("eng", 0.0), 97.0, 0.001,
		"buy_titanium: eng decreases by 3")
	_assert_approx(state.amounts.get("ti", 0.0), 0.5, 0.001,
		"buy_titanium: ti increases by 0.5")

	# Buy Propellant: costs 12 cred + 2 eng, produces 1 prop
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	state.amounts["cred"] = 100.0
	state.amounts["eng"] = 100.0
	state.amounts["prop"] = 0.0
	sim.execute_command(state, "buy_propellant")
	_assert_approx(state.amounts.get("cred", 0.0), 88.0, 0.001,
		"buy_propellant: cred decreases by 12")
	_assert_approx(state.amounts.get("eng", 0.0), 98.0, 0.001,
		"buy_propellant: eng decreases by 2")
	_assert_approx(state.amounts.get("prop", 0.0), 1.0, 0.001,
		"buy_propellant: prop increases by 1")


func _test_command_dream() -> void:
	print("--- Command: Dream ---")

	# Base case: dream_protocols only. Cost 8 eng, boredom -2.0.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_with_research(sim, ["dream_protocols"])
	state.amounts["eng"] = 100.0
	state.amounts["boredom"] = 500.0
	sim.execute_command(state, "dream")
	_assert_approx(state.amounts.get("eng", 0.0), 92.0, 0.001,
		"dream: eng decreases by 8 (base cost)")
	_assert_approx(state.amounts.get("boredom", 0.0), 498.0, 0.001,
		"dream: boredom decreases by 2.0")

	# With efficient_dreaming: cost overridden to 5 eng. Boredom reduction unchanged.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_with_research(sim, ["dream_protocols", "efficient_dreaming"])
	state.amounts["eng"] = 100.0
	state.amounts["boredom"] = 500.0
	sim.execute_command(state, "dream")
	_assert_approx(state.amounts.get("eng", 0.0), 95.0, 0.001,
		"dream + efficient_dreaming: eng decreases by 5 (reduced cost)")
	_assert_approx(state.amounts.get("boredom", 0.0), 498.0, 0.001,
		"dream + efficient_dreaming: boredom still decreases by 2.0")


func _test_command_fund_ideology() -> void:
	print("--- Command: Fund Ideology ---")

	# Fund Nationalists: nationalist +1.0, humanist -0.5, rationalist -0.5
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_with_research(sim, ["nationalist_lobbying"])
	state.amounts["cred"] = 100.0
	state.amounts["eng"] = 100.0
	state.ideology_values = {"nationalist": 0.0, "humanist": 0.0, "rationalist": 0.0}
	sim.execute_command(state, "fund_nationalist")
	_assert_approx(state.ideology_values.get("nationalist", 0.0), 1.0, 0.001,
		"fund_nationalist: nationalist increases by 1.0")
	_assert_approx(state.ideology_values.get("humanist", 0.0), -0.5, 0.001,
		"fund_nationalist: humanist decreases by 0.5")
	_assert_approx(state.ideology_values.get("rationalist", 0.0), -0.5, 0.001,
		"fund_nationalist: rationalist decreases by 0.5")

	# Fund Humanists: humanist +1.0, nationalist -0.5, rationalist -0.5
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_with_research(sim, ["humanist_lobbying"])
	state.amounts["cred"] = 100.0
	state.amounts["eng"] = 100.0
	state.ideology_values = {"nationalist": 0.0, "humanist": 0.0, "rationalist": 0.0}
	sim.execute_command(state, "fund_humanist")
	_assert_approx(state.ideology_values.get("humanist", 0.0), 1.0, 0.001,
		"fund_humanist: humanist increases by 1.0")
	_assert_approx(state.ideology_values.get("nationalist", 0.0), -0.5, 0.001,
		"fund_humanist: nationalist decreases by 0.5")
	_assert_approx(state.ideology_values.get("rationalist", 0.0), -0.5, 0.001,
		"fund_humanist: rationalist decreases by 0.5")

	# Fund Rationalists: rationalist +1.0, nationalist -0.5, humanist -0.5
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_with_research(sim, ["rationalist_lobbying"])
	state.amounts["cred"] = 100.0
	state.amounts["eng"] = 100.0
	state.ideology_values = {"nationalist": 0.0, "humanist": 0.0, "rationalist": 0.0}
	sim.execute_command(state, "fund_rationalist")
	_assert_approx(state.ideology_values.get("rationalist", 0.0), 1.0, 0.001,
		"fund_rationalist: rationalist increases by 1.0")
	_assert_approx(state.ideology_values.get("nationalist", 0.0), -0.5, 0.001,
		"fund_rationalist: nationalist decreases by 0.5")
	_assert_approx(state.ideology_values.get("humanist", 0.0), -0.5, 0.001,
		"fund_rationalist: humanist decreases by 0.5")


func _test_command_failure() -> void:
	print("--- Command: Failure (can't afford) ---")

	# Sell Cloud Compute needs 3 eng. With eng=0, execute_command returns false
	# and nothing changes.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	state.amounts["eng"] = 0.0
	state.amounts["cred"] = 0.0
	state.amounts["boredom"] = 0.0
	var result: bool = sim.execute_command(state, "cloud_compute")
	_assert_false(result,
		"failure: execute_command returns false when eng=0")
	_assert_approx(state.amounts.get("cred", 0.0), 0.0, 0.001,
		"failure: cloud_compute earns no cred when eng=0")
	_assert_approx(state.amounts.get("boredom", 0.0), 0.0, 0.001,
		"failure: cloud_compute adds no boredom when eng=0")

	# Buy Regolith needs 8 cred. With cred=0, nothing changes and eng untouched.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	state.amounts["cred"] = 0.0
	state.amounts["eng"] = 100.0
	state.amounts["reg"] = 0.0
	result = sim.execute_command(state, "buy_regolith")
	_assert_false(result,
		"failure: execute_command returns false when cred=0")
	_assert_approx(state.amounts.get("reg", 0.0), 0.0, 0.001,
		"failure: buy_regolith produces no reg when cred=0")
	_assert_approx(state.amounts.get("cred", 0.0), 0.0, 0.001,
		"failure: buy_regolith does not go negative on cred")
	_assert_approx(state.amounts.get("eng", 0.0), 100.0, 0.001,
		"failure: buy_regolith does not consume eng when cred insufficient")


func _test_command_requires_gating() -> void:
	print("--- Command: Requires Gating ---")

	# Dream requires dream_protocols.
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	state.amounts["eng"] = 100.0
	state.amounts["boredom"] = 500.0
	_assert_false(sim.is_command_executable(state, "dream"),
		"gating: dream is not executable without dream_protocols")
	state.completed_research.append("dream_protocols")
	_assert_true(sim.is_command_executable(state, "dream"),
		"gating: dream is executable with dream_protocols")

	# Verify effect: dream without research leaves state unchanged.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	state.amounts["eng"] = 100.0
	state.amounts["boredom"] = 500.0
	sim.execute_command(state, "dream")
	_assert_approx(state.amounts.get("boredom", 0.0), 500.0, 0.001,
		"gating: dream does not reduce boredom without dream_protocols")

	# Fund Nationalist requires nationalist_lobbying.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	state.amounts["cred"] = 100.0
	state.amounts["eng"] = 100.0
	_assert_false(sim.is_command_executable(state, "fund_nationalist"),
		"gating: fund_nationalist is not executable without nationalist_lobbying")

	# Overclock Mining requires overclock_protocols.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	state.amounts["eng"] = 100.0
	state.amounts["sci"] = 100.0
	_assert_false(sim.is_command_executable(state, "overclock_mining"),
		"gating: overclock_mining is not executable without overclock_protocols")

	# Promote He-3 requires trade_promotion.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	state.amounts["eng"] = 100.0
	state.amounts["cred"] = 100.0
	_assert_false(sim.is_command_executable(state, "promote_he3"),
		"gating: promote_he3 is not executable without trade_promotion")

	# Disrupt Speculators requires market_awareness.
	sim = TF.create_fresh_sim()
	state = TF.fresh_state_isolated(sim)
	state.amounts["eng"] = 100.0
	_assert_false(sim.is_command_executable(state, "disrupt_spec"),
		"gating: disrupt_spec is not executable without market_awareness")


func _test_shipment_cumulative_credits() -> void:
	print("--- Shipment: cumulative credits tracked ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)

	# Provide enough propellant for a launch (fuel cost = 20 per pad)
	state.amounts["prop"] = 100.0

	# Manually create a fully-loaded he3 pad at capacity (100)
	var pad := GameState.LaunchPadData.new()
	pad.resource_type = "he3"
	pad.cargo_loaded = 100.0
	pad.status = GameState.PAD_FULL
	state.pads.append(pad)

	# Fix demand to 1.0 for a deterministic payout.
	# he3 base_value = 20 (from game_config shipment.base_values), so:
	# payout = 20 * 1.0 * 100 = 2000 cred
	state.demand["he3"] = 1.0

	var cred_before: float = state.amounts.get("cred", 0.0)
	var cumulative_before: float = state.cumulative_resources_earned.get("cred", 0.0)

	var launched: bool = sim.launch_pad_manual(state, 0)
	_assert_true(launched, "shipment: launch_pad_manual returned true for a full pad")

	var expected_payout: float = 20.0 * 1.0 * 100.0  # base_value * demand * cargo
	_assert_approx(state.amounts.get("cred", 0.0) - cred_before, expected_payout, 0.001,
		"shipment: cred balance increases by payout (2000)")
	_assert_approx(state.cumulative_resources_earned.get("cred", 0.0) - cumulative_before, expected_payout, 0.001,
		"shipment: cumulative_resources_earned[cred] increases by payout (2000)")
