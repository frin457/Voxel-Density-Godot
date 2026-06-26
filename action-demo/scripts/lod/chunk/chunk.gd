#./scripts/lod/chunk/chunk.gd
class_name Chunk extends StaticBody3D

@export var mat: Material
@onready var collisionShape: CollisionShape3D = $CollisionShape3D
@onready var meshInstance: MeshInstance3D = $MeshInstance3D

var current_meshing_index := 0

var pending_vertices := PackedVector3Array()
var pending_indices := PackedInt32Array()
var pending_normals := PackedVector3Array()
var pending_colors := PackedColorArray()

var parent_chunk: Chunk = null
var chunk_coordinate := Vector3i.ZERO
var child_chunks: Array[Chunk] = []

var active := true
var lod_level := 0       # structural depth
var current_lod := 0     # active subdivision state

# TODO:
# Currently unused.
# Intended for upwards LOD invalidation (0->1->2)
# example: terrain destruction modifies child chunks
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
var voxel_size := 1.0
var mesh_dirty := false
var collision_dirty := false

var voxel_ids := PackedByteArray()
var voxel_density := PackedByteArray()
var voxel_colors := PackedColorArray()

var original_voxel_ids := PackedByteArray()
var original_voxel_density := PackedByteArray()
var original_voxel_colors := PackedColorArray()

func _ready() -> void:
	if meshInstance and not meshInstance.mesh:
		meshInstance.mesh = ArrayMesh.new()


func deactivate() -> void:
	active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

	if meshInstance:		meshInstance.visible = false
	if collisionShape:	collisionShape.set_deferred("disabled", true)


func activate() -> void:
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	
	if meshInstance:		meshInstance.visible = true
	if collisionShape:	collisionShape.set_deferred("disabled",false)


func destroy_voxel() -> void:
	var index = get_1d_index(position.x,	position.y,	position.z)

	if voxel_ids[index] == 0: return

	voxel_ids[index] = 0
	voxel_density[index] = 0
	voxel_colors[index] = Color(0,0,0,0)
	_update_surface_cache()
	mark_dirty()
	#mark_lod_dirty()


func restore_voxel() -> void:
	var index = get_1d_index(position.x,position.y,position.z)

	if original_voxel_ids[index] == 0: return

	if voxel_ids[index] != 0: return

	voxel_ids[index] = original_voxel_ids[index]
	voxel_density[index] = original_voxel_density[index]
	voxel_colors[index] = original_voxel_colors[index]
	
	_update_surface_cache()
	mark_dirty()
	#mark_lod_dirty()

func set_voxel_data(data: Dictionary) -> void:
	voxel_ids = data["ids"].duplicate()
	voxel_density = data["density"].duplicate()
	voxel_colors = data["colors"].duplicate()

	original_voxel_ids = voxel_ids.duplicate()
	original_voxel_density = voxel_density.duplicate()
	original_voxel_colors = voxel_colors.duplicate()

	_update_surface_cache()
	mark_dirty()
	#mark_lod_dirty()

func _update_surface_cache() -> void:
	is_empty_air = true
	
	for k in sub_quadrant_has_surfaces.keys():
		sub_quadrant_has_surfaces[k] = false

	var half_size = float(chunk_size) * 0.5

	for z in range(chunk_size):
		for y in range(chunk_size):
			for x in range(chunk_size):
				var index = get_1d_index(x, y, z)

				if voxel_ids[index] == 0:
					continue

				is_empty_air = false

				var q_x = 1 if x >= half_size else 0
				var q_y = 1 if y >= half_size else 0
				var q_z = 1 if z >= half_size else 0

				sub_quadrant_has_surfaces[
					Vector3i(q_x, q_y, q_z)
				] = true


func mark_dirty() -> void:
	var already_dirty = mesh_dirty or collision_dirty
	if already_dirty:
			return
	mesh_dirty = true
	collision_dirty = true
	is_mesh_ready = false

	var manager = get_parent()
	if manager and manager.has_method("queue_dirty_chunk"):
		manager.queue_dirty_chunk(self)

func mark_lod_dirty() -> void:
	lod_dirty = true

	if parent_chunk:
		parent_chunk.mark_lod_dirty()

func clear_lod_dirty() -> void:
	lod_dirty = false

func get_current_lod() -> int:
	return current_lod


func get_1d_index(x: int, y: int, z: int) -> int:
	return (
		x +
		(y * chunk_size) +
		(z * chunk_size * chunk_size)
	)


func _exit_tree() -> void:
	if parent_chunk and is_instance_valid(parent_chunk):
		parent_chunk.child_chunks.erase(self)
