# ./scripts/lod/engine/subDivisionController.gd
class_name SubdivisionController extends RefCounted

var registry

func _init(_manager: ChunkManager) -> void:
	manager = _manager

func request_subdivision(coord: Vector3i, target_level: int) -> void:
	var key = manager.get_chunk_key(coord, target_level - 1)
	
	if not manager.registry.has(key):
		return

	var parent_chunk = manager.registry[key]

	if parent_chunk.subdivision_pending:
		return

	parent_chunk.subdivision_pending = true
	
	if parent_chunk.is_empty_air:
		parent_chunk.subdivision_pending = false
		return
	
	var world_size = manager.chunk_lod_size / pow(2, target_level)
		
	for x in range(2):
		for y in range(2):
			for z in range(2):
				var child_coord = (coord * 2) + Vector3i(x, y, z)
				var child_world_pos = parent_chunk.position + (Vector3(x, y, z) * world_size)
				
				var job = ChunkJob.new(
					ChunkJob.JobType.GENERATE,
					child_coord,
					child_world_pos,
					{},
					1.0,
					target_level
				)
				manager.job_queue.push(job)


func subdivision_complete(parent_coord: Vector3i, lod: int) -> void:
	var parent_key = manager.get_chunk_key(parent_coord, lod - 1)
	
	if not registry.get_chunk(parent_key):
		return
		
	var parent_chunk = manager.registry[parent_key]
	parent_chunk.subdivision_pending = false
	
	parent_chunk.current_lod = lod
	
	for child in parent_chunk.child_chunks:
		if is_instance_valid(child) and child.has_method("activate"):
			child.activate()
			
	parent_chunk.deactivate()


func request_merge(parent_coord: Vector3i, parent_level: int) -> void:
	var parent_key = manager.get_chunk_key(parent_coord, parent_level)
	
	if not manager.registry.has(parent_key):
		return
		
	var parent_chunk = manager.registry[parent_key]

	if parent_chunk.merge_pending:
		return

	parent_chunk.merge_pending = true

	# 1. Clear the gate for this parent chunk level
	parent_chunk.subdivision_pending = false
	
	# 2. Clear gates for 8 potential child coordinates
	for x in range(2):
		for y in range(2):
			for z in range(2):
				var child_coord = (parent_coord * 2) + Vector3i(x, y, z)
				var child_key = manager.get_chunk_key(child_coord, parent_level + 1)
				
				if manager.registry.has(child_key):
					var child_chunk = manager.registry[child_key]
					child_chunk.subdivision_pending = false
					child_chunk.merge_pending = false

	# Recursively scrub and pool all child nodes
	_clean_child_geometry(parent_chunk)

	parent_chunk.current_lod = parent_level
	parent_chunk.activate()
	
	parent_chunk.merge_pending = false


func _clean_child_geometry(parent_chunk: Chunk) -> void:
	var children = parent_chunk.child_chunks.duplicate()

	for child in children:
		if not is_instance_valid(child):
			continue

		# Recurse first to clear grandchildren
		_clean_child_geometry(child)

		child.parent_chunk = null

		var child_key = manager.get_chunk_key(
			child.chunk_coordinate,
			child.lod_level
		)

		child.subdivision_pending = false
		child.merge_pending = false

		manager.registry.erase(child_key)
		parent_chunk.child_chunks.erase(child)
		manager.pool.release(child)

	parent_chunk.child_chunks.clear()


func notify_chunk_mesh_ready(chunk: Chunk) -> void:
	# Added guard back to prevent LOD 0 processing
	if not is_instance_valid(chunk) or chunk.lod_level == 0:
		return
		
	var parent_chunk = chunk.parent_chunk
	if not is_instance_valid(parent_chunk):
		return

	if not parent_chunk.subdivision_pending:
		if parent_chunk.current_lod == chunk.lod_level:
			return 
			
		if manager.isDev:
			manager.diagnostics.log_late_arrival(chunk.chunk_coordinate)
			
		var child_key = manager.get_chunk_key(chunk.chunk_coordinate, chunk.lod_level)
		manager.registry.erase(child_key)
		manager.pool.release(chunk)
		return
	
	var all_siblings_ready := true

	if parent_chunk.child_chunks.size() < 8:
		all_siblings_ready = false
	else:
		for sibling in parent_chunk.child_chunks:
			if not is_instance_valid(sibling):
				all_siblings_ready = false
				break

			if sibling.mesh_dirty:
				all_siblings_ready = false
				break

	if all_siblings_ready:
		subdivision_complete(
			parent_chunk.chunk_coordinate,
			chunk.lod_level
		)
