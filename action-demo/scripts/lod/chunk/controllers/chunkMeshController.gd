class_name ChunkMeshController extends RefCounted

var active_mesher: BaseMesher = StandardMesher.new()

# Internal State Tracking (Moved from Chunk)
var cooking_chunks : Dictionary = {}
var stale_chunks : Dictionary = {}
var pending_surfaces : Dictionary = {}

func rebuild(
	chunk: Chunk,
	snapshot: MeshSnapshot
) -> void:

	if not is_instance_valid(chunk):
		return

	if cooking_chunks.has(chunk):
		stale_chunks[chunk] = true
		return

	cooking_chunks[chunk] = true

	WorkerThreadPool.add_task(
		_generate_mesh.bind(chunk, snapshot),
		true,
		"Mesh_%s" % chunk.chunk_coordinate
	)


func _generate_mesh(
	chunk: Chunk,
	snapshot: MeshSnapshot
) -> void:

	var arrays = active_mesher.generate_mesh_data(snapshot)

	if not is_instance_valid(chunk):
		return

	pending_surfaces[chunk] = arrays

	_mesh_complete.call_deferred(chunk)


# New internal callback to replace the one previously inside Chunk
func _mesh_complete(chunk: Chunk) -> void:
	cooking_chunks.erase(chunk)
	
	if stale_chunks.has(chunk):
		stale_chunks.erase(chunk)
		if is_instance_valid(chunk) and chunk.has_method("mark_dirty"):
			chunk.mark_dirty()
		return

	apply_mesh(chunk)


func apply_mesh(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		pending_surfaces.erase(chunk) # Prevent memory leaks if chunk was destroyed
		return

	var surface_arrays = pending_surfaces.get(chunk, [])

	if surface_arrays.size() > 0 and surface_arrays[Mesh.ARRAY_VERTEX] != null:
		var new_mesh = ArrayMesh.new()
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		chunk.meshInstance.mesh = new_mesh

		if chunk.mat:
			chunk.meshInstance.set_surface_override_material(0, chunk.mat)
	else:
		chunk.meshInstance.mesh = null

	chunk.mesh_dirty = false
	chunk.collision_dirty = true
	
	# Cleanup memory
	pending_surfaces.erase(chunk)

	if chunk.manager:
		chunk.manager.queue_collision_chunk(chunk)
		if chunk.manager.has_method("_create_chunk_wireframe_bounds"):
			chunk.manager._create_chunk_wireframe_bounds(chunk)
