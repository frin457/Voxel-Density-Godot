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
# PERFORMANCE & SURFACE CACHING
# ==================================================
## True if this chunk contains absolutely zero voxel data (pure air)
var is_empty_air := true

## Pre-calculated flags tracking which of the 8 potential high-LOD sub-quadrants contain voxels
var sub_quadrant_has_surfaces := {
	Vector3i(0,0,0): false, Vector3i(1,0,0): false,
	Vector3i(0,1,0): false, Vector3i(1,1,0): false,
	Vector3i(0,0,1): false, Vector3i(1,0,1): false,
	Vector3i(0,1,1): false, Vector3i(1,1,1): false
}

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
	original_voxels.clear()
	voxels.clear()
	
	for pos in data:
		var src_voxel = data[pos] as Voxel
		
		# Create separate instances for the baseline and live states
		var backup = Voxel.new(src_voxel.color)
		backup.health = src_voxel.health
		backup.density = src_voxel.density
		backup.material_type = src_voxel.material_type
		
		var live = Voxel.new(src_voxel.color)
		live.health = src_voxel.health
		live.density = src_voxel.density
		live.material_type = src_voxel.material_type
		
		original_voxels[pos] = backup
		voxels[pos] = live
		
	_update_surface_cache()
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
	_update_surface_cache()
	mark_dirty()


# ==================================================
# REGENERATION SYSTEM
# ==================================================
func restore_voxel(position) -> void:
	if original_voxels.has(position):
		voxels[position] = original_voxels[position]
		_update_surface_cache()
		mark_dirty()


func restore_all() -> void:
	pass


func begin_regeneration() -> void:
	pass


# ==================================================
# INTERNAL CACHE PROCESSING
# ==================================================
func _update_surface_cache() -> void:
	is_empty_air = voxels.is_empty()
	
	# Clear previous sub-quadrant calculations
	for k in sub_quadrant_has_surfaces.keys():
		sub_quadrant_has_surfaces[k] = false
		
	if is_empty_air:
		return
		
	# Determine the center splitting boundary line of the voxel grid dimensions
	var half_size : float
	if is_inside_tree() and get_parent() is ChunkManager:
		half_size = get_parent().chunk_size / 2

	# Evaluate which sub-quadrants contain physical surfaces
	for pos in voxels:
		var q_x = 1 if pos.x >= half_size else 0
		var q_y = 1 if pos.y >= half_size else 0
		var q_z = 1 if pos.z >= half_size else 0
		sub_quadrant_has_surfaces[Vector3i(q_x, q_y, q_z)] = true
