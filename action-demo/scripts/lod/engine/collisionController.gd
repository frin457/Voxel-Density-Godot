#./scripts/lod/engine/collisionController.gd
class_name CollisionController extends RefCounted

func rebuild(chunk: Chunk) -> void:
	if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
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
	# (Packed arrays use copy-on-write, making this snapshot thread-safe to pass)
	var faces = mesh_instance.mesh.get_faces()
	
	if faces.size() > 0:
		chunk.collision_cooking = true
		chunk.collision_stale = false
		
		# Dispatch heavy generation a worker
		WorkerThreadPool.add_task(
			_cook_collision_shape.bind(chunk, faces), 
			true, 
            "CollisionCookTask"
		)
	else:
		chunk.collision_dirty = false


# Executes on Background Worker Thread
func _cook_collision_shape(chunk: Chunk, faces: PackedVector3Array) -> void:
	var shape := ConcavePolygonShape3D.new()
	# set_faces() triggers the rebuild
	shape.set_faces(faces)
	
	# Safely pass the cooked shape back to the main thread
	_apply_collision.call_deferred(chunk, shape)


# Executes on Main Thread via call_deferred
func _apply_collision(chunk: Chunk, shape: ConcavePolygonShape3D) -> void:
	if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
		return
		
	# if chunk was modified while cooking, discard result
	if chunk.collision_stale:
		chunk.collision_cooking = false
		# Re-queue so the manager fires rebuild() with the new mesh
		if chunk.manager:
			chunk.manager.queue_collision_chunk(chunk)
		return

	var collision_shape: CollisionShape3D = chunk.get_node("CollisionShape3D")
	collision_shape.set_deferred("shape", null)
	collision_shape.set_deferred("shape", shape)
	
	chunk.collision_dirty = false
	chunk.collision_cooking = false
	
	# notify completion when async physics are applied
	if chunk.manager and chunk.manager.subdivision_controller and chunk.manager.subdivision_controller.has_method("notify_chunk_mesh_ready"):
		chunk.manager.subdivision_controller.notify_chunk_mesh_ready(chunk)
