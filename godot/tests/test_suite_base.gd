extends RefCounted

# Base class for all test suites. Provides assertion helpers and pass/fail counters.
# Each suite extends this file via: extends "res://tests/test_suite_base.gd"
# run_tests.gd instantiates each suite, calls run(), then accumulates the totals.

var tests_passed := 0
var tests_failed := 0


# Override in each suite. scene_root is the SceneTree root node; suites that
# need GameManager pass it along, others can ignore it.
func run(_scene_root: Node) -> void:
	pass


func _assert_equal(actual: Variant, expected: Variant, test_name: String) -> void:
	if actual == expected:
		tests_passed += 1
	else:
		tests_failed += 1
		print("  FAIL: ", test_name, " — expected ", expected, " got ", actual)


func _assert_true(value: bool, test_name: String) -> void:
	if value:
		tests_passed += 1
	else:
		tests_failed += 1
		print("  FAIL: ", test_name)


func _assert_gt(actual: float, threshold: float, test_name: String) -> void:
	if actual > threshold:
		tests_passed += 1
	else:
		tests_failed += 1
		print("  FAIL: ", test_name, " — expected > ", threshold, " got ", actual)


func _assert_lt(actual: float, threshold: float, test_name: String) -> void:
	if actual < threshold:
		tests_passed += 1
	else:
		tests_failed += 1
		print("  FAIL: ", test_name, " — expected < ", threshold, " got ", actual)


func _assert_approx(actual: float, expected: float, tolerance: float, test_name: String) -> void:
	if abs(actual - expected) <= tolerance:
		tests_passed += 1
	else:
		tests_failed += 1
		print("  FAIL: ", test_name, " — expected ~", expected, " (±", tolerance, ") got ", actual)
