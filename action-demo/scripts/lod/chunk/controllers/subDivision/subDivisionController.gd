# ./scripts/lod/engine/subDivisionController.gd
class_name SubdivisionController extends RefCounted

var context = EngineContext

func _init(_context: EngineContext) -> void:
	context = _context

func request_subdivision(coord: Vector3i, target_level: int) -> void:
	var parent_chunk : Chunk = context.index.get_chunk(
		coord,
		target_level - 1
	)
	if parent_chunk == null: return
	if context.chunk_state.is_subdivision_pending(parent_chunk): return
	context.chunk_state.mark_subdivision_pending(parent_chunk)
	
# TODO:
# Reintroduce empty-chunk culling once
# surface analysis has been ported.
# 	if parent_chunk.is_empty_air:
#     context.chunk_state.clear_subdivision_pending(parent_chunk)
#     return
	
	var world_size = context.chunk_lod_size / pow(2, target_level)
	for x in range(2):
		for y in range(2):
			for z in range(2):
				var child_coord = (coord * 2) + Vector3i(x, y, z)
				var child_world_pos = parent_chunk.grid_info.world_position + (Vector3(x, y, z) * world_size)
				var job = ChunkJob.new(
					ChunkJob.JobType.GENERATE,
					child_coord,
					child_world_pos,
					null,
					1.0,
					target_level
				)
				context.job_queue.push(job)
	


func subdivision_complete(parent_coord: Vector3i, child_level: int) -> void:
	var parent_chunk : Chunk = context.index.get_chunk(
		parent_coord,
		child_level - 1
	)
	if parent_chunk == null: return
	context.chunk_state.clear_subdivision_pending(parent_chunk)
	parent_chunk.current_lod = child_level 
	
	for child in parent_chunk.child_chunks:
		if is_instance_valid(child) and child.has_method("activate"):
			child.activate()
			
	parent_chunk.deactivate()


func request_merge(parent_coord: Vector3i, parent_level: int) -> void:
	var parent_chunk : Chunk = context.index.get_chunk(
		parent_coord,
		parent_level
	)

	if parent_chunk == null: return
	if context.chunk_state.is_merge_pending(parent_chunk): return
	context.chunk_state.mark_merge_pending(parent_chunk)
	# 1. Clear the gate for this parent chunk level
	parent_chunk.subdivision_pending = false
	
	# 2. Clear gates for 8 potential child coordinates
	for x in range(2):
		for y in range(2):
			for z in range(2):
				var child_coord = (parent_coord * 2) + Vector3i(x, y, z)			
				if context.index.has_chunk(child_coord, parent_level + 1):
					var child_chunk = context.index.get_chunk(child_coord, parent_level + 1)
					context.chunk_state.clear_subdivision_pending(child_chunk)
					context.chunk_state.clear_merge_pending(child_chunk)

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
		context.chunk_state.clear_subdivision_pending(child)
		context.chunk_state.clear_merge_pending(child)

		context.index.remove_chunk(child.grid_info.chunk_coordinate,child.lod_level)
		context.chunk_state.unregister_chunk(child)
		parent_chunk.child_chunks.erase(child)
		context.pool.release(child)

	parent_chunk.child_chunks.clear()


func notify_chunk_mesh_ready(chunk: Chunk) -> void:
	# Added guard back to prevent LOD 0 processing
	if not is_instance_valid(chunk) or chunk.lod_level == 0:
		return
		
	var parent_chunk = chunk.parent_chunk
	if not is_instance_valid(parent_chunk):
		return

	if !context.chunk_state.is_subdivision_pending(parent_chunk):
		if parent_chunk.current_lod == chunk.lod_level:
			return 
			
		if context.is_dev:
			context.diagnostics.log_late_arrival(chunk.grid_info.chunk_coordinate)
			
		context.index.remove_chunk(chunk.grid_info.chunk_coordinate, chunk.lod_level)
		context.wireframe_controller.remove_chunk(chunk)
		context.chunk_state.unregister_chunk(chunk)
		context.pool.release(chunk)
		return
	
	var all_siblings_ready := true

	if parent_chunk.child_chunks.size() < 8:
		all_siblings_ready = false
	else:
		for sibling in parent_chunk.child_chunks:
			if not is_instance_valid(sibling):
				all_siblings_ready = false
				break

			if context.chunk_state.is_mesh_dirty(sibling):
				all_siblings_ready = false
				break

	if all_siblings_ready:
		subdivision_complete(
			parent_chunk.grid_info.chunk_coordinate,
			chunk.lod_level
		)
