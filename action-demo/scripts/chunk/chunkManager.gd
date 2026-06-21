class_name ChunkManager extends Node

@export var voxelScale: float = 1.0
@export var chunkSize: int = 32
@export var noiseSeed: int = 0
@export var workerCount: int = 4

@export var dimensions: Vector3 = Vector3(128, 64, 128)

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
var query_controller: QueryController

# Job system
var job_queue := ChunkJobQueue.new()

# World state
var chunks: Dictionary = {}

var totalChunks: Vector3i


# ----------------------------
# READY
# ----------------------------
func _ready() -> void:
	query_controller = QueryController.new(self)

	random.seed = noiseSeed
	random.noise_type = FastNoiseLite.TYPE_SIMPLEX
	random.frequency = 0.003

	_sanitize_world_settings()

	start_world_generation()


# ----------------------------
# WORLD SANITY + SAFETY
# ----------------------------
func _sanitize_world_settings() -> void:
	
	# Prevent invalid inspector overrides
	dimensions = Vector3(
		max(1.0, dimensions.x),
		max(1.0, dimensions.y),
		max(1.0, dimensions.z)
	)

	chunkSize = max(1, chunkSize)

	totalChunks = Vector3i(
		max(1, int(dimensions.x / chunkSize)),
		max(1, int(dimensions.y / chunkSize)),
		max(1, int(dimensions.z / chunkSize))
	)

# ----------------------------
# MAIN LOOP
# ----------------------------
func _process(delta: float) -> void:

	job_queue.flush()

	var jobs_per_frame := 2

	for i in range(jobs_per_frame):

		var job = job_queue.pop()
		if job == null:
			break

		execute(job)


# ----------------------------
# WORLD GENERATION
# ----------------------------
func start_world_generation() -> void:

	for x in range(totalChunks.x):
		for z in range(totalChunks.z):
			for y in range(totalChunks.y):

				var coord = Vector3i(x, y, z)
				var world_pos = Vector3(coord) * chunkSize

				job_queue.push(
					ChunkJob.new(
						ChunkJob.JobType.GENERATE,
						coord,
						world_pos
					)
				)


# ----------------------------
# DISPATCH
# ----------------------------
func execute(job: ChunkJob) -> void:

	match job.type:

		ChunkJob.JobType.GENERATE:
			handle_generate(job)


# ----------------------------
# GENERATE CHUNK
# ----------------------------
func handle_generate(job: ChunkJob) -> void:

	var coord = job.chunk_coordinate
	var world_pos = job.world_position

	var voxel_data = terrain_generator.generate_data(
		world_pos,
		chunkSize,
		dimensions.y,
		random,
		colors
	)

	var chunk: Chunk = chunk_scene.instantiate()
	chunk.position = world_pos
	chunk.voxel_size = voxelScale

	add_child(chunk)

	chunks[coord] = chunk

	chunk.set_voxel_data(voxel_data)

	process_chunk(chunk)


# ----------------------------
# PROCESS CHUNK
# ----------------------------
func process_chunk(chunk: Chunk) -> void:

	if chunk.mesh_dirty:
		mesh_controller.rebuild(chunk)

	if chunk.collision_dirty:
		collision_controller.rebuild(chunk)

	chunk.clear_dirty()
