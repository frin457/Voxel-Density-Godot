class_name EngineSandbox extends Node3D

@export var auto_generate := true
@onready var chunk_manager: ChunkManager = $ChunkManager


func _ready() -> void:
	if auto_generate:
		chunk_manager.generation_requested.emit()


func restart_world() -> void:
	chunk_manager.generation_requested.emit()


func get_context() -> EngineContext:
	return chunk_manager.get_context()
