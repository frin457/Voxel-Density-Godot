class_name SubdivisionController extends RefCounted

var manager: ChunkManager

var pending_subdivisions := {}
var pending_merges := {}


func _init(_manager: ChunkManager) -> void:
	manager = _manager


func request_subdivision(
	chunk_coord: Vector3i,
	target_level: int,
	wave_index: int = 0
) -> void:

	var request_key = "%s_%d" % [
		chunk_coord,
		target_level
	]

	if pending_subdivisions.has(request_key):
		return

	var parent_chunk = manager.query_controller.get_chunk(
		chunk_coord,
		target_level - 1
	)

	if parent_chunk == null:
		return

	if parent_chunk.subdivision_level >= target_level:
		return

	pending_subdivisions[request_key] = true

	_execute_subdivision(
		parent_chunk,
		chunk_coord,
		target_level,
		wave_index
	)


func request_merge(
	parent_coord: Vector3i,
	parent_lod: int = 0
) -> void:

	var merge_key = "%s_%d" % [
		parent_coord,
		parent_lod
	]

	if pending_merges.has(merge_key):
		return

	pending_merges[merge_key] = true

	var parent_key = manager.get_chunk_key(
		parent_coord,
		parent_lod
	)

	if not manager.chunks.has(parent_key):
		pending_merges.erase(merge_key)
		return

	var parent_chunk: Chunk = manager.chunks[parent_key]

	if not is_instance_valid(parent_chunk):
		pending_merges.erase(merge_key)
		return

	var child_lod = parent_lod + 1

	for x in range(2):
		for y in range(2):
			for z in range(2):

				var child_coord = Vector3i(
					parent_coord.x * 2 + x,
					parent_coord.y * 2 + y,
					parent_coord.z * 2 + z
				)

				var child_key = manager.get_chunk_key(
					child_coord,
					child_lod
				)

				if manager.chunks.has(child_key):

					request_merge(
						child_coord,
						child_lod
					)

					var child_chunk = manager.chunks[child_key]

					if is_instance_valid(child_chunk):
						child_chunk.queue_free()

					manager.chunks.erase(child_key)

	parent_chunk.child_chunks.clear()

	parent_chunk.activate()
	parent_chunk.mark_dirty() # This automatically queues it into ChunkManager now
	parent_chunk.mark_lod_dirty()

	pending_merges.erase(merge_key)


func _execute_subdivision(
	parent_chunk: Chunk,
	chunk_coord: Vector3i,
	target_level: int,
	wave_index: int = 0
) -> void:

	var base_world_pos = parent_chunk.position

	var parent_world_size = (
		manager.get_chunk_world_size()
		/ pow(2, parent_chunk.subdivision_level)
	)

	var child_world_size = parent_world_size * 0.5

	var local_voxel_scale = (
		manager.voxel_scale
		/ pow(2, target_level)
	)

	for x in range(2):
		for y in range(2):
			for z in range(2):

				var child_coord = Vector3i(
					chunk_coord.x * 2 + x,
					chunk_coord.y * 2 + y,
					chunk_coord.z * 2 + z
				)

				var child_offset = Vector3(
					x,
					y,
					z
				) * child_world_size

				var child_world_pos = (
					base_world_pos
					+ child_offset
				)

				var alignment_correction = (
					Vector3.ONE
					* local_voxel_scale
					* 0.5
				)

				child_world_pos -= alignment_correction

				manager.job_queue.push(
					ChunkJob.new(
						ChunkJob.JobType.GENERATE,
						child_coord,
						child_world_pos,
						{},
						1.0,
						target_level,
						wave_index
					)
				)


func subdivision_complete(
	parent_coord: Vector3i,
	target_level: int
) -> void:

	var request_key = "%s_%d" % [
		parent_coord,
		target_level
	]

	pending_subdivisions.erase(request_key)

	var parent_chunk = manager.query_controller.get_chunk(
		parent_coord,
		target_level - 1
	)

	if parent_chunk:
		parent_chunk.mark_lod_dirty()


func debug_force_subdivide_center() -> void:

	var center := Vector3i(0,0,0)

	var chunk = manager.query_controller.get_chunk(
		center,
		0
	)

	if chunk == null:
		return

	request_subdivision(center, 1)
