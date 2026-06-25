#./scripts/lod/tests/playerLODController.gd
class_name PlayerLODController extends Node

@onready var manager: ChunkManager = $".."

var last_tracked_coord := Vector3i(999999, 999999, 999999)
var requested_lod_map := {} 

const MAX_UPGRADES_PER_FRAME = 4
const MAX_DOWNGRADES_PER_FRAME = 8 
const KEEP_NEIGHBORS_LOD1_LOADED = true

func _ready() -> void:
	if not manager:
		manager = get_parent() as ChunkManager
		if not manager and get_parent():
			manager = get_parent().get_parent() as ChunkManager
			
	if not manager:
		push_error("PlayerLODController Error: Cannot find ChunkManager!")

func _process(_delta: float) -> void:
	if not manager:
		return
		
	var camera = get_viewport().get_camera_3d()
	var chunk_size = manager.chunk_size
	var player_position = camera.global_position
	var center_coord = Vector3i(
		floor(player_position.x / manager.chunk_size),
		floor(player_position.y / chunk_size),
		floor(player_position.z / chunk_size)
	)
	
	if center_coord == last_tracked_coord:
		return
	
	if not camera:
		return

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
	var target_lod_map := {}
	const rangeMin = -2
	const rangeMax = 3
	for x in range(rangeMin, rangeMax):
		for z in range(rangeMin, rangeMax):
			for y in range(rangeMin, rangeMax): 
				var offset_coord = center_coord + Vector3i(x, y, z)
				#Prioritze 'center' chunk (player location)
				if x == 0 and y == 0 and z == 0:
					target_lod_map[offset_coord] = 2
					continue # Skip the rest for the center chunk
			
				# Process surroundings only when not already set
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
		
	for key in manager.chunks.keys():
		var chunk = manager.chunks[key]
		if is_instance_valid(chunk) and chunk.lod_level == 0:
			if not target_lod_map.has(chunk.chunk_coordinate):
				coords_to_evaluate.append(chunk.chunk_coordinate)

	for chunk_coord in coords_to_evaluate:
		var key = manager.get_chunk_key(chunk_coord, 0)
		if not manager.chunks.has(key):
			continue
			
		var base_chunk = manager.chunks[key] as Chunk
		if not is_instance_valid(base_chunk) or base_chunk.is_queued_for_deletion():
			continue
			
		var desired_lod = target_lod_map.get(chunk_coord, 0)
		var current_lod = base_chunk.get_current_lod()

		if desired_lod == current_lod:
			var in_flight = requested_lod_map.get(chunk_coord, -1)
			if in_flight == current_lod:
				requested_lod_map.erase(chunk_coord)
			elif in_flight > desired_lod:
				# Downgrade cancellation / stale structural guard
				manager.set_authorized_lod(chunk_coord, desired_lod)
				requested_lod_map.erase(chunk_coord)
			continue

		if desired_lod > current_lod:
			var next_lod = current_lod + 1
			if requested_lod_map.get(chunk_coord, -1) == next_lod:
				continue
			if chunk_coord != center_coord and upgrades_dispatched >= MAX_UPGRADES_PER_FRAME:
				continue
				
			_upgrade_chunk_lod(chunk_coord, current_lod, next_lod, player_position)
			upgrades_dispatched += 1
			requested_lod_map[chunk_coord] = next_lod
			manager.set_authorized_lod(chunk_coord, next_lod)
		else:
			var next_lod = current_lod - 1
			if requested_lod_map.get(chunk_coord, -1) == next_lod:
				continue
			if chunk_coord != center_coord and downgrades_dispatched >= MAX_DOWNGRADES_PER_FRAME:
				continue
				
			_downgrade_chunk_lod(chunk_coord, current_lod, next_lod)
			downgrades_dispatched += 1
			requested_lod_map[chunk_coord] = next_lod
			manager.set_authorized_lod(chunk_coord, next_lod)


func _upgrade_chunk_lod(coord: Vector3i, from_lod: int, to_lod: int, player_pos: Vector3) -> void:
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
					# We need the world position to calculate priority
					var world_pos = Vector3(target_coord) * manager.get_chunk_world_size()
					var dist = world_pos.distance_to(player_pos)
					potential_jobs.append({"coord": target_coord, "dist": dist})
	
	# Sort by distance: Closest chunks first (lowest distance = highest priority)
	potential_jobs.sort_custom(func(a, b): return a.dist < b.dist)
	
	for job in potential_jobs:
		manager.subdivision_controller.request_subdivision(job.coord, to_lod)

func _downgrade_chunk_lod(
	coord: Vector3i,
	from_lod: int,
	to_lod: int
) -> void:
	print(
	"DOWNGRADE ",
	coord,
	" FROM ",
	from_lod,
	" TO ",
	to_lod,
	" PARENT ",
	coord
	)
	manager.subdivision_controller.request_merge(
		coord,
		to_lod
	)


func _chunk_contains_surfaces(coord: Vector3i, target_lod: int) -> bool:
	if target_lod == 0:
		return true
		
	# Dynamically check parents at higher depths supporting arbitrary LODs (LOD 3+)
	var parent_coord = coord
	for i in range(target_lod):
		parent_coord = Vector3i(parent_coord.x >> 1, parent_coord.y >> 1, parent_coord.z >> 1)
		
	var parent_lod = target_lod - 1

	var parent_key = manager.get_chunk_key(
		parent_coord,
		parent_lod
	)
	if manager.chunks.has(parent_key):
		var parent_chunk = manager.chunks[parent_key] as Chunk
		if is_instance_valid(parent_chunk):
			if parent_chunk.is_empty_air:
				return false
			# Dynamic localized quadrant lookup matching step size bitshifts
			var local_offset = Vector3i(coord.x & 1, coord.y & 1, coord.z & 1)
			return parent_quadrant_has_surfaces(parent_chunk, local_offset)
				
	return true


func parent_quadrant_has_surfaces(parent_chunk: Chunk, local_offset: Vector3i) -> bool:
	if is_instance_valid(parent_chunk):
		return parent_chunk.sub_quadrant_has_surfaces.get(
			local_offset,
			true
		)
	return true
