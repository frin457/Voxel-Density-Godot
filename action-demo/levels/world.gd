extends Node3D

@export var world_size: Vector3 =  Vector3(16,16,16)
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

# Called when the node enters the scene tree for the first time.
#@onready var default_cube : CSGBox3D = $DefaultCubes
@onready var default_camera: Camera3D = $DefaultCamera
@onready var chunk : Chunk = $Chunk


#Custom data
var cubes: int = 0
var data: Dictionary[Vector3, Color] = {}
func _ready() -> void:
	
	Performance.add_custom_monitor("game/cubes", func(): return cubes)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var random_gen = FastNoiseLite.new()	
	
	var startTime = Time.get_ticks_usec()
	 
	#var random_gen = RandomNumberGenerator.new()
	for x in range(world_size.x / voxelScale):
		for z in range(world_size.z / voxelScale):
			#Adjust y range for bottom leveled
			#Top leveled selection 
			for y in range(0, world_size.y):
				var random_num = random_gen.get_noise_3d(x,y,z) 
				if random_num > cutoff:
					data[Vector3(x,y,z)] = colors[y % colors.size()]
					cubes += 1
					
	#Calc generation statistics
	var endTime = Time.get_ticks_usec()
	var genTime = (endTime - startTime) 
	print_debug("Cubes mapped: %s\nGen Time: %s milliseconds" % [cubes,genTime])
	
	chunk.genMesh(data, voxelScale)
	#default_camera.position = Vector3(world_size.x/2,world_size.y* 0.75,world_size.z)
	#default_camera.rotation = Vector3(-45,-25,0)
	
	#remove_child(default_cube) #Remove default cube
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
