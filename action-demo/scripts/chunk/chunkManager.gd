#./scripts/chunk/chunkManager.gd
class_name ChunkManager extends Node

@export var voxel_scale: float = 1.0
@export var chunk_size: int = 32
@export var noiseSeed: int = 0
@export var workerCount: int = 4

@export var dimensions: Vector3 = Vector3(128, 64, 128)
@export var chunk_material: Material # Added to pass down to chunks cleanly

@export var colors: Array[Color] = [
	Color.GRAY,
	Color.NAVY_BLUE,
	Color.INDIAN_RED,
	Color.BURLYWOOD,
	Color.YELLOW,
	Color.GREEN_YELLOW
]

var random := FastNoiseLite.new()
var subdivision_controller: SubdivisionController
var chunk_scene = preload("res://scripts/chunk/chunk.tscn")

# Controllers
var terrain_generator := TerrainGenerationController.new()
var mesh_controller := ChunkMeshController.new()
var collision_controller := CollisionController.new()
var query_controller: QueryController

# Job system
var job_queue := ChunkJobQueue.new()

# World state - Accepts compound keys or Vector4i equivalent strings
var chunks: Dictionary = {}
var total_chunks: Vector3i

# Helper to build an octree safe identifier key
func get_chunk_key(coord: Vector3i, lod: int) -> String:
	return "%d_%d_%d_LOD%d" % [coord.x, coord.y, coord.z, lod]

# ----------------------------
# READY
# ----------------------------
func _ready() -> void:
	query_controller = QueryController.new(self)
	subdivision_controller = SubdivisionController.new(self)

	random.seed = noiseSeed
	random.noise_type = FastNoiseLite.TYPE_SIMPLEX
	random.frequency = 0.003

	_sanitize_world_settings()
	start_world_generation()

	# --- Subdivision test ---
	#await get_tree().create_timer(2.0).timeout
	#subdivision_controller.debug_force_subdivide_center()


# ----------------------------
# WORLD SANITY + SAFETY
# ----------------------------
func _sanitize_world_settings() -> void:
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
						world_pos,
						{},
						1.0,
						0
					)
				)


# ----------------------------
# GENERATE CHUNK
# ----------------------------
func handle_generate(job: ChunkJob) -> void:
	var coord = job.chunk_coordinate
	var key = get_chunk_key(coord, job.lod_level)
	
	# CRITICAL SAFETY GUARD: If this exact chunk already exists or is actively rendering, 
	# completely discard this job to prevent infinite duplication/flickering.
	if chunks.has(key) and is_instance_valid(chunks[key]):
		return

	var world_pos = job.world_position
	var local_voxel_scale = voxel_scale / pow(2, job.lod_level)

	var voxel_data = terrain_generator.generate_data(
		world_pos,
		chunk_size,
		local_voxel_scale,
		dimensions.y,
		random,
		colors,
		job.lod_level
	)
	
	var chunk: Chunk = chunk_scene.instantiate()
	chunk.position = world_pos
	chunk.voxel_size = local_voxel_scale
	chunk.subdivision_level = job.lod_level
	chunk.mat = chunk_material

	add_child(chunk)
	chunks[key] = chunk # Save to our compound key dictionary
	
	chunk.set_voxel_data(voxel_data)

	_create_chunk_wireframe_bounds(chunk)
	process_chunk(chunk)

	_link_subdivision_hierarchy(coord, chunk)


# ----------------------------
# HIERARCHY RESOLUTION
# ----------------------------
func _link_subdivision_hierarchy(child_coord: Vector3i, child_chunk: Chunk) -> void:
	if child_chunk.subdivision_level == 0:
		return

	var parent_coord = Vector3i(
		child_coord.x >> 1,
		child_coord.y >> 1,
		child_coord.z >> 1
	)
	
	# Fetching using the correct parenting LOD step down
	var parent_key = get_chunk_key(parent_coord, child_chunk.subdivision_level - 1)
	if chunks.has(parent_key):
		var parent_chunk: Chunk = chunks[parent_key]
		child_chunk.parent_chunk = parent_chunk
		parent_chunk.child_chunks.append(child_chunk)
		
		if parent_chunk.child_chunks.size() == 8:
			parent_chunk.deactivate()


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
	# Keep wireframe box sized around the actual scaled bounds
	var world_size = chunk_size * chunk.voxel_size

	var half_voxel = chunk.voxel_size * 0.5
	var min_p = Vector3.ONE * -half_voxel
	var max_p = Vector3.ONE * (world_size - half_voxel)

	var line_vertices := PackedVector3Array()
	var append_line = func(from: Vector3, to: Vector3):
		line_vertices.append(from)
		line_vertices.append(to)

	append_line.call(Vector3(min_p.x, min_p.y, min_p.z), Vector3(max_p.x, min_p.y, min_p.z))
	append_line.call(Vector3(max_p.x, min_p.y, min_p.z), Vector3(max_p.x, min_p.y, max_p.z))
	append_line.call(Vector3(max_p.x, min_p.y, max_p.z), Vector3(min_p.x, min_p.y, max_p.z))
	append_line.call(Vector3(min_p.x, min_p.y, max_p.z), Vector3(min_p.x, min_p.y, min_p.z))
	append_line.call(Vector3(min_p.x, max_p.y, min_p.z), Vector3(max_p.x, max_p.y, min_p.z))
	append_line.call(Vector3(max_p.x, max_p.y, min_p.z), Vector3(max_p.x, max_p.y, max_p.z))
	append_line.call(Vector3(max_p.x, max_p.y, max_p.z), Vector3(min_p.x, max_p.y, max_p.z))
	append_line.call(Vector3(min_p.x, max_p.y, max_p.z), Vector3(min_p.x, max_p.y, min_p.z))
	append_line.call(Vector3(min_p.x, min_p.y, min_p.z), Vector3(min_p.x, max_p.y, min_p.z))
	append_line.call(Vector3(max_p.x, min_p.y, min_p.z), Vector3(max_p.x, max_p.y, min_p.z))
	append_line.call(Vector3(max_p.x, min_p.y, max_p.z), Vector3(max_p.x, max_p.y, max_p.z))
	append_line.call(Vector3(min_p.x, min_p.y, max_p.z), Vector3(min_p.x, max_p.y, max_p.z))

	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = line_vertices

	var imm_mesh = ArrayMesh.new()
	imm_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, surface_array)

	var debug_mat = StandardMaterial3D.new()
	debug_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	
	var debug_colors = [Color.GREEN, Color.CYAN, Color.ORANGE, Color.MAGENTA]
	debug_mat.albedo_color = debug_colors[chunk.subdivision_level % debug_colors.size()]

	var bounds_visualizer = MeshInstance3D.new()
	bounds_visualizer.mesh = imm_mesh
	bounds_visualizer.set_surface_override_material(0, debug_mat)
	
	chunk.add_child(bounds_visualizer)
	chunk.visual_bounds_mesh = bounds_visualizer
