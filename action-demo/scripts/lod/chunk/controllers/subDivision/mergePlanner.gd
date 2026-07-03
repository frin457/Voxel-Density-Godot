#./scripts/lod/chunk/controllers/subDivision/mergePlanner.gd
class_name MergePlanner extends RefCounted


func create_plan(
	parent_coordinate: Vector3i,
	parent_lod: int
) -> MergePlan:

	var plan := MergePlan.new()

	plan.parent_coordinate = parent_coordinate
	plan.parent_lod = parent_lod

	for x in range(2):
		for y in range(2):
			for z in range(2):

				var child_coord := (
					parent_coordinate * 2
					+ Vector3i(x, y, z)
				)

				var identifier := ChunkIdentifier.new()

				identifier.coordinate = child_coord
				identifier.lod_level = parent_lod + 1

				plan.child_keys.append(identifier)

	return plan
