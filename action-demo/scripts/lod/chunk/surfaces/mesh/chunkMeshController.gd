#./scripts/lod/chunk/surfaces/mesh/chunkMeshController.gd
class_name ChunkMeshController extends RefCounted

## The active meshing strategy. Can be rotated at runtime!
var active_mesher: BaseMesher = StandardMesher.new()
#var active_mesher: BaseMesher = GreedyMesher.new()

## Entry point invoked by ChunkManager during the dirty chunk processing queue loop
func rebuild(chunk: Chunk) -> void:
	if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
		return
	#var collision_queue = chunk.manager.collision_queue	
	# Execute current meshing strategy
	var surface_arrays = active_mesher.generate_mesh_data(chunk)
		
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

	if chunk.manager:
		chunk.manager.queue_collision_chunk(chunk)
		#chunk.manager._create_chunk_wireframe_bounds(chunk)
		
