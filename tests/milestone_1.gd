extends SceneTree
## Integration checks against the real scene, input actions, and physics bodies.
## Run with --headless --fixed-fps 60 --path . --script tests/milestone_1.gd

const Layout = preload("res://scripts/claim_layout.gd")
var failures: Array[String] = []
var claim: Node3D
var walker: CharacterBody3D
var camera: Node3D
var river: Area3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	claim = load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	walker = claim.get_node("Walker")
	camera = claim.get_node("CameraRig")
	river = claim.get_node("Greybox/River")
	await _frames(40)
	_check(walker.is_on_floor(), "Spawn settles onto terrain")
	_check(absf(walker.position.y - Layout.height_at(0, 6)) < 0.08, "Feet align with visible gravel")
	for binding in [[KEY_W, "move_forward"], [KEY_A, "move_left"], [KEY_S, "move_back"], [KEY_D, "move_right"], [KEY_UP, "move_forward"], [KEY_LEFT, "move_left"], [KEY_DOWN, "move_back"], [KEY_RIGHT, "move_right"]]:
		var key := InputEventKey.new()
		key.physical_keycode = binding[0]
		key.pressed = true
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		_check(Input.is_action_pressed(binding[1]), "Physical %s maps to %s" % [OS.get_keycode_string(binding[0]), binding[1]])
		var release := key.duplicate() as InputEventKey
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
	await _place(Vector2(0, 10))
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0.75
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	var original_yaw: float = camera.yaw
	await _frames(60)
	_check(camera.yaw < original_yaw - 0.5, "Right stick orbits the camera")
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	camera.pitch = -0.22
	await _place(Vector2(0, 10))
	var start := walker.position
	await _hold(["move_right"], 120)
	var distance := Vector2(walker.position.x - start.x, walker.position.z - start.z).length()
	_check(distance > 4.3 and distance < 5.0, "Walking travels about 4.8 m in two seconds")
	await _place(Vector2(0, 10))
	start = walker.position
	await _hold(["move_right", "move_back"], 120)
	_check(walker.position.distance_to(start) < 5.0, "Diagonal input does not increase walking speed")
	# Camera-relative movement after orbiting 90 degrees.
	await _place(Vector2(0, 10))
	camera.yaw = PI / 2.0
	camera.rotation.y = PI / 2.0
	start = walker.position
	await _hold(["move_forward"], 60)
	_check(walker.position.x < start.x - 1.8 and absf(walker.position.z - start.z) < 0.2, "Walk direction follows camera orbit")
	# Wade across the shallow shelf, and compare with dry-ground speed.
	await _place(Vector2(0, Layout.shore_z(0) - 2.0))
	start = walker.position
	await _hold(["move_left"], 90)
	var wade_speed := walker.position.distance_to(start) / 1.5
	_check(wade_speed > 1.0 and wade_speed < 2.1, "Wading slows walking")
	# Hold movement into the river, even at the taper, for 20 simulated seconds.
	for x in [-34.0, -20.0, 0.0, 18.0, 34.0]:
		await _place(Vector2(x, Layout.shore_z(x) + 1.0))
		await _hold(["move_forward"], 1200)
		_check(river.depth_at(walker.position) < 0.64, "Cannot enter deep water at x=%s" % x)
		_check(walker.is_on_floor() and walker.position.y > -0.7, "Remains grounded while wading at x=%s" % x)
	# Once beyond knee depth, releasing input must carry the player toward shore.
	await _place(Vector2(0, Layout.shore_z(0) - 4.0))
	var initial_depth: float = river.depth_at(walker.position)
	await _frames(180)
	_check(river.depth_at(walker.position) < initial_depth - 0.1, "Current returns an idle walker toward the bar")
	for side in [-1.0, 1.0]:
		await _place(Vector2(side * 30.0, Layout.shore_z(side * 30.0) + 3.0))
		var action := "move_left" if side < 0.0 else "move_right"
		await _hold([action], 1500)
		_check(absf(walker.position.x) < 41.0, "Cannot escape the %s end" % side)
		_check(walker.position.z < Layout.back_z(walker.position.x), "End push-back keeps walker below canyon slope")
	for x in [-25.0, 0.0, 28.0]:
		await _place(Vector2(x, Layout.back_z(x) - 5.0))
		await _hold(["move_back"], 900)
		_check(walker.position.z < Layout.back_z(walker.position.x), "Cannot climb the back canyon at x=%s" % x)
	# Deliberately drive into an actual boulder; terrain-only tests miss collider regressions.
	await _place(Vector2(-8, 15.0))
	await _hold(["move_back"], 240)
	_check(walker.position.z < 20.0, "Boulder physically blocks walking through its mesh")
	# Put the camera boom toward the same boulder and verify it retracts.
	await _place(Vector2(-8, 17.5))
	await _frames(60)
	var arm: SpringArm3D = camera.get_node("SpringArm3D")
	_check(arm.get_hit_length() < arm.spring_length - 0.2, "Camera boom retracts against a boulder")
	await _place(Vector2(0, 6))
	await _frames(60)
	_check(arm.get_hit_length() > 4.3, "Camera boom extends in open space and excludes the player")
	# Pushing diagonally along water must still allow travel along the shore.
	await _place(Vector2(0, Layout.shore_z(0) - 3.0))
	start = walker.position
	await _hold(["move_forward", "move_right"], 300)
	_check(walker.position.x > start.x + 2.0, "River boundary preserves tangential movement")
	# Combine both boundary gradients at the four corners.
	for x in [-35.0, 35.0]:
		for toward_water in [true, false]:
			await _place(Vector2(x, Layout.shore_z(x) + Layout.width_at(x) * 0.5))
			await _hold(["move_left" if x < 0 else "move_right", "move_forward" if toward_water else "move_back"], 1800)
			_check(absf(walker.position.x) < 41.0 and river.depth_at(walker.position) < 0.64 and walker.position.z < Layout.back_z(walker.position.x), "Diagonal escape held at x=%s, water=%s" % [x, toward_water])
	print("MILESTONE 1: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _place(point: Vector2) -> void:
	walker.position = Vector3(point.x, Layout.height_at(point.x, point.y) + 0.04, point.y)
	walker.velocity = Vector3.ZERO
	camera.yaw = 0.0
	camera.rotation.y = 0.0
	await _frames(20)

func _hold(actions: Array, frames: int) -> void:
	for action in actions:
		Input.action_press(action)
	await _frames(frames)
	for action in actions:
		Input.action_release(action)
	await _frames(1)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _check(condition: bool, description: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures.append(description)
		print("  position=%s depth=%.3f" % [walker.position, river.depth_at(walker.position)])
