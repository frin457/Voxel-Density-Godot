class_name EngineSandbox
extends Node3D

@onready var chunk_manager: ChunkManager = $ChunkManager

func restart_world() -> void:
	chunk_manager.generation_requested.emit()

func get_context() -> EngineContext:
	return chunk_manager.get_context()
