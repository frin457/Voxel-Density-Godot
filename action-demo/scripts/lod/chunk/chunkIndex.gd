# ./scripts/lod/chunk/chunkRegistry.gd
class_name ChunkIndex extends RefCounted
var _chunks: Dictionary = {}

# ==================================================
# PUBLIC API
# ==================================================
func register_chunk(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		return

	_chunks[_get_key(
		chunk.grid_info.chunk_coordinate,
		chunk.lod_level
	)] = chunk


func has_chunk(
	coordinate: Vector3i,
	lod: int
) -> bool:

	return _chunks.has(
		_get_key(coordinate, lod)
	)


func get_chunk(
	coordinate: Vector3i,
	lod: int
) -> Chunk:

	return _chunks.get(
		_get_key(coordinate, lod),
		null
	)


func remove_chunk(
	coordinate: Vector3i,
	lod: int
) -> void:

	_chunks.erase(
		_get_key(coordinate, lod)
	)


func clear() -> void:
	_chunks.clear()


func values() -> Array:
	return _chunks.values()


func size() -> int:
	return _chunks.size()


func is_empty() -> bool:
	return _chunks.is_empty()


# ==================================================
# PRIVATE
# ==================================================

func _get_key(
	coordinate: Vector3i,
	lod: int
) -> String:

	return "%d_%d_%d_LOD%d" % [
		coordinate.x,
		coordinate.y,
		coordinate.z,
		lod
	]


func get_highest_existing_lod(coordinate: Vector3i) -> int:
	for lod in range(10, -1, -1):
		if has_chunk(coordinate, lod):
			return lod
	return 0


func get_all_chunks() -> Array[Chunk]:
	var results : Array[Chunk] = []

	for value in _chunks.values():
		results.append(value)
	return results


func get_chunks_at_lod(lod: int) -> Array[Chunk]:
	var results : Array[Chunk] = []

	for chunk in _chunks.values():
		if chunk.lod_level == lod:
			results.append(chunk)
	return results
