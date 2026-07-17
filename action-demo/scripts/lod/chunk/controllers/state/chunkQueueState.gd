#res://scripts/lod/chunk/controllers/state/ChunkQueueState.gd
class_name ChunkQueueState extends RefCounted

var generation := false
var mesh := false
var collision := false

func reset() -> void:
	generation = false
	mesh = false
	collision = false
