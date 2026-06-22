#./scripts/controllers/terrainGenerationController.gd
class_name TerrainGenerationController
extends RefCounted


func generate_data(
	chunk_position: Vector3,
	chunk_size: int,
	max_height: int,
	noise: Noise,
	color_array: Array[Color]
) -> Dictionary:

	var voxels = {}

	for x in range(chunk_size):

		for z in range(chunk_size):

			var global_pos = Vector2(
				x + chunk_position.x,
				z + chunk_position.z
			)

			var noise_value = (
				noise.get_noise_2d(global_pos.x, global_pos.y)
				+ 0.5 * noise.get_noise_2d(
					global_pos.x * 2,
					global_pos.y * 2
				)
				+ 0.25 * noise.get_noise_2d(
					global_pos.x * 4,
					global_pos.y * 4
				)
			)

			noise_value /= 1.75

			var normalized = (noise_value + 1.0) / 2.0

			var adjusted = pow(normalized, 2.1)

			var height = max_height * adjusted

			if height < chunk_position.y:
				continue

			var local_height = height - chunk_position.y

			for y in range(min(local_height, chunk_size)):

				voxels[
					Vector3i(x, y, z)
				] = Voxel.new(
					color_array[
						y % color_array.size()
					]
				)

	return voxels
