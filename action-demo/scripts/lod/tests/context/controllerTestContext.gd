#./scripts/lod/tests/context/ControllerTestContext.gd

class_name ControllerTestContext extends RefCounted


# ==================================================
# DOMAIN MODELS
# ==================================================

var voxel_data := VoxelChunkData.new()
var voxel_grid := VoxelGridInfo.new()

# ==================================================
# SNAPSHOTS
# ==================================================

var mesh_snapshot := MeshSnapshot.new()
var collision_snapshot := CollisionSnapshot.new()

# ==================================================
# CONTROLLERS
# ==================================================

var voxel_data_controller := VoxelDataController.new()
var mesh_snapshot_controller := MeshSnapshotFactory.new()
var collision_snapshot_controller := CollisionSnapshotController.new()

var mesh_controller := ChunkMeshController.new()
var collision_controller := CollisionSnapshotFactory.new()

# ==================================================
# SCENE OBJECTS
# ==================================================

var chunk : Chunk

# ==================================================
# TEST INITIALIZATION
# ==================================================

func initialize() -> void:

	chunk = Chunk.new()

	chunk.meshInstance = MeshInstance3D.new()
	chunk.collisionShape = CollisionShape3D.new()

	voxel_grid.chunk_size = 4
	voxel_grid.chunk_size_sq = 16
	voxel_grid.voxel_size = 1.0


func cleanup() -> void:

	if is_instance_valid(chunk):
		chunk.queue_free()

	chunk = null


func create_solid_chunk() -> void:
	var count = voxel_grid.chunk_size * voxel_grid.chunk_size_sq
	for i in count:

		voxel_data.voxel_ids.append(1)
		voxel_data.voxel_density.append(255)
		voxel_data.voxel_colors.append(Color.WHITE)
