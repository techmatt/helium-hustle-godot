extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(scene_root: Node) -> void:
	_test_project_drain()
	_test_project_completion()
	_test_project_persistence(scene_root)
	_test_persistent_project_reward(scene_root)
	_test_milestone_reset_on_retirement(scene_root)
	_test_cross_retirement_persistence(scene_root)


# ── Project: Drain Over Time ──────────────────────────────────────────────────

func _test_project_drain() -> void:
	print("--- Project: Drain Over Time ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	var career := CareerState.new()
	var pm := TF.create_fresh_pm()

	# Enable predictive_maintenance directly (costs: sci=80, cred=150).
	# Using a research-condition project avoids the event_unlocked path.
	state.enabled_projects.append("predictive_maintenance")
	state.amounts["sci"] = 1000.0
	state.amounts["cred"] = 1000.0
	pm.set_project_rate(state, "predictive_maintenance", "sci", 5.0)
	pm.set_project_rate(state, "predictive_maintenance", "cred", 5.0)

	var sci_before: float = state.amounts["sci"]
	for _i in range(10):
		pm.tick(state, career)

	_assert_approx(sci_before - state.amounts["sci"], 50.0, 0.5,
		"project drain: sci decreased by ~50 over 10 ticks")
	_assert_approx(
		float(state.project_invested.get("predictive_maintenance", {}).get("sci", -1.0)),
		50.0, 0.5,
		"project drain: project_invested sci ~= 50")

	# Partial drain: only 3 sci available, rate is 5 — should drain exactly 3.
	var state2 := TF.fresh_state_isolated(sim)
	var career2 := CareerState.new()
	state2.enabled_projects.append("predictive_maintenance")
	state2.amounts["sci"] = 3.0
	state2.amounts["cred"] = 1000.0
	pm.set_project_rate(state2, "predictive_maintenance", "sci", 5.0)
	pm.set_project_rate(state2, "predictive_maintenance", "cred", 0.0)
	pm.tick(state2, career2)

	_assert_approx(state2.amounts.get("sci", -1.0), 0.0, 0.001,
		"project drain partial: sci drained to 0")
	_assert_true(state2.amounts.get("sci", -1.0) >= 0.0,
		"project drain partial: sci not negative")
	_assert_approx(
		float(state2.project_invested.get("predictive_maintenance", {}).get("sci", -1.0)),
		3.0, 0.001,
		"project drain partial: invested only 3 sci (not 5)")


# ── Project: Completion & Modifier ───────────────────────────────────────────

func _test_project_completion() -> void:
	print("--- Project: Completion & Modifier ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state_isolated(sim)
	var career := CareerState.new()
	var pm := TF.create_fresh_pm()

	# predictive_maintenance: sci=80, cred=150.
	# Pre-invest to 1 below each threshold; one tick's drain of 5 will complete it.
	state.enabled_projects.append("predictive_maintenance")
	state.project_invested["predictive_maintenance"] = {"sci": 79.0, "cred": 149.0}
	state.amounts["sci"] = 1000.0
	state.amounts["cred"] = 1000.0
	pm.set_project_rate(state, "predictive_maintenance", "sci", 5.0)
	pm.set_project_rate(state, "predictive_maintenance", "cred", 5.0)

	pm.tick(state, career)

	_assert_true(state.completed_projects_this_run.has("predictive_maintenance"),
		"project completion: project in completed_projects_this_run")
	_assert_approx(state.get_modifier("building_upkeep_mult"), 0.90, 0.001,
		"project completion: building_upkeep_mult modifier set to 0.90")


# ── Project: Cross-Retirement Persistence ────────────────────────────────────

func _test_project_persistence(scene_root: Node) -> void:
	print("--- Project: Cross-Retirement Persistence ---")
	var gm: Node = scene_root.get_node("/root/GameManager")
	var real_path: String = TF.redirect_save("test_tmp_project_persist.json")

	# Clean up any state left by prior tests.
	gm.career.project_progress.erase("foundation_grant")
	gm.career.completed_projects.erase("foundation_grant")
	gm.state.project_invested.erase("foundation_grant")

	# Partially invest 200 cred into foundation_grant (persistent tier, costs cred=500 sci=100).
	gm.state.project_invested["foundation_grant"] = {"cred": 200.0, "sci": 0.0}

	gm.retire(true)

	_assert_true(gm.career.project_progress.has("foundation_grant"),
		"project persistence: career.project_progress has foundation_grant after retire")
	_assert_approx(
		float(gm.career.project_progress.get("foundation_grant", {}).get("cred", -1.0)),
		200.0, 0.001,
		"project persistence: career.project_progress cred = 200")

	gm.start_new_run()
	gm.set_speed("||")

	_assert_true(gm.state.project_invested.has("foundation_grant"),
		"project persistence: state.project_invested restored after new run")
	_assert_approx(
		float(gm.state.project_invested.get("foundation_grant", {}).get("cred", -1.0)),
		200.0, 0.001,
		"project persistence: state.project_invested cred = 200 after new run")

	TF.restore_save(real_path, "test_tmp_project_persist.json")


# ── Project: Persistent Reward Applied on New Run ────────────────────────────

func _test_persistent_project_reward(scene_root: Node) -> void:
	print("--- Project: Persistent Reward on Run Start ---")
	var gm: Node = scene_root.get_node("/root/GameManager")
	var real_path: String = TF.redirect_save("test_tmp_project_reward.json")

	# Clean up any state left by prior tests.
	gm.career.project_progress.erase("foundation_grant")
	gm.state.project_invested.erase("foundation_grant")
	if not gm.career.completed_projects.has("foundation_grant"):
		gm.career.completed_projects.append("foundation_grant")

	gm.retire(true)
	gm.start_new_run()
	gm.set_speed("||")

	# foundation_grant reward: { panel: 1, excavator: 1 }.
	# Buildings with bonus count are tracked in buildings_bonus so cost scaling is unaffected.
	_assert_true(
		gm.state.buildings_bonus.has("panel") and gm.state.buildings_bonus["panel"] >= 1,
		"persistent reward: buildings_bonus panel >= 1")
	_assert_true(
		gm.state.buildings_bonus.has("excavator") and gm.state.buildings_bonus["excavator"] >= 1,
		"persistent reward: buildings_bonus excavator >= 1")
	_assert_true(gm.state.completed_projects_this_run.has("foundation_grant"),
		"persistent reward: foundation_grant in completed_projects_this_run on new run")

	# Clean up so later tests don't inherit this completed project.
	gm.career.completed_projects.erase("foundation_grant")
	TF.restore_save(real_path, "test_tmp_project_reward.json")


# ── Milestones: Reset on Retirement ──────────────────────────────────────────

func _test_milestone_reset_on_retirement(scene_root: Node) -> void:
	print("--- Milestones: Reset on Retirement ---")
	var gm: Node = scene_root.get_node("/root/GameManager")
	var real_path: String = TF.redirect_save("test_tmp_milestone_reset.json")

	# Fire first_shipment_credits via a full tick (sim + event + project).
	# execute_tick(true) suppresses boredom accumulation so boredom stays at 0
	# and won't trigger forced retirement.
	gm.state.triggered_milestones.clear()
	TF.pretrigger_all_milestones_except(gm.state, "first_shipment_credits")
	gm.state.amounts["boredom"] = 0.0
	gm.state.total_shipments_completed = 1
	gm.execute_tick(true)

	_assert_true(gm.state.triggered_milestones.has("first_shipment_credits"),
		"milestone reset: first_shipment_credits triggered before retire")

	gm.retire(true)
	gm.start_new_run()
	gm.set_speed("||")

	_assert_true(gm.state.triggered_milestones.is_empty(),
		"milestone reset: triggered_milestones empty at new run start")

	# Trigger the same milestone again in the new run — it should fire again.
	TF.pretrigger_all_milestones_except(gm.state, "first_shipment_credits")
	gm.state.amounts["boredom"] = 400.0
	gm.state.total_shipments_completed = 1
	gm.execute_tick(true)

	_assert_true(gm.state.triggered_milestones.has("first_shipment_credits"),
		"milestone reset: first_shipment_credits fires again in new run")

	TF.restore_save(real_path, "test_tmp_milestone_reset.json")


# ── Cross-Retirement: What Persists vs Resets ────────────────────────────────

func _test_cross_retirement_persistence(scene_root: Node) -> void:
	print("--- Cross-Retirement: Persist vs Reset ---")
	var gm: Node = scene_root.get_node("/root/GameManager")
	var real_path: String = TF.redirect_save("test_tmp_cross_retire.json")

	# Pre-populate career data that should survive retirement.
	if not gm.career.completed_quest_ids.has("_test_cross_quest"):
		gm.career.completed_quest_ids.append("_test_cross_quest")
	if not gm.career.seen_event_ids.has("_test_cross_event"):
		gm.career.seen_event_ids.append("_test_cross_event")
	var pre_retirements: int = gm.career.total_retirements

	# Set run state values that should all reset after retirement.
	gm.state.amounts["boredom"] = 500.0
	gm.state.ideology_values["nationalist"] = 300.0
	gm.state.current_day = 100
	if not gm.state.completed_research.has("overclock_protocols"):
		gm.state.completed_research.append("overclock_protocols")
	if not gm.state.triggered_milestones.has("first_shipment_credits"):
		gm.state.triggered_milestones.append("first_shipment_credits")

	gm.retire(true)
	TF.reset_career_bonus_tracking(gm.career)
	gm.start_new_run()
	gm.set_speed("||")

	# Should RESET
	_assert_equal(gm.state.current_day, 0,
		"cross-retirement: current_day resets to 0")
	_assert_approx(gm.state.amounts.get("boredom", -1.0), 0.0, 0.001,
		"cross-retirement: boredom resets to 0")
	_assert_approx(gm.state.ideology_values.get("nationalist", -999.0), 0.0, 0.001,
		"cross-retirement: ideology_values nationalist resets to 0")
	_assert_true(gm.state.completed_research.is_empty(),
		"cross-retirement: completed_research resets to empty")
	_assert_true(gm.state.triggered_milestones.is_empty(),
		"cross-retirement: triggered_milestones resets to empty")

	# Should PERSIST
	_assert_equal(gm.career.total_retirements, pre_retirements + 1,
		"cross-retirement: total_retirements incremented")
	_assert_true(gm.career.completed_quest_ids.has("_test_cross_quest"),
		"cross-retirement: completed_quest_ids persists")
	_assert_true(gm.career.seen_event_ids.has("_test_cross_event"),
		"cross-retirement: seen_event_ids persists")

	TF.restore_save(real_path, "test_tmp_cross_retire.json")
