class_name CollisionSnapshotController
extends RefCounted


func create_snapshot(
	mesh: Mesh
) -> CollisionSnapshot:

	var snapshot := CollisionSnapshot.new()

	if mesh == null:
		return snapshot

	if mesh.get_surface_count() == 0:
		return snapshot

	snapshot.faces = mesh.get_faces()

	return snapshot
