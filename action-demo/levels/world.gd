extends Node3D

@export var cubeSize: Vector3 =  Vector3(32,32,32)
@export var colors : Array[Color] = [
	Color.GRAY,
	Color.NAVY_BLUE,
	Color.INDIAN_RED,
	Color.BURLYWOOD,
	Color.YELLOW,
	Color.GREEN_YELLOW
]
@export var voxelScale: float = 1.0
@export_range(-1,1) var cutoff: float = 0.5

@onready var default_camera: Camera3D = $DefaultCamera
@onready var chunk : Chunk = $Chunk


#Custom data
var cubes: int = 0
var data: Dictionary[Vector3, Color] = {}
func _ready() -> void:
	
	Performance.add_custom_monitor("game/cubes", func(): return cubes)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var random = FastNoiseLite.new()		
	random.noise_type = FastNoiseLite.TYPE_SIMPLEX
	random.frequency = 0.003
	var startTime = Time.get_ticks_usec()

	chunk.generateData(cubeSize.x / voxelScale, cubeSize.y / voxelScale, random, colors)
	chunk.genMesh(voxelScale)
	
	#Calc generation statistics
	var endTime = Time.get_ticks_usec()
	var genTime = (endTime - startTime) 
	print_debug("Cubes mapped: %s\nGen Time: %s milliseconds" % [cubes,genTime])
	
	#remove_child(default_cube) #Remove default cube
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
