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
var max_ideology_ranks: Dictionary = {}  # axis_id → highest rank ever reached

# Event persistence
var seen_event_ids: Array[String] = []   # events seen in any prior run

# Quest persistence
var completed_quest_ids: Array[String] = []  # quests completed in any prior run

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
		"seen_event_ids": seen_event_ids.duplicate(),
		"completed_quest_ids": completed_quest_ids.duplicate(),
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
	cs.max_ideology_ranks = data.get("max_ideology_ranks", {})
	cs.seen_event_ids.assign(data.get("seen_event_ids", []))
	cs.completed_quest_ids.assign(data.get("completed_quest_ids", []))
	cs.project_progress = data.get("project_progress", {})
	cs.completed_projects.assign(data.get("completed_projects", []))
	cs.achievements.assign(data.get("achievements", []))
	cs.saved_loadouts = data.get("saved_loadouts", [])
	return cs
