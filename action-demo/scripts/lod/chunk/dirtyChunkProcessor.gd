class_name DirtyChunkProcessor extends RefCounted

var context: EngineContext


func _init(_context: EngineContext) -> void:
	context = _context


func process(chunk: Chunk) -> void:
	if !is_instance_valid(chunk): return
	if chunk.is_queued_for_deletion(): return
	
	context.dirty_queue_processed_this_frame += 1
	if !context.chunk_state.is_mesh_dirty(chunk): return

	var snapshot := context.mesh_snapshot_factory.create_snapshot(
		chunk.voxel_data,
		chunk.grid_info
	)
	context.diagnostics.log_mesh_snapshot(
		chunk,
		snapshot
	)
	context.mesh_controller.rebuild(
		chunk,
		snapshot
	)
	context.chunk_state.dequeue_mesh(chunk)
