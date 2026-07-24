#res://scripts/lod/chunk/controllers/collision/collisionProcessor.gd
class_name CollisionProcessor extends RefCounted
var context: EngineContext

func _init(_context: EngineContext) -> void:
	context = _context


func process(chunk: Chunk) -> void:
	if !is_instance_valid(chunk): return
	if chunk.is_queued_for_deletion(): return
	if !context.chunk_state.is_collision_dirty(chunk): return
	context.chunk_state.dequeue_collision(chunk)
	
	var snapshot := context.collision_snapshot_controller.create_snapshot(
		chunk.meshInstance.mesh
	)
	context.collision_controller.rebuild(
		chunk,
		snapshot
	)
