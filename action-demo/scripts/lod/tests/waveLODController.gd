#./scripts/lod/tests/waveLODController.gd
extends Node
class_name LODWaveController

@export var chunk_manager: ChunkManager
@export var wave_speed: float = 0.1
@export var wave_gap_delay: float = 1.0

func _ready() -> void:
	if not chunk_manager:
		chunk_manager = get_node_or_null("../ChunkManager") as ChunkManager
		
	if not chunk_manager:
		push_error("LODWaveController: Missing ChunkManager link!")
		return
		
	_run_wave_demonstration()


func _run_wave_demonstration() -> void:
	print("Wave Engine: Waiting for initial background generation to completely cook...")
	
	while not chunk_manager.initial_generation_cooked:
		await get_tree().process_frame
		
	print("Wave Engine: Map ready! Caching baseline wave coordinates...")
	await get_tree().create_timer(1.5).timeout
	
	var world_size_size = chunk_manager.get_chunk_world_size()
	var total_x = int(ceil(chunk_manager.dimensions.x / world_size_size))
	var total_z = int(ceil(chunk_manager.dimensions.z / world_size_size))
	var total_y = int(ceil(chunk_manager.dimensions.y / world_size_size))
	
	# CRITICAL FIX: Build a static map of the baseline surface targets *before* structural manipulation begins
	var target_wave_surface: Array[Vector3i] = []
	for x in range(total_x):
		for z in range(total_z):
			var surface_coord = _find_top_surface_chunk(x, z, total_y)
			if surface_coord != Vector3i(-1, -1, -1):
				target_wave_surface.append(surface_coord)

	while true:
		print("Wave Engine: ---> Dispatching Sorted Split Front (LOD 1) <---")
		
		# Process across our cached static column markers array
		var current_x = -1
		for target_coord in target_wave_surface:
			# Progress the wave sweep smoothly along the major X axis alignment line
			if current_x != target_coord.x and current_x != -1:
				await get_tree().create_timer(wave_speed).timeout
			current_x = target_coord.x
			
			# PASS THE X POSITION AS THE DETERMINISTIC SORT INDEX
			chunk_manager.subdivision_requested.emit(target_coord, 1, current_x)
			
		# Final padding sweep delay for the last column array line
		await get_tree().create_timer(wave_speed).timeout
			
		print("Wave Engine: Split requested. Waiting for thread pool tasks to clear...")
		while chunk_manager.active_thread_tasks.size() > 0 or not chunk_manager.job_queue.is_empty():
			await get_tree().process_frame
			
		print("Wave Engine: Split wave fully rendered! Holding peak layout...")
		await get_tree().create_timer(wave_gap_delay).timeout
		
		print("Wave Engine: ---> Dispatching Collapse Front (LOD 0) <---")
		current_x = -1
		for target_coord in target_wave_surface:
			if current_x != target_coord.x and current_x != -1:
				await get_tree().create_timer(wave_speed).timeout
			current_x = target_coord.x
			
			chunk_manager.merge_requested.emit(target_coord)
			
		await get_tree().create_timer(wave_speed).timeout
			
		print("Wave Engine: Collapse wave fully rendered! Resetting cycle...")
		await get_tree().create_timer(wave_gap_delay * 2.0).timeout


func _find_top_surface_chunk(x: int, z: int, max_y: int) -> Vector3i:
	for y in range(max_y - 1, -1, -1):
		var test_coord = Vector3i(x, y, z)
		var key = chunk_manager.get_chunk_key(test_coord, 0)
		if chunk_manager.chunks.has(key):
			return test_coord
	return Vector3i(-1, -1, -1)
