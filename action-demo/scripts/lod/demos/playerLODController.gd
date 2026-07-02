# ./scripts/lod/playerLODController.gd
class_name PlayerLODController extends BaseLODController

var chunk_lod_size := 16
var last_chunk_coordinate := Vector3i(999999, 999999, 999999)
var last_player_position := Vector3.ZERO
var last_evaluated_chunk := Vector3i(999999, 999999, 999999)
var last_forward_vector := Vector3.ZERO

const ROTATION_THRESHOLD := 0.95

func _ready() -> void:
	super._ready()
	if not manager:
		manager = get_parent() as ChunkManager
		if not manager and get_parent():
			manager = get_parent().get_parent() as ChunkManager
	if not manager:
		push_error("PlayerLODController Error: Cannot find ChunkManager!")
	chunk_lod_size = manager.chunk_lod_size

func _process(_delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var current_pos = camera.global_position
	var center_coord = Vector3i(
		floor(current_pos.x / chunk_lod_size),
		floor(current_pos.y / chunk_lod_size),
		floor(current_pos.z / chunk_lod_size)
	)

	var current_forward = -camera.global_transform.basis.z.normalized()

	var moved_chunk = center_coord != last_evaluated_chunk
	var rotated_camera = (
		last_forward_vector == Vector3.ZERO or
		current_forward.dot(last_forward_vector) < ROTATION_THRESHOLD
	)

	last_player_position = current_pos

	if not moved_chunk and not rotated_camera:
		return

	last_evaluated_chunk = center_coord
	last_forward_vector = current_forward
	last_chunk_coordinate = center_coord

	update_lod(camera)

func update_lod(camera: Camera3D) -> void:
	var player_pos = last_player_position
	var center_coord = last_chunk_coordinate
	var camera_forward = -camera.global_transform.basis.z.normalized()

	const range_min = -3
	const range_max = 4
	const buffer = 1
	const visibility_threshold = -0.2

	# Clear and rebuild target_lod_map (inherited from base)
	target_lod_map.clear()

	for x in range(range_min, range_max):
		for y in range(range_min, range_max):
			for z in range(range_min, range_max):
				var offset_coord = center_coord + Vector3i(x, y, z)
				if abs(x) <= buffer and abs(y) <= buffer and abs(z) <= buffer:
					target_lod_map[offset_coord] = 2
					continue
				var chunk_center_world = Vector3(offset_coord) * chunk_lod_size + Vector3(chunk_lod_size, chunk_lod_size, chunk_lod_size) * 0.5
				var dir_to_chunk = (chunk_center_world - player_pos).normalized()
				var dot_product = camera_forward.dot(dir_to_chunk)
				if dot_product < visibility_threshold:
					target_lod_map[offset_coord] = 0
				else:
					target_lod_map[offset_coord] = 1

	# Preserve missing chunks as LOD 0
	for coord in prev_lod_map:
		if not target_lod_map.has(coord):
			target_lod_map[coord] = 0

	# Determine evaluation set
	var coords_to_evaluate := []
	for coord in target_lod_map:
		var new_lod = target_lod_map[coord]
		var old_lod = prev_lod_map.get(coord, -1)
		var key = manager.get_chunk_key(coord, 0)
		var is_in_flight := false
		if manager.chunks.has(key):
			var chunk = manager.chunks[key]
			is_in_flight = (chunk.requested_lod != -1)
		if new_lod == old_lod and not is_in_flight:
			continue
		coords_to_evaluate.append(coord)

	# Delegate to base class
	process_lod_changes(coords_to_evaluate, center_coord)
	prev_lod_map = target_lod_map.duplicate()
