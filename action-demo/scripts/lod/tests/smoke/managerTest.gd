# ./scripts/lod/tests/smoke/managerTest.gd
class_name ManagerTest
extends BaseVoxelTest

var manager : ChunkManager

func get_name():
	return "ChunkManager Smoke Test"

func setup():
	manager = ChunkManager.new()


func run():
	pass

func validate():
	return manager != null

func cleanup():
	if is_instance_valid(manager):
		manager.queue_free()
