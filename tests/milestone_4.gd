extends SceneTree
## Structural water checks; GPU compilation and color acceptance live in the harness.
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var claim: Node3D = load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	for i in 40:
		await physics_frame
	var shader := load("res://shaders/water.gdshader") as Shader
	_check(shader != null, "Water shader loads")
	for token in ["hint_depth_texture", "hint_screen_texture", "uniform vec3 absorption", "uniform vec3 scatter", "uniform float foam_distance", "uniform float normal_strength", "uniform float wave_amplitude", "uniform float refraction_strength"]:
		_check(token in shader.code, "Shader declares " + token)
	var water: MeshInstance3D = claim.get_node("Greybox/River/WaterSurface")
	_check(water.material_override is ShaderMaterial and water.material_override.shader == shader, "Water uses its ShaderMaterial")
	var arrays: Array = water.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	_check(colors.size() == vertices.size() and vertices.size() > 2000, "Flow and depth color for every subdivided vertex (%d)" % vertices.size())
	var flat := true
	var min_x := INF
	var max_x := -INF
	var positive_bend := false
	var negative_bend := false
	var shore_speed := false
	var channel_speed := false
	for i in vertices.size():
		var v := vertices[i]
		var c := colors[i]
		flat = flat and absf(v.y) < 0.001
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
		if absf(v.x - 30) < 0.01 and c.b > 0.9:
			positive_bend = c.r > 0.5 and c.g > 0.5
		if absf(v.x + 30) < 0.01 and c.b > 0.9:
			negative_bend = c.r > 0.5 and c.g < 0.5
		if absf(v.x) < 0.01:
			if absf(v.z + 6.666667) < 0.01:
				shore_speed = c.b < 0.35
			if absf(v.z + 19.97) < 0.6:
				channel_speed = c.b > 0.9
	_check(flat and min_x <= -110 and max_x >= 110, "Water mesh stays at Y=0 and covers the river")
	_check(positive_bend and negative_bend, "Baked flow follows both sides of the bend")
	_check(shore_speed and channel_speed, "Shore current is slow and mid-channel fast")
	var probe: ReflectionProbe = claim.get_node("Greybox/RiverReflection")
	var box := AABB(-probe.size / 2, probe.size)
	_check(box.has_point(probe.to_local(Vector3(-40, 0, -10))) and box.has_point(probe.to_local(Vector3(40, 0, -10))) and probe.update_mode == ReflectionProbe.UPDATE_ONCE, "One-shot reflection probe covers the claim river")
	_check(not claim.get_node("Daylight").environment.ssr_enabled, "SSR stays off for transparent water")
	_check(claim.get_node("Daylight").environment.fog_depth_begin >= 120, "Distance fog begins beyond the claim")
	var ground: MeshInstance3D = claim.get_node("Greybox/CanyonAndGravelBar")
	var largest_indices := 0
	var largest_vertices := 0
	for surface in ground.mesh.get_surface_count():
		var mesh_arrays: Array = ground.mesh.surface_get_arrays(surface)
		if mesh_arrays[Mesh.ARRAY_INDEX].size() > largest_indices:
			largest_indices = mesh_arrays[Mesh.ARRAY_INDEX].size()
			largest_vertices = mesh_arrays[Mesh.ARRAY_VERTEX].size()
	_check(largest_indices > 0 and largest_vertices * 2 < largest_indices, "Ground shares indexed vertices (%d vertices, %d indices)" % [largest_vertices, largest_indices])
	# Pinned milestone 3 analytical values: bank, shallows, channel, bend and outside.
	var samples := [Vector4(-30, 0, -1.25, 0.24), Vector4(-15, 0, -5.8125, 0.15), Vector4(0, 0, -6.5, 0), Vector4(0, 0, -7, 0.06), Vector4(0, 0, -9, 0.42), Vector4(0, 0, -11, 0.78), Vector4(0, 0, -16, 2.88), Vector4(0, 0, -26, 4.78), Vector4(30, 0, -2.25, 0.42), Vector4(111, 0, -16, 0)]
	for sample in samples:
		var actual: float = claim.get_node("Greybox/River").depth_at(Vector3(sample.x, sample.y, sample.z))
		_check(absf(actual - sample.w) < 0.0001, "Analytical depth %s = %.3f (expected %.3f)" % [Vector3(sample.x, sample.y, sample.z), actual, sample.w])
	claim.queue_free()
	await process_frame
	print("MILESTONE 4: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, description: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures.append(description)
