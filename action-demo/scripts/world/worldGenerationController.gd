	#./scripts/world/worldGenerationController.gd
class_name WorldGenerationController extends RefCounted

var context: EngineContext
var planner := WorldPlanner


func _init(_context: EngineContext) -> void:
	context = _context
	planner = WorldPlanner.new(context)

func start_world_generation() -> void:

	context.initial_generation_cooked = false
	context.authorized_lod_levels.clear()

	var total_queued := 0

	var plan := planner.create_plan(
		context.dimensions,
		context.chunk_lod_size
	)

	for job in plan.jobs:

		context.authorized_lod_levels[job.chunk_coordinate] = 0

		context.job_queue.push(job)

		total_queued += 1

	if context.is_dev:
		context.diagnostics.log_message(
			"Voxel Engine: Initial map queued successfully! Total chunks: %d"
			% total_queued
	)
