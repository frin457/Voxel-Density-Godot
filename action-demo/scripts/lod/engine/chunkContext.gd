class_name ChunkContext extends RefCounted


# World ownership
var chunks : Dictionary = {}

# Pools
var inactive_chunks : Array[Chunk] = []

# Queues
var job_queue : ChunkJobQueue

# Diagnostics
var diagnostics : DiagnosticsController

# Configuration
var is_dev := false

# --------------------------------------------------

func get_chunk_key(
	coord: Vector3i,
	lod: int
) -> String:

	return "%d_%d_%d_LOD%d" % [
		coord.x,
		coord.y,
		coord.z,
		lod
	]


func has_chunk(key:String)->bool:
	return chunks.has(key)


func get_chunk(key:String)->Chunk:
	return chunks.get(key)


func erase_chunk(key:String)->void:
	chunks.erase(key)


func release_chunk(chunk:Chunk)->void:
	pass
