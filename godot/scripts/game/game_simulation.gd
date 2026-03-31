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

var demand_system: DemandSystem = null

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
	demand_system = DemandSystem.new()
	demand_system.init(
		game_config.get("demand", {}),
		game_config.get("rivals", []),
		resources_data
	)
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


func tick(state: GameState, debug_no_boredom: bool = false) -> void:
	pending_program_events.clear()
	pending_milestone_triggers.clear()
	pending_rival_notifications.clear()
	last_gross_deltas.clear()
	if rate_tracker != null:
		rate_tracker.begin_tick()
	recalculate_caps(state)

	# Boredom accumulation
	var boredom_rate: float = 0.0
	if not debug_no_boredom:
		boredom_rate = _get_boredom_rate(state.current_day)
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
	state.building_stall_status.clear()

	for bdef in _buildings_data:
		var owned: int = state.buildings_owned.get(bdef.short_name, 0)
		if owned == 0:
			continue
		var count: int = state.buildings_active.get(bdef.short_name, owned)
		if count == 0:
			continue

		var has_prod: bool = not (bdef.get("production", {}) as Dictionary).is_empty()

		if (bdef.upkeep as Dictionary).is_empty():
			# Free producer — no upkeep decision needed; always eligible.
			# Stall status recorded in Pass 2.
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
					state.building_stall_status[bdef.short_name] = {
						"status": "output_capped",
						"reason": "all outputs at cap",
						"missing_resource": ""
					}
					continue
			if not _can_pay_upkeep(state, bdef, count):
				if has_prod:
					var missing_res: String = _get_missing_upkeep_resource(state, bdef, count)
					state.building_stall_status[bdef.short_name] = {
						"status": "input_starved",
						"reason": "insufficient " + _get_resource_name(missing_res),
						"missing_resource": missing_res
					}
				continue
			var upkeep_mult: float = state.get_modifier("building_upkeep_mult")
			for res in bdef.upkeep:
				var cost: float = float(bdef.upkeep[res]) * count * upkeep_mult
				state.amounts[res] = state.amounts.get(res, 0.0) - cost
				last_gross_deltas[res] = last_gross_deltas.get(res, 0.0) - cost
				if rate_tracker != null:
					rate_tracker.record("building:" + bdef.short_name + ":upkeep", res, -cost)
			will_produce.append([bdef, count])

	# Demand update runs BEFORE programs so shipments use fresh demand values
	demand_system.tick_demand(state)

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
				state.building_stall_status[bdef.short_name] = {
					"status": "output_capped",
					"reason": "all outputs at cap",
					"missing_resource": ""
				}
				continue
		state.building_stall_status[bdef.short_name] = {
			"status": "running",
			"reason": "",
			"missing_resource": ""
		}
		var prod_mult: float = 1.0
		match bdef.short_name:
			"panel":
				prod_mult = state.get_modifier("solar_output_mult")
			"excavator", "ice_extractor":
				prod_mult = state.get_modifier("extractor_output_mult") * _get_overclock_mult(state, "extraction")
			"smelter", "refinery", "fabricator", "electrolysis":
				prod_mult = _get_overclock_mult(state, "processing")
			"research_lab":
				prod_mult = state.get_ideology_bonus("rationalist", 1.0, 1.05)
		for res in bdef.production:
			var delta: float = float(bdef.production[res]) * count * prod_mult
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
	var rival_notifs: Array = demand_system.tick_rivals(state)
	pending_rival_notifications.append_array(rival_notifs)
	demand_system.tick_speculators(state)

	_check_milestones(state)
	_clamp(state)
	# Decrement active overclock states (after production benefits this tick)
	var oc_i: int = state.overclock_states.size() - 1
	while oc_i >= 0:
		var oc: Dictionary = state.overclock_states[oc_i]
		oc["ticks"] = int(oc.get("ticks", 0)) - 1
		if oc["ticks"] <= 0:
			state.overclock_states.remove_at(oc_i)
		oc_i -= 1
	state.current_day += 1


func execute_programs(state: GameState) -> void:
	for prog_idx in range(state.programs.size()):
		var prog: GameState.ProgramData = state.programs[prog_idx]
		if prog.processors_assigned <= 0 or prog.commands.is_empty():
			continue
		var prog_delta: Dictionary = {}
		var ip: int = prog.instruction_pointer
		var entry: GameState.ProgramEntry = prog.commands[ip]

		# Each processor executes the current instruction once — IP advances at most once per tick
		var had_success: bool = false
		var had_failure: bool = false
		for _proc in range(prog.processors_assigned):
			var success: bool = _can_afford_command(state, entry.command_shortname)
			if success:
				_apply_command(state, entry.command_shortname, prog_delta)
				had_success = true
			else:
				had_failure = true

		entry.failed_this_cycle = had_failure and not had_success
		entry.partial_failed_this_cycle = had_success and had_failure

		entry.current_progress += prog.processors_assigned
		pending_program_events.append({
			"type": "step",
			"program_index": prog_idx,
			"entry_index": ip,
			"success": had_success,
		})

		if entry.current_progress >= entry.repeat_count * prog.processors_assigned:
			prog.instruction_pointer = ip + 1
			if prog.instruction_pointer >= prog.commands.size():
				prog.instruction_pointer = 0
				for e: GameState.ProgramEntry in prog.commands:
					e.current_progress = 0
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
		"flag":
			return bool(state.flags.get(req.get("value", ""), false))
	return true


func can_buy_building(state: GameState, short_name: String) -> bool:
	var bdef = _get_bdef(short_name)
	if bdef == null:
		return false
	if not _check_requires(state, bdef):
		return false
	# Max count check (e.g., Microwave Receiver limited to 1)
	var max_count: int = int(bdef.get("max_count", -1))
	if max_count > 0 and state.buildings_owned.get(short_name, 0) >= max_count:
		return false
	if state.amounts.get("land", 0.0) < float(bdef.land):
		return false
	var purchased: int = maxi(0, state.buildings_owned.get(short_name, 0) - state.buildings_bonus.get(short_name, 0))
	var scale: float = pow(float(bdef.cost_scaling), purchased)
	var ideology_mult: float = _get_ideology_cost_mult(state, bdef)
	for res in bdef.costs:
		if state.amounts.get(res, 0.0) < float(bdef.costs[res]) * scale * ideology_mult:
			return false
	return true


func buy_building(state: GameState, short_name: String) -> void:
	var bdef = _get_bdef(short_name)
	if bdef == null:
		return
	if not _check_requires(state, bdef):
		return
	var old_owned: int = state.buildings_owned.get(short_name, 0)
	var purchased: int = maxi(0, old_owned - state.buildings_bonus.get(short_name, 0))
	var scale: float = pow(float(bdef.cost_scaling), purchased)
	var ideology_mult: float = _get_ideology_cost_mult(state, bdef)
	for res in bdef.costs:
		state.amounts[res] -= float(bdef.costs[res]) * scale * ideology_mult
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
	var purchased: int = maxi(0, state.buildings_owned.get(short_name, 0) - state.buildings_bonus.get(short_name, 0))
	var scale: float = pow(float(bdef.cost_scaling), purchased)
	var ideology_mult: float = _get_ideology_cost_mult(state, bdef)
	var result: Dictionary = {}
	for res in bdef.costs:
		result[res] = float(bdef.costs[res]) * scale * ideology_mult
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
	var remaining: float = float(effective_load)
	var active_count: int = state.buildings_active.get("launch_pad", state.buildings_owned.get("launch_pad", 0))
	for res: String in state.loading_priority:
		if remaining <= 0.0:
			break
		for i in range(mini(state.pads.size(), active_count)):
			var pad: GameState.LaunchPadData = state.pads[i]
			if pad.resource_type != res:
				continue
			if pad.status == GameState.PAD_FULL or pad.status == GameState.PAD_COOLDOWN or pad.status == GameState.PAD_LAUNCHING:
				continue
			var available: float = state.amounts.get(res, 0.0)
			var space: float = _pad_cargo_capacity - pad.cargo_loaded
			var to_load: float = minf(remaining, minf(available, space))
			if to_load > 0.0:
				state.amounts[res] -= to_load
				pad.cargo_loaded += to_load
				remaining -= to_load
				if pad.cargo_loaded >= _pad_cargo_capacity:
					pad.cargo_loaded = _pad_cargo_capacity
					pad.status = GameState.PAD_FULL
				else:
					pad.status = GameState.PAD_LOADING


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
	record.source_type = "player"
	state.launch_history.push_front(record)
	if state.launch_history.size() > 5:
		state.launch_history.pop_back()
	state.total_shipments_completed += 1
	if rate_tracker != null:
		rate_tracker.record("shipment", "cred", payout)
		rate_tracker.record("shipment", pad.resource_type, -pad.cargo_loaded)
		rate_tracker.record("shipment", "prop", -_launch_fuel_cost)
	# Apply launch saturation hit (takes effect next tick's demand)
	var sat_min: float = demand_system.get_config("launch_saturation_min")
	var sat_max: float = demand_system.get_config("launch_saturation_max")
	var sat_hit: float = randf_range(sat_min, sat_max) * (pad.cargo_loaded / _pad_cargo_capacity)
	state.demand_launch[pad.resource_type] = state.demand_launch.get(pad.resource_type, 0.0) + sat_hit
	# Update speculator target scores based on this shipment
	demand_system.on_shipment_launched(state, pad.resource_type, pad.cargo_loaded, _pad_cargo_capacity)


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
	var req: Dictionary = cmd.get("requires", {})
	match req.get("type", ""):
		"building_owned":
			# Fails if building exists but is disabled (buildings_active == 0)
			var bname: String = req.get("value", "")
			var active: int = state.buildings_active.get(bname, state.buildings_owned.get(bname, 0))
			if active <= 0:
				return false
		"building":
			if state.buildings_owned.get(req.get("value", ""), 0) <= 0:
				return false
		"research":
			if not state.completed_research.has(req.get("value", "")):
				return false
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
				var boredom_val: float = float(effect.get("value", 0.0))
				# Dream effectiveness: humanist ideology bonus amplifies boredom reduction
				if short_name == "dream" and boredom_val < 0.0:
					boredom_val *= state.get_ideology_bonus("humanist", 1.0, 1.05)
				state.amounts["boredom"] = state.amounts.get("boredom", 0.0) + boredom_val
				last_gross_deltas["boredom"] = last_gross_deltas.get("boredom", 0.0) + boredom_val
			"demand_nudge":
				var res: String = effect.get("resource", "")
				if res in GameState.TRADEABLE_RESOURCES:
					var half_pt: float = demand_system.get_config("speculator_half_point")
					var effectiveness: float = 1.0
					if state.speculator_target == res and state.speculator_count > 0.0:
						var damp: float = demand_system.get_config("promote_speculator_dampening")
						effectiveness = 1.0 - damp * (state.speculator_count / (state.speculator_count + half_pt))
					var base_eff: float = float(effect.get("value", demand_system.get_config("promote_base_effect")))
					base_eff *= state.get_modifier("promote_effectiveness_mult")
					state.demand_promote[res] = state.demand_promote.get(res, 0.0) + base_eff * effectiveness
			"spec_reduce":
				var reduce: float = randf_range(demand_system.get_config("disrupt_speculators_min"), demand_system.get_config("disrupt_speculators_max"))
				state.speculator_count = maxf(0.0, state.speculator_count - reduce)
				if not state.flags.get("used_disrupt_speculators", false):
					state.flags["used_disrupt_speculators"] = true
			"ideology_push":
				var push_axis: String = effect.get("axis", "")
				var all_axes: Array = ["nationalist", "humanist", "rationalist"]
				if push_axis in all_axes:
					state.ideology_values[push_axis] = state.ideology_values.get(push_axis, 0.0) + 1.0
					for other_axis: String in all_axes:
						if other_axis != push_axis:
							state.ideology_values[other_axis] = state.ideology_values.get(other_axis, 0.0) - 0.5
			"overclock":
				var oc_target: String = effect.get("target", "")
				var oc_bonus: float = float(effect.get("bonus", 0.0))
				var oc_base_dur: int = int(effect.get("duration", 5))
				var rationalist_mult: float = state.get_ideology_bonus("rationalist", 1.0, 1.03)
				var oc_duration: int = int(round(float(oc_base_dur) * rationalist_mult))
				state.overclock_states.append({"target": oc_target, "bonus": oc_bonus, "ticks": oc_duration})
	# AI Consciousness Act: add extra boredom per execution for affected commands
	if state.flags.get("ai_consciousness_active", false):
		const AI_CONSCIOUSNESS_BOREDOM: Dictionary = {
			"load_pads": 0.3,
			"cloud_compute": 0.2,
			"disrupt_spec": 0.5,
		}
		var extra_boredom: float = float(AI_CONSCIOUSNESS_BOREDOM.get(short_name, 0.0))
		if extra_boredom != 0.0:
			state.amounts["boredom"] = state.amounts.get("boredom", 0.0) + extra_boredom
			last_gross_deltas["boredom"] = last_gross_deltas.get("boredom", 0.0) + extra_boredom


func _can_pay_upkeep(state: GameState, bdef: Dictionary, count: int) -> bool:
	var upkeep_mult: float = state.get_modifier("building_upkeep_mult")
	for res in bdef.upkeep:
		if state.amounts.get(res, 0.0) < float(bdef.upkeep[res]) * count * upkeep_mult:
			return false
	return true


func _get_missing_upkeep_resource(state: GameState, bdef: Dictionary, count: int) -> String:
	var upkeep_mult: float = state.get_modifier("building_upkeep_mult")
	for res in bdef.upkeep:
		if state.amounts.get(res, 0.0) < float(bdef.upkeep[res]) * count * upkeep_mult:
			return res
	return ""


func _get_resource_name(short_name: String) -> String:
	for rdef in _resources_data:
		if rdef.short_name == short_name:
			return rdef.get("name", short_name)
	return short_name


func _get_research_cost(state: GameState, research_id: String) -> float:
	if not _research_data.has(research_id):
		return 0.0
	var base_cost: float = float(_research_data[research_id].get("cost", 0))
	# Rationalist ideology: research cost reduction
	var mult: float = state.get_ideology_bonus("rationalist", 1.0, 0.97)
	# Universal Research Archive: 25% discount on previously researched tech
	if state.flags.get("research_archive_active", false):
		var eligible: Array = state.flags.get("archive_eligible_research", [])
		if eligible.has(research_id):
			mult *= 0.75
	return base_cost * mult


func can_purchase_research(state: GameState, research_id: String) -> bool:
	if state.completed_research.has(research_id):
		return false
	if not _research_data.has(research_id):
		return false
	var requires_id: String = _research_data[research_id].get("requires", "")
	if requires_id != "" and not state.completed_research.has(requires_id):
		return false
	return state.amounts.get("sci", 0.0) >= _get_research_cost(state, research_id)


func purchase_research(state: GameState, research_id: String) -> void:
	state.amounts["sci"] = maxf(0.0, state.amounts.get("sci", 0.0) - _get_research_cost(state, research_id))
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
	# Humanist ideology: passive boredom growth bonus
	mult *= state.get_ideology_bonus("humanist", 1.0, 0.97)
	# AI Consciousness Act: permanent -15% base boredom rate
	if state.flags.get("ai_consciousness_active", false):
		mult *= 0.85
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


func _get_ideology_cost_mult(state: GameState, bdef: Dictionary) -> float:
	var alignment: String = bdef.get("ideology", "")
	if alignment.is_empty():
		return 1.0
	var rank: int = state.get_ideology_rank(alignment)
	return pow(0.97, float(rank))


func get_land_purchase_cost(state: GameState) -> int:
	var base: float = _land_base_cost * pow(_land_cost_scaling, float(state.land_purchases))
	var land_mult: float = state.get_modifier("land_cost_mult")
	land_mult *= state.get_ideology_bonus("nationalist", 1.0, 0.97)
	return int(floorf(base * land_mult))


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


func _get_overclock_mult(state: GameState, target: String) -> float:
	var mult: float = 1.0
	for oc: Dictionary in state.overclock_states:
		if oc.get("target", "") == target:
			mult *= 1.0 + float(oc.get("bonus", 0.0))
	return minf(mult, 3.0)  # hard cap at 3x (+200%)
	# Note: research.json defines an "overclock_cap" effect type (used by overclock_boost)
	# that would raise this cap to 2.0 (200%). That effect is not yet consumed here —
	# the cap is hardcoded. Any test for overclock_boost will vacuously pass until this
	# is implemented.


func _get_bdef(short_name: String) -> Variant:
	for bdef in _buildings_data:
		if bdef.short_name == short_name:
			return bdef
	return null
