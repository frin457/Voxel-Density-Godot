class_name ChunkManager extends Node

@export var voxelScale: float = 1.0
@export var chunkSize: int = 32
@export var noiseSeed: int = 0
@export var workerCount: int = 4

@export var dimensions: Vector3 = Vector3(128, 64, 128)
@export var player: Node3D
@export var generation_radius: float = 200.0
@export var max_lod_distance: float = 400.0

@export var colors: Array[Color] = [
	Color.GRAY,
	Color.NAVY_BLUE,
	Color.INDIAN_RED,
	Color.BURLYWOOD,
	Color.YELLOW,
	Color.GREEN_YELLOW
]

var random := FastNoiseLite.new()

var chunk_scene = preload("res://scripts/chunk/chunk.tscn")

# Controllers
var terrain_generator := TerrainGenerationController.new()
var mesh_controller := ChunkMeshController.new()
var collision_controller := CollisionController.new()

# JOB SYSTEM
var job_queue := ChunkJobQueue.new()

# world state
var chunks: Dictionary = {}

var totalChunks: Vector3i


# ----------------------------
# READY
# ----------------------------
func _ready() -> void:

	random.seed = noiseSeed
	random.noise_type = FastNoiseLite.TYPE_SIMPLEX
	random.frequency = 0.003

	totalChunks = Vector3i(
		int(dimensions.x / chunkSize),
		int(dimensions.y / chunkSize),
		int(dimensions.z / chunkSize)
	)

	start_world_generation()


# ----------------------------
# WORLD BOOTSTRAP
# ----------------------------
func start_world_generation() -> void:

	for x in range(totalChunks.x):
		for z in range(totalChunks.z):
			for y in range(totalChunks.y):

				var coord = Vector3i(x, y, z)
				var world_pos = Vector3(coord) * chunkSize

				var dist = 0.0
				if player != null:
					dist = player.global_position.distance_to(world_pos)

				# 🔥 PRIORITY SYSTEM
				var priority = 1.0 / max(dist, 1.0)

				# 🔥 LOD SYSTEM (distance-based)
				var lod = 0
				if dist > max_lod_distance * 0.75:
					lod = 2
				elif dist > generation_radius:
					lod = 1

				job_queue.push(
					ChunkJob.new(
						ChunkJob.JobType.GENERATE,
						coord,
						world_pos,
						{},
						priority,
						lod
					)
				)


# ----------------------------
# MAIN LOOP
# ----------------------------
func _process(delta: float) -> void:

	# 1. move thread-safe jobs into main queue
	job_queue.flush()

	var jobs_per_frame = 2

	for i in range(jobs_per_frame):

		var job = job_queue.pop()
		if job == null:
			return

		execute(job)


# ----------------------------
# JOB EXECUTION DISPATCHER
# ----------------------------
func execute(job: ChunkJob) -> void:

	match job.type:

		ChunkJob.JobType.GENERATE:
			handle_generate(job)

		ChunkJob.JobType.MESH:
			handle_mesh(job)

		ChunkJob.JobType.COLLISION:
			handle_collision(job)


# ----------------------------
# GENERATE CHUNK
# ----------------------------
func handle_generate(job: ChunkJob) -> void:

	var coord = job.chunk_coord
	var world_pos = job.world_position

	var chunk_size_modifier = chunkSize

	# 🔥 LOD REDUCTION (key voxel behavior)
	if job.lod_level == 1:
		chunk_size_modifier = chunkSize / 2
	elif job.lod_level == 2:
		chunk_size_modifier = chunkSize / 4

	var voxel_data = terrain_generator.generate_data(
		world_pos,
		chunk_size_modifier,
		dimensions.y,
		random,
		colors
	)

	var chunk: Chunk = chunk_scene.instantiate()

	chunk.position = world_pos
	chunk.voxel_size = voxelScale * (job.lod_level + 1)

	add_child(chunk)

	chunks[coord] = chunk

	chunk.set_voxel_data(voxel_data)

	# chain next jobs (still priority-aware)
	job_queue.push(
		ChunkJob.new(
			ChunkJob.JobType.MESH,
			coord,
			world_pos,
			{},
			job.priority,
			job.lod_level
		)
	)

	job_queue.push(
		ChunkJob.new(
			ChunkJob.JobType.COLLISION,
			coord,
			world_pos,
			{},
			job.priority,
			job.lod_level
		)
	)


# ----------------------------
# MESH JOB
# ----------------------------
func handle_mesh(job: ChunkJob) -> void:

	var chunk = chunks.get(job.chunkCoordinate)
	if chunk == null:
		return

	if chunk.mesh_dirty:
		mesh_controller.rebuild(chunk)

	chunk.clear_dirty()


# ----------------------------
# COLLISION JOB
# ----------------------------
func handle_collision(job: ChunkJob) -> void:

	var chunk = chunks.get(job.chunkCoordinate)
	if chunk == null:
		return

	if chunk.collision_dirty:
		collision_controller.rebuild(chunk)

	chunk.clear_dirty()
