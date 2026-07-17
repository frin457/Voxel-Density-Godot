#res://scripts/lod/chunk/controllers/state/ChunkPendingState.gd
class_name ChunkPendingState extends RefCounted


# Dirty State
var mesh_dirty := false
var collision_dirty := false

# Deferred Work
var subdivision := false
var merge := false


func reset() -> void:
	mesh_dirty = false
	collision_dirty = false

	subdivision = false
	merge = false
