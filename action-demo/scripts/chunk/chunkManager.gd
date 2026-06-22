#./scripts/chunk/chunkManager.gd
class_name ChunkManager extends Node

@export var voxel_scale: float = 1.0
@export var chunk_size: int = 32
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
#var subdivision_controller := SubdivisionController.new(self)
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

var total_chunks: Vector3i


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

	# TEMP TEST ONLY
	#await get_tree().create_timer(2.0).timeout
	#subdivision_controller.debug_force_subdivide_center()

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

	chunk_size = max(1, chunk_size)
	var chunk_world_size := get_chunk_world_size()
	total_chunks = Vector3i(
		max(1, ceili(dimensions.x / chunk_world_size)),
		max(1, ceili(dimensions.y / chunk_world_size)),
		max(1, ceili(dimensions.z / chunk_world_size))
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
# DISPATCH
# ----------------------------
func execute(job: ChunkJob) -> void:

	match job.type:

		ChunkJob.JobType.GENERATE:
			handle_generate(job)
			
# ----------------------------
# WORLD GENERATION
# ----------------------------
func start_world_generation() -> void:

	for x in range(total_chunks.x):
		for z in range(total_chunks.z):
			for y in range(total_chunks.y):

				var coord = Vector3i(x, y, z)
				var chunk_world_size = get_chunk_world_size()
				var world_pos = Vector3(coord) * chunk_world_size
				
				job_queue.push(
					ChunkJob.new(
						ChunkJob.JobType.GENERATE,
						coord,
						world_pos
					)
				)


# ----------------------------
# GENERATE CHUNK
# ----------------------------
func handle_generate(job: ChunkJob) -> void:
	var coord = job.chunk_coordinate
	var world_pos = job.world_position

	var voxel_data = terrain_generator.generate_data(
		world_pos,
		chunk_size,
		voxel_scale,
		dimensions.y,
		random,
		colors
	)
	


	var chunk: Chunk = chunk_scene.instantiate()
	chunk.position = world_pos
	chunk.voxel_size = voxel_scale
	chunk.subdivision_level = job.lod_level # <-- PropDrill `lod_level` into chunk params

	add_child(chunk)
	chunks[coord] = chunk
	chunk.set_voxel_data(voxel_data)

	# --- Add wireframe bounds ---
	_create_chunk_wireframe_bounds(chunk)

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


func get_chunk_world_size() -> float:
	return chunk_size * voxel_scale	
	
func _create_chunk_wireframe_bounds(chunk: Chunk) -> void:
	# Calculate size scaled down by the subdivision level
	# Level 0 = chunk_size. Level 1 = chunk_size / 2. Level 2 = chunk_size / 4.
	var world_size = (
		chunk_size
		* chunk.voxel_size
	) / pow(2, chunk.subdivision_level)

	var half_voxel = chunk.voxel_size * 0.5

	var min_p = Vector3.ONE * -half_voxel
	var max_p = Vector3.ONE * (world_size - half_voxel)

	# Create a temporary immediate mesh surface for lines
	var line_vertices := PackedVector3Array()
	var append_line = func(from: Vector3, to: Vector3):
		line_vertices.append(from)
		line_vertices.append(to)

	# Bottom face
	append_line.call(Vector3(min_p.x, min_p.y, min_p.z), Vector3(max_p.x, min_p.y, min_p.z))
	append_line.call(Vector3(max_p.x, min_p.y, min_p.z), Vector3(max_p.x, min_p.y, max_p.z))
	append_line.call(Vector3(max_p.x, min_p.y, max_p.z), Vector3(min_p.x, min_p.y, max_p.z))
	append_line.call(Vector3(min_p.x, min_p.y, max_p.z), Vector3(min_p.x, min_p.y, min_p.z))
	# Top face
	append_line.call(Vector3(min_p.x, max_p.y, min_p.z), Vector3(max_p.x, max_p.y, min_p.z))
	append_line.call(Vector3(max_p.x, max_p.y, min_p.z), Vector3(max_p.x, max_p.y, max_p.z))
	append_line.call(Vector3(max_p.x, max_p.y, max_p.z), Vector3(min_p.x, max_p.y, max_p.z))
	append_line.call(Vector3(min_p.x, max_p.y, max_p.z), Vector3(min_p.x, max_p.y, min_p.z))
	# Verticals
	append_line.call(Vector3(min_p.x, min_p.y, min_p.z), Vector3(min_p.x, max_p.y, min_p.z))
	append_line.call(Vector3(max_p.x, min_p.y, min_p.z), Vector3(max_p.x, max_p.y, min_p.z))
	append_line.call(Vector3(max_p.x, min_p.y, max_p.z), Vector3(max_p.x, max_p.y, max_p.z))
	append_line.call(Vector3(min_p.x, min_p.y, max_p.z), Vector3(min_p.x, max_p.y, max_p.z))

	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = line_vertices

	var imm_mesh = ArrayMesh.new()
	imm_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, surface_array)

	# Set up a clean debug material that overrides shading
	var debug_mat = StandardMaterial3D.new()
	debug_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	
	# Cycle colors based on subdivision level so you can visually parse splits
	var debug_colors = [Color.GREEN, Color.CYAN, Color.ORANGE, Color.MAGENTA]
	debug_mat.albedo_color = debug_colors[chunk.subdivision_level % debug_colors.size()]

	# Instantiate a clean visual child node directly inside the chunk
	var bounds_visualizer = MeshInstance3D.new()
	bounds_visualizer.mesh = imm_mesh
	bounds_visualizer.set_surface_override_material(0, debug_mat)
	
	chunk.add_child(bounds_visualizer)
	chunk.visual_bounds_mesh = bounds_visualizer
