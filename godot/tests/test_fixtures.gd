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
#
# Available land = starting_resources.land(40) minus building footprints from
# game_config starting_buildings: panel=1, data_center=2 → 37 available on day 0.
static func fresh_state(sim: GameSimulation) -> GameState:
	var config := load_game_config()
	var buildings_data := load_buildings_data()
	var state := GameState.from_config(config, buildings_data)
	sim.recalculate_caps(state)
	sim.demand_system.initialize_demand(state)
	return state


# Returns a fresh state with all starting buildings deactivated (buildings_active
# set to 0 for each owned building). Use this to isolate a single building's
# effect without interference from panel energy production or data_center upkeep.
static func fresh_state_isolated(sim: GameSimulation) -> GameState:
	var state := fresh_state(sim)
	for sn: String in state.buildings_owned:
		state.buildings_active[sn] = 0
	return state


# Returns the building definition dict for the given short_name, or {} if not found.
static func get_building_def(short_name: String) -> Dictionary:
	for bdef: Dictionary in load_buildings_data():
		if bdef.short_name == short_name:
			return bdef
	return {}


# Sets buildings_owned and buildings_active to count for the given short_name.
# Use this to inject a building into a test state without going through buy_building.
static func add_building(state: GameState, short_name: String, count: int = 1) -> void:
	state.buildings_owned[short_name] = count
	state.buildings_active[short_name] = count


# Sets up program slot with a single command entry and 1 processor.
# Clears any existing commands in the slot first.
static func setup_program(state: GameState, command_shortname: String, slot: int = 0) -> void:
	var entry := GameState.ProgramEntry.new()
	entry.command_shortname = command_shortname
	entry.repeat_count = 1
	state.programs[slot].commands.clear()
	state.programs[slot].commands.append(entry)
	state.programs[slot].processors_assigned = 1
	state.programs[slot].instruction_pointer = 0


# Returns a fresh isolated state with fixed perlin seeds and zeroed demand
# accumulators so demand calculations are deterministic across test calls.
# Random events (speculator bursts, rival dumps) are deferred via defer_random_events().
# Note: state.demand is not populated until the first tick_demand call.
static func fresh_state_demand_isolated(sim: GameSimulation) -> GameState:
	var state := fresh_state_isolated(sim)
	for res: String in GameState.TRADEABLE_RESOURCES:
		state.demand_perlin_seeds[res] = 5.0
		state.demand_perlin_freq[res] = 0.02
		state.demand_promote[res] = 0.0
		state.demand_rival[res] = 0.0
		state.demand_launch[res] = 0.0
		state.demand_history[res] = []
	state.speculator_count = 0.0
	state.speculator_target = ""
	defer_random_events(state)
	return state


# Defers all time-based random events to a far-future tick so they don't
# fire unexpectedly during tests. Sets speculator burst and all rival dump
# ticks to a sentinel value (999999).
static func defer_random_events(state: GameState) -> void:
	state.speculator_next_burst_tick = 999999
	for rid: String in state.rival_next_dump_tick:
		state.rival_next_dump_tick[rid] = 999999


# Returns a fully initialized ProjectManager loaded from project JSON data.
static func create_fresh_pm() -> ProjectManager:
	var pm := ProjectManager.new()
	pm.init(load_projects_data(), load_game_config())
	return pm


# Redirects SaveManager's save path to a temp file so retirement tests don't
# touch the player's real save. Returns the original path for restoration.
# Call restore_save() in a finally-style cleanup at the end of the test.
static func redirect_save(temp_name: String) -> String:
	var SM = preload("res://scripts/game/save_manager.gd")
	var real: String = SM.save_path
	SM.save_path = "user://" + temp_name
	return real


# Restores the save path redirected by redirect_save() and deletes the temp file.
static func restore_save(real_path: String, temp_name: String) -> void:
	var SM = preload("res://scripts/game/save_manager.gd")
	SM.save_path = real_path
	var full: String = "user://" + temp_name
	if FileAccess.file_exists(full):
		DirAccess.remove_absolute(full)


# Pre-triggers every milestone from game_config except the one under test.
# Call this before ticking so only the target milestone can fire.
# Reading from config ensures the exclusion list stays current as milestones
# are added — without this, new milestones silently corrupt boredom assertions.
static func pretrigger_all_milestones_except(state: GameState, except_id: String) -> void:
	var config := load_game_config()
	for m: Dictionary in config.get("milestones", []):
		var mid: String = m.get("id", "")
		if mid != except_id and not state.triggered_milestones.has(mid):
			state.triggered_milestones.append(mid)


# Sets ideology_values[axis] to the exact score for the given integer rank
# using the formula — so tests remain valid if the formula changes.
static func set_ideology_rank(state: GameState, axis: String, rank: int) -> void:
	state.ideology_values[axis] = GameState.score_for_rank(float(rank))


# Zeroes all career-bonus-tracking fields so retire/new-run tests aren't
# affected by career state accumulated by earlier tests in the suite.
# Call this AFTER gm.retire() and BEFORE gm.start_new_run().
static func reset_career_bonus_tracking(career: CareerState) -> void:
	career.max_ideology_scores = {"nationalist": 0.0, "humanist": 0.0, "rationalist": 0.0}
	career.peak_power_production = 0.0
	career.best_run_credits = 0.0
	career.best_run_days = 0


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
