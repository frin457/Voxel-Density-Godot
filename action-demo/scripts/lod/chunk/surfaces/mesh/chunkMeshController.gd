class_name ChunkMeshController extends RefCounted

var active_mesher: BaseMesher = StandardMesher.new()
#var active_mesher: BaseMesher = GreedyMesher.new()


func rebuild(chunk: Chunk) -> void:
	if !is_instance_valid(chunk):
		return

	if chunk.mesh_cooking:
		chunk.mesh_stale = true
		return

	chunk.mesh_cooking = true

	var snapshot := MeshSnapshot.new()

	snapshot.voxel_ids = chunk.voxel_ids.duplicate()
	snapshot.voxel_colors = chunk.voxel_colors.duplicate()
	snapshot.chunk_size = chunk.chunk_size
	snapshot.chunk_size_sq = chunk.chunk_size_sq
	snapshot.voxel_scale = chunk.voxel_size

	WorkerThreadPool.add_task(
		_generate_mesh.bind(chunk, snapshot),
		true,
		"Mesh_%s" % chunk.chunk_coordinate
	)


func _generate_mesh(
	chunk: Chunk,
	snapshot: MeshSnapshot
) -> void:

	if !is_instance_valid(chunk):
		return
	var arrays = active_mesher.generate_mesh_data(snapshot)
	if !is_instance_valid(chunk):
		return
		
	#The main thread might have called queue_free() on this chunk 
	# while the line above was calculating.
	chunk.pending_surface_arrays = arrays
	chunk._mesh_complete.call_deferred()


func apply_mesh(chunk: Chunk) -> void:
	if !is_instance_valid(chunk):
		return

	var surface_arrays = chunk.pending_surface_arrays

	if (
		surface_arrays.size() > 0 and
		surface_arrays[Mesh.ARRAY_VERTEX] != null
	):
		var new_mesh = ArrayMesh.new()

		new_mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			surface_arrays
		)

		chunk.meshInstance.mesh = new_mesh

		if chunk.mat:
			chunk.meshInstance.set_surface_override_material(
				0,
				chunk.mat
			)
	else:
		chunk.meshInstance.mesh = null

	chunk.mesh_dirty = false
	chunk.collision_dirty = true

	if chunk.manager:
		chunk.manager.queue_collision_chunk(chunk)
		chunk.manager._create_chunk_wireframe_bounds(chunk)
	chunk.pending_surface_arrays = []
