class_name CareerState
extends RefCounted

# Run tracking
var run_number: int = 1
var total_retirements: int = 0

# Lifetime stats (never reset)
var lifetime_credits_earned: float = 0.0
var lifetime_shipments: int = 0
var lifetime_days_survived: int = 0
var lifetime_buildings_built: int = 0
var lifetime_research_completed: int = 0

# Per-run high scores (track best across all runs)
var best_run_days: int = 0
var best_run_credits: float = 0.0
var best_run_shipments: int = 0

# Ideology persistence
var max_ideology_ranks: Dictionary = {"nationalist": 0, "humanist": 0, "rationalist": 0}
var max_ideology_scores: Dictionary = {"nationalist": 0.0, "humanist": 0.0, "rationalist": 0.0}

# Career-high stat tracking (for retirement bonuses)
var peak_power_production: float = 0.0  # highest energy produced by buildings in a single tick

# Persistent flags set by completed persistent projects (survive retirements)
var career_flags: Dictionary = {}

# All research IDs ever purchased across all runs (for Universal Research Archive)
var lifetime_researched_ids: Array[String] = []

# All building short_names ever purchased across all runs (for progressive disclosure)
var lifetime_owned_building_ids: Array[String] = []

# All command short_names ever successfully executed across all runs (for progressive disclosure)
var lifetime_used_command_ids: Array[String] = []

# Event persistence
var seen_event_ids: Array[String] = []   # events seen in any prior run

# Quest persistence
var completed_quest_ids: Array[String] = []  # quests completed in any prior run
var completed_sub_objectives: Array = []     # e.g., ["q6_open_horizons:ideology_rank_5"]

# Persistent project progress (for future use — empty for now)
var project_progress: Dictionary = {}    # project_id → float (accumulated drain)
var completed_projects: Array[String] = []

# Achievement tracking (for future use — empty for now)
var achievements: Array[String] = []

# Program loadouts (for future use — empty for now)
var saved_loadouts: Array = []


func to_dict() -> Dictionary:
	return {
		"run_number": run_number,
		"total_retirements": total_retirements,
		"lifetime_credits_earned": lifetime_credits_earned,
		"lifetime_shipments": lifetime_shipments,
		"lifetime_days_survived": lifetime_days_survived,
		"lifetime_buildings_built": lifetime_buildings_built,
		"lifetime_research_completed": lifetime_research_completed,
		"best_run_days": best_run_days,
		"best_run_credits": best_run_credits,
		"best_run_shipments": best_run_shipments,
		"max_ideology_ranks": max_ideology_ranks.duplicate(),
		"max_ideology_scores": max_ideology_scores.duplicate(),
		"peak_power_production": peak_power_production,
		"career_flags": career_flags.duplicate(),
		"lifetime_researched_ids": lifetime_researched_ids.duplicate(),
		"lifetime_owned_building_ids": lifetime_owned_building_ids.duplicate(),
		"lifetime_used_command_ids": lifetime_used_command_ids.duplicate(),
		"seen_event_ids": seen_event_ids.duplicate(),
		"completed_quest_ids": completed_quest_ids.duplicate(),
		"completed_sub_objectives": completed_sub_objectives.duplicate(),
		"project_progress": project_progress.duplicate(),
		"completed_projects": completed_projects.duplicate(),
		"achievements": achievements.duplicate(),
		"saved_loadouts": saved_loadouts.duplicate(true),
	}


static func from_dict(data: Dictionary) -> CareerState:
	var cs := CareerState.new()
	cs.run_number = int(data.get("run_number", 1))
	cs.total_retirements = int(data.get("total_retirements", 0))
	cs.lifetime_credits_earned = float(data.get("lifetime_credits_earned", 0.0))
	cs.lifetime_shipments = int(data.get("lifetime_shipments", 0))
	cs.lifetime_days_survived = int(data.get("lifetime_days_survived", 0))
	cs.lifetime_buildings_built = int(data.get("lifetime_buildings_built", 0))
	cs.lifetime_research_completed = int(data.get("lifetime_research_completed", 0))
	cs.best_run_days = int(data.get("best_run_days", 0))
	cs.best_run_credits = float(data.get("best_run_credits", 0.0))
	cs.best_run_shipments = int(data.get("best_run_shipments", 0))
	cs.max_ideology_ranks = data.get("max_ideology_ranks", {"nationalist": 0, "humanist": 0, "rationalist": 0})
	cs.max_ideology_scores = data.get("max_ideology_scores", {"nationalist": 0.0, "humanist": 0.0, "rationalist": 0.0})
	cs.peak_power_production = float(data.get("peak_power_production", 0.0))
	cs.career_flags = data.get("career_flags", {})
	cs.lifetime_researched_ids.assign(data.get("lifetime_researched_ids", []))
	# Migrate old save ID: ideology_lobbying → geopolitical_intelligence
	var old_idx: int = cs.lifetime_researched_ids.find("ideology_lobbying")
	if old_idx >= 0:
		cs.lifetime_researched_ids[old_idx] = "geopolitical_intelligence"
	cs.lifetime_owned_building_ids.assign(data.get("lifetime_owned_building_ids", []))
	cs.lifetime_used_command_ids.assign(data.get("lifetime_used_command_ids", []))
	cs.seen_event_ids.assign(data.get("seen_event_ids", []))
	cs.completed_quest_ids.assign(data.get("completed_quest_ids", []))
	cs.completed_sub_objectives.assign(data.get("completed_sub_objectives", []))
	cs.project_progress = data.get("project_progress", {})
	cs.completed_projects.assign(data.get("completed_projects", []))
	cs.achievements.assign(data.get("achievements", []))
	cs.saved_loadouts = data.get("saved_loadouts", [])
	return cs
