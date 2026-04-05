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
		"career_credits": roundi(career.lifetime_credits_earned),
		"completed_projects": career.completed_projects.duplicate(),
		"achievements": career.achievements.duplicate(),
	})


# Write a single JSONL entry. tick is taken from the stored state reference.
# Rounds all numeric leaf values before serializing.
func log_event(type: String, data: Dictionary) -> void:
	if GameManager.skip_save_load or _file == null:
		return
	var tick: int = _state_ref.current_day if _state_ref != null else 0
	_file.store_line(JSON.stringify({"tick": tick, "type": type, "data": _round_dict(data)}))


# Write a compact resource/building/ideology snapshot entry.
func log_snapshot(state: GameState, demand_system: DemandSystem) -> void:
	if GameManager.skip_save_load or _file == null:
		return

	# ── Resources: [current, cap, rate] — omit if current=0 and rate=0 ────────
	var res_dict: Dictionary = {}
	var uncapped := {"cred": true, "sci": true, "land": true, "boredom": true}
	for res: String in ["eng", "proc", "land", "cred", "ti", "reg", "ice", "he3", "cir", "prop", "sci", "boredom"]:
		var current: float = state.amounts.get(res, 0.0)
		var rate: float = GameManager.rate_tracker.get_net_instant(res) if GameManager.rate_tracker != null else 0.0
		if absf(current) < 0.05 and absf(rate) < 0.05:
			continue
		var cap_val: float = state.caps.get(res, INF)
		var cap_out: int = -1 if (cap_val == INF or uncapped.has(res)) else roundi(cap_val)
		res_dict[res] = [roundi(current), cap_out, snappedf(rate, 0.1)]

	# ── Buildings ─────────────────────────────────────────────────────────────
	var bldg_dict: Dictionary = {}
	for bsn: String in state.buildings_owned:
		var count: int = state.buildings_owned[bsn]
		if count > 0:
			bldg_dict[bsn] = count

	# ── Demand: only nonzero tradeable resources, rounded to 1 decimal ────────
	var demand_dict: Dictionary = {}
	for res: String in GameState.TRADEABLE_RESOURCES:
		var d: float = snappedf(state.demand.get(res, 0.0), 0.1)
		if absf(d) >= 0.05:
			demand_dict[res] = d

	# ── Build snapshot data ───────────────────────────────────────────────────
	var data: Dictionary = {}
	data["res"] = res_dict
	if not bldg_dict.is_empty():
		data["bldg"] = bldg_dict
	if not demand_dict.is_empty():
		data["demand"] = demand_dict

	# Speculators: only if count > 0
	if state.speculator_count >= 0.5:
		data["spec"] = [roundi(state.speculator_count), state.speculator_target]

	# Processors: only if any assigned
	if state.total_processors > 0:
		var assignments: Array = []
		for prog: GameState.ProgramData in state.programs:
			assignments.append(prog.processors_assigned)
		data["proc"] = [state.total_processors, assignments]

	# Ideology: compact abbrev → raw score, omit axes at 0, omit block if all zero
	var ideo_dict: Dictionary = {}
	var abbrevs := {"nationalist": "nat", "humanist": "hum", "rationalist": "rat"}
	for axis: String in ["humanist", "nationalist", "rationalist"]:
		var val: float = state.ideology_values.get(axis, 0.0)
		if absf(val) >= 0.5:
			ideo_dict[abbrevs[axis]] = roundi(val)
	if not ideo_dict.is_empty():
		data["ideo"] = ideo_dict

	# Research: flat array, omit if empty
	if not state.completed_research.is_empty():
		data["research"] = state.completed_research.duplicate()

	# Overflow: only resources with non-zero rolling average
	var overflow_dict: Dictionary = {}
	for res: String in state.overflow_rolling_avg:
		var oval: float = state.overflow_rolling_avg[res]
		if oval >= 0.5:
			overflow_dict[res] = roundi(oval)
	if not overflow_dict.is_empty():
		data["overflow"] = overflow_dict

	# Lifetime boredom accumulators (omit zero values)
	var lbore: Dictionary = {}
	for key: String in state.lifetime_boredom_sources:
		var val: float = state.lifetime_boredom_sources[key]
		if absf(val) >= 0.5:
			lbore[key] = roundi(val)
	if not lbore.is_empty():
		data["lifetime_boredom"] = lbore

	# Lifetime credit accumulators (omit zero values)
	var lcred: Dictionary = {}
	for key: String in state.lifetime_credit_sources:
		var val: float = state.lifetime_credit_sources[key]
		if absf(val) >= 0.5:
			lcred[key] = roundi(val)
	if not lcred.is_empty():
		data["lifetime_credits"] = lcred

	log_event("snapshot", data)


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
				"value": roundi(state.ideology_values.get(axis, 0.0)),
			})
			_prev_ideology_ranks[axis] = current_rank


# Recursively round all numeric leaf values in a dictionary.
# Floats that are effectively integers round to int; others snap to 0.1.
func _round_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		out[k] = _round_value(d[k])
	return out


func _round_value(v: Variant) -> Variant:
	if v is float:
		# If it's effectively an integer value, store as int
		if absf(v - roundf(v)) < 0.001:
			return roundi(v)
		return snappedf(v, 0.1)
	if v is Dictionary:
		return _round_dict(v)
	if v is Array:
		var out: Array = []
		for item in v:
			out.append(_round_value(item))
		return out
	return v


func _get_logs_dir() -> String:
	var project_dir: String = ProjectSettings.globalize_path("res://")
	# Strip trailing slash so get_base_dir() steps up one level correctly
	if project_dir.ends_with("/") or project_dir.ends_with("\\"):
		project_dir = project_dir.left(project_dir.length() - 1)
	var repo_root: String = project_dir.get_base_dir()
	return repo_root.path_join("logs")
