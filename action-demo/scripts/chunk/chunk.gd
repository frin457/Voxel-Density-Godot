class_name Chunk
extends StaticBody3D

@export var mat: Material

@onready var collisionShape: CollisionShape3D = $CollisionShape3D
@onready var meshInstance: MeshInstance3D = $MeshInstance3D

var voxels: Dictionary = {}

var voxel_size: float = 1.0
var subdivision_level: int = 0

var mesh_dirty := false
var collision_dirty := false

func _ready() -> void:
	meshInstance.mesh = ArrayMesh.new()

func mark_dirty():
	mesh_dirty = true
	collision_dirty = true

func clear_dirty():
	mesh_dirty = false
	collision_dirty = false


# NEW
func set_voxel_data(data: Dictionary):
	voxels = data
	mark_dirty()
