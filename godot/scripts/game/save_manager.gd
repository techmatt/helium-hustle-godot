class_name SaveManager
extends RefCounted

static var save_path: String = "user://helium_hustle_save.json"
const SAVE_VERSION := 1


static func save_game(career: CareerState, state: GameState, speed_key: String = "1x") -> void:
	var data := {
		"version": SAVE_VERSION,
		"career": career.to_dict(),
		"run_state": state.to_dict(),
		"speed_key": speed_key,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	var json_string := JSON.stringify(data, "  ")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		var building_count: int = 0
		for v in state.buildings_owned.values():
			building_count += int(v)
		print("[Save] Saved run %d, day %d — %d buildings, %d shipments" % [
			state.run_number, state.current_day, building_count, state.total_shipments_completed])
	else:
		push_error("SaveManager: failed to open save file for writing")


static func load_game() -> Variant:
	if not FileAccess.file_exists(save_path):
		return null
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return null
	var json_string := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		push_warning("Save file corrupted, starting fresh: %s" % json.get_error_message())
		_backup_corrupt_save()
		return null
	var data: Variant = json.data
	if not data is Dictionary:
		push_warning("Save file invalid format, starting fresh")
		_backup_corrupt_save()
		return null
	var file_version: int = int((data as Dictionary).get("version", 0))
	if file_version != SAVE_VERSION:
		push_warning("Save version mismatch (got %d, expected %d), starting fresh" % [file_version, SAVE_VERSION])
		_backup_corrupt_save()
		return null
	var run_state: Dictionary = (data as Dictionary).get("run_state", {})
	var building_count: int = 0
	for v in (run_state.get("buildings_owned", {}) as Dictionary).values():
		building_count += int(v)
	print("[Save] Loaded run %d, day %d — %d buildings, %d shipments" % [
		int(run_state.get("run_number", 1)),
		int(run_state.get("current_day", 0)),
		building_count,
		int(run_state.get("total_shipments_completed", 0))])
	return data


static func clear_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


static func _backup_corrupt_save() -> void:
	var backup_path := save_path + ".bak"
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, backup_path)
