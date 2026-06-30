#./scripts/lod/tests/smoke/exampleTest.gd
class_name ExampleTest extends BaseVoxelTest

var value := 0


func get_name() -> String:
	return "Example Test"


func setup() -> void:
	value = 5


func run() -> void:
	value *= 2


func validate() -> bool:
	return value == 10

 
func cleanup() -> void:
	value = 0

func fail(message:String) -> bool:
	failure_message = message
	return false
