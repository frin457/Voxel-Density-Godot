class_name Chunk extends StaticBody3D

# ==================================================
# CORE OWNERSHIP (KEEP)
# ==================================================

var manager: ChunkManager
var voxel_data:= VoxelData.new()
var grid_info := VoxelGridInfo.new()
var parent_chunk: Chunk = null
var child_chunks: Array[Chunk] = []

var chunk_coordinate := Vector3i.ZERO

var active := true
var lod_level := 0
var current_lod := 0

var mesh_dirty := false
var collision_dirty := false

var subdivision_pending := false
var merge_pending := false

# ==================================================
# SCENE REFERENCES 	
# ==================================================

@onready var collisionShape: CollisionShape3D = $CollisionShape3D
@onready var meshInstance: MeshInstance3D = $MeshInstance3D

# ==================================================
# CONFIG
# ==================================================

@export var chunk_size := grid_info.chunk_size
var chunk_size_sq := grid_info.chunk_size_sq
var voxel_size := grid_info.voxel_size

# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	chunk_size_sq = chunk_size * chunk_size
	if meshInstance and not meshInstance.mesh:
		meshInstance.mesh = ArrayMesh.new()

# ==================================================
# LIFECYCLE (CORE CONTRACT)
# ==================================================

func activate() -> void:
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT

	if meshInstance:
		meshInstance.visible = true

	if collisionShape:
		if not collision_dirty and collisionShape.shape == null:
			mark_dirty()
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
# RESET (POOL CONTRACT)
# ==================================================

func reset() -> void:
	parent_chunk = null
	child_chunks.clear()

	active = false
	lod_level = 0
	current_lod = 0

	subdivision_pending = false
	merge_pending = false

	mesh_dirty = false
	collision_dirty = false
	
# ==================================================
# DIRTY STATE (SIGNAL CONTRACT)
# ==================================================

func mark_dirty() -> void:
	if mesh_dirty and collision_dirty:
		return

	mesh_dirty = true
	collision_dirty = true

	if manager:
		manager.queue_dirty_chunk(self)
