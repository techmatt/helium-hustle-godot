class_name GameSimulation
extends RefCounted

var _resources_data: Array = []
var _buildings_data: Array = []


func init(resources_data: Array, buildings_data: Array) -> void:
	_resources_data = resources_data
	_buildings_data = buildings_data


func tick(state: GameState) -> void:
	recalculate_caps(state)

	for bdef in _buildings_data:
		var count: int = state.buildings_owned.get(bdef.short_name, 0)
		if count == 0:
			continue
		if not _can_pay_upkeep(state, bdef, count):
			continue
		for res in bdef.upkeep:
			state.amounts[res] = state.amounts.get(res, 0.0) - float(bdef.upkeep[res]) * count
		for res in bdef.production:
			state.amounts[res] = state.amounts.get(res, 0.0) + float(bdef.production[res]) * count

	_clamp(state)
	state.current_day += 1


func recalculate_caps(state: GameState) -> void:
	for rdef in _resources_data:
		var sn: String = rdef.short_name
		if rdef.storage_base == null:
			state.caps[sn] = INF
		else:
			state.caps[sn] = float(rdef.storage_base)

	for bdef in _buildings_data:
		var count: int = state.buildings_owned.get(bdef.short_name, 0)
		if count == 0:
			continue
		for effect in bdef.effects:
			if effect.prefix == "store":
				state.caps[effect.resource] = state.caps.get(effect.resource, 0.0) + float(effect.value) * count


func can_buy_building(state: GameState, short_name: String) -> bool:
	var bdef = _get_bdef(short_name)
	if bdef == null:
		return false
	if state.amounts.get("land", 0.0) < float(bdef.land):
		return false
	var scale: float = pow(float(bdef.cost_scaling), state.buildings_owned.get(short_name, 0))
	for res in bdef.costs:
		if state.amounts.get(res, 0.0) < float(bdef.costs[res]) * scale:
			return false
	return true


func buy_building(state: GameState, short_name: String) -> void:
	var bdef = _get_bdef(short_name)
	if bdef == null:
		return
	var scale: float = pow(float(bdef.cost_scaling), state.buildings_owned.get(short_name, 0))
	for res in bdef.costs:
		state.amounts[res] -= float(bdef.costs[res]) * scale
	state.amounts["land"] -= float(bdef.land)
	state.buildings_owned[short_name] = state.buildings_owned.get(short_name, 0) + 1
	recalculate_caps(state)


func get_scaled_costs(state: GameState, short_name: String) -> Dictionary:
	var bdef = _get_bdef(short_name)
	if bdef == null:
		return {}
	var scale: float = pow(float(bdef.cost_scaling), state.buildings_owned.get(short_name, 0))
	var result: Dictionary = {}
	for res in bdef.costs:
		result[res] = float(bdef.costs[res]) * scale
	return result


func _can_pay_upkeep(state: GameState, bdef: Dictionary, count: int) -> bool:
	for res in bdef.upkeep:
		if state.amounts.get(res, 0.0) < float(bdef.upkeep[res]) * count:
			return false
	return true


func _clamp(state: GameState) -> void:
	for res in state.amounts.keys():
		var cap: float = state.caps.get(res, INF)
		state.amounts[res] = clampf(state.amounts.get(res, 0.0), 0.0, cap)


func _get_bdef(short_name: String) -> Variant:
	for bdef in _buildings_data:
		if bdef.short_name == short_name:
			return bdef
	return null
