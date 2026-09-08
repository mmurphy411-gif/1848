extends RefCounted
## Named lighting views and a warmed frame-time sample, called by capture_greybox.

const Layout = preload("res://scripts/claim_layout.gd")

static func run(tree: SceneTree, claim: Node3D) -> bool:
	var walker: CharacterBody3D = claim.get_node("Walker")
	var rig: Node3D = claim.get_node("CameraRig")
	var camera: Camera3D = rig.get_node("SpringArm3D/Camera3D")
	var daylight: Node3D = claim.get_node("Daylight")
	claim.get_node("DensityDebug").hide()
	walker.get_node("Panner")._reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	daylight.apply(19.25)
	camera.current = true
	await _place(tree, walker, rig, Vector2(-20, Layout.shore_z(-20) + 8), -1.1475, -0.08)
	await _save(tree, "milestone-3-bar-downstream.png")
	var budget_ok := await _sample(tree, "golden downstream")
	await _place(tree, walker, rig, Vector2(20, Layout.shore_z(20) + 8), 1.4, -0.08)
	await _save(tree, "milestone-3-bar-upstream.png")
	await _place(tree, walker, rig, Vector2(6, 1), -0.8, 0.02)
	await _save(tree, "milestone-3-boulders.png")
	var overview := Camera3D.new()
	claim.add_child(overview)
	overview.far = 600
	overview.attributes = daylight.camera_attributes
	overview.position = Vector3(95, 100, 18)
	overview.fov = 60.0
	overview.look_at(Vector3(-15, 0, -3))
	overview.current = true
	await _save(tree, "milestone-3-overview.png")
	budget_ok = await _sample(tree, "golden overview") and budget_ok
	camera.current = true
	daylight.apply(12.0)
	await _place(tree, walker, rig, Vector2(-20, Layout.shore_z(-20) + 8), -1.1475, -0.08)
	await _save(tree, "milestone-3-noon.png")
	daylight.apply(19.25)
	overview.queue_free()
	return budget_ok

static func _place(tree: SceneTree, walker: CharacterBody3D, rig: Node3D, point: Vector2, yaw: float, pitch: float) -> void:
	walker.position = Vector3(point.x, Layout.height_at(point.x, point.y) + 0.05, point.y)
	walker.velocity = Vector3.ZERO
	rig.yaw = yaw
	rig.pitch = pitch
	walker.get_node("Visual").rotation.y = yaw
	for i in 45:
		await tree.physics_frame

static func _save(tree: SceneTree, name: String) -> void:
	# Allow cascades, screen-space history and fog to settle after each view change.
	for i in 180:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	if not preload("res://tests/composition_guard.gd").check(tree,name): return
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var error := tree.root.get_texture().get_image().save_png("res://artifacts/" + name)
	assert(error == OK, "Could not save " + name)
	print("Saved ", name)

static func _sample(tree: SceneTree, label: String) -> bool:
	var times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 600:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
	times.sort()
	print("MILESTONE 3 1080p %s: median %.2f ms, p95 %.2f ms (600 warmed frames, VSync off)." % [label, times[300], times[570]])
	return times[570] < 5.5
