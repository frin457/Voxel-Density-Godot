#./generateTerrain/terrainGeneration.gd
class_name TerrainGenerator extends RefCounted

@export var terrain_exponent = 1.5

func generate(
	grid: VoxelGridInfo,
	noise: Noise,
	color_palette: Array[Color]
) -> VoxelChunkData:
	
	var voxel_data := VoxelChunkData.new()
	if color_palette.is_empty():
		push_error("Color palette is empty!")
		return voxel_data
	
	var voxel_count := (
		grid.chunk_size *
		grid.chunk_size *
		grid.chunk_size
	)
	
	voxel_data.voxel_ids.resize(voxel_count)
	voxel_data.voxel_density.resize(voxel_count)
	voxel_data.voxel_colors.resize(voxel_count)
	voxel_data.voxel_colors.fill(Color.TRANSPARENT)
	var color_count := color_palette.size()
	for x in range(grid.chunk_size):
		var world_x = grid.world_position.x + float(x) * grid.voxel_size
		for z in range(grid.chunk_size):
			var world_z = grid.world_position.z + float(z) * grid.voxel_size
			
			var noise_value := (
				noise.get_noise_2d(world_x, world_z)
				+ 0.5 * noise.get_noise_2d(world_x * 2.0, world_z * 2.0)
				+ 0.25 * noise.get_noise_2d(world_x * 4.0, world_z * 4.0)
			)

			noise_value /= 1.75
			var normalized := (noise_value + 1.0) / 2.0
			var adjusted := pow(normalized, terrain_exponent)
			var terrain_height := grid.max_world_height * adjusted

			for y in range(grid.max_world_height):
				
				var world_y = grid.world_position.y + float(y) * grid.voxel_size
				# Small overlap prevents gaps between chunks
				if world_y > terrain_height + (grid.voxel_size * 0.1):
					break

				var color_index : int = abs(int(floor(world_y / grid.voxel_size)))
				var index := x + (y * grid.chunk_size) + (z * grid.chunk_size * grid.chunk_size)
				voxel_data.voxel_ids[index] = 1
				voxel_data.voxel_density[index] = 255
				voxel_data.voxel_colors[index] = color_palette[color_index % color_count]
	return voxel_data
