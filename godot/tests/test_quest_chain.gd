extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_quest_chain_ids()
	_test_all_of_partial_completion()
	_test_sub_objective_latching()
	_test_days_survived_condition()
	_test_credits_earned_condition()
	_test_persistent_project_pre_completion()


# ── Helper: create a fresh EventManager loaded from JSON ─────────────────────

func _make_em(career: CareerState = null) -> EventManager:
	var em := EventManager.new()
	var events_data: Array = TF.load_events_data()
	var game_config: Dictionary = TF.load_game_config()
	em.init(events_data, game_config)
	if career != null:
		em.on_game_start(GameState.new(), career)
	return em


# ── 1. Quest chain IDs ────────────────────────────────────────────────────────

func _test_quest_chain_ids() -> void:
	print("--- Quest Chain: Revised IDs ---")
	var em := _make_em()
	var chain: Array = em.get_quest_chain()
	var ids: Array = []
	for def: Dictionary in chain:
		ids.append(def.get("id", ""))

	_assert_true(ids.has("q1_boot_sequence"), "chain has q1_boot_sequence")
	_assert_true(ids.has("q2_first_extraction"), "chain has q2_first_extraction")
	_assert_true(ids.has("q3_proof_of_concept"), "chain has q3_proof_of_concept")
	_assert_true(ids.has("q4_automation"), "chain has q4_automation")
	_assert_true(ids.has("q5_market_awareness"), "chain has q5_market_awareness")
	_assert_true(ids.has("q6_open_horizons"), "chain has q6_open_horizons")
	_assert_true(ids.has("q_end_signal_detected"), "chain has q_end_signal_detected")

	_assert_false(ids.has("q5_revenue_target"), "q5_revenue_target removed")
	_assert_false(ids.has("q7_first_legacy"), "q7_first_legacy removed")
	_assert_false(ids.has("q8_influence"), "q8_influence removed")

	# Verify ordering
	var idx_q4: int = ids.find("q4_automation")
	var idx_q5: int = ids.find("q5_market_awareness")
	var idx_q6: int = ids.find("q6_open_horizons")
	var idx_end: int = ids.find("q_end_signal_detected")
	_assert_true(idx_q4 < idx_q5, "q4 before q5")
	_assert_true(idx_q5 < idx_q6, "q5 before q6")
	_assert_true(idx_q6 < idx_end, "q6 before q_end")


# ── 2. all_of: partial completion does not complete quest ─────────────────────

func _test_all_of_partial_completion() -> void:
	print("--- Quest Chain: all_of Partial Completion ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	var career := CareerState.new()
	var em := EventManager.new()
	em.init(TF.load_events_data(), TF.load_game_config())
	em.on_game_start(state, career)

	# Manually trigger q6 (bypass earlier quest chain)
	var q6_def: Dictionary = em.get_event_def("q6_open_horizons")
	_assert_false(q6_def.is_empty(), "q6_open_horizons def exists")
	state.event_instances.append({
		"id": "q6_open_horizons",
		"state": "active",
		"choice_made": "",
		"completed_on_day": -1,
		"progress": 0.0,
	})

	# Satisfy only ideology_rank_5 and persistent_project (2 of 4)
	TF.set_ideology_rank(state, "nationalist", 5)
	career.completed_projects.append("some_project")

	# days_survived: day 100 < 3650; credits_earned: 0 < 100000
	state.current_day = 100
	state.cumulative_resources_earned["cred"] = 0.0

	em.tick(state)

	# Quest should not be completed yet
	var inst: Dictionary = _get_q6_instance(state)
	_assert_false(inst.is_empty(), "q6 instance exists after partial tick")
	_assert_false(inst.get("state", "") == "completed",
		"q6 not completed when only 2/4 sub-objectives met")

	# Latched sub-objectives should include the two satisfied ones
	_assert_true(career.completed_sub_objectives.has("q6_open_horizons:ideology_rank_5"),
		"ideology_rank_5 latched after ideology rank 5 reached")
	_assert_true(career.completed_sub_objectives.has("q6_open_horizons:persistent_project"),
		"persistent_project latched after project completed")
	_assert_false(career.completed_sub_objectives.has("q6_open_horizons:survive_10_years"),
		"survive_10_years not latched at day 100")
	_assert_false(career.completed_sub_objectives.has("q6_open_horizons:credits_100k"),
		"credits_100k not latched at 0 credits")

	# Now satisfy remaining two
	state.current_day = 3650
	state.cumulative_resources_earned["cred"] = 100000.0
	em.tick(state)

	inst = _get_q6_instance(state)
	_assert_true(inst.get("state", "") == "completed",
		"q6 completed when all 4 sub-objectives met")


# ── 3. Sub-objective latching persists across retirements ─────────────────────

func _test_sub_objective_latching() -> void:
	print("--- Quest Chain: Sub-objective Latching ---")
	var career := CareerState.new()

	# Simulate: latch 2 sub-objectives in run 1
	career.completed_sub_objectives.append("q6_open_horizons:ideology_rank_5")
	career.completed_sub_objectives.append("q6_open_horizons:persistent_project")

	# Serialize and deserialize (simulating save/load across retirement)
	var saved: Dictionary = career.to_dict()
	var career2: CareerState = CareerState.from_dict(saved)

	_assert_true(career2.completed_sub_objectives.has("q6_open_horizons:ideology_rank_5"),
		"latching persists: ideology_rank_5 survives save/load")
	_assert_true(career2.completed_sub_objectives.has("q6_open_horizons:persistent_project"),
		"latching persists: persistent_project survives save/load")
	_assert_false(career2.completed_sub_objectives.has("q6_open_horizons:survive_10_years"),
		"latching persists: survive_10_years not present (not yet met)")

	# In run 2, q6 should see that those two are already done
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	var em := EventManager.new()
	em.init(TF.load_events_data(), TF.load_game_config())
	em.on_game_start(state, career2)

	state.event_instances.append({
		"id": "q6_open_horizons",
		"state": "active",
		"choice_made": "",
		"completed_on_day": -1,
		"progress": 0.0,
	})

	# Complete remaining two in run 2
	state.current_day = 3650
	state.cumulative_resources_earned["cred"] = 100000.0
	em.tick(state)

	var inst: Dictionary = _get_q6_instance(state)
	_assert_true(inst.get("state", "") == "completed",
		"q6 completes in run 2 after remaining sub-objectives met")
	_assert_true(career2.completed_sub_objectives.has("q6_open_horizons:survive_10_years"),
		"survive_10_years latched in run 2")
	_assert_true(career2.completed_sub_objectives.has("q6_open_horizons:credits_100k"),
		"credits_100k latched in run 2")


# ── 4. days_survived condition ────────────────────────────────────────────────

func _test_days_survived_condition() -> void:
	print("--- Quest Chain: days_survived Condition ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	var career := CareerState.new()
	var em := EventManager.new()
	em.init(TF.load_events_data(), TF.load_game_config())
	em.on_game_start(state, career)

	state.event_instances.append({
		"id": "q6_open_horizons",
		"state": "active",
		"choice_made": "",
		"completed_on_day": -1,
		"progress": 0.0,
	})

	# Pre-satisfy everything except days_survived; set day to 3649
	career.completed_sub_objectives.append("q6_open_horizons:ideology_rank_5")
	career.completed_sub_objectives.append("q6_open_horizons:persistent_project")
	career.completed_sub_objectives.append("q6_open_horizons:credits_100k")
	state.current_day = 3649
	state.cumulative_resources_earned["cred"] = 100000.0

	em.tick(state)
	var inst: Dictionary = _get_q6_instance(state)
	_assert_false(inst.get("state", "") == "completed",
		"days_survived: quest not complete at day 3649")
	_assert_false(career.completed_sub_objectives.has("q6_open_horizons:survive_10_years"),
		"days_survived: survive_10_years not latched at day 3649")

	state.current_day = 3650
	em.tick(state)
	_assert_true(career.completed_sub_objectives.has("q6_open_horizons:survive_10_years"),
		"days_survived: survive_10_years latched at day 3650")
	inst = _get_q6_instance(state)
	_assert_true(inst.get("state", "") == "completed",
		"days_survived: quest completes at day 3650")


# ── 5. credits_earned condition ───────────────────────────────────────────────

func _test_credits_earned_condition() -> void:
	print("--- Quest Chain: credits_earned Condition ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	var career := CareerState.new()
	var em := EventManager.new()
	em.init(TF.load_events_data(), TF.load_game_config())
	em.on_game_start(state, career)

	state.event_instances.append({
		"id": "q6_open_horizons",
		"state": "active",
		"choice_made": "",
		"completed_on_day": -1,
		"progress": 0.0,
	})

	# Pre-satisfy everything except credits_earned; set credits to 99999
	career.completed_sub_objectives.append("q6_open_horizons:ideology_rank_5")
	career.completed_sub_objectives.append("q6_open_horizons:persistent_project")
	career.completed_sub_objectives.append("q6_open_horizons:survive_10_years")
	state.current_day = 3650
	state.cumulative_resources_earned["cred"] = 99999.0

	em.tick(state)
	var inst: Dictionary = _get_q6_instance(state)
	_assert_false(inst.get("state", "") == "completed",
		"credits_earned: quest not complete at 99999")
	_assert_false(career.completed_sub_objectives.has("q6_open_horizons:credits_100k"),
		"credits_earned: credits_100k not latched at 99999")

	state.cumulative_resources_earned["cred"] = 100000.0
	em.tick(state)
	_assert_true(career.completed_sub_objectives.has("q6_open_horizons:credits_100k"),
		"credits_earned: credits_100k latched at 100000")
	inst = _get_q6_instance(state)
	_assert_true(inst.get("state", "") == "completed",
		"credits_earned: quest completes at 100000")


# ── 6. Persistent project pre-completed before Q6 activates ──────────────────

func _test_persistent_project_pre_completion() -> void:
	print("--- Quest Chain: Persistent Project Pre-Completion ---")
	var sim := TF.create_fresh_sim()
	var state := TF.fresh_state(sim)
	var career := CareerState.new()

	# Player completed a persistent project before Q6 was active
	career.completed_projects.append("foundation_grant")

	var em := EventManager.new()
	em.init(TF.load_events_data(), TF.load_game_config())
	em.on_game_start(state, career)

	# Activate Q6
	state.event_instances.append({
		"id": "q6_open_horizons",
		"state": "active",
		"choice_made": "",
		"completed_on_day": -1,
		"progress": 0.0,
	})

	em.tick(state)

	# persistent_project sub-objective should latch immediately on first tick
	_assert_true(career.completed_sub_objectives.has("q6_open_horizons:persistent_project"),
		"pre-completion: persistent_project latches immediately when Q6 activates")


# ── Private ───────────────────────────────────────────────────────────────────

func _get_q6_instance(state: GameState) -> Dictionary:
	for inst: Dictionary in state.event_instances:
		if inst.get("id", "") == "q6_open_horizons":
			return inst
	return {}
