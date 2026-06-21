class_name ChunkJobQueue
extends RefCounted

var queue: Array[ChunkJob] = []
var pending_add: Array[ChunkJob] = []


# ----------------------------
# THREAD-SAFE PUSH
# ----------------------------
func push(job: ChunkJob) -> void:
	pending_add.append(job)


# ----------------------------
# FLUSH THREAD BUFFER
# ----------------------------
func flush() -> void:

	for j in pending_add:
		queue.append(j)

	pending_add.clear()

	# 🔥 sort by priority AFTER merge
	queue.sort_custom(func(a, b):
		return a.priority > b.priority
	)


# ----------------------------
# POP HIGHEST PRIORITY
# ----------------------------
func pop() -> ChunkJob:
	if queue.is_empty():
		return null
	return queue.pop_front()


func is_empty() -> bool:
	return queue.is_empty()
