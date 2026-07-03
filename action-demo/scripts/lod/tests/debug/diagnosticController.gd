#./scripts/lod/debug/diagnosticController.gd.gd
class_name DiagnosticsController extends RefCounted

var context: EngineContext

func _init(_context: EngineContext) -> void:
	context = _context

## Compiles and returns a structural snapshot of current live engine parameters
func snapshot() -> Dictionary:
	var pending_subdivisions := 0
	var pending_merges := 0
	var mesh_cooking := 0
	var collision_cooking := 0
	
	# Aggregate live inner-chunk states dynamically to prevent mixing tracking logic into Chunk code
	if context and context.registry.values():
		for chunk in context.registry.values():
			if is_instance_valid(chunk):
				if chunk.subdivision_pending:
					pending_subdivisions += 1
				if chunk.merge_pending:
					pending_merges += 1
				if chunk.mesh_cooking:
					mesh_cooking += 1
				if chunk.collision_cooking:
					collision_cooking += 1

	return {
		"Chunks": context.registry.size() if context else 0,
		"Pool": context.pool.size() if context else 0,
		"Worker Threads": context.active_thread_tasks.size() if context else 0,
		"Dirty Queue": context.dirty_queue.size() if context else 0,
		"Collision Queue": context.collision_queue.size() if context else 0,
		"Pending Subdivisions": pending_subdivisions,
		"Pending Merges": pending_merges,
		"Mesh Cooking": mesh_cooking,
		"Collision Cooking": collision_cooking
	}

## Centralized print utility for generic engine logs
func log_message(msg: String) -> void:
	print(msg)

## Centralized print utility for late-arrival chunk aborts
func log_late_arrival(coord: Vector3i) -> void:
	print("SubdivisionController: Aborting late-arrival child chunk at ", coord)

## Centralized print utility for stale thread corrections
func log_stale_thread(coord: Vector3i, job_lod: int, current_authorized_lod: int) -> void:
	print("Voxel Engine Thread Guard: Discarded STALE ghost thread at ", coord, " (Job LOD: ", job_lod, " | Current Live Authorized LOD: ", current_authorized_lod, ")")

## Formats and prints the snapshot to replace the previous inline manager prints
func print_formatted_snapshot() -> void:
	var snap = snapshot()
	print(
		"Active: ", snap["Chunks"], 
		" | Pool: ", snap["Pool"], 
		" | Dirty: ", snap["Dirty Queue"], 
		" | Collision: ", snap["Collision Queue"], 
		" | Active Threads: ", snap["Worker Threads"]
	)
