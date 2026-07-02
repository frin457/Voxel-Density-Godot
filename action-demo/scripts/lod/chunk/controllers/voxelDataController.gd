#./scripts/lod/chunk/surfaces/voxels/voxelDataController.gd
class_name VoxelDataController
extends RefCounted

# ==================================================
# PUBLIC API
# ==================================================

func set_voxel_data(
	voxel_data: VoxelData,
	source: Dictionary
) -> void:

	voxel_data.voxel_ids = source["ids"].duplicate()
	voxel_data.voxel_density = source["density"].duplicate()
	voxel_data.voxel_colors = source["colors"].duplicate()

	voxel_data.original_voxel_ids = voxel_data.voxel_ids.duplicate()
	voxel_data.original_voxel_density = voxel_data.voxel_density.duplicate()
	voxel_data.original_voxel_colors = voxel_data.voxel_colors.duplicate()

func destroy_voxel(
	voxel_data: VoxelData,
	index: int
) -> void:

	if not is_instance_valid(voxel_data):
		return
	if voxel_data.voxel_ids.get(index) == 0:
		return

	voxel_data.voxel_ids[index] = 0
	voxel_data.voxel_density[index] = 0
	voxel_data.voxel_colors[index] = 0

	#update_surface_cache(voxel_data)


func restore_voxel(
	voxel_data: VoxelData,
	index: int
) -> void:

	if not is_instance_valid(voxel_data):
		return
	if voxel_data.original_voxel_ids[index] == 0:
		return
	if voxel_data.voxel_ids[index] != 0:
		return

	voxel_data.voxel_ids[index] = voxel_data.original_voxel_ids[index]
	voxel_data.voxel_density[index] = voxel_data.original_voxel_density[index]
	voxel_data.voxel_colors[index] = voxel_data.original_voxel_colors[index]


func clear_voxel_data(voxel_data: VoxelData) -> void:
	if not is_instance_valid(voxel_data):
		return

	voxel_data.voxel_ids.clear()
	voxel_data.voxel_density.clear()
	voxel_data.voxel_colors.clear()

	voxel_data.original_voxel_ids.clear()
	voxel_data.original_voxel_density.clear()
	voxel_data.original_voxel_colors.clear()

	voxel_data.is_empty_air = true

	for key in voxel_data.sub_quadrant_has_surfaces:
		voxel_data.sub_quadrant_has_surfaces[key] = false

#
## ==================================================
## SURFACE CACHE
## ==================================================
#
#func update_surface_cache(voxel_data: VoxelData) -> void:
#
	#if not is_instance_valid(chunk):
		#return
#
	#chunk.is_empty_air = true
#
	#var q_keys := [
		#Vector3i(0,0,0),
		#Vector3i(1,0,0),
		#Vector3i(0,1,0),
		#Vector3i(1,1,0),
		#Vector3i(0,0,1),
		#Vector3i(1,0,1),
		#Vector3i(0,1,1),
		#Vector3i(1,1,1)
	#]
#
	#var q_found := [
		#false,false,false,false,
		#false,false,false,false
	#]
#
	#var quadrants_completed := 0
## TODO VOX-312
	# Replace direct voxel access with VoxelDataController API.
	#var half_size := int(chunk.chunk_size / 2)
	#var size := chunk.chunk_size
	#var size_sq := chunk.chunk_size_sq
#
	#for z in range(size):
#
		#var z_offset = z * size_sq
		#var q_z = 4 if z >= half_size else 0
#
		#for y in range(size):
#
			#var y_offset = y * size
			#var q_y = 2 if y >= half_size else 0
#
			#for x in range(size):
#
				#var index = x + y_offset + z_offset
## TODO VOX-312
	# Replace direct voxel access with VoxelDataController API.
				#if chunk.voxel_ids[index] == 0:
					#continue
## TODO VOX-312
	# Replace direct voxel access with VoxelDataController API.
				#chunk.is_empty_air = false
#
				#var q_x = 1 if x >= half_size else 0
				#var flat_index = q_x + q_y + q_z
#
				#if not q_found[flat_index]:
					#q_found[flat_index] = true
					#quadrants_completed += 1
#
				#if quadrants_completed == 8:
					#break
#
			#if quadrants_completed == 8:
				#break
#
		#if quadrants_completed == 8:
			#break
#
	#for i in range(8):
	# TODO VOX-312
	# Replace direct voxel access with VoxelDataController API.
		#chunk.sub_quadrant_has_surfaces[q_keys[i]] = q_found[i]


# ==================================================
# PRIVATE
# ==================================================
#
#func _get_index(
	#voxel_data: VoxelData,
	#local_coordinate: Vector3i
#) -> int:
#
	#return (
		#local_coordinate.x +
		#local_coordinate.y * voxel_data.chunk_size +
		#local_coordinate.z * voxel_data.chunk_size_sq
	#)
