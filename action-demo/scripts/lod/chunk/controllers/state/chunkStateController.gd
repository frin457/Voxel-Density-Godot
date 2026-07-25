#res://scripts/lod/chunk/controllers/state/ChunkStateController.gd
class_name ChunkStateController extends RefCounted

# ==================================================
# STATE STORAGE
# ==================================================

var _states: Dictionary = {}


# ==================================================
# LIFECYCLE
# ==================================================
func register_chunk(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		return

	if _states.has(chunk): return

	_states[chunk] = ChunkRuntimeState.new()

func unregister_chunk(chunk: Chunk) -> void:
	_states.erase(chunk)


func get_state(chunk: Chunk) -> ChunkRuntimeState:
	if not _states.has(chunk):
		register_chunk(chunk)

	return _states[chunk]


# ==================================================
# GENERATION
# ==================================================
func begin_generation(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.generating = true
	_touch(state)

func finish_generation(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.generating = false
	_touch(state)

# ==================================================
# MESHING
# ==================================================
func begin_meshing(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.meshing = true
	_touch(state)

func finish_meshing(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.meshing = false
	_touch(state)

# ==================================================
# COLLISION
# ==================================================
func begin_collision(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.colliding = true
	_touch(state)

func finish_collision(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.colliding = false
	_touch(state)

# ==================================================
# LOD OPERATIONS
# ==================================================
func begin_subdivision(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.subdividing = true
	_touch(state)

func finish_subdivision(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.subdividing = false
	_touch(state)


func begin_merge(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.merging = true
	_touch(state)

func finish_merge(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.merging = false
	_touch(state)

# ==================================================
# QUEUE STATE
# ==================================================
func queue_mesh(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.queue.mesh = true
	_touch(state)

func dequeue_mesh(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.queue.mesh = false
	_touch(state)


func queue_collision(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.queue.collision = true
	_touch(state)

func dequeue_collision(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.queue.collision = false
	_touch(state)

# ==================================================
# PENDING STATE
# ==================================================
func mark_stale(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.stale = true
	_touch(state)

func clear_stale(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.stale = false
	_touch(state)


func mark_merge_pending(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.pending.merge = true
	_touch(state)

func clear_merge_pending(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.pending.merge = false
	_touch(state)


func mark_mesh_dirty(chunk: Chunk) -> void:
	var state := get_state(chunk)
	
	state.pending.mesh_dirty = true
	_touch(state)

func clear_mesh_dirty(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.pending.mesh_dirty = false
	_touch(state)


func mark_collision_dirty(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.pending.collision_dirty = true
	_touch(state)

func clear_collision_dirty(chunk : Chunk) -> void:
	var state := get_state(chunk)
	state.pending.collision_dirty = false
	_touch(state)


func mark_subdivision_pending(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.pending.subdivision = true
	_touch(state)

func clear_subdivision_pending(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.pending.subdivision = false
	_touch(state)


#func clear_dirty(chunk: Chunk) -> void:
	#clear_mesh_dirty(chunk)
	#clear_collision_dirty(chunk)

#func mark_dirty(chunk: Chunk) -> void:
	#mark_mesh_dirty(chunk)
	#mark_collision_dirty(chunk)
	
# ==================================================
# FUTURE DESTRUCTION SYSTEM
# ==================================================
func begin_destruction(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.destroying = true
	_touch(state)

func finish_destruction(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.destroying = false
	_touch(state)

# ==================================================
# FUTURE RESTORATION SYSTEM
# ==================================================
func begin_restoration(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.restoring = true
	_touch(state)

func finish_restoration(chunk: Chunk) -> void:
	var state := get_state(chunk)

	state.operations.restoring = false
	_touch(state)

# ==================================================
# QUERIES
# ==================================================
func is_busy(chunk: Chunk) -> bool:
	var state := get_state(chunk)

	return (
		state.operations.generating
		or state.operations.meshing
		or state.operations.colliding
		or state.operations.subdividing
		or state.operations.merging
		or state.operations.destroying
		or state.operations.restoring
	)


func is_idle(chunk: Chunk) -> bool:
	return not is_busy(chunk)


func is_stale(chunk: Chunk) -> bool:
	return get_state(chunk).stale


# ==================================================
# STATE QUERIES
# ==================================================
func is_mesh_dirty(chunk: Chunk) -> bool:
	return get_state(chunk).pending.mesh_dirty

func is_collision_dirty(chunk: Chunk) -> bool:
	return get_state(chunk).pending.collision_dirty

func is_mesh_queued(chunk: Chunk) -> bool:
	return get_state(chunk).queue.mesh

func is_collision_queued(chunk: Chunk) -> bool:
	return get_state(chunk).queue.collision

func is_subdivision_pending(chunk: Chunk) -> bool:
	return get_state(chunk).pending.subdivision

func is_merge_pending(chunk: Chunk) -> bool:
	return get_state(chunk).pending.merge

func is_generating(chunk: Chunk) -> bool:
	return get_state(chunk).operations.generating

func is_meshing(chunk: Chunk) -> bool:
	return get_state(chunk).operations.meshing

func is_colliding(chunk: Chunk) -> bool:
	return get_state(chunk).operations.colliding

func is_subdividing(chunk: Chunk) -> bool:
	return get_state(chunk).operations.subdividing

func is_merging(chunk: Chunk) -> bool:
	return get_state(chunk).operations.merging

func is_destroying(chunk: Chunk) -> bool:
	#TODO: complete Destruction implementation
	return get_state(chunk).operations.destroying

func is_restoring(chunk: Chunk) -> bool:
	#TODO: Complete Restoration implementation
	return get_state(chunk).operations.restoring


func is_registered(chunk: Chunk) -> bool:
	return _states.has(chunk)

# ==================================================
# INTERNAL
# ==================================================

func _touch(state: ChunkRuntimeState) -> void:
	state.last_state_change = Time.get_ticks_msec()

#func print_state(chunk: Chunk) -> void:
