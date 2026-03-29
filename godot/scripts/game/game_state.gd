class_name GameState
extends RefCounted

class ProgramEntry:
	var command_shortname: String = ""
	var repeat_count: int = 1
	var current_progress: int = 0
	var failed_this_cycle: bool = false

class ProgramData:
	var commands: Array = []  # Array of ProgramEntry
	var processors_assigned: int = 0
	var instruction_pointer: int = 0

class LaunchPadData:
	var resource_type: String = "he3"
	var cargo_loaded: float = 0.0
	var status: int = 0   # use GameState.PAD_* constants
	var cooldown_ticks: int = 0

class LaunchRecord:
	var resource_type: String = ""
	var quantity: float = 0.0
	var credits_earned: float = 0.0
	var tick: int = 0
	var notification_message: String = ""  # non-empty = rival dump notification, not a launch

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
