#./scripts/controllers/terrainGenerationController.gd
class_name TerrainGenerationController extends RefCounted

@export var terrainExponent = 1.5

func generate_data(
	chunk_position: Vector3,
	chunk_resolution: int,
	voxel_size: float,
	max_world_height: float,
	noise: Noise,
	color_array: Array[Color]
) -> Dictionary:

	var voxels := {}

	# Physical dimensions occupied by this chunk.
	var chunk_world_size = chunk_resolution * voxel_size

	for x in range(chunk_resolution):

		for z in range(chunk_resolution):

			# Sample noise using WORLD coordinates.
			var world_x = chunk_position.x + (x * voxel_size)
			var world_z = chunk_position.z + (z * voxel_size)

			var noise_value = (
				noise.get_noise_2d(world_x, world_z)
				+ 0.5 * noise.get_noise_2d(
					world_x * 2.0,
					world_z * 2.0
				)
				+ 0.25 * noise.get_noise_2d(
					world_x * 4.0,
					world_z * 4.0
				)
			)

			noise_value /= 1.75

			var normalized = (noise_value + 1.0) / 2
			var adjusted = pow(normalized, terrainExponent)

			# Height now exists in WORLD SPACE.
			var terrain_height = max_world_height * adjusted

			for y in range(chunk_resolution):

				var world_y = (
					chunk_position.y
					+ (y * voxel_size)
				)

				# We've reached terrain surface.
				if world_y > terrain_height:
					break

				voxels[
					Vector3i(x, y, z)
				] = Voxel.new(
					color_array[
						y % color_array.size()
					]
				)

	return voxels
