#./scripts/chunk/chunk.gd
class_name Chunk extends StaticBody3D

@export var mat: Material

@onready var collisionShape: CollisionShape3D = $CollisionShape3D
@onready var meshInstance: MeshInstance3D = $MeshInstance3D

# ==================================================
# LOD & OCTREE HIERARCHY
# ==================================================
var parent_chunk: Chunk = null
var child_chunks: Array[Chunk] = []
var active := true
var subdivision_level: int = 0

# ==================================================
# VOXEL STATE
# ==================================================
# Original terrain definition. Never modified.
var original_voxels: Dictionary = {}
# Current live state.
var voxels: Dictionary = {}

# Future regeneration timer support.
var regeneration_enabled := false
# Seconds until restoration begins.
var regeneration_delay := 0.0
# Optional restoration speed.
var regeneration_rate := 0.0

var voxel_size: float = 1.0
var visual_bounds_mesh: MeshInstance3D = null # Holds wireframe reference

var mesh_dirty := false
var collision_dirty := false


#func _ready() -> void:
	## Avoid overwriting an already generated/assigned mesh
	#if meshInstance and meshInstance.mesh == null:
		#meshInstance.mesh = ArrayMesh.new()

func _ready() -> void:
	# CRITICAL FIX: Explicitly assign a unique ArrayMesh instance 
	# to break the shared template resource link across instances!
	if meshInstance:
		meshInstance.mesh = ArrayMesh.new()

func mark_dirty() -> void:
	mesh_dirty = true
	collision_dirty = true


func clear_dirty() -> void:
	mesh_dirty = false
	collision_dirty = false


func set_voxel_data(data: Dictionary) -> void:
	# Permanent source state.
	original_voxels = data.duplicate(true)
	# Runtime state.
	voxels = data.duplicate(true)
	mark_dirty()


# ==================================================
# LOD ACTIVATION CONTROL (level of detail)
# ==================================================
func deactivate() -> void:
	active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

	if meshInstance:
		meshInstance.visible = false

	if collisionShape:
		# Use set_deferred to avoid physics physics-server errors mid-frame
		collisionShape.set_deferred("disabled", true)


func activate() -> void:
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT

	if meshInstance:
		meshInstance.visible = true

	if collisionShape:
		collisionShape.set_deferred("disabled", false)


# ==================================================
# DESTRUCTION SYSTEM
# ==================================================
func destroy_voxel(position) -> void:
	voxels.erase(position)
	mark_dirty()


# ==================================================
# REGENERATION SYSTEM
# ==================================================
func restore_voxel(position) -> void:
	if original_voxels.has(position):
		voxels[position] = original_voxels[position]
		mark_dirty()


func restore_all() -> void:
	pass


func begin_regeneration() -> void:
	pass
