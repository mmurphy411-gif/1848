extends Node3D
## Permanent development view; no construction or input handling in release builds.

const Layout = preload("res://scripts/claim_layout.gd")
const GoldMap = preload("res://scripts/gold_map.gd")

func _ready() -> void:
	visible = false
	set_process_unhandled_key_input(OS.is_debug_build())

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_density") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if not OS.is_debug_build():
		return
	if get_child_count() == 0:
		_build()
	visible = not visible

func _build() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-41, 42):
		for z in range(-10, 33):
			if z < Layout.shore_z(x) - 3.0 or z > Layout.back_z(x):
				continue
			if _on_bedrock(Vector2(x, z)):
				continue # Leave the dark slab visible beside its glowing downstream edge.
			var density := GoldMap.density_at(x, z)
			surface.set_color(Color(0.055, 0.06, 0.065).lerp(Color(1.0, 0.62, 0.06), density))
			for offset in [Vector2(-0.45, -0.45), Vector2(0.45, -0.45), Vector2(-0.45, 0.45), Vector2(0.45, -0.45), Vector2(0.45, 0.45), Vector2(-0.45, 0.45)]:
				var point: Vector2 = Vector2(x, z) + offset
				surface.add_vertex(Vector3(point.x, Layout.height_at(point.x, point.y) + 0.05, point.y))
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Draw after transparent water so the debug colors retain their meaning.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 1
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

func _on_bedrock(point: Vector2) -> bool:
	for slab in Layout.BEDROCK:
		if absf(point.x - slab.x) < slab.z * 0.5 - 0.01 and absf(point.y - slab.y) < slab.w * 0.5 + 0.3:
			return true
	return false
