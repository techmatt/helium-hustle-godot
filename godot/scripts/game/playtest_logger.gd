extends Node

var _file: FileAccess = null
var _state_ref: GameState = null
var _demand_system_ref: DemandSystem = null
var _prev_ideology_ranks: Dictionary = {"nationalist": 0, "humanist": 0, "rationalist": 0}


# Called at the start of each run (fresh or new-run-after-retirement).
# Opens the log file and writes the run_start event.
func start_run(run_number: int, career: CareerState, state: GameState, demand_system: DemandSystem) -> void:
	if GameManager.skip_save_load:
		return
	if _file != null:
		finalize_run()
	_state_ref = state
	_demand_system_ref = demand_system
	_prev_ideology_ranks = {"nationalist": 0, "humanist": 0, "rationalist": 0}

	var logs_dir := _get_logs_dir()
	DirAccess.make_dir_recursive_absolute(logs_dir)
	var path := logs_dir.path_join("run_%d.jsonl" % run_number)
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("PlaytestLogger: cannot open log file: " + path)
		return

	log_event("run_start", {
		"run_number": run_number,
		"career_retirements": career.total_retirements,
		"career_credits": career.lifetime_credits_earned,
		"completed_projects": career.completed_projects.duplicate(),
		"achievements": career.achievements.duplicate(),
	})


# Write a single JSONL entry. tick is taken from the stored state reference.
func log_event(type: String, data: Dictionary) -> void:
	if GameManager.skip_save_load or _file == null:
		return
	var tick: int = _state_ref.current_day if _state_ref != null else 0
	_file.store_line(JSON.stringify({"tick": tick, "type": type, "data": data}))


# Write a full resource/building/ideology snapshot entry.
func log_snapshot(state: GameState, demand_system: DemandSystem) -> void:
	if GameManager.skip_save_load or _file == null:
		return

	var resources_dict: Dictionary = {}
	for res: String in ["boredom", "eng", "proc", "land", "cred", "ti", "reg", "ice", "he3", "cir", "prop", "sci"]:
		var cap_val: float = state.caps.get(res, INF)
		resources_dict[res] = {
			"current": state.amounts.get(res, 0.0),
			"cap": cap_val if cap_val != INF else -1.0,
			"net_rate": GameManager.rate_tracker.get_net_instant(res) if GameManager.rate_tracker != null else 0.0,
		}

	var buildings_dict: Dictionary = {}
	for bsn: String in state.buildings_owned:
		var count: int = state.buildings_owned[bsn]
		if count > 0:
			buildings_dict[bsn] = count

	var processors_assigned: Array = []
	for prog: GameState.ProgramData in state.programs:
		processors_assigned.append(prog.processors_assigned)

	var ideology_dict: Dictionary = {}
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		ideology_dict[axis] = {
			"value": state.ideology_values.get(axis, 0.0),
			"rank": state.get_ideology_rank(axis),
		}

	var demand_dict: Dictionary = {}
	for res: String in GameState.TRADEABLE_RESOURCES:
		demand_dict[res] = state.demand.get(res, 0.0)

	log_event("snapshot", {
		"resources": resources_dict,
		"credits": {
			"current": state.amounts.get("cred", 0.0),
			"cumulative_this_run": state.cumulative_resources_earned.get("cred", 0.0),
		},
		"boredom": {
			"current": state.amounts.get("boredom", 0.0),
			"rate": GameManager.rate_tracker.get_net_instant("boredom") if GameManager.rate_tracker != null else 0.0,
		},
		"buildings": buildings_dict,
		"demand": demand_dict,
		"speculators": {
			"count": state.speculator_count,
			"target": state.speculator_target,
		},
		"ideology": ideology_dict,
		"processors": {
			"total": state.total_processors,
			"assigned": processors_assigned,
		},
	})


# Called on retirement and app close. Writes a final snapshot then closes the file.
func finalize_run() -> void:
	if _file == null:
		return
	if _state_ref != null and _demand_system_ref != null:
		log_snapshot(_state_ref, _demand_system_ref)
	_file.close()
	_file = null
	_state_ref = null
	_demand_system_ref = null


# Compare current ideology ranks to stored previous ranks and log any changes.
# Call once per tick after ideology values may have changed.
func check_ideology_changes(state: GameState) -> void:
	if GameManager.skip_save_load or _file == null:
		return
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		var current_rank: int = state.get_ideology_rank(axis)
		var prev_rank: int = _prev_ideology_ranks.get(axis, 0)
		if current_rank != prev_rank:
			log_event("ideology_rank_change", {
				"axis": axis,
				"old_rank": prev_rank,
				"new_rank": current_rank,
				"value": state.ideology_values.get(axis, 0.0),
			})
			_prev_ideology_ranks[axis] = current_rank


func _get_logs_dir() -> String:
	var project_dir: String = ProjectSettings.globalize_path("res://")
	# Strip trailing slash so get_base_dir() steps up one level correctly
	if project_dir.ends_with("/") or project_dir.ends_with("\\"):
		project_dir = project_dir.left(project_dir.length() - 1)
	var repo_root: String = project_dir.get_base_dir()
	return repo_root.path_join("logs")
