extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(scene_root: Node) -> void:
	_test_full_production()
	_test_partial_production()
	_test_cost_scaling()
	_test_land_cost()
	_test_building_unlock_gating(scene_root)
	_test_project_visibility()
	_test_project_completion()
	_test_persistent_reward(scene_root)


# ── 1. Full production ────────────────────────────────────────────────────────

func _test_full_production() -> void:
	print("--- Fuel Cell Array: Full Production ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	state.flags["chemical_energy_completed"] = true
	TF.add_building(state, "fuel_cell", 1)
	state.amounts["prop"] = 10.0
	state.amounts["eng"] = 0.0
	sim.recalculate_caps(state)

	sim.tick(state, true)

	_assert_approx(state.amounts.get("prop", -1.0), 7.0, 0.001,
		"fuel_cell full: 3 prop consumed")
	_assert_approx(state.amounts.get("eng", -1.0), 15.0, 0.001,
		"fuel_cell full: 15 energy produced")
	_assert_stall_status(state, "fuel_cell", "running",
		"fuel_cell full: not stalled")


# ── 2. Partial production ─────────────────────────────────────────────────────

func _test_partial_production() -> void:
	print("--- Fuel Cell Array: Partial Production ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	state.flags["chemical_energy_completed"] = true
	TF.add_building(state, "fuel_cell", 1)
	state.amounts["prop"] = 1.0
	state.amounts["eng"] = 0.0
	sim.recalculate_caps(state)

	sim.tick(state, true)

	# 1/3 of full upkeep available → 1/3 production
	_assert_approx(state.amounts.get("prop", -1.0), 0.0, 0.001,
		"fuel_cell partial: all 1 prop consumed")
	_assert_approx(state.amounts.get("eng", -1.0), 5.0, 0.5,
		"fuel_cell partial: ~5 energy produced (1/3 of 15)")
	_assert_stall_status(state, "fuel_cell", "input_starved",
		"fuel_cell partial: input_starved stall status")


# ── 3. Cost scaling ───────────────────────────────────────────────────────────

func _test_cost_scaling() -> void:
	print("--- Fuel Cell Array: Cost Scaling ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	state.flags["chemical_energy_completed"] = true

	# First unit cost: cred=200, cir=30
	var costs0: Dictionary = sim.get_scaled_costs(state, "fuel_cell")
	_assert_approx(costs0.get("cred", -1.0), 200.0, 0.001,
		"fuel_cell cost scaling: base cred = 200")
	_assert_approx(costs0.get("cir", -1.0), 30.0, 0.001,
		"fuel_cell cost scaling: base cir = 30")

	# Simulate owning 1 — second purchase should scale by 1.4
	state.buildings_owned["fuel_cell"] = 1
	var costs1: Dictionary = sim.get_scaled_costs(state, "fuel_cell")
	_assert_approx(costs1.get("cred", -1.0), 200.0 * 1.4, 0.01,
		"fuel_cell cost scaling: 2nd unit cred = 280")
	_assert_approx(costs1.get("cir", -1.0), 30.0 * 1.4, 0.01,
		"fuel_cell cost scaling: 2nd unit cir = 42")

	# Nationalist ideology discount at rank 1: pow(0.97, 1) = 0.97
	state.buildings_owned.erase("fuel_cell")
	state.ideology_values["nationalist"] = 100.0  # enough for rank 1
	sim.recalculate_caps(state)
	var costs_disc: Dictionary = sim.get_scaled_costs(state, "fuel_cell")
	var rank1_mult: float = pow(0.97, float(state.get_ideology_rank("nationalist")))
	_assert_approx(costs_disc.get("cred", -1.0), 200.0 * rank1_mult, 1.0,
		"fuel_cell cost scaling: nationalist rank 1 discount applies")


# ── 4. Land cost ──────────────────────────────────────────────────────────────

func _test_land_cost() -> void:
	print("--- Fuel Cell Array: Land Cost ---")
	var bdef: Dictionary = TF.get_building_def("fuel_cell")
	_assert_equal(int(bdef.get("land", -1)), 2,
		"fuel_cell land: land cost = 2")


# ── 5. Building unlock gating ─────────────────────────────────────────────────

func _test_building_unlock_gating(scene_root: Node) -> void:
	print("--- Fuel Cell Array: Unlock Gating ---")
	var gm: Node = scene_root.get_node("/root/GameManager")

	# Save and clear flag
	var had_flag: bool = gm.state.flags.get("chemical_energy_completed", false)
	gm.state.flags.erase("chemical_energy_completed")

	# Not visible and not purchasable without flag
	_assert_false(gm.is_building_visible("fuel_cell"),
		"fuel_cell gating: not visible without flag")
	_assert_false(gm.sim.can_buy_building(gm.state, "fuel_cell"),
		"fuel_cell gating: not purchasable without flag")

	# Set flag — becomes visible and purchasable (if resources allow)
	gm.state.flags["chemical_energy_completed"] = true
	_assert_true(gm.is_building_visible("fuel_cell"),
		"fuel_cell gating: visible with flag")
	_assert_false(gm.sim.is_building_locked(gm.state, "fuel_cell"),
		"fuel_cell gating: requires satisfied with flag")

	# Restore
	if had_flag:
		gm.state.flags["chemical_energy_completed"] = true
	else:
		gm.state.flags.erase("chemical_energy_completed")


# ── 6. Chemical Energy Initiative visibility ──────────────────────────────────

func _test_project_visibility() -> void:
	print("--- Chemical Energy Initiative: Visibility ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	var career := CareerState.new()
	var pm := TF.create_fresh_pm()

	# Not visible before Q6
	pm.tick(state, career)
	_assert_false(state.enabled_projects.has("chemical_energy"),
		"chemical_energy visibility: not enabled before Q6")

	# Becomes visible when Q6 is in event_instances (quest active)
	state.event_instances.append({"id": "q6_open_horizons", "state": "active"})
	pm.tick(state, career)
	_assert_true(state.enabled_projects.has("chemical_energy"),
		"chemical_energy visibility: enabled when Q6 instance active")

	# Also visible via seen_event_ids (completed this run)
	var state2 := TF.fresh_state_isolated(sim)
	var career2 := CareerState.new()
	state2.seen_event_ids.append("q6_open_horizons")
	pm.tick(state2, career2)
	_assert_true(state2.enabled_projects.has("chemical_energy"),
		"chemical_energy visibility: enabled when Q6 in seen_event_ids")

	# Also visible via career.completed_quest_ids (prior run)
	var state3 := TF.fresh_state_isolated(sim)
	var career3 := CareerState.new()
	career3.completed_quest_ids.append("q6_open_horizons")
	pm.tick(state3, career3)
	_assert_true(state3.enabled_projects.has("chemical_energy"),
		"chemical_energy visibility: enabled when Q6 in career.completed_quest_ids")


# ── 7. Chemical Energy Initiative completion ──────────────────────────────────

func _test_project_completion() -> void:
	print("--- Chemical Energy Initiative: Completion ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	var career := CareerState.new()
	var pm := TF.create_fresh_pm()

	state.enabled_projects.append("chemical_energy")
	state.amounts["cred"] = 5000.0
	state.amounts["sci"] = 3000.0
	state.amounts["prop"] = 3000.0
	pm.set_project_rate(state, "chemical_energy", "cred", 30.0)
	pm.set_project_rate(state, "chemical_energy", "sci", 30.0)
	pm.set_project_rate(state, "chemical_energy", "prop", 30.0)

	# Pre-invest to just below threshold, then one tick completes it
	state.project_invested["chemical_energy"] = {"cred": 1999.0, "sci": 999.0, "prop": 999.0}
	pm.tick(state, career)

	_assert_true(state.completed_projects_this_run.has("chemical_energy"),
		"chemical_energy completion: in completed_projects_this_run")
	_assert_true(career.career_flags.get("chemical_energy_completed", false),
		"chemical_energy completion: career_flag set")
	_assert_true(bool(state.flags.get("chemical_energy_completed", false)),
		"chemical_energy completion: state flag set immediately")

	# Verify fuel_cell is now unlocked (requires satisfied)
	_assert_false(sim.is_building_locked(state, "fuel_cell"),
		"chemical_energy completion: fuel_cell requires satisfied after completion")


# ── 8. Persistent reward re-application on new run ────────────────────────────

func _test_persistent_reward(scene_root: Node) -> void:
	print("--- Chemical Energy Initiative: Persistent Reward on New Run ---")
	var gm: Node = scene_root.get_node("/root/GameManager")
	var real_path: String = TF.redirect_save("test_tmp_fuel_cell.json")

	# Save original state
	var had_career_flag: bool = gm.career.career_flags.get("chemical_energy_completed", false)
	var had_state_flag: bool = gm.state.flags.get("chemical_energy_completed", false)

	# Mark as completed in career
	gm.career.career_flags["chemical_energy_completed"] = true
	if not gm.career.completed_projects.has("chemical_energy"):
		gm.career.completed_projects.append("chemical_energy")

	gm.retire(true)
	gm.start_new_run()
	gm.set_speed("||")

	_assert_true(bool(gm.state.flags.get("chemical_energy_completed", false)),
		"persistent reward: chemical_energy_completed flag re-applied on new run")
	_assert_false(gm.sim.is_building_locked(gm.state, "fuel_cell"),
		"persistent reward: fuel_cell visible/unlockable on new run")

	TF.restore_save(real_path, "test_tmp_fuel_cell.json")

	# Restore original state
	if had_career_flag:
		gm.career.career_flags["chemical_energy_completed"] = true
	else:
		gm.career.career_flags.erase("chemical_energy_completed")
	if had_state_flag:
		gm.state.flags["chemical_energy_completed"] = true
	else:
		gm.state.flags.erase("chemical_energy_completed")
