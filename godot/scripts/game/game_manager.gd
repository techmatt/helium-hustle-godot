extends Node

const SaveManager := preload("res://scripts/game/save_manager.gd")
const AchievementManager := preload("res://scripts/game/achievement_manager.gd")

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
var achievement_manager: AchievementManager
var career: CareerState = CareerState.new()
var last_deltas: Dictionary = {}
var current_speed_key: String = "1x"
var _run_peak_power: float = 0.0  # per-run max energy produced by buildings in a single tick

# Visibility snapshots for new-item indicator tracking (transient, not saved)
var _prev_visible_buildings: Dictionary = {}
var _prev_visible_commands: Dictionary = {}
var _prev_visible_nav: Dictionary = {}
var _prev_visible_research: Dictionary = {}
var _prev_visible_projects: Dictionary = {}

# Snapshots of career high-water marks at the start of this run, captured before any
# live updates occur. Used by the retire panel to detect "NEW" career records.
var run_start_career_peak_power: float = 0.0
var run_start_career_ideology_scores: Dictionary = {"nationalist": 0.0, "humanist": 0.0, "rationalist": 0.0}

# When true: skip reading/writing the save file on startup and during autosave.
# Set this before _ready() runs to prevent the initial load, or set it in _process()
# to block the autosave timer. Tests set it to protect the player's real save file.
var skip_save_load: bool = false

signal tick_completed
signal program_step_executed(program_index: int, entry_index: int, success: bool)
signal program_cycle_reset(program_index: int)
signal retirement_started(summary_data: Dictionary)
signal project_completed_notification(project_name: String)
signal achievement_unlocked(achievement_id: String)

var career_credits_bonus_fraction: float = 0.02
var career_ideology_headstart_fraction: float = 0.2
var career_boredom_resilience_base: float = 0.995
var career_boredom_resilience_period: float = 400.0

var _timer: Timer
var _autosave_timer: Timer
var _game_config: Dictionary
var _resources_data: Array = []
var _buildings_data: Array = []
var _commands_data: Array = []
var _research_data: Array = []
var _projects_data: Array = []
var _achievements_data: Array = []


func get_resource_display_name(short_name: String) -> String:
	for rdef: Dictionary in _resources_data:
		if rdef.get("short_name", "") == short_name:
			return rdef.get("name", short_name)
	return short_name


func _ready() -> void:
	var resources_data: Array = _load_json("res://data/resources.json")
	_resources_data = resources_data
	_buildings_data = _load_json("res://data/buildings.json")
	_game_config = _load_json("res://data/game_config.json")
	career_credits_bonus_fraction = float(_game_config.get("career_credits_bonus_fraction", 0.02))
	career_ideology_headstart_fraction = float(_game_config.get("career_ideology_headstart_fraction", 0.2))
	career_boredom_resilience_base = float(_game_config.get("career_boredom_resilience_base", 0.995))
	career_boredom_resilience_period = float(_game_config.get("career_boredom_resilience_period", 400.0))
	_commands_data = _load_json("res://data/commands.json")
	_research_data = _load_json("res://data/research.json")
	var events_data: Array = _load_json("res://data/events.json")
	_projects_data = _load_json("res://data/projects.json")
	_achievements_data = _load_json("res://data/achievements.json")

	sim = GameSimulation.new()
	sim.init(resources_data, _buildings_data, _commands_data, _game_config, _research_data)
	rate_tracker = ResourceRateTracker.new()
	sim.rate_tracker = rate_tracker

	event_manager = EventManager.new()
	event_manager.init(events_data, _game_config)

	project_manager = ProjectManager.new()
	project_manager.init(_projects_data, _game_config)

	achievement_manager = AchievementManager.new()
	achievement_manager.init(_achievements_data)

	# Connect telemetry signals before any state initialization
	event_manager.event_triggered.connect(func(eid: String) -> void:
		PlaytestLogger.log_event("event_triggered", {"event_id": eid})
	)
	event_manager.event_completed.connect(func(eid: String) -> void:
		var edef: Dictionary = event_manager.get_event_def(eid)
		if edef.get("category", "") == "story":
			PlaytestLogger.log_event("quest_completed", {"quest_id": eid})
	)
	event_manager.boredom_phase_changed.connect(func(_old: int, new_phase: int) -> void:
		PlaytestLogger.log_event("boredom_phase", {
			"phase": new_phase,
			"boredom_value": state.amounts.get("boredom", 0.0),
		})
	)
	project_manager.project_completed.connect(func(pid: String) -> void:
		var pdef: Dictionary = project_manager.get_project_def(pid)
		PlaytestLogger.log_event("project_completed", {"id": pid, "tier": pdef.get("tier", "")})
	)

	if skip_save_load:
		career = CareerState.new()
		state = GameState.new()
		_initialize_state()
		call_deferred("_fire_startup_events")
	else:
		var save_data: Variant = SaveManager.load_game()
		if save_data != null:
			career = CareerState.from_dict((save_data as Dictionary).get("career", {}))
			state = GameState.from_dict((save_data as Dictionary).get("run_state", {}))
			_restore_from_save()
			current_speed_key = (save_data as Dictionary).get("speed_key", "1x") as String
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

	get_tree().auto_accept_quit = false

	set_speed(current_speed_key)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		PlaytestLogger.finalize_run()
		_autosave()
		get_tree().quit()


func _restore_from_save() -> void:
	run_start_career_peak_power = career.peak_power_production
	run_start_career_ideology_scores = career.max_ideology_scores.duplicate()
	event_manager.reapply_career_unlocks(state, career)
	event_manager.on_game_start(state, career)  # sets _career reference; won't re-trigger fired events
	_apply_career_flags_to_run_state()
	sim.recalculate_caps(state)
	PlaytestLogger.start_run(state.run_number, career, state, sim.demand_system)
	_init_visibility_baseline()
	tick_completed.emit()


func _initialize_state() -> void:
	run_start_career_peak_power = career.peak_power_production
	run_start_career_ideology_scores = career.max_ideology_scores.duplicate()
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
	var _idle_entry := GameState.ProgramEntry.new()
	_idle_entry.command_shortname = "idle"
	_idle_entry.repeat_count = 1
	state.programs[0].commands = [_idle_entry]
	state.programs[0].processors_assigned = 1
	_run_peak_power = 0.0
	PlaytestLogger.start_run(state.run_number, career, state, sim.demand_system)
	_init_visibility_baseline()


func set_speed(speed_key: String) -> void:
	if speed_key == "1":
		speed_key = "1x"  # migrate old saves that stored "1" before the rename
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
		var costs: Dictionary = sim.get_scaled_costs(state, short_name)
		sim.buy_building(state, short_name)
		PlaytestLogger.log_event("building_purchased", {
			"id": short_name,
			"owned_count": state.buildings_owned.get(short_name, 0),
			"cost": costs,
		})
		if not career.lifetime_owned_building_ids.has(short_name):
			career.lifetime_owned_building_ids.append(short_name)
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
	PlaytestLogger.log_event("building_sold", {
		"id": short_name,
		"owned_count": state.buildings_owned.get(short_name, 0),
	})
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


func set_pad_paused(pad_idx: int, paused: bool) -> void:
	if pad_idx >= 0 and pad_idx < state.pads.size():
		state.pads[pad_idx].paused = paused
	tick_completed.emit()


func set_loading_priority(priority: Array) -> void:
	state.loading_priority = priority.duplicate()
	tick_completed.emit()


func get_buildings_data() -> Array:
	return _buildings_data


func get_resources_data() -> Array:
	return _resources_data


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
		var land_cost: int = sim.get_land_purchase_cost(state)
		sim.buy_land(state)
		PlaytestLogger.log_event("land_purchased", {
			"total_land": get_total_land(),
			"cost": land_cost,
		})
		tick_completed.emit()


func set_project_rate(project_id: String, resource_id: String, rate: float) -> void:
	project_manager.set_project_rate(state, project_id, resource_id, rate)
	tick_completed.emit()


func get_commands_data() -> Array:
	return _commands_data


# Resources visible in the sidebar. Always-visible set plus resources unlocked
# by owning a building this run or in a prior run, or by ever running a buy command.
const _ALWAYS_VISIBLE_RESOURCES: Array[String] = [
	"boredom", "eng", "proc", "land", "cred", "ti", "reg"
]
const _RESOURCE_UNLOCK_BUILDING: Dictionary = {
	"ice":  "ice_extractor",
	"he3":  "refinery",
	"cir":  "fabricator",
	"prop": "electrolysis",
	"sci":  "research_lab",
}
const _RESOURCE_UNLOCK_COMMAND: Dictionary = {
	"ice":  "buy_ice",
	"prop": "buy_propellant",
	"reg":  "buy_regolith",
	"ti":   "buy_titanium",
}

func get_visible_resources() -> Array[String]:
	var visible: Array[String] = _ALWAYS_VISIBLE_RESOURCES.duplicate()
	for res: String in _RESOURCE_UNLOCK_BUILDING:
		var bsn: String = _RESOURCE_UNLOCK_BUILDING[res]
		if state.buildings_owned.get(bsn, 0) > 0 \
				or career.lifetime_owned_building_ids.has(bsn):
			if not visible.has(res):
				visible.append(res)
	for res: String in _RESOURCE_UNLOCK_COMMAND:
		if career.lifetime_used_command_ids.has(_RESOURCE_UNLOCK_COMMAND[res]):
			if not visible.has(res):
				visible.append(res)
	return visible


# Always-visible buildings (show regardless of requires or lifetime ownership).
const _ALWAYS_VISIBLE_BUILDINGS: Array[String] = [
	"panel", "battery", "storage_depot", "data_center"
]

func _is_quest_gated(short_name: String) -> bool:
	for bdef: Dictionary in _buildings_data:
		if bdef.get("short_name", "") == short_name:
			return bdef.get("requires", {}).get("type", "none") == "quest"
	return false


func is_building_visible(short_name: String) -> bool:
	if GameSettings.show_all_cards:
		return true
	if _ALWAYS_VISIBLE_BUILDINGS.has(short_name):
		return true
	# Lifetime ownership overrides building-prereq gates but NOT event/quest gates.
	# Quest-gated buildings (requires.type == "quest") must be unlocked via the event
	# chain each run — the player must replay the event progression.
	if career.lifetime_owned_building_ids.has(short_name) and not _is_quest_gated(short_name):
		return true
	# Visible if its requires are currently satisfied
	return not sim.is_building_locked(state, short_name)


func is_command_visible(short_name: String) -> bool:
	if GameSettings.show_all_cards:
		return true
	if career.lifetime_used_command_ids.has(short_name):
		return true
	for cmd: Dictionary in _commands_data:
		if cmd.short_name == short_name:
			var req: Dictionary = cmd.get("requires", {})
			match req.get("type", "none"):
				"none":
					return true
				"building", "building_owned":
					return state.buildings_owned.get(req.get("value", ""), 0) > 0
				"research":
					return state.completed_research.has(req.get("value", ""))
			return false
	return false


func get_lifetime_used_command_ids() -> Array:
	return career.lifetime_used_command_ids.duplicate()


func get_research_data() -> Array:
	return _research_data


func get_run_peak_power() -> float:
	return _run_peak_power


func is_research_item_visible(item_id: String) -> bool:
	if GameSettings.show_all_cards:
		return true
	if career.lifetime_researched_ids.has(item_id):
		return true
	var item: Dictionary = {}
	for rd: Dictionary in _research_data:
		if rd.get("id", "") == item_id:
			item = rd
			break
	if item.is_empty():
		return false
	var visible_when: Dictionary = item.get("visible_when", {})
	if visible_when.is_empty():
		return true
	match visible_when.get("type", ""):
		"always":
			return true
		"event_seen":
			return state.seen_event_ids.has(visible_when.get("event_id", ""))
		"event_completed":
			var eid: String = visible_when.get("event_id", "")
			for inst: Dictionary in state.event_instances:
				if inst.get("id", "") == eid and inst.get("state", "") == "completed":
					return true
			return false
		"boredom_above":
			return state.amounts.get("boredom", 0.0) > float(visible_when.get("threshold", 0))
		"research_purchased":
			return state.completed_research.has(visible_when.get("research_id", ""))
		"building_count":
			var bid: String = visible_when.get("building_id", "")
			return state.buildings_owned.get(bid, 0) >= int(visible_when.get("count", 1))
		"shipments_completed":
			var total: int = state.total_shipments_completed + career.lifetime_shipments
			return total >= int(visible_when.get("count", 1))
		"quest_completed":
			var qid: String = visible_when.get("quest_id", "")
			if career.completed_quest_ids.has(qid):
				return true
			for inst: Dictionary in state.event_instances:
				if inst.get("id", "") == qid and inst.get("state", "") == "completed":
					return true
			return false
	return false


func purchase_research(research_id: String) -> void:
	if sim.can_purchase_research(state, research_id):
		var sci_cost: float = 0.0
		for rd: Dictionary in _research_data:
			if rd.get("id", "") == research_id:
				sci_cost = float(rd.get("cost", 0))
				break
		sim.purchase_research(state, research_id)
		PlaytestLogger.log_event("research_completed", {
			"id": research_id,
			"science_cost": sci_cost,
		})
		# Track in lifetime researched for Universal Research Archive
		if not career.lifetime_researched_ids.has(research_id):
			career.lifetime_researched_ids.append(research_id)
		tick_completed.emit()


# ── New-item indicator tracking ───────────────────────────────────────────────

func _snap_visible_buildings() -> Dictionary:
	var snap: Dictionary = {}
	for bdef: Dictionary in _buildings_data:
		var sn: String = bdef.get("short_name", "")
		if is_building_visible(sn):
			snap[sn] = true
	return snap


func _snap_visible_commands() -> Dictionary:
	var snap: Dictionary = {}
	for cmd: Dictionary in _commands_data:
		var sn: String = cmd.get("short_name", "")
		if is_command_visible(sn):
			snap[sn] = true
	return snap


func _snap_visible_nav() -> Dictionary:
	return {
		"retirement":  state.unlocked_nav_panels.has("retirement"),
		"projects":    state.unlocked_nav_panels.has("projects"),
		"ideologies":  state.unlocked_nav_panels.has("ideologies"),
		"launch_pad":  state.buildings_owned.get("launch_pad", 0) > 0,
		"research_lab": state.buildings_owned.get("research_lab", 0) > 0,
	}


func _snap_visible_research() -> Dictionary:
	var snap: Dictionary = {}
	for item: Dictionary in _research_data:
		var iid: String = item.get("id", "")
		if is_research_item_visible(iid):
			snap[iid] = true
	return snap


func _snap_visible_projects() -> Dictionary:
	var snap: Dictionary = {}
	for pid: String in state.enabled_projects:
		snap[pid] = true
	return snap


# Capture current visibility as the baseline. Items visible now will NOT be
# marked new — only items that become visible AFTER this call are marked.
func _init_visibility_baseline() -> void:
	_prev_visible_buildings = _snap_visible_buildings()
	_prev_visible_commands  = _snap_visible_commands()
	_prev_visible_nav       = _snap_visible_nav()
	_prev_visible_research  = _snap_visible_research()
	_prev_visible_projects  = _snap_visible_projects()


# Diff current visibility against baseline; add newly visible items to
# state.newly_revealed_*. Then update the baseline for the next tick.
func _check_new_indicators() -> void:
	if GameSettings.show_all_cards:
		_init_visibility_baseline()
		return

	var cur_b: Dictionary = _snap_visible_buildings()
	for sn: String in cur_b:
		if not _prev_visible_buildings.has(sn):
			state.newly_revealed_buildings[sn] = true
	_prev_visible_buildings = cur_b

	var cur_c: Dictionary = _snap_visible_commands()
	for sn: String in cur_c:
		if not _prev_visible_commands.has(sn):
			state.newly_revealed_commands[sn] = true
	_prev_visible_commands = cur_c

	var cur_n: Dictionary = _snap_visible_nav()
	for pid: String in cur_n:
		if cur_n[pid] and not _prev_visible_nav.get(pid, false):
			state.newly_revealed_nav[pid] = true
	_prev_visible_nav = cur_n

	var cur_r: Dictionary = _snap_visible_research()
	for rid: String in cur_r:
		if not _prev_visible_research.has(rid):
			state.newly_revealed_research[rid] = true
	_prev_visible_research = cur_r

	var cur_p: Dictionary = _snap_visible_projects()
	for pid: String in cur_p:
		if not _prev_visible_projects.has(pid):
			state.newly_revealed_projects[pid] = true
	_prev_visible_projects = cur_p


# ── Tick ──────────────────────────────────────────────────────────────────────

# Executes a full tick against the live state without using the timer.
# Runs sim + event_manager + project_manager in the same order as _on_tick().
# Pass debug_no_boredom = true to suppress boredom accumulation (useful in
# tests that assert on exact boredom values).
# Does NOT emit tick_completed, trigger autosave, or check boredom >= 1000.
func execute_tick(debug_no_boredom: bool = false) -> void:
	sim.tick(state, debug_no_boredom)
	event_manager.tick(state)
	project_manager.tick(state, career)


func _on_tick() -> void:
	sim.tick(state, GameSettings.debug_no_boredom)
	event_manager.tick(state)
	project_manager.tick(state, career)
	# On the very first tick, re-baseline to capture anything unlocked by startup events.
	# This ensures tick-0-visible items are NOT marked new. On all subsequent ticks, diff.
	if state.current_day == 1:
		_init_visibility_baseline()
	else:
		_check_new_indicators()
	last_deltas = sim.last_gross_deltas.duplicate()
	for sn: String in sim.pending_executed_commands:
		if not career.lifetime_used_command_ids.has(sn):
			career.lifetime_used_command_ids.append(sn)
	for event in sim.pending_program_events:
		if event.type == "step":
			program_step_executed.emit(event.program_index, event.entry_index, event.success)
		elif event.type == "cycle_reset":
			program_cycle_reset.emit(event.program_index)
	for notif in project_manager.pending_completion_notifications:
		event_manager.push_notification("Project Complete: " + notif.name, state.current_day)
		project_completed_notification.emit(notif.name)
	# Log shipments and check shipment-based achievements
	for shipment in sim.pending_shipments:
		PlaytestLogger.log_event("shipment_launched", {
			"resource": shipment.resource,
			"cargo": shipment.get("cargo", 0.0),
			"demand": shipment.demand,
			"revenue": shipment.revenue,
			"spec": state.speculators.get(shipment.resource, 0.0),
		})
		var newly: Array[String] = achievement_manager.check_shipment_conditions(
			state, career, float(shipment.revenue), float(shipment.demand)
		)
		for aid: String in newly:
			_unlock_achievement(aid)
	# Check tick-based achievements
	var tick_new: Array[String] = achievement_manager.check_tick_conditions(
		state, career, sim.tick_produced, sim.tick_consumed
	)
	for aid: String in tick_new:
		_unlock_achievement(aid)
	# Track peak building energy production for career bonus
	var tick_eng: float = sim.tick_produced.get("eng", 0.0)
	if tick_eng > _run_peak_power:
		_run_peak_power = tick_eng
	if tick_eng > career.peak_power_production:
		career.peak_power_production = tick_eng
	# Update career max ideology ranks/scores and log any rank changes
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		var current_rank: int = state.get_ideology_rank(axis)
		if current_rank > int(career.max_ideology_ranks.get(axis, 0)):
			career.max_ideology_ranks[axis] = current_rank
		var abs_score: float = abs(state.ideology_values.get(axis, 0.0))
		if abs_score > float(career.max_ideology_scores.get(axis, 0.0)):
			career.max_ideology_scores[axis] = abs_score
	PlaytestLogger.check_ideology_changes(state)
	# Periodic snapshot every 100 ticks
	if state.current_day > 0 and state.current_day % 100 == 0:
		PlaytestLogger.log_snapshot(state, sim.demand_system)
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

	# Capture pre-update career highs for "new record" display on retirement screen
	var pre_best_credits: float = career.best_run_credits
	var pre_best_days: int = career.best_run_days
	var pre_peak_power: float = career.peak_power_production
	var pre_max_ideology_scores: Dictionary = career.max_ideology_scores.duplicate()

	career.lifetime_credits_earned += run_credits
	career.lifetime_shipments += run_shipments
	career.lifetime_days_survived += run_days
	career.lifetime_buildings_built += run_buildings
	career.lifetime_research_completed += run_research
	career.best_run_days = maxi(career.best_run_days, run_days)
	career.best_run_credits = maxf(career.best_run_credits, run_credits)
	career.best_run_shipments = maxi(career.best_run_shipments, run_shipments)
	# peak_power_production is already updated live each tick; finalize ideology scores
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		var abs_score: float = abs(state.ideology_values.get(axis, 0.0))
		if abs_score > float(career.max_ideology_scores.get(axis, 0.0)):
			career.max_ideology_scores[axis] = abs_score

	# Update event persistence
	# Propagate only properly-seen events (completed or acknowledged) — NOT merely active
	# instances. Active-but-uncompleted events (e.g. ideology_unlock waiting for research)
	# must not enter career.seen_event_ids, because reapply_career_unlocks would
	# re-apply their unlocks on the next run even though the condition was never met.
	for eid: String in state.seen_event_ids:
		if not career.seen_event_ids.has(eid):
			career.seen_event_ids.append(eid)
	# Track completed story quests for repeat-run resumption (separate pass)
	for inst: Dictionary in state.event_instances:
		if inst.get("state", "") != "completed":
			continue
		var eid: String = inst.get("id", "")
		if eid.is_empty():
			continue
		var edef: Dictionary = event_manager.get_event_def(eid)
		if edef.get("category", "") == "story" and not career.completed_quest_ids.has(eid):
			career.completed_quest_ids.append(eid)

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
		"ideology_ranks": {
			"nationalist": state.get_ideology_rank("nationalist"),
			"humanist": state.get_ideology_rank("humanist"),
			"rationalist": state.get_ideology_rank("rationalist"),
		},
		"career_retirements": career.total_retirements + 1,
		"career_total_days": career.lifetime_days_survived,
		# Career highs (post-update) used by bonus preview
		"career_best_credits": career.best_run_credits,
		"career_best_days": career.best_run_days,
		"career_peak_power": career.peak_power_production,
		"career_max_ideology_scores": career.max_ideology_scores.duplicate(),
		# Pre-update highs for "NEW" indicator display
		"pre_best_credits": pre_best_credits,
		"pre_best_days": pre_best_days,
		"pre_peak_power": pre_peak_power,
		"pre_max_ideology_scores": pre_max_ideology_scores,
		# This run's peak power (for "from peak power" display)
		"run_peak_power": _run_peak_power,
	}

	# Increment career counters
	career.total_retirements += 1
	career.run_number += 1

	PlaytestLogger.log_event("retirement", {
		"reason": "voluntary" if voluntary else "forced",
		"final_day": run_days,
		"final_credits": run_credits,
		"final_boredom": state.amounts.get("boredom", 0.0),
	})
	PlaytestLogger.finalize_run()

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

	# --- Career bonus application (steps 4–6 of run init sequence) ---

	# Step 4: Ideology head start — fraction of best continuous rank per axis
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		var max_score: float = float(career.max_ideology_scores.get(axis, 0.0))
		if max_score > 0.0:
			var max_continuous: float = GameState.continuous_rank_for_score(max_score)
			var starting_rank: float = max_continuous * career_ideology_headstart_fraction
			var starting_score: float = GameState.score_for_rank(starting_rank)
			state.ideology_values[axis] = starting_score

	# Step 5: Starting credits bonus — fraction of best run credits (see game_config.json)
	var credits_bonus: float = floor(career.best_run_credits * career_credits_bonus_fraction)
	if credits_bonus > 0.0:
		state.amounts["cred"] = state.amounts.get("cred", 0.0) + credits_bonus

	# Step 6: Career modifiers derived from CareerState
	# buy_power_mult: scales Buy Power command output and cost
	var buy_power_mult: float = 1.0 + maxf(0.0, career.peak_power_production - 100.0) * 0.01
	state.set_modifier("buy_power_mult", buy_power_mult)
	# boredom_resilience_mult: reduces boredom rate based on best survival
	var boredom_resilience_mult: float = pow(career_boredom_resilience_base, career.best_run_days / career_boredom_resilience_period)
	state.set_modifier("boredom_resilience_mult", boredom_resilience_mult)

	run_start_career_peak_power = career.peak_power_production
	run_start_career_ideology_scores = career.max_ideology_scores.duplicate()
	_run_peak_power = 0.0

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
					state.buildings_bonus[bsn] = state.buildings_bonus.get(bsn, 0) + count
					for bdef: Dictionary in _buildings_data:
						if bdef.short_name == bsn:
							state.amounts["land"] = state.amounts.get("land", 0.0) - float(bdef.land) * count
							break
		state.completed_projects_this_run.append(pid)

	# Load persistent project progress from career
	for pid: String in career.project_progress:
		state.project_invested[pid] = (career.project_progress[pid] as Dictionary).duplicate()

	# Apply achievement rewards from prior runs
	achievement_manager.apply_all_rewards(state, career, _buildings_data)

	# First processor always starts assigned to program slot 0, running Idle
	var idle_entry := GameState.ProgramEntry.new()
	idle_entry.command_shortname = "idle"
	idle_entry.repeat_count = 1
	state.programs[0].commands = [idle_entry]
	state.programs[0].processors_assigned = 1

	# Re-initialize subsystems for the new state
	rate_tracker = ResourceRateTracker.new()
	sim.rate_tracker = rate_tracker
	sim.recalculate_caps(state)
	sim.demand_system.initialize_demand(state)

	# Re-apply unlock effects from all previously completed events
	event_manager.reapply_career_unlocks(state, career)

	# Fire game_start events for the new run
	event_manager.on_game_start(state, career)

	_apply_career_flags_to_run_state()

	PlaytestLogger.start_run(state.run_number, career, state, sim.demand_system)

	_init_visibility_baseline()
	set_speed("1x")
	tick_completed.emit()
	SaveManager.save_game(career, state, current_speed_key)


func _unlock_achievement(achievement_id: String) -> void:
	if career.achievements.has(achievement_id):
		return
	career.achievements.append(achievement_id)
	achievement_manager.apply_reward(state, achievement_id, _buildings_data)
	sim.recalculate_caps(state)
	var def: Dictionary = achievement_manager.get_def(achievement_id)
	var notif: String = "Achievement Unlocked: %s — %s" % [
		def.get("name", achievement_id),
		def.get("reward_description", "")
	]
	PlaytestLogger.log_event("achievement_earned", {
		"id": achievement_id,
		"reward_summary": def.get("reward_description", ""),
	})
	event_manager.push_notification(notif, state.current_day)
	achievement_unlocked.emit(achievement_id)


func _apply_career_flags_to_run_state() -> void:
	if career.career_flags.get("ai_consciousness_completed", false):
		state.flags["ai_consciousness_active"] = true
		state.set_modifier("ai_consciousness_boredom_rate_mult",
			float(career.career_flags.get("ai_consciousness_boredom_rate_mult", 1.0)))
		state.flags["ai_consciousness_command_boredom"] = \
			career.career_flags.get("ai_consciousness_command_boredom", {})
	if career.career_flags.get("microwave_power_completed", false):
		state.flags["microwave_power_active"] = true
	if career.career_flags.get("chemical_energy_completed", false):
		state.flags["chemical_energy_completed"] = true
	if career.career_flags.get("research_archive_completed", false):
		state.flags["research_archive_active"] = true
		state.set_modifier("research_archive_discount_mult",
			float(career.career_flags.get("research_archive_discount_mult", 0.75)))
		# Copy eligible research IDs for cost discount lookup in simulation
		state.flags["archive_eligible_research"] = career.lifetime_researched_ids.duplicate()


func _autosave() -> void:
	if skip_save_load:
		return
	if state != null and sim != null:
		SaveManager.save_game(career, state, current_speed_key)


func set_save_path(path: String) -> void:
	SaveManager.save_path = path


func save_to_dict() -> Dictionary:
	return {
		"version": SaveManager.SAVE_VERSION,
		"career": career.to_dict(),
		"run_state": state.to_dict(),
		"speed_key": current_speed_key,
		"timestamp": Time.get_datetime_string_from_system(),
	}


func load_from_dict(data: Dictionary) -> void:
	career = CareerState.from_dict(data.get("career", {}))
	state = GameState.from_dict(data.get("run_state", {}))
	_restore_from_save()
	set_speed(data.get("speed_key", "1x") as String)


func _fire_startup_events() -> void:
	event_manager.on_game_start(state, career)


func _debug_clear_save() -> void:
	SaveManager.clear_save()
	career = CareerState.new()
	state = GameState.new()
	_initialize_state()
	event_manager.on_game_start(state, career)
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
