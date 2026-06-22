extends Node3D

@onready var default_camera: Camera3D = $DefaultCamera

var data: Dictionary[Vector3, Color] = {}
func _ready() -> void:
	
	Performance.add_custom_monitor("game/cubes", func(): return data.keys().size())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
