extends Node

const DEBUG_PROGRAM_TEST: bool = false
const DEBUG_UI: bool = false

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
var event_manager: EventManager
var last_deltas: Dictionary = {}
var current_speed_key: String = "1x"

signal tick_completed
signal program_step_executed(program_index: int, entry_index: int, success: bool)
signal program_cycle_reset(program_index: int)

var _timer: Timer
var _game_config: Dictionary
var _buildings_data: Array = []
var _commands_data: Array = []
var _research_data: Array = []


func _ready() -> void:
	var resources_data: Array = _load_json("res://data/resources.json")
	_buildings_data = _load_json("res://data/buildings.json")
	_game_config = _load_json("res://data/game_config.json")
	_commands_data = _load_json("res://data/commands.json")
	_research_data = _load_json("res://data/research.json")
	var events_data: Array = _load_json("res://data/events.json")

	sim = GameSimulation.new()
	sim.init(resources_data, _buildings_data, _commands_data, _game_config, _research_data)

	state = GameState.new()
	_initialize_state()

	event_manager = EventManager.new()
	event_manager.init(events_data, _game_config)
	call_deferred("_fire_startup_events")

	if DEBUG_PROGRAM_TEST:
		_debug_setup_test_program()
	if DEBUG_UI:
		_debug_setup_ui_state()

	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	set_speed("1x")


func _initialize_state() -> void:
	for sn in _game_config.starting_resources:
		state.amounts[sn] = float(_game_config.starting_resources[sn])
	for sn in _game_config.starting_buildings:
		state.buildings_owned[sn] = int(_game_config.starting_buildings[sn])
	sim.recalculate_caps(state)
	state.programs[0].processors_assigned = 1


func set_speed(speed_key: String) -> void:
	current_speed_key = speed_key
	var tps: float = SPEED_MAP.get(speed_key, 1.0)
	if tps <= 0.0:
		_timer.stop()
	else:
		_timer.wait_time = 1.0 / tps
		_timer.start()


func buy_building(short_name: String) -> void:
	if sim.can_buy_building(state, short_name):
		sim.buy_building(state, short_name)
		tick_completed.emit()


func can_afford_building(short_name: String) -> bool:
	return sim.can_buy_building(state, short_name)


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
	last_deltas = sim.last_gross_deltas.duplicate()
	for event in sim.pending_program_events:
		if event.type == "step":
			program_step_executed.emit(event.program_index, event.entry_index, event.success)
		elif event.type == "cycle_reset":
			program_cycle_reset.emit(event.program_index)
	tick_completed.emit()


func _fire_startup_events() -> void:
	event_manager.on_game_start(state)


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


func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameManager: cannot open " + path)
		return null
	var result: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return result
