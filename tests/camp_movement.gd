extends SceneTree
## Walk through low camp clutter using the real claim, capsule and input path.
const Layout = preload("res://scripts/claim_layout.gd")
var failures: Array[String] = []
var claim: Node3D
var walker: CharacterBody3D

func _initialize() -> void:
	run.call_deferred()
	create_timer(60).timeout.connect(func(): push_error("Camp movement timeout"); quit(2))

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures.append(label)

func walk_across(label: String, center: Vector3, direction: Vector3, distance: float, should_cross := true) -> void:
	Input.action_release("move_forward")
	walker.global_position = center - direction * distance * .5
	walker.position.y = Layout.height_at(walker.position.x, walker.position.z) + .02
	walker.velocity = Vector3.ZERO
	claim.get_node("CameraRig").rotation.y = atan2(-direction.x, -direction.z)
	for i in 15: await physics_frame
	var start := walker.global_position
	Input.action_press("move_forward")
	for i in 150: await physics_frame
	Input.action_release("move_forward")
	var traveled := (walker.global_position - start).dot(direction)
	check(traveled > distance if should_cross else traveled < distance, "%s (%.2fm)" % [label, traveled])
	for i in 15: await physics_frame
	check(walker.is_on_floor(), label + " stays grounded")

func run() -> void:
	root.get_node("GameState").apply_scenario({"day":"20", "hour":"12", "weather":"clear", "firewood":"6"})
	claim = load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	walker = claim.get_node("Walker")
	claim.get_node("CameraRig").set_physics_process(false)
	claim.get_node("CameraRig").set_process(false)
	claim.get_node("Daylight/Clock").running = false
	var camp: Node3D = claim.get_node("Camp")
	await walk_across("Cross skillet", camp.props.Skillet.global_position, Vector3.RIGHT, 2.0)
	await walk_across("Cross driftwood", camp.props.Driftwood.global_position, Vector3.RIGHT, 2.0)
	await walk_across("Cross driftwood in reverse", camp.props.Driftwood.global_position, Vector3.LEFT, 2.0)
	await walk_across("Cross fire ring", camp.global_position, Vector3.FORWARD, 2.5)
	await walk_across("Cross fire ring inland", camp.global_position, Vector3.BACK, 2.5)
	await walk_across("Crate remains solid", camp.props.Crate.global_position, Vector3.BACK, 2.0, false)
	# The same low obstacle must remain impassable if lifting the capsule hits a roof.
	var ceiling := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, .1, 2)
	shape.shape = box
	ceiling.add_child(shape)
	claim.add_child(ceiling)
	ceiling.global_position = camp.props.Driftwood.global_position + Vector3(0, 1.94, 0)
	await walk_across("Low ceiling prevents stepping", camp.props.Driftwood.global_position, Vector3.RIGHT, 2.0, false)
	print("CAMP MOVEMENT: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
