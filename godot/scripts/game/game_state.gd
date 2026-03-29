class_name GameState
extends RefCounted

class ProgramEntry:
	var command_shortname: String = ""
	var repeat_count: int = 1
	var current_progress: int = 0
	var failed_this_cycle: bool = false

	func to_dict() -> Dictionary:
		return {
			"command_shortname": command_shortname,
			"repeat_count": repeat_count,
			"current_progress": current_progress,
			"failed_this_cycle": failed_this_cycle,
		}

	static func from_dict(data: Dictionary) -> ProgramEntry:
		var e := ProgramEntry.new()
		e.command_shortname = data.get("command_shortname", "")
		e.repeat_count = int(data.get("repeat_count", 1))
		e.current_progress = int(data.get("current_progress", 0))
		e.failed_this_cycle = bool(data.get("failed_this_cycle", false))
		return e


class ProgramData:
	var commands: Array = []  # Array of ProgramEntry
	var processors_assigned: int = 0
	var instruction_pointer: int = 0

	func to_dict() -> Dictionary:
		var cmds: Array = []
		for entry: ProgramEntry in commands:
			cmds.append(entry.to_dict())
		return {
			"processors_assigned": processors_assigned,
			"instruction_pointer": instruction_pointer,
			"commands": cmds,
		}

	static func from_dict(data: Dictionary) -> ProgramData:
		var p := ProgramData.new()
		p.processors_assigned = int(data.get("processors_assigned", 0))
		p.instruction_pointer = int(data.get("instruction_pointer", 0))
		for cmd_data in data.get("commands", []):
			p.commands.append(ProgramEntry.from_dict(cmd_data))
		return p


class LaunchPadData:
	var resource_type: String = "he3"
	var cargo_loaded: float = 0.0
	var status: int = 0   # use GameState.PAD_* constants
	var cooldown_ticks: int = 0

	func to_dict() -> Dictionary:
		return {
			"resource_type": resource_type,
			"cargo_loaded": cargo_loaded,
			"status": status,
			"cooldown_ticks": cooldown_ticks,
		}

	static func from_dict(data: Dictionary) -> LaunchPadData:
		var pad := LaunchPadData.new()
		pad.resource_type = data.get("resource_type", "he3")
		pad.cargo_loaded = float(data.get("cargo_loaded", 0.0))
		pad.status = int(data.get("status", 0))
		pad.cooldown_ticks = int(data.get("cooldown_ticks", 0))
		return pad


class LaunchRecord:
	var resource_type: String = ""
	var quantity: float = 0.0
	var credits_earned: float = 0.0
	var tick: int = 0
	var notification_message: String = ""  # non-empty = rival dump notification, not a launch

	func to_dict() -> Dictionary:
		return {
			"resource_type": resource_type,
			"quantity": quantity,
			"credits_earned": credits_earned,
			"tick": tick,
			"notification_message": notification_message,
		}

	static func from_dict(data: Dictionary) -> LaunchRecord:
		var r := LaunchRecord.new()
		r.resource_type = data.get("resource_type", "")
		r.quantity = float(data.get("quantity", 0.0))
		r.credits_earned = float(data.get("credits_earned", 0.0))
		r.tick = int(data.get("tick", 0))
		r.notification_message = data.get("notification_message", "")
		return r


const TRADEABLE_RESOURCES: Array = ["he3", "ti", "cir", "prop"]

# Pad status constants
const PAD_EMPTY     = 0
const PAD_LOADING   = 1
const PAD_FULL      = 2
const PAD_LAUNCHING = 3
const PAD_COOLDOWN  = 4

var amounts: Dictionary = {}          # {short_name: float}
var caps: Dictionary = {}             # {short_name: float}  INF = no cap
var buildings_owned: Dictionary = {}  # {short_name: int}
var buildings_active: Dictionary = {} # {short_name: int}  defaults to owned if absent
var current_day: int = 0
var programs: Array = []              # Array of ProgramData, always 5 slots
var pads: Array = []                  # Array of LaunchPadData
var loading_priority: Array = ["he3", "ti", "cir", "prop"]
var launch_history: Array = []        # Array of LaunchRecord, max 5
var completed_research: Array = []    # Array of String research IDs purchased this run
var land_purchases: int = 0           # number of times Buy Land has been used this run

# Event system — per-run state
var event_instances: Array[Dictionary] = []
var cumulative_resources_earned: Dictionary = {}  # resource short_name -> float
var total_shipments_completed: int = 0
var current_boredom_phase: int = 1
var unlocked_buildings: Array[String] = []     # buildings unlocked via event effects
var enabled_projects: Array[String] = []       # projects enabled via event effects
var flags: Dictionary = {}                      # named boolean flags set by events
var unlocked_nav_panels: Array[String] = []    # nav panel ids revealed via event effects
var triggered_milestones: Array[String] = []   # milestone ids fired this run

# Demand system — all reset on retirement
var demand: Dictionary = {}                    # resource → current demand float [0.01, 1.0]
var demand_promote: Dictionary = {}            # resource → accumulated promote effect
var demand_rival: Dictionary = {}              # resource → accumulated rival pressure
var demand_launch: Dictionary = {}             # resource → accumulated shipment saturation
var demand_perlin_seeds: Dictionary = {}       # resource → float noise offset
var demand_perlin_freq: Dictionary = {}        # resource → float noise frequency
var demand_history: Dictionary = {}            # resource → Array of last ~200 demand values

var speculator_count: float = 0.0
var speculator_target: String = ""
var speculator_burst_number: int = 0
var speculator_next_burst_tick: int = 200
var speculator_revenue_tracking: Dictionary = {}  # resource → cumulative base-value shipped

var rival_next_dump_tick: Dictionary = {}      # rival_id → int tick

# Event system — persistent across retirements
var seen_event_ids: Array[String] = []
var highest_completed_story_quest: String = ""
var run_number: int = 1

var total_processors: int:
	get: return buildings_active.get("data_center", buildings_owned.get("data_center", 0))

var unassigned_processors: int:
	get:
		var assigned: int = 0
		for p: ProgramData in programs:
			assigned += p.processors_assigned
		return total_processors - assigned


func _init() -> void:
	for _i in range(5):
		programs.append(ProgramData.new())


func to_dict() -> Dictionary:
	var programs_arr: Array = []
	for prog: ProgramData in programs:
		programs_arr.append(prog.to_dict())
	var pads_arr: Array = []
	for pad: LaunchPadData in pads:
		pads_arr.append(pad.to_dict())
	var history_arr: Array = []
	for rec: LaunchRecord in launch_history:
		history_arr.append(rec.to_dict())
	return {
		# Core
		"amounts": amounts.duplicate(),
		"current_day": current_day,
		"run_number": run_number,

		# Buildings
		"buildings_owned": buildings_owned.duplicate(),
		"buildings_active": buildings_active.duplicate(),
		"unlocked_buildings": Array(unlocked_buildings),

		# Programs
		"programs": programs_arr,

		# Launch pads
		"pads": pads_arr,
		"loading_priority": loading_priority.duplicate(),
		"launch_history": history_arr,
		"total_shipments_completed": total_shipments_completed,

		# Research
		"completed_research": Array(completed_research),

		# Cumulative tracking
		"cumulative_resources_earned": cumulative_resources_earned.duplicate(),

		# Milestones
		"triggered_milestones": Array(triggered_milestones),

		# Boredom
		"current_boredom_phase": current_boredom_phase,

		# Land
		"land_purchases": land_purchases,

		# Demand system
		"demand": demand.duplicate(),
		"demand_promote": demand_promote.duplicate(),
		"demand_rival": demand_rival.duplicate(),
		"demand_launch": demand_launch.duplicate(),
		"demand_perlin_seeds": demand_perlin_seeds.duplicate(),
		"demand_perlin_freq": demand_perlin_freq.duplicate(),
		"demand_history": demand_history.duplicate(true),

		# Speculators
		"speculator_count": speculator_count,
		"speculator_target": speculator_target,
		"speculator_burst_number": speculator_burst_number,
		"speculator_next_burst_tick": speculator_next_burst_tick,
		"speculator_revenue_tracking": speculator_revenue_tracking.duplicate(),

		# Rivals
		"rival_next_dump_tick": rival_next_dump_tick.duplicate(),

		# Events
		"event_instances": _serialize_event_instances(),
		"seen_event_ids": Array(seen_event_ids),
		"highest_completed_story_quest": highest_completed_story_quest,
		"flags": flags.duplicate(),
		"unlocked_nav_panels": Array(unlocked_nav_panels),
		"enabled_projects": Array(enabled_projects),
	}


static func from_dict(data: Dictionary) -> GameState:
	var s := GameState.new()

	# Core
	s.amounts = data.get("amounts", {})
	s.current_day = int(data.get("current_day", 0))
	s.run_number = int(data.get("run_number", 1))

	# Buildings
	s.buildings_owned = data.get("buildings_owned", {})
	s.buildings_active = data.get("buildings_active", {})
	s.unlocked_buildings.assign(data.get("unlocked_buildings", []))

	# Programs
	s.programs.clear()
	for prog_data in data.get("programs", []):
		s.programs.append(ProgramData.from_dict(prog_data))
	while s.programs.size() < 5:
		s.programs.append(ProgramData.new())

	# Launch pads
	s.pads.clear()
	for pad_data in data.get("pads", []):
		s.pads.append(LaunchPadData.from_dict(pad_data))
	s.loading_priority = data.get("loading_priority", ["he3", "ti", "cir", "prop"])
	s.launch_history.clear()
	for rec_data in data.get("launch_history", []):
		s.launch_history.append(LaunchRecord.from_dict(rec_data))
	s.total_shipments_completed = int(data.get("total_shipments_completed", 0))

	# Research
	s.completed_research.assign(data.get("completed_research", []))

	# Cumulative
	s.cumulative_resources_earned = data.get("cumulative_resources_earned", {})

	# Milestones
	s.triggered_milestones.assign(data.get("triggered_milestones", []))

	# Boredom
	s.current_boredom_phase = int(data.get("current_boredom_phase", 1))

	# Land
	s.land_purchases = int(data.get("land_purchases", 0))

	# Demand
	s.demand = data.get("demand", {})
	s.demand_promote = data.get("demand_promote", {})
	s.demand_rival = data.get("demand_rival", {})
	s.demand_launch = data.get("demand_launch", {})
	s.demand_perlin_seeds = data.get("demand_perlin_seeds", {})
	s.demand_perlin_freq = data.get("demand_perlin_freq", {})
	s.demand_history = data.get("demand_history", {})

	# Speculators
	s.speculator_count = float(data.get("speculator_count", 0.0))
	s.speculator_target = data.get("speculator_target", "")
	s.speculator_burst_number = int(data.get("speculator_burst_number", 0))
	s.speculator_next_burst_tick = int(data.get("speculator_next_burst_tick", 200))
	s.speculator_revenue_tracking = data.get("speculator_revenue_tracking", {})

	# Rivals
	s.rival_next_dump_tick = data.get("rival_next_dump_tick", {})

	# Events
	s.event_instances.assign(data.get("event_instances", []))
	s.seen_event_ids.assign(data.get("seen_event_ids", []))
	s.highest_completed_story_quest = data.get("highest_completed_story_quest", "")
	s.flags = data.get("flags", {})
	s.unlocked_nav_panels.assign(data.get("unlocked_nav_panels", []))
	s.enabled_projects.assign(data.get("enabled_projects", []))

	return s


func _serialize_event_instances() -> Array:
	var result: Array = []
	for inst: Dictionary in event_instances:
		result.append(inst.duplicate())
	return result
