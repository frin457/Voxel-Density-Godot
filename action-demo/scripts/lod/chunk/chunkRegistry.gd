# ./scripts/lod/chunk/chunkRegistry.gd
class_name ChunkRegistry
extends RefCounted

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

func get_highest_existing_lod(
	coordinate: Vector3i
) -> int:

	var highest := -1

	for key in _chunks:

		var chunk : Chunk = _chunks[key]

		if !is_instance_valid(chunk):
			continue

		if chunk.grid_info.chunk_coordinate != coordinate:
			continue

		if chunk.lod_level > highest:
			highest = chunk.lod_level

	return max(highest, 0)
