# ./scripts/controllers/subdivisionController.gd
class_name SubdivisionController extends RefCounted

var manager: ChunkManager

# Gating variables to stop frame-by-frame floods
var last_evaluation_position := Vector3(INF, INF, INF)
@export var evaluation_threshold_meters := 2.0 

# Hysteresis offsets to stop oscillation at the boundaries
@export var subdivision_radius := 32.0
@export var merge_radius := 40.0 

# Track what is currently processing to reject duplicate request floods
var pending_subdivisions := {}
var pending_merges := {}

func _init(_manager: ChunkManager) -> void:
	manager = _manager


func evaluate_lod_grid(player_position: Vector3) -> void:
	if player_position.distance_to(last_evaluation_position) < evaluation_threshold_meters:
		return
		
	last_evaluation_position = player_position
	var current_chunk_keys = manager.chunks.keys()
	
	for key in current_chunk_keys:
		var chunk = manager.chunks.get(key)
		if not is_instance_valid(chunk):
			continue
			
		if not chunk.visible:
			continue
			
		var chunk_world_size = float(manager.chunk_size) * chunk.voxel_size
		var chunk_center = chunk.global_position + (Vector3.ONE * (chunk_world_size * 0.5))
		var distance = chunk_center.distance_to(player_position)
		
		var coord = chunk.chunk_coordinate
		var current_level = chunk.subdivision_level
		
		if distance < subdivision_radius:
			if current_level < 2: 
				if not pending_subdivisions.has(key):
					request_subdivision(coord, current_level + 1)
					
		elif current_level > 0:
			var parent_chunk = chunk.parent_chunk
			if is_instance_valid(parent_chunk):
				var parent_level = current_level - 1
				var parent_voxel_size = chunk.voxel_size * 2.0
				var parent_world_size = float(manager.chunk_size) * parent_voxel_size
				var parent_center = parent_chunk.global_position + (Vector3.ONE * (parent_world_size * 0.5))
				var parent_distance = parent_center.distance_to(player_position)
				
				if parent_distance > merge_radius:
					var parent_key = manager.get_chunk_key(parent_chunk.chunk_coordinate, parent_level)
					if not pending_merges.has(parent_key):
						request_merge(parent_chunk.chunk_coordinate, parent_level)


func request_subdivision(coord: Vector3i, target_level: int) -> void:
	var key = manager.get_chunk_key(coord, target_level - 1)
	
	if pending_subdivisions.has(key) or not manager.chunks.has(key):
		return
		
	pending_subdivisions[key] = true
	
	var parent_chunk = manager.chunks[key]
	var world_size = manager.get_chunk_world_size() / pow(2, target_level)
	
	for x in range(2):
		for y in range(2):
			for z in range(2):
				var child_coord = (coord * 2) + Vector3i(x, y, z)
				var child_world_pos = parent_chunk.position + (Vector3(x, y, z) * world_size)
				
				var job = ChunkJob.new(
					ChunkJob.JobType.GENERATE,
					child_coord,
					child_world_pos,
					{},
					1.0,
					target_level
				)
				manager.job_queue.push(job)


func subdivision_complete(parent_coord: Vector3i, level: int) -> void:
	var parent_key = manager.get_chunk_key(parent_coord, level - 1)
	pending_subdivisions.erase(parent_key)
	
	if manager.chunks.has(parent_key):
		var parent_chunk = manager.chunks[parent_key]
		parent_chunk.visible = false
		parent_chunk.process_mode = Node.PROCESS_MODE_DISABLED


func request_merge(parent_coord: Vector3i, parent_level: int) -> void:
	var parent_key = manager.get_chunk_key(parent_coord, parent_level)
	
	# Clean Action Guard: Stop duplicate concurrent executions on the same chunk
	if pending_merges.has(parent_key):
		return
		
	pending_merges[parent_key] = true
	
	if manager.chunks.has(parent_key):
		var parent_chunk = manager.chunks[parent_key]
		
		# 1. Reactivate parent visually and logically
		parent_chunk.visible = true
		parent_chunk.process_mode = Node.PROCESS_MODE_INHERIT
		
		# 2. Clean up child hierarchy nodes safely on the main thread
		_clean_child_geometry(parent_chunk)
		
	pending_merges.erase(parent_key)


func _clean_child_geometry(parent_chunk: Chunk) -> void:
	var children_to_free = parent_chunk.child_chunks.duplicate()
	parent_chunk.child_chunks.clear()
	
	for child in children_to_free:
		if is_instance_valid(child):
			var child_key = manager.get_chunk_key(child.chunk_coordinate, child.subdivision_level)
			manager.chunks.erase(child_key)
			child.queue_free()


func notify_chunk_mesh_ready(chunk: Chunk) -> void:
	if chunk.subdivision_level == 0:
		return 
		
	var parent_chunk = chunk.parent_chunk
	if not is_instance_valid(parent_chunk):
		return

	var all_siblings_ready := true
	if parent_chunk.child_chunks.size() < 8:
		all_siblings_ready = false
	else:
		for sibling in parent_chunk.child_chunks:
			if not is_instance_valid(sibling) or sibling.mesh_dirty or sibling.collision_dirty:
				all_siblings_ready = false
				break

	if all_siblings_ready:
		var parent_coord = parent_chunk.chunk_coordinate
		subdivision_complete(parent_coord, chunk.subdivision_level)
