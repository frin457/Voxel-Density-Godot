class_name ChunkJobQueue
extends RefCounted

var queue: Array[ChunkJob] = []

# thread-safe buffer
var pending_add: Array[ChunkJob] = []


func push(job: ChunkJob) -> void:
	# called from ANY thread-safe context (deferred safe)
	pending_add.append(job)


func flush() -> void:
	# move pending into main queue
	for j in pending_add:
		queue.append(j)
	pending_add.clear()


func pop() -> ChunkJob:
	if queue.is_empty():
		return null
	return queue.pop_front()


func is_empty() -> bool:
	return queue.is_empty()
