# ./scripts/lod/debug/diagnosticController.gd

class_name DiagnosticsController
extends RefCounted

var context: EngineContext


func _init(_context: EngineContext) -> void:
	context = _context


# ==================================================
# ENGINE SNAPSHOT
# ==================================================

func snapshot() -> Dictionary:

	var pending_subdivisions := 0
	var pending_merges := 0

	if context and context.registry:
		for chunk in context.registry.values():
			if !is_instance_valid(chunk):
				continue

			if chunk.subdivision_pending:
				pending_subdivisions += 1

			if chunk.merge_pending:
				pending_merges += 1

	return {
		"Chunks":
			context.registry.size()
			if context and context.registry
			else 0,

		"Pool":
			context.pool.available()
			if context and context.pool
			else 0,

		"Worker Threads":
			context.active_thread_tasks.size()
			if context
			else 0,

		"Dirty Queue":
			context.dirty_queue.size()
			if context
			else 0,

		"Collision Queue":
			context.collision_queue.size()
			if context
			else 0,

		"Pending Subdivisions":
			pending_subdivisions,

		"Pending Merges":
			pending_merges,

		"Mesh Cooking":
			context.mesh_controller.cooking_chunks.size()
			if context.mesh_controller
			else 0,

		"Collision Cooking":
			context.collision_controller.cooking_chunks.size()
			if context.collision_controller
			else 0
	}


func print_formatted_snapshot() -> void:

	if !context.is_dev:
		return

	var snap := snapshot()

	print(
		"[Voxel Engine] ",
		"Chunks=", snap["Chunks"],
		" Pool=", snap["Pool"],
		" Dirty=", snap["Dirty Queue"],
		" Collision=", snap["Collision Queue"],
		" Threads=", snap["Worker Threads"],
		" Mesh=", snap["Mesh Cooking"],
		" CollisionCook=", snap["Collision Cooking"]
	)


# ==================================================
# GENERIC
# ==================================================

func log_message(msg: String) -> void:

	if !context.is_dev:
		return

	print(msg)


func log_late_arrival(coord: Vector3i) -> void:

	if !context.is_dev:
		return

	print(
		"[Subdivision] Discarding stale child chunk ",
		coord
	)


func log_stale_thread(
	coord: Vector3i,
	job_lod: int,
	current_authorized_lod: int
) -> void:

	if !context.is_dev:
		return

	print(
		"[Thread Guard] ",
		coord,
		" JobLOD=",
		job_lod,
		" AuthorizedLOD=",
		current_authorized_lod
	)


# ==================================================
# DIRTY QUEUE
# ==================================================

func log_dirty_queued(chunk: Chunk) -> void:

	if !context.is_dev:
		return

	print(
		"[Dirty Queue] + ",
		chunk.chunk_coordinate,
		" Queue=",
		context.dirty_queue.size()
	)


func log_dirty_processing(chunk: Chunk) -> void:

	if !context.is_dev:
		return

	print(
		"[Dirty Process] ",
		chunk.chunk_coordinate
	)


# ==================================================
# COLLISION QUEUE
# ==================================================

func log_collision_queued(chunk: Chunk) -> void:

	if !context.is_dev:
		return

	print(
		"[Collision Queue] + ",
		chunk.chunk_coordinate,
		" Queue=",
		context.collision_queue.size()
	)


func log_collision_processing(chunk: Chunk) -> void:

	if !context.is_dev:
		return

	print(
		"[Collision Process] ",
		chunk.chunk_coordinate
	)


# ==================================================
# SNAPSHOTS
# ==================================================

func log_mesh_snapshot(
	chunk: Chunk,
	snapshot: MeshSnapshot
) -> void:

	if !context.is_dev:
		return

	var solid := 0

	for id in snapshot.voxel_ids:
		if id != 0:
			solid += 1

	print(
		"[Mesh Snapshot] ",
		chunk.chunk_coordinate,
		" Solid Voxels=",
		solid,
		"/",
		snapshot.voxel_ids.size()
	)


func log_collision_snapshot(
	chunk: Chunk,
	face_count: int
) -> void:

	if !context.is_dev:
		return

	print(
		"[Collision Snapshot] ",
		chunk.chunk_coordinate,
		" Faces=",
		face_count
	)


# ==================================================
# MESH
# ==================================================

func log_mesh_generated(
	chunk: Chunk,
	arrays: Array
) -> void:

	if !context.is_dev:
		return

	if arrays.is_empty():
		print(
			"[Mesh] ",
			chunk.chunk_coordinate,
			" EMPTY"
		)
		return

	var vertices = arrays[Mesh.ARRAY_VERTEX]

	print(
		"[Mesh Generated] ",
		chunk.chunk_coordinate,
		" Vertices=",
		vertices.size()
	)


func log_mesh_applied(chunk: Chunk) -> void:

	if !context.is_dev:
		return

	var surfaces := 0

	if chunk.meshInstance.mesh:
		surfaces = chunk.meshInstance.mesh.get_surface_count()

	print(
		"[Mesh Applied] ",
		chunk.chunk_coordinate,
		" Surfaces=",
		surfaces
	)


# ==================================================
# COLLISION
# ==================================================

func log_collision_generated(
	chunk: Chunk
) -> void:

	if !context.is_dev:
		return

	print(
		"[Collision Generated] ",
		chunk.chunk_coordinate
	)


func log_collision_applied(
	chunk: Chunk
) -> void:

	if !context.is_dev:
		return

	print(
		"[Collision Applied] ",
		chunk.chunk_coordinate
	)
