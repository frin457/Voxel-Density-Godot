# ./scripts/controllers/chunkMeshController.gd
class_name ChunkMeshController extends RefCounted

# Tracks chunks currently undergoing background meshing tasks
var active_mesh_tasks := {}
# Tracks the structural modification version of a chunk to discard stale threads
var chunk_generations := {}

## Entry point called by ChunkManager
func rebuild(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		return
		
	# Prune any deleted chunk references from tracking to prevent memory bloat
	_prune_invalid_references()

	# Increment the generation ID for this specific chunk.
	# Any background thread currently running for this chunk will now carry an outdated ID
	# and will be safely ignored when it returns.
	var current_generation = chunk_generations.get(chunk, 0) + 1
	chunk_generations[chunk] = current_generation

	# Snapshot live properties instantly on the main thread
	var voxel_snapshot := chunk.voxels.duplicate()
	var chunk_size := chunk.chunk_size
	var voxel_size := chunk.voxel_size
	var mesh_instance := chunk.meshInstance
	var material := chunk.mat

	
	if active_mesh_tasks.has(chunk):
		var existing_task = active_mesh_tasks[chunk]

		if not WorkerThreadPool.is_task_completed(existing_task):
			return
			
	var task_id = WorkerThreadPool.add_task(
		_async_extract_surface.bind(chunk, voxel_snapshot, chunk_size, voxel_size, mesh_instance, material, current_generation),
		true,
		"MeshExtract_%X" % chunk.get_instance_id()
	)
	
	active_mesh_tasks[chunk] = task_id


## Executed entirely on a BACKGROUND WORKER THREAD
func _async_extract_surface(
	chunk: Object, 
	voxels: Dictionary, 
	size: int, 
	scale: float, 
	mesh_instance: Object, 
	material: Material,
	generation: int
) -> void:
	
	# -------------------------------------------------------------
	# SURFACE EXTRACTION LOOPS (Marching Cubes, Greedy Meshing, etc.)
	# -------------------------------------------------------------
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	for pos in voxels:
		var voxel = voxels[pos]
		# Build geometry components here...
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

	# Safely hand off arrays and our generation ID back to the main thread
	# Note: We pass standard Objects down to bypass thread-boundary type strictness drops
	_main_thread_commit_mesh.call_deferred(chunk, surface_arrays, mesh_instance, material, generation)


## Executed back on the MAIN THREAD
func _main_thread_commit_mesh(
	chunk_obj: Object, 
	surface_arrays: Array, 
	mesh_instance_obj: Object, 
	material: Material,
	generation: int
) -> void:
	
	if not is_instance_valid(chunk_obj): return
	var actual_chunk = chunk_obj as Chunk
	
	# --- THREAD GENERATION GUARD ---
	# If a newer request was made while this thread was processing, this data is stale.
	# Return early without touching the mesh or clearing flags.
	if generation != chunk_generations.get(actual_chunk, -1):
		active_mesh_tasks.erase(actual_chunk)
		return

	if not is_instance_valid(mesh_instance_obj): return
	var actual_mesh_instance = mesh_instance_obj as MeshInstance3D

	# Create a NEW mesh resource instead of clearing the old one.
	# This keeps the old mesh visible until the new one is fully baked.
	var new_mesh = ArrayMesh.new()
	
	if surface_arrays[Mesh.ARRAY_VERTEX] != null and surface_arrays[Mesh.ARRAY_VERTEX].size() > 0:
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		actual_mesh_instance.set_surface_override_material(0, material)

	# Swap the reference instantly. This is a single pointer change.
	# No more flickering from removing/adding surfaces!
	actual_mesh_instance.mesh = new_mesh
	active_mesh_tasks.erase(actual_chunk)
	actual_chunk.mesh_dirty = false

	# TODO: Temporary until CollisionController exists.
	actual_chunk.collision_dirty = false
	_evaluate_chunk_readiness(actual_chunk)


func _evaluate_chunk_readiness(chunk: Chunk) -> void:
	if not is_instance_valid(chunk):
		return

	chunk.evaluate_ready()

	var manager = chunk.get_parent()
	if manager and manager.subdivision_controller:
		manager.subdivision_controller.notify_chunk_mesh_ready(chunk)


func _prune_invalid_references() -> void:
	for c in active_mesh_tasks.keys():
		if not is_instance_valid(c):
			active_mesh_tasks.erase(c)
			chunk_generations.erase(c)
