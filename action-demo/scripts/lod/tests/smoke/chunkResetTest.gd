class_name ChunkResetTest
extends BaseVoxelTest

var chunk: Chunk


func get_name() -> String:
	return "Chunk Reset Contract"


func setup() -> void:
	chunk = Chunk.new()

	# Simulate runtime state.

	chunk.parent_chunk = Chunk.new()
	chunk.child_chunks.append(Chunk.new())

	chunk.active = true

	chunk.mesh_dirty = true
	chunk.collision_dirty = true

	#chunk.mesh_cooking = true
	#chunk.collision_cooking = true

	#chunk.mesh_stale = true
	#chunk.collision_stale = true
	#chunk.collision_queued = true

	chunk.subdivision_pending = true
	chunk.merge_pending = true

	#chunk.is_empty_air = false
	#chunk.is_mesh_ready = true

	#chunk.pending_surface_arrays.append("placeholder")

	#chunk.visual_bounds_mesh = MeshInstance3D.new()


func run() -> void:
	chunk.reset()


func validate() -> bool:

	var passed := true

	# --------------------------------------------------
	# Lifecycle
	# --------------------------------------------------

	passed = assert_true(
		not chunk.active,
		"Chunk should be inactive after reset."
	) and passed

	# --------------------------------------------------
	# Hierarchy
	# --------------------------------------------------

	passed = assert_true(
		chunk.parent_chunk == null,
		"Parent reference should be cleared."
	) and passed

	passed = assert_true(
		chunk.child_chunks.is_empty(),
		"Child list should be empty."
	) and passed

	# --------------------------------------------------
	# Dirty Flags
	# --------------------------------------------------

	passed = assert_true(
		not chunk.mesh_dirty,
		"mesh_dirty should be cleared."
	) and passed

	passed = assert_true(
		not chunk.collision_dirty,
		"collision_dirty should be cleared."
	) and passed

	# --------------------------------------------------
	# Subdivision State
	# --------------------------------------------------

	passed = assert_true(
		not chunk.subdivision_pending,
		"subdivision_pending should be cleared."
	) and passed

	passed = assert_true(
		not chunk.merge_pending,
		"merge_pending should be cleared."
	) and passed

	return passed


func cleanup() -> void:

	if is_instance_valid(chunk):
		chunk.queue_free()

	chunk = null
