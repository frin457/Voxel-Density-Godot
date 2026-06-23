# ./scripts/controllers/ChunkMeshController.gd
#
# Responsible only for converting voxel data into renderable geometry.

class_name ChunkMeshController extends RefCounted

enum Face {
	BOTTOM,
	FRONT,
	RIGHT,
	TOP,
	LEFT,
	BACK
}

var cube_indicies = {
	Face.FRONT : [[0,4,5],[0,5,1]],
	Face.BACK  : [[2,7,3],[2,6,7]],
	Face.LEFT  : [[3,7,4],[3,4,0]],
	Face.RIGHT : [[1,5,6],[1,6,2]],
	Face.BOTTOM: [[0,1,2],[0,2,3]],
	Face.TOP   : [[4,7,6],[4,6,5]]
}

var cube_normals = {
	Face.FRONT  : Vector3(0,0,1),
	Face.BACK   : Vector3(0,0,-1),
	Face.LEFT   : Vector3(-1,0,0),
	Face.RIGHT  : Vector3(1,0,0),
	Face.BOTTOM : Vector3(0,-1,0),
	Face.TOP    : Vector3(0,1,0)
}

func rebuild(chunk: Chunk) -> void:
	if chunk.voxels.is_empty():
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	var half_size = chunk.voxel_size * 0.5

	var cube_vertices = [
		Vector3(-half_size, -half_size,  half_size),
		Vector3( half_size, -half_size,  half_size),
		Vector3( half_size, -half_size, -half_size),
		Vector3(-half_size, -half_size, -half_size),

		Vector3(-half_size,  half_size,  half_size),
		Vector3( half_size,  half_size,  half_size),
		Vector3( half_size,  half_size, -half_size),
		Vector3(-half_size,  half_size, -half_size)
	]

	for voxel_position in chunk.voxels.keys():
		var world_position = Vector3(voxel_position) * chunk.voxel_size
		var voxel = chunk.voxels[voxel_position]

		if !has_neighbor(chunk, Face.FRONT, voxel_position):
			add_face(vertices, normals, colors, Face.FRONT, world_position, voxel.color, cube_vertices)

		if !has_neighbor(chunk, Face.BACK, voxel_position):
			add_face(vertices, normals, colors, Face.BACK, world_position, voxel.color, cube_vertices)

		if !has_neighbor(chunk, Face.LEFT, voxel_position):
			add_face(vertices, normals, colors, Face.LEFT, world_position, voxel.color, cube_vertices)

		if !has_neighbor(chunk, Face.RIGHT, voxel_position):
			add_face(vertices, normals, colors, Face.RIGHT, world_position, voxel.color, cube_vertices)

		if !has_neighbor(chunk, Face.BOTTOM, voxel_position):
			add_face(vertices, normals, colors, Face.BOTTOM, world_position, voxel.color, cube_vertices)

		if !has_neighbor(chunk, Face.TOP, voxel_position):
			add_face(vertices, normals, colors, Face.TOP, world_position, voxel.color, cube_vertices)

	# If the chunk is empty/invisible, pass a null mesh to clear it out
	if vertices.is_empty():
		_apply_mesh_to_node.call_deferred(chunk, null)
		return

	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_COLOR] = colors

	# FIX: Always generate a totally detached ArrayMesh on the thread.
	var new_mesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	new_mesh.surface_set_material(0, chunk.mat)

	# Safely defer the final Node mutation back to Godot's Main Thread
	_apply_mesh_to_node.call_deferred(chunk, new_mesh)


func _apply_mesh_to_node(chunk: Chunk, new_mesh: ArrayMesh) -> void:
	# Ensure the chunk wasn't deleted while the thread was working
	if is_instance_valid(chunk) and chunk.meshInstance:
		chunk.meshInstance.mesh = new_mesh
		
	if chunk:
		chunk.mesh_dirty = false


func has_neighbor(chunk: Chunk, face: Face, position: Vector3i) -> bool:
	var adjacent = position + Vector3i(cube_normals[face])
	return chunk.voxels.has(adjacent)


func add_face(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	face: Face,
	world_position: Vector3,
	color: Color,
	custom_vertices: Array
) -> void:

	for triangle in cube_indicies[face]:
		for index in triangle:
			vertices.append(custom_vertices[index] + world_position)
			normals.append(cube_normals[face])
			colors.append(color)
