#./scripts/controllers/subDivisionController.gd
class_name SubdivisionController extends RefCounted

# Reference back to world state (read-only access)
var manager: ChunkManager

# ----------------------------
# INIT
# ----------------------------
func _init(_manager: ChunkManager) -> void:
	manager = _manager


# ----------------------------
# SUBDIVIDE CHUNK
# ----------------------------
func subdivide_chunk(chunk_coord: Vector3i, target_level: int) -> void:
	var chunk = manager.query_controller.get_chunk(chunk_coord)
	if chunk == null or chunk.subdivision_level >= target_level:
		return

	var base_world_pos = chunk.position
	var parent_world_size = manager.get_chunk_world_size() / pow(2, chunk.subdivision_level)
	var child_world_size = parent_world_size * 0.5

	# 1. Deactivate parent (Per your plan requirements)
	chunk.deactivate() 

	# 2. Spawn / Queue Children
	for x in range(2):
		for y in range(2):
			for z in range(2):
				var child_coord = Vector3i(
					chunk_coord.x * 2 + x,
					chunk_coord.y * 2 + y,
					chunk_coord.z * 2 + z
				)
				
				var child_world_pos = base_world_pos + Vector3(x, y, z) * child_world_size

				# NOTE: When your JobQueue finishes creating this chunk, 
				# you MUST append it to chunk.child_chunks and set child.parent_chunk = chunk
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

# ----------------------------
# MERGE CHUNK (reverse operation)
# ----------------------------
func merge_chunk(chunk_coord: Vector3i) -> void:
	var chunk = manager.query_controller.get_chunk(chunk_coord)
	if chunk == null:
		return

	# 1. Bring back the parent cheaply
	chunk.activate()
	chunk.subdivision_level = max(0, chunk.subdivision_level - 1)

	# 2. Clean up the children
	for child in chunk.child_chunks:
		if is_instance_valid(child):
			child.queue_free() # or unregister from manager
			
	chunk.child_chunks.clear()


# ----------------------------
# Testing functions
# ----------------------------

func debug_force_subdivide_center() -> void:
	# Finds a central chunk and forces subdivision

	var center := Vector3i(0, 0, 0)

	var chunk = manager.query_controller.get_chunk(center)

	if chunk == null:
		print("Subdivision TEST: no chunk at (0,0,0)")
		return

	print("Subdivision TEST: forcing subdivision on", center)

	subdivide_chunk(center, 1)
