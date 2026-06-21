# ChunkManager.gd
class_name ChunkManager
extends Node

@export var voxelScale: float = 1.0

@export var colors: Array[Color] = [
	Color.GRAY,
	Color.NAVY_BLUE,
	Color.INDIAN_RED,
	Color.BURLYWOOD,
	Color.YELLOW,
	Color.GREEN_YELLOW
]

@export var dimensions: Vector3 = Vector3(128, 64, 128)
@export var chunkSize: int = 32
@export var noiseSeed: int = 0
@export var workerCount: int = 4

var random := FastNoiseLite.new()
var totalChunks: Vector3i

var chunk_scene = preload("res://scripts/chunk/chunk.tscn")

var terrain_generator := TerrainGenerationController.new()
var mesh_controller := ChunkMeshController.new()
var collision_controller := CollisionController.new()

var threads: Array[Thread] = []

var generation_queue: Array[Dictionary] = []
var completed_chunks: Array

var chunks: Dictionary = {}


# ----------------------------
# Lifecycle
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

	threads.clear()

	for i in range(workerCount):
		threads.append(Thread.new())

	var regions = getThreadRegions(workerCount)

	startGen(regions)


# ----------------------------
# Region Partitioning
# ----------------------------

func getThreadRegions(worker_count: int) -> Array:

	var regions = []

	var grid_x = int(ceil(sqrt(worker_count)))
	var grid_z = int(ceil(worker_count / float(grid_x)))

	var chunks_x_per_region = int(totalChunks.x / grid_x)
	var chunks_z_per_region = int(totalChunks.z / grid_z)

	var index = 0

	for gz in range(grid_z):
		for gx in range(grid_x):

			if index >= worker_count:
				break

			var region = {
				"x_min": gx * chunks_x_per_region,
				"x_max": min((gx + 1) * chunks_x_per_region, totalChunks.x),
				"z_min": gz * chunks_z_per_region,
				"z_max": min((gz + 1) * chunks_z_per_region, totalChunks.z)
			}

			regions.append(region)
			index += 1

	return regions


# ----------------------------
# Thread Startup
# ----------------------------

func startGen(regions: Array) -> void:

	for i in range(regions.size()):
		threads[i].start(genRegion.bind(regions[i]))


# ----------------------------
# Thread Worker
# ----------------------------

func genRegion(region: Dictionary) -> void:

	var local_results: Array = []

	for x in range(region["x_min"], region["x_max"]):
		for z in range(region["z_min"], region["z_max"]):
			for y in range(totalChunks.y):

				var chunk_coord = Vector3i(x, y, z)
				var world_pos = Vector3(chunk_coord) * chunkSize

				var voxel_data = terrain_generator.generate_data(
					world_pos,
					chunkSize,
					dimensions.y,
					random,
					colors
				)

				local_results.append({
					"coord": chunk_coord,
					"position": world_pos,
					"voxels": voxel_data
				})

	call_deferred("_receive_chunks", local_results)


# ----------------------------
# Thread -> Main Thread handoff
# ----------------------------

func _receive_chunks(results: Array) -> void:

	for r in results:
		completed_chunks.append(r)


# ----------------------------
# Main Thread Processing
# ----------------------------

func _process(delta: float) -> void:

	var chunks_per_frame = 2

	for i in range(chunks_per_frame):

		if completed_chunks.is_empty():
			return

		var result = completed_chunks.pop_front()

		createChunk(
			result.coord,
			result.position,
			result.voxels
		)

	# optional: incremental mesh updates (future-safe)
	_process_dirty_chunks()


# ----------------------------
# Chunk Creation
# ----------------------------

func createChunk(
	chunk_coord: Vector3i,
	world_position: Vector3,
	voxel_data: Dictionary
) -> void:

	var new_chunk: Chunk = chunk_scene.instantiate()

	new_chunk.position = world_position
	new_chunk.voxel_size = voxelScale

	add_child(new_chunk)

	chunks[chunk_coord] = new_chunk

	new_chunk.set_voxel_data(voxel_data)

	processChunk(new_chunk)


# ----------------------------
# Chunk Processing Pipeline
# ----------------------------

func processChunk(chunk: Chunk) -> void:

	if chunk.mesh_dirty:
		mesh_controller.rebuild(chunk)

	if chunk.collision_dirty:
		collision_controller.rebuild(chunk)

	chunk.clear_dirty()


# ----------------------------
# Optional incremental pipeline hook
# ----------------------------

func _process_dirty_chunks() -> void:
	# Future: unify generation + destruction + LOD here
	pass


# ----------------------------
# Cleanup
# ----------------------------

func _exit_tree() -> void:

	for t in threads:
		if t.is_started():
			t.wait_to_finish()
