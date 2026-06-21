class_name QueryController extends RefCounted

var manager: ChunkManager

# ----------------------------
# INIT
# ----------------------------
func _init(_manager: ChunkManager) -> void:
	manager = _manager


# ----------------------------
# GET CHUNK (SAFE)
# ----------------------------
func get_chunk(coord: Vector3i) -> Chunk:
	if manager.chunks.has(coord):
		return manager.chunks[coord]
	return null


# ----------------------------
# GET CHUNK FROM WORLD POSITION
# ----------------------------
func get_chunk_at_world_position(world_pos: Vector3) -> Chunk:

	var chunk_size = manager.chunkSize

	var coord = Vector3i(
		floor(world_pos.x / chunk_size),
		floor(world_pos.y / chunk_size),
		floor(world_pos.z / chunk_size)
	)

	return get_chunk(coord)


# ----------------------------
# GET NEIGHBORS (6-directional)
# ----------------------------
func get_neighbor_chunks(coord: Vector3i) -> Array[Chunk]:

	var neighbors: Array[Chunk] = []

	var offsets = [
		Vector3i( 1, 0, 0),
		Vector3i(-1, 0, 0),
		Vector3i( 0, 1, 0),
		Vector3i( 0,-1, 0),
		Vector3i( 0, 0, 1),
		Vector3i( 0, 0,-1)
	]

	for offset in offsets:
		var neighbor = get_chunk(coord + offset)
		if neighbor != null:
			neighbors.append(neighbor)

	return neighbors


# ----------------------------
# GET REGION (FOR FUTURE SUBDIVISION / DESTRUCTION)
# ----------------------------
func get_chunks_in_radius(center: Vector3i, radius: int) -> Array[Chunk]:

	var results: Array[Chunk] = []

	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			for z in range(center.z - radius, center.z + radius + 1):

				var c = Vector3i(x, y, z)
				var chunk = get_chunk(c)

				if chunk != null:
					results.append(chunk)

	return results
