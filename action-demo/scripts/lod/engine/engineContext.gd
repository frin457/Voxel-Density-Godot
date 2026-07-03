class_name EngineContext extends RefCounted

#==================================================
# ENGINE SERVICES
#==================================================

var registry : ChunkRegistry
var pool : ChunkPool

var mesh_controller : ChunkMeshController
var collision_controller : CollisionController
var voxel_controller : VoxelDataController
var terrain_generator : TerrainGenerator

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

var is_dev := false

#==================================================
# THREAD STATE
#==================================================

var authorized_lod_levels : Dictionary = {}
