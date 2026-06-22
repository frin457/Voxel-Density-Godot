#./scripts/world.gd
extends Node3D

@export var is_dev: bool = true

@onready var chunk_manager: ChunkManager
@onready var default_camera: Camera3D = $DefaultCamera

var data: Dictionary[Vector3, Color] = {}

func _ready() -> void:
	Performance.add_custom_monitor("game/cubes", func(): return data.keys().size())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# check if the export variable was assigned (via the inspector)
	if not chunk_manager:
		chunk_manager = $ChunkManager as ChunkManager

	# Guard clause: stop here if setup is missing
	if not chunk_manager:
		push_error("World: ChunkManager node reference missing!")
		return
		
	# Boot world generation
	chunk_manager.generation_requested.emit.call_deferred()
	
	# dev-mode testing sequence
	if is_dev:
		_run_development_test()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

# ----------------------------
# COMPONENT EVENT TESTING
# ----------------------------
func _run_development_test() -> void:
	print("World Trigger: Starting 2.0 second subdivision test delay...")
	await get_tree().create_timer(2.0).timeout
	
	var center_coord := Vector3i(0, 0, 0)
	var target_lod_level := 1
	
	print("World Trigger: Emitting request to subdivide center chunk.")
	chunk_manager.subdivision_requested.emit(center_coord, target_lod_level)
