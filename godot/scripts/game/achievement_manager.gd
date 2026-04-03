class_name AchievementManager
extends RefCounted

var _defs: Array = []        # Array of achievement dicts
var _def_map: Dictionary = {} # id → dict


func init(achievements_data: Array) -> void:
	_defs = achievements_data
	for def in _defs:
		_def_map[def.id] = def


func get_def(achievement_id: String) -> Dictionary:
	return _def_map.get(achievement_id, {})


# Check tick-based conditions at end of each tick.
# Returns array of newly-completed achievement IDs.
func check_tick_conditions(
	state: GameState,
	career: CareerState,
	tick_produced: Dictionary,
	tick_consumed: Dictionary,
) -> Array[String]:
	var newly_completed: Array[String] = []
	for def in _defs:
		var aid: String = def.get("id", "")
		if career.achievements.has(aid):
			continue
		var ctype: String = def.get("condition_type", "")
		var params: Dictionary = def.get("condition_params", {})
		var met: bool = false
		match ctype:
			"resource_produced_per_tick":
				var res: String = params.get("resource", "")
				var threshold: float = float(params.get("threshold", 0))
				met = tick_produced.get(res, 0.0) >= threshold
			"resource_consumed_per_tick":
				var res: String = params.get("resource", "")
				var threshold: float = float(params.get("threshold", 0))
				met = tick_consumed.get(res, 0.0) > threshold
			"resource_stockpile":
				var res: String = params.get("resource", "")
				var threshold: float = float(params.get("threshold", 0))
				met = state.amounts.get(res, 0.0) >= threshold
			"shipments_this_run":
				var threshold: int = int(params.get("threshold", 0))
				met = state.total_shipments_completed >= threshold
		if met:
			newly_completed.append(aid)
	return newly_completed


# Check shipment-based conditions when a shipment completes.
# Returns array of newly-completed achievement IDs.
func check_shipment_conditions(
	state: GameState,
	career: CareerState,
	revenue: float,
	demand: float,
) -> Array[String]:
	var newly_completed: Array[String] = []
	for def in _defs:
		var aid: String = def.get("id", "")
		if career.achievements.has(aid):
			continue
		var ctype: String = def.get("condition_type", "")
		var params: Dictionary = def.get("condition_params", {})
		var met: bool = false
		match ctype:
			"shipment_revenue":
				var threshold: float = float(params.get("threshold", 0))
				met = revenue >= threshold
			"shipment_demand":
				var threshold: float = float(params.get("threshold", 0))
				met = demand > threshold
		if met:
			newly_completed.append(aid)
	return newly_completed


# Apply a single achievement's reward to GameState immediately.
# Call this when an achievement is first earned AND on run start for all earned achievements.
func apply_reward(state: GameState, achievement_id: String, buildings_data: Array) -> void:
	var def: Dictionary = _def_map.get(achievement_id, {})
	if def.is_empty():
		return
	var rtype: String = def.get("reward_type", "")
	var rparams: Dictionary = def.get("reward_params", {})
	match rtype:
		"modifier":
			var key: String = rparams.get("key", "")
			var value: float = float(rparams.get("value", 1.0))
			# Modifiers stack multiplicatively with existing value
			state.active_modifiers[key] = state.active_modifiers.get(key, 1.0) * value
		"bonus_buildings":
			var bsn: String = rparams.get("building", "")
			var count: int = int(rparams.get("count", 0))
			if bsn.is_empty() or count <= 0:
				return
			state.buildings_owned[bsn] = state.buildings_owned.get(bsn, 0) + count
			state.buildings_active[bsn] = state.buildings_active.get(bsn, 0) + count
			state.buildings_bonus[bsn] = state.buildings_bonus.get(bsn, 0) + count
			for bdef: Dictionary in buildings_data:
				if bdef.get("short_name", "") == bsn:
					state.amounts["land"] = state.amounts.get("land", 0.0) - float(bdef.get("land", 0)) * count
					break


# Apply all rewards for achievements earned in career (for run start).
# Call sim.recalculate_caps(state) after this.
func apply_all_rewards(state: GameState, career: CareerState, buildings_data: Array) -> void:
	for aid: String in career.achievements:
		apply_reward(state, aid, buildings_data)


# Returns the display name for a category.
func get_category_display(category: String) -> String:
	match category:
		"miner":
			return "Miner"
		"trader":
			return "Trader"
	return category.capitalize()


# Returns all defs in a given category.
func get_defs_by_category(category: String) -> Array:
	var result: Array = []
	for def in _defs:
		if def.get("category", "") == category:
			result.append(def)
	return result


# Returns all unique category names in definition order.
func get_categories() -> Array[String]:
	var seen: Array[String] = []
	for def in _defs:
		var cat: String = def.get("category", "")
		if not seen.has(cat):
			seen.append(cat)
	return seen
