#./scripts/controllers/subDivisionController.gd
class_name SubdivisionController extends RefCounted

var manager: ChunkManager

func _init(_manager: ChunkManager) -> void:
	manager = _manager

func subdivide_chunk(chunk_coord: Vector3i, target_level: int) -> void:
	# Look up the target chunk at its accurate level (usually target - 1)
	var chunk = manager.query_controller.get_chunk(chunk_coord, target_level - 1)
	if chunk == null or chunk.subdivision_level >= target_level:
		return

	var base_world_pos = chunk.position
	var parent_world_size = manager.get_chunk_world_size() / pow(2, chunk.subdivision_level)
	var child_world_size = parent_world_size * 0.5
	
	# Determine the higher density voxel scale for this target child LOD level
	var local_voxel_scale = manager.voxel_scale / pow(2, target_level)

	# Spawn / Queue 8 Children asynchronously
	for x in range(2):
		for y in range(2):
			for z in range(2):
				var child_coord = Vector3i(
					chunk_coord.x * 2 + x,
					chunk_coord.y * 2 + y,
					chunk_coord.z * 2 + z
				)
				
				# Calculate the standard octree midpoint offset for this child
				var child_offset = Vector3(x, y, z) * child_world_size
				var child_world_pos = base_world_pos + child_offset
				
				# FIX: Offset child world center position backwards by exactly half an LOD-level voxel
				# to lock the child's higher-density vertex arrays into the parent's alignment grid.
				var alignment_correction = Vector3.ONE * (local_voxel_scale * 0.5)
				child_world_pos -= alignment_correction

				manager.job_queue.push(
					ChunkJob.new(
						ChunkJob.JobType.GENERATE,
						child_coord,
						child_world_pos,
						{},
						1.0,
						target_level
					)
				)

func merge_chunk(chunk_coord: Vector3i, parent_lod: int) -> void:
	var chunk = manager.query_controller.get_chunk(chunk_coord, parent_lod)
	if chunk == null:
		return

	# Bring back parent
	chunk.activate()

	# Clean up child instances
	for child in chunk.child_chunks:
		if is_instance_valid(child):
			# Remove child entry from master state tracker dictionary
			var child_key = manager.get_chunk_key(child.chunk_coordinate, child.subdivision_level)
			manager.chunks.erase(child_key)
			child.queue_free()
			
	chunk.child_chunks.clear()

func debug_force_subdivide_center() -> void:
	var center := Vector3i(0, 0, 0)
	var chunk = manager.query_controller.get_chunk(center, 0)

	if chunk == null:
		print("Subdivision TEST: no chunk found at (0,0,0) LOD 0")
		return

	print("Subdivision TEST: forcing subdivision on ", center)
	subdivide_chunk(center, 1)
