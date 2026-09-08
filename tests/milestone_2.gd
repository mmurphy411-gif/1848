extends SceneTree
## Real input, physics, state transitions and deterministic distribution checks.

const Layout = preload("res://scripts/claim_layout.gd")
const GoldMap = preload("res://scripts/gold_map.gd")
const PanResult = preload("res://scripts/pan_result.gd")
var failures: Array[String] = []
var walker: CharacterBody3D
var panner: Node
var rig: Node3D
var claim: Node3D
var sack: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_density()
	_test_rolls()
	claim = load("res://scenes/claim.tscn").instantiate()
	var spawn_position: Vector3 = claim.get_node("Walker").position
	claim.get_node("Walker/Panner").reproducible = true
	root.add_child(claim)
	walker = claim.get_node("Walker")
	panner = walker.get_node("Panner")
	rig = claim.get_node("CameraRig")
	sack = root.get_node("Sack")
	await _frames(40)
	_check(panner.rng.seed == hash(spawn_position), "Test RNG is seeded from the walker spawn")
	_check(sack.ounces == 0.0 and sack.stage() == 0, "Sack starts empty")
	_check(not panner.pan.visible, "Pan is hidden while idle")
	await _place(Vector2(0, Layout.shore_z(0) + 8.0))
	_key(KEY_E)
	_check(panner.state == panner.State.IDLE, "Pan input does nothing 8 m inland")
	await _place(Vector2(0, Layout.shore_z(0) + 0.3))
	_key(KEY_E)
	_check(panner.state == panner.State.PANNING, "E starts PANNING at the waterline")
	_check(panner.pan.visible, "Placeholder pan appears during PANNING")
	var start := walker.position
	var held_density: float = panner.sampled_density
	var held_result: Dictionary = panner.result.duplicate()
	Input.action_press("move_right")
	await _frames(180)
	Input.action_release("move_right")
	_check(walker.position.distance_to(start) < 0.1, "Movement is ignored while panning")
	_check(panner.state == panner.State.PANNING and sack.ounces == 0.0, "Panning remains active at 3 seconds without an award")
	_key(KEY_E)
	_check(panner.result == held_result and panner.sampled_density == held_density, "Repeated input cannot reroll a held result")
	# Move the test body to a different legal sample; the held result must not change.
	walker.position.x = 1.0
	await _frames(20)
	_check(panner.result == held_result and panner.sampled_density == held_density, "Density is sampled once on entry")
	walker.position = Vector3(0, -0.7, Layout.shore_z(0) - 4.0)
	await _frames(2)
	_check(panner.state == panner.State.IDLE and sack.ounces == 0.0, "Deep water cancels with no gold")
	_check(not panner.pan.visible and not rig.focused, "Cancellation resets pan and camera")
	for point in GoldMap.peak_points():
		await _place(point)
		_check(panner.can_pan() and GoldMap.density_at(walker.position.x, walker.position.z) > 0.7, "Rich pocket is physically accessible at %s" % point)
	# Exercise six complete timed pans, alternating natural completion and Escape.
	var awarded := 0.0
	var peak := GoldMap.peak_points()[0]
	for cycle in 6:
		await _place(peak)
		_key(KEY_E)
		_check(panner.state == panner.State.PANNING, "Peak is accessible for pan %d" % cycle)
		var amount: float = panner.result.get("ounces", 0.0)
		await _frames(int(panner.PAN_DURATION * 60) - 2)
		_check(panner.state == panner.State.PANNING, "Pan lasts the full six seconds (%d)" % cycle)
		await _frames(40)
		_check(panner.state == panner.State.SHOWING and rig.focused, "Six-second pan enters focused SHOWING (%d)" % cycle)
		var camera: Camera3D = rig.get_node("SpringArm3D/Camera3D")
		_check(camera.global_position.distance_to(panner.pan.global_position) < 1.0, "Camera dollies within 1 m of the pan (%d)" % cycle)
		var yaw: float = rig.yaw
		Input.action_press("look_right")
		await _frames(20)
		Input.action_release("look_right")
		_check(is_equal_approx(rig.yaw, yaw), "Orbit input is ignored during focus (%d)" % cycle)
		_check(is_equal_approx(sack.ounces, awarded), "Gold is not awarded before showing ends (%d)" % cycle)
		if cycle % 2 == 0:
			_key(KEY_ESCAPE)
			await _frames(2)
		else:
			await _frames(125)
		awarded += amount
		_check(panner.state == panner.State.IDLE and is_equal_approx(sack.ounces, awarded), "Pan awards exactly once on completion (%d)" % cycle)
		await _frames(60)
		var arm: SpringArm3D = rig.get_node("SpringArm3D")
		_check(not rig.focused and is_equal_approx(arm.spring_length, 4.6), "Normal camera boom is restored (%d)" % cycle)
		_check(camera.global_position.distance_to(walker.global_position) < 5.0, "Camera returns within 5 m of walker (%d)" % cycle)
	_check(claim.get_node("HUD").label.text == "%.2f oz" % awarded, "HUD matches the awarded sack total")
	# Gamepad A/cross is the same action, using an actual input event.
	await _place(Vector2(0, Layout.shore_z(0) + 0.3))
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	Input.parse_input_event(button)
	Input.flush_buffered_events()
	_check(panner.state == panner.State.PANNING, "Gamepad A starts a pan")
	var release := button.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	# Five visual tiers have distinct fleck counts and a nugget only in tier 4.
	for tier in 5:
		panner.pan.show_result(tier, 42)
		var count: int = panner.pan.flecks.multimesh.instance_count
		var ranges := [Vector2i(0, 0), Vector2i(2, 3), Vector2i(12, 20), Vector2i(40, 60), Vector2i(40, 60)]
		_check(count >= ranges[tier].x and count <= ranges[tier].y and panner.pan.nugget.visible == (tier == 4), "Readable fleck count for tier %d" % tier)
	var debug: Node3D = claim.get_node("DensityDebug")
	_check(not debug.visible, "Density overlay defaults off")
	_key(KEY_F3)
	_check(debug.visible == OS.is_debug_build(), "F3 toggles the debug-only overlay")
	_key(KEY_F3)
	_check(not debug.visible, "F3 hides the overlay again")
	for index in 5:
		var threshold: float = sack.THRESHOLDS[index]
		sack.ounces = maxf(0.0, threshold - 0.001)
		_check(sack.stage() == maxi(0, index - 1), "Sack stage just below threshold %s" % threshold)
		sack.add(threshold - sack.ounces)
		_check(sack.stage() == index, "Sack stage at threshold %s" % threshold)
	print("MILESTONE 2: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _test_density() -> void:
	for point in [Vector2(50, 0), Vector2(0, 40), Vector2(0, -16), Vector2(-43, 12)]:
		_check(GoldMap.density_at(point.x, point.y) == 0.0, "Zero density outside the claim at %s" % point)
	var peaks := GoldMap.peak_points()
	_check(peaks.size() >= 3 and peaks.size() <= 5, "Three to five distinct rich pockets")
	for peak in peaks:
		_check(GoldMap.density_at(peak.x, peak.y) > 0.7, "Rich peak at %s" % peak)
	var head := peaks[0]
	_check(GoldMap.density_at(head.x, head.y) - GoldMap.density_at(-head.x, head.y) >= 0.3, "Bar head is richer than mirrored downstream gravel")
	for rock in Layout.BOULDERS:
		if absf(rock.y - Layout.shore_z(rock.x)) <= 6.0:
			var lee := GoldMap.density_at(rock.x + 2.0, rock.y)
			var face := GoldMap.density_at(rock.x - 2.0, rock.y)
			_check(lee - face >= 0.3, "Boulder lee beats upstream face at x=%s (%.3f / %.3f)" % [rock.x, lee, face])
	_check(GoldMap.density_at(0, Layout.shore_z(0) + 15) < 0.05, "Fine inland sand is poor")
	_check(GoldMap.density_at(-10, -4) == GoldMap.density_at(-10, -4), "Density sampling is deterministic")

func _test_rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1848
	var rich := 0
	var lean := 0
	var steady := 0
	var previous := -1
	var peak := GoldMap.peak_points()[0]
	var peak_density := GoldMap.density_at(peak.x, peak.y)
	var lean_density := GoldMap.density_at(0, Layout.shore_z(0) + 0.3)
	for i in 20:
		var result := PanResult.roll(peak_density, rng)
		rich += int(result.tier >= 2)
		steady += int(previous < 0 or absi(result.tier - previous) <= 1)
		previous = result.tier
		lean += int(PanResult.roll(lean_density, rng).tier <= 1)
	_check(rich >= 15 and lean >= 15, "20 peak and lean pans have clearly different results")
	_check(steady >= 16, "Repeated peak pans remain within one tier")
	var nuggets := 0
	for i in 200:
		nuggets += int(PanResult.roll(0.5, rng).tier == 4)
	_check(nuggets == 0, "No nuggets in 200 moderate-density rolls")
	nuggets = 0
	for i in 400:
		var result := PanResult.roll(0.95, rng)
		nuggets += int(result.tier == 4)
		if result.tier == 4 and (result.ounces < 0.3 or result.ounces > 1.15):
			failures.append("Nugget ounces outside the specified range")
	_check(nuggets > 0 and nuggets < 60, "Rare nuggets occur in 400 rich rolls (%d)" % nuggets)
	var repeat := RandomNumberGenerator.new()
	rng.seed = 73
	repeat.seed = 73
	_check(PanResult.roll(0.6, rng) == PanResult.roll(0.6, repeat), "Fixed seeds reproduce pan results")

func _place(point: Vector2) -> void:
	walker.position = Vector3(point.x, Layout.height_at(point.x, point.y) + 0.04, point.y)
	walker.velocity = Vector3.ZERO
	await _frames(30)

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _check(condition: bool, description: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures.append(description)
