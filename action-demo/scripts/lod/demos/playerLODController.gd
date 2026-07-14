# ./scripts/lod/playerLODController.gd
class_name PlayerLODController extends BaseLODController

@export var target: Node3D

const ROTATION_THRESHOLD := 0.95
# Desired LOD radii (measured in chunks)
const HIGH_RADIUS := 1
const MEDIUM_RADIUS := 3

var chunk_lod_size := 16.0

var last_chunk_coordinate := Vector3i(999999, 999999, 999999)
var last_player_position := Vector3.ZERO
var last_forward_vector := Vector3.ZERO


func _ready() -> void:
	super._ready()

	if manager == null:
		push_error("PlayerLODController: Missing ChunkManager.")
		return
	chunk_lod_size = manager.chunk_lod_size
	# Default to the active camera if no explicit target
	# has been assigned in the editor.
	if target == null:
		target = get_viewport().get_camera_3d()
	if target == null:
		push_error("PlayerLODController: Missing tracking target.")


func _process(_delta: float) -> void:
	if target == null:
		return
	var player_position := target.global_position


	var center_coord := manager.world_to_chunk_coordinate(
		player_position
	)
	
	var forward := -target.global_transform.basis.z.normalized()

	var moved_chunk := (
		center_coord != last_chunk_coordinate
	)

	var rotated := (
		last_forward_vector == Vector3.ZERO
		or forward.dot(last_forward_vector) < ROTATION_THRESHOLD
	)

	if !moved_chunk and !rotated:
		return

	last_chunk_coordinate = center_coord
	last_player_position = player_position
	last_forward_vector = forward
	update_targets()
	print("Player:", player_position)
	print("Center:", center_coord)
	

func update_targets() -> void:
	clear_requests()
	var world_chunks_x : int = int(
		ceil(manager.dimensions.x / manager.chunk_lod_size)
	)

	var world_chunks_y : int = int(
		ceil(manager.dimensions.y / manager.chunk_lod_size)
	)

	var world_chunks_z : int = int(
		ceil(manager.dimensions.z / manager.chunk_lod_size)
	)
	
	for x in range(world_chunks_x):
		for y in range(world_chunks_y):
			for z in range(world_chunks_z):
				var coord := Vector3i(x, y, z)

				var distance : int = max(
					abs(coord.x - last_chunk_coordinate.x),
					abs(coord.y - last_chunk_coordinate.y),
					abs(coord.z - last_chunk_coordinate.z)
				)

				var desired_lod : int = 0

				if distance <= HIGH_RADIUS:
					desired_lod = 1
				elif distance <= MEDIUM_RADIUS:
					desired_lod = 1
				request_lod(
					coord,
					desired_lod
				)

	flush()
