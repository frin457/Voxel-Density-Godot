#./scripts/lod/chunk/controllers/queue/queueController.gd
class_name QueueController extends RefCounted

var context : EngineContext

func _init(_context: EngineContext) -> void:
	context = _context

func process() -> void:
	_process_dirty()
	_process_collision()
# ==================================================
# PUBLIC API
# ==================================================
func queue_dirty(chunk: Chunk) -> void:
	if !is_instance_valid(chunk): return
	var state = context.chunk_state.get_state(chunk)
	if state.queue.mesh: return
	context.chunk_state.queue_mesh(chunk)


func queue_collision(chunk: Chunk) -> void:
	if not is_instance_valid(chunk): return
	
	var state = context.chunk_state.get_state(chunk)
	
	if !state.pending.collision_dirty: return
	if state.queue.collision: return

	context.chunk_state.queue_collision(chunk)
	context.collision_queue.append(chunk)

func _process_dirty() -> void:
	context.dirty_queue_processed_this_frame = 0

	while (
		context.dirty_queue.size() > 0
		and
		context.dirty_queue_processed_this_frame
			< context.max_dirty_queue_per_frame
	):
		var chunk : Chunk = context.dirty_queue.pop_front()
		context.diagnostics.log_dirty_processing(chunk)
		context.dirty_processor.process(chunk)
		

func _process_collision() -> void:
	var cooked := 0

	while (
		context.collision_queue.size() > 0
		and cooked < context.max_collisions_per_frame
	):
		var chunk : Chunk = context.collision_queue.pop_front()
		context.collision_processor.process(chunk)
		cooked += 1
