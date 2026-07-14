# res://scripts/lod/tests/debug/wireframeLODController.gd 
class_name WireframeLODController extends Node3D

var _wireframes : Dictionary = {}
const LOD_COLORS := {
	0: Color.WHITE,
	1: Color.LIME_GREEN,
	2: Color.YELLOW,
	3: Color.ORANGE,
	4: Color.RED,
	5: Color.PURPLE
}

var context: EngineContext
func _init(_context: EngineContext) -> void:
	context = _context


# ==================================================
# PUBLIC API
# ==================================================

func update_chunk(chunk: Chunk) -> void:

	if not is_instance_valid(chunk):
		return

	var mesh_instance : MeshInstance3D

	if _wireframes.has(chunk):
		mesh_instance = _wireframes[chunk]
	else:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)
		_wireframes[chunk] = mesh_instance

	mesh_instance.position = chunk.grid_info.world_position
	mesh_instance.mesh = _build_wireframe_mesh(
		chunk.grid_info.chunk_size,
		LOD_COLORS.get(chunk.lod_level, Color.MAGENTA)
	)


func remove_chunk(chunk: Chunk) -> void:

	if !_wireframes.has(chunk):
		return

	var mesh_instance : MeshInstance3D = _wireframes[chunk]

	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()

	_wireframes.erase(chunk)


func clear() -> void:

	for mesh in _wireframes.values():
		if is_instance_valid(mesh):
			mesh.queue_free()

	_wireframes.clear()


# ==================================================
# INTERNAL
# ==================================================

func _build_wireframe_mesh(
	size: float,
	color: Color
) -> ImmediateMesh:

	var mesh := ImmediateMesh.new()

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

	var s := size

	var p000 := Vector3(0,0,0)
	var p100 := Vector3(s,0,0)
	var p110 := Vector3(s,s,0)
	var p010 := Vector3(0,s,0)

	var p001 := Vector3(0,0,s)
	var p101 := Vector3(s,0,s)
	var p111 := Vector3(s,s,s)
	var p011 := Vector3(0,s,s)

	_draw_edge(mesh,p000,p100,color)
	_draw_edge(mesh,p100,p110,color)
	_draw_edge(mesh,p110,p010,color)
	_draw_edge(mesh,p010,p000,color)

	_draw_edge(mesh,p001,p101,color)
	_draw_edge(mesh,p101,p111,color)
	_draw_edge(mesh,p111,p011,color)
	_draw_edge(mesh,p011,p001,color)

	_draw_edge(mesh,p000,p001,color)
	_draw_edge(mesh,p100,p101,color)
	_draw_edge(mesh,p110,p111,color)
	_draw_edge(mesh,p010,p011,color)

	mesh.surface_end()

	return mesh


func _draw_edge(
	mesh: ImmediateMesh,
	a: Vector3,
	b: Vector3,
	color: Color
) -> void:

	mesh.surface_set_color(color)
	mesh.surface_add_vertex(a)

	mesh.surface_set_color(color)
	mesh.surface_add_vertex(b)
