class_name Chunk extends StaticBody3D

@export var mat: Material
@onready var collisionShape: CollisionShape3D = $CollisionShape3D
@onready var meshInstance: MeshInstance3D = $MeshInstance3D

var parent_chunk: Chunk = null
var chunk_coordinate := Vector3i.ZERO
var child_chunks: Array[Chunk] = []

var active := true
var lod_level := 0       # structural depth
var current_lod := 0     # active subdivision state
var lod_dirty := false


# ==================================================
# PERFORMANCE & SURFACE CACHING
# ==================================================
@export var chunk_size: int = 32

var is_empty_air := true
var is_mesh_ready := false

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

var visual_bounds_mesh: MeshInstance3D = null
var voxels: Dictionary = {}
var original_voxels: Dictionary = {}
var voxel_size := 1.0
var mesh_dirty := false
var collision_dirty := false

func _ready() -> void:
	if meshInstance and not meshInstance.mesh:
		meshInstance.mesh = ArrayMesh.new()

func _exit_tree() -> void:
	if parent_chunk and is_instance_valid(parent_chunk):
		parent_chunk.child_chunks.erase(self)

func mark_dirty() -> void:
	var already_dirty = mesh_dirty or collision_dirty

	mesh_dirty = true
	collision_dirty = true
	is_mesh_ready = false

	if already_dirty:
		return

	var manager = get_parent()
	if manager and manager.has_method("queue_dirty_chunk"):
		manager.queue_dirty_chunk(self)
		
func evaluate_ready() -> void:
	if not mesh_dirty and not collision_dirty:
		clear_dirty()
		
func clear_dirty() -> void:
	mesh_dirty = false
	collision_dirty = false
	is_mesh_ready = true

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

		if not src_voxel:
			continue

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

func destroy_voxel(position) -> void:
	# Stability Improvement Guard: Check if the voxel actually exists before erasing
	if not voxels.has(position):
		return

	voxels.erase(position)

	# Only update cache and mark dirty if state actually changed
	_update_surface_cache()
	mark_dirty()
	mark_lod_dirty()


func restore_voxel(position) -> void:
	# Stability Improvement Guard: Only restore if original data exists AND it isn't already restored
	if original_voxels.has(position) and not voxels.has(position):
		voxels[position] = original_voxels[position]

		# Only update cache and mark dirty if state actually changed
		_update_surface_cache()
		mark_dirty()
		mark_lod_dirty()

func _update_surface_cache() -> void:
	is_empty_air = voxels.is_empty()

	for k in sub_quadrant_has_surfaces.keys():
		sub_quadrant_has_surfaces[k] = false

	if is_empty_air:
		return

	var half_size = float(chunk_size) * 0.5

	for pos in voxels:
		var q_x = 1 if pos.x >= half_size else 0
		var q_y = 1 if pos.y >= half_size else 0
		var q_z = 1 if pos.z >= half_size else 0

		sub_quadrant_has_surfaces[
			Vector3i(q_x, q_y, q_z)
		] = true


func get_current_lod() -> int:
	return current_lod
