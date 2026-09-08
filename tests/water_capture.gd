extends RefCounted
## Water views and fixed, world-anchored image gates. No probes run in the game.
const Layout = preload("res://scripts/claim_layout.gd")
const Lighting = preload("res://tests/lighting_capture.gd")

static func run(tree: SceneTree, claim: Node3D) -> bool:
	var walker: CharacterBody3D = claim.get_node("Walker")
	var rig: Node3D = claim.get_node("CameraRig")
	var player_camera: Camera3D = rig.get_node("SpringArm3D/Camera3D")
	var daylight: Node3D = claim.get_node("Daylight")
	claim.get_node("DensityDebug").hide()
	walker.get_node("Panner")._reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	daylight.apply(19.25)
	var camera := Camera3D.new()
	claim.add_child(camera)
	camera.attributes = daylight.camera_attributes
	camera.far = 600
	camera.fov = 65
	walker.hide()
	_view(camera, Vector3(-19, 1.1, -1.8), Vector3(-12, 0, -9))
	await _save(tree, "water-shore")
	walker.show()
	player_camera.current = true
	await Lighting._place(tree, walker, rig, Vector2(6, 1), -0.8, 0.02)
	var glint := await _save(tree, "water-glint")
	var sun_direction: Vector3 = daylight.sun.global_basis.z
	var glint_point := player_camera.global_position + Vector3(sun_direction.x, 0, sun_direction.z) * 40.0
	glint_point.y = 0
	var glint_stats := _patch(glint, player_camera, glint_point, 64)
	var ok := _check(glint_stats.w > 0.06, "Glint luminance deviation %.3f > 0.06" % glint_stats.w)
	walker.hide()
	_view(camera, Vector3(0, 6, 0), Vector3(0, 0, -6))
	var top := await _save(tree, "water-top")
	var shallow := _patch(top, camera, Vector3(0, 0, -6.966667))
	# The gravel directly below this camera is shaded by Boulder03; compare
	# the exposed shallows to exposed dry gravel in the same view.
	var dry := _patch(top, camera, Vector3(-6, Layout.height_at(-6, -2), -2))
	var deep := _patch(top, camera, Vector3(0, 0, -10.666667))
	ok = _check(shallow.y <= dry.y * 1.25, "Shallows green %.3f <= dry %.3f × 1.25" % [shallow.y, dry.y]) and ok
	ok = _check(deep.y >= deep.x * 1.3 and _luma(deep) < _luma(shallow), "Channel RGB %s darker than shallows %s, G/R %.3f >= 1.3" % [deep, shallow, deep.y / maxf(deep.x, 0.001)]) and ok
	# Hold an actual knee-deep pose without the idle current moving the probe target.
	walker.set_physics_process(false)
	walker.position = Vector3(10, -0.45, Layout.shore_z(10) - 3.166667)
	walker.show()
	_view(camera, Vector3(13, 2.4, -6.6), Vector3(10, 0, -8.4))
	var wade := await _save(tree, "water-wade")
	var contact_point := Vector3(10.3, 0, walker.position.z + 0.18)
	var ring := _patch(wade, camera, contact_point)
	var nearby := _patch(wade, camera, contact_point + Vector3.RIGHT)
	ok = _check(_luma(ring) >= _luma(nearby) + 0.1, "Wade contact luminance %.3f >= nearby %.3f + 0.1" % [_luma(ring), _luma(nearby)]) and ok
	walker.set_physics_process(true)
	walker.hide()
	camera.fov = 60
	_view(camera, Vector3(95, 100, 18), Vector3(-15, 0, -3))
	var overview := await _save(tree, "overview")
	var contrast := _stats(overview, Rect2i(0, 0, overview.get_width(), overview.get_height())).w
	ok = _check(contrast > 0.08, "Overview luminance deviation %.3f > 0.08" % contrast) and ok
	_view(camera, Vector3(7, 20, -5), Vector3(7, 0, -5), Vector3.FORWARD)
	var shadow_image := await _save(tree, "shadow-color")
	var shadow := _patch(shadow_image, camera, Vector3(1, Layout.height_at(1, -1), -1))
	var sunlit := _patch(shadow_image, camera, Vector3(10, Layout.height_at(10, -1), -1))
	var ratio := shadow.z / maxf(shadow.x, 0.001) / (sunlit.z / maxf(sunlit.x, 0.001))
	ok = _check(ratio >= 1.12, "Shadow/sunlit B:R ratio %.3f >= 1.12 (shadow %s, sunlit %s)" % [ratio, shadow, sunlit]) and ok
	daylight.apply(12.0)
	camera.fov = 65
	_view(camera, Vector3(0, 6, 0), Vector3(0, 0, -6))
	await _save(tree, "noon-water")
	daylight.apply(19.25)
	# Warm the complete water view before measuring, including the screen copy.
	await _settle(tree)
	ok = await _sample(tree) and ok
	walker.show()
	player_camera.current = true
	camera.queue_free()
	print("WATER CAPTURE: ", "PASS" if ok else "FAIL")
	return ok

static func _view(camera: Camera3D, position: Vector3, target: Vector3, up := Vector3.UP) -> void:
	camera.position = position
	camera.look_at(target, up)
	camera.current = true

static func _settle(tree: SceneTree) -> void:
	for i in 240:
		await tree.process_frame
	await RenderingServer.frame_post_draw

static func _save(tree: SceneTree, label: String) -> Image:
	await _settle(tree)
	var picture := tree.root.get_texture().get_image()
	assert(picture.get_width() == 1920 and picture.get_height() == 1080)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	assert(picture.save_png("res://artifacts/milestone-4-%s.png" % label) == OK)
	print("Saved milestone-4-%s.png" % label)
	return picture

static func _patch(picture: Image, camera: Camera3D, world: Vector3, size := 16) -> Vector4:
	var pixel := Vector2i(camera.unproject_position(world))
	assert(not camera.is_position_behind(world))
	var rect := Rect2i(pixel - Vector2i(size / 2, size / 2), Vector2i(size, size))
	assert(Rect2i(0, 0, picture.get_width(), picture.get_height()).encloses(rect))
	print("Probe world %s -> pixel %s (%d×%d)" % [world, pixel, size, size])
	return _stats(picture, rect)

static func _stats(picture: Image, rect: Rect2i, stride := 1) -> Vector4:
	var sum := Vector3.ZERO
	var lum := 0.0
	var squared := 0.0
	var count := 0
	for y in range(rect.position.y, rect.end.y, stride):
		for x in range(rect.position.x, rect.end.x, stride):
			var c := picture.get_pixel(x, y)
			var rgb := Vector3(c.r, c.g, c.b)
			var l := rgb.dot(Vector3(0.2126, 0.7152, 0.0722))
			sum += rgb
			lum += l
			squared += l * l
			count += 1
	sum /= count
	return Vector4(sum.x, sum.y, sum.z, sqrt(maxf(squared / count - pow(lum / count, 2), 0)))

static func _luma(color: Vector4) -> float:
	return Vector3(color.x, color.y, color.z).dot(Vector3(0.2126, 0.7152, 0.0722))

static func _check(condition: bool, description: String) -> bool:
	print("%s: %s" % ["PASS" if condition else "FAIL", description])
	return condition

static func _sample(tree: SceneTree) -> bool:
	var times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 600:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
	times.sort()
	return _check(times[570] < 5.5, "MILESTONE 4 1080p: median %.2f ms, p95 %.2f ms < 5.5 (600 warmed frames)" % [times[300], times[570]])
