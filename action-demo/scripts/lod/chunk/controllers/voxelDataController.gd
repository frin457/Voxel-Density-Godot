# ./scripts/lod/chunk/controllers/voxelDataController.gd
class_name VoxelDataController extends RefCounted
# ==================================================
# PUBLIC API
# ==================================================
func set_voxel_data(
	target: VoxelChunkData,
	source: VoxelChunkData
) -> void:

	if target == null or source == null:
		return

	target.voxel_ids = source.voxel_ids.duplicate()
	target.voxel_density = source.voxel_density.duplicate()
	target.voxel_colors = source.voxel_colors.duplicate()

	target.original_voxel_ids = source.voxel_ids.duplicate()
	target.original_voxel_density = source.voxel_density.duplicate()
	target.original_voxel_colors = source.voxel_colors.duplicate()

	target.is_empty_air = source.is_empty_air

	target.sub_quadrant_has_surfaces.clear()

	for key in source.sub_quadrant_has_surfaces:
		target.sub_quadrant_has_surfaces[key] = source.sub_quadrant_has_surfaces[key]
