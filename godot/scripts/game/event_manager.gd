class_name EventManager
extends RefCounted

signal event_triggered(event_id: String)
signal event_completed(event_id: String)
signal boredom_phase_changed(old_phase: int, new_phase: int)

var _event_defs: Array = []
var _def_map: Dictionary = {}
var _boredom_curve: Array = []  # Array of [day: int, rate: float]
var _career: CareerState = null

# Dynamic notifications (project completions, etc.) — shown in ongoing section
var notifications: Array = []  # Array of { title: String, day: int }

signal notification_added


func init(events_data: Array, game_config: Dictionary) -> void:
	_event_defs = events_data
	for def in _event_defs:
		_def_map[def.id] = def
	_boredom_curve.clear()
	for entry in game_config.get("boredom_curve", []):
		_boredom_curve.append([int(entry.get("day", 0)), float(entry.get("rate", 0.0))])


func on_game_start(state: GameState, career: CareerState = null) -> void:
	if career != null:
		_career = career

	# Fire game_start triggers
	for def in _event_defs:
		var trigger: Dictionary = def.get("trigger", {})
		if trigger.get("type", "") != "game_start":
			continue
		var run_num: int = int(trigger.get("run_number", 0))
		if run_num != 0 and run_num != state.run_number:
			continue
		if not _get_instance(state, def.id).is_empty():
			continue
		_trigger_event(state, def)

	# On repeat runs: resume quest chain at the first incomplete quest
	if state.run_number > 1 and _career != null:
		for def in _event_defs:
			if def.get("category", "") != "story":
				continue
			if _career.completed_quest_ids.has(def.id):
				continue
			if not _get_instance(state, def.id).is_empty():
				continue
			var trigger: Dictionary = def.get("trigger", {})
			if trigger.get("type", "") == "quest_complete":
				var req_quest: String = trigger.get("quest_id", "")
				if _career.completed_quest_ids.has(req_quest):
					_trigger_event(state, def)
					break  # Only activate one quest — the first incomplete one


func tick(state: GameState) -> void:
	_check_boredom_phase(state)

	# Check triggers for not-yet-triggered events (game_start handled in on_game_start)
	for def in _event_defs:
		if not _get_instance(state, def.id).is_empty():
			continue
		var trigger: Dictionary = def.get("trigger", {})
		match trigger.get("type", ""):
			"quest_complete":
				var quest_id: String = trigger.get("quest_id", "")
				if _is_event_completed(state, quest_id):
					_trigger_event(state, def)
			"boredom_phase":
				var phase: int = int(trigger.get("phase", 0))
				if state.current_boredom_phase == phase:
					_trigger_event(state, def)

	# Check conditions for active or acknowledged events
	for inst in state.event_instances:
		if inst.state == "completed":
			continue
		var def: Dictionary = _def_map.get(inst.id, {})
		if def.is_empty():
			continue
		if _check_condition(state, def):
			if (def.get("choices", []) as Array).is_empty():
				_complete_event(state, inst, "")


func acknowledge_event(event_id: String, state: GameState) -> void:
	var inst: Dictionary = _get_instance(state, event_id)
	if inst.is_empty():
		return
	if inst.state == "active":
		inst.state = "acknowledged"
	if not state.seen_event_ids.has(event_id):
		state.seen_event_ids.append(event_id)


func make_choice(event_id: String, choice_id: String, state: GameState) -> void:
	var inst: Dictionary = _get_instance(state, event_id)
	if inst.is_empty() or inst.state == "completed":
		return
	var def: Dictionary = _def_map.get(event_id, {})
	if def.is_empty():
		return
	for choice in def.get("choices", []):
		if choice.get("id", "") == choice_id:
			for res in choice.get("cost", {}):
				state.amounts[res] = maxf(0.0, state.amounts.get(res, 0.0) - float(choice.cost[res]))
			break
	_complete_event(state, inst, choice_id)
	if not state.seen_event_ids.has(event_id):
		state.seen_event_ids.append(event_id)


func get_active_events(category: String, state: GameState) -> Array:
	var result: Array = []
	for inst in state.event_instances:
		if inst.state != "active" and inst.state != "acknowledged":
			continue
		var def: Dictionary = _def_map.get(inst.id, {})
		if category.is_empty() or def.get("category", "") == category:
			result.append(inst)
	return result


func get_completed_events(state: GameState) -> Array:
	var result: Array = []
	for inst in state.event_instances:
		if inst.state == "completed":
			result.append(inst)
	return result


func is_event_first_time(event_id: String, state: GameState) -> bool:
	return not state.seen_event_ids.has(event_id)


func push_notification(title: String, day: int) -> void:
	notifications.append({"title": title, "day": day})
	notification_added.emit()


func get_event_def(event_id: String) -> Dictionary:
	return _def_map.get(event_id, {})


func get_condition_display(event_id: String, state: GameState) -> String:
	var def: Dictionary = _def_map.get(event_id, {})
	if def.is_empty():
		return ""
	var cond: Dictionary = def.get("condition", {})
	match cond.get("type", ""):
		"resource_cumulative":
			var res: String = cond.get("resource_id", "")
			var amount: float = float(cond.get("amount", 0))
			var current: float = state.cumulative_resources_earned.get(res, 0.0)
			return "%d/%d" % [int(current), int(amount)]
		"building_owned":
			var bname: String = cond.get("building_id", "")
			var count: int = int(cond.get("count", 1))
			return "%d/%d" % [state.buildings_owned.get(bname, 0), count]
		"shipment_completed":
			var count: int = int(cond.get("count", 1))
			return "%d/%d" % [state.total_shipments_completed, count]
	return ""


# ── Private ──────────────────────────────────────────────────────────────────


func _check_boredom_phase(state: GameState) -> void:
	var new_phase: int = _compute_boredom_phase(state)
	if new_phase != state.current_boredom_phase:
		var old_phase: int = state.current_boredom_phase
		state.current_boredom_phase = new_phase
		boredom_phase_changed.emit(old_phase, new_phase)


func _compute_boredom_phase(state: GameState) -> int:
	var phase: int = 1
	for i in range(_boredom_curve.size()):
		if state.current_day >= _boredom_curve[i][0]:
			phase = i + 1
		else:
			break
	return phase


func _trigger_event(state: GameState, def: Dictionary) -> void:
	var inst: Dictionary = {
		"id": def.id,
		"state": "active",
		"choice_made": "",
		"completed_on_day": -1,
		"progress": 0.0,
	}
	state.event_instances.append(inst)
	event_triggered.emit(def.id)


func _check_condition(state: GameState, def: Dictionary) -> bool:
	var cond: Dictionary = def.get("condition", {})
	if cond.is_empty():
		return true
	match cond.get("type", ""):
		"immediate":
			return true
		"never":
			return false
		"building_owned":
			var bname: String = cond.get("building_id", "")
			var count: int = int(cond.get("count", 1))
			return state.buildings_owned.get(bname, 0) >= count
		"resource_cumulative":
			var res: String = cond.get("resource_id", "")
			var amount: float = float(cond.get("amount", 0))
			return state.cumulative_resources_earned.get(res, 0.0) >= amount
		"shipment_completed":
			var count: int = int(cond.get("count", 1))
			return state.total_shipments_completed >= count
		"boredom_threshold":
			var value: float = float(cond.get("value", 0))
			return state.amounts.get("boredom", 0.0) >= value
		"research_completed_any":
			return not state.completed_research.is_empty()
		"research_completed":
			return state.completed_research.has(cond.get("research_id", ""))
		"persistent_project_completed_any":
			if _career != null:
				return _career.completed_projects.size() > 0
			return false
		"ideology_rank_any":
			var target_rank: int = int(cond.get("rank", 0))
			# Check career max ideology ranks (ideology system not yet implemented in GameState)
			if _career != null:
				for axis: String in ["nationalist", "humanist", "rationalist"]:
					if _career.max_ideology_ranks.get(axis, 0) >= target_rank:
						return true
			return false
	return false


func _complete_event(state: GameState, inst: Dictionary, choice_id: String) -> void:
	inst.state = "completed"
	inst.choice_made = choice_id
	inst.completed_on_day = state.current_day
	var def: Dictionary = _def_map.get(inst.id, {})
	if def.get("category", "") == "story":
		state.highest_completed_story_quest = inst.id
	# Auto-completing events (no choices) are immediately marked seen so
	# systems that gate on seen_event_ids (e.g. research visible_when) activate at once.
	if (def.get("choices", []) as Array).is_empty():
		if not state.seen_event_ids.has(inst.id):
			state.seen_event_ids.append(inst.id)
	for effect in def.get("unlocks", []):
		_apply_unlock(state, effect)
	event_completed.emit(inst.id)


func _apply_unlock(state: GameState, effect: Dictionary) -> void:
	match effect.get("type", ""):
		"enable_building":
			var bname: String = effect.get("building_id", "")
			if bname and not state.unlocked_buildings.has(bname):
				state.unlocked_buildings.append(bname)
		"enable_nav_panel":
			var panel: String = effect.get("panel", "")
			if panel and not state.unlocked_nav_panels.has(panel):
				state.unlocked_nav_panels.append(panel)
		"enable_project":
			var proj: String = effect.get("project_id", "")
			print("[EventManager] Unlock: enable_project " + proj)
			if proj and not state.enabled_projects.has(proj):
				state.enabled_projects.append(proj)
		"set_flag":
			var flag: String = effect.get("flag", "")
			if flag:
				state.flags[flag] = bool(effect.get("value", false))


func _get_instance(state: GameState, event_id: String) -> Dictionary:
	for inst: Dictionary in state.event_instances:
		if inst.id == event_id:
			return inst
	return {}


func _is_event_completed(state: GameState, event_id: String) -> bool:
	var inst: Dictionary = _get_instance(state, event_id)
	return not inst.is_empty() and inst.state == "completed"
