#./scripts/world.gd
extends Node3D

@export var isDev: bool = true

@onready var chunk_manager: ChunkManager
@onready var default_camera: Camera3D = $DefaultCamera

var data: Dictionary[Vector3, Color] = {}

func _ready() -> void:
	Performance.add_custom_monitor("game/cubes", func(): return data.keys().size())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# check if the export variable was assigned (via the inspector)
	if not chunk_manager:
		chunk_manager = $ChunkManager as ChunkManager

	# guard clause: stop here if setup is missing
	if not chunk_manager:
		push_error("World: ChunkManager node reference missing!")
		return
	
	# runs first to begin listening to the generation signals
	if isDev:
		_run_development_test()
		
	# start world generation
	chunk_manager.generation_requested.emit.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

# ----------------------------
# COMPONENT EVENT TESTING
# ----------------------------
func _run_development_test() -> void:
	if isDev:
		print("World Trigger: Dev mode active. Awaiting deterministic 'generation_completed' signal...")
	
	# await the specific signal completion
	await chunk_manager.generation_completed
	
	if isDev: 
		print("World Trigger: Generation confirmed completed! Emitting request to subdivide center chunk.")
		
	var center_coord := Vector3i(0, 0, 0)
	var target_lod_level := 1
	chunk_manager.subdivision_requested.emit(center_coord, target_lod_level)
