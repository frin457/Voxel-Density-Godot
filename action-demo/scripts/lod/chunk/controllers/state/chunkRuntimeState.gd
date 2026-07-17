#res://scripts/lod/chunk/controllers/state/ChunkRuntimeState.gd
class_name ChunkRuntimeState extends RefCounted

# ==================================================
# SUB STATE OBJECTS
# ==================================================
var operations := ChunkOperationState.new()
var queue := ChunkQueueState.new()
var pending := ChunkPendingState.new()


# ==================================================
# GENERAL STATE
# ==================================================
var stale := false
# ==================================================
# DIAGNOSTICS
# ==================================================
var last_state_change := 0

# ==================================================
# PUBLIC API
# ==================================================
func reset() -> void:
	operations.reset()
	queue.reset()
	pending.reset()

	stale = false
	last_state_change = 0
