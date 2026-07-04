#./scripts/world/worldPlanner.gd
class_name WorldPlanner extends RefCounted

func create_plan(
	dimensions: Vector3,
	chunk_world_size: float
) -> WorldGenerationPlan:

	var plan := WorldGenerationPlan.new()

	var total_chunks_x := int(
		ceil(dimensions.x / chunk_world_size)
	)

	var total_chunks_y := int(
		ceil(dimensions.y / chunk_world_size)
	)

	var total_chunks_z := int(
		ceil(dimensions.z / chunk_world_size)
	)

	for x in range(total_chunks_x):
		for z in range(total_chunks_z):
			for y in range(total_chunks_y):

				var coord := Vector3i(x, y, z)

				var world_pos := (
					Vector3(coord)
					* chunk_world_size
				)

				var job := ChunkJob.new(
					ChunkJob.JobType.GENERATE,
					coord,
					world_pos,
					null,
					1.0,
					0
				)

				plan.jobs.append(job)

	return plan
