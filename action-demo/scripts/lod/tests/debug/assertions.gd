#./scripts/lod/tests/debug/assertions.gd
class_name VoxelAssertions
extends RefCounted

#######
#Layer 1 (Pool & Memory): Iterates through every active chunk in manager.chunks and verifies that chunk.is_inside_tree() returns true. 
	#It validates that every tracked chunk has a valid parent node (specifically, the ChunkManager) to ensure it hasn't been accidentally detached from the live scene. 
	#For the pool, it iterates through manager.inactive_chunks and verifies no null or freed references exist inside the array , 
	#validates that there are no duplicate chunk memory addresses sitting in the pool , 
	#and cross-references the pool against active systems to ensure pooled chunks are entirely isolated; 
	#they must not exist in manager.chunks, manager.dirty_queue, or manager.collision_queue.
#	
#Layer 2 (Scene Sync): First, it ensures every chunk tracked in manager.chunks actually exists in the Scene Tree. 
	#Next, it recursively scans the Scene Tree for all Chunk nodes and verifies that each node is actively tracked in either manager.chunks or manager.inactive_chunks. 
	#It fails if a node is found completely untracked (a memory leak ghost) or if a node is simultaneously marked as active and pooled.
#
#Layer 3 (Chunk State): Inspects a given chunk to ensure all background cooking processes have safely terminated
	#by verifying mesh_cooking == false and collision_cooking == false. 
	#It verifies that no pending update loops are trailing behind by ensuring mesh_dirty == false and collision_dirty == false , 
	#and confirms structural stability by checking that both subdivision_pending and merge_pending gates have successfully closed (== false).
#
#Layer 4 (Hierarchy): Checks a parent chunk's child_chunks array to ensure the exact same object reference isn't stored at multiple indices. 
	#It reads the chunk_coordinate and lod_level of every child and asserts that no two children 
	#are trying to claim the exact same spatial grid position and structural depth.
#
#Layer 5 (Queues): Inspects the size of the ChunkManager arrays and fails if dirty_queue.size() > 0 or collision_queue.size() > 0. 
	#Finally, it validates that the underlying thread task manager (job_queue) has fully flushed and holds no pending jobs.
#######

# ==============================================================================
# LAYER 1: MEMORY MANAGEMENT & OBJECT POOLING
# ==============================================================================

static func assert_no_orphans(manager: ChunkManager) -> bool:
	if not is_instance_valid(manager):
		push_error("VoxelAssertions: Given ChunkManager instance is invalid.")
		return false
	
	var passed := true
	for key in manager.chunks:
		var chunk = manager.chunks[key]
		if is_instance_valid(chunk):
			if not chunk.is_inside_tree():
				push_error("VoxelAssertions: Active tracked chunk at key '%s' is an orphan (not inside Scene Tree)." % str(key))
				passed = false
			if chunk.get_parent() != manager:
				push_error("VoxelAssertions: Tracked chunk '%s' is not a direct child of the ChunkManager." % str(key))
				passed = false
	return passed

static func assert_pool_integrity(manager: ChunkManager) -> bool:
	if not is_instance_valid(manager):
		push_error("VoxelAssertions: Given ChunkManager instance is invalid.")
		return false
		
	var passed := true
	var unique_instances := {}
	
	for i in range(manager.inactive_chunks.size()):
		var chunk = manager.inactive_chunks[i]
		
		if not is_instance_valid(chunk):
			push_error("VoxelAssertions: Pool breakdown! Freed memory reference inside inactive_chunks at index %d." % i)
			passed = false
			continue
			
		if unique_instances.has(chunk):
			push_error("VoxelAssertions: Pool breakdown! Duplicate chunk object reference found in pool at index %d." % i)
			passed = false
		unique_instances[chunk] = i
		
		if chunk.get_parent() != manager:
			push_error("VoxelAssertions: Pool contamination! Inactive chunk at index %d lost its parent relationship." % i)
			passed = false
			
		for key in manager.chunks:
			if manager.chunks[key] == chunk:
				push_error("VoxelAssertions: Pool contamination! Pooled chunk at index %d is still present in active chunks dictionary." % i)
				passed = false
				break
				
		if manager.dirty_queue.has(chunk) or manager.collision_queue.has(chunk):
			push_error("VoxelAssertions: Queue contamination! Pooled chunk is lingering in active execution queues.")
			passed = false
			
	return passed

# ==============================================================================
# LAYER 2: ENGINE DATA SYNCHRONIZATION
# ==============================================================================

static func assert_dictionary_matches_scene(manager: ChunkManager) -> bool:
	if not is_instance_valid(manager):
		push_error("VoxelAssertions: Given ChunkManager instance is invalid.")
		return false
	
	var passed := true
	var live_scene_chunks: Array[Node] = []
	_find_chunks_recursive(manager, live_scene_chunks)
	
	for scene_chunk in live_scene_chunks:
		var is_tracked_active = false
		for key in manager.chunks:
			if manager.chunks[key] == scene_chunk:
				is_tracked_active = true
				break
				
		var is_tracked_pooled = manager.inactive_chunks.has(scene_chunk)
		
		if not is_tracked_active and not is_tracked_pooled:
			push_error("VoxelAssertions: Scene graph sync failure! Chunk node '%s' is leaking (neither active nor pooled)." % scene_chunk.name)
			passed = false
		elif is_tracked_active and is_tracked_pooled:
			push_error("VoxelAssertions: State corruption! Chunk node '%s' is simultaneously marked active AND pooled." % scene_chunk.name)
			passed = false
			
	return passed

# ==============================================================================
# LAYER 3: CHUNK STATE & MESHING PIPELINE
# ==============================================================================

static func assert_chunk_clean(chunk: Chunk) -> bool:
	if not is_instance_valid(chunk):
		push_error("VoxelAssertions: Given Chunk instance is invalid.")
		return false
		
	var passed := true
	var chunk_id = "Coord: %s" % str(chunk.get("chunk_coordinate"))
	
	var flags = {
		"mesh_cooking": chunk.get("mesh_cooking"),
		"collision_cooking": chunk.get("collision_cooking"),
		"mesh_dirty": chunk.get("mesh_dirty"),
		"collision_dirty": chunk.get("collision_dirty"),
		"subdivision_pending": chunk.get("subdivision_pending"),
		"merge_pending": chunk.get("merge_pending")
	}
	
	for flag_name in flags:
		if flags[flag_name] == true:
			push_error("VoxelAssertions: Clean-state failure! Chunk [%s] has trailing flag: %s == true." % [chunk_id, flag_name])
			passed = false
			
	return passed

# ==============================================================================
# LAYER 4: OCTREE & SUBDIVISION HIERARCHY
# ==============================================================================

static func assert_no_duplicate_children(parent_chunk: Chunk) -> bool:
	if not is_instance_valid(parent_chunk):
		push_error("VoxelAssertions: Given parent_chunk instance is invalid.")
		return false
		
	var passed := true
	if "child_chunks" in parent_chunk:
		var children = parent_chunk.get("child_chunks") as Array
		var unique_child_references := {}
		var unique_coordinates_set := {}
		
		for i in range(children.size()):
			var child = children[i]
			if is_instance_valid(child):
				if unique_child_references.has(child):
					push_error("VoxelAssertions: Hierarchical duplication! Same child checked twice at index %d." % i)
					passed = false
				unique_child_references[child] = i
				
				var coord_key = "%s_LOD%d" % [str(child.get("chunk_coordinate")), child.get("lod_level")]
				if unique_coordinates_set.has(coord_key):
					push_error("VoxelAssertions: Spatial overlap! Multiple children claim space: %s" % coord_key)
					passed = false
				unique_coordinates_set[coord_key] = i
				
	return passed

# ==============================================================================
# LAYER 5: THREAD SCHEDULING & EXECUTION QUEUES
# ==============================================================================

static func assert_queue_empty(manager: ChunkManager) -> bool:
	if not is_instance_valid(manager):
		push_error("VoxelAssertions: Given ChunkManager instance is invalid.")
		return false
		
	var passed := true
	if not manager.dirty_queue.is_empty():
		push_error("VoxelAssertions: Settling error! dirty_queue not empty. Count: %d" % manager.dirty_queue.size())
		passed = false
	if not manager.collision_queue.is_empty():
		push_error("VoxelAssertions: Settling error! collision_queue not empty. Count: %d" % manager.collision_queue.size())
		passed = false
		
	if manager.job_queue and not manager.job_queue.is_empty():
		push_error("VoxelAssertions: Thread-pool scheduling failure! manager.job_queue still has queued async jobs pending execution.")
		passed = false
		
	return passed

# ==============================================================================
# PRIVATE INTERNAL UTILITIES
# ==============================================================================

static func _find_chunks_recursive(current_node: Node, results: Array[Node]) -> void:
	for child in current_node.get_children():
		if child.has_method("mark_dirty") or "chunk_coordinate" in child:
			results.append(child)
		_find_chunks_recursive(child, results)
