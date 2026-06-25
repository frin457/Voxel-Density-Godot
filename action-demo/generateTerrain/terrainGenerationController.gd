#./generateTerrain/terrainGenerationController.gd
class_name TerrainGenerationController extends RefCounted

@export var terrainExponent = 1.5

func generate_data(
	chunk_position: Vector3,
	chunk_resolution: int,
	voxel_size: float,
	max_world_height: float,
	noise: Noise,
	color_array: Array[Color]
	#lod_level: int = 0
) -> Dictionary:
	var voxel_count = (
		chunk_resolution
		* chunk_resolution
		* chunk_resolution
	)

	var ids := PackedByteArray()
	var density := PackedByteArray()
	var colors := PackedColorArray()

	ids.resize(voxel_count)
	density.resize(voxel_count)
	colors.resize(voxel_count)

	colors.fill(Color(0,0,0,0))
	
	var index = func index(x: int, y: int, z: int) -> int:		
		return x + (y * chunk_resolution) +(z * chunk_resolution * chunk_resolution)
	
	# We loop exactly from 0 to chunk_resolution - 1 to align with the grid 
	for x in range(chunk_resolution):
		for z in range(chunk_resolution):

			var world_x = chunk_position.x + (float(x) * voxel_size)
			var world_z = chunk_position.z + (float(z) * voxel_size)

			var noise_value = (
				noise.get_noise_2d(world_x, world_z)
				+ 0.5 * noise.get_noise_2d(world_x * 2.0, world_z * 2.0)
				+ 0.25 * noise.get_noise_2d(world_x * 4.0, world_z * 4.0)
			)

			noise_value /= 1.75

			var normalized = (noise_value + 1.0) / 2
			var adjusted = pow(normalized, terrainExponent)
			var terrain_height = max_world_height * adjusted

			for y in range(chunk_resolution):
				var world_y = chunk_position.y + (float(y) * voxel_size)

				# Ensure voxels are generated right up to the line, allows overlap buffer 
				#if world_y is extremely close to the height boundary.
				if world_y > (terrain_height + (voxel_size * 0.1)):
					break

				var color_index = int(floor(world_y / voxel_size))
				if color_index < 0:
					color_index = abs(color_index)
				var i = index.call(x,y,z)
				#Assign properties
				ids[i] = 1
				density[i] = 255

				colors[i] = color_array[
					color_index % color_array.size()
				]
	return {
		"ids": ids,
		"density": density,
		"colors": colors
	}
