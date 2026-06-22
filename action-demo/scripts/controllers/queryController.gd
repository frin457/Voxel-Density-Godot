#./scripts/controllers/queryController.gd
class_name QueryController extends RefCounted

var manager: ChunkManager

func _init(_manager: ChunkManager) -> void:
	manager = _manager

# Safe chunk retrieval by mapping coordinate lookup into compound keys
func get_chunk(coord: Vector3i, lod_level: int = 0) -> Chunk:
	var key = manager.get_chunk_key(coord, lod_level)
	if manager.chunks.has(key):
		return manager.chunks[key]
	return null

func get_chunk_at_world_position(world_pos: Vector3, lod_level: int = 0) -> Chunk:
	var current_chunk_world_size = manager.get_chunk_world_size() / pow(2, lod_level)

	var coord = Vector3i(
		floor(world_pos.x / current_chunk_world_size),
		floor(world_pos.y / current_chunk_world_size),
		floor(world_pos.z / current_chunk_world_size)
	)

	return get_chunk(coord, lod_level)

func get_neighbor_chunks(coord: Vector3i, lod_level: int = 0) -> Array[Chunk]:
	var neighbors: Array[Chunk] = []
	var offsets = [
		Vector3i( 1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i( 0, 1, 0), Vector3i( 0,-1, 0),
		Vector3i( 0, 0, 1), Vector3i( 0, 0,-1)
	]

	for offset in offsets:
		var neighbor = get_chunk(coord + offset, lod_level)
		if neighbor != null:
			neighbors.append(neighbor)

	return neighbors

func get_chunks_in_radius(center: Vector3i, radius: int, lod_level: int = 0) -> Array[Chunk]:
	var results: Array[Chunk] = []

	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			for z in range(center.z - radius, center.z + radius + 1):
				var chunk = get_chunk(Vector3i(x, y, z), lod_level)
				if chunk != null:
					results.append(chunk)

	return results
