class_name ChunkJob
extends RefCounted

enum JobType {
	GENERATE,
	MESH,
	COLLISION,
	DESCTRUCT,
	SUBDIVIDE,
	MERGE
}

var type: JobType
var chunk_coordinate: Vector3i

var data: Dictionary = {}

# 🔥 NEW: world-space position (cached for priority)
var world_position: Vector3

# 🔥 NEW: priority (higher = processed first)
var priority: float = 0.0

# 🔥 NEW: level of detail hint
var lod_level: int = 0


func _init(
	_type: JobType,
	_coord: Vector3i,
	_world_position: Vector3 = Vector3.ZERO,
	_data: Dictionary = {},
	_priority: float = 0.0,
	_lod: int = 0
):

	type = _type
	chunk_coordinate = _coord
	world_position = _world_position
	data = _data
	priority = _priority
	lod_level = _lod
