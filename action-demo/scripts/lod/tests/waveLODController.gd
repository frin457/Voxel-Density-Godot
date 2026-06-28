# ./scripts/lod/tests/waveLODController.gd
class_name LODWaveController extends Node

@export var manager: ChunkManager
@export var wave_speed: float = 0.1
@export var wave_gap_delay: float = 5.0

# ==========================================
# MODERN LOD SYSTEM HOOKS & STATE TRACKING
# ==========================================
var target_lod_map := {}
var requested_lod_map := {}

const MAX_UPGRADES_PER_FRAME = 4
const MAX_DOWNGRADES_PER_FRAME = 8

var target_wave_surface: Array[Vector3i] = []

func _ready() -> void:
	if not manager:
		manager = get_node_or_null("../ChunkManager") as ChunkManager
		
	if not manager:
		push_error("LODWaveController: Missing ChunkManager link!")
		return
		
	_run_wave_demonstration()

func _process(_delta: float) -> void:
	if target_lod_map.is_empty():
		return
		
	# 1. Diff Engine: Evaluate chunks strictly against their ACTUAL current state
	var coords_to_evaluate := []
	for coord in target_lod_map:
		var key = manager.get_chunk_key(coord, 0)
		if not manager.chunks.has(key):
			continue
			
		var base_chunk = manager.chunks[key] as Chunk
		if not is_instance_valid(base_chunk) or base_chunk.is_queued_for_deletion():
			continue
			
		var desired_lod = target_lod_map[coord]
		var current_lod = base_chunk.get_current_lod()
		
		# If transition completed successfully, clear its in-flight status
		if desired_lod == current_lod:
			if requested_lod_map.has(coord) and requested_lod_map[coord] == current_lod:
				requested_lod_map.erase(coord)
			continue 
			
		# If it needs an update and isn't currently mid-transition, queue it
		if not requested_lod_map.has(coord):
			coords_to_evaluate.append(coord)

	# PROPAGATION ORDER
	# Sort sequentially by X, then Z, then Y to ensure a perfect sweeping line
	coords_to_evaluate.sort_custom(func(a, b):
		if a.x != b.x: return a.x < b.x
		if a.z != b.z: return a.z < b.z
		return a.y < b.y
	)

	# Dispatching Throttle
	var upgrades_dispatched = 0
	var downgrades_dispatched = 0

	for chunk_coord in coords_to_evaluate:
		var key = manager.get_chunk_key(chunk_coord, 0)
		var base_chunk = manager.chunks[key] as Chunk
		var desired_lod = target_lod_map[chunk_coord]
		var current_lod = base_chunk.get_current_lod()
		
		# Dispatch Upgrades (Split)
		if desired_lod > current_lod:
			var next_lod = current_lod + 1
			
			if requested_lod_map.get(chunk_coord, -1) == next_lod: continue #map completed, skip
			if upgrades_dispatched >= MAX_UPGRADES_PER_FRAME: continue #batch count, skip
			#otherwise upgrade chunk
			_upgrade_chunk_lod(chunk_coord, current_lod, next_lod)
			upgrades_dispatched += 1
			requested_lod_map[chunk_coord] = next_lod
			manager.set_authorized_lod(chunk_coord, next_lod)
			
		# Dispatch Downgrades (Merge)
		elif desired_lod < current_lod:
			var next_lod = current_lod - 1
			if requested_lod_map.get(chunk_coord, -1) == next_lod: continue
			if downgrades_dispatched >= MAX_DOWNGRADES_PER_FRAME: continue
				
			_downgrade_chunk_lod(chunk_coord, current_lod, next_lod)
			downgrades_dispatched += 1
			requested_lod_map[chunk_coord] = next_lod
			manager.set_authorized_lod(chunk_coord, next_lod)

# ==========================================
# WAVE-PATTERN TIMELINE SEQUENCE
# ==========================================
func _run_wave_demonstration() -> void:
	print("Wave Engine: Waiting for initial background generation to completely cook...")
	
	while not manager.initial_generation_cooked:
		await get_tree().process_frame
		
	var world_chunk_size = manager.chunk_lod_size
	var total_x = int(ceil(manager.dimensions.x / world_chunk_size))
	var total_z = int(ceil(manager.dimensions.z / world_chunk_size))
	var total_y = int(ceil(manager.dimensions.y / world_chunk_size))
	
	# Build baseline static map
	for x in range(total_x):
		for z in range(total_z):
			var surface_coord = _find_top_surface_chunk(x, z, total_y)
			if surface_coord != Vector3i(-1, -1, -1):
				target_wave_surface.append(surface_coord)
				target_lod_map[surface_coord] = 0
				
	print("Wave Test: Map ready! Caching baseline wave coordinates...")
	await get_tree().create_timer(0.1).timeout
	while true:
		print("Wave Test: ---> Dispatching Sorted Split Front (LOD 1) <---")
		for current_x in range(total_x):
			var advanced = false
			for coord in target_wave_surface:
				if coord.x == current_x:
					target_lod_map[coord] = 1 # DECLARE the state change
					advanced = true
			if advanced:
				await get_tree().create_timer(wave_speed).timeout
			
			
		print("Wave Test: Split wave fully rendered! Holding peak layout...")
		await get_tree().create_timer(wave_gap_delay* 2.0).timeout
		
		print("Wave Test: ---> Dispatching Collapse Front (LOD 0) <---")
		for current_x in range(total_x):
			var advanced = false
			for coord in target_wave_surface:
				if coord.x == current_x:
					target_lod_map[coord] = 0 # DECLARE the state change
					advanced = true
			if advanced:
				await get_tree().create_timer(wave_speed).timeout
			
			
		print("Wave Test: Collapse wave fully rendered! Resetting cycle...")
		await get_tree().create_timer(wave_gap_delay).timeout

# ==========================================
# SYSTEM HELPERS
# ==========================================

func _upgrade_chunk_lod(coord: Vector3i, from_lod: int, to_lod: int) -> void:
	var scale := 1 << from_lod
	var potential_jobs := []
	
	for x in range(scale):
		for y in range(scale):
			for z in range(scale):
				var target_coord = Vector3i(
					coord.x * scale + x,
					coord.y * scale + y,
					coord.z * scale + z
				)
				if _chunk_contains_surfaces(target_coord, to_lod):
					potential_jobs.append(target_coord)
	
	for job_coord in potential_jobs:
		manager.subdivision_controller.request_subdivision(job_coord, to_lod)

func _downgrade_chunk_lod(coord: Vector3i, _from_lod: int, to_lod: int) -> void:
	manager.subdivision_controller.request_merge(coord, to_lod)

func _chunk_contains_surfaces(coord: Vector3i, target_lod: int) -> bool:
	if target_lod == 0: return true
	var parent_coord = coord
	for i in range(target_lod):
		parent_coord = Vector3i(parent_coord.x >> 1, parent_coord.y >> 1, parent_coord.z >> 1)
		
	var parent_lod = target_lod - 1
	var parent_key = manager.get_chunk_key(parent_coord, parent_lod)
	
	if manager.chunks.has(parent_key):
		var parent_chunk = manager.chunks[parent_key] as Chunk
		if is_instance_valid(parent_chunk):
			if parent_chunk.is_empty_air: return false
			var local_offset = Vector3i(coord.x & 1, coord.y & 1, coord.z & 1)
			return parent_quadrant_has_surfaces(parent_chunk, local_offset)
	return true

func parent_quadrant_has_surfaces(parent_chunk: Chunk, local_offset: Vector3i) -> bool:
	if is_instance_valid(parent_chunk):
		return parent_chunk.sub_quadrant_has_surfaces.get(local_offset, true)
	return true

func _dispatch_batch(coords: Array, target_lod: int) -> void:
	for coord in coords:
		target_lod_map[coord] = target_lod
		manager.set_authorized_lod(coord, target_lod)
		# Assuming you have a way to identify these specific jobs
		#	_track_pending_batch(coord)
		
func _find_top_surface_chunk(x: int, z: int, max_y: int) -> Vector3i:
	for y in range(max_y - 1, -1, -1):
		var test_coord = Vector3i(x, y, z)
		var key = manager.get_chunk_key(test_coord, 0)
		if manager.chunks.has(key):
			return test_coord
	return Vector3i(-1, -1, -1)
