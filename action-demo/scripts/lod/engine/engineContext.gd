#res://scripts/lod/engine/engineContext.gd
class_name EngineContext extends RefCounted

var is_dev := false

# ==================================================
# ENGINE STATE
# ==================================================

var manager: ChunkManager
var scene_root: Node

var world_generation_controller: WorldGenerationController

# ==================================================
# ENGINE SERVICES
# ==================================================
var index: ChunkIndex
var pool: ChunkPool
var chunk_instantiator: ChunkInstantiationController

var chunk_state : ChunkStateController
var voxel_data_controller: VoxelDataController
var terrain_generator: TerrainGenerator

var dirty_processor: DirtyChunkProcessor
var collision_processor: CollisionProcessor

var mesh_controller: ChunkMeshController
var mesh_snapshot_factory: MeshSnapshotFactory

var collision_controller: CollisionController
var collision_snapshot_controller: CollisionSnapshotController

var subdivision_planner: SubdivisionPlanner
var merge_planner: MergePlanner

var hierarchy: ChunkHierarchyController
var activation: ActivationController

var diagnostics: DiagnosticsController
var lod_wireframes: WireframeLODController

# ==================================================
# WORK QUEUES
# ==================================================
var queue_controller: QueueController
var job_queue := ChunkJobQueue.new()
var active_thread_tasks: Array[int] = []
var dirty_queue: Array[Chunk] = []
var collision_queue: Array[Chunk] = []

var dirty_queue_processed_this_frame := 0

var max_dirty_queue_per_frame := 8
var max_collisions_per_frame := 2

# ==================================================
# WORLD CONFIGURATION
# ==================================================

var chunk_scene: PackedScene

# Default values copied into each chunk's GridInfo
var chunk_size: int
var voxel_size: float
var max_world_height: float

var chunk_lod_size: float

var dimensions: Vector3

var chunk_material: Material
var colors: Array[Color]

var noise: Noise

var worker_count: int

# ==================================================
# THREAD STATE
# ==================================================

var thread_manager: ThreadManager

var authorized_lod_levels: Dictionary = {}
