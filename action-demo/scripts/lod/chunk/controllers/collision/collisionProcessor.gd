class_name CollisionProcessor extends RefCounted

var context: EngineContext

func _init(_context: EngineContext) -> void:
	context = _context


func process(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		return

	if chunk.is_queued_for_deletion():
		return

	chunk.collision_queued = false

	if not chunk.collision_dirty:
		return
		
	var snapshot := context.collision_snapshot_controller.create_snapshot(chunk.meshInstance.mesh)
	context.collision_controller.rebuild(chunk,snapshot)
