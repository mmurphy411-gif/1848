extends SceneTree
## Render-only review harness; never loaded by the playable scene.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var claim: Node3D = load("res://scenes/claim.tscn").instantiate()
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
	print("Saved player and overview renders to artifacts/.")
	quit()
