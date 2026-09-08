extends Node3D
## Smoothed orbit with a sphere-tested boom that retracts against terrain and rocks.

@export var target: Node3D
@export var mouse_sensitivity := 0.0022
@export var stick_speed := 1.5
@onready var arm: SpringArm3D = $SpringArm3D

var yaw := -0.65
var pitch := -0.22
const FOCUS_DURATION := 0.6
var focused := false
var panning := false
var side_sign := 1.0
var _focus_transform := Transform3D.IDENTITY
var _focus_blend := 0.0
var _orbit_position := Vector3.ZERO
var _orbit_rotation := Vector3.ZERO
var _spring_length := 4.6
var _shoulder := Vector3.ZERO
var _spring_margin := 0.18
var _transition_from := Transform3D.IDENTITY
var _transition_time := 1.0
var _transition_arm := Vector3.ZERO
var _transition_length := 0.0
var _transition_margin := 0.0

func _ready() -> void:
	rotation = Vector3(pitch, yaw, 0)
	global_position = target.global_position + Vector3(0, 1.45, 0)
	_orbit_position = global_position
	_orbit_rotation = rotation
	_spring_length = arm.spring_length
	_shoulder = arm.position
	_spring_margin = arm.margin
	arm.add_excluded_object(target.get_rid())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not focused and not panning and _transition_time >= FOCUS_DURATION:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -0.85, 0.32)

func _process(delta: float) -> void:
	if not focused and not panning and _transition_time >= FOCUS_DURATION:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		yaw -= stick.x * stick_speed * delta
		pitch = clampf(pitch - stick.y * stick_speed * delta, -0.85, 0.32)
	var blend := 1.0 - exp(-12.0 * delta)
	_orbit_rotation.y = lerp_angle(_orbit_rotation.y, yaw, blend)
	_orbit_rotation.x = lerpf(_orbit_rotation.x, pitch, blend)
	_orbit_position = _orbit_position.lerp(target.global_position + Vector3(0, 1.45, 0), blend)
	var orbit := Transform3D(Basis.from_euler(_orbit_rotation), _orbit_position)
	var held := focused or panning
	if panning: _update_side()
	_transition_time = minf(FOCUS_DURATION, _transition_time + delta)
	var weight := smoothstep(0.0, FOCUS_DURATION, _transition_time)
	var destination := _focus_transform if held else orbit
	global_transform = _transition_from.interpolate_with(destination, weight) if weight < 1.0 else destination
	arm.position = _transition_arm.lerp(Vector3.ZERO if held else _shoulder, weight)
	arm.spring_length = lerpf(_transition_length, 0.0 if held else _spring_length, weight)
	arm.margin = lerpf(_transition_margin, 0.0 if held else _spring_margin, weight)
	_focus_blend = 1.0 if held else 1.0-weight
	if held:
		var pan: Vector3 = target.get_node("Visual").pan_attachment.global_position
		# Sphere sweep remains active during the dolly as well as the held shot.
		var camera: Camera3D = arm.get_node("Camera3D")
		var desired := global_transform * arm.transform * Vector3(0,0,arm.spring_length)
		var safe := _safe_position(pan, desired)
		if safe.distance_to(desired) > .001:
			global_position += safe-desired
		camera.fov = lerpf(camera.fov, 38.0 if focused else 65.0, blend)
	else:
		var camera: Camera3D = arm.get_node("Camera3D")
		camera.fov = lerpf(camera.fov,65.0,blend)

func _begin_transition() -> void:
	_transition_from = global_transform
	_transition_arm = arm.position
	_transition_length = arm.spring_length
	_transition_margin = arm.margin
	_transition_time = 0.0

func _safe_position(origin: Vector3, destination: Vector3) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = arm.shape
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = destination-origin
	query.collision_mask = arm.collision_mask
	query.exclude = [target.get_rid()]
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	return origin + query.motion * maxf(0.0, fractions[0]-.01)

func begin_panning() -> void:
	_begin_transition()
	panning = true
	focused = false
	side_sign = 1.0
	_update_side()

func _update_side() -> void:
	var visual: Node3D = target.get_node("Visual")
	var hips: Vector3 = (visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("Hips"))).origin
	var pan: Vector3 = visual.pan_attachment.global_position
	var left := -visual.global_basis.x.normalized()
	var desired := hips + left * 2.2 * side_sign + Vector3.UP * .4
	var safe := _safe_position(pan,desired)
	if safe.distance_to(desired) > .12:
		var alternate := hips-left*2.2*side_sign+Vector3.UP*.4
		var alternative_safe := _safe_position(pan,alternate)
		if alternative_safe.distance_to(alternate) < safe.distance_to(desired):
			side_sign *= -1
			safe = alternative_safe
	_focus_transform = Transform3D(Basis.IDENTITY,safe).looking_at(pan,Vector3.UP)

func focus(pan_transform: Transform3D) -> void:
	if not focused: _begin_transition()
	focused = true
	panning = false
	var forward: Vector3 = -target.get_node("Visual").global_basis.z.normalized()
	# The imported socket is at the bowl bottom. Frame the opening's centre,
	# whose 8 cm rim offset follows the pan tilt, rather than its underside.
	var centre := pan_transform * Vector3(0,.08,0)
	var camera_point := _safe_position(centre,centre+forward*.55+Vector3.UP*.35)
	_focus_transform = Transform3D(Basis.IDENTITY, camera_point).looking_at(centre+Vector3.UP*.025, Vector3.UP)

func release_focus() -> void:
	if focused or panning: _begin_transition()
	focused = false
	panning = false
