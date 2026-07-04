class_name ChunkInstantiationController
extends RefCounted

var context: EngineContext


func _init(_context: EngineContext) -> void:
	context = _context


func instantiate(job: ChunkJob) -> void:

	if not _validate_job(job):
		return

	var chunk := _create_chunk()
	_initialize_chunk(chunk, job)
	_initialize_chunk_state(chunk)
	context.registry.register_chunk(chunk)

	context.voxel_data_controller.set_voxel_data(
		chunk.voxel_data,
		job.data
	)

	context.hierarchy.attach_to_parent(chunk)


func _validate_job(job: ChunkJob) -> bool:
	var base_coord := job.chunk_coordinate
	
	if job.lod_level > 0:
		var factor := int(pow(2, job.lod_level))
		base_coord = Vector3i(
			job.chunk_coordinate.x / factor,
			job.chunk_coordinate.y / factor,
			job.chunk_coordinate.z / factor
		)

	var authorized : int = context.authorized_lod_levels.get(
		base_coord,
		0
	)

	if job.lod_level > authorized:
		if context.is_dev:
			context.diagnostics.log_stale_thread(
				job.chunk_coordinate,
				job.lod_level,
				authorized
			)
		context.registry.remove_chunk(
			job.chunk_coordinate,
			job.lod_level
		)
		return false

	return true


func _create_chunk() -> Chunk:
	return context.pool.acquire()	


func _initialize_chunk(
	chunk: Chunk,
	job: ChunkJob
) -> void:

	chunk.manager = context.manager

	chunk.position = job.world_position

	chunk.voxel_size = (
		context.voxel_scale
		/ pow(2.0, job.lod_level)
	)

	chunk.chunk_coordinate = job.chunk_coordinate

	chunk.chunk_size = context.chunk_size

	chunk.lod_level = job.lod_level
	chunk.current_lod = job.lod_level

	chunk.mat = context.chunk_material


func _initialize_chunk_state(chunk: Chunk) -> void:
	if chunk.lod_level > 0:
		chunk.deactivate()
