#./scripts/lod/chunk/controllers/subDivision/mergePlanner.gd
class_name MergePlanner extends RefCounted


func create_plan(
	parent_coordinate: Vector3i,
	parent_lod: int
) -> Merge:

	var plan := Merge.new()

	plan.parent_coordinate = parent_coordinate
	plan.parent_lod = parent_lod

	for x in range(2):
		for y in range(2):
			for z in range(2):

				var child_coord := (
					parent_coordinate * 2
					+ Vector3i(x, y, z)
				)

				var child_key := _chunk_key(
					child_coord,
					parent_lod + 1
				)

				plan.child_keys.append(child_key)

	return plan


func _chunk_key(
	coord: Vector3i,
	lod: int
) -> String:

	return "%d_%d_%d_LOD%d" % [
		coord.x,
		coord.y,
		coord.z,
		lod
	]
