# ./scripts/lod/chunk/chunkRegistry.gd

class_name ChunkRegistry extends RefCounted

var _chunks: Dictionary = {}


func add_chunk(chunk: Chunk) -> void:
	if !is_instance_valid(chunk):
		return

	_chunks[get_key(
		chunk.chunk_coordinate,
		chunk.lod_level
	)] = chunk


func remove_chunk(
	coordinate: Vector3i,
	lod_level: int
) -> void:

	_chunks.erase(
		get_key(
			coordinate,
			lod_level
		)
	)


func remove(chunk: Chunk) -> void:

	if !is_instance_valid(chunk):
		return

	remove_chunk(
		chunk.chunk_coordinate,
		chunk.lod_level
	)


func find_chunk(
	coordinate: Vector3i,
	lod_level: int
) -> Chunk:

	return _chunks.get(
		get_key(
			coordinate,
			lod_level
		)
	)


func contains(
	coordinate: Vector3i,
	lod_level: int
) -> bool:

	return _chunks.has(
		get_key(
			coordinate,
			lod_level
		)
	)


func clear() -> void:
	_chunks.clear()


func size() -> int:
	return _chunks.size()


func values() -> Array:
	return _chunks.values()


func get_key(
	coordinate: Vector3i,
	lod_level: int
) -> String:

	return "%d_%d_%d_LOD%d" % [
		coordinate.x,
		coordinate.y,
		coordinate.z,
		lod_level
	]
