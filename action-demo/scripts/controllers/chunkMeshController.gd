# ./scripts/controllers/chunkMeshController.gd
class_name ChunkMeshController extends RefCounted

# Tracks chunks currently undergoing background meshing tasks to prevent duplicate threads
var active_mesh_tasks := {}

## Entry point called by ChunkManager
func rebuild(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		return
		
	# If this chunk is already being meshed on a thread, do not spin up another one
	if active_mesh_tasks.has(chunk):
		return

	# CRITICAL FOR THREAD SAFETY: Dictionaries are not thread-safe in Godot 4 if modified
	# during iteration. We duplicate the live voxel dictionary instantly on the main thread 
	# to act as an immutable snapshot for our worker thread.
	var voxel_snapshot := chunk.voxels.duplicate()
	var chunk_size := chunk.chunk_size
	var voxel_size := chunk.voxel_size
	var mesh_instance := chunk.meshInstance
	var material := chunk.mat

	# Dispatch surface extraction to a background thread
	var task_id = WorkerThreadPool.add_task(
		_async_extract_surface.bind(chunk, voxel_snapshot, chunk_size, voxel_size, mesh_instance, material),
		true,
		"MeshExtract_%X" % chunk.get_instance_id()
	)
	active_mesh_tasks[chunk] = task_id


## Executed entirely on a BACKGROUND WORKER THREAD
func _async_extract_surface(
	chunk: Chunk, 
	voxels: Dictionary, 
	size: int, 
	scale: float, 
	mesh_instance: MeshInstance3D, 
	material: Material
) -> void:
	
	# -------------------------------------------------------------
	# PLACE YOUR SURFACE EXTRACTION LOOPS HERE (Marching Cubes, Greedy Meshing, etc.)
	# -------------------------------------------------------------
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	# --- Example Loop Structure Placeholder ---
	# For demonstration purposes. Replace this loop with your actual voxel iteration 
	# and face building logic using the 'voxels', 'size', and 'scale' passed parameters.
	for pos in voxels:
		var voxel = voxels[pos]
		# Build your faces, vertices, indices, normals, and colors here...
		pass
	# -------------------------------------------------------------

	# Package arrays for transmission
	var surface_arrays := []
	surface_arrays.resize(Mesh.ARRAY_MAX)
	
	if vertices.size() > 0:
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_INDEX] = indices
		surface_arrays[Mesh.ARRAY_NORMAL] = normals
		surface_arrays[Mesh.ARRAY_COLOR] = colors

	# Safely hand off the extracted vertex arrays back to the main thread for rendering
	_main_thread_commit_mesh.call_deferred(chunk, surface_arrays, mesh_instance, material)


## Executed back on the MAIN THREAD (Scene-tree safe operations)
func _main_thread_commit_mesh(
	chunk: Chunk, 
	surface_arrays: Array, 
	mesh_instance: MeshInstance3D, 
	material: Material
) -> void:
	
	# Clean up tracking immediately
	active_mesh_tasks.erase(chunk)

	# Safety check in case the chunk was freed/cleared while threading was active
	if not is_instance_valid(chunk) or not is_instance_valid(mesh_instance):
		return

	var array_mesh = mesh_instance.mesh as ArrayMesh
	if not array_mesh:
		array_mesh = ArrayMesh.new()
		mesh_instance.mesh = array_mesh

	# Clear previous geometry surfaces
	while array_mesh.get_surface_count() > 0:
		array_mesh.remove_surface(0)

	# Commit new geometry if valid surfaces were built
	if surface_arrays[Mesh.ARRAY_VERTEX] != null and surface_arrays[Mesh.ARRAY_VERTEX].size() > 0:
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		mesh_instance.set_surface_override_material(0, material)

	# Tell the chunk its mesh is clean.
	chunk.mesh_dirty = false
	
	# Evaluate if both rendering and physics are ready to release the block
	_evaluate_chunk_readiness(chunk)


func _evaluate_chunk_readiness(chunk: Chunk) -> void:
	# Only mark the chunk as fully cleared once BOTH physics and mesh generation threads finish
	if not chunk.mesh_dirty and not chunk.collision_dirty:
		chunk.clear_dirty()
