extends Node

const DEBUG_PROGRAM_TEST: bool = false

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
var last_deltas: Dictionary = {}

signal tick_completed
signal program_step_executed(program_index: int, entry_index: int, success: bool)
signal program_cycle_reset(program_index: int)

var _timer: Timer
var _game_config: Dictionary
var _buildings_data: Array = []
var _commands_data: Array = []


func _ready() -> void:
	var resources_data: Array = _load_json("res://data/resources.json")
	_buildings_data = _load_json("res://data/buildings.json")
	_game_config = _load_json("res://data/game_config.json")
	_commands_data = _load_json("res://data/commands.json")

	sim = GameSimulation.new()
	sim.init(resources_data, _buildings_data, _commands_data)

	state = GameState.new()
	_initialize_state()

	if DEBUG_PROGRAM_TEST:
		_debug_setup_test_program()

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


func get_buildings_data() -> Array:
	return _buildings_data


func get_commands_data() -> Array:
	return _commands_data


func _on_tick() -> void:
	var prev: Dictionary = state.amounts.duplicate()
	sim.tick(state)
	last_deltas.clear()
	for res in state.amounts:
		last_deltas[res] = state.amounts[res] - prev.get(res, 0.0)
	for event in sim.pending_program_events:
		if event.type == "step":
			program_step_executed.emit(event.program_index, event.entry_index, event.success)
		elif event.type == "cycle_reset":
			program_cycle_reset.emit(event.program_index)
	tick_completed.emit()


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


func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameManager: cannot open " + path)
		return null
	var result: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return result

