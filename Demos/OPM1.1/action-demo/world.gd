extends Node3D

@export var world_size: Vector3 =  Vector3(16,16,16)
@export var colors : Array[Color]
@export_range(-1,1) var cutoff: float = 0.5

# Called when the node enters the scene tree for the first time.
@onready var default_cube : CSGBox3D = $DefaultCube
@onready var default_camera: Camera3D = $DefaultCamera
@onready var mesh_instance : MultiMeshInstance3D = $MultiMeshInstance3D

#Custom data
var cubes: int = 0
var data: Array[Vector3] = []
func _ready() -> void:
	
	Performance.add_custom_monitor("game/cubes", func(): return cubes)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var random_gen = FastNoiseLite.new()	
	
	var startTime = Time.get_ticks_usec()
	 
	#var random_gen = RandomNumberGenerator.new()
	for x in range(world_size.x):
		for z in range(world_size.z):
			for y in range(2, 2 + world_size.y):
				var random_num = random_gen.get_noise_3d(x,y,z) 
				if random_num > cutoff:
					data.append(Vector3(x,y,z))
					cubes += 1
					
	#Calc generation statistics
	var endTime = Time.get_ticks_usec()
	var genTime = (endTime - startTime) / 100000
	print_debug("Blocks generated %s\n Gen Time: %s seconds" % [cubes,genTime])
	
	#Set size of the multimesh buffer
	mesh_instance.multimesh.instance_count = data.size()
	for i in range(mesh_instance.multimesh.instance_count):
		mesh_instance.multimesh.set_instance_transform(i, Transform3D(Basis(), data[i]))
		mesh_instance.multimesh.set_instance_color(i, colors[randf() * colors.size()])
	
	
	#default_camera.position = Vector3(world_size.x/2,world_size.y* 0.75,world_size.z)
	#default_camera.rotation = Vector3(-45,-25,0)
	
	remove_child(default_cube) #Remove default cube
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
