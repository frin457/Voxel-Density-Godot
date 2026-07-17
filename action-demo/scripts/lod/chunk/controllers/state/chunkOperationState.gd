#res://scripts/lod/chunk/controllers/state/ChunkOperationState.gd
class_name ChunkOperationState extends RefCounted

# Active Operations
var generating := false
var meshing := false
var colliding := false

# LOD Operations
var subdividing := false
var merging := false

# Future Operations
var destroying := false
var restoring := false

func reset() -> void:
	generating = false
	meshing = false
	colliding = false

	subdividing = false
	merging = false

	destroying = false
	restoring = false
