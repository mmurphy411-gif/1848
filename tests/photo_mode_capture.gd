extends SceneTree
## Renders photo mode at golden hour in each tone, plus one real exposure.
## Run without --headless: writes artifacts/v2/photo_<tone>.png.
const Layout = preload("res://scripts/claim_layout.gd")
const TEST_DIR := "user://photo_mode_capture"
var claim: Node3D

func _initialize() -> void:
	run.call_deferred()
	create_timer(120).timeout.connect(func(): push_error("capture timed out"); quit(2))

func frames(n: int) -> void:
	for i in n: await process_frame

func save(name: String, settle := 20) -> void:
	await frames(settle)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("no image for " + name); return
	image.save_png("res://artifacts/v2/" + name + ".png")
	print("CAPTURE ", name, " ", image.get_size())

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/v2")
	root.size = Vector2i(1920, 1080)
	var game: Node = root.get_node("GameState")
	game.apply_scenario({"day": "38", "hour": "18.6", "weather": "clear"})
	claim = load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	await frames(30)
	var walker: CharacterBody3D = claim.get_node("Walker")
	var x := -3.0
	var z: float = Layout.shore_z(x) + 1.6
	walker.position = Vector3(x, Layout.height_at(x, z) + .05, z)
	walker.velocity = Vector3.ZERO
	walker.get_node("Visual").rotation.y = -1.75 # three-quarter towards the lens
	claim.get_node("Daylight").apply(18.6)
	await frames(30)
	var photo: Node = claim.get_node("PhotoMode")
	photo.plate_dir = TEST_DIR
	if not photo.enter():
		push_error("could not enter photo mode"); quit(1); return
	var cam: Camera3D = photo.camera
	var eye := walker.global_position + Vector3(3.6, 1.45, 1.4)
	cam.global_position = eye
	cam.look_at(walker.global_position + Vector3(-14, 2.2, -2.6))
	var forward := -cam.global_basis.z
	photo.yaw = atan2(-forward.x, -forward.z)
	photo.pitch = asin(forward.y)
	photo.target_fov = 50.0
	cam.fov = 50.0
	for tone in [0, 1, 2]:
		photo.tone = tone
		photo._apply_look()
		await save("photo_" + ["daguerreotype", "salt_print", "cyanotype"][tone])
	photo.tone = 0
	photo.toggle_mat()
	await save("photo_no_mat")
	photo.toggle_mat()
	# A real exposure through the game path, then tidy the test folder.
	photo.exposure_seconds = 20.0 # held open long enough to photograph the dial mid-exposure
	photo.expose()
	while photo.dial.progress < 0.12: await process_frame
	await save("photo_exposing", 1)
	photo.exposure_seconds = 0.1
	for i in 240:
		await process_frame
		if photo.state == photo.State.COMPOSING: break
	await save("photo_saved_toast", 3)
	print("EXPOSED ", photo.last_plate, " ", photo.toast.text)
	if photo.last_plate != "":
		var plate := Image.load_from_file(photo.last_plate)
		if plate: plate.save_png("res://artifacts/v2/photo_saved_plate.png")
		DirAccess.remove_absolute(photo.last_plate)
	DirAccess.remove_absolute(TEST_DIR)
	photo.leave()
	await save("photo_after_exit")
	claim.get_node("Soundscape").stop()
	claim.queue_free()
	await frames(5)
	quit()
