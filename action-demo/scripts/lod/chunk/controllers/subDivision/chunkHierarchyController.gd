#./scripts/lod/chunk/controllers/subDivision/activationController.gd
class_name ChunkHierarchyController extends RefCounted


func attach_child(
	parent: Chunk,
	child: Chunk
) -> void:

	if not is_instance_valid(parent):
		return

	if not is_instance_valid(child):
		return

	if not parent.child_chunks.has(child):
		parent.child_chunks.append(child)

	child.parent_chunk = parent


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
	manager: ChunkManager,
	parent: Chunk
) -> void:

	if not is_instance_valid(parent):
		return

	var children := parent.child_chunks.duplicate()

	for child in children:

		if not is_instance_valid(child):
			continue

		remove_descendants(manager, child)

		detach_child(parent, child)

		child.subdivision_pending = false
		child.merge_pending = false

		manager.chunks.erase(
			manager.get_chunk_key(
				child.chunk_coordinate,
				child.lod_level
			)
		)

		manager.release_chunk(child)

	parent.child_chunks.clear()
