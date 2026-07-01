#./scripts/lod/chunk/surfaces/mesh/meshSnapshot.gd
class_name MeshSnapshot extends RefCounted

var voxel_ids: PackedByteArray
var voxel_colors: PackedColorArray
var chunk_size: int
var chunk_size_sq: int
var voxel_scale: float

## Calculates the flat array index for a 3D coordinate.
## WARNING: This method carries GDScript function overhead. 
## DO NOT use inside tight processing (n^3) loops:
func get_1d_index(x: int, y: int, z: int) -> int:
	return x + (y * chunk_size) + (z * chunk_size_sq)
