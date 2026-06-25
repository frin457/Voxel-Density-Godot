#./scripts/lod/chunk/surfaces/mesh/baseMesher.gd
class_name BaseMesher extends RefCounted

## Analyzes voxel data and returns an array compatible with ArrayMesh.add_surface_from_arrays()
func generate_mesh_data(chunk: Chunk) -> Array:
	push_error("generate_mesh_data() not implemented in base class.")
	return []
