# ./scripts/lod/tests/waveLODController.gd
class_name LODWaveController extends BaseLODController

@export var wave_speed: float = 0.1
@export var wave_gap_delay: float = 5.0

var target_wave_surface: Array[Vector3i] = []
var sorted_wave_surface: Array[Vector3i] = []
var dirty_coords: Array[Vector3i] = []

func _ready() -> void:
	super._ready()
	if not manager:
		manager = get_node_or_null("../ChunkManager") as ChunkManager
	if not manager:
		push_error("LODWaveController: Missing ChunkManager link!")
		return
	_run_wave_demonstration()

func _process(_delta: float) -> void:
	if dirty_coords.is_empty():
		return

	var remaining_dirty: Array[Vector3i] = []
	var coords_to_evaluate: Array[Vector3i] = []

	for coord in sorted_wave_surface:
		if not dirty_coords.has(coord):
			continue
		var key = manager.get_chunk_key(coord, 0)
		if not manager.chunks.has(key):
			continue
		var chunk = manager.chunks[key] as Chunk
		if not is_instance_valid(chunk):
			continue

		var desired_lod = target_lod_map.get(coord, 0)
		var current_lod = chunk.current_lod

		if desired_lod == current_lod:
			if chunk.requested_lod == current_lod:
				chunk.requested_lod = -1
			continue

		if chunk.requested_lod == -1:
			coords_to_evaluate.append(coord)

		remaining_dirty.append(coord)

	dirty_coords = remaining_dirty
	process_lod_changes(coords_to_evaluate)

func _run_wave_demonstration() -> void:
	print("Wave Engine: Waiting for initial generation...")
	while not manager.initial_generation_cooked:
		await get_tree().process_frame

	var world_chunk_size = manager.chunk_lod_size
	var total_x = int(ceil(manager.dimensions.x / world_chunk_size))
	var total_z = int(ceil(manager.dimensions.z / world_chunk_size))
	var total_y = int(ceil(manager.dimensions.y / world_chunk_size))

	for x in range(total_x):
		for z in range(total_z):
			var surface_coord = _find_top_surface_chunk(x, z, total_y)
			if surface_coord != Vector3i(-1, -1, -1):
				target_lod_map[surface_coord] = 0
				target_wave_surface.append(surface_coord)

	sorted_wave_surface = target_wave_surface.duplicate()
	sorted_wave_surface.sort_custom(func(a, b):
		if a.x != b.x: return a.x < b.x
		if a.z != b.z: return a.z < b.z
		return a.y < b.y
	)

	while true:
		for current_x in range(total_x):
			for coord in target_wave_surface:
				if coord.x == current_x:
					target_lod_map[coord] = 1
					if not dirty_coords.has(coord):
						dirty_coords.append(coord)
			await get_tree().create_timer(wave_speed).timeout

		await get_tree().create_timer(wave_gap_delay * 2.0).timeout

		for current_x in range(total_x):
			for coord in target_wave_surface:
				if coord.x == current_x:
					target_lod_map[coord] = 0
					if not dirty_coords.has(coord):
						dirty_coords.append(coord)
			await get_tree().create_timer(wave_speed).timeout

		await get_tree().create_timer(wave_gap_delay).timeout

func _find_top_surface_chunk(x: int, z: int, max_y: int) -> Vector3i:
	for y in range(max_y - 1, -1, -1):
		var test_coord = Vector3i(x, y, z)
		var key = manager.get_chunk_key(test_coord, 0)
		if manager.chunks.has(key):
			return test_coord
	return Vector3i(-1, -1, -1)
