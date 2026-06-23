# ./scripts/voxel/voxel.gd
class_name Voxel extends RefCounted

var color: Color
var health: float = 100.0
var density: float = 1.0
var material_type: String = "default"

func _init(voxel_color: Color):
	color = voxel_color
