class_name ChunkJob extends RefCounted

enum JobType {
	GENERATE,
	MESH,
	COLLISION,
	DESCTRUCT,
	SUBDIVIDE,
	MERGE
}

var type: JobType
var chunk_coord: Vector3i

# Optional payload depending on job type
var data: Dictionary = {}

# Priority system (future LOD support)
var priority: int = 0

func _init(_type: JobType, _coord: Vector3i, _data: Dictionary = {}, _priority: int = 0):
	type = _type
	chunk_coord = _coord
	data = _data
	priority = _priority
