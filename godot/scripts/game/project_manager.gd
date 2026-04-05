class_name ProjectManager
extends RefCounted

signal project_unlocked(project_id: String)
signal project_completed(project_id: String)

var _project_defs: Array = []
var _def_map: Dictionary = {}       # { id: pdef_dict }
var _max_drain_rate: float = 30.0

# Populated during tick, read by GameManager for notifications
var pending_completion_notifications: Array = []  # { name: String }


func init(projects_data: Array, game_config: Dictionary) -> void:
	_project_defs = projects_data
	for pdef: Dictionary in _project_defs:
		_def_map[pdef.id] = pdef
	_max_drain_rate = float(game_config.get("projects", {}).get("max_drain_rate", 30.0))


func tick(state: GameState, career: CareerState) -> void:
	pending_completion_notifications.clear()
	_check_unlock_conditions(state, career)
	_process_drains(state, career)


func get_max_drain_rate() -> float:
	return _max_drain_rate


func get_project_def(project_id: String) -> Dictionary:
	return _def_map.get(project_id, {})


func get_all_defs() -> Array:
	return _project_defs


func set_project_rate(state: GameState, project_id: String, resource_id: String, rate: float) -> void:
	rate = clampf(rate, 0.0, _max_drain_rate)
	if not state.active_project_rates.has(project_id):
		state.active_project_rates[project_id] = {}
	state.active_project_rates[project_id][resource_id] = rate


func get_project_rate(state: GameState, project_id: String, resource_id: String) -> float:
	return float(state.active_project_rates.get(project_id, {}).get(resource_id, 0.0))


func is_project_complete(state: GameState, project_id: String) -> bool:
	return state.completed_projects_this_run.has(project_id)


func is_project_unlocked(state: GameState, project_id: String) -> bool:
	return state.enabled_projects.has(project_id)


# ── Private ───────────────────────────────────────────────────────────────────


func _check_unlock_conditions(state: GameState, career: CareerState) -> void:
	for pdef: Dictionary in _project_defs:
		var pid: String = pdef.id
		if state.enabled_projects.has(pid):
			continue
		if state.completed_projects_this_run.has(pid):
			continue
		var cond: Dictionary = pdef.get("unlock_condition", {})
		if cond.get("type", "") == "event_unlocked":
			# Handled by event system writing to state.enabled_projects
			continue
		if _check_condition(cond, state, career):
			state.enabled_projects.append(pid)
			project_unlocked.emit(pid)


func _process_drains(state: GameState, career: CareerState) -> void:
	for pid: String in state.enabled_projects:
		if not _def_map.has(pid):
			continue
		if state.completed_projects_this_run.has(pid):
			continue
		var pdef: Dictionary = _def_map[pid]
		var costs: Dictionary = pdef.get("costs", {})
		var rates: Dictionary = state.active_project_rates.get(pid, {})

		if not state.project_invested.has(pid):
			state.project_invested[pid] = {}

		for res: String in costs:
			var total_needed: float = float(costs[res])
			var already_invested: float = float(state.project_invested[pid].get(res, 0.0))
			if already_invested >= total_needed:
				continue
			var rate: float = float(rates.get(res, 0.0))
			if rate <= 0.0:
				continue
			var remaining: float = total_needed - already_invested
			var available: float = float(state.amounts.get(res, 0.0))
			var actual_drain: float = minf(rate, minf(remaining, available))
			if actual_drain <= 0.0:
				continue
			state.amounts[res] = state.amounts.get(res, 0.0) - actual_drain
			state.project_invested[pid][res] = already_invested + actual_drain

		if _is_fully_funded(pdef, state.project_invested.get(pid, {})):
			_complete_project(state, career, pid, pdef)


func _is_fully_funded(pdef: Dictionary, invested: Dictionary) -> bool:
	for res: String in pdef.get("costs", {}):
		if float(invested.get(res, 0.0)) < float(pdef.costs[res]):
			return false
	return true


func _complete_project(state: GameState, career: CareerState, pid: String, pdef: Dictionary) -> void:
	# Apply reward
	var reward: Dictionary = pdef.get("reward", {})
	match reward.get("type", ""):
		"modifier":
			state.set_modifier(reward.get("modifier_key", ""), float(reward.get("modifier_value", 1.0)))
		"starting_buildings":
			pass  # Applied on run start from CareerState
		"stub":
			pass  # Placeholder — no gameplay effect yet
		"unlock":
			# Set a persistent career flag to unlock content in future runs
			var flag: String = reward.get("flag", "")
			if not flag.is_empty():
				career.career_flags[flag] = true
				state.flags[flag] = true  # apply immediately this run too
		"boredom_modifiers":
			# AI Consciousness Act — permanent boredom rate reduction
			career.career_flags["ai_consciousness_completed"] = true
			career.career_flags["ai_consciousness_boredom_rate_mult"] = float(reward.get("base_boredom_rate_mult", 1.0))
			career.career_flags["ai_consciousness_command_boredom"] = reward.get("command_boredom", {}).duplicate()
			state.flags["ai_consciousness_active"] = true
			state.set_modifier("ai_consciousness_boredom_rate_mult", float(reward.get("base_boredom_rate_mult", 1.0)))
			state.flags["ai_consciousness_command_boredom"] = reward.get("command_boredom", {}).duplicate()
		"research_discount":
			# Universal Research Archive — discount on re-purchased research
			career.career_flags["research_archive_completed"] = true
			career.career_flags["research_archive_discount_mult"] = float(reward.get("discount_mult", 0.75))
			state.flags["research_archive_active"] = true
			state.set_modifier("research_archive_discount_mult", float(reward.get("discount_mult", 0.75)))
			state.flags["archive_eligible_research"] = career.lifetime_researched_ids.duplicate()

	# Track completion
	state.completed_projects_this_run.append(pid)

	# Persistent: save progress into career
	if pdef.get("tier", "") == "persistent":
		if not career.completed_projects.has(pid):
			career.completed_projects.append(pid)
		career.project_progress.erase(pid)

	# Clear drain rates so UI stepper resets
	state.active_project_rates.erase(pid)

	pending_completion_notifications.append({"name": pdef.get("name", pid)})
	project_completed.emit(pid)


func _check_condition(cond: Dictionary, state: GameState, career: CareerState) -> bool:
	match cond.get("type", ""):
		"event_unlocked":
			return state.enabled_projects.has(cond.get("project_id", ""))
		"research_completed":
			return state.completed_research.has(cond.get("research_id", ""))
		"flag_set":
			return bool(state.flags.get(cond.get("flag", ""), false))
		"ideology_rank":
			var axis: String = cond.get("axis", "")
			var required_rank: int = int(cond.get("rank", 0))
			# Check current run rank OR career max (so persistent projects unlock after prior-run achievement)
			var current_rank: int = state.get_ideology_rank(axis)
			var career_max: int = int(career.max_ideology_ranks.get(axis, 0))
			return current_rank >= required_rank or career_max >= required_rank
	return false
