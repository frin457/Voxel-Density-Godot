#./scripts/lod/tests/BaseTest.gd
class_name BaseTest extends RefCounted

var failure_message := ""

## Human readable name shown by the test harness.
func get_name() -> String:
	return "Unnamed Test"


## Optional setup before execution.
func setup() -> void:
	pass


## Executes the test.
func run() -> void:
	pass


## Returns true if the test passed.
func validate() -> bool:
	return true



## Optional cleanup.
## Always executed even if the test fails.
func cleanup() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> bool:
	if not condition:
		push_error(message)
	return condition


func assert_equal(expected, actual, message: String = "") -> bool:
	if expected != actual:
		push_error(
			"%s Expected: %s  Actual: %s"
			% [message, str(expected), str(actual)]
		)
		return false
	return true
