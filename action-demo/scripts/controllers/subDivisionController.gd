#./scripts/controllers/subDivisionController.gd
class_name SubdivisionController extends RefCounted

var manager: ChunkManager

func _init(_manager: ChunkManager) -> void:
	manager = _manager


## Public Hook: Subdivides a specific chunk coordinate to an explicit depth level
func request_subdivision(chunk_coord: Vector3i, target_level: int, wave_index: int = 0) -> void:
	var chunk = manager.query_controller.get_chunk(chunk_coord, target_level - 1)
	
	# Guard: If parent doesn't exist, or it's already at/beyond target LOD, cancel
	if chunk == null or chunk.subdivision_level >= target_level:
		return

	_execute_subdivision(chunk, chunk_coord, target_level, wave_index)


## Public Hook: Merges children back into a parent chunk
## Collapses 8 LOD 1 children back into their original baseline LOD 0 parent
func request_merge(parent_coord: Vector3i) -> void:
	var parent_key = manager.get_chunk_key(parent_coord, 0)
	
	if not manager.chunks.has(parent_key):
		return
		
	var parent_chunk: Chunk = manager.chunks[parent_key]
	if not is_instance_valid(parent_chunk):
		return

	print("Subdivision Controller: Collapsing 8 children of parent ", parent_coord)
		
	# 1. Clear out children chunk elements from the global registry and scene tree
	# Query global registry keys directly to catch unlinked/delayed thread orphans
	for x in range(2):
		for y in range(2):
			for z in range(2):
				var child_coord = Vector3i(
					parent_coord.x * 2 + x,
					parent_coord.y * 2 + y,
					parent_coord.z * 2 + z
				)
				var child_key = manager.get_chunk_key(child_coord, 1)
				if manager.chunks.has(child_key):
					var child_chunk = manager.chunks[child_key]
					if is_instance_valid(child_chunk):
						child_chunk.queue_free()
					manager.chunks.erase(child_key)
				
	# 2. Fallback sweep: Free any remaining structural node links inside the array
	for child in parent_chunk.child_chunks:
		if is_instance_valid(child):
			child.queue_free()
			
	parent_chunk.child_chunks.clear()
	
	# 3. Restore the parent baseline
	parent_chunk.activate()
	
	# FORCE THE MESH AND VISUAL ARRAYS TO BE RERENDERED IMMEDIATELY
	if parent_chunk.has_method("set_mesh_dirty"):
		parent_chunk.set_mesh_dirty(true)
	else:
		parent_chunk.mesh_dirty = true
		
	manager.process_chunk(parent_chunk)

# ----------------------------
# INTERNAL PROCESSING
# ----------------------------
func _execute_subdivision(parent_chunk: Chunk, chunk_coord: Vector3i, target_level: int, wave_index: int = 0) -> void:
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
						target_level,
						wave_index
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
