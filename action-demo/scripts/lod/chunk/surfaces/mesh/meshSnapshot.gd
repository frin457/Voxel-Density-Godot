class_name MeshSnapshot
extends RefCounted

var voxel_ids
var voxel_colors
var chunk_size
var chunk_size_sq
var voxel_scale

var snapshot := MeshSnapshot

func get_1d_index(x: int, y: int, z: int) -> int:
	return (
		x +
		(y * chunk_size) +
		(z * chunk_size_sq)
	)
