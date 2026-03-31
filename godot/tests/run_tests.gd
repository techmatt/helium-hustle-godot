extends SceneTree

# Test runner entry point.
# Run: godot --headless --path godot/ --script tests/run_tests.gd
#
# Each suite is a separate file extending test_suite_base.gd.
# Add new suites to the _SUITES list below — no other changes needed.
#
# class_name declarations outside the autoload chain are NOT auto-registered in
# headless --script mode, so all suite files are preloaded explicitly.

const _SUITES: Array = [
	preload("res://tests/test_game_state.gd"),
	preload("res://tests/test_data_integrity.gd"),
	preload("res://tests/test_simulation.gd"),
	preload("res://tests/test_save_load.gd"),
	preload("res://tests/test_research.gd"),
	preload("res://tests/test_building_mechanics.gd"),
	preload("res://tests/test_command_execution.gd"),
	preload("res://tests/test_demand_system.gd"),
	preload("res://tests/test_projects_milestones.gd"),
	preload("res://tests/test_passive_effects.gd"),
]

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true

	# Block autosave timer from touching the player's real save file.
	# Note: _ready() has already run and loaded the save by this point.
	# skip_save_load here only prevents future autosave writes.
	var gm: Node = root.get_node("/root/GameManager")
	gm.skip_save_load = true

	var total_passed := 0
	var total_failed := 0

	for suite_script in _SUITES:
		var suite = suite_script.new()
		suite.run(root)
		total_passed += suite.tests_passed
		total_failed += suite.tests_failed

	print("")
	print("=============================")
	print("  Passed: ", total_passed)
	print("  Failed: ", total_failed)
	print("=============================")
	if total_failed > 0:
		print("TESTS FAILED")
	else:
		print("ALL TESTS PASSED")
	quit()
	return false
