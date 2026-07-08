#./scripts/lod/tests/testHarness.gd
class_name TestHarness extends Node

var tests: Array[BaseTest] = []
var results: Array[TestResult] = []

func _ready():

	register_suite()
	run_all()


func register_test(test: BaseTest) -> void:
	if test == null:
		print('No test selected, please register a test within testHarness.register_test().')
		return
	tests.append(test)


func register_suite():
	register_test(FailureTest.new())
	
func clear_tests() -> void:
	tests.clear()


func clear_results() -> void:
	results.clear()


func run_all() -> void:
	clear_results()

	print("")
	print("===============================")
	print("Voxel Test Harness")
	print("===============================")

	for test in tests:
		_execute_test(test)

	_print_summary()


func _execute_test(test: BaseTest) -> void:

	var result := TestResult.new()
	result.test_name = test.get_name()

	var start_time := Time.get_ticks_usec()

	var passed := false
	var message := ""

	#
	# Execute
	#
	test.setup()

	# Godot currently has no try/finally.
	# We explicitly separate execution and cleanup so cleanup
	# always occurs even if validation fails.
	test.run()

	passed = test.validate()

	if not passed:
		message = "Validation returned false."

	#
	# Cleanup ALWAYS runs.
	#
	test.cleanup()

	var end_time := Time.get_ticks_usec()

	result.passed = passed
	result.message = message
	result.duration_ms = float(end_time - start_time) / 1000.0

	results.append(result)

	if result.passed:
		print("[PASS] ", result.test_name, " (", result.duration_ms, " ms)")
	else:
		print("[FAIL] ", result.test_name)

		if result.message != "":
			print("       ", result.message)


func _print_summary() -> void:

	var passed := 0

	for result in results:
		if result.passed:
			passed += 1

	print("")
	print("===============================")
	print("Results")
	print("===============================")

	print("Passed: ", passed)
	print("Failed: ", results.size() - passed)
	print("Total : ", results.size())
	print("===============================")
