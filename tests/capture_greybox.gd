extends SceneTree
## Render-only review harness; never loaded by the playable scene.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var claim: Node3D = load("res://scenes/claim.tscn").instantiate()
	claim.get_node("Walker/Panner").reproducible = true
	root.add_child(claim)
	# Mouse capture is unavailable in headless mode, so verify it in this harness.
	var rig: Node3D = claim.get_node("CameraRig")
	var original_yaw: float = rig.yaw
	var original_pitch: float = rig.pitch
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(200, -100)
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	if rig.yaw > original_yaw - 0.4 or rig.pitch < original_pitch + 0.2:
		push_error("Mouse orbit input failed")
		quit(1)
		return
	print("PASS: Captured mouse input orbits the camera.")
	rig.yaw = original_yaw
	rig.pitch = original_pitch
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var ignore := FileAccess.open("res://artifacts/.gdignore", FileAccess.WRITE)
	ignore.close()
	root.get_texture().get_image().save_png("res://artifacts/milestone-1-player.png")
	var frame_times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 240:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append(float(now - previous) / 1000.0)
		previous = now
	frame_times.sort()
	var total := 0.0
	for frame_time in frame_times:
		total += frame_time
	print("1080p player view: %.1f FPS average; %.2f ms median; %.2f ms p95 (240 frames, VSync off)." % [240000.0 / total, frame_times[120], frame_times[228]])
	var overview := Camera3D.new()
	claim.add_child(overview)
	overview.position = Vector3(62, 65, 76)
	overview.look_at(Vector3(0, 0, 5))
	overview.current = true
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/milestone-1-overview.png")
	# Capture the same playable camera in SHOWING with a deterministic good pan.
	var walker: CharacterBody3D = claim.get_node("Walker")
	var panner: Node = walker.get_node("Panner")
	var layout = load("res://scripts/claim_layout.gd")
	walker.position = Vector3(0, layout.height_at(0, -5.5) + 0.04, -5.5)
	walker.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	var player_camera: Camera3D = rig.get_node("SpringArm3D/Camera3D")
	player_camera.current = true
	panner.start_pan()
	# A test-only injected result exercises the normal display/camera path.
	panner.result = {"tier": 3, "ounces": 0.1}
	for i in 400:
		await physics_frame
	await RenderingServer.frame_post_draw
	if panner.state != panner.State.SHOWING:
		push_error("Pan capture did not reach SHOWING")
		quit(1)
		return
	root.get_texture().get_image().save_png("res://artifacts/milestone-2-pan.png")
	# Check Escape is consumed by SHOWING, rather than quitting/releasing the mouse.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	if panner.state != panner.State.IDLE or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		push_error("Showing did not consume Escape")
		quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# An uncaptured click only recaptures; the following captured click starts a pan.
	for captured in [false, true]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		if (panner.state == panner.State.PANNING) != captured:
			push_error("Captured left-click pan gating failed")
			quit(1)
			return
		var release := click.duplicate() as InputEventMouseButton
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("PASS: Showing Escape and captured-only click controls.")
	overview.position = Vector3(0, 88, 7)
	overview.look_at(Vector3(0, 0, 7), Vector3.FORWARD)
	overview.projection = Camera3D.PROJECTION_ORTHOGONAL
	overview.size = 55.0
	overview.current = true
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_F3
	toggle.pressed = true
	Input.parse_input_event(toggle)
	Input.flush_buffered_events()
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/milestone-2-density.png")
	print("Saved player, overview, tier 3 pan, and F3 density renders to artifacts/.")
	quit()
