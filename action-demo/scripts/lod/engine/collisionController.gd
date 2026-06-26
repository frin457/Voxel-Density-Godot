#./scripts/lod/engine/collisionController.gd
class_name CollisionController extends RefCounted

## Invoked by ChunkManager during the dirty chunk processing queue loop
func rebuild(chunk: Chunk) -> void:
	if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
		return
		
	if not chunk.has_node("CollisionShape3D") or not chunk.has_node("MeshInstance3D"):
		chunk.collision_dirty = false
		return
		
	var mesh_instance: MeshInstance3D = chunk.get_node("MeshInstance3D")
	var collision_shape: CollisionShape3D = chunk.get_node("CollisionShape3D")
	
	# 1. If the chunk mesh is empty or null, clear out the collision shape entirely
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		collision_shape.shape = null
		chunk.collision_dirty = false
		return
		
	# 2. Extract Faces and bake a trimesh shape
	var faces = mesh_instance.mesh.get_faces()
	if faces.size() > 0:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		collision_shape.shape = shape
		
	# Clear the dirty flag so the manager stops querying it
	chunk.collision_dirty = false
