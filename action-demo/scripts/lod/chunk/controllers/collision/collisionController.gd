#./scripts/lod/chunk/controllers/CollisionController.gd
class_name CollisionController extends RefCounted

var context: EngineContext

var cooking_chunks : Dictionary = {}
var stale_chunks : Dictionary = {}
var pending_shapes : Dictionary = {}

func _init(_context: EngineContext) -> void:
	context = _context
	
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

		context.chunk_state.clear_collision_dirty(chunk)

		if chunk.collisionShape:
			chunk.collisionShape.shape = null

		return

	cooking_chunks[chunk] = true
	#TODO: UPDATE to push COLLISION JOB into queue
	WorkerThreadPool.add_task(
		_cook_collision.bind(chunk, snapshot),
		true,
		"Collision_%s" % chunk.grid_info.chunk_coordinate
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
		var overlap_scale = 1 # Adjust this if you need more/less overlap
		chunk.collisionShape.scale = Vector3(overlap_scale, overlap_scale, overlap_scale)
	context.chunk_state.clear_collision_dirty(chunk)

	if (
		chunk.manager
		and chunk.manager.subdivision_controller
		and chunk.manager.subdivision_controller.has_method("notify_chunk_mesh_ready")
	):
		chunk.manager.subdivision_controller.notify_chunk_mesh_ready(chunk)
