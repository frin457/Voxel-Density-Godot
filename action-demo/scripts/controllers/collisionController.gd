class_name CollisionController
extends RefCounted


func rebuild(chunk: Chunk):
	chunk.collisionShape.shape = chunk.meshInstance.mesh.create_trimesh_shape()
	chunk.collision_dirty = false
