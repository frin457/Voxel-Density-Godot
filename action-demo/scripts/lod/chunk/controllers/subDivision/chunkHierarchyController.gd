#./scripts/lod/chunk/controllers/subDivision/chunkHierarchyController.gd
class_name ChunkHierarchyController extends RefCounted


func attach_child(
	parent: Chunk,
	child: Chunk
) -> void:
	if not is_instance_valid(parent):
		return
	if not is_instance_valid(child):
		return
	child.parent_chunk = parent

	if !parent.child_chunks.has(child):
		parent.child_chunks.append(child)


func detach_child(
	parent: Chunk,
	child: Chunk
) -> void:

	if not is_instance_valid(parent):
		return

	if not is_instance_valid(child):
		return

	parent.child_chunks.erase(child)

	if child.parent_chunk == parent:
		child.parent_chunk = null


func clear_children(parent: Chunk) -> void:

	if not is_instance_valid(parent):
		return

	for child in parent.child_chunks:
		if is_instance_valid(child):
			child.parent_chunk = null

	parent.child_chunks.clear()


func remove_descendants(
	context: EngineContext,
	parent: Chunk
) -> void:

	if not is_instance_valid(parent):
		return

	var children : Array[Chunk] = parent.child_chunks.duplicate()

	for child in children:

		if not is_instance_valid(child):
			continue

		remove_descendants(context, child)

		detach_child(parent, child)

		context.chunk_state.mark_subdivision_pending(child)
		context.chunk_state.mark_merge_pending(child)

		context.index.remove_chunk(
			child.grid_info.chunk_coordinate,
			child.lod_level
		)

		context.pool.release(child)

	parent.child_chunks.clear()


# ----------------------------
# HIERARCHY RESOLUTION
# ----------------------------
func attach_to_parent(
	context: EngineContext,
	child: Chunk
) -> void:

	if child.lod_level == 0:
		return

	var parent_coord := Vector3i(
		child.grid_info.chunk_coordinate.x >> 1,
		child.grid_info.chunk_coordinate.y >> 1,
		child.grid_info.chunk_coordinate.z >> 1
	)
	
	var parent_chunk: Chunk = context.index.get_chunk(parent_coord,child.lod_level - 1)
	if parent_chunk == null:
		return

	attach_child(parent_chunk,child)
