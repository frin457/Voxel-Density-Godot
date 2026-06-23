#./scripts/chunk/chunkJobQueue.gd
class_name ChunkJobQueue extends RefCounted

var queue: Array[ChunkJob] = []
var pending_add: Array[ChunkJob] = []

# Thread protection lock guard
var lock: Mutex = Mutex.new()

# ----------------------------
# THREAD-SAFE PUSH
# ----------------------------
func push(job: ChunkJob) -> void:
	lock.lock()
	pending_add.append(job)
	lock.unlock()

# ----------------------------
# FLUSH THREAD BUFFER
# ----------------------------
func flush() -> void:
	lock.lock()
	if pending_add.is_empty():
		lock.unlock()
		return
		
	for j in pending_add:
		queue.append(j)

	pending_add.clear()
	lock.unlock()

	# Sort operates solely on the main thread queue array
	# Sorted ascending by wave index to guarantee linear visual propagation
	queue.sort_custom(func(a, b):
		return a.sort_index < b.sort_index
	)

# ----------------------------
# POP HIGHEST PRIORITY
# ----------------------------
func pop() -> ChunkJob:
	# Single element pop array operations should remain guarded
	lock.lock()
	if queue.is_empty():
		lock.unlock()
		return null
	var job = queue.pop_front()
	lock.unlock()
	return job

func is_empty() -> bool:
	lock.lock()
	var empty = queue.is_empty()
	lock.unlock()
	return empty
