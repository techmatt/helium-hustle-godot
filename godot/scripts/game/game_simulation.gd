class_name GameSimulation
extends RefCounted

var _resources_data: Array = []
var _buildings_data: Array = []
var _commands_data: Dictionary = {}   # {short_name: command_dict}
var _research_data: Dictionary = {}   # {id: research_item_dict}
var pending_program_events: Array = []  # populated during tick, read by GameManager
var last_gross_deltas: Dictionary = {}  # pre-clamp net change per resource this tick

# Shipment constants (set from game_config in init)
var _pad_cargo_capacity: float = 100.0
var _launch_fuel_cost: float = 20.0
var _launch_cooldown: int = 10
var _trade_values: Dictionary = {"he3": 20.0, "ti": 12.0, "cir": 30.0, "prop": 8.0}
var _demand_baseline: float = 0.5

# Boredom curve: Array of [start_day, rate]
var _boredom_curve: Array = []


func init(resources_data: Array, buildings_data: Array, commands_data: Array, game_config: Dictionary = {}, research_data: Array = []) -> void:
	_resources_data = resources_data
	_buildings_data = buildings_data
	for cmd in commands_data:
		_commands_data[cmd.short_name] = cmd
	for item in research_data:
		_research_data[item.id] = item
	var ship: Dictionary = game_config.get("shipment", {})
	if not ship.is_empty():
		_pad_cargo_capacity = float(ship.get("pad_cargo_capacity", 100))
		_launch_fuel_cost = float(ship.get("fuel_per_pad", 20))
		_trade_values = {}
		for k: String in ship.get("base_values", {}):
			_trade_values[k] = float(ship.base_values[k])
	var dem: Dictionary = game_config.get("demand", {})
	if dem.has("baseline"):
		_demand_baseline = float(dem.get("baseline", 0.5))
	_boredom_curve.clear()
	for entry in game_config.get("boredom_curve", []):
		_boredom_curve.append([int(entry.get("day", 0)), float(entry.get("rate", 0.0))])


func tick(state: GameState) -> void:
	pending_program_events.clear()
	last_gross_deltas.clear()
	recalculate_caps(state)

	# Boredom accumulation
	var boredom_rate: float = _get_boredom_rate(state.current_day)
	boredom_rate *= _get_boredom_multiplier(state)
	state.amounts["boredom"] = state.amounts.get("boredom", 0.0) + boredom_rate
	last_gross_deltas["boredom"] = boredom_rate

	# Two-pass building tick so producers see post-consumption resource levels.
	#
	# Pass 1 — upkeep only.
	#   Buildings WITH upkeep: pay now if output isn't already all-at-cap and
	#   upkeep is affordable. Add to will_produce list.
	#   Buildings with NO upkeep (e.g. solar panels): always added to
	#   will_produce — they cost nothing to run; let Pass 2 decide.
	#
	# Pass 2 — production only, using the post-upkeep resource levels.
	#   Now a producer (solar) correctly sees that consumers (data center)
	#   already drew down shared resources, and runs when it should.

	var will_produce: Array = []  # each entry: [bdef, count]

	for bdef in _buildings_data:
		var owned: int = state.buildings_owned.get(bdef.short_name, 0)
		if owned == 0:
			continue
		var count: int = state.buildings_active.get(bdef.short_name, owned)
		if count == 0:
			continue

		if (bdef.upkeep as Dictionary).is_empty():
			# Free producer — no upkeep decision needed; always eligible.
			will_produce.append([bdef, count])
		else:
			# Skip if every output is already at cap (don't waste upkeep).
			var prod: Dictionary = bdef.get("production", {})
			if not prod.is_empty():
				var all_at_cap: bool = true
				for res in prod:
					var cap: float = state.caps.get(res, INF)
					if cap == INF or state.amounts.get(res, 0.0) < cap:
						all_at_cap = false
						break
				if all_at_cap:
					continue
			if not _can_pay_upkeep(state, bdef, count):
				continue
			for res in bdef.upkeep:
				var cost: float = float(bdef.upkeep[res]) * count
				state.amounts[res] = state.amounts.get(res, 0.0) - cost
				last_gross_deltas[res] = last_gross_deltas.get(res, 0.0) - cost
			will_produce.append([bdef, count])

	for entry in will_produce:
		var bdef: Dictionary = entry[0]
		var count: int = entry[1]
		var prod: Dictionary = bdef.get("production", {})
		if not prod.is_empty():
			var all_at_cap: bool = true
			for res in prod:
				var cap: float = state.caps.get(res, INF)
				if cap == INF or state.amounts.get(res, 0.0) < cap:
					all_at_cap = false
					break
			if all_at_cap:
				continue
		for res in bdef.production:
			var delta: float = float(bdef.production[res]) * count
			state.amounts[res] = state.amounts.get(res, 0.0) + delta
			last_gross_deltas[res] = last_gross_deltas.get(res, 0.0) + delta
			if res == "sci":
				state.cumulative_science_earned += delta
			if delta > 0.0:
				state.cumulative_resources_earned[res] = state.cumulative_resources_earned.get(res, 0.0) + delta

	# Advance pad cooldown states
	for pad: GameState.LaunchPadData in state.pads:
		if pad.status == GameState.PAD_LAUNCHING:
			pad.status = GameState.PAD_COOLDOWN
			pad.cargo_loaded = 0.0
			pad.cooldown_ticks = _launch_cooldown
		elif pad.status == GameState.PAD_COOLDOWN:
			pad.cooldown_ticks -= 1
			if pad.cooldown_ticks <= 0:
				pad.status = GameState.PAD_EMPTY
				pad.cooldown_ticks = 0

	execute_programs(state)

	_clamp(state)
	state.current_day += 1


func execute_programs(state: GameState) -> void:
	for prog_idx in range(state.programs.size()):
		var prog: GameState.ProgramData = state.programs[prog_idx]
		if prog.processors_assigned <= 0 or prog.commands.is_empty():
			continue
		for _proc in range(prog.processors_assigned):
			if prog.commands.is_empty():
				break
			var ip: int = prog.instruction_pointer
			var entry: GameState.ProgramEntry = prog.commands[ip]
			var success: bool = _can_afford_command(state, entry.command_shortname)
			if success:
				_apply_command(state, entry.command_shortname)
			else:
				entry.failed_this_cycle = true
			entry.current_progress += 1
			pending_program_events.append({
				"type": "step",
				"program_index": prog_idx,
				"entry_index": ip,
				"success": success,
			})
			if entry.current_progress >= entry.repeat_count:
				prog.instruction_pointer = ip + 1
				if prog.instruction_pointer >= prog.commands.size():
					prog.instruction_pointer = 0
					for e: GameState.ProgramEntry in prog.commands:
						e.current_progress = 0
						e.failed_this_cycle = false
					pending_program_events.append({
						"type": "cycle_reset",
						"program_index": prog_idx,
					})


func recalculate_caps(state: GameState) -> void:
	for rdef in _resources_data:
		var sn: String = rdef.short_name
		if rdef.storage_base == null:
			state.caps[sn] = INF
		else:
			state.caps[sn] = float(rdef.storage_base)

	for bdef in _buildings_data:
		var owned: int = state.buildings_owned.get(bdef.short_name, 0)
		if owned == 0:
			continue
		var count: int = state.buildings_active.get(bdef.short_name, owned)
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
	var old_owned: int = state.buildings_owned.get(short_name, 0)
	var scale: float = pow(float(bdef.cost_scaling), old_owned)
	for res in bdef.costs:
		state.amounts[res] -= float(bdef.costs[res]) * scale
	state.amounts["land"] -= float(bdef.land)
	state.buildings_owned[short_name] = old_owned + 1
	# New building comes online immediately
	state.buildings_active[short_name] = state.buildings_active.get(short_name, old_owned) + 1
	recalculate_caps(state)
	if short_name == "launch_pad":
		var pad := GameState.LaunchPadData.new()
		pad.resource_type = state.loading_priority[0] if not state.loading_priority.is_empty() else "he3"
		state.pads.append(pad)


func get_scaled_costs(state: GameState, short_name: String) -> Dictionary:
	var bdef = _get_bdef(short_name)
	if bdef == null:
		return {}
	var scale: float = pow(float(bdef.cost_scaling), state.buildings_owned.get(short_name, 0))
	var result: Dictionary = {}
	for res in bdef.costs:
		result[res] = float(bdef.costs[res]) * scale
	return result


func sell_building(state: GameState, short_name: String, sell_count: int = 1) -> void:
	var owned: int = state.buildings_owned.get(short_name, 0)
	if owned <= 0:
		return
	var actual: int = mini(sell_count, owned)
	var bdef = _get_bdef(short_name)
	if bdef:
		state.amounts["land"] = state.amounts.get("land", 0.0) + float(bdef.land) * actual
	state.buildings_owned[short_name] = owned - actual
	state.buildings_active[short_name] = mini(
		state.buildings_active.get(short_name, owned),
		state.buildings_owned[short_name]
	)
	recalculate_caps(state)
	_clamp(state)
	_clamp_processor_assignments(state)
	if short_name == "launch_pad":
		var new_owned: int = state.buildings_owned.get(short_name, 0)
		while state.pads.size() > new_owned:
			var removed: GameState.LaunchPadData = state.pads.pop_back()
			if removed.cargo_loaded > 0.0 and removed.status != GameState.PAD_COOLDOWN and removed.status != GameState.PAD_LAUNCHING:
				state.amounts[removed.resource_type] = state.amounts.get(removed.resource_type, 0.0) + removed.cargo_loaded


func set_building_active(state: GameState, short_name: String, delta: int) -> void:
	var owned: int = state.buildings_owned.get(short_name, 0)
	var active: int = state.buildings_active.get(short_name, owned)
	state.buildings_active[short_name] = clampi(active + delta, 0, owned)
	recalculate_caps(state)
	_clamp(state)
	_clamp_processor_assignments(state)


func launch_pad_manual(state: GameState, pad_idx: int) -> bool:
	if pad_idx < 0 or pad_idx >= state.pads.size():
		return false
	var pad: GameState.LaunchPadData = state.pads[pad_idx]
	if pad.status != GameState.PAD_FULL:
		return false
	if state.amounts.get("prop", 0.0) < _launch_fuel_cost:
		return false
	state.amounts["prop"] -= _launch_fuel_cost
	var payout: float = _trade_values.get(pad.resource_type, 1.0) * _demand_baseline * pad.cargo_loaded
	state.amounts["cred"] = state.amounts.get("cred", 0.0) + payout
	_record_launch(state, pad, payout)
	pad.status = GameState.PAD_LAUNCHING
	return true


func can_launch_pad(state: GameState, pad_idx: int) -> bool:
	if pad_idx < 0 or pad_idx >= state.pads.size():
		return false
	var pad: GameState.LaunchPadData = state.pads[pad_idx]
	return pad.status == GameState.PAD_FULL and state.amounts.get("prop", 0.0) >= _launch_fuel_cost


func set_pad_resource(state: GameState, pad_idx: int, resource_type: String) -> void:
	if pad_idx < 0 or pad_idx >= state.pads.size():
		return
	var pad: GameState.LaunchPadData = state.pads[pad_idx]
	if pad.resource_type == resource_type:
		return
	if pad.cargo_loaded > 0.0 and (pad.status == GameState.PAD_LOADING or pad.status == GameState.PAD_FULL):
		state.amounts[pad.resource_type] = state.amounts.get(pad.resource_type, 0.0) + pad.cargo_loaded
		pad.cargo_loaded = 0.0
		pad.status = GameState.PAD_EMPTY
	pad.resource_type = resource_type


func _effect_load_pads(state: GameState, load_amount: int) -> void:
	var effective_load: int = _get_load_per_execution(state, load_amount)
	var active_count: int = state.buildings_active.get("launch_pad", state.buildings_owned.get("launch_pad", 0))
	for res: String in state.loading_priority:
		for i in range(mini(state.pads.size(), active_count)):
			var pad: GameState.LaunchPadData = state.pads[i]
			if pad.resource_type != res:
				continue
			if pad.status == GameState.PAD_FULL or pad.status == GameState.PAD_COOLDOWN or pad.status == GameState.PAD_LAUNCHING:
				continue
			var available: float = state.amounts.get(res, 0.0)
			var space: float = _pad_cargo_capacity - pad.cargo_loaded
			var to_load: float = minf(float(effective_load), minf(available, space))
			if to_load > 0.0:
				state.amounts[res] -= to_load
				pad.cargo_loaded += to_load
				if pad.cargo_loaded >= _pad_cargo_capacity:
					pad.cargo_loaded = _pad_cargo_capacity
					pad.status = GameState.PAD_FULL
				else:
					pad.status = GameState.PAD_LOADING
			return  # one execution = one pad


func _effect_launch_pads(state: GameState) -> void:
	var active_count: int = state.buildings_active.get("launch_pad", state.buildings_owned.get("launch_pad", 0))
	for i in range(mini(state.pads.size(), active_count)):
		var pad: GameState.LaunchPadData = state.pads[i]
		if pad.status != GameState.PAD_FULL:
			continue
		if state.amounts.get("prop", 0.0) < _launch_fuel_cost:
			continue
		state.amounts["prop"] -= _launch_fuel_cost
		var payout: float = _trade_values.get(pad.resource_type, 1.0) * _demand_baseline * pad.cargo_loaded
		state.amounts["cred"] = state.amounts.get("cred", 0.0) + payout
		_record_launch(state, pad, payout)
		pad.status = GameState.PAD_LAUNCHING


func _record_launch(state: GameState, pad: GameState.LaunchPadData, payout: float) -> void:
	var record := GameState.LaunchRecord.new()
	record.resource_type = pad.resource_type
	record.quantity = pad.cargo_loaded
	record.credits_earned = payout
	record.tick = state.current_day
	state.launch_history.push_front(record)
	if state.launch_history.size() > 5:
		state.launch_history.pop_back()
	state.total_shipments_completed += 1


func _clamp_processor_assignments(state: GameState) -> void:
	var total: int = state.total_processors
	var assigned: int = 0
	for p: GameState.ProgramData in state.programs:
		assigned += p.processors_assigned
	if assigned <= total:
		return
	var excess: int = assigned - total
	for i in range(state.programs.size() - 1, -1, -1):
		if excess <= 0:
			break
		var prog: GameState.ProgramData = state.programs[i]
		var remove: int = mini(prog.processors_assigned, excess)
		prog.processors_assigned -= remove
		excess -= remove


func _can_afford_command(state: GameState, short_name: String) -> bool:
	if not _commands_data.has(short_name):
		return false
	var cmd = _commands_data[short_name]
	var costs: Dictionary = _get_effective_costs(state, cmd)
	for res in costs:
		if state.amounts.get(res, 0.0) < float(costs[res]):
			return false
	return true


func _apply_command(state: GameState, short_name: String) -> void:
	if not _commands_data.has(short_name):
		return
	var cmd = _commands_data[short_name]
	var costs: Dictionary = _get_effective_costs(state, cmd)
	for res in costs:
		var cost: float = float(costs[res])
		state.amounts[res] = state.amounts.get(res, 0.0) - cost
		last_gross_deltas[res] = last_gross_deltas.get(res, 0.0) - cost
	for res in cmd.production:
		var delta: float = float(cmd.production[res])
		state.amounts[res] = state.amounts.get(res, 0.0) + delta
		last_gross_deltas[res] = last_gross_deltas.get(res, 0.0) + delta
		if delta > 0.0:
			state.cumulative_resources_earned[res] = state.cumulative_resources_earned.get(res, 0.0) + delta
	for effect in cmd.get("effects", []):
		match effect.get("effect", ""):
			"load_pads":
				_effect_load_pads(state, int(effect.get("value", 5)))
			"launch_full_pads":
				_effect_launch_pads(state)
			"boredom_add":
				state.amounts["boredom"] = state.amounts.get("boredom", 0.0) + float(effect.get("value", 0.0))


func _can_pay_upkeep(state: GameState, bdef: Dictionary, count: int) -> bool:
	for res in bdef.upkeep:
		if state.amounts.get(res, 0.0) < float(bdef.upkeep[res]) * count:
			return false
	return true


func can_purchase_research(state: GameState, research_id: String) -> bool:
	if state.completed_research.has(research_id):
		return false
	if not _research_data.has(research_id):
		return false
	var cost: float = float(_research_data[research_id].get("cost", 0))
	return state.amounts.get("sci", 0.0) >= cost


func purchase_research(state: GameState, research_id: String) -> void:
	var item: Dictionary = _research_data[research_id]
	state.amounts["sci"] = maxf(0.0, state.amounts.get("sci", 0.0) - float(item.get("cost", 0)))
	state.completed_research.append(research_id)


func _get_boredom_rate(day: int) -> float:
	var rate: float = 0.0
	for entry in _boredom_curve:
		if day >= entry[0]:
			rate = entry[1]
		else:
			break
	return rate


func _get_boredom_multiplier(state: GameState) -> float:
	var mult: float = 1.0
	for id: String in state.completed_research:
		if not _research_data.has(id):
			continue
		var effect: Dictionary = _research_data[id].get("effect", {})
		if effect.get("type", "") == "boredom_rate_multiplier":
			mult *= float(effect.get("value", 1.0))
	return mult


func _get_effective_costs(state: GameState, cmd: Dictionary) -> Dictionary:
	var costs: Dictionary = cmd.get("costs", {}).duplicate()
	for id: String in state.completed_research:
		if not _research_data.has(id):
			continue
		var effect: Dictionary = _research_data[id].get("effect", {})
		if effect.get("type", "") == "command_cost_override":
			if effect.get("command", "") == cmd.get("short_name", ""):
				costs[effect.get("resource", "")] = float(effect.get("value", 0))
	return costs


func _get_load_per_execution(state: GameState, default_load: int) -> int:
	for id: String in state.completed_research:
		if not _research_data.has(id):
			continue
		var effect: Dictionary = _research_data[id].get("effect", {})
		if effect.get("type", "") == "load_per_execution":
			return int(effect.get("value", default_load))
	return default_load


func _clamp(state: GameState) -> void:
	for res in state.amounts.keys():
		var cap: float = state.caps.get(res, INF)
		state.amounts[res] = clampf(state.amounts.get(res, 0.0), 0.0, cap)


func _get_bdef(short_name: String) -> Variant:
	for bdef in _buildings_data:
		if bdef.short_name == short_name:
			return bdef
	return null
