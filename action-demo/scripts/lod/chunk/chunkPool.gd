#./scripts/lod/chunk/chunkPool.gd
class_name ChunkPool extends RefCounted

var context : EngineContext
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
	var chunk : Chunk 
	if inactive_chunks.is_empty():
		chunk = scene.instantiate()
		scene_root.add_child(chunk)
		chunk.reset()
	else: chunk = inactive_chunks.pop_back()
	return chunk


func release(chunk: Chunk) -> void:
	if not is_instance_valid(chunk): return
	context.chunk_state.unregister_chunk(chunk)
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
