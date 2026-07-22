class_name Chunk
extends StaticBody3D

# ==================================================
# CORE OWNERSHIP
# ==================================================

var manager: ChunkManager

var voxel_data := VoxelChunkData.new()
var grid_info := VoxelGridInfo.new()

var parent_chunk: Chunk = null
var child_chunks: Array[Chunk] = []

var active := true

var lod_level := 0
var current_lod := 0

# ==================================================
# PIPELINE STATE
# ==================================================

var mesh_dirty := false
var mesh_queued := false

var collision_dirty := false
var collision_queued := false

var subdivision_pending := false
var merge_pending := false

# ==================================================
# VISUALS
# ==================================================

var mat: Material

# ==================================================
# SCENE REFERENCES
# ==================================================

@onready var collisionShape: CollisionShape3D = $CollisionShape3D
@onready var meshInstance: MeshInstance3D = $MeshInstance3D

# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	if meshInstance and meshInstance.mesh == null:
		meshInstance.mesh = ArrayMesh.new()

# ==================================================
# LIFECYCLE
# ==================================================

func activate() -> void:
	active = true

	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT

	if meshInstance:
		meshInstance.visible = true

	if collisionShape:
		collisionShape.set_deferred("disabled", false)


func deactivate() -> void:
	active = false

	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

	if meshInstance:
		meshInstance.visible = false

	if collisionShape:
		collisionShape.set_deferred("disabled", true)

# ==================================================
# POOL RESET
# ==================================================

func reset() -> void:
	parent_chunk = null
	child_chunks.clear()

	active = false

	lod_level = 0
	current_lod = 0

	mat = null

# ==================================================
# STATE
# ==================================================

func mark_dirty() -> void:

	if manager:
		var state = manager.context.chunk_state

		state.mark_mesh_dirty(self)
		state.mark_collision_dirty(self)
		state.mark_stale(self)

		manager.context.diagnostics.log_dirty_queued(self)

		manager.queue_dirty_chunk(self)
