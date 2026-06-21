class_name ChunkManager
extends Node


@export var voxelScale: float = 1.0

@export var colors : Array[Color] = [
	Color.GRAY,
	Color.NAVY_BLUE,
	Color.INDIAN_RED,
	Color.BURLYWOOD,
	Color.YELLOW,
	Color.GREEN_YELLOW
]

@export var dimensions: Vector3 = Vector3(64,16,64)

@export var chunkSize: int = 32

@export var noiseSeed: int = 0

@export var workerCount: int = 4


var random := FastNoiseLite.new()

var totalChunks: Vector3


var chunk_scene = preload(
	"res://scripts/chunk/chunk.tscn"
)


var terrain_generator := TerrainGenerationController.new()
var mesh_controller := ChunkMeshController.new()
var collision_controller := CollisionController.new()


var threads: Array[Thread] = []

var completed_chunks = []

var chunks: Dictionary = {}

func _ready():

	random.seed = noiseSeed

	random.noise_type = FastNoiseLite.TYPE_SIMPLEX

	random.frequency = 0.003

	totalChunks = dimensions / chunkSize

	for i in range(workerCount):
		threads.append(Thread.new())

	start_generation()
	
func start_generation():

	var half_x = dimensions.x / 2
	var half_z = dimensions.z / 2

	threads[0].start(
		generate_region.bind(
			Vector3(0,0,0)
		)
	)

	if workerCount > 1:
		threads[1].start(
			generate_region.bind(
				Vector3(half_x,0,0)
			)
		)

	if workerCount > 2:
		threads[2].start(
			generate_region.bind(
				Vector3(0,0,half_z)
			)
		)

	if workerCount > 3:
		threads[3].start(
			generate_region.bind(
				Vector3(half_x,0,half_z)
			)
		)
func generate_region(offset: Vector3):

	var local_results = []

	for x in range(totalChunks.x):

		for z in range(totalChunks.z):

			for y in range(totalChunks.y):

				var chunk_position = (
					Vector3(x,y,z) * chunkSize
				) + offset

				var voxel_data = (
					terrain_generator.generate_data(
						chunk_position,
						chunkSize,
						dimensions.y,
						random,
						colors
					)
				)

				local_results.append({
					"position": chunk_position,
					"voxels": voxel_data
				})

	call_deferred(
		"_receive_chunks",
		local_results
	)
	
func _receive_chunks(results):
	for result in results:
		completed_chunks.append(result)

func _process(delta):
	var chunks_per_frame = 2

	for i in range(chunks_per_frame):
		if completed_chunks.is_empty():
			return
		var result = completed_chunks.pop_front()
		create_chunk(
			result.position,
			result.voxels
		)

func create_chunk(
	world_position: Vector3,
	voxel_data: Dictionary
):

	var new_chunk: Chunk = (
		chunk_scene.instantiate()
	)

	new_chunk.position = world_position

	new_chunk.voxel_size = voxelScale

	new_chunk.set_voxel_data(
		voxel_data
	)

	add_child(new_chunk)

	chunks[world_position] = new_chunk

	process_chunk(new_chunk)

func process_chunk(chunk: Chunk):
	if chunk.mesh_dirty:
		mesh_controller.rebuild(chunk)
	if chunk.collision_dirty:
		collision_controller.rebuild(chunk)
	chunk.clear_dirty()
	
func _exit_tree():
	for thread in threads:
		if thread.is_started():
			thread.wait_to_finish()
