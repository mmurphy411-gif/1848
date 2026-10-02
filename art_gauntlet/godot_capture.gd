extends SceneTree
## This script runs only in the candidate's isolated inspection project.
var settings: Dictionary
var subject: Node3D
var camera: Camera3D
var center := Vector3.ZERO
var extent := 1.0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://settings.json"))
	root.size = Vector2i(1000, 760)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file("res://asset.glb", state)
	if error != OK:
		push_error("GLB load failed")
		quit(1)
		return
	subject = document.generate_scene(state)
	root.add_child(subject)
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var mesh_count := 0
	for node in subject.find_children("*", "MeshInstance3D", true, false):
		mesh_count += 1
		var box: AABB = node.global_transform * node.get_aabb()
		low = low.min(box.position)
		high = high.max(box.end)
		for index in node.mesh.get_surface_count():
			var original: Material = node.mesh.surface_get_material(index)
			if settings.profile == "fish_existing":
				var mat := ShaderMaterial.new()
				mat.shader = load("res://runtime.gdshader")
				mat.set_shader_parameter("scales", load("res://runtime_atlas.png"))
				mat.set_shader_parameter("length_m", 0.40)
				mat.set_shader_parameter("pace", 0.0)
				mat.set_shader_parameter("phase", 0.0)
				node.set_surface_override_material(index, mat)
			elif settings.profile == "wildlife_existing" and original is StandardMaterial3D:
				var excluded := false
				for part_name in ["Wet eye", "Nose", "Hoof", "Paw", "feet"]:
					excluded = excluded or part_name in original.resource_name
				if not excluded:
					var mat := ShaderMaterial.new()
					mat.shader = load("res://runtime.gdshader")
					mat.set_shader_parameter("coat_color", original.albedo_color)
					node.set_surface_override_material(index, mat)
	if mesh_count == 0:
		push_error("No imported meshes")
		quit(1)
		return
	center = (low + high) * 0.5
	extent = (high-low).length()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.19, 0.21, 0.23)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.84, 0.9)
	environment.environment.ambient_light_energy = 0.6
	root.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45,-30,0)
	key.light_energy = 1.4
	root.add_child(key)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.near = 0.001
	camera.far = 1000
	camera.fov = 42
	camera.make_current()
	await shot("close", maxf(extent * 1.6, 0.1))
	await shot("gameplay", float(settings.gameplay_distance))
	var file := FileAccess.open("res://engine_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"meshes": mesh_count, "extent": extent, "engine": Engine.get_version_info().string}, "\t"))
	file.close()
	quit(0)

func shot(label: String, distance: float) -> void:
	camera.position = center + Vector3(-0.2,0.22,1).normalized() * distance
	camera.look_at(center)
	for frame in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://"+label+".png")
