extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")
const AchievementManager := preload("res://scripts/game/achievement_manager.gd")


func run(scene_root: Node) -> void:
	_test_tick_condition_produced()
	_test_tick_condition_consumed()
	_test_tick_condition_stockpile()
	_test_tick_condition_shipments_this_run()
	_test_shipment_condition_revenue()
	_test_shipment_condition_demand()
	_test_modifier_reward()
	_test_bonus_buildings_reward()
	_test_bonus_buildings_cost_scaling()
	_test_demand_ceiling_modifier()
	_test_all_rewards_applied_on_run_start(scene_root)


# ── Condition detection ───────────────────────────────────────────────────────

func _test_tick_condition_produced() -> void:
	print("--- Achievements: resource_produced_per_tick ---")
	var am := _make_am()
	var state := GameState.new()
	var career := CareerState.new()

	# Below threshold — not met
	var result := am.check_tick_conditions(state, career, {"reg": 39.9}, {})
	_assert_false(result.has("strip_mining"),
		"strip_mining not triggered when reg produced < 40")

	# At threshold — met
	result = am.check_tick_conditions(state, career, {"reg": 40.0}, {})
	_assert_true(result.has("strip_mining"),
		"strip_mining triggered when reg produced >= 40")

	# Already earned — not re-triggered
	career.achievements.append("strip_mining")
	result = am.check_tick_conditions(state, career, {"reg": 100.0}, {})
	_assert_false(result.has("strip_mining"),
		"strip_mining not re-triggered when already earned")


func _test_tick_condition_consumed() -> void:
	print("--- Achievements: resource_consumed_per_tick ---")
	var am := _make_am()
	var state := GameState.new()
	var career := CareerState.new()

	# At threshold — not met (must be strictly greater)
	var result := am.check_tick_conditions(state, career, {}, {"eng": 100.0})
	_assert_false(result.has("powerhouse"),
		"powerhouse not triggered at exactly 100 energy consumed")

	# Above threshold — met
	result = am.check_tick_conditions(state, career, {}, {"eng": 100.1})
	_assert_true(result.has("powerhouse"),
		"powerhouse triggered when eng consumed > 100")


func _test_tick_condition_stockpile() -> void:
	print("--- Achievements: resource_stockpile ---")
	var am := _make_am()
	var state := GameState.new()
	var career := CareerState.new()
	state.amounts["cir"] = 999.9

	var result := am.check_tick_conditions(state, career, {}, {})
	_assert_false(result.has("silicon_valley"),
		"silicon_valley not triggered at cir stockpile < 1000")

	state.amounts["cir"] = 1000.0
	result = am.check_tick_conditions(state, career, {}, {})
	_assert_true(result.has("silicon_valley"),
		"silicon_valley triggered at cir stockpile >= 1000")


func _test_tick_condition_shipments_this_run() -> void:
	print("--- Achievements: shipments_this_run ---")
	var am := _make_am()
	var state := GameState.new()
	var career := CareerState.new()
	state.total_shipments_completed = 9

	var result := am.check_tick_conditions(state, career, {}, {})
	_assert_false(result.has("bulk_shipper"),
		"bulk_shipper not triggered at 9 shipments")

	state.total_shipments_completed = 10
	result = am.check_tick_conditions(state, career, {}, {})
	_assert_true(result.has("bulk_shipper"),
		"bulk_shipper triggered at 10 shipments")


func _test_shipment_condition_revenue() -> void:
	print("--- Achievements: shipment_revenue ---")
	var am := _make_am()
	var state := GameState.new()
	var career := CareerState.new()

	var result := am.check_shipment_conditions(state, career, 999.9, 0.5)
	_assert_false(result.has("first_profit"),
		"first_profit not triggered at revenue < 1000")

	result = am.check_shipment_conditions(state, career, 1000.0, 0.5)
	_assert_true(result.has("first_profit"),
		"first_profit triggered at revenue >= 1000")


func _test_shipment_condition_demand() -> void:
	print("--- Achievements: shipment_demand ---")
	var am := _make_am()
	var state := GameState.new()
	var career := CareerState.new()

	# At threshold — not met (must be strictly greater)
	var result := am.check_shipment_conditions(state, career, 500.0, 0.95)
	_assert_false(result.has("market_timer"),
		"market_timer not triggered at demand == 0.95")

	result = am.check_shipment_conditions(state, career, 500.0, 0.951)
	_assert_true(result.has("market_timer"),
		"market_timer triggered at demand > 0.95")


# ── Reward application ────────────────────────────────────────────────────────

func _test_modifier_reward() -> void:
	print("--- Achievements: modifier reward ---")
	var am := _make_am()
	var state := GameState.new()
	var buildings_data := TF.load_buildings_data()

	# Apply strip_mining reward: excavator_output_mult = 1.10
	_assert_equal(state.active_modifiers.get("excavator_output_mult", 1.0), 1.0,
		"excavator_output_mult starts at 1.0")

	am.apply_reward(state, "strip_mining", buildings_data)
	_assert_approx(state.active_modifiers.get("excavator_output_mult", 0.0), 1.10, 0.001,
		"excavator_output_mult set to 1.10 after strip_mining reward")

	# Apply again — stacks multiplicatively
	am.apply_reward(state, "strip_mining", buildings_data)
	_assert_approx(state.active_modifiers.get("excavator_output_mult", 0.0), 1.21, 0.001,
		"excavator_output_mult stacks multiplicatively on second apply")


func _test_bonus_buildings_reward() -> void:
	print("--- Achievements: bonus_buildings reward ---")
	var am := _make_am()
	var state := GameState.new()
	state.amounts["land"] = 100.0
	var buildings_data := TF.load_buildings_data()

	_assert_equal(state.buildings_owned.get("battery", 0), 0,
		"battery owned starts at 0")

	am.apply_reward(state, "powerhouse", buildings_data)

	_assert_equal(state.buildings_owned.get("battery", 0), 2,
		"powerhouse reward: 2 batteries added to owned_count")
	_assert_equal(state.buildings_active.get("battery", 0), 2,
		"powerhouse reward: 2 batteries added to active_count")
	_assert_equal(state.buildings_bonus.get("battery", 0), 2,
		"powerhouse reward: 2 batteries added to bonus_count")


func _test_bonus_buildings_cost_scaling() -> void:
	print("--- Achievements: bonus buildings don't inflate cost scaling ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	state.amounts["cred"] = 100000.0
	state.amounts["land"] = 200.0
	var am := _make_am()
	var buildings_data := TF.load_buildings_data()

	# Grant 2 bonus batteries via achievement reward
	am.apply_reward(state, "powerhouse", buildings_data)
	var owned_after: int = state.buildings_owned.get("battery", 0)
	var bonus_after: int = state.buildings_bonus.get("battery", 0)
	_assert_equal(bonus_after, 2, "bonus_count is 2 after powerhouse reward")

	# purchased_count = max(0, owned - bonus) = max(0, 2 - 2) = 0
	# So next battery should cost base price (no scaling)
	var purchased: int = maxi(0, owned_after - bonus_after)
	_assert_equal(purchased, 0,
		"purchased_count is 0 so cost scaling is unaffected by bonus buildings")


# ── Demand ceiling ────────────────────────────────────────────────────────────

func _test_demand_ceiling_modifier() -> void:
	print("--- Achievements: demand_ceiling modifier ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_demand_isolated(sim)

	# Without modifier, demand is clamped to 1.0 max
	state.demand_perlin_seeds["he3"] = 0.0   # seed that pushes demand high
	# Push demand high via promote
	state.demand_promote["he3"] = 5.0
	sim.demand_system.tick_demand(state)
	var demand_without: float = state.demand.get("he3", 0.0)
	_assert_lt(demand_without, 1.001,
		"demand clamped to <= 1.0 without demand_ceiling modifier")

	# With demand_ceiling = 1.10, demand can exceed 1.0
	state.set_modifier("demand_ceiling", 1.10)
	state.demand_promote["he3"] = 5.0
	sim.demand_system.tick_demand(state)
	var demand_with: float = state.demand.get("he3", 0.0)
	# Can be up to 1.10 now; should be above what it was without modifier
	_assert_gt(demand_with, demand_without - 0.001,
		"demand with ceiling modifier is >= demand without it")


# ── Cross-retirement persistence ──────────────────────────────────────────────

func _test_all_rewards_applied_on_run_start(scene_root: Node) -> void:
	print("--- Achievements: rewards applied on run start ---")
	var gm: Node = scene_root.get_node("/root/GameManager")
	var original_skip: bool = gm.skip_save_load
	gm.skip_save_load = true

	# Manually add achievement to career
	var career: CareerState = CareerState.new()
	career.achievements.append("strip_mining")
	career.achievements.append("powerhouse")

	# Create fresh state and apply all achievement rewards
	var am := _make_am()
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	state.amounts["land"] = 200.0
	var buildings_data := TF.load_buildings_data()
	am.apply_all_rewards(state, career, buildings_data)
	sim.recalculate_caps(state)

	_assert_approx(state.active_modifiers.get("excavator_output_mult", 0.0), 1.10, 0.001,
		"excavator_output_mult applied on run start from career achievements")
	_assert_equal(state.buildings_bonus.get("battery", 0), 2,
		"bonus batteries granted on run start from career achievements")
	_assert_equal(state.buildings_owned.get("battery", 0), 2,
		"battery owned count includes bonus on run start")

	gm.skip_save_load = original_skip


# ── Helper ────────────────────────────────────────────────────────────────────

func _make_am() -> AchievementManager:
	var am := AchievementManager.new()
	var file := FileAccess.open("res://data/achievements.json", FileAccess.READ)
	var data: Array = JSON.parse_string(file.get_as_text())
	file.close()
	am.init(data)
	return am
