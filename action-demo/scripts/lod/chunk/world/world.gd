# ./scripts/lod/chunk/world/world.gd

extends Node3D

@export var is_dev: bool = true

@onready var default_camera: Camera3D = $DefaultCamera

var data: Dictionary[Vector3, Color] = {}


func _ready() -> void:
	Performance.add_custom_monitor(
		"game/cubes",
		func(): return data.size()
	)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if is_dev:
		print("World initialized.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
