extends SceneTree
## Daguerreotype photo mode: entry gating, state capture and exact restore,
## tethered free camera, tone cycling, plate naming and the exposure cycle.
const Layout = preload("res://scripts/claim_layout.gd")
const PhotoMode = preload("res://scripts/photo_mode.gd")
const TEST_DIR := "user://photo_mode_test"
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()
	create_timer(60).timeout.connect(func(): push_error("photo mode test timed out"); quit(2))

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures.append(label)

func frames(count: int) -> void:
	for i in count: await process_frame

func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate()
	release.pressed = false
	root.push_input(release)

func clear_dir(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null: return
	for file in folder.get_files(): folder.remove(file)
	DirAccess.remove_absolute(path)

func run() -> void:
	var game: Node = root.get_node("GameState")
	game.apply_scenario({"day": "38", "hour": "18"})
	var claim: Node3D = load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	await frames(8)
	var photo: Node = claim.get_node_or_null("PhotoMode")
	check(photo != null and photo is CanvasLayer, "claim adds a PhotoMode canvas layer")
	if photo == null:
		finish(claim); return
	photo.plate_dir = TEST_DIR
	var walker: CharacterBody3D = claim.get_node("Walker")
	var clock: Node = claim.get_node("Daylight/Clock")
	var hud: CanvasLayer = claim.get_node("HUD")
	var activities: Node = claim.get_node("Activities")
	var rig_camera: Camera3D = claim.get_node("CameraRig/SpringArm3D/Camera3D")
	clock.start(18.6)
	check(InputMap.has_action("photo") and InputMap.action_get_events("photo").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_P), "photo action is bound to P")

	# Entry requires an idle miner.
	claim.get_node("Ledger").open_book()
	check(not activities.idle() and not photo.can_enter() and not photo.enter() and not photo.active, "open ledger blocks photo mode")
	claim.get_node("Ledger").close_book()
	activities.busy = true
	press_key(KEY_P); await frames(2)
	check(not photo.active, "P does nothing while the miner is busy")
	activities.busy = false
	check(activities.idle() and photo.can_enter(), "idle miner may enter photo mode")

	# Enter through the real input path.
	var clock_was: bool = clock.running
	var physics_was: bool = walker.is_physics_processing()
	var hud_was: bool = hud.visible
	var original_transform := rig_camera.global_transform
	press_key(KEY_P); await frames(2)
	check(photo.active and photo.visible, "P enters photo mode")
	check(not clock.running, "day clock stopped")
	check(not walker.is_physics_processing() and walker.velocity == Vector3.ZERO, "walker physics disabled and velocity zeroed")
	check(not hud.visible, "HUD hidden")
	var cam: Camera3D = photo.camera
	check(is_instance_valid(cam) and root.get_camera_3d() == cam, "plate camera is current")
	check(is_instance_valid(cam) and cam.global_position.distance_to(original_transform.origin) < .6 and absf(cam.fov - rig_camera.fov) < 1.0, "plate camera starts at the player camera")
	var hour_before: float = clock.hour_at(clock.elapsed)
	await frames(30)
	check(is_equal_approx(clock.hour_at(clock.elapsed), hour_before), "light holds still while composing")
	check(not photo.enter(), "second enter is refused while active")

	# Tether and ground clearance.
	var centre := walker.global_position + Vector3.UP * PhotoMode.TETHER_HEIGHT
	var worst_radius := 0.0
	var worst_clearance := 99.0
	for direction in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, -1, 0), Vector3(0, 1, 0), Vector3(1, -1, -1)]:
		for angle in [0.0, 1.3, 2.6, -1.9]:
			photo.look(Vector2(angle, -0.6 if direction.y < 0 else 0.2))
			photo.fly(direction, 100.0, true)
			var p: Vector3 = cam.global_position
			worst_radius = maxf(worst_radius, p.distance_to(centre))
			worst_clearance = minf(worst_clearance, p.y - Layout.height_at(p.x, p.z))
	check(worst_radius <= PhotoMode.RADIUS + .05, "camera stays within 14 m of the miner (worst %.2f m)" % worst_radius)
	check(worst_clearance >= PhotoMode.CLEARANCE - .001, "camera stays 0.3 m above terrain (worst %.2f m)" % worst_clearance)
	photo.move_camera(Vector3(0, -500, 0))
	var low: Vector3 = cam.global_position
	check(low.y >= Layout.height_at(low.x, low.z) + PhotoMode.CLEARANCE - .001, "a straight dive stops above the ground")
	photo.look(Vector2(0, 10)); check(absf(photo.pitch) <= PhotoMode.PITCH_LIMIT + .001, "pitch is clamped")
	for i in 40: photo.zoom(-5)
	check(photo.target_fov == PhotoMode.MIN_FOV, "lens narrows to 25 degrees")
	for i in 40: photo.zoom(5)
	check(photo.target_fov == PhotoMode.MAX_FOV, "lens widens to 75 degrees")

	# Tones.
	var material: ShaderMaterial = photo.overlay.material
	check(material.shader.resource_path.ends_with("daguerreotype.gdshader") and material.get_shader_parameter("tone") == 0, "daguerreotype shader with silver tone by default")
	press_key(KEY_T); await frames(1)
	check(photo.tone == 1 and material.get_shader_parameter("tone") == 1, "T selects the salt print")
	photo.cycle_tone()
	check(material.get_shader_parameter("tone") == 2, "then the cyanotype")
	photo.cycle_tone()
	check(material.get_shader_parameter("tone") == 0, "and back to the daguerreotype")
	photo.toggle_mat(); check(material.get_shader_parameter("mat_visible") == 0.0 and not photo.plate_label.visible, "M hides the mat and label")
	photo.toggle_mat(); check(material.get_shader_parameter("mat_visible") == 1.0, "M restores the mat")

	# Gameplay keys do not leak through while composing.
	var fisher: Node = walker.get_node("Fisher")
	press_key(KEY_F); press_key(KEY_G); press_key(KEY_C); press_key(KEY_F4); await frames(2)
	var crew_book: Node = claim.get_node_or_null("CrewBook")
	var sandbox: Node = claim.get_node_or_null("Sandbox")
	check(fisher.state == 0 and not activities.busy and not claim.get_node("Ledger").opened and not (crew_book and crew_book.get("opened") == true) and not (sandbox and sandbox.opened), "gameplay and menu keys are consumed")

	# Exposure cycle, headless-safe (no image -> nothing saved, no crash).
	photo.exposure_seconds = 0.2
	check(photo.expose() and photo.state == PhotoMode.State.EXPOSING and not photo.caption.visible and photo.dial.visible, "expose hides the caption and shows the dial")
	check(not photo.expose(), "a second exposure cannot start mid-exposure")
	for i in 150:
		await process_frame
		if photo.state == PhotoMode.State.COMPOSING: break
	check(photo.state == PhotoMode.State.COMPOSING and photo.toast.visible, "exposure completes and reports (%s)" % photo.toast.text)

	# Exit restores everything.
	press_key(KEY_ESCAPE); await frames(2)
	check(not photo.active and not photo.visible, "Esc leaves photo mode")
	check(clock.running == clock_was, "clock running state restored")
	check(walker.is_physics_processing() == physics_was, "walker physics restored")
	check(hud.visible == hud_was, "HUD visibility restored")
	check(root.get_camera_3d() == rig_camera and photo.camera == null, "original camera current and plate camera released")
	await frames(2)
	check(not is_instance_valid(cam), "plate camera freed")
	check(claim.get_node("CameraRig").is_processing(), "orbit rig processing restored")

	# Double enter / exit.
	photo.leave(); photo.leave()
	check(photo.enter() and not photo.enter(), "re-enter once")
	press_key(KEY_P); await frames(2)
	check(not photo.active and clock.running == clock_was and walker.is_physics_processing() and hud.visible and root.get_camera_3d() == rig_camera, "P leaves and restores")
	photo.toggle(); photo.toggle(); photo.toggle(); photo.leave()
	check(not photo.active and clock.running == clock_was and walker.is_physics_processing() and hud.visible and root.get_camera_3d() == rig_camera, "rapid toggles leave a clean state")

	# Clock that was already stopped stays stopped.
	clock.running = false
	photo.enter(); photo.leave()
	check(not clock.running, "a paused clock stays paused after leaving")
	clock.running = true

	# Plate naming.
	clear_dir(TEST_DIR)
	check(PhotoMode.next_plate_path(TEST_DIR, 5) == TEST_DIR + "/plate_5_001.png", "first plate is 001")
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var dummy := Image.create(4, 4, false, Image.FORMAT_RGB8)
	dummy.fill(Color(.5, .5, .5))
	dummy.save_png(PhotoMode.next_plate_path(TEST_DIR, 5))
	check(PhotoMode.next_plate_path(TEST_DIR, 5) == TEST_DIR + "/plate_5_002.png", "second plate is 002")
	dummy.save_png(TEST_DIR + "/plate_3_007.png")
	FileAccess.open(TEST_DIR + "/notes.txt", FileAccess.WRITE).store_string("not a plate")
	check(PhotoMode.next_plate_path(TEST_DIR, 9) == TEST_DIR + "/plate_9_008.png", "numbering runs past every existing plate")
	clear_dir(TEST_DIR)
	check(not DirAccess.dir_exists_absolute(TEST_DIR), "temporary plate folder cleaned up")

	# Freeing the claim mid-composition must not strand global state.
	photo.enter()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finish(claim)

func finish(claim: Node) -> void:
	claim.get_node("Soundscape").stop()
	claim.queue_free()
	for i in 5: await process_frame
	check(not is_instance_valid(claim), "claim freed while composing without errors")
	print("PHOTO MODE ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
