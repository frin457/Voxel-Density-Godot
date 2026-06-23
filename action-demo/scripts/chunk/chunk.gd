# ./scripts/components/chunk.gd
class_name Chunk extends StaticBody3D

@export var mat: Material

@onready var collisionShape: CollisionShape3D = $CollisionShape3D
@onready var meshInstance: MeshInstance3D = $MeshInstance3D

# ==================================================
# LOD & OCTREE HIERARCHY
# ==================================================
# Add this under your "LOD & OCTREE HIERARCHY" section
var parent_chunk: Chunk = null
var child_chunks: Array[Chunk] = []
var chunk_coordinate := Vector3i.ZERO

var active := true
var subdivision_level := 0
var lod_dirty := false

# ==================================================
# PERFORMANCE & SURFACE CACHING
# ==================================================
@export var chunk_size: int = 32 # FIXED: Maintain explicit sizing independent of SceneTree state

var is_empty_air := true
var is_mesh_ready := false # Track if the asynchronous mesh generation is ready

var sub_quadrant_has_surfaces := {
	Vector3i(0,0,0): false,
	Vector3i(1,0,0): false,
	Vector3i(0,1,0): false,
	Vector3i(1,1,0): false,
	Vector3i(0,0,1): false,
	Vector3i(1,0,1): false,
	Vector3i(0,1,1): false,
	Vector3i(1,1,1): false
}

# ==================================================
# VOXEL STATE
# ==================================================
var original_voxels: Dictionary = {}
var voxels: Dictionary = {}

var regeneration_enabled := false
var regeneration_delay := 0.0
var regeneration_rate := 0.0
var voxel_size := 1.0

var visual_bounds_mesh: MeshInstance3D = null
var mesh_dirty := false
var collision_dirty := false

func _ready() -> void:
	if meshInstance and not meshInstance.mesh:
		meshInstance.mesh = ArrayMesh.new()

func mark_dirty() -> void:
	mesh_dirty = true
	collision_dirty = true
	is_mesh_ready = false # Reset readiness until thread completes compilation
	
	var manager = get_parent()
	if manager and manager.has_method("queue_dirty_chunk"):
		manager.queue_dirty_chunk(self)

func clear_dirty() -> void:
	mesh_dirty = false
	collision_dirty = false
	is_mesh_ready = true # Set ready when meshing system clears dirty flags

	# FIXED: Atomic Handoff Trigger
	# If this is a parent chunk that finished building while waiting to merge,
	# notify the controller to safely clear away old child geometry now.
	var manager = get_parent()
	if manager and "subdivision_controller" in manager:
		manager.subdivision_controller.notify_chunk_mesh_ready(self)

func mark_lod_dirty() -> void:
	lod_dirty = true
	if parent_chunk:
		parent_chunk.mark_lod_dirty()

func clear_lod_dirty() -> void:
	lod_dirty = false

func set_voxel_data(data: Dictionary) -> void:
	original_voxels.clear()
	voxels.clear()

	for pos in data:
		var src_voxel = data[pos] as Voxel
		if not src_voxel: continue

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
# LOD CONTROL
# ==================================================
func deactivate() -> void:
	active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if meshInstance:
		meshInstance.visible = false
	if collisionShape:
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
# DESTRUCTION & MODIFICATION
# ==================================================
func destroy_voxel(position) -> void:
	voxels.erase(position)
	_update_surface_cache()
	mark_dirty()
	mark_lod_dirty()

func restore_voxel(position) -> void:
	if original_voxels.has(position):
		voxels[position] = original_voxels[position]
		_update_surface_cache()
		mark_dirty()
		mark_lod_dirty()

# ==================================================
# INTERNAL CACHE
# ==================================================
func _update_surface_cache() -> void:
	is_empty_air = voxels.is_empty()

	for k in sub_quadrant_has_surfaces.keys():
		sub_quadrant_has_surfaces[k] = false

	if is_empty_air:
		return

	# FIXED: Safely read local chunk size property. Completely thread-safe
	# and unaffected by tree attachment state.
	var half_size = float(chunk_size) * 0.5

	for pos in voxels:
		var q_x = 1 if pos.x >= half_size else 0
		var q_y = 1 if pos.y >= half_size else 0
		var q_z = 1 if pos.z >= half_size else 0

		sub_quadrant_has_surfaces[Vector3i(q_x, q_y, q_z)] = true
