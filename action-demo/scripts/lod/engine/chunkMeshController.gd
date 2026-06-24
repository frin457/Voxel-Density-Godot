#./scripts/lod/engine/chunkMeshController.gd
class_name ChunkMeshController extends RefCounted

# The 8 corners of a standard canonical unit cube
const VERTICES = [
	Vector3(0, 0, 0), # 0
	Vector3(1, 0, 0), # 1
	Vector3(1, 1, 0), # 2
	Vector3(0, 1, 0), # 3
	Vector3(0, 0, 1), # 4
	Vector3(1, 0, 1), # 5
	Vector3(1, 1, 1), # 6
	Vector3(0, 1, 1)  # 7
]

# Six directional face offsets corresponding to standard block neighbors
enum Face { TOP, BOTTOM, LEFT, RIGHT, FRONT, BACK }

const NEIGHBOR_OFFSETS = {
	Face.TOP:    Vector3i(0, 1, 0),
	Face.BOTTOM: Vector3i(0, -1, 0),
	Face.LEFT:   Vector3i(-1, 0, 0),
	Face.RIGHT:  Vector3i(1, 0, 0),
	Face.FRONT:  Vector3i(0, 0, 1),
	Face.BACK:   Vector3i(0, 0, -1)
}

const FACE_NORMALS = {
	Face.TOP:    Vector3(0, 1, 0),
	Face.BOTTOM: Vector3(0, -1, 0),
	Face.LEFT:   Vector3(-1, 0, 0),
	Face.RIGHT:  Vector3(1, 0, 0),
	Face.FRONT:  Vector3(0, 0, 1),
	Face.BACK:   Vector3(0, 0, -1)
}

# The 4 vertices required per face, wound COUNTER-CLOCKWISE looking straight at the face
const FACE_VERTICES = {
	Face.TOP:    [3, 2, 6, 7], # +Y
	Face.BOTTOM: [4, 5, 1, 0], # -Y
	Face.LEFT:   [0, 3, 7, 4], # -X
	Face.RIGHT:  [1, 5, 6, 2], # +X
	Face.FRONT:  [4, 7, 6, 5], # +Z
	Face.BACK:   [1, 2, 3, 0]  # -Z
}

## Entry point invoked by ChunkManager during the dirty chunk processing queue loop
func rebuild(chunk: Chunk) -> void:
	if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
		return
		
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

				var voxel_origin = Vector3(
					x,
					y,
					z
				) * voxel_scale

				var voxel_color = chunk.voxel_colors[voxel_index]

				for face_dir in NEIGHBOR_OFFSETS:

					var offset = NEIGHBOR_OFFSETS[face_dir]

					var nx = x + offset.x
					var ny = y + offset.y
					var nz = z + offset.z

					var neighbor_solid := false

					if (
						nx >= 0 and nx < chunk_size and
						ny >= 0 and ny < chunk_size and
						nz >= 0 and nz < chunk_size
					):
						var neighbor_index = chunk.get_1d_index(
							nx,
							ny,
							nz
						)

						neighbor_solid = (
							chunk.voxel_ids[neighbor_index] != 0
						)

					if neighbor_solid:
						continue

					var vertex_start_index = vertices.size()

					for i in range(4):
						var local_vertex_index = (
							FACE_VERTICES[face_dir][i]
						)

						var vertex_pos = (
							voxel_origin +
							(VERTICES[local_vertex_index] * voxel_scale)
						)

						vertices.append(vertex_pos)
						normals.append(FACE_NORMALS[face_dir])
						colors.append(voxel_color)

					indices.append(vertex_start_index + 0)
					indices.append(vertex_start_index + 1)
					indices.append(vertex_start_index + 2)

					indices.append(vertex_start_index + 0)
					indices.append(vertex_start_index + 2)
					indices.append(vertex_start_index + 3)

	# Package up and apply safely to the MeshInstance3D directly on main thread
	var surface_arrays := []
	surface_arrays.resize(Mesh.ARRAY_MAX)
		
	if vertices.size() > 0:
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_INDEX] = indices
		surface_arrays[Mesh.ARRAY_NORMAL] = normals
		surface_arrays[Mesh.ARRAY_COLOR] = colors
		
		var new_mesh = ArrayMesh.new()
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		chunk.meshInstance.mesh = new_mesh
		
		var trimesh_shape = new_mesh.create_trimesh_shape()
		#if chunk.collision_shape_node != null:
		chunk.collisionShape.shape = trimesh_shape
		chunk.collisionShape.disabled = false
		
		if chunk.mat:
			chunk.meshInstance.set_surface_override_material(0, chunk.mat)
	else:
		chunk.meshInstance.mesh = null
		
	# Clear out the state flag so ChunkManager doesn't continually flag it as processing required
	chunk.mesh_dirty = false
	chunk.collision_dirty = false
