#./scripts/lod/chunk/chunkPool.gd
class_name ChunkPool extends RefCounted

var scene : PackedScene
var scene_root : Node

var inactive_chunks : Array[Chunk] = []


func _init(
	chunk_scene: PackedScene,
	root: Node
) -> void:

	scene = chunk_scene
	scene_root = root


func acquire() -> Chunk:
	if inactive_chunks.is_empty():
		var chunk: Chunk = scene.instantiate()
		scene_root.add_child(chunk)
		chunk.reset()
		return chunk

	var chunk : Chunk = inactive_chunks.pop_back()
	chunk.reset()
	return chunk


func release(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		return

	chunk.reset()
	chunk.deactivate()
	inactive_chunks.append(chunk)


func clear() -> void:
	for chunk in inactive_chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()

	inactive_chunks.clear()


func available() -> int:
	return inactive_chunks.size()


func is_empty() -> bool:
	return inactive_chunks.is_empty()
