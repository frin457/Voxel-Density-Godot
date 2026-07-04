#./scripts/lod/chunk/jobs/threadManager.gd
class_name ThreadManager extends RefCounted

var context : EngineContext

func _init(_context: EngineContext) -> void:
	context = _context


func process() -> void:

	context.job_queue.flush()

	_dispatch_jobs()

	_collect_finished_jobs()


func _dispatch_jobs() -> void:

	while (
		context.job_queue.queue.size() > 0
		and context.active_thread_tasks.size() < context.worker_count
	):

		var job := context.job_queue.pop()

		if job == null:
			break

		var task := WorkerThreadPool.add_task(
			context.worker_callback.bind(job),
			true,
			"Voxel_%s" % context.registry.get_key(
				job.chunk_coordinate,
				job.lod_level
			)
		)

		context.active_thread_tasks.append(task)


func _collect_finished_jobs() -> void:

	for i in range(context.active_thread_tasks.size() - 1, -1, -1):

		var task = context.active_thread_tasks[i]

		if WorkerThreadPool.is_task_completed(task):
			context.active_thread_tasks.remove_at(i)
