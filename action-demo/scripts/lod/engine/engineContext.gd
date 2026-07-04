#./scripts/lod/engine/engineContext.gd
class_name EngineContext extends RefCounted
var is_dev := false

#==================================================
# ENGINE SERVICES
#==================================================

var registry : ChunkRegistry
var pool : ChunkPool

var voxel_controller : VoxelDataController
var terrain_generator : TerrainGenerator

var dirty_processor : DirtyChunkProcessor
var collision_processor : CollisionProcessor
var mesh_controller : ChunkMeshController
var collision_controller : CollisionController

var subdivision_planner : SubdivisionPlanner
var merge_planner : MergePlanner
var hierarchy : ChunkHierarchyController
var activation : ActivationController

var diagnostics : DiagnosticsController

#==================================================
# WORK QUEUES
#==================================================

var job_queue : ChunkJobQueue

#==================================================
# CONFIGURATION
#==================================================

var chunk_scene : PackedScene

var chunk_size : int
var voxel_size : float
var chunk_world_size : float
var max_world_height : float
var colors : Array[Color]
var noise : Noise

#==================================================
# THREAD STATE
#==================================================

var authorized_lod_levels : Dictionary = {}
var chunk_lod_size : float

#==================================================
# QUEUES
#==================================================
var active_thread_tasks : Array[int]
var dirty_queue : Array[Chunk]
var collision_queue : Array[Chunk]
