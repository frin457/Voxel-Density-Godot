	#./scripts/world/worldGenerationController.gd
class_name WorldGenerationController extends RefCounted

var context: EngineContext
var planner := WorldPlanner.new()


func _init(_context: EngineContext) -> void:
	context = _context

func start_world_generation() -> void:
	context.authorized_lod_levels.clear()
	var total_queued := 0
	var plans = planner.create_plan(
		context.dimensions,
		context.chunk_lod_size
	)
	
	for job in plans.jobs:

		context.authorized_lod_levels[job.chunk_coordinate] = 0

		context.job_queue.push(job)

		total_queued += 1

	if context.is_dev:
		context.diagnostics.log_message(
			"Voxel Engine: Initial map queued successfully! Total chunks: %d"
			% total_queued
	)
