class_name TestFixtures
extends RefCounted

# Must be preloaded in test scripts — class_name is not auto-registered in
# headless --script mode for files outside the autoload chain.
# Usage: const TF = preload("res://tests/test_fixtures.gd")


static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("TestFixtures: cannot open " + path)
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)


static func load_game_config() -> Dictionary:
	return load_json("res://data/game_config.json")


static func load_resources_data() -> Array:
	return load_json("res://data/resources.json")


static func load_buildings_data() -> Array:
	return load_json("res://data/buildings.json")


static func load_commands_data() -> Array:
	return load_json("res://data/commands.json")


static func load_research_data() -> Array:
	return load_json("res://data/research.json")


static func load_events_data() -> Array:
	return load_json("res://data/events.json")


static func load_projects_data() -> Array:
	return load_json("res://data/projects.json")


# Returns a fully initialized GameSimulation loaded from project JSON data.
static func create_fresh_sim() -> GameSimulation:
	var sim := GameSimulation.new()
	sim.init(
		load_resources_data(),
		load_buildings_data(),
		load_commands_data(),
		load_game_config(),
		load_research_data(),
	)
	return sim


# Returns a GameState at Day 0 starting conditions, with caps calculated and
# demand initialized. Pass a sim from create_fresh_sim().
static func fresh_state(sim: GameSimulation) -> GameState:
	var config := load_game_config()
	var buildings_data := load_buildings_data()
	var state := GameState.from_config(config, buildings_data)
	sim.recalculate_caps(state)
	sim.demand_system.initialize_demand(state)
	return state
