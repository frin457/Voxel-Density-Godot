class_name VoxelChunkData
extends RefCounted

# ==================================================
# VOXEL CONTENT
# ==================================================

var voxel_ids := PackedByteArray()
var voxel_density := PackedByteArray()
var voxel_colors := PackedColorArray()

# ==================================================
# ORIGINAL SNAPSHOT
# ==================================================

var original_voxel_ids := PackedByteArray()
var original_voxel_density := PackedByteArray()
var original_voxel_colors := PackedColorArray()

# ==================================================
# DERIVED CACHE
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
