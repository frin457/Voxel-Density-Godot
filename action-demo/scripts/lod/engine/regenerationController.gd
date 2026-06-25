#./scripts/lod/engine/regenerationController.gd
#place holder for eventual voxel regeneration hooks
enum RegenerationMode {
	NONE,
	TIMER,
	PLAYER_DISTANCE,
	CHECKPOINT,
	SCRIPTED
}

var regeneration_mode = RegenerationMode.NONE
