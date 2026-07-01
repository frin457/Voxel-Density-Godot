# ./scripts/lod/engine/voxelDataController.gd

class_name VoxelDataController
extends RefCounted

# ==================================================
# PUBLIC API
# ==================================================

func set_voxel_data(chunk: Chunk, data: Dictionary) -> void:
	if not is_instance_valid(chunk):
		return

	chunk.voxel_ids = data["ids"].duplicate()
	chunk.voxel_density = data["density"].duplicate()
	chunk.voxel_colors = data["colors"].duplicate()

	chunk.original_voxel_ids = chunk.voxel_ids.duplicate()
	chunk.original_voxel_density = chunk.voxel_density.duplicate()
	chunk.original_voxel_colors = chunk.voxel_colors.duplicate()

	update_surface_cache(chunk)
	chunk.mark_dirty()


func destroy_voxel(
	chunk: Chunk,
	local_coordinate: Vector3i
) -> void:

	if not is_instance_valid(chunk):
		return

	var index := _get_index(chunk, local_coordinate)

	if chunk.voxel_ids[index] == 0:
		return

	chunk.voxel_ids[index] = 0
	chunk.voxel_density[index] = 0
	chunk.voxel_colors[index] = Color(0, 0, 0, 0)

	update_surface_cache(chunk)
	chunk.mark_dirty()


func restore_voxel(
	chunk: Chunk,
	local_coordinate: Vector3i
) -> void:

	if not is_instance_valid(chunk):
		return

	var index := _get_index(chunk, local_coordinate)

	if chunk.original_voxel_ids[index] == 0:
		return

	if chunk.voxel_ids[index] != 0:
		return

	chunk.voxel_ids[index] = chunk.original_voxel_ids[index]
	chunk.voxel_density[index] = chunk.original_voxel_density[index]
	chunk.voxel_colors[index] = chunk.original_voxel_colors[index]

	update_surface_cache(chunk)
	chunk.mark_dirty()


# ==================================================
# SURFACE CACHE
# ==================================================

func update_surface_cache(chunk: Chunk) -> void:

	if not is_instance_valid(chunk):
		return

	chunk.is_empty_air = true

	var q_keys := [
		Vector3i(0,0,0),
		Vector3i(1,0,0),
		Vector3i(0,1,0),
		Vector3i(1,1,0),
		Vector3i(0,0,1),
		Vector3i(1,0,1),
		Vector3i(0,1,1),
		Vector3i(1,1,1)
	]

	var q_found := [
		false,false,false,false,
		false,false,false,false
	]

	var quadrants_completed := 0

	var half_size := int(chunk.chunk_size / 2)
	var size := chunk.chunk_size
	var size_sq := chunk.chunk_size_sq

	for z in range(size):

		var z_offset = z * size_sq
		var q_z = 4 if z >= half_size else 0

		for y in range(size):

			var y_offset = y * size
			var q_y = 2 if y >= half_size else 0

			for x in range(size):

				var index = x + y_offset + z_offset

				if chunk.voxel_ids[index] == 0:
					continue

				chunk.is_empty_air = false

				var q_x = 1 if x >= half_size else 0
				var flat_index = q_x + q_y + q_z

				if not q_found[flat_index]:
					q_found[flat_index] = true
					quadrants_completed += 1

				if quadrants_completed == 8:
					break

			if quadrants_completed == 8:
				break

		if quadrants_completed == 8:
			break

	for i in range(8):
		chunk.sub_quadrant_has_surfaces[q_keys[i]] = q_found[i]


# ==================================================
# PRIVATE
# ==================================================

func _get_index(
	chunk: Chunk,
	local_coordinate: Vector3i
) -> int:

	return (
		local_coordinate.x +
		local_coordinate.y * chunk.chunk_size +
		local_coordinate.z * chunk.chunk_size_sq
	)
