extends MeshInstance3D

#cubeDimension
@export var cDim : float = 0.5
@export var mat : Material
var surfaceArray : Array = []
var vertices = PackedVector3Array()
var normals = PackedVector3Array()
var colors = PackedColorArray()

var cubeVerticies : Array[Vector3] = [
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
	genMesh()
	
func genMesh() -> void:
	addFace(Face.FRONT, Vector3.ZERO)
	addFace(Face.BACK, Vector3.ZERO)
	addFace(Face.LEFT, Vector3.ZERO)
	addFace(Face.RIGHT, Vector3.ZERO)
	addFace(Face.BOTTOM, Vector3.ZERO)
	addFace(Face.TOP, Vector3.ZERO)
	
	commitMesh()
	
func addFace(face:Face, postion: Vector3):
	var indicies = cIndys[face]
	for triangle in indicies:
		for index in triangle:
			vertices.append(cubeVerticies[index] + postion)
			normals.append(cNormals[face])
			colors.append(cColors[face])
	
	
func commitMesh() -> void: 
	surfaceArray[Mesh.ARRAY_VERTEX] = vertices
	surfaceArray[Mesh.ARRAY_NORMAL] = normals
	surfaceArray[Mesh.ARRAY_COLOR] = colors
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaceArray)
	mesh.surface_set_material(0,mat)
