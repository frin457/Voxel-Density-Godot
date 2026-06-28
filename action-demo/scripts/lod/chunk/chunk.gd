#./scripts/lod/chunk/chunk.gd
class_name Chunk extends StaticBody3D

var manager: ChunkManager
@export var mat: Material
@onready var collisionShape: CollisionShape3D = $CollisionShape3D
@onready var meshInstance: MeshInstance3D = $MeshInstance3D

var parent_chunk: Chunk = null
var chunk_coordinate := Vector3i.ZERO
var child_chunks: Array[Chunk] = []

var active := true
var lod_level := 0       # structural depth
var current_lod := 0     # active subdivision state

# LOD transistion state params
var requested_lod := -1
var subdivision_pending := false
var merge_pending := false

# ==================================================
# PERFORMANCE & SURFACE CACHING
# ==================================================
@export var chunk_size:= 32
var chunk_size_sq := 1024
var current_meshing_index := 0

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

# --- Async State Parameters ---
var collision_cooking := false 
var collision_stale := false 
var collision_queued := false # Added to prevent O(N) array checks
var mesh_cooking := false
var mesh_stale := false
# ------------------------------

var voxel_ids := PackedByteArray()
var voxel_density := PackedByteArray()
var voxel_colors := PackedColorArray()

var original_voxel_ids := PackedByteArray()
var original_voxel_density := PackedByteArray()
var original_voxel_colors := PackedColorArray()

var pending_surface_arrays := []

func _ready() -> void:
	chunk_size_sq = chunk_size * chunk_size
	if meshInstance and not meshInstance.mesh:
		meshInstance.mesh = ArrayMesh.new()


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
		# null assignment forces the Godot Physics Server to cleanly rebuild its broadphase 
		# tracking bounds for this chunk, rather than utilizing stale data.
		if not collision_dirty and collisionShape.shape == null:
			mark_dirty() 
		collisionShape.set_deferred("disabled", false)


func destroy_voxel() -> void:
	var index = chunk_coordinate.x + chunk_coordinate.y * chunk_size + chunk_coordinate.z * chunk_size_sq

	if voxel_ids[index] == 0: return

	voxel_ids[index] = 0
	voxel_density[index] = 0
	voxel_colors[index] = Color(0,0,0,0)
	_update_surface_cache()
	mark_dirty()


func restore_voxel() -> void:
	var index = chunk_coordinate.x + chunk_coordinate.y * chunk_size + chunk_coordinate.z * chunk_size_sq

	if original_voxel_ids[index] == 0: return

	if voxel_ids[index] != 0: return

	voxel_ids[index] = original_voxel_ids[index]
	voxel_density[index] = original_voxel_density[index]
	voxel_colors[index] = original_voxel_colors[index]
	
	_update_surface_cache()
	mark_dirty()

func set_voxel_data(data: Dictionary) -> void:
	voxel_ids = data["ids"].duplicate()
	voxel_density = data["density"].duplicate()
	voxel_colors = data["colors"].duplicate()

	original_voxel_ids = voxel_ids.duplicate()
	original_voxel_density = voxel_density.duplicate()
	original_voxel_colors = voxel_colors.duplicate()

	_update_surface_cache()
	mark_dirty()

func _update_surface_cache() -> void:
	is_empty_air = true

	# Pre-allocate keys Vector3i for memory allocations
	var q_keys = [
		Vector3i(0,0,0), Vector3i(1,0,0),
		Vector3i(0,1,0), Vector3i(1,1,0),
		Vector3i(0,0,1), Vector3i(1,0,1),
		Vector3i(0,1,1), Vector3i(1,1,1)
	]

	# Use a flat boolean array fast memory lookups (indices 0-7)
	var q_found = [false, false, false, false, false, false, false, false]
	var quadrants_completed = 0

	var half_size = int(chunk_size / 2)
	var size = chunk_size
	var size_sq = size * size

	for z in range(size):
		var z_offset = z * size_sq
		var q_z = 4 if z >= half_size else 0 # Generates 0 or 4

		for y in range(size):
			var y_offset = y * size
			var q_y = 2 if y >= half_size else 0 # Generates 0 or 2

			for x in range(size):
				var index = x + y_offset + z_offset

				if voxel_ids[index] == 0:
					continue

				is_empty_air = false

				# Calculate a flat integer index (0 to 7)
				var q_x = 1 if x >= half_size else 0
				var flat_q_index = q_x + q_y + q_z

				if not q_found[flat_q_index]:
					q_found[flat_q_index] = true
					quadrants_completed += 1

				# EARLY EXIT: If we found a surface in all 8 quadrants
				if quadrants_completed == 8:
					break
			if quadrants_completed == 8: break
		if quadrants_completed == 8: break

	# Map to Dictionary exactly ONCE at the end
	for i in range(8):
		sub_quadrant_has_surfaces[q_keys[i]] = q_found[i]
func _mesh_complete():
	mesh_cooking = false

	if mesh_stale:
		mesh_stale = false
		mark_dirty()
		return
	manager.mesh_controller.apply_mesh(self)

func mark_dirty() -> void:
	var already_dirty = mesh_dirty and collision_dirty
	if already_dirty:
		return

	mesh_dirty = true
	collision_dirty = true
	is_mesh_ready = false

	# flag the result as stale
	if collision_cooking:
		collision_stale = true
	if mesh_cooking:
		mesh_stale = true

	if manager and manager.has_method("queue_dirty_chunk"):
		manager.queue_dirty_chunk(self)

func get_current_lod() -> int:
	return current_lod

func _exit_tree() -> void:
	#Clear the array to sever any data connection 
	#from a thread that is finishing up.
	pending_surface_arrays = []
	if parent_chunk and is_instance_valid(parent_chunk):
		parent_chunk.child_chunks.erase(self)
