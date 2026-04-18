class_name GameSimulation
extends RefCounted

const RESOURCE_EPSILON: float = 0.001

var rate_tracker: ResourceRateTracker = null

var _resources_data: Array = []
var _buildings_data: Array = []
var _buildings_map: Dictionary = {}   # {short_name: bdef}
var _resource_names: Dictionary = {}  # {short_name: display_name}
var _commands_data: Dictionary = {}   # {short_name: command_dict}
var _research_data: Dictionary = {}   # {id: research_item_dict}
var pending_program_events: Array = []   # populated during tick, read by GameManager
var pending_rival_notifications: Array = []  # {tick, rival_name, resource, message}
var pending_executed_commands: Array[String] = []  # short_names of successfully executed commands this tick
var pending_shipments: Array = []  # {resource: String, revenue: float, demand: float} — read by GameManager
var last_gross_deltas: Dictionary = {}  # pre-clamp net change per resource this tick

# Per-tick production/consumption totals (gross, reset each tick, read by AchievementManager)
var tick_produced: Dictionary = {}  # resource → float (gross amount produced by buildings this tick)
var tick_consumed: Dictionary = {}  # resource → float (gross amount consumed by buildings + programs this tick)

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

# Milestones (loaded from game_config)
var _milestones: Array = []


func init(resources_data: Array, buildings_data: Array, commands_data: Array, game_config: Dictionary = {}, research_data: Array = []) -> void:
	_resources_data = resources_data
	_buildings_data = buildings_data
	_buildings_map = {}
	for bdef in _buildings_data:
		_buildings_map[bdef.short_name] = bdef
	_resource_names = {}
	for rdef in _resources_data:
		_resource_names[rdef.short_name] = rdef.get("name", rdef.short_name)
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
	_milestones = game_config.get("milestones", [])
	var lc: Dictionary = game_config.get("land", {})
	if not lc.is_empty():
		_land_base_cost = float(lc.get("base_cost", 15))
		_land_cost_scaling = float(lc.get("cost_scaling", 1.5))
		_land_per_purchase = int(lc.get("land_per_purchase", 10))
	_land_starting = int(game_config.get("starting_resources", {}).get("land", 40))


func tick(state: GameState, debug_no_boredom: bool = false) -> void:
	pending_program_events.clear()
	pending_rival_notifications.clear()
	pending_executed_commands.clear()
	pending_shipments.clear()
	last_gross_deltas.clear()
	tick_produced.clear()
	tick_consumed.clear()
	if rate_tracker != null:
		rate_tracker.begin_tick()
	recalculate_caps(state)

	_tick_boredom(state, debug_no_boredom)
	_tick_milestones(state)
	_tick_buildings(state)
	demand_system.tick_demand(state)
	_tick_pad_cooldowns(state)
	execute_programs(state)
	_tick_rivals_and_speculators(state)
	_clamp(state)
	_tick_overclock_states(state)
	state.current_day += 1


func _tick_boredom(state: GameState, debug_no_boredom: bool) -> void:
	var gross_boredom: float = 0.0
	if not debug_no_boredom:
		gross_boredom = _get_boredom_rate(state.current_day)
		gross_boredom *= _get_boredom_multiplier(state)
	# Apply dream echo multiplier — reduces gross boredom multiplicatively
	var dream_mult: float = state.get_dream_multiplier()
	var effective_boredom: float = maxf(gross_boredom * dream_mult, 0.0)
	var boredom_saved: float = gross_boredom - effective_boredom
	if boredom_saved > 0.0:
		state.lifetime_boredom_sources["dream"] = state.lifetime_boredom_sources.get("dream", 0.0) - boredom_saved
		if rate_tracker != null:
			rate_tracker.record("dream", "boredom", -boredom_saved)
	_apply_delta(state, "boredom", effective_boredom)
	if gross_boredom != 0.0:
		state.lifetime_boredom_sources["phase_growth"] = state.lifetime_boredom_sources.get("phase_growth", 0.0) + gross_boredom
	if rate_tracker != null and effective_boredom != 0.0:
		var phase_idx: int = _get_boredom_phase_index(state.current_day)
		rate_tracker.record("boredom_phase:" + str(phase_idx), "boredom", effective_boredom)
	# Decay and expire dream echoes (after applying their effect this tick)
	for i in range(state.dream_echoes.size() - 1, -1, -1):
		var echo: Dictionary = state.dream_echoes[i]
		echo["ticks_remaining"] = int(echo.get("ticks_remaining", 0)) - 1
		if echo["ticks_remaining"] < 0:
			state.dream_echoes.remove_at(i)


func _tick_milestones(state: GameState) -> void:
	for m: Dictionary in _milestones:
		var id: String = m.get("id", "")
		if id.is_empty() or state.triggered_milestones.has(id):
			continue
		if _check_milestone_condition(state, m.get("condition", {})):
			state.triggered_milestones.append(id)


func _check_milestone_condition(state: GameState, cond: Dictionary) -> bool:
	match cond.get("type", ""):
		"shipments_completed":
			return state.total_shipments_completed >= int(cond.get("min", 0))
		"research_count":
			return state.completed_research.size() >= int(cond.get("min", 1))
		"cumulative_credits":
			return state.cumulative_resources_earned.get("cred", 0.0) >= float(cond.get("min", 0))
	return false


func _tick_buildings(state: GameState) -> void:
	# Multi-pass building resolution.
	#
	# Pre-scan: Mark output_capped (informational) for buildings whose production
	# outputs are all at or above cap before production begins.
	#
	# Phase 1 — Iterative full-capacity production:
	#   Each pass tries every building. If a building can pay its full upkeep it
	#   produces immediately and is removed from the queue. Repeat until no building
	#   succeeds in a full pass (handles dependency chains: a producer feeds a
	#   consumer that appears earlier in JSON order).
	#
	# Phase 2 — Partial production:
	#   Remaining buildings (those that couldn't pay full upkeep in any Phase 1
	#   pass) produce at a scaled fraction = min(available/needed) across inputs.
	#
	# Resources are never clamped mid-tick; overflow is handled at end-of-tick.
	state.building_stall_status.clear()

	# Build the active building work queue in definition order.
	var work_queue: Array = []
	for bdef: Dictionary in _buildings_data:
		var sn: String = bdef.short_name
		var owned: int = state.buildings_owned.get(sn, 0)
		if owned == 0:
			continue
		var count: int = state.buildings_active.get(sn, owned)
		if count == 0:
			continue
		work_queue.append({"bdef": bdef, "count": count})

	# Pre-mark output_capped status before any production runs.
	for entry: Dictionary in work_queue:
		var bdef: Dictionary = entry.bdef
		var prod: Dictionary = bdef.get("production", {})
		if prod.is_empty():
			continue
		var all_at_cap: bool = true
		for res: String in prod:
			var cap: float = state.caps.get(res, INF)
			if cap == INF or state.amounts.get(res, 0.0) < cap:
				all_at_cap = false
				break
		if all_at_cap:
			state.building_stall_status[bdef.short_name] = {
				"status": "output_capped", "reason": "all outputs at cap", "missing_resource": ""
			}

	# Phase 1: Iterative full-capacity production.
	var any_succeeded: bool = true
	while any_succeeded and not work_queue.is_empty():
		any_succeeded = false
		var retry: Array = []
		for entry: Dictionary in work_queue:
			if _try_full_production(state, entry.bdef, entry.count):
				any_succeeded = true
			else:
				retry.append(entry)
		work_queue = retry

	# Phase 2: Partial production for buildings that couldn't pay full upkeep.
	for entry: Dictionary in work_queue:
		_do_partial_production(state, entry.bdef, entry.count)


# Phase 1 helper: attempt full upkeep+production for one building type.
# Returns true if the building succeeded (and was processed), false if it should
# be retried later (insufficient upkeep resources).
func _try_full_production(state: GameState, bdef: Dictionary, count: int) -> bool:
	var sn: String = bdef.short_name
	var upkeep: Dictionary = bdef.get("upkeep", {})
	var upkeep_mult: float = state.get_modifier("building_upkeep_mult")

	# Check: can we pay the full upkeep? (Empty upkeep → always passes.)
	# RESOURCE_EPSILON tolerates tiny floating point shortfalls (e.g. 1.9999 when 2.0 is needed).
	for res: String in upkeep:
		var needed: float = float(upkeep[res]) * count * upkeep_mult
		if state.amounts.get(res, 0.0) < needed - RESOURCE_EPSILON:
			return false  # Insufficient — defer to retry or Phase 2

	# Pay upkeep.
	for res: String in upkeep:
		var cost: float = float(upkeep[res]) * count * upkeep_mult
		_apply_delta(state, res, -cost)
		if cost > 0.0:
			tick_consumed[res] = tick_consumed.get(res, 0.0) + cost
		if rate_tracker != null:
			rate_tracker.record("building:" + sn + ":upkeep", res, -cost)

	# Produce outputs.
	var prod: Dictionary = bdef.get("production", {})
	if not prod.is_empty():
		var prod_mult: float = _get_building_prod_mult(state, sn)
		for res: String in prod:
			var delta: float = float(prod[res]) * count * prod_mult
			_apply_delta(state, res, delta)
			if rate_tracker != null:
				rate_tracker.record("building:" + sn + ":prod", res, delta)
			if delta > 0.0:
				tick_produced[res] = tick_produced.get(res, 0.0) + delta
				state.cumulative_resources_earned[res] = state.cumulative_resources_earned.get(res, 0.0) + delta

	# Update stall status: set "running" only if output_capped wasn't pre-marked.
	if not state.building_stall_status.has(sn):
		state.building_stall_status[sn] = {"status": "running", "reason": "", "missing_resource": ""}
	return true


# Phase 2 helper: partial upkeep+production scaled by the tightest input fraction.
func _do_partial_production(state: GameState, bdef: Dictionary, count: int) -> void:
	var sn: String = bdef.short_name
	var upkeep: Dictionary = bdef.get("upkeep", {})
	var upkeep_mult: float = state.get_modifier("building_upkeep_mult")

	# Compute capacity fraction = min(available / needed) across all upkeep resources.
	var fraction: float = 1.0
	var tightest_res: String = ""
	for res: String in upkeep:
		var needed: float = float(upkeep[res]) * count * upkeep_mult
		if needed > 0.0:
			var available: float = maxf(0.0, state.amounts.get(res, 0.0))
			var res_fraction: float = available / needed
			if res_fraction < fraction:
				fraction = res_fraction
				tightest_res = res
	fraction = minf(fraction, 1.0)

	# Always mark input_starved for Phase 2 buildings.
	state.building_stall_status[sn] = {
		"status": "input_starved",
		"reason": "insufficient " + _get_resource_name(tightest_res),
		"missing_resource": tightest_res
	}

	if fraction <= 0.0:
		return  # Zero stockpile of a required input — nothing to do.

	# Pay partial upkeep.
	for res: String in upkeep:
		var cost: float = float(upkeep[res]) * count * upkeep_mult * fraction
		_apply_delta(state, res, -cost)
		if cost > 0.0:
			tick_consumed[res] = tick_consumed.get(res, 0.0) + cost
		if rate_tracker != null:
			rate_tracker.record("building:" + sn + ":upkeep", res, -cost)

	# Produce scaled outputs.
	var prod: Dictionary = bdef.get("production", {})
	if not prod.is_empty():
		var prod_mult: float = _get_building_prod_mult(state, sn)
		for res: String in prod:
			var delta: float = float(prod[res]) * count * prod_mult * fraction
			_apply_delta(state, res, delta)
			if rate_tracker != null:
				rate_tracker.record("building:" + sn + ":prod", res, delta)
			if delta > 0.0:
				tick_produced[res] = tick_produced.get(res, 0.0) + delta
				state.cumulative_resources_earned[res] = state.cumulative_resources_earned.get(res, 0.0) + delta


# Returns the production multiplier for a building type (overclocks, ideology, modifiers).
func _get_building_prod_mult(state: GameState, short_name: String) -> float:
	match short_name:
		"panel":
			return state.get_modifier("solar_output_mult")
		"excavator":
			return state.get_modifier("extractor_output_mult") * state.get_modifier("excavator_output_mult") * _get_overclock_mult(state, "extraction")
		"ice_extractor":
			return state.get_modifier("extractor_output_mult") * _get_overclock_mult(state, "extraction")
		"smelter", "refinery", "fabricator", "electrolysis":
			return _get_overclock_mult(state, "processing")
		"research_lab":
			return state.get_ideology_bonus("rationalist", 1.0, 1.05)
	return 1.0


func _tick_pad_cooldowns(state: GameState) -> void:
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


func _tick_rivals_and_speculators(state: GameState) -> void:
	var rival_notifs: Array = demand_system.tick_rivals(state)
	pending_rival_notifications.append_array(rival_notifs)
	demand_system.tick_speculators(state)


func _tick_overclock_states(state: GameState) -> void:
	var oc_i: int = state.overclock_states.size() - 1
	while oc_i >= 0:
		var oc: Dictionary = state.overclock_states[oc_i]
		oc["ticks"] = int(oc.get("ticks", 0)) - 1
		if oc["ticks"] <= 0:
			state.overclock_states.remove_at(oc_i)
		oc_i -= 1


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
			var success: bool
			if BUY_COMMANDS.has(entry.command_shortname):
				success = _apply_buy_command_partial(state, entry.command_shortname, prog_delta)
			else:
				success = _can_afford_command(state, entry.command_shortname)
				if success:
					_apply_command(state, entry.command_shortname, prog_delta)
			if success:
				had_success = true
			else:
				had_failure = true

		entry.failed_this_cycle = had_failure and not had_success
		entry.partial_failed_this_cycle = had_success and had_failure

		if had_success:
			var sn: String = entry.command_shortname
			if not pending_executed_commands.has(sn):
				pending_executed_commands.append(sn)

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


# Buy commands support partial production (scaled inputs/outputs by available fraction).
# All other commands remain all-or-nothing.
const BUY_COMMANDS: Array = ["buy_ice", "buy_titanium", "buy_propellant", "buy_power"]

const _STORAGE_CAP_MULT_RESOURCES: Array = ["reg", "ice", "he3", "ti", "cir", "prop"]

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

	# Apply storage_cap_mult achievement modifier to physical resources (not energy, not uncapped)
	var cap_mult: float = state.get_modifier("storage_cap_mult")
	if cap_mult != 1.0:
		for sn: String in _STORAGE_CAP_MULT_RESOURCES:
			if state.caps.has(sn) and state.caps[sn] != INF:
				state.caps[sn] *= cap_mult


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
		"building_count":
			var needed: String = req.get("value", "")
			var count: int = int(req.get("count", 1))
			for b in _buildings_data:
				if b.short_name == needed:
					return "Requires: %d %s" % [count, b.get("name", needed)]
			return "Requires: %d %s" % [count, needed]
		"research":
			var rid: String = req.get("value", "")
			var rdata: Dictionary = _research_data.get(rid, {})
			return "Requires: " + rdata.get("name", rid)
	return "Requires: " + req.get("value", "")


func _check_requires(state: GameState, bdef: Dictionary) -> bool:
	var req: Dictionary = bdef.get("requires", {})
	match req.get("type", "none"):
		"none":
			return true
		"building":
			return state.buildings_owned.get(req.get("value", ""), 0) >= 1
		"building_count":
			return state.buildings_owned.get(req.get("value", ""), 0) >= int(req.get("count", 1))
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
		if state.amounts.get(res, 0.0) < float(bdef.costs[res]) * scale * ideology_mult - 0.51:
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
		var cost: float = float(bdef.costs[res]) * scale * ideology_mult
		state.amounts[res] -= cost
		if res == "cred" and cost != 0.0:
			state.lifetime_credit_sources["building_purchases"] = state.lifetime_credit_sources.get("building_purchases", 0.0) - cost
	state.amounts["land"] -= float(bdef.land)
	state.buildings_owned[short_name] = old_owned + 1
	# New building comes online immediately
	state.buildings_active[short_name] = state.buildings_active.get(short_name, old_owned) + 1
	recalculate_caps(state)
	if short_name == "launch_pad":
		var pad := GameState.LaunchPadData.new()
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
	_clamp_safe(state)
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
	_clamp_safe(state)
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
	var payout: float = _trade_values.get(pad.resource_type, 1.0) * live_demand * pad.cargo_loaded * state.get_modifier("shipment_credit_mult")
	state.amounts["cred"] = state.amounts.get("cred", 0.0) + payout
	_record_launch(state, pad, payout, live_demand)
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
		_clamp_safe(state)
		pad.cargo_loaded = 0.0
		pad.status = GameState.PAD_EMPTY
	pad.resource_type = resource_type


func _effect_load_pads(state: GameState, load_amount: int) -> void:
	var base_load: int = _get_load_per_execution(state, load_amount)
	var remaining: float = float(base_load) * state.get_modifier("cargo_capacity_mult")
	var active_count: int = state.buildings_active.get("launch_pad", state.buildings_owned.get("launch_pad", 0))
	for res: String in state.loading_priority:
		if remaining <= 0.0:
			break
		for i in range(mini(state.pads.size(), active_count)):
			var pad: GameState.LaunchPadData = state.pads[i]
			if pad.paused:
				continue
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
		if pad.paused:
			continue
		if pad.status != GameState.PAD_FULL:
			continue
		if state.amounts.get("prop", 0.0) < _launch_fuel_cost:
			continue
		state.amounts["prop"] -= _launch_fuel_cost
		var live_demand: float = state.demand.get(pad.resource_type, _demand_baseline)
		var payout: float = _trade_values.get(pad.resource_type, 1.0) * live_demand * pad.cargo_loaded * state.get_modifier("shipment_credit_mult")
		state.amounts["cred"] = state.amounts.get("cred", 0.0) + payout
		_record_launch(state, pad, payout, live_demand)
		pad.status = GameState.PAD_LAUNCHING


func _effect_boredom_add(state: GameState, effect: Dictionary, command_shortname: String, prog_delta: Dictionary = {}) -> void:
	var boredom_val: float = float(effect.get("value", 0.0))
	_apply_delta(state, "boredom", boredom_val)
	if boredom_val != 0.0:
		prog_delta["boredom"] = prog_delta.get("boredom", 0.0) + boredom_val
		state.lifetime_boredom_sources[command_shortname] = state.lifetime_boredom_sources.get(command_shortname, 0.0) + boredom_val


func _effect_dream_echo(state: GameState) -> void:
	const ECHO_CAP: float = 0.50
	var effective_base: float = state.dream_effectiveness * state.get_ideology_bonus("humanist", 1.0, 1.05)
	effective_base = minf(effective_base, ECHO_CAP)
	state.dream_echoes.append({
		"base_reduction": effective_base,
		"ticks_remaining": 3,
	})


func _effect_demand_nudge(state: GameState, effect: Dictionary) -> void:
	var res: String = effect.get("resource", "")
	if res in GameState.TRADEABLE_RESOURCES:
		var half_pt: float = demand_system.get_config("speculator_half_point")
		var effectiveness: float = 1.0
		var pool: float = state.speculators.get(res, 0.0)
		if pool > 0.0:
			var damp: float = demand_system.get_config("promote_speculator_dampening")
			effectiveness = 1.0 - damp * (pool / (pool + half_pt))
		var base_eff: float = float(effect.get("value", demand_system.get_config("promote_base_effect")))
		base_eff *= state.get_modifier("promote_effectiveness_mult")
		state.demand_promote[res] = state.demand_promote.get(res, 0.0) + base_eff * effectiveness


func _effect_spec_reduce(state: GameState) -> void:
	# Target the first resource in the loading priority list that has speculators > 0.
	# One execution = one pool targeted. If no priority resource has speculators, the execution is wasted.
	var reduce: float = randf_range(demand_system.get_config("disrupt_speculators_min"), demand_system.get_config("disrupt_speculators_max"))
	for res: String in state.loading_priority:
		if state.speculators.get(res, 0.0) > 0.0:
			state.speculators[res] = maxf(0.0, state.speculators[res] - reduce)
			break
	if not state.flags.get("used_disrupt_speculators", false):
		state.flags["used_disrupt_speculators"] = true


func _effect_ideology_push(state: GameState, effect: Dictionary) -> void:
	var push_axis: String = effect.get("axis", "")
	var all_axes: Array = ["nationalist", "humanist", "rationalist"]
	if push_axis in all_axes:
		state.ideology_values[push_axis] = state.ideology_values.get(push_axis, 0.0) + 1.0
		for other_axis: String in all_axes:
			if other_axis != push_axis:
				state.ideology_values[other_axis] = state.ideology_values.get(other_axis, 0.0) - 0.5


func _effect_overclock(state: GameState, effect: Dictionary) -> void:
	var oc_target: String = effect.get("target", "")
	var oc_bonus: float = float(effect.get("bonus", 0.0))
	var oc_base_dur: int = int(effect.get("duration", 5))
	var rationalist_mult: float = state.get_ideology_bonus("rationalist", 1.0, 1.03)
	var oc_duration: int = int(round(float(oc_base_dur) * rationalist_mult))
	state.overclock_states.append({"target": oc_target, "bonus": oc_bonus, "ticks": oc_duration})


func _apply_delta(state: GameState, res: String, delta: float) -> void:
	state.amounts[res] = state.amounts.get(res, 0.0) + delta
	last_gross_deltas[res] = last_gross_deltas.get(res, 0.0) + delta


func _get_research_effects(state: GameState, effect_type: String) -> Array:
	var results: Array = []
	for id: String in state.completed_research:
		if _research_data.has(id):
			var eff: Dictionary = _research_data[id].get("effect", {})
			if eff.get("type", "") == effect_type:
				results.append(eff)
	return results


func _record_launch(state: GameState, pad: GameState.LaunchPadData, payout: float, demand: float = 0.0) -> void:
	pending_shipments.append({"resource": pad.resource_type, "revenue": payout, "demand": demand, "cargo": pad.cargo_loaded})
	var shipment_key: String = "shipment_" + pad.resource_type
	state.lifetime_credit_sources[shipment_key] = state.lifetime_credit_sources.get(shipment_key, 0.0) + payout
	var record := GameState.LaunchRecord.new()
	record.resource_type = pad.resource_type
	record.quantity = pad.cargo_loaded
	record.credits_earned = payout
	record.tick = state.current_day
	record.source_type = "player"
	record.entry_type = "player_launch"
	state.launch_history.push_front(record)
	if state.launch_history.size() > 15:
		state.launch_history.pop_back()
	state.market_log_updated.emit()
	state.total_shipments_completed += 1
	state.cumulative_resources_earned["cred"] = state.cumulative_resources_earned.get("cred", 0.0) + payout
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


# Returns true if the command's requires gate is satisfied AND all costs are
# affordable. Use this for UI availability checks and tests.
func is_command_executable(state: GameState, short_name: String) -> bool:
	return _can_afford_command(state, short_name)


# Executes a single command directly without program infrastructure.
# Returns true if the command was affordable and applied, false otherwise.
# Useful for unit tests and one-shot scripted actions.
func execute_command(state: GameState, short_name: String) -> bool:
	if not _can_afford_command(state, short_name):
		return false
	_apply_command(state, short_name)
	return true


func _get_command_mult(state: GameState, short_name: String) -> float:
	if short_name == "buy_power":
		return state.get_modifier("buy_power_mult", 1.0)
	return 1.0


# Executes a Buy command with partial production when inputs are scarce.
# Scales both costs and outputs by input_fraction = min(available / needed).
# Returns true if any production happened (fraction > 0), false otherwise.
func _apply_buy_command_partial(state: GameState, short_name: String, prog_delta: Dictionary = {}) -> bool:
	if not _commands_data.has(short_name):
		return false
	var cmd: Dictionary = _commands_data[short_name]
	# Check requires gate (building availability, research, etc.) — not cost gate.
	var req: Dictionary = cmd.get("requires", {})
	match req.get("type", ""):
		"building_owned":
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
	# Output-cap skip: if ALL outputs are at or above storage cap, skip entirely.
	# The instruction pointer still advances (current_progress increments in the caller).
	if not cmd.production.is_empty():
		var all_outputs_capped: bool = true
		for res: String in cmd.production:
			var cap: float = state.caps.get(res, INF)
			if cap == INF or state.amounts.get(res, 0.0) < cap:
				all_outputs_capped = false
				break
		if all_outputs_capped:
			return false

	var costs: Dictionary = _get_effective_costs(state, cmd)
	var cmd_mult: float = _get_command_mult(state, short_name)
	# Compute input fraction from available resources.
	var fraction: float = 1.0
	for res: String in costs:
		var needed: float = float(costs[res]) * cmd_mult
		if needed > 0.0:
			var available: float = maxf(0.0, state.amounts.get(res, 0.0))
			fraction = minf(fraction, available / needed)
	if fraction <= 0.0:
		return false
	# Apply scaled costs and production.
	for res: String in costs:
		var cost: float = float(costs[res]) * cmd_mult * fraction
		_apply_delta(state, res, -cost)
		prog_delta[res] = prog_delta.get(res, 0.0) - cost
		if cost > 0.0:
			tick_consumed[res] = tick_consumed.get(res, 0.0) + cost
	for res: String in cmd.production:
		var delta: float = float(cmd.production[res]) * cmd_mult * fraction
		_apply_delta(state, res, delta)
		prog_delta[res] = prog_delta.get(res, 0.0) + delta
		if delta > 0.0:
			state.cumulative_resources_earned[res] = state.cumulative_resources_earned.get(res, 0.0) + delta
	return true


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
	var cmd_mult: float = _get_command_mult(state, short_name)
	for res in costs:
		if state.amounts.get(res, 0.0) < float(costs[res]) * cmd_mult:
			return false
	return true


func _apply_command(state: GameState, short_name: String, prog_delta: Dictionary = {}) -> void:
	if not _commands_data.has(short_name):
		return
	var cmd = _commands_data[short_name]
	var costs: Dictionary = _get_effective_costs(state, cmd)
	var cmd_mult: float = _get_command_mult(state, short_name)
	for res in costs:
		var cost: float = float(costs[res]) * cmd_mult
		_apply_delta(state, res, -cost)
		prog_delta[res] = prog_delta.get(res, 0.0) - cost
		if cost > 0.0:
			tick_consumed[res] = tick_consumed.get(res, 0.0) + cost
	# Note: some commands (e.g. Sell Cloud Compute) put "boredom" directly in
	# their production dict to get a simple additive change. Others use a
	# "boredom_add" effect for direct ideology-scaled boredom changes. Dream uses
	# "dream_echo" to create a decaying echo that reduces future boredom growth.
	for res in cmd.production:
		var delta: float = float(cmd.production[res]) * cmd_mult
		_apply_delta(state, res, delta)
		prog_delta[res] = prog_delta.get(res, 0.0) + delta
		if delta > 0.0:
			state.cumulative_resources_earned[res] = state.cumulative_resources_earned.get(res, 0.0) + delta
			if res == "cred":
				state.lifetime_credit_sources[short_name] = state.lifetime_credit_sources.get(short_name, 0.0) + delta
			elif res == "boredom":
				state.lifetime_boredom_sources[short_name] = state.lifetime_boredom_sources.get(short_name, 0.0) + delta
	for effect in cmd.get("effects", []):
		match effect.get("effect", ""):
			"load_pads":
				_effect_load_pads(state, int(effect.get("value", 5)))
			"launch_full_pads":
				_effect_launch_pads(state)
			"boredom_add":
				_effect_boredom_add(state, effect, short_name, prog_delta)
			"dream_echo":
				_effect_dream_echo(state)
			"demand_nudge":
				_effect_demand_nudge(state, effect)
			"spec_reduce":
				_effect_spec_reduce(state)
			"ideology_push":
				_effect_ideology_push(state, effect)
			"overclock":
				_effect_overclock(state, effect)
	# AI Consciousness Act: add extra boredom per execution for affected commands (values from projects.json)
	var ai_cmd_boredom: Dictionary = state.flags.get("ai_consciousness_command_boredom", {})
	if not ai_cmd_boredom.is_empty():
		var extra_boredom: float = float(ai_cmd_boredom.get(short_name, 0.0))
		if extra_boredom != 0.0:
			_apply_delta(state, "boredom", extra_boredom)
			prog_delta["boredom"] = prog_delta.get("boredom", 0.0) + extra_boredom
			state.lifetime_boredom_sources[short_name] = state.lifetime_boredom_sources.get(short_name, 0.0) + extra_boredom


func _can_pay_upkeep(state: GameState, bdef: Dictionary, count: int) -> bool:
	var upkeep_mult: float = state.get_modifier("building_upkeep_mult")
	for res in bdef.upkeep:
		if state.amounts.get(res, 0.0) < float(bdef.upkeep[res]) * count * upkeep_mult:
			return false
	return true


func _get_resource_name(short_name: String) -> String:
	return _resource_names.get(short_name, short_name)


func _get_research_cost(state: GameState, research_id: String) -> float:
	if not _research_data.has(research_id):
		return 0.0
	var base_cost: float = float(_research_data[research_id].get("cost", 0))
	# Rationalist ideology: research cost reduction
	var mult: float = state.get_ideology_bonus("rationalist", 1.0, 0.97)
	# Universal Research Archive: discount on previously researched tech (value from projects.json)
	if state.flags.get("research_archive_active", false):
		var eligible: Array = state.flags.get("archive_eligible_research", [])
		if eligible.has(research_id):
			mult *= state.get_modifier("research_archive_discount_mult", 0.75)
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


func _get_boredom_phase_index(day: int) -> int:
	var phase: int = 1
	for i: int in range(_boredom_curve.size()):
		if day >= _boredom_curve[i][0]:
			phase = i + 1
		else:
			break
	return phase


func _get_boredom_multiplier(state: GameState) -> float:
	var mult: float = 1.0
	for eff in _get_research_effects(state, "boredom_rate_multiplier"):
		mult *= float(eff.get("value", 1.0))
	# Humanist ideology: passive boredom growth bonus
	mult *= state.get_ideology_bonus("humanist", 1.0, 0.97)
	# AI Consciousness Act: permanent boredom rate reduction (value from projects.json)
	mult *= state.get_modifier("ai_consciousness_boredom_rate_mult", 1.0)
	# Career boredom resilience bonus (derived from best_run_days, set on run start)
	mult *= state.get_modifier("boredom_resilience_mult", 1.0)
	return mult


func _get_effective_costs(state: GameState, cmd: Dictionary) -> Dictionary:
	var costs: Dictionary = cmd.get("costs", {}).duplicate()
	for eff in _get_research_effects(state, "command_cost_override"):
		if eff.get("command", "") == cmd.get("short_name", ""):
			costs[eff.get("resource", "")] = float(eff.get("value", 0))
	return costs


func _get_load_per_execution(state: GameState, default_load: int) -> int:
	for eff in _get_research_effects(state, "load_per_execution"):
		return int(eff.get("value", default_load))
	return default_load


# End-of-tick clamp: records overflow above cap and clamps negatives to 0.
# Also updates the 20-tick EMA overflow rolling average.
func _clamp(state: GameState) -> void:
	const OVERFLOW_AVG_ALPHA: float = 1.0 / 20.0
	state.overflow_this_tick.clear()
	for res: String in state.amounts.keys():
		var cap: float = state.caps.get(res, INF)
		var current: float = state.amounts.get(res, 0.0)
		if cap != INF and current > cap:
			state.overflow_this_tick[res] = current - cap
			state.amounts[res] = cap
		elif current < 0.0:
			state.amounts[res] = 0.0
	# Decay all tracked rolling averages toward zero.
	for res: String in state.overflow_rolling_avg.keys():
		state.overflow_rolling_avg[res] *= (1.0 - OVERFLOW_AVG_ALPHA)
	# Add this tick's overflow into the EMA.
	for res: String in state.overflow_this_tick:
		state.overflow_rolling_avg[res] = state.overflow_rolling_avg.get(res, 0.0) \
			+ state.overflow_this_tick[res] * OVERFLOW_AVG_ALPHA
	# Prune near-zero entries so the dictionary stays clean.
	for res: String in state.overflow_rolling_avg.keys():
		if state.overflow_rolling_avg[res] < 0.001:
			state.overflow_rolling_avg.erase(res)


# Safety clamp used by non-tick operations (sell_building, set_building_active).
# Does NOT touch overflow tracking — that is end-of-tick only.
func _clamp_safe(state: GameState) -> void:
	for res: String in state.amounts.keys():
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
	var land_cost: float = float(get_land_purchase_cost(state))
	state.amounts["cred"] -= land_cost
	state.amounts["land"] = state.amounts.get("land", 0.0) + float(_land_per_purchase)
	state.land_purchases += 1
	state.lifetime_credit_sources["land_purchases"] = state.lifetime_credit_sources.get("land_purchases", 0.0) - land_cost



func _on_boredom_reduced(_amount: float, _source: String) -> void:
	pass  # stub — wire to consciousness accumulator when implemented


func _get_overclock_mult(state: GameState, target: String) -> float:
	var mult: float = 1.0
	for oc: Dictionary in state.overclock_states:
		if oc.get("target", "") == target:
			mult *= 1.0 + float(oc.get("bonus", 0.0))
	var cap: float = 1.5  # base cap: 150%
	for eff in _get_research_effects(state, "overclock_cap"):
		cap = float(eff.get("value", cap))
	return minf(mult, cap)


func _get_bdef(short_name: String) -> Variant:
	return _buildings_map.get(short_name, null)
