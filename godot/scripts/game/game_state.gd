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

var amounts: Dictionary = {}        # {short_name: float}
var caps: Dictionary = {}           # {short_name: float}  INF = no cap
var buildings_owned: Dictionary = {} # {short_name: int}
var current_day: int = 0
var programs: Array = []            # Array of ProgramData, always 5 slots

var total_processors: int:
	get: return buildings_owned.get("data_center", 0)

var unassigned_processors: int:
	get:
		var assigned: int = 0
		for p: ProgramData in programs:
			assigned += p.processors_assigned
		return total_processors - assigned


func _init() -> void:
	for _i in range(5):
		programs.append(ProgramData.new())
