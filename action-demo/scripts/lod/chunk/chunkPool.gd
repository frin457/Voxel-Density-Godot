# ./scripts/lod/chunk/pool/chunkPool.gd

class_name ChunkPool extends RefCounted


var scene: PackedScene

var inactive_chunks : Array[Chunk] = []


func _init(chunk_scene: PackedScene) -> void:
	scene = chunk_scene


func acquire() -> Chunk:

	if inactive_chunks.is_empty():
		return scene.instantiate()

	var chunk : Chunk = inactive_chunks.pop_back()

	chunk.reset()

	return chunk


func release(
	chunk: Chunk
) -> void:

	if !is_instance_valid(chunk):
		return

	chunk.reset()

	if chunk.get_parent():
		chunk.get_parent().remove_child(chunk)

	inactive_chunks.append(chunk)


func clear() -> void:

	for chunk in inactive_chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()

	inactive_chunks.clear()


func available() -> int:
	return inactive_chunks.size()
