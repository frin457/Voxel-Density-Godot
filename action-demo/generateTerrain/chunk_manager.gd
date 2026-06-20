class_name ChunkManager extends Node

@export var voxelScale: float = 1.0
@export var colors : Array[Color] = [ Color.GRAY,
	Color.NAVY_BLUE,
	Color.INDIAN_RED,
	Color.BURLYWOOD,
	Color.YELLOW,
	Color.GREEN_YELLOW]
@export var dimensions: Vector3 = Vector3(128,64,128)
@export var chunkSize: int = 32
@export var noiseSeed : int = 0

var random = FastNoiseLite.new()
var totalChunks: Vector3

var threads: Array[Thread] = [Thread.new(), Thread.new(), Thread.new(), Thread.new()]

var chunk = preload("res://generateTerrain/chunk.tscn")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	random.noise_type = FastNoiseLite.TYPE_SIMPLEX
	random.frequency = 0.003

	totalChunks = dimensions / chunkSize
	var startTime = Time.get_ticks_usec()
	threads[0].start(genChunks.bind(Vector3(0,0,0)))
	threads[1].start(genChunks.bind(Vector3(dimensions.x / 2 ,0,0)))
	threads[2].start(genChunks.bind(Vector3(0,0,dimensions.z / 2)))
	threads[3].start(genChunks.bind(Vector3(dimensions.x / 2, 0 ,dimensions.z / 2)))
	var endTime = Time.get_ticks_usec()
	var genTime = (endTime - startTime) 
	print_debug("Gen Time: %s milliseconds" % [genTime])

func genChunks(pos: Vector3) -> void:
	var chunks: Vector3 = totalChunks /  2
	for x in range(totalChunks.x):
		for z in range(totalChunks.z):
			for y in range(totalChunks.y):
				var newChunk = chunk.instantiate()
				newChunk.position = Vector3(x,y,z) * chunkSize + pos
				newChunk.genData(chunkSize, dimensions.y,random,colors)
				newChunk.genMesh()
				call_deferred("add_child", newChunk)

func _exit_tree() -> void:
	for thread in threads:
		thread.wait_to_finish()
