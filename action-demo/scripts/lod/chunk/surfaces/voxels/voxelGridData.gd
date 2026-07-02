#./scripts/lod/chunk/surfaces/voxels/voxelGridData.gd
class_name VoxelGridInfo extends RefCounted

# World placement
var chunk_coordinate: Vector3i
var world_position: Vector3

# Grid dimensions
var chunk_size: int
var chunk_size_sq: int
var voxel_size: float

# Generation settings
var max_world_height: float

func get_index(x: int, y: int, z: int) -> int:
	return (
		x +
		y * chunk_size +
		z * chunk_size_sq
	)
