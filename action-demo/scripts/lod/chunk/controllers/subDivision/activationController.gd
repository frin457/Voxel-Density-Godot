#./scripts/lod/chunk/controllers/subDivision/activationController.gd
class_name ActivationController extends RefCounted


func activate(chunk: Chunk) -> void:

	if not is_instance_valid(chunk):
		return

	chunk.activate()


func deactivate(chunk: Chunk) -> void:

	if not is_instance_valid(chunk):
		return

	chunk.deactivate()


func activate_children(parent: Chunk) -> void:

	if not is_instance_valid(parent):
		return

	for child in parent.child_chunks:

		if is_instance_valid(child):
			child.activate()


func deactivate_children(parent: Chunk) -> void:

	if not is_instance_valid(parent):
		return

	for child in parent.child_chunks:

		if is_instance_valid(child):
			child.deactivate()


func swap_parent_for_children(parent: Chunk) -> void:

	if not is_instance_valid(parent):
		return

	activate_children(parent)

	parent.deactivate()


func restore_parent(parent: Chunk) -> void:

	if not is_instance_valid(parent):
		return

	deactivate_children(parent)

	parent.activate()
