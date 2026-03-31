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
#
# Note: energy starts at its storage cap (100). If testing production from buildings
# like the solar panel, drain state.amounts["eng"] = 0.0 first so the output is
# visible after clamping.
static func fresh_state(sim: GameSimulation) -> GameState:
	var config := load_game_config()
	var buildings_data := load_buildings_data()
	var state := GameState.from_config(config, buildings_data)
	sim.recalculate_caps(state)
	sim.demand_system.initialize_demand(state)
	return state


# Returns a fresh state with the given research IDs pre-completed.
# Also pre-triggers the "first_research" milestone so it doesn't fire during
# the first tick and zero out the small boredom delta you're usually measuring.
# (In real gameplay research is purchased mid-run when boredom is already high;
# injecting it at Day 0 would cause the 150-point reduction to clamp a 0.085-
# point accumulation to 0 before you can read it.)
static func fresh_state_with_research(sim: GameSimulation, ids: Array) -> GameState:
	var state := fresh_state(sim)
	for id: String in ids:
		state.completed_research.append(id)
	if not ids.is_empty():
		state.triggered_milestones.append("first_research")
	return state
