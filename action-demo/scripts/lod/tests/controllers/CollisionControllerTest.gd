#./scripts/lod/tests/controllers/voxelDataTest.gd
class_name CollisionControllerTest extends BaseTest

var controller: CollisionController
var snapshot: CollisionSnapshot
var chunk : Chunk

var voxel_data := {}

func get_name() -> String:
	return "CollisionController Contract"


func setup() -> void:

	controller = CollisionController.new()
	snapshot = CollisionSnapshot.new()


func run() -> void:
	pass


func validate() -> bool:

	var passed := true

	#passed = _test_rebuild() and passed
	#passed = _test_cook_collision() and passed
	#passed = _test_collision_complete() and passed
	#passed = _test_apply_collision() and passed

	return passed


func cleanup() -> void:
#	voxels are RefCount
	controller = null
	snapshot = null


func _test_rebuild() -> void :
	controller.rebuild(chunk,snapshot)
	var passed := true
	
#	assert conditions for rebuild
	passed = assert_equal(
		chunk.snapshot,
		snapshot,
		"Chunk should match snapshot data."
	) and passed

	return

func _test_cook_collision() -> void: 
	return
	
func _test_collision_complete() -> void: 
	return

func _test_apply_collision() -> void: 
	return
