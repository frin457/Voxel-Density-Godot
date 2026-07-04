# ./scripts/lod/chunk/chunkJob.gd
class_name ChunkJob extends RefCounted

enum JobType {
	GENERATE,
	DESTRUCT,
	SUBDIVIDE,
	MERGE,
	MESH
}

var type: JobType
var chunk_coordinate: Vector3i

var data: VoxelChunkData

var world_position: Vector3

var priority: float = 0.0

var lod_level: int = 0
var sort_index: int = 0


func _init(
	_type: JobType,
	_coord: Vector3i,
	_world_position: Vector3 = Vector3.ZERO,
	_data: VoxelChunkData = null,
	_priority: float = 0.0,
	_lod: int = 0,
	_sort_index: int = 0
) -> void:

	type = _type
	chunk_coordinate = _coord
	world_position = _world_position

	data = _data if _data != null else VoxelChunkData.new()

	priority = _priority
	lod_level = _lod
	sort_index = _sort_index
