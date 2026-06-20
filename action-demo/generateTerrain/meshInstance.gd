extends MeshInstance3D

# 1. UPDATE: Removed the static cVerticies array definition from here 
# because it can't dynamically adapt to parameter changes on launch.
@export var mat : Material

@onready var collisionShape: CollisionShape3D = $StaticBody3D/CollisionShape3D

var surfaceArray : Array = []
var vertices = PackedVector3Array()
var normals = PackedVector3Array()
var colors = PackedColorArray()

enum Face{BOTTOM, FRONT, RIGHT, TOP, LEFT, BACK}
var cIndys: Dictionary[Face,Array] = {
	Face.FRONT : [[0,4,5],[0,5,1]],
	Face.BACK  : [[2,7,3],[2,6,7]],
	Face.LEFT  : [[3,7,4],[3,4,0]],
	Face.RIGHT : [[1,5,6],[1,6,2]],
	Face.BOTTOM: [[0,1,2],[0,2,3]],
	Face.TOP   : [[4,7,6],[4,6,5]]
}

var cNormals: Dictionary[Face,Vector3] = {
	Face.FRONT  : Vector3(0,0,1),
	Face.BACK   : Vector3(0,0,-1),
	Face.LEFT   : Vector3(-1,0,0),
	Face.RIGHT  : Vector3(1,0,0),
	Face.BOTTOM : Vector3(0,-1,0),
	Face.TOP    : Vector3(0,1,0)
}

var cColors: Dictionary[Face,Color] = {
	Face.FRONT  : Color.GRAY,
	Face.BACK   : Color.NAVY_BLUE,
	Face.LEFT   : Color.INDIAN_RED,
	Face.RIGHT  : Color.BURLYWOOD,
	Face.BOTTOM : Color.YELLOW,
	Face.TOP    : Color.GREEN_YELLOW
}

func _ready() -> void: 
	surfaceArray.resize(Mesh.ARRAY_MAX)

func genMesh(data : Dictionary[Vector3,Color], voxel_size: float = 1.0) -> void:
	# Half-dimension calculation for building the cube centered around its origin
	var voxelDimensions = voxel_size * 0.5
	
	# Generate the local cube vertices dynamically based on the requested size
	var dynamic_vertices: Array[Vector3] = [
		Vector3(-voxelDimensions, -voxelDimensions, voxelDimensions ),
		Vector3(voxelDimensions , -voxelDimensions, voxelDimensions ),
		Vector3(voxelDimensions , -voxelDimensions, -voxelDimensions),
		Vector3(-voxelDimensions, -voxelDimensions, -voxelDimensions),
		Vector3(-voxelDimensions, voxelDimensions , voxelDimensions ),
		Vector3(voxelDimensions , voxelDimensions , voxelDimensions ),
		Vector3(voxelDimensions , voxelDimensions , -voxelDimensions),
		Vector3(-voxelDimensions, voxelDimensions , -voxelDimensions)
	]

	for position in data:
		# 3. UPDATE: Scale the integer grid coordinates to actual 3D world space positions
		var world_position = position * voxel_size
		var color = data[position]
		
		# Neighbor checks stay on integer coordinates (position)
		if not hasNeighbour(data, Face.FRONT, position):
			addFace(Face.FRONT, world_position, cColors[Face.FRONT], dynamic_vertices)
		if not hasNeighbour(data, Face.BACK, position):
			addFace(Face.BACK, world_position, cColors[Face.BACK], dynamic_vertices)
		if not hasNeighbour(data, Face.LEFT, position):
			addFace(Face.LEFT, world_position, cColors[Face.LEFT], dynamic_vertices)
		if not hasNeighbour(data, Face.RIGHT, position):
			addFace(Face.RIGHT, world_position, cColors[Face.RIGHT], dynamic_vertices)
		if not hasNeighbour(data, Face.BOTTOM, position):
			addFace(Face.BOTTOM, world_position, cColors[Face.BOTTOM], dynamic_vertices)
		if not hasNeighbour(data, Face.TOP, position):
			addFace(Face.TOP, world_position, cColors[Face.TOP], dynamic_vertices)
	
	commitMesh()
	
func hasNeighbour(data: Dictionary[Vector3,Color], face:Face, position:Vector3) -> bool:
	var adjacent = position + cNormals[face]
	if data.has(adjacent): return true
	return false
	
# 4. UPDATE: Pass the dynamically sized vertices into the face assembly loop
func addFace(face:Face, world_position: Vector3, color : Color, custom_vertices: Array[Vector3]):
	var indicies = cIndys[face]
	for triangle in indicies:
		for index in triangle:
			# Offset the dynamically scaled vertex by our scaled world position
			vertices.append(custom_vertices[index] + world_position)
			normals.append(cNormals[face])
			colors.append(color)
	
func commitMesh() -> void: 
	surfaceArray[Mesh.ARRAY_VERTEX] = vertices
	surfaceArray[Mesh.ARRAY_NORMAL] = normals
	surfaceArray[Mesh.ARRAY_COLOR] = colors
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaceArray)
	mesh.surface_set_material(0, mat)
	collisionShape.shape = mesh.create_trimesh_shape()
