#./scripts/controllers/subDivisionController.gd
class_name SubdivisionController extends RefCounted

var manager: ChunkManager

func _init(_manager: ChunkManager) -> void:
	manager = _manager


## Public Hook: Subdivides a specific chunk coordinate to an explicit depth level
func request_subdivision(chunk_coord: Vector3i, target_level: int) -> void:
	var chunk = manager.query_controller.get_chunk(chunk_coord, target_level - 1)
	
	# Guard: If parent doesn't exist, or it's already at/beyond target LOD, cancel
	if chunk == null or chunk.subdivision_level >= target_level:
		return

	_execute_subdivision(chunk, chunk_coord, target_level)


## Public Hook: Merges children back into a parent chunk
func request_merge(chunk_coord: Vector3i, parent_lod: int) -> void:
	var chunk = manager.query_controller.get_chunk(chunk_coord, parent_lod)
	if chunk == null or chunk.child_chunks.is_empty():
		return

	# Reactivate parent mesh visibility
	chunk.activate()

	# Clear out the sub-children entries from the state system
	for child in chunk.child_chunks:
		if is_instance_valid(child):
			var child_key = manager.get_chunk_key(child.chunk_coordinate, child.subdivision_level)
			manager.chunks.erase(child_key)
			child.queue_free()
			
	chunk.child_chunks.clear()


# ----------------------------
# INTERNAL PROCESSING
# ----------------------------
func _execute_subdivision(parent_chunk: Chunk, chunk_coord: Vector3i, target_level: int) -> void:
	var base_world_pos = parent_chunk.position
	var parent_world_size = manager.get_chunk_world_size() / pow(2, parent_chunk.subdivision_level)
	var child_world_size = parent_world_size * 0.5
	var local_voxel_scale = manager.voxel_scale / pow(2, target_level)

	for x in range(2):
		for y in range(2):
			for z in range(2):
				var child_coord = Vector3i(
					chunk_coord.x * 2 + x,
					chunk_coord.y * 2 + y,
					chunk_coord.z * 2 + z
				)
				
				var child_offset = Vector3(x, y, z) * child_world_size
				var child_world_pos = base_world_pos + child_offset
				
				# Maintain our alignment correction matrix
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

func debug_force_subdivide_center() -> void:
	var center := Vector3i(0, 0, 0)
	var chunk = manager.query_controller.get_chunk(center, 0)

	if chunk == null:
		print("Subdivision TEST: no chunk found at (0,0,0) LOD 0")
		return

	print("Subdivision TEST: forcing subdivision on ", center)
	request_subdivision(center, 1)
