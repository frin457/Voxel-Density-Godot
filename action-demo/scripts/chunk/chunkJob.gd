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
var chunkCoordinate: Vector3i

var data: Dictionary = {}

# 🔥 NEW: world-space position (cached for priority)
var worldPos: Vector3

# 🔥 NEW: priority (higher = processed first)
var priority: float = 0.0

# 🔥 NEW: level of detail hint
var lodLevel: int = 0


func _init(
	_type: JobType,
	_coord: Vector3i,
	_world_position: Vector3 = Vector3.ZERO,
	_data: Dictionary = {},
	_priority: float = 0.0,
	_lod: int = 0
):

	type = _type
	chunkCoordinate = _coord
	worldPos = _world_position
	data = _data
	priority = _priority
	lodLevel = _lod
