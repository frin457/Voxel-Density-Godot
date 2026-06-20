class_name Chunk extends StaticBody3D

@export var mat : Material
@onready var collisionShape: CollisionShape3D = $CollisionShape3D
@onready var meshInstance : MeshInstance3D = $MeshInstance3D

var voxels: Dictionary[Vector3, Color] = {}
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
	Face.TOP    : Color(171,0,102,255)
}

func _ready() -> void: 
	surfaceArray.resize(Mesh.ARRAY_MAX)
	meshInstance.mesh = ArrayMesh.new()
	if voxels.is_empty(): return
	commitMesh()

func genData(chunkSize: int, maxHeight:int, noise: Noise, colorArr: Array[Color]) -> void:
	for x in range(chunkSize):
		for z in range(chunkSize):
			#TODO: Provide an algo as an input
			var globalPos = Vector2(x + position.x, z + position.z)
			var rand = ((noise.get_noise_2d(globalPos.x,globalPos.y) + 0.5 * noise.get_noise_2d(globalPos.x * 2, globalPos.y * 2) + 0.25 * noise.get_noise_2d(4 * globalPos.x,4 * globalPos.y)
			) / 1.75 + 1
			) / 2
			var randP = pow(rand,2.1)
			var height = maxHeight * randP
			
			if height < position.y: continue
			
			var localHeight = height - position.y
			for y in range(min(localHeight,chunkSize)):
				voxels[Vector3(x,y,z)] = colorArr[ y % colorArr.size()]
			
			
func genMesh(voxel_size: float = 1.0) -> void:
	if voxels.is_empty(): return
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
	
	for position in voxels:
		# Scale the integer grid coordinates to actual 3D world space positions
		var world_position = position * voxel_size
		
		
		# Neighbor checks stay on integer coordinates (position)
		if not hasNeighbour(voxels, Face.FRONT, position):
			addFace(Face.FRONT, world_position, cColors[Face.FRONT], dynamic_vertices)
		if not hasNeighbour(voxels, Face.BACK, position):
			addFace(Face.BACK, world_position, cColors[Face.BACK], dynamic_vertices)
		if not hasNeighbour(voxels, Face.LEFT, position):
			addFace(Face.LEFT, world_position, cColors[Face.LEFT], dynamic_vertices)
		if not hasNeighbour(voxels, Face.RIGHT, position):
			addFace(Face.RIGHT, world_position, cColors[Face.RIGHT], dynamic_vertices)
		if not hasNeighbour(voxels, Face.BOTTOM, position):
			addFace(Face.BOTTOM, world_position, cColors[Face.BOTTOM], dynamic_vertices)
		if not hasNeighbour(voxels, Face.TOP, position):
			addFace(Face.TOP, world_position, cColors[Face.TOP], dynamic_vertices)
	
func hasNeighbour(data: Dictionary[Vector3,Color], face:Face, position:Vector3) -> bool:
	var adjacent = position + cNormals[face]
	if data.has(adjacent): return true
	return false
	
#Pass the dynamically sized vertices into the face assembly loop
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
	
	if surfaceArray.is_empty(): return
	meshInstance.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaceArray)
	meshInstance.mesh.surface_set_material(0, mat)
	collisionShape.shape = meshInstance.mesh.create_trimesh_shape()
