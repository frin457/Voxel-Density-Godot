#./scripts/lod/chunk/controllers/CollisionSnapshotFactory.gd
class_name CollisionSnapshotFactory extends RefCounted

var cooking_chunks : Dictionary = {}
var stale_chunks : Dictionary = {}
var pending_shapes : Dictionary = {}


func rebuild(
	chunk: Chunk,
	snapshot: CollisionSnapshot
) -> void:

	if !is_instance_valid(chunk):
		return

	if cooking_chunks.has(chunk):
		stale_chunks[chunk] = true
		return

	if snapshot.faces.is_empty():
		chunk.collision_dirty = false
		if chunk.collisionShape:
			chunk.collisionShape.shape = null
		return

	cooking_chunks[chunk] = true
	WorkerThreadPool.add_task(
		_cook_collision.bind(chunk, snapshot),
		true,
		"Collision_%s" % chunk.chunk_coordinate
	)


func _cook_collision(
	chunk: Chunk,
	snapshot: CollisionSnapshot
) -> void:

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(snapshot.faces)
	if !is_instance_valid(chunk):
		return
	pending_shapes[chunk] = shape
	_collision_complete.call_deferred(chunk)


func _collision_complete(
	chunk: Chunk
) -> void:
	cooking_chunks.erase(chunk)
	if stale_chunks.has(chunk):
		stale_chunks.erase(chunk)
		if is_instance_valid(chunk):
			chunk.mark_dirty()
		return
	apply_collision(chunk)


func apply_collision(
	chunk: Chunk
) -> void:

	if !is_instance_valid(chunk):
		pending_shapes.erase(chunk)
		return

	var shape = pending_shapes.get(chunk)

	pending_shapes.erase(chunk)

	if chunk.collisionShape:
		chunk.collisionShape.shape = shape

	chunk.collision_dirty = false

	if (
		chunk.manager
		and chunk.manager.subdivision_controller
		and chunk.manager.subdivision_controller.has_method("notify_chunk_mesh_ready")
	):
		chunk.manager.subdivision_controller.notify_chunk_mesh_ready(chunk)
