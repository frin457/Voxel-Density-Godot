#./scripts/lod/chunk/surfaces/mesh/standardMesher.gd
class_name StandardMesher extends BaseMesher

const VERTICES = [
	Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0),
	Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)
]

enum Face { TOP, BOTTOM, LEFT, RIGHT, FRONT, BACK }

const NEIGHBOR_OFFSETS = {
	Face.TOP:    Vector3i(0, 1, 0),    Face.BOTTOM: Vector3i(0, -1, 0),
	Face.LEFT:   Vector3i(-1, 0, 0),   Face.RIGHT:  Vector3i(1, 0, 0),
	Face.FRONT:  Vector3i(0, 0, 1),    Face.BACK:   Vector3i(0, 0, -1)
}

const FACE_NORMALS = {
	Face.TOP:    Vector3(0, 1, 0),     Face.BOTTOM: Vector3(0, -1, 0),
	Face.LEFT:   Vector3(-1, 0, 0),    Face.RIGHT:  Vector3(1, 0, 0),
	Face.FRONT:  Vector3(0, 0, 1),     Face.BACK:   Vector3(0, 0, -1)
}

const FACE_VERTICES = {
	Face.TOP:    [3, 2, 6, 7], Face.BOTTOM: [4, 5, 1, 0],
	Face.LEFT:   [0, 3, 7, 4], Face.RIGHT:  [1, 5, 6, 2],
	Face.FRONT:  [4, 7, 6, 5], Face.BACK:   [1, 2, 3, 0]
}

func generate_mesh_data(chunk: Chunk) -> Array:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	
	var voxel_scale: float = chunk.voxel_size    
	var chunk_size = chunk.chunk_size
	
	for z in range(chunk_size):
		for y in range(chunk_size):
			for x in range(chunk_size):
				var voxel_index = chunk.get_1d_index(x, y, z)
				if chunk.voxel_ids[voxel_index] == 0:
					continue

				var voxel_origin = Vector3(x, y, z) * voxel_scale
				var voxel_color = chunk.voxel_colors[voxel_index]

				for face_dir in NEIGHBOR_OFFSETS:
					var offset = NEIGHBOR_OFFSETS[face_dir]
					var nx = x + offset.x
					var ny = y + offset.y
					var nz = z + offset.z

					var neighbor_solid := false
					if nx >= 0 and nx < chunk_size and ny >= 0 and ny < chunk_size and nz >= 0 and nz < chunk_size:
						var neighbor_index = chunk.get_1d_index(nx, ny, nz)
						neighbor_solid = (chunk.voxel_ids[neighbor_index] != 0)

					if neighbor_solid:
						continue

					var vertex_start_index = vertices.size()

					for i in range(4):
						var local_vertex_index = FACE_VERTICES[face_dir][i]
						var vertex_pos = voxel_origin + (VERTICES[local_vertex_index] * voxel_scale)
						vertices.append(vertex_pos)
						normals.append(FACE_NORMALS[face_dir])
						colors.append(voxel_color)

					indices.append(vertex_start_index + 0)
					indices.append(vertex_start_index + 1)
					indices.append(vertex_start_index + 2)
					indices.append(vertex_start_index + 0)
					indices.append(vertex_start_index + 2)
					indices.append(vertex_start_index + 3)

	var surface_arrays := []
	surface_arrays.resize(Mesh.ARRAY_MAX)
	if vertices.size() > 0:
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_INDEX] = indices
		surface_arrays[Mesh.ARRAY_NORMAL] = normals
		surface_arrays[Mesh.ARRAY_COLOR] = colors
		
	return surface_arrays
