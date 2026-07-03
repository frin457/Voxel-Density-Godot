#./scripts/lod/chunk/controllers/subDivision/subdivision.gd
class_name Subdivision extends RefCounted

var parent_coordinate: Vector3i
var parent_lod: int

var children: Array[SubdivisionChildInfo] = []

func is_empty() -> bool:
	return children.is_empty()


func child_count() -> int:
	return children.size()
