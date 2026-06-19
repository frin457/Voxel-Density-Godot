extends CharacterBody3D
@export var mouse_sensativity : float = 0.001
@onready var head: Node3D = $Head
@onready var player_camera : Camera3D = $Head/PlayerCamera

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var isFlying : bool = true

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
	# As good practice, you should replace UI actions with custom gameplay actions.
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


func _unhandled_input(event: InputEvent) -> void:  
	if event is InputEventMouseMotion:
		var relative = event.relative * mouse_sensativity
		head.rotate_y(-relative.x)
		player_camera.rotate_x(-relative.y)
		player_camera.rotation.x = clamp(player_camera.rotation.x, deg_to_rad(-40), deg_to_rad(40))
