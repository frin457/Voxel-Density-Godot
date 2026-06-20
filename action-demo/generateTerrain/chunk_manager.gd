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
var chunk = preload("res://generateTerrain/chunk.tscn")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	random.noise_type = FastNoiseLite.TYPE_SIMPLEX
	random.frequency = 0.003

	totalChunks = dimensions / chunkSize
	var startTime = Time.get_ticks_usec()
	genChunks()
	var endTime = Time.get_ticks_usec()
	var genTime = (endTime - startTime) 
	print_debug("Gen Time: %s milliseconds" % [genTime])

func genChunks() -> void:
	for x in range(totalChunks.x):
		for z in range(totalChunks.z):
			for y in range(totalChunks.y):
				var newChunk = chunk.instantiate()
				newChunk.position = Vector3(x,y,z) * chunkSize
				add_child(newChunk)
				newChunk.genData(chunkSize, dimensions.y,random,colors)
				newChunk.genMesh()
