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

# When true: skip reading/writing the save file on startup and during autosave.
# Set this before _ready() runs to prevent the initial load, or set it in _process()
# to block the autosave timer. Tests set it to protect the player's real save file.
var skip_save_load: bool = false

signal tick_completed
signal program_step_executed(program_index: int, entry_index: int, success: bool)
signal program_cycle_reset(program_index: int)
signal milestone_triggered(milestone_id: String, label: String, boredom_reduction: float)
signal retirement_started(summary_data: Dictionary)
signal project_completed_notification(project_name: String)
signal achievement_unlocked(achievement_id: String)

var _timer: Timer
var _autosave_timer: Timer
var _game_config: Dictionary
var _buildings_data: Array = []
var _commands_data: Array = []
var _research_data: Array = []
var _projects_data: Array = []
var _achievements_data: Array = []


func _ready() -> void:
	var resources_data: Array = _load_json("res://data/resources.json")
	_buildings_data = _load_json("res://data/buildings.json")
	_game_config = _load_json("res://data/game_config.json")
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

	set_speed(current_speed_key)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_autosave()
		get_tree().quit()


func _restore_from_save() -> void:
	event_manager.reapply_career_unlocks(state, career)
	event_manager.on_game_start(state, career)  # sets _career reference; won't re-trigger fired events
	_apply_career_flags_to_run_state()
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
		sim.buy_building(state, short_name)
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

func is_building_visible(short_name: String) -> bool:
	if GameSettings.show_all_cards:
		return true
	if _ALWAYS_VISIBLE_BUILDINGS.has(short_name):
		return true
	if career.lifetime_owned_building_ids.has(short_name):
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
		sim.purchase_research(state, research_id)
		# Track in lifetime researched for Universal Research Archive
		if not career.lifetime_researched_ids.has(research_id):
			career.lifetime_researched_ids.append(research_id)
		tick_completed.emit()


# Executes a full tick against the live state without using the timer.
# Runs sim + event_manager + project_manager in the same order as _on_tick().
# Pass debug_no_boredom = true to suppress boredom accumulation (useful in
# tests that assert on exact boredom values after milestone reductions).
# Does NOT emit tick_completed, trigger autosave, or check boredom >= 1000.
func execute_tick(debug_no_boredom: bool = false) -> void:
	sim.tick(state, debug_no_boredom)
	event_manager.tick(state)
	project_manager.tick(state, career)


func _on_tick() -> void:
	sim.tick(state, GameSettings.debug_no_boredom)
	event_manager.tick(state)
	project_manager.tick(state, career)
	last_deltas = sim.last_gross_deltas.duplicate()
	for sn: String in sim.pending_executed_commands:
		if not career.lifetime_used_command_ids.has(sn):
			career.lifetime_used_command_ids.append(sn)
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
	# Check shipment-based achievements
	for shipment in sim.pending_shipments:
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
	# Update career max ideology ranks
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		var current_rank: int = state.get_ideology_rank(axis)
		if current_rank > int(career.max_ideology_ranks.get(axis, 0)):
			career.max_ideology_ranks[axis] = current_rank
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
		# Track completed story quests for repeat-run resumption
		if inst.get("state", "") == "completed":
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

	# First processor always starts assigned to program slot 0
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
	event_manager.push_notification(notif, state.current_day)
	achievement_unlocked.emit(achievement_id)


func _apply_career_flags_to_run_state() -> void:
	if career.career_flags.get("ai_consciousness_completed", false):
		state.flags["ai_consciousness_active"] = true
	if career.career_flags.get("microwave_power_completed", false):
		state.flags["microwave_power_active"] = true
	if career.career_flags.get("research_archive_completed", false):
		state.flags["research_archive_active"] = true
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
