# ./scripts/lod/BaseLODController.gd

class_name BaseLODController extends Node

@export var manager: ChunkManager

@export var max_upgrades_per_frame := 8
@export var max_downgrades_per_frame := 16

var target_lod_map := {}
var prev_lod_map := {}

func _ready() -> void:
	if not manager:
		manager = get_parent() as ChunkManager

	if not manager and get_parent():
		manager = get_parent().get_parent() as ChunkManager

	if not manager:
		push_error("LODControllerBase: Missing ChunkManager.")


# ==================================================
# MAIN DISPATCH PIPELINE
# ==================================================
func process_lod_changes(coords_to_evaluate: Array, priority_coord: Vector3i = Vector3i(999999,999999,999999)) -> void:
	var upgrades := 0
	var downgrades := 0

	for coord in coords_to_evaluate:

		var key = manager.get_chunk_key(coord, 0)

		if not manager.chunks.has(key):
			continue

		var chunk := manager.chunks[key] as Chunk

		if not is_instance_valid(chunk):
			continue

		var desired_lod = target_lod_map.get(coord, 0)
		var current_lod = chunk.current_lod

		# Already correct
		if desired_lod == current_lod:
			if chunk.requested_lod == current_lod:
				chunk.requested_lod = -1
			continue

		# ======================
		# UPSCALE / SPLIT
		# ======================
		if desired_lod > current_lod:

			var next_lod = current_lod + 1

			if chunk.requested_lod == next_lod:
				continue

			if coord != priority_coord and upgrades >= max_upgrades_per_frame:
				continue

			_upgrade_chunk_lod(coord, current_lod, next_lod)

			upgrades += 1
			chunk.requested_lod = next_lod
			manager.set_authorized_lod(coord, next_lod)

		# ======================
		# DOWNSCALE / MERGE
		# ======================
		else:

			var next_lod = current_lod - 1

			if chunk.requested_lod == next_lod:
				continue

			if coord != priority_coord and downgrades >= max_downgrades_per_frame:
				continue

			_downgrade_chunk_lod(coord, current_lod, next_lod)

			downgrades += 1
			chunk.requested_lod = next_lod
			manager.set_authorized_lod(coord, next_lod)


# ==================================================
# DEFAULT LOD OPERATIONS
# ==================================================
func _upgrade_chunk_lod(coord: Vector3i, from_lod: int, to_lod: int) -> void:
	var scale := 1 << from_lod
	var jobs := []

	for x in range(scale):
		for y in range(scale):
			for z in range(scale):

				var target_coord = Vector3i(
					coord.x * scale + x,
					coord.y * scale + y,
					coord.z * scale + z
				)

				if not _chunk_contains_surfaces(target_coord, to_lod):
					continue

				jobs.append(target_coord)

	for job in jobs:
		manager.subdivision_controller.request_subdivision(job, to_lod)


func _downgrade_chunk_lod(coord: Vector3i, _from_lod: int, to_lod: int) -> void:
	manager.subdivision_controller.request_merge(coord, to_lod)


# ==================================================
# SURFACE CHECK (NOW SHARED)
# ==================================================
func _chunk_contains_surfaces(coord: Vector3i, target_lod: int) -> bool:

	if target_lod == 0:
		return true

	var parent_coord = coord

	for i in range(target_lod):
		parent_coord = Vector3i(
			parent_coord.x >> 1,
			parent_coord.y >> 1,
			parent_coord.z >> 1
		)

	var parent_lod = target_lod - 1
	var parent_key = manager.get_chunk_key(parent_coord, parent_lod)

	if manager.chunks.has(parent_key):

		var parent_chunk = manager.chunks[parent_key] as Chunk

		if is_instance_valid(parent_chunk):

			if parent_chunk.is_empty_air:
				return false

			var local_offset = Vector3i(
				coord.x & 1,
				coord.y & 1,
				coord.z & 1
			)

			return parent_quadrant_has_surfaces(parent_chunk, local_offset)

	return true


func parent_quadrant_has_surfaces(parent_chunk: Chunk, local_offset: Vector3i) -> bool:
	if is_instance_valid(parent_chunk):
		return parent_chunk.sub_quadrant_has_surfaces.get(local_offset, true)
	return true
