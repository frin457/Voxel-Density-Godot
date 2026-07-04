class_name WorldGenerationPlan extends RefCounted

var jobs: Array[ChunkJob] = []

func is_empty() -> bool:
	return jobs.is_empty()

func count() -> int:
	return jobs.size()
