extends MeshInstance3D

#cubeDimension
@export var cDim : float = 0.5
@export var mat : Material

@onready var collisionShape: CollisionShape3D = $StaticBody3D/CollisionShape3D

var surfaceArray : Array = []
var vertices = PackedVector3Array()
var normals = PackedVector3Array()
var colors = PackedColorArray()

var cVerticies : Array[Vector3] = [
	Vector3(-cDim, -cDim, cDim ),
	Vector3(cDim , -cDim, cDim ),
	Vector3(cDim , -cDim, -cDim),
	Vector3(-cDim, -cDim, -cDim),
	Vector3(-cDim, cDim , cDim ),
	Vector3(cDim , cDim , cDim ),
	Vector3(cDim , cDim , -cDim),
	Vector3(-cDim, cDim , -cDim)
]

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
	surfaceArray	.resize(Mesh.ARRAY_MAX)

	
func genMesh(data : Dictionary[Vector3,Color]) -> void:
	for position in data:
		var color = data[position]
	#TODO: Cleanup, not using nested ifs
		if not hasNeighbour(data,Face.FRONT,position):
			addFace(Face.FRONT, position, color)
		if not hasNeighbour(data,Face.BACK,position):
			addFace(Face.BACK, position, color)
		if not hasNeighbour(data,Face.LEFT,position):
			addFace(Face.LEFT, position, color)
		if not hasNeighbour(data,Face.RIGHT,position):
			addFace(Face.RIGHT, position, color)
		if not hasNeighbour(data,Face.BOTTOM,position):
			addFace(Face.BOTTOM, position, color)
		if not hasNeighbour(data,Face.TOP,position):
			addFace(Face.TOP, position, color)
	
	commitMesh()
	
func hasNeighbour(data: Dictionary[Vector3,Color], face:Face, position:Vector3) -> bool:
	var adjacent = position + cNormals[face]
	if data.has(adjacent): return true
	return false;
	
	
func addFace(face:Face, position: Vector3, color : Color):
	var indicies = cIndys[face]
	for triangle in indicies:
		for index in triangle:
			vertices.append(cVerticies[index] + position)
			normals.append(cNormals[face])
			colors.append(color)
	
	
func commitMesh() -> void: 
	surfaceArray[Mesh.ARRAY_VERTEX] = vertices
	surfaceArray[Mesh.ARRAY_NORMAL] = normals
	surfaceArray[Mesh.ARRAY_COLOR] = colors
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaceArray)
	mesh.surface_set_material(0,mat)
	collisionShape.shape = mesh.create_trimesh_shape()
