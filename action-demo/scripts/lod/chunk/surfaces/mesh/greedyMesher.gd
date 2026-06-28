#./scripts/lod/engine/meshers/greedy_voxel_mesher.gd
class_name GreedyMesher extends BaseMesher

const FACE_NORMALS = [
	Vector3(-1, 0, 0), # d=0, b=0 (Left)
	Vector3(1, 0, 0),  # d=0, b=1 (Right)
	Vector3(0, -1, 0), # d=1, b=0 (Bottom)
	Vector3(0, 1, 0),  # d=1, b=1 (Top)
	Vector3(0, 0, -1), # d=2, b=0 (Back)
	Vector3(0, 0, 1)   # d=2, b=1 (Front)
]

func generate_mesh_data(data: MeshSnapshot) -> Array:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	var chunk_size = data.chunk_size
	var chunk_size_sq = data.chunk_size_sq

	var voxel_ids = data.voxel_ids
	var voxel_colors = data.voxel_colors
	var voxel_scale = data.voxel_scale
	
	# Sweep over both back/front passes (b) across all 3 dimensions (d)
	for b in range(2):
		for d in range(3):
			var u = (d + 1) % 3
			var v = (d + 2) % 3

			var pos := Vector3i.ZERO
			var q := Vector3i.ZERO
			q[d] = 1

			# Allocate a 1D slice mask for the 2D sweep plane
			var mask: Array[int] = []
			mask.resize(chunk_size_sq)

			pos[d] = -1
			while pos[d] < chunk_size:
				#POPULATE THE MASK FOR THIS SLICE
				var mask_index = 0
				pos[v] = 0
				while pos[v] < chunk_size:
					pos[u] = 0
					while pos[u] < chunk_size:
						var current_id = 0
						var compare_id = 0
					
						if pos[d] < chunk_size - 1:
							var nx = pos.x + q.x
							var ny = pos.y + q.y
							var nz = pos.z + q.z

							var compare_index = nx + (ny * chunk_size) + (nz * chunk_size_sq)
							if compare_index < 0 or compare_index >= voxel_ids.size():
								mask[mask_index] = 0
								mask_index += 1
								pos[u] += 1
								continue
							
							if pos[d] >= 0:
								current_id = voxel_ids[(
									pos.x + 
									pos.y * chunk_size + 
									pos.z * chunk_size_sq
								
								)]
							compare_id = voxel_ids[compare_index]

						# Cull internal face matches; assign voxel ID to mask, if exposed
						if b == 0:
							if current_id == 0 and compare_id != 0:
								mask[mask_index] = compare_id
							else:
								mask[mask_index] = 0
						else:
							if current_id != 0 and compare_id == 0:
								mask[mask_index] = current_id
							else:
								mask[mask_index] = 0

						mask_index += 1
						pos[u] += 1
					pos[v] += 1

				pos[d] += 1
				mask_index = 0

				# FORM QUAD MESHES
				for j in range(chunk_size):
					var i = 0
					while i < chunk_size:
						var voxel_id = mask[mask_index]
						if voxel_id == 0:
							mask_index += 1
							i += 1
							continue

						# Compute width of identical voxels along the U axis
						var width = 1
						while i + width < chunk_size and voxel_id == mask[mask_index + width]:
							width += 1

						# Compute height of identical row combinations along the V axis
						var height = 1
						var done = false
						while j + height < chunk_size:
							for k in range(width):
								if voxel_id != mask[mask_index + k + (height * chunk_size)]:
									done = true
									break
							if done:
								break
							height += 1

						# Set coordinates relative to our current loop state
						var width_vec := Vector3.ZERO
						var height_vec := Vector3.ZERO
						width_vec[u] = width
						height_vec[v] = height

						var local_pos := Vector3(pos)
						local_pos[u] = i
						local_pos[v] = j # In the slice, j represents the vertical coordinate axis map

						# Sample color from an active voxel within this quad zone
						var sample_x = int(local_pos.x)
						var sample_y = int(local_pos.y)
						var sample_z = int(local_pos.z)

						# If b == 1 (Front/Right/Top), the face belongs to the voxel *behind* the cursor.
						# If b == 0 (Back/Left/Bottom), the face belongs to the voxel *ahead* of the cursor.
						if b == 1:
							if d == 0: sample_x -= 1
							if d == 1: sample_y -= 1
							if d == 2: sample_z -= 1
						else:
							# Retained from original code to capture inward offsets properly
							if d == 0: sample_x = sample_x
							if d == 1: sample_y = sample_y
							if d == 2: sample_z = sample_z
						
						sample_x = clampi(sample_x, 0, chunk_size - 1)
						sample_y = clampi(sample_y, 0, chunk_size - 1)
						sample_z = clampi(sample_z, 0, chunk_size - 1)
						
						var sample_index = (
								sample_x +
								(sample_y * chunk_size) +
								(sample_z * chunk_size_sq)
							)
						var face_color = voxel_colors[sample_index]
						var normal_vector = FACE_NORMALS[(d * 2) + b]

						# APPEND QUAD to data arrays
						var start_v_idx = vertices.size()

						# Quad corners scaled out to the world sizing mesh bounds
						var v0 = local_pos * voxel_scale
						var v1 = (local_pos + width_vec) * voxel_scale
						var v2 = (local_pos + width_vec + height_vec) * voxel_scale
						var v3 = (local_pos + height_vec) * voxel_scale

						vertices.append(v0)
						vertices.append(v1)
						vertices.append(v2)
						vertices.append(v3)

						for m in range(4):
							normals.append(normal_vector)
							colors.append(face_color)

						# Clockwise face winding verification for Godot front-face rendering
						if b == 1:
							# Front/Right/Top
							indices.append(start_v_idx + 0)
							indices.append(start_v_idx + 2)
							indices.append(start_v_idx + 1)
							indices.append(start_v_idx + 0)
							indices.append(start_v_idx + 3)
							indices.append(start_v_idx + 2)
						else:
							# Back/Left/Bottom
							indices.append(start_v_idx + 0)
							indices.append(start_v_idx + 1)
							indices.append(start_v_idx + 2)
							indices.append(start_v_idx + 0)
							indices.append(start_v_idx + 2)
							indices.append(start_v_idx + 3)

						# Zero out grouped areas from the slice mask so they aren't meshed twice
						for l in range(height):
							for k in range(width):
								mask[mask_index + k + (l * chunk_size)] = 0

						i += width
						mask_index += width

	var surface_arrays := []
	surface_arrays.resize(Mesh.ARRAY_MAX)
	if vertices.size() > 0:
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_INDEX] = indices
		surface_arrays[Mesh.ARRAY_NORMAL] = normals
		surface_arrays[Mesh.ARRAY_COLOR] = colors

	return surface_arrays
