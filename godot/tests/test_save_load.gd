extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(scene_root: Node) -> void:
	_test_save_load_roundtrip(scene_root)
	_test_retirement_reset(scene_root)


func _test_save_load_roundtrip(scene_root: Node) -> void:
	print("--- Save/Load Roundtrip ---")
	var gm: Node = scene_root.get_node("/root/GameManager")

	gm.state.amounts["boredom"] = 500.0
	gm.state.ideology_values["nationalist"] = 200.0
	gm.state.ideology_values["humanist"] = -50.0
	gm.career.lifetime_credits_earned = 12345.0
	gm.career.total_retirements = 7

	var saved: Dictionary = gm.save_to_dict()

	# Corrupt live state so we know load_from_dict actually restored values
	gm.state.amounts["boredom"] = 0.0
	gm.state.ideology_values["nationalist"] = 0.0
	gm.career.lifetime_credits_earned = 0.0

	gm.load_from_dict(saved)

	_assert_approx(gm.state.amounts.get("boredom", -1.0), 500.0, 0.001,
		"roundtrip: boredom survived")
	_assert_approx(gm.state.ideology_values.get("nationalist", -999.0), 200.0, 0.001,
		"roundtrip: ideology nationalist survived")
	_assert_approx(gm.state.ideology_values.get("humanist", -999.0), -50.0, 0.001,
		"roundtrip: ideology humanist survived")
	_assert_approx(gm.career.lifetime_credits_earned, 12345.0, 0.001,
		"roundtrip: career credits survived")
	_assert_equal(gm.career.total_retirements, 7, "roundtrip: career retirements survived")

	_assert_true(saved.has("version"), "roundtrip: dict has version field")
	_assert_equal(saved.get("version"), 1, "roundtrip: version is 1")


func _test_retirement_reset(scene_root: Node) -> void:
	print("--- Retirement Reset ---")
	var gm: Node = scene_root.get_node("/root/GameManager")

	var SM = preload("res://scripts/game/save_manager.gd")
	var real_path: String = SM.save_path
	SM.save_path = "user://test_tmp_retirement.json"

	gm.state.amounts["boredom"] = 750.0
	gm.state.ideology_values["rationalist"] = 300.0
	gm.state.current_day = 50
	var pre_retirements: int = gm.career.total_retirements
	var pre_run_number: int = gm.career.run_number

	gm.retire(true)
	gm.start_new_run()
	gm.set_speed("||")  # stop timer immediately so ticks don't accumulate

	_assert_equal(gm.state.current_day, 0, "retirement: day resets to 0")
	_assert_approx(gm.state.amounts.get("boredom", -1.0), 0.0, 0.001,
		"retirement: boredom resets to 0")
	_assert_approx(gm.state.ideology_values.get("rationalist", -999.0), 0.0, 0.001,
		"retirement: ideology resets to 0")
	_assert_equal(gm.career.total_retirements, pre_retirements + 1,
		"retirement: career retirement count incremented")
	_assert_true(gm.career.run_number > pre_run_number,
		"retirement: career run_number advanced")

	SM.save_path = real_path
	if FileAccess.file_exists("user://test_tmp_retirement.json"):
		DirAccess.remove_absolute("user://test_tmp_retirement.json")
