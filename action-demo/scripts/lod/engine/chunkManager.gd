#./scripts/lod/chunk/chunkManager.gd
class_name ChunkManager extends Node

# Global Parameters 
@export var isDev: bool = false
@export var workerCount: int = 4
@export var dimensions: Vector3 = Vector3(128, 64, 128)
@export var voxel_scale: float = 1.0
@export var chunk_material: Material
@export var chunk_size: int = 16
var         chunk_lod_size: float  = float(chunk_size) * voxel_scale
var         inactive_chunks: Array[Chunk] = []

# World Building Controllers
var terrain_generator := TerrainGenerationController.new()
var mesh_controller := ChunkMeshController.new()
var voxel_data_controller := VoxelDataController.new()

# LOD Engine Controllers
var collision_controller := CollisionController.new()
var subdivision_controller:= SubdivisionController.new(self)
var diagnostics := DiagnosticsController.new(self)

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
var dirty_queue: Array[Chunk] = []
var collision_queue: Array[Chunk] = []

@export var max_dirty_queue_per_frame := 8
const MAX_COLLISIONS_PER_FRAME := 2

# World state - Accepts compound keys or Vector4i equivalent strings
var chunks: Dictionary = {}
var total_chunks: Vector3i

# Tracks the maximum allowed LOD level for any base chunk column to prevent stale threads from spawning orphaned nodes
var authorized_lod_levels: Dictionary = {}

# Initial generation state synchronization tracking
var initial_generation_cooked: bool = false

# Active asynchronous thread tracking array
var active_thread_tasks: Array[int] = []

# Entry points for ANY external script 
# TODO: Review these signals pattern    
signal subdivision_requested(coord: Vector3i, target_level: int, wave_index: int)
signal merge_requested(coord: Vector3i)
signal generation_requested()
signal generation_completed()
signal chunk_mesh_finished(coord: Vector3i)

var dirty_queue_processed_this_frame := 0
var random := FastNoiseLite.new()
var chunk_scene = preload("res://scripts/lod/chunk/chunk.tscn")

# Helper to build an octree safe identifier key
func get_chunk_key(coord: Vector3i, lod: int) -> String:
	return "%d_%d_%d_LOD%d" % [coord.x, coord.y, coord.z, lod]


# Helper methods to manage authorized structural LOD levels
func set_authorized_lod(base_coord: Vector3i, max_lod: int) -> void:
	authorized_lod_levels[base_coord] = max_lod

func get_authorized_lod(base_coord: Vector3i) -> int:
	return authorized_lod_levels.get(base_coord, 0)

# ----------------------------
# READY & LIFECYCLE
# ----------------------------
	subdivision_requested.connect(subdivision_controller.request_subdivision)
	merge_requested.connect(subdivision_controller.request_merge)
	generation_requested.connect(start_world_generation)

	# Automatically begin generation.
	generation_requested.emit.call_deferred()


func _on_subdivision_requested(coord: Vector3i, lod_level: int) -> void:
	subdivision_controller.request_subdivision(coord, lod_level)


## Hook: Subdivides all chunks touching a spherical radius
func _on_structural_impact_area_requested(world_position: Vector3, radius: float) -> void:
	
	# Compute a bounding box in chunk-space coordinates
	var min_chunk_x = int(floor((world_position.x - radius) / chunk_lod_size))
	var max_chunk_x = int(floor((world_position.x + radius) / chunk_lod_size))
	var min_chunk_z = int(floor((world_position.z - radius) / chunk_lod_size))
	var max_chunk_z = int(floor((world_position.z + radius) / chunk_lod_size))
	
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
	total_chunks = Vector3i(
		max(1, ceili(dimensions.x / chunk_lod_size)),
		max(1, ceili(dimensions.y / chunk_lod_size)),
		max(1, ceili(dimensions.z / chunk_lod_size))
	)

func _process(_delta: float) -> void:
	
	if isDev and Engine.get_frames_drawn() % 120 == 0:
		diagnostics.print_formatted_snapshot()
	job_queue.flush()

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

	var i = active_thread_tasks.size() - 1
	while i >= 0:
		var task_id = active_thread_tasks[i]
		if WorkerThreadPool.is_task_completed(task_id):
			active_thread_tasks.remove_at(i)
		i -= 1

	# --- CONSUME DIRTY CHUNKS ---
	if isDev and Engine.get_frames_drawn() % 120 == 0:
		diagnostics.print_formatted_snapshot()
		
	var frame_start_time := Time.get_ticks_usec()
	var max_allowed_budget_usec := 2500
	
	dirty_queue_processed_this_frame = 0
	
	if dirty_queue.size() > 128 and isDev:
		push_warning("Voxel Engine Warning: Dirty queue backlog exceeds threshold! Count: ", dirty_queue.size())
	if collision_queue.size() > 128 and isDev:
		push_warning("Voxel Engine Warning: Collision queue backlog exceeds threshold! Count: ", collision_queue.size())

	# SAFE WORKER CHECK: Verify budget BEFORE extracting items from our queue
	while dirty_queue.size() > 0:
		if Time.get_ticks_usec() - frame_start_time >= max_allowed_budget_usec:
			break # Exit smoothly; item remains safe at front of queue for next frame
			
		var chunk = dirty_queue.pop_front()
		if is_instance_valid(chunk) and not chunk.is_queued_for_deletion():
			process_chunk(chunk)

	# --- CONSUME COLLISION QUEUE ---
	var processed_collisions = 0
	
	while processed_collisions < MAX_COLLISIONS_PER_FRAME and not collision_queue.is_empty():
		if Time.get_ticks_usec() - frame_start_time >= max_allowed_budget_usec:
			break

		var chunk = collision_queue.pop_front()

		if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
			continue

		chunk.collision_queued = false # Unflag

		# Only dispatch if it still requires rebuilding
		if chunk.collision_dirty:
			collision_controller.rebuild(chunk)
			
		processed_collisions += 1
			
	if not initial_generation_cooked:
		if job_queue.is_empty() and active_thread_tasks.is_empty() and dirty_queue.is_empty() and collision_queue.is_empty():
			initial_generation_cooked = true
		if isDev:
			if isDev:
				diagnostics.log_message("Voxel Engine: True Async generation empty. All background meshes live!")
		generation_completed.emit()


func process_chunk(chunk: Chunk) -> void:
	# Safe short-circuit validation check
	if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
		return
	dirty_queue_processed_this_frame += 1
	# Run the meshing controller pass
	if chunk.mesh_dirty:
		mesh_controller.rebuild(chunk)
		chunk_mesh_finished.emit(chunk.chunk_coordinate)

func _main_thread_instantiate_chunk(job: ChunkJob) -> void:
	var coord = job.chunk_coordinate
	
	# DYNAMIC AUTHORIZATION DEPTH CHECK
	var base_coord = coord
	if job.lod_level > 0:
		# Calculate the exact LOD 0 root coordinate column
		var factor = int(pow(2, job.lod_level))
		base_coord = Vector3i(
			int(floor(float(coord.x) / factor)),
			int(floor(float(coord.y) / factor)),
			int(floor(float(coord.z) / factor))
		)
		
	# FETCH CURRENT LIVE AUTHORIZATION LEVEL
	var current_authorized_lod = authorized_lod_levels.get(base_coord, 0)
	
	# Base chunks (LOD 0) must ALWAYS instantiate to hold their children!
	if job.lod_level > current_authorized_lod:
		if isDev:
			if job.lod_level > current_authorized_lod and isDev:
				diagnostics.log_stale_thread(coord, job.lod_level, current_authorized_lod)
		
		var stale_key = get_chunk_key(coord, job.lod_level)
		if chunks.has(stale_key):
			var stale_chunk = chunks[stale_key]
			if is_instance_valid(stale_chunk):
				stale_chunk.queue_free()
			chunks.erase(stale_key)
		return

	var key = get_chunk_key(coord, job.lod_level)
	
	# DUPLICATE GUARD
	if chunks.has(key) and is_instance_valid(chunks[key]):
		return

	var local_voxel_scale = voxel_scale / pow(2, job.lod_level)
	var chunk: Chunk = acquire_chunk() 
	chunk.manager = self
	chunk.position = job.world_position
	chunk.voxel_size = local_voxel_scale
	chunk.lod_level = job.lod_level
	chunk.current_lod = job.lod_level
	chunk.chunk_coordinate = job.chunk_coordinate 
	chunk.mat = chunk_material
	chunk.chunk_size = chunk_size 

	if job.lod_level > 0:
		chunk.deactivate()

	chunks[key] = chunk
	voxel_data_controller.set_voxel_data(chunk,job.data)
	_link_subdivision_hierarchy(coord, chunk)



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
	)
	
	job.data = voxel_data
	_main_thread_instantiate_chunk.call_deferred(job)

# ----------------------------
# BASELINE INITIALIZATION
# ----------------------------
func start_world_generation() -> void:
	
	initial_generation_cooked = false
	
	authorized_lod_levels.clear()
	
	var total_chunks_x = int(ceil(dimensions.x / chunk_lod_size))
	var total_chunks_y = int(ceil(dimensions.y / chunk_lod_size))
	var total_chunks_z = int(ceil(dimensions.z / chunk_lod_size))
	
	var total_queued := 0

	for x in range(total_chunks_x):
		for z in range(total_chunks_z):
			for y in range(total_chunks_y):
				
				var coord = Vector3i(x, y, z)
				authorized_lod_levels[coord] = 0 # Initialize authorization maps
				var world_pos = Vector3(coord) * chunk_lod_size
				
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
		diagnostics.log_message("Voxel Engine: Initial map queued successfully! Total chunks: " + str(total_queued))


# ----------------------------
# HIERARCHY RESOLUTION
# ----------------------------
func _link_subdivision_hierarchy(
	child_coord: Vector3i,
	child_chunk: Chunk
) -> void:

	if child_chunk.lod_level == 0:
		return

	var parent_coord = Vector3i(
		child_coord.x >> 1,
		child_coord.y >> 1,
		child_coord.z >> 1
	)

	var parent_key = get_chunk_key(
		parent_coord,
		child_chunk.lod_level - 1
	)

	if chunks.has(parent_key):
		var parent_chunk: Chunk = chunks[parent_key]

		child_chunk.parent_chunk = parent_chunk

		if not parent_chunk.child_chunks.has(child_chunk):
			parent_chunk.child_chunks.append(child_chunk)
			


func queue_dirty_chunk(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		return

	if chunk in dirty_queue:
		return

	dirty_queue.append(chunk)
	
func queue_collision_chunk(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		return

	if chunk.collision_dirty == false:
		return

	if chunk.collision_queued:
		return

	chunk.collision_queued = true
	collision_queue.append(chunk)

# ==================================================
# OBJECT POOLING
# ==================================================
func acquire_chunk() -> Chunk:
	var chunk: Chunk
	if inactive_chunks.is_empty():
		chunk = chunk_scene.instantiate()
		add_child(chunk) # Keep it in the scene tree permanently
	else:
		chunk = inactive_chunks.pop_back()
	
	chunk.reset()
	return chunk

func release_chunk(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		return
	chunk.deactivate()
	inactive_chunks.append(chunk)

# ----------------------------
# CHUNK WIREFRAMES (DEBUG ONLY)
# ----------------------------
func _create_chunk_wireframe_bounds(chunk: Chunk) -> void:
	if is_instance_valid(chunk.visual_bounds_mesh):
		if chunk.visual_bounds_mesh.mesh:
			chunk.visual_bounds_mesh.material_override = null
			chunk.visual_bounds_mesh.mesh = null
			chunk.visual_bounds_mesh.free()

	var world_size = float(chunk_size) * chunk.voxel_size

	var min_p = Vector3.ZERO
	var max_p = Vector3.ONE * world_size

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

	# Vertical pillars
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

	var colors = [Color.GREEN, Color.CYAN, Color.ORANGE, Color.MAGENTA]
	debug_mat.albedo_color = colors[chunk.lod_level % colors.size()]

	var bounds_visualizer = MeshInstance3D.new()
	bounds_visualizer.mesh = imm_mesh
	bounds_visualizer.set_surface_override_material(0, debug_mat)

	chunk.add_child(bounds_visualizer)
	chunk.visual_bounds_mesh = bounds_visualizer
