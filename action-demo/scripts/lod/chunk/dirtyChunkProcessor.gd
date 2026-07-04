class_name DirtyChunkProcessor
extends RefCounted

var context: EngineContext


func _init(_context: EngineContext) -> void:
	context = _context


func process(chunk: Chunk) -> void:

	if not is_instance_valid(chunk):
		return

	if chunk.is_queued_for_deletion():
		return

	context.dirty_queue_processed_this_frame += 1

	if not chunk.mesh_dirty:
		return

	context.mesh_controller.rebuild(
		chunk,
		context.snapshot
	)

	context.chunk_mesh_finished.emit(
		chunk.chunk_coordinate
	)
