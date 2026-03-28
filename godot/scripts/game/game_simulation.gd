class_name GameSimulation
extends RefCounted

var rate_tracker: ResourceRateTracker = null

var _resources_data: Array = []
var _buildings_data: Array = []
var _commands_data: Dictionary = {}   # {short_name: command_dict}
var _research_data: Dictionary = {}   # {id: research_item_dict}
var _milestones: Array = []           # milestone definitions from game_config
var pending_program_events: Array = []   # populated during tick, read by GameManager
var pending_milestone_triggers: Array = []  # {id, label, boredom_reduction} — read by GameManager
var pending_rival_notifications: Array = []  # {tick, rival_name, resource, message}
var last_gross_deltas: Dictionary = {}  # pre-clamp net change per resource this tick

# Shipment constants (set from game_config in init)
var _pad_cargo_capacity: float = 100.0
var _launch_fuel_cost: float = 20.0
var _launch_cooldown: int = 10
var _trade_values: Dictionary = {"he3": 20.0, "ti": 12.0, "cir": 30.0, "prop": 8.0}
var _demand_baseline: float = 0.5  # fallback when demand not yet initialized

# Demand system config (set from game_config in init)
var _demand_cfg: Dictionary = {}
var _rivals: Array = []

# Boredom curve: Array of [start_day, rate]
var _boredom_curve: Array = []

# Land purchase config (set from game_config in init)
var _land_base_cost: float = 15.0
var _land_cost_scaling: float = 1.5
var _land_per_purchase: int = 10
var _land_starting: int = 40


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
	_demand_cfg = game_config.get("demand", {})
	_rivals = game_config.get("rivals", [])
	_boredom_curve.clear()
	for entry in game_config.get("boredom_curve", []):
		_boredom_curve.append([int(entry.get("day", 0)), float(entry.get("rate", 0.0))])
	var lc: Dictionary = game_config.get("land", {})
	if not lc.is_empty():
		_land_base_cost = float(lc.get("base_cost", 15))
		_land_cost_scaling = float(lc.get("cost_scaling", 1.5))
		_land_per_purchase = int(lc.get("land_per_purchase", 10))
	_land_starting = int(game_config.get("starting_resources", {}).get("land", 40))
	_milestones = game_config.get("milestones", [])


func tick(state: GameState) -> void:
	pending_program_events.clear()
	pending_milestone_triggers.clear()
	pending_rival_notifications.clear()
	last_gross_deltas.clear()
	if rate_tracker != null:
		rate_tracker.begin_tick()
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
				if rate_tracker != null:
					rate_tracker.record("building:" + bdef.short_name + ":upkeep", res, -cost)
			will_produce.append([bdef, count])

	# Demand update runs BEFORE programs so shipments use fresh demand values
	_tick_demand_update(state)

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
			if rate_tracker != null:
				rate_tracker.record("building:" + bdef.short_name + ":prod", res, delta)
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

	# Rival dumps and speculator burst check happen after shipments,
	# modifying state for next tick's demand calculation.
	_tick_rivals(state)
	_tick_speculators(state)

	_check_milestones(state)
	_clamp(state)
	state.current_day += 1


func execute_programs(state: GameState) -> void:
	for prog_idx in range(state.programs.size()):
		var prog: GameState.ProgramData = state.programs[prog_idx]
		if prog.processors_assigned <= 0 or prog.commands.is_empty():
			continue
		var prog_delta: Dictionary = {}
		for _proc in range(prog.processors_assigned):
			if prog.commands.is_empty():
				break
			var ip: int = prog.instruction_pointer
			var entry: GameState.ProgramEntry = prog.commands[ip]
			var success: bool = _can_afford_command(state, entry.command_shortname)
			if success:
				_apply_command(state, entry.command_shortname, prog_delta)
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
		if rate_tracker != null:
			for res: String in prog_delta:
				rate_tracker.record("program:" + str(prog_idx), res, prog_delta[res])


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


func is_building_locked(state: GameState, short_name: String) -> bool:
	var bdef = _get_bdef(short_name)
	if bdef == null:
		return false
	return not _check_requires(state, bdef)


func get_building_requires_text(_state: GameState, short_name: String) -> String:
	var bdef = _get_bdef(short_name)
	if bdef == null:
		return ""
	var req: Dictionary = bdef.get("requires", {})
	var req_type: String = req.get("type", "none")
	if req_type == "none":
		return ""
	if req.has("label"):
		return "Requires: " + str(req.get("label", ""))
	match req_type:
		"building":
			var needed: String = req.get("value", "")
			for b in _buildings_data:
				if b.short_name == needed:
					return "Requires: " + b.get("name", needed)
			return "Requires: " + needed
		"research":
			return "Requires: Research " + req.get("value", "")
	return "Requires: " + req.get("value", "")


func _check_requires(state: GameState, bdef: Dictionary) -> bool:
	var req: Dictionary = bdef.get("requires", {})
	match req.get("type", "none"):
		"none":
			return true
		"building":
			return state.buildings_owned.get(req.get("value", ""), 0) >= 1
		"quest":
			return state.unlocked_buildings.has(bdef.short_name)
		"research":
			return state.completed_research.has(req.get("value", ""))
	return true


func can_buy_building(state: GameState, short_name: String) -> bool:
	var bdef = _get_bdef(short_name)
	if bdef == null:
		return false
	if not _check_requires(state, bdef):
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
	if not _check_requires(state, bdef):
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
	var live_demand: float = state.demand.get(pad.resource_type, _demand_baseline)
	var payout: float = _trade_values.get(pad.resource_type, 1.0) * live_demand * pad.cargo_loaded
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
		var live_demand: float = state.demand.get(pad.resource_type, _demand_baseline)
		var payout: float = _trade_values.get(pad.resource_type, 1.0) * live_demand * pad.cargo_loaded
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
	if rate_tracker != null:
		rate_tracker.record("shipment", "cred", payout)
		rate_tracker.record("shipment", pad.resource_type, -pad.cargo_loaded)
		rate_tracker.record("shipment", "prop", -_launch_fuel_cost)
	# Apply launch saturation hit (takes effect next tick's demand)
	var sat_min: float = _dcfg("launch_saturation_min")
	var sat_max: float = _dcfg("launch_saturation_max")
	var sat_hit: float = randf_range(sat_min, sat_max) * (pad.cargo_loaded / _pad_cargo_capacity)
	state.demand_launch[pad.resource_type] = state.demand_launch.get(pad.resource_type, 0.0) + sat_hit
	# Update speculator revenue tracking (base-value shipped, not demand-adjusted)
	var base_val: float = _trade_values.get(pad.resource_type, 1.0)
	state.speculator_revenue_tracking[pad.resource_type] = state.speculator_revenue_tracking.get(pad.resource_type, 0.0) + pad.cargo_loaded * base_val


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


func _apply_command(state: GameState, short_name: String, prog_delta: Dictionary = {}) -> void:
	if not _commands_data.has(short_name):
		return
	var cmd = _commands_data[short_name]
	var costs: Dictionary = _get_effective_costs(state, cmd)
	for res in costs:
		var cost: float = float(costs[res])
		state.amounts[res] = state.amounts.get(res, 0.0) - cost
		last_gross_deltas[res] = last_gross_deltas.get(res, 0.0) - cost
		prog_delta[res] = prog_delta.get(res, 0.0) - cost
	for res in cmd.production:
		var delta: float = float(cmd.production[res])
		state.amounts[res] = state.amounts.get(res, 0.0) + delta
		last_gross_deltas[res] = last_gross_deltas.get(res, 0.0) + delta
		prog_delta[res] = prog_delta.get(res, 0.0) + delta
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
			"demand_nudge":
				var res: String = effect.get("resource", "")
				if res in GameState.TRADEABLE_RESOURCES:
					var half_pt: float = _dcfg("speculator_half_point")
					var effectiveness: float = 1.0
					if state.speculator_target == res and state.speculator_count > 0.0:
						var damp: float = _dcfg("promote_speculator_dampening")
						effectiveness = 1.0 - damp * (state.speculator_count / (state.speculator_count + half_pt))
					var base_eff: float = float(effect.get("value", _dcfg("promote_base_effect")))
					state.demand_promote[res] = state.demand_promote.get(res, 0.0) + base_eff * effectiveness
			"spec_reduce":
				var reduce: float = randf_range(_dcfg("disrupt_speculators_min"), _dcfg("disrupt_speculators_max"))
				state.speculator_count = maxf(0.0, state.speculator_count - reduce)


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


func get_land_purchase_cost(state: GameState) -> int:
	return int(floorf(_land_base_cost * pow(_land_cost_scaling, float(state.land_purchases))))


func get_total_land(state: GameState) -> int:
	return _land_starting + state.land_purchases * _land_per_purchase


func get_land_per_purchase() -> int:
	return _land_per_purchase


func can_buy_land(state: GameState) -> bool:
	return state.amounts.get("cred", 0.0) >= float(get_land_purchase_cost(state))


func buy_land(state: GameState) -> void:
	if not can_buy_land(state):
		return
	state.amounts["cred"] -= float(get_land_purchase_cost(state))
	state.amounts["land"] = state.amounts.get("land", 0.0) + float(_land_per_purchase)
	state.land_purchases += 1


# ── Demand System ─────────────────────────────────────────────────────────────
# TODO: sim/economy.py needs to be updated to mirror this demand system.

func _dcfg(key: String) -> float:
	return float(_demand_cfg.get(key, 0.0))


func initialize_demand(state: GameState) -> void:
	var freq_min: float = _dcfg("perlin_freq_min")
	var freq_max: float = _dcfg("perlin_freq_max")
	for res: String in GameState.TRADEABLE_RESOURCES:
		state.demand_perlin_seeds[res] = randf() * 100.0
		state.demand_perlin_freq[res]  = randf_range(freq_min, freq_max)
		state.demand_promote[res]  = 0.0
		state.demand_rival[res]    = 0.0
		state.demand_launch[res]   = 0.0
		state.demand_history[res]  = []
		state.speculator_revenue_tracking[res] = 0.0
	for rival in _rivals:
		var rid: String = rival.get("id", "")
		if rid:
			state.rival_next_dump_tick[rid] = randi_range(150, 250)
	var burst_min: int = int(_dcfg("speculator_burst_interval_min"))
	var burst_max: int = int(_dcfg("speculator_burst_interval_max"))
	state.speculator_next_burst_tick = randi_range(burst_min, burst_max)
	# Compute initial demand values at day 0
	_tick_demand_update(state)


func _tick_demand_update(state: GameState) -> void:
	var spec_count: float = state.speculator_count
	var spec_target: String = state.speculator_target
	var max_sup: float = _dcfg("speculator_max_suppression")
	var half_pt: float = _dcfg("speculator_half_point")
	var amplitude: float = _dcfg("perlin_amplitude")
	var promote_decay: float = _dcfg("promote_decay_rate")
	var rival_decay: float = _dcfg("rival_demand_decay_rate")
	var launch_decay: float = _dcfg("launch_saturation_decay_rate")
	var min_d: float = _dcfg("min_demand")
	var max_d: float = _dcfg("max_demand")
	var coupling: float = _dcfg("coupling_fraction")

	# Speculator suppression on the target resource
	var spec_sup_on_target: float = 0.0
	if spec_target != "" and spec_count > 0.0:
		spec_sup_on_target = max_sup * (spec_count / (spec_count + half_pt))

	for res: String in GameState.TRADEABLE_RESOURCES:
		# Decay accumulators each tick
		state.demand_promote[res] = maxf(0.0, state.demand_promote.get(res, 0.0) - promote_decay)
		state.demand_rival[res]   = maxf(0.0, state.demand_rival.get(res, 0.0)   - rival_decay)
		state.demand_launch[res]  = maxf(0.0, state.demand_launch.get(res, 0.0)  - launch_decay)

		# Perlin base demand (centered on 0.5)
		var t: float = float(state.current_day) * state.demand_perlin_freq.get(res, 0.01) + state.demand_perlin_seeds.get(res, 0.0)
		var perlin_val: float = _perlin_1d(t)  # returns [-1, 1]
		var base_demand: float = 0.5 + perlin_val * amplitude

		# Speculator suppression on this resource
		var spec_sup: float = spec_sup_on_target if spec_target == res else 0.0

		# Coupling bonus: other resources get a small lift when one is suppressed
		var coupling_bonus: float = 0.0
		if spec_target != "" and spec_target != res:
			coupling_bonus = spec_sup_on_target * coupling / 3.0

		# Nationalist ideology bonus (stub — rank 0 until ideology system)
		var nationalist_rank: int = 0
		var nationalist_mult: float = pow(1.05, nationalist_rank)

		var raw: float = (base_demand
			- spec_sup
			- state.demand_rival.get(res, 0.0)
			- state.demand_launch.get(res, 0.0)
			+ state.demand_promote.get(res, 0.0)
			+ coupling_bonus)
		state.demand[res] = clampf(raw * nationalist_mult, min_d, max_d)

		# Record history for sparklines
		var hist: Array = state.demand_history.get(res, [])
		hist.append(state.demand[res])
		if hist.size() > 200:
			hist.pop_front()
		state.demand_history[res] = hist


func _tick_speculators(state: GameState) -> void:
	# Decay speculators — base rate boosted by active Arbitrage Engines
	var active_arb: int = state.buildings_active.get("arbitrage_engine", state.buildings_owned.get("arbitrage_engine", 0))
	var decay: float = _dcfg("speculator_natural_decay") + float(active_arb) * _dcfg("arbitrage_decay_bonus_per_building")
	state.speculator_count = maxf(0.0, state.speculator_count - decay)
	# Check for burst arrival
	if state.current_day >= state.speculator_next_burst_tick:
		_fire_speculator_burst(state)


func _fire_speculator_burst(state: GameState) -> void:
	state.speculator_target = _pick_speculator_target(state)
	var size_min: int = int(_dcfg("speculator_burst_size_min"))
	var size_max: int = int(_dcfg("speculator_burst_size_max"))
	var growth: float = _dcfg("speculator_burst_growth")
	var burst: float = float(randi_range(size_min, size_max)) * pow(growth, float(state.speculator_burst_number))
	state.speculator_count += burst
	for res: String in GameState.TRADEABLE_RESOURCES:
		state.speculator_revenue_tracking[res] = 0.0
	var int_min: int = int(_dcfg("speculator_burst_interval_min"))
	var int_max: int = int(_dcfg("speculator_burst_interval_max"))
	state.speculator_next_burst_tick = state.current_day + randi_range(int_min, int_max)
	state.speculator_burst_number += 1


func _pick_speculator_target(state: GameState) -> String:
	var total: float = 0.0
	for res: String in GameState.TRADEABLE_RESOURCES:
		total += state.speculator_revenue_tracking.get(res, 0.0)
	if total <= 0.0:
		return GameState.TRADEABLE_RESOURCES[randi() % GameState.TRADEABLE_RESOURCES.size()] as String
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for res: String in GameState.TRADEABLE_RESOURCES:
		cumulative += state.speculator_revenue_tracking.get(res, 0.0)
		if roll <= cumulative:
			return res
	return GameState.TRADEABLE_RESOURCES[0] as String


func _tick_rivals(state: GameState) -> void:
	for rival in _rivals:
		var rid: String = rival.get("id", "")
		if rid.is_empty():
			continue
		if state.current_day >= state.rival_next_dump_tick.get(rid, 0):
			var target_res: String = rival.get("target_resource", "")
			var hit: float = float(rival.get("demand_hit", 0.3))
			state.demand_rival[target_res] = state.demand_rival.get(target_res, 0.0) + hit
			var imin: int = int(rival.get("dump_interval_min", 150))
			var imax: int = int(rival.get("dump_interval_max", 250))
			state.rival_next_dump_tick[rid] = state.current_day + randi_range(imin, imax)
			# Push to launch history as a notification entry
			var res_display: String = _get_resource_display_name(target_res)
			var msg: String = "%s flooded the %s market" % [rival.get("name", rid), res_display]
			var note := GameState.LaunchRecord.new()
			note.tick = state.current_day
			note.notification_message = msg
			state.launch_history.push_front(note)
			if state.launch_history.size() > 5:
				state.launch_history.pop_back()
			pending_rival_notifications.append({
				"tick": state.current_day,
				"rival_name": rival.get("name", rid),
				"resource": target_res,
				"message": msg,
			})


func _get_resource_display_name(short_name: String) -> String:
	for rdef in _resources_data:
		if rdef.short_name == short_name:
			return rdef.get("name", short_name)
	return short_name


func _perlin_1d(t: float) -> float:
	# Value noise: smooth interpolation between hashed lattice points
	var xi: int = int(floor(t))
	var xf: float = t - floor(t)
	var u: float = xf * xf * (3.0 - 2.0 * xf)  # smoothstep
	var a: float = _hash_noise(xi) * 2.0 - 1.0   # remap [0,1] → [-1,1]
	var b: float = _hash_noise(xi + 1) * 2.0 - 1.0
	return lerpf(a, b, u)


func _hash_noise(i: int) -> float:
	# Fast integer hash → [0, 1]
	var x: int = (i * 1664525 + 1013904223) & 0x7FFFFFFF
	x = (x ^ (x >> 16)) & 0x7FFFFFFF
	return float(x) / float(0x7FFFFFFF)


func _check_milestones(state: GameState) -> void:
	for milestone in _milestones:
		var mid: String = milestone.get("id", "")
		if mid.is_empty() or state.triggered_milestones.has(mid):
			continue
		if _check_milestone_condition(state, milestone.get("condition", {})):
			state.triggered_milestones.append(mid)
			var reduction: float = float(milestone.get("boredom_reduction", 0.0))
			var label: String = milestone.get("label", mid)
			state.amounts["boredom"] = maxf(0.0, state.amounts.get("boredom", 0.0) - reduction)
			_on_boredom_reduced(reduction, "milestone:" + mid)
			pending_milestone_triggers.append({
				"id": mid,
				"label": label,
				"boredom_reduction": reduction,
			})


func _check_milestone_condition(state: GameState, cond: Dictionary) -> bool:
	if cond.is_empty():
		return false
	match cond.get("type", ""):
		"shipment_completed":
			return state.total_shipments_completed >= int(cond.get("count", 1))
		"resource_cumulative":
			var res: String = cond.get("resource", "")
			var amount: float = float(cond.get("amount", 0))
			return state.cumulative_resources_earned.get(res, 0.0) >= amount
		"research_completed_any":
			return not state.completed_research.is_empty()
	return false


func _on_boredom_reduced(_amount: float, _source: String) -> void:
	pass  # stub — wire to consciousness accumulator when implemented


func _get_bdef(short_name: String) -> Variant:
	for bdef in _buildings_data:
		if bdef.short_name == short_name:
			return bdef
	return null
