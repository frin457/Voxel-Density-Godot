# ./scripts/controllers/playerLODController.gd
class_name PlayerLODController extends Node 

## If empty, automatically try find a parent ChunkManager.
@export var manager: ChunkManager

var last_tracked_coord := Vector3i(999999, 999999, 999999)

func _ready() -> void:
	# check heritage nodes for a ChunkManager.
	if not manager:
		manager = get_parent() as ChunkManager
		if not manager and get_parent():
			manager = get_parent().get_parent() as ChunkManager
			
	if not manager:
		push_error("PlayerLODController Error: Could not find a ChunkManager! Please add ChunkManager.gd to a child node of the world.")

func _process(_delta: float) -> void:
	if not manager:
		return
		
	# Tracks the camera viewport, currently being used
	var camera = get_viewport().get_camera_3d()
	if camera:
		update_lod(camera) # Explicitly pass the camera for view culling

## Hook for handling the grid logic and view culling
func update_lod(camera: Camera3D) -> void:
	var player_position = camera.global_position
	var chunk_world_size = manager.get_chunk_world_size()
	
	# 1. Determine player's current baseline LOD 0 chunk coordinate
	var center_coord = Vector3i(
		floor(player_position.x / chunk_world_size),
		floor(player_position.y / chunk_world_size),
		floor(player_position.z / chunk_world_size)
	)
	
	# State machine actively audits chunks every frame
	# to catch and clean up late-arriving async threads.
	last_tracked_coord = center_coord
	
	# Get normalized forward direction vector of the camera
	var camera_forward = -camera.global_transform.basis.z.normalized()
	
	# 2. Define target states for our X by Z layout matrix around the player
	var target_lod_map := {}
	const rangeMin = -1
	const rangeMax = 1
	for x in range(rangeMin,rangeMax):
		for z in range(rangeMin,rangeMax):
			for y in range(-1,1): # Vertical cushion layer
				var offset_coord = center_coord + Vector3i(x, y, z)
				
				if x == 0 and y == 0 and z == 0:
					target_lod_map[offset_coord] = 2 #  chunk resolution increases 2 steps (LOD 2)
				else:
					# Surrounding chunks go up 1 step (LOD 1) when within view of the camera
					if not target_lod_map.has(offset_coord):
						# Calculate the absolute world center position of this surrounding chunk
						var chunk_center_world = Vector3(offset_coord) * chunk_world_size + Vector3(chunk_world_size, chunk_world_size, chunk_world_size) * 0.5
						var dir_to_chunk = (chunk_center_world - player_position).normalized()
						
						# Cone Visibility Check via Dot Product:
						# 1.0 = centered, 0.0 = perpendicular. 0.4 creates a  ~132° peripheral view cone.
						var is_in_view = camera_forward.dot(dir_to_chunk) > 0.4
						
						if is_in_view:
							target_lod_map[offset_coord] = 1 # Directly in front of camera -> Keep detailed
						else:
							target_lod_map[offset_coord] = 0 # Behind camera -> Drop to LOD 0

	# 3. Evaluate every base chunk currently registered in the manager
	var chunk_keys = manager.chunks.keys()
	for key in chunk_keys:
		if not "_LOD0" in key:
			continue 
			
		var base_chunk = manager.chunks[key] as Chunk
		if not is_instance_valid(base_chunk):
			continue
			
		var chunk_coord = Vector3i(
			round(base_chunk.position.x / chunk_world_size),
			round(base_chunk.position.y / chunk_world_size),
			round(base_chunk.position.z / chunk_world_size)
		)
		
		var desired_lod = target_lod_map.get(chunk_coord, 0)
		
		var current_lod = 0
		if base_chunk.child_chunks.size() == 8:
			current_lod = 1
			var first_child = base_chunk.child_chunks[0]
			if is_instance_valid(first_child) and first_child.child_chunks.size() == 8:
				current_lod = 2

		# 4. State Machine Transition Execution
		if desired_lod == current_lod:
			continue
			
		if desired_lod > current_lod:
			_upgrade_chunk_lod(chunk_coord, current_lod, desired_lod)
		else:
			_downgrade_chunk_lod(chunk_coord, current_lod, desired_lod)


func _upgrade_chunk_lod(coord: Vector3i, from_lod: int, to_lod: int) -> void:
	if from_lod == 0 and to_lod >= 1:
		manager.subdivision_controller.request_subdivision(coord, 1)
		
	if to_lod == 2:
		for x in range(2):
			for y in range(2):
				for z in range(2):
					var child_coord = Vector3i(
						coord.x * 2 + x,
						coord.y * 2 + y,
						coord.z * 2 + z
					)
					manager.subdivision_controller.request_subdivision(child_coord, 2)


func _downgrade_chunk_lod(coord: Vector3i, from_lod: int, to_lod: int) -> void:
	if to_lod == 0:
		manager.subdivision_controller.request_merge(coord, 0)
		
	elif to_lod == 1 and from_lod == 2:
		for x in range(2):
			for y in range(2):
				for z in range(2):
					var child_coord = Vector3i(
						coord.x * 2 + x,
						coord.y * 2 + y,
						coord.z * 2 + z
					)
					manager.subdivision_controller.request_merge(child_coord, 1)
