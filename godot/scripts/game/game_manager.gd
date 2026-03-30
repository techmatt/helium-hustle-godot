extends Node

const SaveManager := preload("res://scripts/game/save_manager.gd")

const DEBUG_PROGRAM_TEST: bool = false
const DEBUG_UI: bool = false
const DEBUG_DEMAND: bool = false

const SPEED_MAP: Dictionary = {
	"||":   0.0,
	"1x":   1.0,
	"3x":   3.0,
	"10x":  10.0,
	"50x":  50.0,
	"200x": 200.0,
}


var state: GameState
var sim: GameSimulation
var rate_tracker: ResourceRateTracker
var event_manager: EventManager
var project_manager: ProjectManager
var career: CareerState = CareerState.new()
var last_deltas: Dictionary = {}
var current_speed_key: String = "1x"

signal tick_completed
signal program_step_executed(program_index: int, entry_index: int, success: bool)
signal program_cycle_reset(program_index: int)
signal milestone_triggered(milestone_id: String, label: String, boredom_reduction: float)
signal retirement_started(summary_data: Dictionary)
signal project_completed_notification(project_name: String)

var _timer: Timer
var _autosave_timer: Timer
var _game_config: Dictionary
var _buildings_data: Array = []
var _commands_data: Array = []
var _research_data: Array = []
var _projects_data: Array = []


func _ready() -> void:
	var resources_data: Array = _load_json("res://data/resources.json")
	_buildings_data = _load_json("res://data/buildings.json")
	_game_config = _load_json("res://data/game_config.json")
	_commands_data = _load_json("res://data/commands.json")
	_research_data = _load_json("res://data/research.json")
	var events_data: Array = _load_json("res://data/events.json")
	_projects_data = _load_json("res://data/projects.json")

	sim = GameSimulation.new()
	sim.init(resources_data, _buildings_data, _commands_data, _game_config, _research_data)
	rate_tracker = ResourceRateTracker.new()
	sim.rate_tracker = rate_tracker

	event_manager = EventManager.new()
	event_manager.init(events_data, _game_config)

	project_manager = ProjectManager.new()
	project_manager.init(_projects_data, _game_config)

	var save_data: Variant = SaveManager.load_game()
	if save_data != null:
		career = CareerState.from_dict((save_data as Dictionary).get("career", {}))
		state = GameState.from_dict((save_data as Dictionary).get("run_state", {}))
		_restore_from_save()
	else:
		career = CareerState.new()
		state = GameState.new()
		_initialize_state()
		call_deferred("_fire_startup_events")

	if DEBUG_PROGRAM_TEST:
		_debug_setup_test_program()
	if DEBUG_UI:
		_debug_setup_ui_state()
	if DEBUG_DEMAND:
		_debug_setup_demand_state()

	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = 60.0
	_autosave_timer.one_shot = false
	_autosave_timer.timeout.connect(_autosave)
	add_child(_autosave_timer)
	_autosave_timer.start()

	set_speed("1x")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_autosave()
		get_tree().quit()


func _restore_from_save() -> void:
	sim.recalculate_caps(state)
	tick_completed.emit()


func _initialize_state() -> void:
	for sn in _game_config.starting_resources:
		state.amounts[sn] = float(_game_config.starting_resources[sn])
	for sn in _game_config.starting_buildings:
		var count: int = int(_game_config.starting_buildings[sn])
		state.buildings_owned[sn] = count
		for bdef: Dictionary in _buildings_data:
			if bdef.short_name == sn:
				state.amounts["land"] -= float(bdef.land) * count
				break
	state.run_number = career.run_number
	sim.recalculate_caps(state)
	sim.demand_system.initialize_demand(state)
	state.programs[0].processors_assigned = 1


func set_speed(speed_key: String) -> void:
	current_speed_key = speed_key
	var tps: float = SPEED_MAP.get(speed_key, 1.0)
	if tps <= 0.0:
		_timer.stop()
		_autosave()
	else:
		_timer.wait_time = 1.0 / tps
		_timer.start()


func buy_building(short_name: String) -> void:
	if sim.can_buy_building(state, short_name):
		sim.buy_building(state, short_name)
		tick_completed.emit()


func can_afford_building(short_name: String) -> bool:
	return sim.can_buy_building(state, short_name)


func is_building_locked(short_name: String) -> bool:
	return sim.is_building_locked(state, short_name)


func get_building_requires_text(short_name: String) -> String:
	return sim.get_building_requires_text(state, short_name)


func get_scaled_costs(short_name: String) -> Dictionary:
	return sim.get_scaled_costs(state, short_name)


func sell_building(short_name: String, sell_count: int = 1) -> void:
	sim.sell_building(state, short_name, sell_count)
	tick_completed.emit()


func set_building_active(short_name: String, delta: int) -> void:
	sim.set_building_active(state, short_name, delta)
	tick_completed.emit()


func get_building_active(short_name: String) -> int:
	return state.buildings_active.get(short_name, state.buildings_owned.get(short_name, 0))


func launch_pad_manual(pad_idx: int) -> void:
	if sim.launch_pad_manual(state, pad_idx):
		tick_completed.emit()


func can_launch_pad(pad_idx: int) -> bool:
	return sim.can_launch_pad(state, pad_idx)


func set_pad_resource(pad_idx: int, resource_type: String) -> void:
	sim.set_pad_resource(state, pad_idx, resource_type)
	tick_completed.emit()


func set_loading_priority(priority: Array) -> void:
	state.loading_priority = priority.duplicate()
	tick_completed.emit()


func get_buildings_data() -> Array:
	return _buildings_data


func can_buy_land() -> bool:
	return sim.can_buy_land(state)


func get_land_purchase_cost() -> int:
	return sim.get_land_purchase_cost(state)


func get_total_land() -> int:
	return sim.get_total_land(state)


func get_land_per_purchase() -> int:
	return sim.get_land_per_purchase()


func buy_land() -> void:
	if sim.can_buy_land(state):
		sim.buy_land(state)
		tick_completed.emit()


func set_project_rate(project_id: String, resource_id: String, rate: float) -> void:
	project_manager.set_project_rate(state, project_id, resource_id, rate)
	tick_completed.emit()


func get_commands_data() -> Array:
	return _commands_data


func get_research_data() -> Array:
	return _research_data


func purchase_research(research_id: String) -> void:
	if sim.can_purchase_research(state, research_id):
		sim.purchase_research(state, research_id)
		tick_completed.emit()


func _on_tick() -> void:
	sim.tick(state)
	event_manager.tick(state)
	project_manager.tick(state, career)
	last_deltas = sim.last_gross_deltas.duplicate()
	for event in sim.pending_program_events:
		if event.type == "step":
			program_step_executed.emit(event.program_index, event.entry_index, event.success)
		elif event.type == "cycle_reset":
			program_cycle_reset.emit(event.program_index)
	for m in sim.pending_milestone_triggers:
		print("[Milestone] %s — Boredom -%s" % [m.label, m.boredom_reduction])
		milestone_triggered.emit(m.id, m.label, m.boredom_reduction)
	for notif in project_manager.pending_completion_notifications:
		event_manager.push_notification("Project Complete: " + notif.name, state.current_day)
		project_completed_notification.emit(notif.name)
	tick_completed.emit()
	if state.amounts.get("boredom", 0.0) >= 1000.0:
		retire(false)


func retire(voluntary: bool) -> void:
	set_speed("||")

	# Snapshot run stats into career
	var run_credits: float = state.cumulative_resources_earned.get("cred", 0.0)
	var run_shipments: int = state.total_shipments_completed
	var run_days: int = state.current_day
	var run_buildings: int = 0
	for count: int in state.buildings_owned.values():
		run_buildings += count
	var run_research: int = state.completed_research.size()

	career.lifetime_credits_earned += run_credits
	career.lifetime_shipments += run_shipments
	career.lifetime_days_survived += run_days
	career.lifetime_buildings_built += run_buildings
	career.lifetime_research_completed += run_research
	career.best_run_days = maxi(career.best_run_days, run_days)
	career.best_run_credits = maxf(career.best_run_credits, run_credits)
	career.best_run_shipments = maxi(career.best_run_shipments, run_shipments)

	# Update event persistence
	for inst: Dictionary in state.event_instances:
		var eid: String = inst.get("id", "")
		if eid and not career.seen_event_ids.has(eid):
			career.seen_event_ids.append(eid)

	# Save persistent project progress to career
	for pid: String in state.project_invested:
		var pdef: Dictionary = project_manager.get_project_def(pid)
		if pdef.get("tier", "") == "persistent" and not career.completed_projects.has(pid):
			career.project_progress[pid] = (state.project_invested[pid] as Dictionary).duplicate()

	# Build summary data for the UI
	var summary: Dictionary = {
		"run_number": career.run_number,
		"voluntary": voluntary,
		"days_survived": run_days,
		"credits_earned": run_credits,
		"shipments_completed": run_shipments,
		"buildings_built": run_buildings,
		"research_completed": state.completed_research.duplicate(),
		"ideology_ranks": {},
		"milestones_hit": state.triggered_milestones.duplicate(),
		"career_retirements": career.total_retirements + 1,
		"career_total_days": career.lifetime_days_survived,
	}

	# Increment career counters
	career.total_retirements += 1
	career.run_number += 1

	retirement_started.emit(summary)


func start_new_run() -> void:
	# Fresh state
	state = GameState.new()
	for sn in _game_config.starting_resources:
		state.amounts[sn] = float(_game_config.starting_resources[sn])
	for sn in _game_config.starting_buildings:
		var count: int = int(_game_config.starting_buildings[sn])
		state.buildings_owned[sn] = count
		for bdef: Dictionary in _buildings_data:
			if bdef.short_name == sn:
				state.amounts["land"] -= float(bdef.land) * count
				break
	state.run_number = career.run_number

	# Transfer event history from career so prior events are marked seen
	for eid: String in career.seen_event_ids:
		if not state.seen_event_ids.has(eid):
			state.seen_event_ids.append(eid)

	# Apply persistent project rewards from prior runs
	for pid: String in career.completed_projects:
		var pdef: Dictionary = project_manager.get_project_def(pid)
		if pdef.is_empty():
			continue
		var reward: Dictionary = pdef.get("reward", {})
		match reward.get("type", ""):
			"modifier":
				state.set_modifier(reward.get("modifier_key", ""), float(reward.get("modifier_value", 1.0)))
			"starting_buildings":
				for bsn: String in reward.get("buildings", {}):
					var count: int = int((reward.get("buildings", {}) as Dictionary).get(bsn, 0))
					state.buildings_owned[bsn] = state.buildings_owned.get(bsn, 0) + count
					state.buildings_active[bsn] = state.buildings_active.get(bsn, 0) + count
					for bdef: Dictionary in _buildings_data:
						if bdef.short_name == bsn:
							state.amounts["land"] = state.amounts.get("land", 0.0) - float(bdef.land) * count
							break
		state.completed_projects_this_run.append(pid)

	# Load persistent project progress from career
	for pid: String in career.project_progress:
		state.project_invested[pid] = (career.project_progress[pid] as Dictionary).duplicate()

	# First processor always starts assigned to program slot 0
	state.programs[0].processors_assigned = 1

	# Re-initialize subsystems for the new state
	rate_tracker = ResourceRateTracker.new()
	sim.rate_tracker = rate_tracker
	sim.recalculate_caps(state)
	sim.demand_system.initialize_demand(state)

	# Fire game_start events for the new run
	event_manager.on_game_start(state)

	set_speed("1x")
	tick_completed.emit()
	SaveManager.save_game(career, state)


func _autosave() -> void:
	if state != null and sim != null:
		SaveManager.save_game(career, state)


func _fire_startup_events() -> void:
	event_manager.on_game_start(state)


func _debug_clear_save() -> void:
	SaveManager.clear_save()
	career = CareerState.new()
	state = GameState.new()
	_initialize_state()
	event_manager.on_game_start(state)
	rate_tracker = ResourceRateTracker.new()
	sim.rate_tracker = rate_tracker
	set_speed("1x")
	tick_completed.emit()
	print("Save data cleared")


func _debug_setup_test_program() -> void:
	var e1 := GameState.ProgramEntry.new()
	e1.command_shortname = "cloud_compute"
	e1.repeat_count = 2
	var e2 := GameState.ProgramEntry.new()
	e2.command_shortname = "idle"
	e2.repeat_count = 1
	var e3 := GameState.ProgramEntry.new()
	e3.command_shortname = "cloud_compute"
	e3.repeat_count = 3
	state.programs[0].commands = [e1, e2, e3]
	state.programs[0].processors_assigned = 1


func debug_boost() -> void:
	# Ensure at least debug minimums, then max all resources to current caps.
	var minimums: Dictionary = {
		"panel":         20,
		"storage_depot": 5,
		"launch_pad":    3,
		"data_center":   1,
	}
	for sn: String in minimums:
		var need: int = minimums[sn]
		var have: int = state.buildings_owned.get(sn, 0)
		if have < need:
			state.buildings_owned[sn] = need
			state.buildings_active[sn] = need
	# Sync pads array to owned launch pad count
	var owned_pads: int = state.buildings_owned.get("launch_pad", 0)
	while state.pads.size() < owned_pads:
		var pad := GameState.LaunchPadData.new()
		pad.resource_type = state.loading_priority[0] if not state.loading_priority.is_empty() else "he3"
		state.pads.append(pad)
	state.amounts["land"] = maxf(state.amounts.get("land", 0.0), 200.0)
	sim.recalculate_caps(state)
	for res: String in ["eng", "reg", "ice", "he3", "ti", "cir", "prop"]:
		state.amounts[res] = state.caps.get(res, state.amounts.get(res, 0.0))
	state.amounts["cred"] = maxf(state.amounts.get("cred", 0.0), 1000.0)
	tick_completed.emit()


func _debug_setup_ui_state() -> void:
	# Override starting state for UI development: rich resources, pads ready to test
	state.buildings_owned.clear()
	state.buildings_active.clear()
	state.pads.clear()

	var debug_buildings: Dictionary = {
		"panel":         20,
		"storage_depot": 5,
		"launch_pad":    3,
		"data_center":   1,
	}
	for sn: String in debug_buildings:
		state.buildings_owned[sn] = debug_buildings[sn]
		state.buildings_active[sn] = debug_buildings[sn]

	for i in range(3):
		var pad := GameState.LaunchPadData.new()
		pad.resource_type = state.loading_priority[0] if not state.loading_priority.is_empty() else "he3"
		state.pads.append(pad)

	sim.recalculate_caps(state)

	state.amounts["land"]    = 200.0
	state.amounts["cred"]    = 1000.0
	state.amounts["boredom"] = 0.0
	state.amounts["sci"]     = 0.0
	for res: String in ["eng", "reg", "ice", "he3", "ti", "cir", "prop"]:
		state.amounts[res] = state.caps.get(res, 0.0)


func _debug_setup_demand_state() -> void:
	# Sets up all prerequisites for testing the demand/trading system.
	sim.demand_system.debug_pure_noise = false
	_debug_setup_ui_state()  # rich resources + 3 launch pads
	# Unlock market_awareness so the demand section shows sparklines + exact values
	if not state.completed_research.has("market_awareness"):
		state.completed_research.append("market_awareness")
	# Trigger speculators very soon so suppression behavior is immediately testable
	state.speculator_next_burst_tick = 5
	# Bring all rival dump timers forward so market disruptions appear within ~10–20 ticks
	for rid: String in ["aria7", "crucible", "nodal", "fringe9"]:
		state.rival_next_dump_tick[rid] = randi_range(8, 20)


func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameManager: cannot open " + path)
		return null
	var result: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return result
