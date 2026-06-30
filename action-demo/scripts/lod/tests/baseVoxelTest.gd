class_name BaseVoxelTest
extends RefCounted

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
