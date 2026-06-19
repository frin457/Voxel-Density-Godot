extends Node3D

@export var world_size: Vector3 =  Vector3(16,16,16)
@export_range(-1,1) var cutoff: float = 0.5

# Called when the node enters the scene tree for the first time.
@onready var default_cube : CSGBox3D = $DefaultCube
@onready var default_camera: Camera3D = $DefaultCamera

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	var random_gen = FastNoiseLite.new()
	#var random_gen = RandomNumberGenerator.new()
	for x in range(world_size.x):
		for z in range(world_size.z):
			for y in range(2, 2 + world_size.y):
				var random_num = random_gen.get_noise_3d(x,y,z)
				#var random_num = random_gen.randf()
				if random_num > cutoff:
					var new_cube = default_cube.duplicate()
					new_cube.position = Vector3(x,y,z)
					add_child(new_cube)
					
	default_camera.position = Vector3(world_size.x/2,world_size.y* 0.75,world_size.z)
	default_camera.rotation = Vector3(-45,-25,0)
	
	remove_child(default_cube) #Remove default cube
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
