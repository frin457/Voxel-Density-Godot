#./scripts/lod/chunk/surfaces/mesh/chunkMeshController.gd
class_name ChunkMeshController extends RefCounted

## The active meshing strategy. Can be rotated at runtime!
var active_mesher: BaseVoxelMesher = CulledVoxelMesher.new()

## Entry point invoked by ChunkManager during the dirty chunk processing queue loop
func rebuild(chunk: Chunk) -> void:
	if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
		return
		
	# Execute whatever strategy is currently slotted in
	var surface_arrays = active_mesher.generate_mesh_data(chunk)
		
	if surface_arrays.size() > 0 and surface_arrays[Mesh.ARRAY_VERTEX] != null:
		var new_mesh = ArrayMesh.new()
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		chunk.meshInstance.mesh = new_mesh
		
		# Generate collisions cleanly
		var trimesh_shape = new_mesh.create_trimesh_shape()
		chunk.collisionShape.shape = trimesh_shape
		chunk.collisionShape.disabled = false
		
		if chunk.mat:
			chunk.meshInstance.set_surface_override_material(0, chunk.mat)
	else:
		chunk.meshInstance.mesh = null
		chunk.collisionShape.shape = null
		
	# Clear tracking states safely
	chunk.mesh_dirty = false
	chunk.collision_dirty = false
