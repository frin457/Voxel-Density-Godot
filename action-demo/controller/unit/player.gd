extends CharacterBody3D

signal chunk_changed(new_chunk_coords: Vector3i)

@export var mouse_sensativity : float = 0.001
@export var chunk_size: float = 32.0 # Adjust this to match your actual chunk size

@onready var head: Node3D = $Head
@onready var player_camera : Camera3D = $Head/PlayerCamera

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var isFlying : bool = true

# Tracks the discrete chunk coordinates to avoid redundant updates
var current_chunk_coords: Vector3i = Vector3i(-99999, -99999, -99999)

func _physics_process(delta: float) -> void:
	up_direction = Vector3.UP
	# Add the gravity.
	if not is_on_floor():
		if isFlying:
			velocity += Vector3.ZERO
		else: 
			velocity += get_gravity() * delta
		
	# Handle jumping.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	#Toggle Flight
	if Input.is_action_just_pressed("flying"):
		#print_debug("flying toggled, %s" % isFlying)
		velocity = Vector3(0,0,0)
		isFlying = !isFlying
			
	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (player_camera.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		if isFlying:
			velocity = direction * SPEED * 3
		else:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		if isFlying:
			velocity.y = move_toward(velocity.y, 0, SPEED)
			
	move_and_slide()

	# --- CHUNK BOUNDARY CHECK ---
	# Calculate current discrete chunk index based on global position
	var new_coords = Vector3i(
		floor(global_position.x / chunk_size),
		floor(global_position.y / chunk_size),
		floor(global_position.z / chunk_size)
	)
	
	# Only fire updates when the player crosses over into a new chunk cell
	if new_coords != current_chunk_coords:
		current_chunk_coords = new_coords
		chunk_changed.emit(current_chunk_coords)
		# If your ChunkManager isn't hooked up via signals, you can directly call it here:
		# ChunkManager.update_player_position(new_coords)


func _unhandled_input(event: InputEvent) -> void:  
	if event is InputEventMouseMotion:
		var relative = event.relative * mouse_sensativity
		head.rotate_y(-relative.x)
		player_camera.rotate_x(-relative.y)
		player_camera.rotation.x = clamp(player_camera.rotation.x, deg_to_rad(-40), deg_to_rad(40))
