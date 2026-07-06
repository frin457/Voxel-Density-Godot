class_name MeshSnapshotFactory extends RefCounted

func create_snapshot(
	voxel_data: VoxelChunkData,
	grid: VoxelGridInfo
) -> MeshSnapshot:
	var snapshot := MeshSnapshot.new()

	snapshot.voxel_ids = voxel_data.voxel_ids.duplicate()
	snapshot.voxel_colors = voxel_data.voxel_colors.duplicate()

	snapshot.chunk_size = grid.chunk_size
	snapshot.chunk_size_sq = grid.chunk_size_sq
	snapshot.voxel_size = grid.voxel_size

	return snapshot
