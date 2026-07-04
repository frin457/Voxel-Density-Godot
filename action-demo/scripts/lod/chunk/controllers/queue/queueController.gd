#./scripts/lod/chunk/controllers/queue/queueController.gd
class_name QueueController extends RefCounted

var context : EngineContext


func _init(_context: EngineContext) -> void:
	context = _context


# ==================================================
# PUBLIC API
# ==================================================

func queue_dirty_chunk(chunk: Chunk) -> void:

	if not is_instance_valid(chunk):
		return

	if context.dirty_queue.has(chunk):
		return

	context.dirty_queue.append(chunk)


func queue_collision_chunk(chunk: Chunk) -> void:

	if not is_instance_valid(chunk):
		return

	if not chunk.collision_dirty:
		return

	if chunk.collision_queued:
		return

	chunk.collision_queued = true

	context.collision_queue.append(chunk)
