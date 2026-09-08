extends Node3D
var ribbon := ImmediateMesh.new()
var mesh := MeshInstance3D.new()
var ring := MeshInstance3D.new()
var bait := MeshInstance3D.new()
func _ready() -> void:
	top_level=true
	global_transform=Transform3D.IDENTITY
	mesh.mesh=ribbon
	var mat := StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color(.78,.72,.51,.9)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test=true;mat.render_priority=8;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.material_override=mat;add_child(mesh)
	var torus := TorusMesh.new()
	torus.inner_radius=.23;torus.outer_radius=.25;torus.rings=24;torus.ring_segments=6
	ring.mesh=torus;ring.material_override=mat;add_child(ring)
	var shape := SphereMesh.new();shape.radius=.018;shape.height=.035
	bait.mesh=shape;bait.material_override=mat;add_child(bait)
	hide()
func draw_line(start: Vector3,end: Vector3,taut: bool) -> void:
	ribbon.clear_surfaces()
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var direction := (end-start).normalized()
	var side := direction.cross((get_viewport().get_camera_3d().global_position-start).normalized()).normalized()*.003
	for i in 13:
		var t := i/12.0
		var point := start.lerp(end,t)+Vector3.DOWN*sin(PI*t)*(.035 if taut else .35)
		ribbon.surface_add_vertex(point-side)
		ribbon.surface_add_vertex(point+side)
	ribbon.surface_end()
	bait.global_position=end
