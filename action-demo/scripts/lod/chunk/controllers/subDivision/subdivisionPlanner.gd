#./scripts/lod/chunk/controllers/subDivision/subdivisionPlanner.gd
class_name SubdivisionPlanner extends RefCounted


func create_plan(
	parent_coordinate: Vector3i,
	parent_world_position: Vector3,
	target_lod: int,
	grid: VoxelGridInfo
) -> SubdivisionPlan:

	var plan := SubdivisionPlan.new()

	plan.parent_coordinate = parent_coordinate
	plan.parent_lod = target_lod - 1

	var child_world_size := (
		(grid.chunk_size * grid.voxel_size)
		/ pow(2.0, target_lod)
	)

	for x in range(2):
		for y in range(2):
			for z in range(2):

				var child := SubdivisionChildInfo.new()

				child.coordinate = (
					parent_coordinate * 2
					+ Vector3i(x, y, z)
				)

				child.world_position = (
					parent_world_position
					+ Vector3(x, y, z) * child_world_size
				)

				child.lod_level = target_lod

				plan.children.append(child)

	return plan
