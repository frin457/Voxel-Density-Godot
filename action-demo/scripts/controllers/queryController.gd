class_name QueryController extends RefCounted

var chunk_manager: ChunkManager


func _init(manager: ChunkManager):
	chunk_manager = manager


# --------------------------------------------------
# Chunk Lookup
# --------------------------------------------------

func get_chunk(chunk_coord: Vector3i) -> Chunk:
	return chunk_manager.chunks.get(chunk_coord)


func has_chunk(chunk_coord: Vector3i) -> bool:
	return chunk_manager.chunks.has(chunk_coord)


# --------------------------------------------------
# World Position -> Chunk
# --------------------------------------------------

func get_chunk_at_world_position(world_position: Vector3) -> Chunk:

	var chunk_coord = Vector3i(
		floor(world_position.x / chunk_manager.chunkSize),
		floor(world_position.y / chunk_manager.chunkSize),
		floor(world_position.z / chunk_manager.chunkSize)
	)

	return get_chunk(chunk_coord)


# --------------------------------------------------
# World Position -> Chunk Coordinate
# --------------------------------------------------

func get_chunk_coord(world_position: Vector3) -> Vector3i:

	return Vector3i(
		floor(world_position.x / chunk_manager.chunkSize),
		floor(world_position.y / chunk_manager.chunkSize),
		floor(world_position.z / chunk_manager.chunkSize)
	)


# --------------------------------------------------
# Voxel Query
# --------------------------------------------------

func get_voxel(world_position: Vector3):

	var chunk = get_chunk_at_world_position(world_position)

	if chunk == null:
		return null

	var local_position = world_position - chunk.global_position

	var voxel_coord = Vector3(
		floor(local_position.x / chunk.voxel_size),
		floor(local_position.y / chunk.voxel_size),
		floor(local_position.z / chunk.voxel_size)
	)

	return chunk.voxels.get(voxel_coord)


# --------------------------------------------------
# Neighbor Queries
# --------------------------------------------------

func get_neighbor_chunks(chunk_coord: Vector3i) -> Array[Chunk]:

	var neighbors: Array[Chunk] = []

	var directions = [
		Vector3i.LEFT,
		Vector3i.RIGHT,
		Vector3i.UP,
		Vector3i.DOWN,
		Vector3i.FORWARD,
		Vector3i.BACK
	]

	for dir in directions:

		var coord = chunk_coord + dir

		if chunk_manager.chunks.has(coord):
			neighbors.append(
				chunk_manager.chunks[coord]
			)

	return neighbors


# --------------------------------------------------
# Radius Query
# --------------------------------------------------

func get_chunks_in_radius(
	world_position: Vector3,
	radius: float
) -> Array[Chunk]:

	var results: Array[Chunk] = []

	for chunk in chunk_manager.chunks.values():

		if chunk.global_position.distance_to(world_position) <= radius:
			results.append(chunk)

	return results


# --------------------------------------------------
# Bounds Query
# --------------------------------------------------

func get_chunks_in_bounds(bounds: AABB) -> Array[Chunk]:

	var results: Array[Chunk] = []

	for chunk in chunk_manager.chunks.values():

		var chunk_bounds = AABB(
			chunk.global_position,
			Vector3.ONE * chunk_manager.chunkSize
		)

		if bounds.intersects(chunk_bounds):
			results.append(chunk)

	return results
