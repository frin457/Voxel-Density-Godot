#./scripts/controllers/playerLODController.gd
class_name PlayerLODController extends RefCounted

var manager: ChunkManager
var last_tracked_coord := Vector3i(999999, 999999, 999999)

func _init(_manager: ChunkManager) -> void:
	manager = _manager

## Main execution hook called from ChunkManager's process loop
func update_lod(player_position: Vector3) -> void:
	var chunk_world_size = manager.get_chunk_world_size()
	
	# 1. Determine player's current baseline LOD 0 chunk coordinate
	var center_coord = Vector3i(
		floor(player_position.x / chunk_world_size),
		floor(player_position.y / chunk_world_size),
		floor(player_position.z / chunk_world_size)
	)
	
	# OPTIMIZATION: Only update if the player has actually crossed into a new LOD 0 chunk
	if center_coord == last_tracked_coord:
		return
	last_tracked_coord = center_coord
	
	# 2. Define target states for our 3x3 layout matrix around the player
	# Key: Vector3i (LOD 0 coordinate) -> Value: int (Desired LOD Level)
	var target_lod_map := {}
	
	# Loop through a 3x3 horizontally. We include y from -1 to 1 to give a vertical 
	# cushion so chunks don't aggressively blink out if the player jumps/flies.
	for x in range(-1, 2):
		for z in range(-1, 2):
			for y in range(-1, 2):
				var offset_coord = center_coord + Vector3i(x, y, z)
				
				if x == 0 and y == 0 and z == 0:
					target_lod_map[offset_coord] = 2 # Center chunk 'e' goes up 2 steps (LOD 2)
				else:
					# Surrounding chunks 'a, b, c, d, f, g, h, i' go up 1 step (LOD 1)
					# Protect center assignment from inner-loop overrides
					if not target_lod_map.has(offset_coord):
						target_lod_map[offset_coord] = 1

	# 3. Evaluate every base chunk currently registered in the manager
	var chunk_keys = manager.chunks.keys()
	for key in chunk_keys:
		if not "_LOD0" in key:
			continue # Only evaluate from baseline parent registries
			
		var base_chunk = manager.chunks[key] as Chunk
		if not is_instance_valid(base_chunk):
			continue
			
		# Deconstruct chunk coordinate from its position scale
		var chunk_coord = Vector3i(
			round(base_chunk.position.x / chunk_world_size),
			round(base_chunk.position.y / chunk_world_size),
			round(base_chunk.position.z / chunk_world_size)
		)
		
		# Get desired LOD (default to 0 if out of the 3x3 grid)
		var desired_lod = target_lod_map.get(chunk_coord, 0)
		
		# Figure out current structural runtime LOD depth
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
		# Subdivide the 8 expected children from LOD 1 to LOD 2
		# NOTE: If LOD 1 threads haven't finished yet, the subdivision controller 
		# will cleanly guard-return early and retry safely on subsequent frames.
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
		# Collapse everything entirely back to the baseline parent
		manager.subdivision_controller.request_merge(coord, 0)
		
	elif to_lod == 1 and from_lod == 2:
		# Collapse grandchildren (LOD 2) but preserve the child layer (LOD 1)
		for x in range(2):
			for y in range(2):
				for z in range(2):
					var child_coord = Vector3i(
						coord.x * 2 + x,
						coord.y * 2 + y,
						coord.z * 2 + z
					)
					manager.subdivision_controller.request_merge(child_coord, 1)
