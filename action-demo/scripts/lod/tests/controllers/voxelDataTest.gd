#./scripts/lod/tests/controllers/voxelDataTest.gd
class_name VoxelDataControllerTest extends BaseVoxelTest

var controller: VoxelDataController
var data: VoxelData

var voxel_data := {}

func get_name() -> String:
	return "VoxelDataController Contract"


func setup() -> void:

	controller = VoxelDataController.new()
	data = VoxelData.new()


	# Required cache members

	var count := 64

	voxel_data = {
		"ids": PackedByteArray(),
		"density": PackedByteArray(),
		"colors": PackedColorArray()
	}

	for i in count:
		voxel_data.ids.append(0)
		voxel_data.density.append(0)
		voxel_data.colors.append(Color.BLACK)

	# one solid voxel
	voxel_data.ids[0] = 1
	voxel_data.density[0] = 255
	voxel_data.colors[0] = Color.RED

	data.original_voxel_ids.append(voxel_data.ids[0])
	data.original_voxel_density.append(voxel_data.density[0])
	data.original_voxel_colors.append(voxel_data.colors[0])

func run() -> void:
	pass


func validate() -> bool:

	var passed := true

	passed = _test_set_voxel_data() and passed
	passed = _test_destroy_voxel() and passed
	passed = _test_restore_voxel() and passed
	passed = _test_clear_voxel_data() and passed

	return passed


func cleanup() -> void:
#	voxels are RefCount
	controller = null
	data = null


# =====================================================
# CONTRACT 1 : set_voxel_data
# =====================================================

func _test_set_voxel_data() -> bool:

	controller.set_voxel_data(data, voxel_data)

	var passed := true

	passed = assert_equal(
		1,
		voxel_data.ids[0],
		"Voxel id should copy."
	) and passed

	passed = assert_equal(
		255,
		voxel_data.density[0],
		"Density should copy."
	) and passed

	passed = assert_equal(
		Color.RED,
		voxel_data.colors[0],
		"Color should copy."
	) and passed

	passed = assert_equal(
		voxel_data.ids[0],
		data.original_voxel_ids.get(0),
		"Original ids should be duplicated."
	) and passed

	#passed = assert_true(
		#data.mesh_dirty,
		#"Chunk should become mesh dirty."
	#) and passed
#
	#passed = assert_true(
		#data.collision_dirty,
		#"Chunk should become collision dirty."
	#) and passed

	return passed


# =====================================================
# CONTRACT 2 : destroy_voxel
# =====================================================

func _test_destroy_voxel() -> bool:

	controller.destroy_voxel(data, 0)

	var passed := true

	passed = assert_equal(
		0,
		data.voxel_ids.get(0),
		"Voxel should be destroyed."
	) and passed

	passed = assert_equal(
		0,
		data.voxel_density.get(0),
		"Density should clear."
	) and passed

	passed = assert_equal(
		Color(0,0,0,0),
		data.voxel_colors.get(0),
		"Color should clear."
	) and passed

	return passed


# =====================================================
# CONTRACT 3 : restore_voxel
# =====================================================

func _test_restore_voxel() -> bool:

	controller.restore_voxel(data, 0)

	var passed := true

	passed = assert_equal(
		1,
		data.voxel_ids[0],
		"Voxel should restore."
	) and passed

	passed = assert_equal(
		255,
		data.voxel_density[0],
		"Density should restore."
	) and passed

	passed = assert_equal(
		Color.RED,
		data.voxel_colors[0],
		"Color should restore."
	) and passed

	return passed

# =====================================================
# CONTRACT 4 clear_voxel_data
# =====================================================

func _test_clear_voxel_data() -> bool:

	controller.clear_voxel_data(data)

	var passed := true

	passed = assert_true(
		data.voxel_ids.is_empty(),
		"Ids should clear."
	) and passed

	passed = assert_true(
		data.voxel_density.is_empty(),
		"Density should clear."
	) and passed

	passed = assert_true(
		data.voxel_colors.is_empty(),
		"Colors should clear."
	) and passed

	return passed
