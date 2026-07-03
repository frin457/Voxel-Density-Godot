#./scripts/lod/chunk/controllers/subDivision/merge.gd
class_name Merge extends RefCounted

var parent_coordinate: Vector3i
var parent_lod: int

var child_keys: Array[ChunkIdentifier] = []

func is_empty() -> bool:
	return child_keys.is_empty()


func child_count() -> int:
	return child_keys.size()
