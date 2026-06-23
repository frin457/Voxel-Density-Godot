class_name ChunkManager extends Node

# Global Parameters 
@export var isDev: bool = false
@export var voxel_scale: float = 1.0
@export var chunk_size: int = 32
@export var noiseSeed: int = 0
@export var workerCount: int = 4
@export var dimensions: Vector3 = Vector3(128, 64, 128)
@export var chunk_material: Material

# Global Controllers
var terrain_generator := TerrainGenerationController.new()
var mesh_controller := ChunkMeshController.new()
var collision_controller := CollisionController.new()

# Controllers initialized in _ready()
var subdivision_controller: SubdivisionController
var query_controller: QueryController

@export var colors: Array[Color] = [
	Color.GRAY,
	Color.NAVY_BLUE,
	Color.INDIAN_RED,
	Color.BURLYWOOD,
	Color.YELLOW,
	Color.GREEN_YELLOW
]

# Job / update systems
var job_queue := ChunkJobQueue.new()
var dirty_chunks: Array[Chunk] = []
@export var max_dirty_chunks_per_frame := 4

# World state - Accepts compound keys or Vector4i equivalent strings
var chunks: Dictionary = {}
var total_chunks: Vector3i

# Initial generation state synchronization tracking
var initial_generation_cooked: bool = false
var tracking_initial_gen: bool = false

# Active asynchronous thread tracking array
var active_thread_tasks: Array[int] = []

# Decoupled entry points for ANY external script
signal subdivision_requested(coord: Vector3i, target_level: int, wave_index: int)
signal merge_requested(coord: Vector3i)
signal generation_requested()
signal generation_completed()


var random := FastNoiseLite.new()
var chunk_scene = preload("res://scripts/chunk/chunk.tscn")

# Helper to build an octree safe identifier key
func get_chunk_key(coord: Vector3i, lod: int) -> String:
	return "%d_%d_%d_LOD%d" % [coord.x, coord.y, coord.z, lod]

func get_chunk_world_size() -> float:
	return float(chunk_size) * voxel_scale

# ----------------------------
# READY & LIFECYCLE
# ----------------------------
func _ready() -> void:
	# Explicitly assign controllers first
	query_controller = QueryController.new(self)
	subdivision_controller = SubdivisionController.new(self)
	
	# Connect signals directly to controller methods to bypass lambda execution delays
	subdivision_requested.connect(subdivision_controller.request_subdivision)
	merge_requested.connect(subdivision_controller.request_merge)
	generation_requested.connect(start_world_generation)


func _exit_tree() -> void:
	if isDev:
		print("Voxel Engine: Shutting down. Waiting for active background threads to finish...")
	for task_id in active_thread_tasks:
		WorkerThreadPool.wait_for_task_completion(task_id)
	if isDev:
		print("Voxel Engine: Clean asynchronous shutdown complete.")


func _on_subdivision_requested(coord: Vector3i, lod_level: int) -> void:
	subdivision_controller.request_subdivision(coord, lod_level)


## Hook: Subdivides all chunks touching a spherical radius
func _on_structural_impact_area_requested(world_position: Vector3, radius: float) -> void:
	var world_size = get_chunk_world_size()
	
	# Compute a bounding box in chunk-space coordinates
	var min_chunk_x = int(floor((world_position.x - radius) / world_size))
	var max_chunk_x = int(floor((world_position.x + radius) / world_size))
	var min_chunk_z = int(floor((world_position.z - radius) / world_size))
	var max_chunk_z = int(floor((world_position.z + radius) / world_size))
	
	# Force subdivision across the entire hit envelope
	for x in range(min_chunk_x, max_chunk_x + 1):
		for z in range(min_chunk_z, max_chunk_z + 1):
			# Target chunk origin column at base level (LOD 0)
			var target_coord = Vector3i(x, 0, z) 
			subdivision_controller.request_subdivision(target_coord, 1)


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
# MAIN PROCESSING LOOP (THREAD & DIRTY QUEUE DISPATCHER)
# ----------------------------
func _process(_delta: float) -> void:
	# Pull items from thread buffer array into active queue array safely
	job_queue.flush()

	# Spin up background worker, for available jobs, up to worker count limit
	while job_queue.queue.size() > 0 and active_thread_tasks.size() < workerCount:
		var job = job_queue.pop()
		if job == null:
			break
			
		var task_id = WorkerThreadPool.add_task(
			_async_worker_execute.bind(job), 
			true, 
			"VoxelGenTask_%s" % get_chunk_key(job.chunk_coordinate, job.lod_level)
		)
		active_thread_tasks.append(task_id)

	# Clean completed thread handles AND free their memory slots
	var i = active_thread_tasks.size() - 1
	while i >= 0:
		var task_id = active_thread_tasks[i]
		if WorkerThreadPool.is_task_completed(task_id):
			WorkerThreadPool.wait_for_task_completion(task_id)
			active_thread_tasks.remove_at(i)
		i -= 1

	# --- CONSUME DIRTY CHUNKS (FRAME BUDGETED REBUILDING) ---
	var chunks_processed_this_frame := 0
	while dirty_chunks.size() > 0 and chunks_processed_this_frame < max_dirty_chunks_per_frame:
		var chunk = dirty_chunks.pop_front() # Processes oldest dirty chunks first
		if is_instance_valid(chunk):
			process_chunk(chunk)
			chunks_processed_this_frame += 1

	# Async Guard:
	# Confirm that the initial batch has finished compiling AND all dirty meshes have baked...
	if tracking_initial_gen and not initial_generation_cooked:
		if job_queue.is_empty() and active_thread_tasks.is_empty() and dirty_chunks.is_empty():
			initial_generation_cooked = true
			tracking_initial_gen = false
			if isDev:
				print("Voxel Engine: True Async generation empty. All background meshes live!")
			generation_completed.emit()

# ----------------------------
# BACKGROUND THREAD EXECUTION BLOCK
# ----------------------------
func _async_worker_execute(job: ChunkJob) -> void:
	if job.type == ChunkJob.JobType.GENERATE:
		_bg_thread_generate_voxels(job)


func _bg_thread_generate_voxels(job: ChunkJob) -> void:
	var local_voxel_scale = voxel_scale / pow(2, job.lod_level)

	var voxel_data = terrain_generator.generate_data(
		job.world_position,
		chunk_size,
		local_voxel_scale,
		dimensions.y,
		random,
		colors,
		job.lod_level
	)
	
	job.data["voxels"] = voxel_data
	_main_thread_instantiate_chunk.call_deferred(job)


# ----------------------------
# MAIN THREAD CALLBACK (Scene-Tree Safe Node Spawning)
# ----------------------------
func _main_thread_instantiate_chunk(job: ChunkJob) -> void:
	var coord = job.chunk_coordinate
	var key = get_chunk_key(coord, job.lod_level)
	
	if chunks.has(key) and is_instance_valid(chunks[key]):
		return

	var local_voxel_scale = voxel_scale / pow(2, job.lod_level)
	var chunk: Chunk = chunk_scene.instantiate()
	chunk.position = job.world_position
	chunk.voxel_size = local_voxel_scale
	chunk.subdivision_level = job.lod_level
	chunk.chunk_coordinate = job.chunk_coordinate	
	chunk.mat = chunk_material

	add_child(chunk)
	chunks[key] = chunk
	
	# Calling set_voxel_data calls mark_dirty(), which queues it for a smooth, frame-budgeted mesh bake
	chunk.set_voxel_data(job.data["voxels"])
	
	if isDev:
		_create_chunk_wireframe_bounds(chunk)
		
	_link_subdivision_hierarchy(coord, chunk)


# ----------------------------
# BASELINE INITIALIZATION
# ----------------------------
func start_world_generation() -> void:
	if isDev:
		print("Voxel Engine: Generating initial base world map...")
	
	tracking_initial_gen = true
	initial_generation_cooked = false
	
	var chunk_world_size = get_chunk_world_size()
	var total_chunks_x = int(ceil(dimensions.x / chunk_world_size))
	var total_chunks_y = int(ceil(dimensions.y / chunk_world_size))
	var total_chunks_z = int(ceil(dimensions.z / chunk_world_size))
	
	var total_queued := 0

	for x in range(total_chunks_x):
		for z in range(total_chunks_z):
			for y in range(total_chunks_y):
				
				var coord = Vector3i(x, y, z)
				var world_pos = Vector3(coord) * chunk_world_size
				
				var job = ChunkJob.new(
					ChunkJob.JobType.GENERATE,
					coord,
					world_pos,
					{},
					1.0, 
					0   
				)
				
				job_queue.push(job)
				total_queued += 1
				
	if isDev:
		print("Voxel Engine: Initial map queued successfully! Total chunks: ", total_queued)


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
	
	var parent_key = get_chunk_key(parent_coord, child_chunk.subdivision_level - 1)
	if chunks.has(parent_key):
		var parent_chunk: Chunk = chunks[parent_key]
		child_chunk.parent_chunk = parent_chunk
		if child_chunk in parent_chunk.child_chunks:
			return
		parent_chunk.child_chunks.append(child_chunk)
		
		if parent_chunk.child_chunks.size() == 8:
			parent_chunk.deactivate()
			subdivision_controller.subdivision_complete(
				parent_coord,
				child_chunk.subdivision_level
			)

# ----------------------------
# PROCESS CHUNK MESHER (CONSUMER)
# ----------------------------
func process_chunk(chunk: Chunk) -> void:
	if chunk.mesh_dirty:
		mesh_controller.rebuild(chunk)

	if chunk.collision_dirty:
		collision_controller.rebuild(chunk)

	chunk.clear_dirty()


func queue_dirty_chunk(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		return

	if dirty_chunks.has(chunk):
		return

	dirty_chunks.append(chunk)


# ----------------------------
# CHUNK WIREFRAMES (DEBUG ONLY)
# ----------------------------
func _create_chunk_wireframe_bounds(chunk: Chunk) -> void:
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
