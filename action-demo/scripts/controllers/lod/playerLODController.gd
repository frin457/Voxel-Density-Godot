# ./scripts/controllers/playerLODController.gd
class_name PlayerLODController extends Node

## If left empty, it will automatically try to find it if this node is a child of the ChunkManager.
@onready var manager: ChunkManager = $".."

var last_tracked_coord := Vector3i(999999, 999999, 999999)
var requested_lod_map := {} 

@export_group("Velocity Gating")
@export var speed_threshold_lod2: float = 8.0
@export var settle_duration: float = 0.4

var last_player_position := Vector3.ZERO
var current_speed := 0.0
var settle_timer := 0.0

const MAX_UPGRADES_PER_FRAME = 2
const MAX_DOWNGRADES_PER_FRAME = 1
const KEEP_NEIGHBORS_LOD1_LOADED = true

func _ready() -> void:
	if not manager:
		manager = get_parent() as ChunkManager
		if not manager and get_parent():
			manager = get_parent().get_parent() as ChunkManager
			
	if not manager:
		push_error("PlayerLODController Error: Cannot find ChunkManager!")

func _process(delta: float) -> void:
	if not manager:
		return
		
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	var current_position = camera.global_position
	if last_player_position != Vector3.ZERO and delta > 0.0:
		current_speed = (current_position - last_player_position).length() / delta
	else:
		current_speed = 0.0
	last_player_position = current_position

	if current_speed < speed_threshold_lod2:
		settle_timer += delta
	else:
		settle_timer = 0.0 

	update_lod(camera)

func update_lod(camera: Camera3D) -> void:
	var player_position = camera.global_position
	var chunk_world_size = manager.get_chunk_world_size()
	
	var center_coord = Vector3i(
		floor(player_position.x / chunk_world_size),
		floor(player_position.y / chunk_world_size),
		floor(player_position.z / chunk_world_size)
	)
	
	last_tracked_coord = center_coord
	var camera_forward = -camera.global_transform.basis.z.normalized()
	var is_allowed_lod2 = (current_speed < speed_threshold_lod2) and (settle_timer >= settle_duration)
	
	var target_lod_map := {}
	const rangeMin = -1
	const rangeMax = 2 
	for x in range(rangeMin, rangeMax):
		for z in range(rangeMin, rangeMax):
			for y in range(rangeMin, rangeMax): 
				var offset_coord = center_coord + Vector3i(x, y, z)
				
				if x == 0 and y == 0 and z == 0:
					target_lod_map[offset_coord] = 2 if is_allowed_lod2 else 1
				else:
					if not target_lod_map.has(offset_coord):
						if KEEP_NEIGHBORS_LOD1_LOADED:
							target_lod_map[offset_coord] = 1
						else:
							var chunk_center_world = Vector3(offset_coord) * chunk_world_size + Vector3(chunk_world_size, chunk_world_size, chunk_world_size) * 0.5
							var dir_to_chunk = (chunk_center_world - player_position).normalized()
							var dot_product = camera_forward.dot(dir_to_chunk)
							
							if dot_product > 0.4:
								target_lod_map[offset_coord] = 1 
							elif dot_product < 0.1:
								target_lod_map[offset_coord] = 0
							else:
								target_lod_map[offset_coord] = requested_lod_map.get(offset_coord, 0)

	var upgrades_dispatched = 0
	var downgrades_dispatched = 0

	var coords_to_evaluate := []
	for coord in target_lod_map:
		coords_to_evaluate.append(coord)
	for coord in requested_lod_map:
		if not target_lod_map.has(coord):
			coords_to_evaluate.append(coord)

	for chunk_coord in coords_to_evaluate:
		var key = manager.get_chunk_key(chunk_coord, 0)
		if not manager.chunks.has(key):
			continue
			
		var base_chunk = manager.chunks[key] as Chunk
		if not is_instance_valid(base_chunk):
			continue
			
		var desired_lod = target_lod_map.get(chunk_coord, 0)
		
		var current_lod = 0
		if base_chunk.child_chunks.size() > 0: 
			current_lod = 1
			for child in base_chunk.child_chunks:
				if is_instance_valid(child) and child.child_chunks.size() > 0:
					current_lod = 2
					break

		# If we have successfully achieved our desired LOD state, clear our tracking history
		if desired_lod == current_lod:
			if requested_lod_map.get(chunk_coord, -1) == current_lod:
				requested_lod_map.erase(chunk_coord)
			continue

		# FIXED: Enforce a strict incremental single-step state transition loop.
		# This completely avoids simultaneous double-merges or double-subdivisions.
		if desired_lod > current_lod:
			var next_lod = current_lod + 1
			
			# If we've already dispatched a request for this step, wait for it to build
			if requested_lod_map.get(chunk_coord, -1) == next_lod:
				continue
				
			if chunk_coord != center_coord and upgrades_dispatched >= MAX_UPGRADES_PER_FRAME:
				continue
				
			_upgrade_chunk_lod(chunk_coord, current_lod, next_lod)
			upgrades_dispatched += 1
			requested_lod_map[chunk_coord] = next_lod
		else:
			var next_lod = current_lod - 1
			
			# If we've already dispatched a request for this step, wait for it to collapse
			if requested_lod_map.get(chunk_coord, -1) == next_lod:
				continue
				
			if chunk_coord != center_coord and downgrades_dispatched >= MAX_DOWNGRADES_PER_FRAME:
				continue
				
			_downgrade_chunk_lod(chunk_coord, current_lod, next_lod)
			downgrades_dispatched += 1
			requested_lod_map[chunk_coord] = next_lod


# Upgrades are now strictly single-step (0 -> 1 OR 1 -> 2)
func _upgrade_chunk_lod(coord: Vector3i, from_lod: int, to_lod: int) -> void:
	if from_lod == 0 and to_lod == 1:
		if _chunk_contains_surfaces(coord, 1):
			manager.subdivision_controller.request_subdivision(coord, 1)
		
	elif from_lod == 1 and to_lod == 2:
		for x in range(2):
			for y in range(2):
				for z in range(2):
					var child_coord = Vector3i(
						coord.x * 2 + x,
						coord.y * 2 + y,
						coord.z * 2 + z
					)
					if _chunk_contains_surfaces(child_coord, 2):
						manager.subdivision_controller.request_subdivision(child_coord, 2)


# Downgrades are now strictly single-step (2 -> 1 OR 1 -> 0)
func _downgrade_chunk_lod(coord: Vector3i, from_lod: int, to_lod: int) -> void:
	if from_lod == 2 and to_lod == 1:
		for x in range(2):
			for y in range(2):
				for z in range(2):
					var child_coord = Vector3i(
						coord.x * 2 + x,
						coord.y * 2 + y,
						coord.z * 2 + z
					)
					manager.subdivision_controller.request_merge(child_coord, 1)
		
	elif from_lod == 1 and to_lod == 0:
		manager.subdivision_controller.request_merge(coord, 0)


## ULTRA-FAST CACHED AUDIT LOOKUP
func _chunk_contains_surfaces(coord: Vector3i, target_lod: int) -> bool:
	if target_lod == 1:
		var key = manager.get_chunk_key(coord, 0)
		if manager.chunks.has(key):
			var chunk = manager.chunks[key] as Chunk
			if is_instance_valid(chunk):
				return not chunk.is_empty_air
				
	elif target_lod == 2:
		var parent_coord = Vector3i(coord.x >> 1, coord.y >> 1, coord.z >> 1)
		var parent_key = manager.get_chunk_key(parent_coord, 0)
		
		if manager.chunks.has(parent_key):
			var parent_chunk = manager.chunks[parent_key] as Chunk
			if is_instance_valid(parent_chunk):
				var local_offset = Vector3i(coord.x & 1, coord.y & 1, coord.z & 1)
				return parent_quadrant_has_surfaces(parent_chunk, local_offset)
				
	return true 

func parent_quadrant_has_surfaces(parent_chunk: Chunk, local_offset: Vector3i) -> bool:
	if not parent_chunk.get("sub quadrant has faces") != null:
	#if not parent_chunk.get("sub_quadrant_has_surfaces") != null:
		return parent_chunk.sub_quadrant_has_surfaces.get(local_offset, true)
	return true
