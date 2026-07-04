# ./scripts/lod/chunk/chunkManager.gd

class_name ChunkManager
extends Node

# ==================================================
# CONFIGURATION
# ==================================================

@export var isDev: bool = false
@export var workerCount := 4

@export var dimensions := Vector3(128, 64, 128)

@export var voxel_scale := 1.0
@export var chunk_size := 16
@export var chunk_material: Material

var chunk_lod_size: float

@export var colors: Array[Color] = [
	Color.GRAY,
	Color.NAVY_BLUE,
	Color.INDIAN_RED,
	Color.BURLYWOOD,
	Color.YELLOW,
	Color.GREEN_YELLOW
]

#==================================================
# SCENE
#==================================================

var scene_root : Node

# ==================================================
# ENGINE CONTEXT
# ==================================================

var context: EngineContext

# ==================================================
# CONTROLLERS
# ==================================================

var terrain_generator := TerrainGenerator.new()
var voxel_data_controller := VoxelDataController.new()

var registry := ChunkRegistry.new()
var pool := ChunkPool

var hierarchy: ChunkHierarchyController
var diagnostics: DiagnosticsController

var thread_manager: ThreadManager
var subdivision_controller: SubdivisionController
var world_generation_controller: WorldGenerationController

var queue_controller: QueueController
var dirty_processor: DirtyChunkProcessor
var collision_processor: CollisionProcessor
var chunk_instantiator: ChunkInstantiationController

# ==================================================
# SIGNALS
# ==================================================

signal subdivision_requested(coord: Vector3i, target_level: int, wave_index: int)
signal merge_requested(coord: Vector3i)

signal generation_requested()
signal generation_completed()

signal chunk_mesh_finished(coord: Vector3i)

# ==================================================
# LIFECYCLE
# ==================================================

func _ready() -> void:
	
	chunk_lod_size = float(chunk_size) * voxel_scale

	_sanitize_world_settings()

	context = EngineContext.new()
	context.scene_root = self
	#context.chunk_scene = chunk_scene

	context.pool = ChunkPool.new(
		context.chunk_scene,
		context.scene_root
	)

	context.manager = self
	context.scene_root = self

	context.is_dev = isDev

	context.dimensions = dimensions

	context.chunk_size = chunk_size
	context.chunk_lod_size = chunk_lod_size
	context.voxel_scale = voxel_scale

	context.chunk_material = chunk_material
	context.colors = colors

	context.worker_count = workerCount

	context.registry = registry

	context.terrain_generator = terrain_generator
	context.voxel_data_controller = voxel_data_controller

	hierarchy = ChunkHierarchyController.new()
	context.hierarchy = hierarchy

	diagnostics = DiagnosticsController.new(context)
	context.diagnostics = diagnostics

	thread_manager = ThreadManager.new(context)

	queue_controller = QueueController.new(context)

	dirty_processor = DirtyChunkProcessor.new(context)

	collision_processor = CollisionProcessor.new(context)

	chunk_instantiator = ChunkInstantiationController.new(context)

	subdivision_controller = SubdivisionController.new(context)

	world_generation_controller = WorldGenerationController.new(context)

	subdivision_requested.connect(
		subdivision_controller.request_subdivision
	)

	merge_requested.connect(
		subdivision_controller.request_merge
	)

	generation_requested.connect(
		world_generation_controller.start_world_generation
	)

	generation_requested.emit.call_deferred()


func _process(delta: float) -> void:
	thread_manager.process()

# ==================================================
# PUBLIC API
# ==================================================

func set_authorized_lod(
	base_coord: Vector3i,
	max_lod: int
) -> void:

	context.authorized_lod_levels[base_coord] = max_lod


func get_authorized_lod(
	base_coord: Vector3i
) -> int:

	return context.authorized_lod_levels.get(base_coord, 0)


func queue_dirty_chunk(chunk: Chunk) -> void:
	queue_controller.queue_dirty(chunk)


func queue_collision_chunk(chunk: Chunk) -> void:
	queue_controller.queue_collision(chunk)

# ==================================================
# WORLD EVENTS
# ==================================================

func _on_subdivision_requested(
	coord: Vector3i,
	lod: int
) -> void:

	subdivision_controller.request_subdivision(
		coord,
		lod
	)


func _on_structural_impact_area_requested(
	world_position: Vector3,
	radius: float
) -> void:

	var min_chunk_x := int(
		floor((world_position.x - radius) / chunk_lod_size)
	)

	var max_chunk_x := int(
		floor((world_position.x + radius) / chunk_lod_size)
	)

	var min_chunk_z := int(
		floor((world_position.z - radius) / chunk_lod_size)
	)

	var max_chunk_z := int(
		floor((world_position.z + radius) / chunk_lod_size)
	)

	for x in range(min_chunk_x, max_chunk_x + 1):
		for z in range(min_chunk_z, max_chunk_z + 1):
			subdivision_controller.request_subdivision(
				Vector3i(x, 0, z),
				1
			)

# ==================================================
# INTERNAL
# ==================================================

func _sanitize_world_settings() -> void:

	dimensions = Vector3(
		max(1.0, dimensions.x),
		max(1.0, dimensions.y),
		max(1.0, dimensions.z)
	)
