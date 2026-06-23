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
var subdivision_level := 0

# Signals that this chunk's hierarchy state changed.
var lod_dirty := false


# ==================================================
# PERFORMANCE & SURFACE CACHING
# ==================================================

var is_empty_air := true

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
	if meshInstance:
		meshInstance.mesh = ArrayMesh.new()


func mark_dirty() -> void:
	mesh_dirty = true
	collision_dirty = true
	
	# Safely communicate up to the manager to queue this chunk for rebuilding
	var manager = get_parent()
	if manager and manager.has_method("queue_dirty_chunk"):
		manager.queue_dirty_chunk(self)


func clear_dirty() -> void:
	mesh_dirty = false
	collision_dirty = false


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
# DESTRUCTION
# ==================================================

func destroy_voxel(position) -> void:
	voxels.erase(position)

	_update_surface_cache()

	mark_dirty()
	mark_lod_dirty()


# ==================================================
# REGENERATION
# ==================================================

func restore_voxel(position) -> void:
	if original_voxels.has(position):
		voxels[position] = original_voxels[position]

		_update_surface_cache()

		mark_dirty()
		mark_lod_dirty()


func restore_all() -> void:
	pass


func begin_regeneration() -> void:
	pass


# ==================================================
# INTERNAL CACHE
# ==================================================

func _update_surface_cache() -> void:

	is_empty_air = voxels.is_empty()

	for k in sub_quadrant_has_surfaces.keys():
		sub_quadrant_has_surfaces[k] = false

	if is_empty_air:
		return

	var half_size := 16.0

	if is_inside_tree():
		var parent = get_parent()

		if parent is ChunkManager:
			half_size = float(parent.chunk_size) * 0.5

	for pos in voxels:

		var q_x = 1 if pos.x >= half_size else 0
		var q_y = 1 if pos.y >= half_size else 0
		var q_z = 1 if pos.z >= half_size else 0

		sub_quadrant_has_surfaces[
			Vector3i(q_x, q_y, q_z)
		] = true
