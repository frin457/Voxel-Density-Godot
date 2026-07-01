class_name CollisionController extends RefCounted

# Internal State Tracking (Moved from Chunk)
var cooking_chunks: Dictionary = {}
var stale_chunks: Dictionary = {}

func rebuild(chunk: Chunk) -> void:
	if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
		return
		
	if cooking_chunks.has(chunk):
		return
		
	if not chunk.has_node("CollisionShape3D") or not chunk.has_node("MeshInstance3D"):
		chunk.collision_dirty = false
		return
		
	var mesh_instance: MeshInstance3D = chunk.get_node("MeshInstance3D")
	var collision_shape: CollisionShape3D = chunk.get_node("CollisionShape3D")
	
	# Sync transforms
	collision_shape.transform = mesh_instance.transform
	
	# Check for empty surfaces
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		collision_shape.set_deferred("shape", null)
		chunk.collision_dirty = false
		return
		
	# Extract local vertex faces safely on the main thread
	var faces = mesh_instance.mesh.get_faces()
	
	if faces.size() > 0:
		cooking_chunks[chunk] = true
		stale_chunks.erase(chunk)
		
		# Dispatch heavy generation to a worker
		WorkerThreadPool.add_task(
			_cook_collision_shape.bind(chunk.get_instance_id(), faces), 
			true, 
            "CollisionCookTask"
		)
	else:
		chunk.collision_dirty = false


# Executes on Background Worker Thread
func _cook_collision_shape(chunk_id: int, faces: PackedVector3Array) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	
	_apply_collision.call_deferred(chunk_id, shape)


# Executes on Main Thread via call_deferred
func _apply_collision(chunk_id: int, shape: ConcavePolygonShape3D) -> void:
	var chunk: Chunk = instance_from_id(chunk_id) as Chunk
	
	if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
		return
		
	# Check internal controller state for staleness
	if stale_chunks.has(chunk):
		cooking_chunks.erase(chunk)
		stale_chunks.erase(chunk)
		
		# Re-queue so the manager fires rebuild() with the new mesh
		if chunk.manager and chunk.manager.has_method("queue_collision_chunk"):
			chunk.manager.queue_collision_chunk(chunk)
		return

	var collision_shape: CollisionShape3D = chunk.get_node("CollisionShape3D")
	collision_shape.set_deferred("shape", null)
	collision_shape.set_deferred("shape", shape)
	
	chunk.collision_dirty = false
	cooking_chunks.erase(chunk)
	
	# notify completion when async physics are applied
	if chunk.manager and chunk.manager.get("subdivision_controller"):
		if chunk.manager.subdivision_controller.has_method("notify_chunk_mesh_ready"):
			chunk.manager.subdivision_controller.notify_chunk_mesh_ready(chunk)
