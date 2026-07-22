class_name CollisionProcessor extends RefCounted

var context: EngineContext

func _init(_context: EngineContext) -> void:
	context = _context


func process(chunk: Chunk) -> void:
	if !is_instance_valid(chunk): return

	if chunk.is_queued_for_deletion(): return
	var state := context.chunk_state.get_state(chunk)

	if !state.pending.collision_dirty: return

	context.chunk_state.dequeue_collision(chunk)
	var snapshot := context.collision_snapshot_controller.create_snapshot(
		chunk.meshInstance.mesh
	)
	context.collision_controller.rebuild(
		chunk,
		snapshot
	)
